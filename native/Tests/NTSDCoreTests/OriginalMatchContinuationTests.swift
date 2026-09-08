import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMatchContinuationTests: XCTestCase {
    func testRemainingMenuThroughOriginalReturnWithAllTeamPatterns() throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try MatchContinuationReference.compare(loaded: fixture("original-loaded-catalog"), parents: [
            fixture("original-match-prelude"), fixture("original-match-prelude-ramp")
        ], corpora: [fixture("original-match-continuation"), fixture("original-match-continuation-ramp")])
        XCTAssertEqual(result.cases, 222)
        XCTAssertEqual(result.randomCalls, 1998)
        XCTAssertEqual(result.constructors, 544)
        XCTAssertEqual(result.bitmaps, 960)
        XCTAssertEqual(result.parent.cases, 50)
    }
}
