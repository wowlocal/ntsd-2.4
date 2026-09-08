import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalFrontScreenPreludeTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-front-screen-prelude"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try FrontScreenPreludeReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,178)
        XCTAssertEqual(r.sources,13)
        XCTAssertEqual(r.helpers,control ? 882 : 707)
        XCTAssertEqual(r.events,control ? 3171 : 1972)
        XCTAssertEqual(r.fills,177)
        XCTAssertEqual(r.draws,177)
        XCTAssertEqual(r.blits,control ? 318 : 156)
        XCTAssertEqual(r.reads,control ? 1721 : 859)
        XCTAssertEqual(r.undefinedReads,control ? 1061 : 361)
        XCTAssertEqual(r.clips,control ? 351 : 176)
        XCTAssertEqual(r.constructors,32)
        XCTAssertEqual(r.formats,33)
        XCTAssertEqual(r.threads,13)
        XCTAssertEqual(r.boundaries,3)
        XCTAssertEqual(r.records,7491)
        XCTAssertEqual(r.bytes,65803344)
        XCTAssertEqual(r.parent.cases,1)
        XCTAssertEqual(r.parent.front.constructors,24)
    }
    func testScreenPrefixAfterOriginalSettings() throws { try compare(false) }
    func testScreenPrefixWithReverseResourcesAndRampBacking() throws { try compare(true) }
}
