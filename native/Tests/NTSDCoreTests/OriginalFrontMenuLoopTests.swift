import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalFrontMenuLoopTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-front-menu-loop"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try FrontMenuLoopReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,119)
        XCTAssertEqual(r.phases,547)
        XCTAssertEqual(r.returns,114)
        XCTAssertEqual(r.boundaries,4)
        XCTAssertEqual(r.loading,1)
        XCTAssertEqual(r.bodies,41)
        XCTAssertEqual(r.main,37)
        XCTAssertEqual(r.tails,113)
        XCTAssertEqual(r.worldOne,1)
        XCTAssertEqual(r.helpers,control ? 2088 : 1857)
        XCTAssertEqual(r.events,control ? 13284 : 11667)
        XCTAssertEqual(r.draws,565)
        XCTAssertEqual(r.reads,control ? 4626 : 3471)
        XCTAssertEqual(r.clips,control ? 796 : 565)
        XCTAssertEqual(r.blits,control ? 774 : 543)
        XCTAssertEqual(r.fills,305)
        XCTAssertEqual(r.constructors,1)
        XCTAssertEqual(r.frees,1)
        XCTAssertEqual(r.tables,5)
        XCTAssertEqual(r.random,15000)
        XCTAssertEqual(r.settings,5)
        XCTAssertEqual(r.settingsReturns,4)
        XCTAssertEqual(r.settingsEvents,262)
        XCTAssertEqual(r.prints,216)
        XCTAssertEqual(r.fileWrites,33)
        XCTAssertEqual(r.failedWrites,1)
        XCTAssertEqual(r.records,20029)
        XCTAssertEqual(r.bytes,188449860)
        XCTAssertEqual(r.parent.cases,1)
        XCTAssertEqual(r.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.parent.cases,1)
    }
    func testRepeatedOriginalEarlyMenuCallsFromOwnFirstReturn() throws { try compare(false) }
    func testRepeatedOriginalEarlyMenuWithReverseResourcesAndRampBacking() throws { try compare(true) }
}
