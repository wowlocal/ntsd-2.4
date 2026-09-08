import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalInitialLoadingTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try InitialLoadingReference.compare(loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"), sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(result.catalog.catalog.objects,137)
        XCTAssertEqual(result.catalog.catalog.frames,15388)
        XCTAssertEqual(result.catalog.catalog.checksum,31_475_378)
        XCTAssertEqual(result.commonLoads,18)
        XCTAssertEqual(result.catalog.calls,400)
        XCTAssertEqual(result.poolConstructors,408)
        XCTAssertEqual(result.interfaceConstructors,10)
    }
    func testContinuousFirstLoadingFromRealPrologue() throws { try compare("") }
    func testPhaseZeroPauseAndReversedActorAllocations() throws { try compare("-control") }
}
