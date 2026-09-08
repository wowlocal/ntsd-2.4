import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalInputControlTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try InputControlReference.compare(control: fixture("original-input-control"),local: fixture("original-local-input"),
            loading: fixture("original-initial-loading"),catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.cases,2993)
        XCTAssertEqual(r.local.cases,303)
        XCTAssertEqual(r.local.initial.catalog.catalog.objects,137)
        XCTAssertGreaterThan(r.actions,5000)
        XCTAssertGreaterThan(r.sends,400)
        XCTAssertGreaterThan(r.receives,r.sends)
        XCTAssertGreaterThan(r.messages,0)
        XCTAssertGreaterThan(r.restores,0)
        XCTAssertGreaterThan(r.resets,0)
    }
    func testOriginalControlAndReceivedInputAfterFirstLoading() throws { try compare("") }
    func testOriginalControlWithReversePoolAndPlaybackBacking() throws { try compare("-control") }
}
