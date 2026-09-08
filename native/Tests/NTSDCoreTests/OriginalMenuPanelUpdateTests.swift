import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuPanelUpdateTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-menu-panel-update"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try MenuPanelUpdateReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,133)
        XCTAssertEqual(r.content,166)
        XCTAssertEqual(r.bitmaps,59)
        XCTAssertEqual(r.defaults,65)
        XCTAssertEqual(r.caches,125)
        XCTAssertEqual(r.returns,414)
        XCTAssertEqual(r.constructors,47)
        XCTAssertEqual(r.destructors,46)
        XCTAssertEqual(r.events,1926)
        XCTAssertEqual(r.childEvents,17380)
        XCTAssertEqual(r.boundaries,1)
        XCTAssertEqual(r.records,21578)
        XCTAssertEqual(r.bytes,367220837)
        XCTAssertEqual(r.parent.cases,1)
        XCTAssertEqual(r.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.front.constructors,24)
    }
    func testCompletePanelUpdateAfterFreshScreenPrefix() throws { try compare(false) }
    func testPanelUpdateWithReverseResourcesAndRampBacking() throws { try compare(true) }
}
