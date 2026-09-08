import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalFrontScreenAlternateTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-front-screen-alternate"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try FrontScreenAlternateReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,533)
        XCTAssertEqual(r.helpers,3421)
        XCTAssertEqual(r.events,15955)
        XCTAssertEqual(r.settingsEvents,5552)
        XCTAssertEqual(r.draws,1250)
        XCTAssertEqual(r.reads,8682)
        XCTAssertEqual(r.clips,1247)
        XCTAssertEqual(r.blits,1200)
        XCTAssertEqual(r.fills,674)
        XCTAssertEqual(r.sounds,85)
        XCTAssertEqual(r.timers,512)
        XCTAssertEqual(r.workers,13)
        XCTAssertEqual(r.settings,82)
        XCTAssertEqual(r.settingsReturns,74)
        XCTAssertEqual(r.prints,3996)
        XCTAssertEqual(r.fileWrites,1326)
        XCTAssertEqual(r.failedWrites,18)
        XCTAssertEqual(r.boundaries,12)
        XCTAssertEqual(r.records,31828)
        XCTAssertEqual(r.bytes,394472552)
        XCTAssertEqual(r.parent.cases,1)
        XCTAssertEqual(r.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.parent.parent.front.constructors,24)
    }
    func testOriginalAlternateScreensWithFreshParentsAndChildren() throws { try compare(false) }
    func testOriginalAlternateScreensWithReverseResourcesAndRampBacking() throws { try compare(true) }
}
