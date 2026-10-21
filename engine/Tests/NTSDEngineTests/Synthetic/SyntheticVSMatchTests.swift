import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDRuntime

/// ENGINE_SPLIT E7d, rung 3: a VS match on the synthetic pack with scripted
/// keyboard input (the session's `--loaded-script` form): START, VS on the mode
/// screen, two players joining with the pack's first two characters, no
/// computer players, the start; then player 2 walks to player 1's depth and
/// player 1 punches. `bodies` gameplay bodies are run; every presented frame
/// goes into a 64-bit chain, three frames and the World and Actors into
/// SHA-256 digests, and the fighters' state at five bodies is pinned. Globals
/// are not digested: the match prelude writes the replay name from the local
/// time in the host's time zone (OriginalMatchPrelude.swift:57-76; the runtime's
/// GetLocalTime, OriginalMacRuntimeLoading.swift:414-419). (E7f: the run now
/// supplies a date whose local time is the same in every zone,
/// `SyntheticRun.localVirtualDate`; no pin here changed.)
final class SyntheticVSMatchTests: XCTestCase {
    typealias Pack = SyntheticContentPack
    static let bodies = 100

    func testScriptedVSMatch() throws {
        try Pack.withWrittenPack { root, pack in
            try MainActor.assumeIsolated {
                let run = try SyntheticRun(root: root, pack: pack)
                try run.run(limit: 5) { run.committed == 5 }
                try run.clickStart()
                run.scriptVSStart(); run.scriptFight()
                // Up to the match: the launch, then the first gameplay body.
                var launchCycle = -1, steps = 0
                while run.gameplayBodies == 0 && steps < 400 {
                    let stepped = try run.step(); steps += 1
                    if stepped == .loaded(.launched) { launchCycle = run.cycles }
                }
                let firstBodyCycle = run.cycles
                var chain = SyntheticDigest.fnvBasis
                var frames: [Int: String] = [:], states: [Int: [String]] = [:]
                @MainActor func record() throws {
                    let frame = try XCTUnwrap(run.presented())
                    SyntheticDigest.fnv64(frame, into: &chain)
                    let body = run.gameplayBodies
                    if [1, Self.bodies/2, Self.bodies].contains(body) { frames[body] = SyntheticDigest.sha256(frame) }
                    if body % 25 == 0 || body == 1 { states[body] = try run.fighters().map(\.description) }
                }
                try record()
                while run.gameplayBodies < Self.bodies {
                    let before = run.gameplayBodies
                    if case .quit(let code) = try run.step() { throw SyntheticRunError.quit(code) }
                    if run.gameplayBodies > before { try record() }
                }
                let match = try XCTUnwrap(run.match)
                let worldAndActors = SyntheticDigest.records([match.world] + match.actors)
                syntheticLog("E7D rung3 launch \(launchCycle) firstBody \(firstBodyCycle) cycles \(run.cycles) committed \(run.committed) steps \(run.steps)")
                syntheticLog("E7D rung3 chain \(String(chain, radix: 16)) frames \(frames.sorted { $0.key < $1.key }) worldActors \(worldAndActors)")
                for (body, state) in states.sorted(by: { $0.key < $1.key }) { syntheticLog("E7D rung3 body \(body) \(state)") }
                let c = try XCTUnwrap(run.loading).counts
                syntheticLog("E7D rung3 counts objectInputs \(c.objectInputs) characterAI \(c.characterAI) replayedDraws \(c.replayedDraws) skipped \(c.skippedDraws) rejected \(c.rejectedDraws) musicResumes \(c.musicResumes) epilogues \(c.epilogues) sounds performed \(run.sounds.performed) rejected \(run.sounds.rejected) log \(run.log.shown)")

                XCTAssertEqual([launchCycle, firstBodyCycle, run.cycles, run.committed], Self.pinnedClock)
                XCTAssertEqual(String(chain, radix: 16), Self.pinnedChain)
                XCTAssertEqual(frames, Self.pinnedFrames)
                XCTAssertEqual(worldAndActors, Self.pinnedWorldAndActors)
                XCTAssertEqual(states, Self.pinnedStates)
                XCTAssertEqual([c.replayedDraws, c.rejectedDraws, c.skippedDraws, run.sounds.performed], Self.pinnedDrawsAndSounds)
                // VS (mode 0), no character AI (two players, no computers), the replay name's form.
                XCTAssertEqual(try run.global(0x451160), 0)
                XCTAssertEqual(c.characterAI, 0)
                let name = try (0..<40).map { try match.globals.integer(at: 0x44fd98 - OriginalMatchPreparation.globalBase + $0, as: UInt8.self) }
                XCTAssertTrue(String(decoding: name.prefix { $0 != 0 }, as: UTF8.self).hasSuffix("_VS.lfr"))
                XCTAssertEqual(run.log.shown, [])
            }
        }
    }
    /// Loaded cycle of the launch and of the first body; cycles and committed menu iterations at the end.
    static let pinnedClock = [198, 199, 298, 53]
    static let pinnedChain = "71a8e5226a973805"
    static let pinnedFrames = [1: "9a4b1564e4b57cf7a4d8c5fd3fbb19900e03bd97d13a56bddc4ab56fdf081339",
                               50: "86cd2d2a086f59e233faae9036e1d62408ecf97120a0a21d1affba72c6660888",
                               100: "b84f85d1ec9cc101188873a3c8454c82fde82530a1a46d8b87887125befd7cc3"]
    static let pinnedWorldAndActors = "4107931034475b1f93d6ff129ba02a353b5c87c8b8012da6abe44cc3bc0c0998"
    /// Body 1: both landed (219); 25: player 2 walking up; 50: at player 1's depth, an
    /// item (ID 150, seat 50) falling; 75: the item on the ground (60); 100: two punches
    /// have hit player 2 (500 - 2 × 23, 2 HP regained) and knocked it to x 292.
    static let pinnedStates: [Int: [String]] = [
        1: ["s0 id1 f219 (250,0,344) hp500 face0", "s1 id2 f219 (250,0,416) hp500 face0"],
        25: ["s0 id1 f3 (250,0,344) hp500 face0", "s1 id2 f7 (250,0,384) hp500 face0"],
        50: ["s0 id1 f2 (250,0,344) hp500 face0", "s1 id2 f0 (250,0,343) hp500 face0", "s50 id150 f3 (78,-177,403) hp500 face0"],
        75: ["s0 id1 f0 (250,0,344) hp500 face0", "s1 id2 f3 (250,0,343) hp500 face0", "s50 id150 f60 (78,0,403) hp500 face0"],
        100: ["s0 id1 f0 (250,0,344) hp500 face0", "s1 id2 f0 (292,0,343) hp456 face0", "s50 id150 f60 (78,0,403) hp500 face0"]]
    /// Replayed draws, of them DDERR_INVALIDRECT (zero-area or outside the small
    /// synthetic images; the recovered callers ignore the result), skipped
    /// continuation draws, and DirectSound methods performed.
    static let pinnedDrawsAndSounds = [12907, 9108, 4088, 42]
}
