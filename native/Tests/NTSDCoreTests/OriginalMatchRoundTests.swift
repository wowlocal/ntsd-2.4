import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMatchRoundTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try MatchRoundReference.compare(round: fixture("original-match-round"),replay: fixture("original-replay-tick"),
            control: fixture("original-input-control"),local: fixture("original-local-input"),loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.cases,2074)
        XCTAssertEqual(r.parent.cases,1134)
        XCTAssertEqual(r.parent.parent.cases,2993)
        XCTAssertEqual(r.parent.parent.local.cases,303)
        XCTAssertEqual(r.constructors,45)
        XCTAssertEqual(r.teams,suffix.isEmpty ? 1746 : 1745)
        XCTAssertEqual(r.stages,240)
        XCTAssertEqual(r.events,suffix.isEmpty ? 3388 : 3387)
        XCTAssertEqual(r.continuations["epilogue"],457)
        XCTAssertEqual(r.continuations["gameplay"],1180)
    }
    func testRoundControlAfterOriginalLoadingAndReplay() throws { try compare("") }
    func testRoundControlWithReversePoolAndRampStorage() throws { try compare("-control") }
}
