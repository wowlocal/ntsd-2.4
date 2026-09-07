import Foundation
import XCTest
import NTSDReferenceChecks
@testable import NTSDCore

final class OriginalBackgroundTests: XCTestCase {
    func testOriginalBackgroundParsingAndResourceLifecycle() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-backgrounds", withExtension: "json", subdirectory: "Fixtures"))
        let result = try BackgroundReference.compareSuite(Data(contentsOf: url))
        XCTAssertEqual(result.calls, 149)
        XCTAssertEqual(result.parses, 39)
        XCTAssertEqual(result.bitmaps, 673)
        XCTAssertEqual(result.releases, 608)
        XCTAssertEqual(result.bytes, 5_759_520)
    }

    func testFailuresPreserveBackgroundSessionAndLiveLayerReferences() throws {
        let backing = try OriginalStateRecord(bytes: Array(repeating: 0xa5, count: 0x990), defined: Array(repeating: false, count: 0x990))
        let available: (String) -> OriginalBitmapInput = { .init(path: $0, present: true, width: 3, height: 7) }
        var loader = OriginalBackgroundLoader(initialChecksum: 0xffff1234)
        // The shadow succeeds before an unclosed layer aborts parsing. Neither
        // its candidate wrapper nor the partially advanced checksum may escape.
        XCTAssertThrowsError(try loader.parse(decoded: "shadow: shadow.bmp xy: 3 4 layer: a.bmp width: 42", backing: backing, bitmapSource: available))
        XCTAssertTrue(loader.bitmaps.isEmpty)
        XCTAssertEqual(loader.checksum, 0xffff1234)
        var record = try loader.parse(decoded: "layer: a.bmp layer_end layer: b.bmp layer_end", backing: backing, bitmapSource: available)
        let parsed = record
        XCTAssertThrowsError(try loader.loadLayers(in: &record, bitmapSource: { path in
            path == "a.bmp" ? available(path) : .init(path: path, present: false)
        }))
        XCTAssertEqual(record, parsed)
        XCTAssertTrue(loader.bitmaps.isEmpty)
        try loader.loadLayers(in: &record, bitmapSource: available)
        let live = record
        // A malformed second reference must not release the first live surface.
        try record.write(UInt32(0), at: 0x918)
        let malformed = record
        XCTAssertThrowsError(try loader.releaseLayers(in: &record))
        XCTAssertEqual(record, malformed)
        XCTAssertTrue(loader.releasedBitmaps.isEmpty)
        record = live
        XCTAssertEqual(try loader.releaseLayers(in: &record), [0, 1])
    }
}
