import Foundation
@testable import NTSDCore
@testable import NTSDRuntime

/// ENGINE_SPLIT E7f: one VS match of player 1 against a computer player on the
/// synthetic pack, played to its end and back to the menu, observed once per
/// test process and glyph source (684 loaded cycles; about 7 s in a debug build).
/// SyntheticComputerMatchTests reads the run without glyphs (rungs 1-3),
/// SyntheticTextTests the run with the authored glyph source (rung 4).
///
/// Input is replay-supplied (the session's `--loaded-script` form): the start
/// (`SyntheticRun.scriptComputerStart`) and, at the result screen, player 1's
/// attack (`scriptLeaveResult`). Player 1 does nothing else; the computer's
/// buttons come from the engine's character AI on the synthetic rules
/// (`OriginalCharacterAI`, the profile's AI rows with no IDs and the engine
/// tests' `NoSpecialMoves`, EngineTestRules.swift:41-45, 48-51), run by the runtime's
/// loading for every gameplay body (OriginalMacRuntimeLoading.swift:370-372).
enum SyntheticComputerMatch {
    /// Rung 1's bodies: the computer walks up and fights (the knock-out comes later).
    static let fightBodies = 150
    /// Bodies whose frames are digested with SHA-256 besides the result screen's.
    static let frameBodies = [1, 75, 150]
    /// Loaded cycles (counted after the cycle) of menu screens whose frames are
    /// digested: the character screen with player 1 ready, the computer's
    /// character being chosen, its team, and the settings.
    static let menuCycles = [24, 190, 202, 216]

    struct Observation {
        /// Loaded cycles after the launch and after the first gameplay body.
        var launchCycle = -1, firstBodyCycle = -1
        /// The computer players' slots (one expected).
        var computers: [Int] = []
        /// 64-bit chains over every presented gameplay frame: through `fightBodies`, and through the last body.
        var fightChain = SyntheticDigest.fnvBasis, chain = SyntheticDigest.fnvBasis
        /// Frames: SHA-256 at gameplay bodies, FNV-64 (SyntheticDigest.fnv64) at
        /// menu cycles and at the cycles after the match.
        var frames: [Int: String] = [:], menuFrames: [Int: String] = [:], afterFrames: [Int: String] = [:]
        /// The fighters (SyntheticRun.Fighter) at sampled bodies.
        var states: [Int: [String]] = [:]
        /// The computer's seven buttons after each of the first `fightBodies` bodies.
        var aiKeys: [[UInt8]] = []
        /// World and Actors (SyntheticDigest.records) after `fightBodies` and at the result screen's wait.
        var fightWorldActors = "", endWorldActors = ""
        /// Character-AI calls and replayed text calls after `fightBodies`.
        var fightCharacterAI = 0, fightReplayedText = 0
        /// The match's end: the first body with player 1's HP at or below 0,
        /// the first with the round timer (0x450bdc) at 1, 101 (the result's
        /// recording and layout, OriginalResultRecording.swift:101-107) and
        /// 144 (where the round waits, OriginalMatchRound.swift:122); the last body.
        var koBody = -1, timerStartBody = -1, resultBody = -1, waitBody = -1, lastBody = -1
        /// Globals at the wait: winner team 0x450bf8, ticks 0x450bbc, 0x44d02c,
        /// recording flag 0x450b80, 0x450b70, timer 0x450bdc.
        var endGlobals: [Int32] = []
        /// Replay files the runtime had saved before and after the result body.
        var replaysBeforeResult = -1, replaysAtResult = -1
        /// The prelude's replay name (globals 0x44fd98), read at the wait.
        var preludeName = ""
        /// The epilogue's loaded cycle and the menu state (0x44d020) after it and one cycle later.
        var epilogueCycle = -1, menuAfter: [Int32] = []
        /// The runtime's saved replays, the files in the overlay's `recording`
        /// folder, and the writes it refused or failed.
        var replays: [(path: String, bytes: [UInt8])] = [], recordingFolder: [String: [UInt8]] = [:]
        var refusedReplays: [String] = [], failedReplays: [String] = []
        /// The first saved replay read back through the engine's playback loader
        /// (OriginalReplayFileInput.load): its status, payload and inflated
        /// lengths, the recording's FNV-64 and selected words.
        var playbackStatus: Int32 = -2, payloadLength: Int?, inflatedLength: Int?
        var recordingFNV = "", recordingWords: [Int: Int32] = [:], recordingNames: [String] = []
        var counts = OriginalMacRuntimeLoading.Counts(), soundsPerformed = 0, committed = 0, cycles = 0, log: [String] = []
    }
    /// Recording offsets read back (OriginalReplayRecording.swift:79-104 at the
    /// start, OriginalResultRecording.swift:107-169 at the end).
    static let recordingOffsets: [Int] = {
        var offsets: [Int] = [0x0, 0x4, 0x10, 0x144, 0x148, 0x1a4, 0x744, 0x748, 0x8c4]
        for seat in 0..<8 { for base in [0x14, 0x34, 0x54, 0x114] { offsets.append(base + 4*seat) } }
        for slot in [0, 11] { for base in [0x1a8, 0x1f0, 0x238] { offsets.append(base + 4*slot) } }
        return offsets
    }()

