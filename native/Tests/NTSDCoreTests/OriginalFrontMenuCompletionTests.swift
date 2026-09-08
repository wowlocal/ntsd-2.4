import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalFrontMenuCompletionTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-front-menu-completion"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try FrontMenuCompletionReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,403)
        XCTAssertEqual(r.main,393)
        XCTAssertEqual(r.tails,395)
        XCTAssertEqual(r.worldOne,1)
        XCTAssertEqual(r.errors,7)
        XCTAssertEqual(r.helpers,control ? 3696 : 3300)
        XCTAssertEqual(r.events,control ? 12232 : 9716)
        XCTAssertEqual(r.draws,961)
        XCTAssertEqual(r.reads,control ? 7483 : 5631)
        XCTAssertEqual(r.clips,control ? 1357 : 961)
        XCTAssertEqual(r.blits,control ? 925 : 657)
        XCTAssertEqual(r.tables,39)
        XCTAssertEqual(r.random,117000)
        XCTAssertEqual(r.formats,74)
        XCTAssertEqual(r.frees,1)
        XCTAssertEqual(r.posts,1)
        XCTAssertEqual(r.records,21493)
        XCTAssertEqual(r.bytes,197893536)
        XCTAssertEqual(r.parent.cases,1)
        XCTAssertEqual(r.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.parent.parent.cases,1)
        XCTAssertEqual(r.parent.parent.parent.parent.parent.front.constructors,24)
    }
    func testOriginalMenuReturnAndWorldTransitionWithEarlyResources() throws { try compare(false) }
    func testOriginalMenuReturnWithReverseResourcesAndRampBacking() throws { try compare(true) }
}
