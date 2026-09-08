import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalFrontMenuResourcesTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-front-menu-resources"+suffix,
                                                withExtension: "json",subdirectory: "Fixtures"))
        let r = try FrontMenuResourcesReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,145)
        XCTAssertEqual(r.sources,23)
        XCTAssertEqual(r.allocations,2151)
        XCTAssertEqual(r.nullAllocations,106)
        XCTAssertEqual(r.constructors,2045)
        XCTAssertEqual(r.events,506213)
        XCTAssertEqual(r.writes,497585)
        XCTAssertEqual(r.settings,72)
        XCTAssertEqual(r.skipped,44)
        XCTAssertEqual(r.nullBitmaps,29)
        XCTAssertEqual(r.records,122263)
        XCTAssertEqual(r.bytes,984711600)
    }
    func testOriginalStartupResources() throws { try compare("") }
    func testStartupResourcesWithReverseAllocationsAndRampBacking() throws { try compare("-control") }
}
