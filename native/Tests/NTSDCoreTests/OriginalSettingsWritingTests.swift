import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalSettingsWritingTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-settings-writing"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try SettingsWritingReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,226)
        XCTAssertEqual(r.returns,221)
        XCTAssertEqual(r.nullFiles,4)
        XCTAssertEqual(r.stringBoundaries,1)
        XCTAssertEqual(r.prints,11982)
        XCTAssertEqual(r.closes,221)
        XCTAssertEqual(r.fileWrites,36813)
        XCTAssertEqual(r.failedWrites,54)
        XCTAssertEqual(r.events,53533)
        XCTAssertEqual(r.parentWrites,4070)
        XCTAssertEqual(r.records,149067)
        XCTAssertEqual(r.bytes,2307985161)
    }
    func testOriginalSettingsWriterAndSharedPrintf() throws { try compare(false) }
    func testSettingsWriterWithRampOutputBacking() throws { try compare(true) }
}
