import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMainMenuTests: XCTestCase {
    func testMouseMenuNetworkAndGeneratedMatchState() throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try MainMenuReference.compare(loaded: fixture("original-loaded-catalog"), corpora: [
            fixture("original-main-menu"), fixture("original-main-menu-ramp")
        ])
        XCTAssertEqual(result.probes, 1020)
        XCTAssertEqual(result.mouseMessages, 450)
        XCTAssertEqual(result.bytes, 139_759_680)
        XCTAssertEqual(result.events, 4150)
        XCTAssertEqual(result.tables, 250)
        XCTAssertEqual(result.formats, 46)
        XCTAssertEqual(result.networkFailures, 14)
        XCTAssertEqual(result.initialization.match.cases, 50)
        XCTAssertEqual(result.initialization.match.replay.buffers, 50)
        XCTAssertEqual(result.initialization.match.replay.bytes, 324_583_600)
    }
}
