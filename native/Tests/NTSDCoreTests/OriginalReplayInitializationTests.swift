import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalReplayInitializationTests: XCTestCase {
    func testRecordingInitializationAfterRealCatalogAndMatchPreparation() throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try ReplayInitializationReference.compare(loaded: fixture("original-loaded-catalog"), corpora: [
            fixture("original-replay-initialization"), fixture("original-replay-initialization-ramp")
        ])
        XCTAssertEqual(result.buffers, 50)
        XCTAssertEqual(result.bytes, 324583600)
        XCTAssertEqual(result.allocations, 50)
        XCTAssertEqual(result.releases, 50)
        XCTAssertEqual(result.preparation.cases, 50)
        XCTAssertEqual(result.preparation.records, 77252)
        XCTAssertEqual(result.preparation.bytes, 115486336)
    }
}
