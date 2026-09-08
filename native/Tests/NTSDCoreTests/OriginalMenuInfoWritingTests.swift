import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuInfoWritingTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-menu-info-writing"+suffix,withExtension: "json",subdirectory: "Fixtures"))
        let r = try MenuInfoWritingReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,267)
        XCTAssertEqual(r.defaults,73)
        XCTAssertEqual(r.caches,194)
        XCTAssertEqual(r.formats,534)
        XCTAssertEqual(r.prints,259)
        XCTAssertEqual(r.closes,259)
        XCTAssertEqual(r.fileWrites,1309)
        XCTAssertEqual(r.failedWrites,74)
        XCTAssertEqual(r.events,3106)
        XCTAssertEqual(r.parentWrites,219)
        XCTAssertEqual(r.records,9462)
        XCTAssertEqual(r.bytes,147664942)
    }
    func testOriginalDefaultAndCacheWriters() throws { try compare(false) }
    func testWritersWithRampBufferAndPartialWrites() throws { try compare(true) }
}
