import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalInitialInterfaceTests: XCTestCase {
    func testInitialInterfaceAfterRealPoolAgainstEXE() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-initial-interface", withExtension: "json", subdirectory: "Fixtures"))
        let result = try InitialInterfaceReference.compare(Data(contentsOf: url))
        XCTAssertEqual(result.cases, 13)
        XCTAssertEqual(result.sources, 10)
        XCTAssertEqual(result.constructors, 114)
        XCTAssertEqual(result.poolConstructors, 5304)
        XCTAssertEqual(result.records, 5470)
        XCTAssertEqual(result.bytes, 13_029_720)
        XCTAssertEqual(result.events, 519)
        XCTAssertEqual(result.nullAllocations, 16)
        XCTAssertEqual(result.messages, 23)
        XCTAssertEqual(result.releases, 12)
    }
}
