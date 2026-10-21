import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDRuntime

/// ENGINE_SPLIT E7f, rung 1: a VS match with one computer-controlled fighter
/// on the synthetic rules (SyntheticComputerMatch, no glyphs). Player 1 picks
/// SyOne and stands still; the computer (seat 1, slot 11) plays SyThree. Its
/// buttons are the engine's character AI's: with the profile's AI rows empty
/// and `NoSpecialMoves`, the generic AI targets the nearest enemy once it has
/// stopped blinking (Actor +8, OriginalCharacterAI.swift:249), walks up,
/// aligns its depth and attacks (:404-446, 448-466, 609-612). The first 150
/// bodies are pinned: frames, the fighters, the World and Actors, and the
/// buttons the AI chose for every body.
final class SyntheticComputerPlayerTests: XCTestCase {
    typealias Match = SyntheticComputerMatch

    func testComputerPlayerFights() throws {
        let o = try MainActor.assumeIsolated { try Match.observation(glyphs: false) }
        let keys = Match.fightBodies
        syntheticLog("E7F rung1 launch \(o.launchCycle) firstBody \(o.firstBodyCycle) computers \(o.computers) ai \(o.fightCharacterAI)")
        syntheticLog("E7F rung1 fightChain \(String(o.fightChain, radix: 16)) frames \(o.frames.filter { Match.frameBodies.contains($0.key) }.sorted { $0.key < $1.key }) worldActors \(o.fightWorldActors)")
        for (body, state) in o.states.sorted(by: { $0.key < $1.key }) where body <= keys { syntheticLog("E7F rung1 body \(body) \(state)") }
        let pressed = (0..<7).map { key in o.aiKeys.filter { $0[key] != 0 }.count }
        let keyDigest = SyntheticContentPack.digest(o.aiKeys.flatMap { $0 })
        syntheticLog("E7F rung1 aiKeys pressed (up down left right attack jump defend) \(pressed) digest \(keyDigest)")
        syntheticLog("E7F rung1 aiKeys \(o.aiKeys.enumerated().filter { $0.element.contains(1) }.map { "\($0.offset + 1):\($0.element.map(String.init).joined())" }.joined(separator: " "))")

        XCTAssertEqual([o.launchCycle, o.firstBodyCycle], Self.pinnedClock)
        XCTAssertEqual(o.computers, [11], "seat 1's computer plays in slot 11")
        XCTAssertEqual(o.aiKeys.count, keys)
        // One character-AI call per body: the computer's slot (OriginalLocalInput.swift:114-127).
        XCTAssertEqual(o.fightCharacterAI, keys)
        XCTAssertEqual(String(o.fightChain, radix: 16), Self.pinnedChain)
        XCTAssertEqual(o.frames.filter { Match.frameBodies.contains($0.key) }, Self.pinnedFrames)
        XCTAssertEqual(o.fightWorldActors, Self.pinnedWorldAndActors)
        XCTAssertEqual(o.states.filter { $0.key <= keys }, Self.pinnedStates)
        // The AI acts: what it chose, per key and as a whole.
        XCTAssertEqual(pressed, Self.pinnedPressed)
        XCTAssertEqual(keyDigest, Self.pinnedKeyDigest)
        XCTAssertEqual(o.log, [])
    }
    /// Loaded cycles after the launch and after the first body.
    static let pinnedClock = [220, 221]
    static let pinnedChain = "c30d562c9889802d"
    static let pinnedFrames = [1: "7382fdc99a1b8e84e378a89762b6c644e69402014370b708fb8d36883d6fe605",
                               75: "336f0e1893cf2e9eaf77050b1ab67e59b548789726610a3b553a3b8061e4552b",
                               150: "9dfce23b37fa1a6890a49de5e78576a9ebcda9d673c0209bc074de4d623e3a39"]
    static let pinnedWorldAndActors = "cd00a81c1ea92c74222349284610b83ef3e2dd13a7a7eb5ad80d64ceefb71874"
    /// Body 1: both landed (219); 25, 50: both blinking, the computer idles
    /// (no target, OriginalCharacterAI.swift:141); 75: it walks up and left
    /// (frame 5, facing left); 100: it runs (11) beside player 1, closing
    /// the depth (z 380 against 344); 125:
    /// player 1 hit once (SyThree's injury 94, then 1 HP regained) and injured
    /// (225); 150: player 1 falling (188) after a third hit, at 221 HP, the
    /// computer walking after it.
    static let pinnedStates: [Int: [String]] = [
        1: ["s0 id1 f219 (250,0,344) hp500 face0", "s11 id3 f219 (425,0,416) hp500 face0"],
        25: ["s0 id1 f3 (250,0,344) hp500 face0", "s11 id3 f2 (425,0,416) hp500 face0"],
        50: ["s0 id1 f2 (250,0,344) hp500 face0", "s11 id3 f1 (425,0,416) hp500 face0", "s50 id150 f3 (78,-177,403) hp500 face0"],
        75: ["s0 id1 f2 (250,0,344) hp500 face0", "s11 id3 f5 (419,0,412) hp500 face1", "s50 id150 f60 (78,0,403) hp500 face0"],
        100: ["s0 id1 f1 (250,0,344) hp500 face0", "s11 id3 f11 (245,0,380) hp500 face1", "s50 id150 f60 (78,0,403) hp500 face0",
              "s51 id150 f0 (648,-500,412) hp500 face0"],
        125: ["s0 id1 f225 (272,0,344) hp407 face0", "s11 id3 f66 (243,0,345) hp500 face0", "s50 id150 f60 (78,0,403) hp500 face0",
              "s51 id150 f60 (648,0,412) hp500 face0"],
        150: ["s0 id1 f188 (355,-8,344) hp221 face0", "s11 id3 f6 (263,0,345) hp500 face0", "s50 id150 f60 (78,0,403) hp500 face0",
              "s51 id150 f60 (648,0,412) hp500 face0"]]
    /// Bodies (of 150) after which the AI held up, down, left, right, attack,
    /// jump, defend: nothing for the first 73 (player 1 blinks), then up and
    /// left to close in, attacks from body 118, right to follow the fall.
    static let pinnedPressed = [44, 0, 18, 10, 19, 1, 0]
    static let pinnedKeyDigest = "c75bbade2e60ba69d43467a7fcb7f00ef6f39665d0da0ec80d78b10ae2262695"
}

