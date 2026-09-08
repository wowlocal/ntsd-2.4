import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalFrontScreenBodyTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-front-screen-body"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try FrontScreenBodyReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,571)
        XCTAssertEqual(r.helpers,4325)
        XCTAssertEqual(r.events,90443)
        XCTAssertEqual(r.texts,1871)
        XCTAssertEqual(r.draws,1196)
        XCTAssertEqual(r.reads,8328)
        XCTAssertEqual(r.clips,1196)
        XCTAssertEqual(r.blits,1152)
        XCTAssertEqual(r.sounds,63)
        XCTAssertEqual(r.shells,19)
        XCTAssertEqual(r.boundaries,1)
        XCTAssertEqual(r.records,15989)
        XCTAssertEqual(r.bytes,142078968)
        XCTAssertEqual(r.parent.cases,1)
        XCTAssertEqual(r.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.parent.front.constructors,24)
    }
    func testScreenBodyAfterFreshOriginalPanelUpdate() throws { try compare(false) }
    func testScreenBodyWithReverseResourcesAndRampBacking() throws { try compare(true) }
}
