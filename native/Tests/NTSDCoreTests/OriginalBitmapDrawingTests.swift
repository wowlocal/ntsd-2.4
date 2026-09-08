import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalBitmapDrawingTests: XCTestCase {
    func testOriginalBitmapDrawingAndClipping() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-bitmap-drawing",withExtension: "json",subdirectory: "Fixtures"))
        let r = try BitmapDrawingReference.compare(Data(contentsOf: url))
        XCTAssertEqual(r.cases,3971)
        XCTAssertEqual(r.setups,96)
        XCTAssertEqual(r.sources,34)
        XCTAssertEqual(r.constructors,76)
        XCTAssertEqual(r.reads,21475)
        XCTAssertEqual(r.undefinedReads,9055)
        XCTAssertEqual(r.clips,3330)
        XCTAssertEqual(r.blits,2297)
        XCTAssertEqual(r.dualBlits,198)
        XCTAssertEqual(r.boundaries,20)
    }
}