/// ENGINE_SPLIT E7f, rung 2: the same match to its end. The computer's hits
/// take player 1's 500 HP (OriginalStateRecord.swift:1025) below zero; with
/// one living team the round timer runs (OriginalMatchRound.swift:99-106):
/// at 101 the result is recorded and the result screen drawn
/// (OriginalResultRecording.swift:99-178, OriginalResultLayout.swift:96-160),
/// at 144 the round waits (OriginalMatchRound.swift:122) until player 1's
/// attack sets 350 (:138-152), and the next round's restoration returns to the
/// menu through the epilogue (:123-135, OriginalApplicationEpilogueSession).
final class SyntheticMatchEndTests: XCTestCase {
    typealias Match = SyntheticComputerMatch

    func testMatchEndsAtTheResultScreen() throws {
        let o = try MainActor.assumeIsolated { try Match.observation(glyphs: false) }
        let c = o.counts
        syntheticLog("E7F rung2 ko \(o.koBody) timer1 \(o.timerStartBody) result \(o.resultBody) wait \(o.waitBody) last \(o.lastBody) epilogue \(o.epilogueCycle) menuAfter \(o.menuAfter) cycles \(o.cycles) committed \(o.committed)")
        syntheticLog("E7F rung2 chain \(String(o.chain, radix: 16)) frames \(o.frames.filter { !Match.frameBodies.contains($0.key) }.sorted { $0.key < $1.key }) after \(o.afterFrames.sorted { $0.key < $1.key })")
        syntheticLog("E7F rung2 endGlobals \(o.endGlobals) worldActors \(o.endWorldActors)")
        for body in [o.koBody, o.waitBody] { syntheticLog("E7F rung2 body \(body) \(o.states[body] ?? [])") }
        syntheticLog("E7F rung2 counts characterAI \(c.characterAI) objectInputs \(c.objectInputs) replayedDraws \(c.replayedDraws) rejected \(c.rejectedDraws) skipped \(c.skippedDraws) replayedText \(c.replayedText) epilogues \(c.epilogues) replayFiles \(c.replayFiles) sounds \(o.soundsPerformed) log \(o.log)")

        XCTAssertEqual([o.koBody, o.timerStartBody, o.resultBody, o.waitBody, o.lastBody], Self.pinnedBodies)
        XCTAssertEqual(o.timerStartBody, o.koBody + 1, "the timer starts on the body after the knock-out")
        XCTAssertEqual([o.resultBody - o.timerStartBody, o.waitBody - o.timerStartBody], [100, 143])
        XCTAssertEqual([o.epilogueCycle, o.cycles, o.committed], Self.pinnedCycles)
        XCTAssertEqual(o.menuAfter, Self.pinnedMenuAfter)
        XCTAssertEqual(c.epilogues, 1)
        XCTAssertEqual(String(o.chain, radix: 16), Self.pinnedChain)
        XCTAssertEqual(o.frames.filter { !Match.frameBodies.contains($0.key) }, Self.pinnedResultFrames)
        XCTAssertEqual(o.afterFrames, Self.pinnedAfterFrames)
        // The winner is the computer's team: Independent fighters get their
        // slot + 10 (OriginalMatchPreparation.swift:227), so slot 11's team 21.
        XCTAssertEqual(o.endGlobals, Self.pinnedEndGlobals)
        XCTAssertEqual(o.endWorldActors, Self.pinnedEndWorldAndActors)
        XCTAssertEqual(o.states[o.koBody], Self.pinnedKnockOut)
        XCTAssertEqual(o.states[o.waitBody], Self.pinnedWait)
        XCTAssertEqual([c.characterAI, c.replayedDraws, c.rejectedDraws, c.skippedDraws, o.soundsPerformed], Self.pinnedCounts)
        XCTAssertEqual(o.log, [])
    }
    /// The knock-out, the timer's start, the result (101), the wait (144), the last body.
    static let pinnedBodies = [299, 300, 400, 443, 462]
    /// Loaded cycles: the epilogue's, the last; committed message-loop iterations.
    static let pinnedCycles = [683, 684, 103]
    /// The menu state (0x44d020) after the epilogue (VS's 2, OriginalMatchRound.swift:125)
    /// and one cycle later (1, the character screen).
    static let pinnedMenuAfter: [Int32] = [2, 1]
    static let pinnedChain = "258d758dd90acd2b"
    /// The result screen when drawn first (body 400) and at the wait (443; the world behind it moves on).
    static let pinnedResultFrames = [400: "54b9b75d1eed981312f873dc1d5622aed199213e6db9420262e6cd4cd9f2d2c7",
                                     443: "467de5c0ce6a48e6e77cdc74fefd335705d15919bf6d05a947393218ac23668e"]
    /// FNV-64 of the epilogue's frame and the character screen after it.
    static let pinnedAfterFrames = [683: "f7dd8cec347eb9cc", 684: "925d878b240f923a"]
    /// Winner team 21; 398 ticks (counted while the timer is below 100,
    /// OriginalResultRecording.swift:100); 0x44d02c set at timer 80 (OriginalMatchRound.swift:104);
    /// recording flag cleared after the write (OriginalResultRecording.swift:174);
    /// notice 2, "saved" (:140); timer 144.
    static let pinnedEndGlobals: [Int32] = [21, 398, 1, 0, 2, 144]
    static let pinnedEndWorldAndActors = "822eb86fd67986506c464c0f1eff10742ade0bb3628a7fd8dde7fd0419512f73"
    /// Player 1 falls (180) at -49 HP under the computer's second punch (65).
    static let pinnedKnockOut: [String]? = ["s0 id1 f180 (370,0,344) hp-49 face0", "s11 id3 f65 (433,0,345) hp500 face1",
        "s50 id150 f60 (78,0,403) hp500 face0", "s51 id150 f60 (648,0,412) hp500 face0", "s52 id150 f60 (217,0,388) hp500 face0"]
    /// At the wait player 1 lies (230); items still drop.
    static let pinnedWait: [String]? = ["s0 id1 f230 (306,0,344) hp-49 face0", "s11 id3 f1 (430,0,345) hp500 face1",
        "s50 id150 f60 (78,0,403) hp500 face0", "s51 id150 f60 (648,0,412) hp500 face0", "s52 id150 f60 (217,0,388) hp500 face0",
        "s53 id150 f2 (438,-494,410) hp500 face0"]
    /// Character-AI calls, replayed draws, of them DDERR_INVALIDRECT, skipped draws, DirectSound methods.
    static let pinnedCounts = [464, 54644, 42244, 10982, 62]
}

