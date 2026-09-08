import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuPresentationTests: XCTestCase {
    func testPresentationReturnAndWorldTransitionThroughMatchRecording() throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try MenuPresentationReference.compare(loaded: fixture("original-loaded-catalog"), corpora: [
            fixture("original-menu-presentation"), fixture("original-menu-presentation-ramp")
        ])
        XCTAssertEqual(result.steps, 1482)
        XCTAssertEqual(result.transitions, 66)
        XCTAssertEqual(result.bytes, 177_955_008)
        XCTAssertEqual(result.events, 5382)
        XCTAssertEqual(result.formats, 184)
        XCTAssertEqual(result.frees, 8)
        XCTAssertEqual(result.quits, 12)
        XCTAssertEqual(result.menu.probes, 1020)
        XCTAssertEqual(result.menu.initialization.match.cases, 50)
        XCTAssertEqual(result.menu.initialization.match.replay.buffers, 50)
        XCTAssertEqual(result.menu.initialization.match.replay.bytes, 324_583_600)
    }
}
