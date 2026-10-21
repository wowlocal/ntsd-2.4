#if canImport(Darwin)
import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDRuntime

/// ENGINE_SPLIT E7c, second rung: the synthetic music package through the
/// silent player's loader (`OriginalMacMusicOutput.silent`, the headless and
/// SDL hosts' music). Darwin only for now: it is the only main-actor test
/// outside Mac/, and the Linux XCTest run of a @MainActor case is not yet
/// established here.
@MainActor final class SyntheticContentPackMusicTests: XCTestCase {
    func testMusicPackageResolvesTheEngineTracksAndEndsOnItsFrameCount() throws {
        try SyntheticContentPack.withWrittenPack { root, _ in
            let output = try OriginalMacMusicOutput.silent(directory: root.appendingPathComponent(SyntheticContentPack.music))
            var now = 0.0
            output.virtualSeconds = { now }
            // bgm\main.wma: 8000 frames at 16 kHz, half a second.
            let main = OriginalMacRuntimeMusic.Presented(graph: 1, file: Array("bgm\\main.wma".utf8), running: true, volume: 0, seeks: 0, position: 0)
            try output.present(main)
            XCTAssertEqual(output.state?.track, "bgm\\main.wma")
            XCTAssertEqual(output.unresolved, [])
            now = 0.4; try output.present(main)
            XCTAssertNil(output.takeEnded())
            now = 0.6; try output.present(main)
            XCTAssertEqual(output.takeEnded(), 1)
            // A name the pack does not hold stays unresolved.
            try output.present(.init(graph: 2, file: Array("bgm\\other.wma".utf8), running: true, volume: 0, seeks: 0, position: 0))
            XCTAssertEqual(output.unresolved, [Array("bgm\\other.wma".utf8)])
        }
    }
}
#endif