/// ENGINE_SPLIT E7f, rung 3: the replay the match's end wrote (the writer at
/// timer 101, OriginalResultRecording.swift:107-172; OriginalReplayWriter), into
/// the run's overlay folder in the temporary pack (`recording\` beside the EXE,
/// OriginalMacRuntimeLoading.swift:484-498, 576-580). The file's name is the
/// prelude's local time (OriginalMatchPrelude.swift:57-74); the run supplies
/// GetLocalTime's source as the instant that is 2026-01-01 00:00:00 in the
/// host's zone (`SyntheticRun.localVirtualDate`), so the name is the same on
/// every host and is pinned, and checked against the runtime's own
/// conversion. The file's structure is the engine's: a 4-byte length, then the
/// compressed recording (OriginalReplayFileOutput.swift:91-94), read back here
/// through the engine's playback loader (OriginalReplayFileInput.load).
final class SyntheticReplayWriteTests: XCTestCase {
    typealias Match = SyntheticComputerMatch

    func testMatchEndWritesTheReplay() throws {
        let o = try MainActor.assumeIsolated { try Match.observation(glyphs: false) }
        let file = try XCTUnwrap(o.replays.first)
        syntheticLog("E7F rung3 replays \(o.replays.map { "\($0.path) \($0.bytes.count)" }) folder \(o.recordingFolder.mapValues(\.count)) before \(o.replaysBeforeResult) at \(o.replaysAtResult) refused \(o.refusedReplays) failed \(o.failedReplays) name \(o.preludeName)")
        syntheticLog("E7F rung3 file sha256 \(SyntheticContentPack.digest(file.bytes)) head \(file.bytes.prefix(8).map { String($0, radix: 16) }) playback \(o.playbackStatus) payload \(o.payloadLength ?? -1) inflated \(o.inflatedLength ?? -1) recording \(o.recordingFNV)")
        syntheticLog("E7F rung3 words \(o.recordingWords.sorted { $0.key < $1.key }.map { "\(String($0.key, radix: 16)):\($0.value)" }.joined(separator: " ")) names \(o.recordingNames)")

        // One file, written when the result was recorded, nothing refused or failed.
        XCTAssertEqual([o.replaysBeforeResult, o.replaysAtResult, o.replays.count, o.counts.replayFiles], [0, 1, 1, 1])
        XCTAssertEqual(o.refusedReplays, []); XCTAssertEqual(o.failedReplays, [])
        // The path: `recording\` and the prelude's name, YYYYMMDD_HHMMSS_VS.lfr
        // from the runtime's GetLocalTime of the supplied date.
        XCTAssertEqual(file.path, "recording\\" + o.preludeName)
        XCTAssertEqual(o.preludeName, "20260101_000000_VS.lfr")
        XCTAssertEqual(o.preludeName, MainActor.assumeIsolated { Self.expectedName() })
        XCTAssertEqual(o.recordingFolder.keys.sorted(), [o.preludeName])
        XCTAssertEqual(o.recordingFolder[o.preludeName], file.bytes, "the file on disk is the saved replay")
        // The bytes (host-independent): a 4-byte little-endian length, then that many bytes.
        XCTAssertEqual(file.bytes.count, Self.pinnedFileSize)
        let length = (0..<4).reduce(0) { $0 | Int(file.bytes[$1]) << (8*$1) }
        XCTAssertEqual(length, file.bytes.count - 4)
        XCTAssertEqual(SyntheticContentPack.digest(file.bytes), Self.pinnedFileSHA256)
        // Read back by the engine's playback loader: the 0x630e18-byte recording.
        XCTAssertEqual(o.playbackStatus, 1)
        XCTAssertEqual(o.payloadLength, file.bytes.count - 4)
        XCTAssertEqual(o.inflatedLength, OriginalReplayFileInput.recordingSize)
        XCTAssertEqual(o.recordingFNV, Self.pinnedRecordingFNV)
        XCTAssertEqual(o.recordingWords, Self.pinnedRecordingWords)
        // The players' names: the control file's four (OriginalSettingsLoading.swift:108)
        // and the front menu's digits for the rest (OriginalFrontMenuResources.swift:91).
        XCTAssertEqual(o.recordingNames, ["Ann", "Bo", "Cy", "Di", "5", "6", "7", "8"])
    }
    /// The prelude's name for the run's local date, formatted as
    /// OriginalMatchPrelude.swift:57-74 does ("%4d%02d%02d_%02d%02d%02d", "_VS",
    /// ".lfr") from the runtime's GetLocalTime (OriginalMacRuntimeLoading.swift:414-419).
    @MainActor static func expectedName() -> String {
        let t = OriginalMacRuntimeLoading.localTime(SyntheticRun.localVirtualDate)
        func two(_ v: UInt16) -> String { v < 10 ? "0\(v)" : "\(v)" }
        return "\(t.year)" + two(t.month) + two(t.day) + "_" + two(t.hour) + two(t.minute) + two(t.second) + "_VS.lfr"
    }
    static let pinnedFileSize = 10073
    static let pinnedFileSHA256 = "6e3ee8f20947dab7c03b72bbee237647ec90425a75f116aa20d5bca882204089"
    /// FNV-64 of the 0x630e18-byte recording read back.
    static let pinnedRecordingFNV = "3df0a0ed8a556889"
    /// The recording's words read back: written at the match's start
    /// (OriginalReplayRecording.swift:79-104) and at its end (OriginalResultRecording.swift:107-169).
    static let pinnedRecordingWords: [Int: Int32] = {
        var words: [Int: Int32] = [
            0x0: 0, 0x4: 0,       // difficulty 0x450c30 (0, "Difficult"), stage 0x450b94
            0x148: 0, 0x1a4: 0,   // mode (VS), arena 0x44d024
            0x744: Int32(bitPattern: SyntheticContentPackTests.pinnedCatalogChecksum),   // 0x44f620
            0x748: 0xe7f,         // the version word 0x44d03c, the pack's record word
            0x8c4: 25,            // the random table's index 0x450bcc at the start
            0x10: 2, 0x144: 398,  // results recorded; ticks 0x450bbc
        ]
        // Seats 0-7: participant (1 human, 0 computer, -1 none), Object ID, team,
        // mark (-1 lost; 2 won, standing).
        let seats: [[Int32]] = [[1, 1, 10, -1], [0, 3, 21, 2]] + Array(repeating: [-1, 0, 0, 0], count: 6)
        for (seat, v) in seats.enumerated() {
            for (base, value) in zip([0x14, 0x34, 0x54, 0x114], v) { words[base + 4*seat] = value }
        }
        // The start's slot table, slots 0 and 11: team, Object ID, active.
        for (slot, v): (Int, [Int32]) in [(0, [10, 1, 1]), (11, [21, 3, 1])] {
            for (base, value) in zip([0x1a8, 0x1f0, 0x238], v) { words[base + 4*slot] = value }
        }
        return words
    }()
}
