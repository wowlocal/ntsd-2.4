import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalReceivedInputTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try ReceivedInputReference.compare(received: fixture("original-received-input"),local: fixture("original-local-input"),
            loading: fixture("original-initial-loading"),catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.local.initial.catalog.catalog.objects,137)
        XCTAssertEqual(r.local.initial.catalog.catalog.checksum,31_475_378)
        XCTAssertEqual(r.local.cases,303)
        XCTAssertEqual(r.cases,726)
        XCTAssertEqual(r.continuous,suffix.isEmpty ? 1 : 0)
        XCTAssertGreaterThan(r.remoteCalls,256)
        XCTAssertGreaterThan(r.playbackCalls,256)
    }
    func testReceivedInputAfterNaturalLocalInput() throws { try compare("") }
    func testPhaseZeroCallerBoundaryAndAliasedReversedPool() throws { try compare("-control") }
}
