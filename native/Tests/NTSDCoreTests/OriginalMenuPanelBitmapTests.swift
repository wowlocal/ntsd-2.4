import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuPanelBitmapTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-menu-panel-bitmap"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try MenuPanelBitmapReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,59)
        XCTAssertEqual(r.sources,3)
        XCTAssertEqual(r.helpers,101)
        XCTAssertEqual(r.constructors,51)
        XCTAssertEqual(r.destructors,50)
        XCTAssertEqual(r.allocations,59)
        XCTAssertEqual(r.nullAllocations,8)
        XCTAssertEqual(r.reused,22)
        XCTAssertEqual(r.events,1406)
        XCTAssertEqual(r.writes,1009)
        XCTAssertEqual(r.releases,37)
        XCTAssertEqual(r.frees,50)
        XCTAssertEqual(r.success,20)
        XCTAssertEqual(r.failure,39)
        XCTAssertEqual(r.records,1437)
        XCTAssertEqual(r.bytes,13768544)
    }
    func testOriginalPanelBitmapReplacement() throws { try compare(false) }
    func testPanelReplacementWithReusedAddressesAndRampBacking() throws { try compare(true) }
}
