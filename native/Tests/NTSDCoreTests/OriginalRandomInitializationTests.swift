import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalRandomInitializationTests: XCTestCase {
    func testCRTGeneratedTablesThroughMatchAndRecording() throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try RandomInitializationReference.compare(loaded: fixture("original-loaded-catalog"), corpora: [
            fixture("original-random-initialization"), fixture("original-random-initialization-ramp")
        ])
        XCTAssertEqual(result.tables, 50)
        XCTAssertEqual(result.seedCalls, 40)
        XCTAssertEqual(result.tableCalls, 150_000)
        XCTAssertEqual(result.interveningCalls, 26_178)
        XCTAssertEqual(result.bytes, 4_614_400)
        XCTAssertEqual(result.match.cases, 50)
        XCTAssertEqual(result.match.replay.buffers, 50)
        XCTAssertEqual(result.match.replay.bytes, 324_583_600)
        XCTAssertEqual(result.match.replay.preparation.cases, 50)
    }
}
