import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalLocalInputTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try LocalInputReference.compare(input: fixture("original-local-input"),loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.initial.catalog.catalog.objects,137)
        XCTAssertEqual(r.initial.catalog.catalog.checksum,31_475_378)
        XCTAssertEqual(r.cases,303)
        XCTAssertGreaterThan(r.characterAI,0)
        XCTAssertGreaterThan(r.objectInput,0)
    }
    func testLocalInputAfterContinuousFirstLoading() throws { try compare("") }
    func testPausedFirstInputAndReversedActorStorage() throws { try compare("-control") }
}
