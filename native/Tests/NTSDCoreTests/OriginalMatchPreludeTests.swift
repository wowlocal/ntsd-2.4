import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMatchPreludeTests: XCTestCase {
    func testConfirmedMenuPreludeThroughPreparationAndRecording() throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try MatchPreludeReference.compare(loaded: fixture("original-loaded-catalog"), corpora: [
            fixture("original-match-prelude"), fixture("original-match-prelude-ramp")
        ])
        XCTAssertEqual(result.cases, 50)
        XCTAssertEqual(result.bytes, 4_614_400)
        XCTAssertEqual(result.formatCalls, 130)
        XCTAssertEqual(result.soundCalls, 60)
        XCTAssertEqual(result.fills, 10)
        XCTAssertEqual(result.replay.buffers, 50)
        XCTAssertEqual(result.replay.bytes, 324_583_600)
        XCTAssertEqual(result.replay.allocations, 50)
        XCTAssertEqual(result.replay.releases, 50)
        XCTAssertEqual(result.replay.preparation.cases, 50)
    }
}
