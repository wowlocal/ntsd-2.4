import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalSettingsLoadingTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-settings-loading"+suffix,
                                                withExtension: "json",subdirectory: "Fixtures"))
        let r = try SettingsLoadingReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,94)
        XCTAssertEqual(r.scans,4371)
        XCTAssertEqual(r.gets,348)
        XCTAssertEqual(r.eof,255)
        XCTAssertEqual(r.returns,93)
        XCTAssertEqual(r.nullFiles,1)
        XCTAssertEqual(r.writes,2310)
        XCTAssertEqual(r.events,7564)
        XCTAssertEqual(r.records,10324)
        XCTAssertEqual(r.front.cases,1)
        XCTAssertEqual(r.front.constructors,24)
    }
    func testSettingsAfterOriginalFrontResources() throws { try compare("") }
    func testSettingsWithReverseResourcesAndRampScratch() throws { try compare("-control") }
}
