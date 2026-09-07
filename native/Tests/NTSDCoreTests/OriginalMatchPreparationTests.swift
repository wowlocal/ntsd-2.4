import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMatchPreparationTests: XCTestCase {
    func testFullCatalogBootstrapAndChainedMatchPreparation() throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try MatchPreparationReference.compare(loaded: fixture("original-loaded-catalog"), corpora: [
            fixture("original-match-preparation"), fixture("original-match-preparation-ramp")
        ])
        XCTAssertEqual(result.cases, 50)
        XCTAssertEqual(result.records, 52102)
        XCTAssertEqual(result.bytes, 79596336)
        XCTAssertEqual(result.constructors, 19324)
        XCTAssertEqual(result.randomCalls, 720)
        XCTAssertEqual(result.bitmaps, 796)
        XCTAssertEqual(result.releases, 766)
    }
}
