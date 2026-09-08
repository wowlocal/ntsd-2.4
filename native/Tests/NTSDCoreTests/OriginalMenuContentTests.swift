import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuContentTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-menu-content"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try MenuContentReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,352)
        XCTAssertEqual(r.formats,704)
        XCTAssertEqual(r.gets,8499)
        XCTAssertEqual(r.scans,control ? 8499 : 8493)
        XCTAssertEqual(r.events,control ? 58237 : 58225)
        XCTAssertEqual(r.writes,39833)
        XCTAssertEqual(r.success,32)
        XCTAssertEqual(r.failure,control ? 320 : 314)
        XCTAssertEqual(r.boundaries,control ? 0 : 6)
        XCTAssertEqual(r.records,control ? 36108 : 36096)
        XCTAssertEqual(r.bytes,control ? 853015392 : 852731904)
    }
    func testOriginalMissingFilesAndControlledContent() throws { try compare(false) }
    func testContentWithRampScratchAndPersistentGlobals() throws { try compare(true) }
}