    @MainActor private static var observed: [Bool: Result<Observation, Error>] = [:]
    /// The match observed once per process for `glyphs`.
    @MainActor static func observation(glyphs: Bool) throws -> Observation {
        if let known = observed[glyphs] { return try known.get() }
        let result = Result { try observe(glyphs: glyphs) }
        observed[glyphs] = result
        return try result.get()
    }

    @MainActor private static func observe(glyphs: Bool) throws -> Observation {
        try SyntheticContentPack.withWrittenPack { root, pack in try MainActor.assumeIsolated {
            let run = try SyntheticRun(root: root, pack: pack, glyphs: glyphs)
            try run.run(limit: 5) { run.committed == 5 }
            try run.clickStart()
            run.scriptComputerStart(); run.scriptLeaveResult()
            var o = Observation()
            @MainActor func frame() throws -> OriginalFramebuffer {
                guard let frame = try run.presented() else { throw SyntheticRunError.unexpected("no presented frame at cycle \(run.cycles)") }
                return frame
            }
            // The menus and the launch.
            while run.gameplayBodies == 0 {
                guard run.cycles < 400, run.steps < 4000 else { throw SyntheticRunError.stepBound(400) }
                let stepped = try run.step()
                if case .quit(let code) = stepped { throw SyntheticRunError.quit(code) }
                if stepped == .loaded(.launched) { o.launchCycle = run.cycles }
                if stepped == .loaded(.menu), menuCycles.contains(run.cycles) { o.menuFrames[run.cycles] = SyntheticDigest.fnv64(try frame()) }
            }
            o.firstBodyCycle = run.cycles
            o.computers = try run.computerSlots()
            guard let computer = o.computers.first else { throw SyntheticRunError.unexpected("no computer player") }
            guard let loading = run.loading else { throw SyntheticRunError.noState }
            @MainActor func worldAndActors() throws -> String {
                guard let m = run.match else { throw SyntheticRunError.noState }
                return SyntheticDigest.records([m.world] + m.actors)
            }
            @MainActor func record() throws {
                let body = run.gameplayBodies, shown = try frame()
                SyntheticDigest.fnv64(shown, into: &o.chain)
                o.lastBody = body
                if frameBodies.contains(body) { o.frames[body] = SyntheticDigest.sha256(shown) }
                if body <= fightBodies {
                    o.aiKeys.append(try run.buttons(slot: computer))
                    if body == 1 || body % 25 == 0 { o.states[body] = try run.fighters().map(\.description) }
                }
                if body == fightBodies {
                    o.fightChain = o.chain; o.fightWorldActors = try worldAndActors()
                    o.fightCharacterAI = loading.counts.characterAI; o.fightReplayedText = loading.counts.replayedText
                }
                let fighters = try run.fighters()
                if o.koBody < 0, let player = fighters.first(where: { $0.seat == 0 }), player.hp <= 0 {
                    o.koBody = body; o.states[body] = fighters.map(\.description)
                }
                switch try run.global(0x450bdc) {
                case 1 where o.timerStartBody < 0: o.timerStartBody = body
                case 100 where o.replaysBeforeResult < 0: o.replaysBeforeResult = loading.savedReplays.count
                case 101 where o.resultBody < 0:
                    o.resultBody = body; o.replaysAtResult = loading.savedReplays.count
                    o.frames[body] = SyntheticDigest.sha256(shown)
                case 144 where o.waitBody < 0:
                    o.waitBody = body; o.frames[body] = SyntheticDigest.sha256(shown)
                    o.states[body] = fighters.map(\.description)
                    o.endWorldActors = try worldAndActors()
                    o.endGlobals = try [0x450bf8, 0x450bbc, 0x44d02c, 0x450b80, 0x450b70, 0x450bdc].map { try run.global($0) }
                    guard let m = run.match else { throw SyntheticRunError.noState }
                    let name = try (0..<40).map { try m.globals.integer(at: 0x44fd98 - OriginalMatchPreparation.globalBase + $0, as: UInt8.self) }
                    o.preludeName = String(decoding: name.prefix { $0 != 0 }, as: UTF8.self)
                default: break
                }
            }
            try record()
            // The match, the result screen, the epilogue and one menu cycle after it.
            while o.menuAfter.count < 2 {
                guard run.cycles < 1000, run.steps < 10000 else { throw SyntheticRunError.stepBound(1000) }
                let before = run.gameplayBodies, stepped = try run.step()
                if case .quit(let code) = stepped { throw SyntheticRunError.quit(code) }
                if run.gameplayBodies > before { try record(); continue }
                // Committed iterations of the window's message loop (no loading request) come between.
                if stepped == .committed { continue }
                guard stepped == .loaded(.menu) else { throw SyntheticRunError.unexpected("\(stepped) at cycle \(run.cycles)") }
                if o.epilogueCycle < 0 { o.epilogueCycle = run.cycles }
                o.menuAfter.append(try run.global(0x44d020))
                o.afterFrames[run.cycles] = SyntheticDigest.fnv64(try frame())
            }
            // The replay the match's end wrote, as saved and as on disk.
            o.replays = loading.savedReplays.map { ($0.path, $0.bytes) }
            o.refusedReplays = loading.refusedReplayOpens; o.failedReplays = loading.failedReplayWrites
            let folder = root.appendingPathComponent("overlay", isDirectory: true).appendingPathComponent("recording", isDirectory: true)
            for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] {
                o.recordingFolder[name] = [UInt8](try Data(contentsOf: folder.appendingPathComponent(name)))
            }
            if let file = o.replays.first?.bytes, let m = run.match {
                var globals = m.globals
                let read = try OriginalReplayFileInput.load(file: file, globals: &globals)
                o.playbackStatus = read.status; o.payloadLength = read.payloadLength; o.inflatedLength = read.inflatedLength
                if let recording = read.recording {
                    o.recordingFNV = SyntheticDigest.fnv64(recording)
                    for offset in recordingOffsets {
                        o.recordingWords[offset] = Int32(bitPattern: (0..<4).reduce(UInt32(0)) { $0 | UInt32(recording[offset + $1]) << (8*$1) })
                    }
                    o.recordingNames = (0..<8).map { seat in
                        String(decoding: recording[(0x14c + 11*seat)...].prefix { $0 != 0 }, as: UTF8.self)
                    }
                }
            }
            o.counts = loading.counts; o.soundsPerformed = run.sounds.performed
            o.committed = run.committed; o.cycles = run.cycles; o.log = run.log.shown
            return o
        } }
    }
}
