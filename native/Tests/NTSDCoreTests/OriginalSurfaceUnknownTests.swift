import XCTest
@testable import NTSDCore

/// MEMORY_LOADING L9: a new surface's colours stay implicit (every pixel
/// unknown on zero backing) until read or partly written; it reads, compares
/// and takes writes exactly as the zeroed arrays it replaced.
final class OriginalSurfaceUnknownTests: XCTestCase {
    func testAnUntouchedSurfaceIsAllUnknownOnZeroBacking() throws {
        let fresh = try OriginalSurfaceSourceColors(width: 3, height: 2)
        XCTAssertEqual(fresh.rgb, [UInt8](repeating: 0, count: 18)); XCTAssertEqual(fresh.defined, [Bool](repeating: false, count: 6))
        XCTAssertEqual(fresh, try OriginalSurfaceSourceColors(width: 3, height: 2))
        XCTAssertNotEqual(fresh, try OriginalSurfaceSourceColors(width: 2, height: 3))
        XCTAssertThrowsError(try fresh.color(x: 1, y: 1)) { XCTAssertEqual($0 as? OriginalSurfaceSourceColors.Boundary, .undefinedPixel) }
        XCTAssertThrowsError(try fresh.color(x: 3, y: 0)) { XCTAssertEqual($0 as? OriginalSurfaceSourceColors.Boundary, .rectangle) }
        XCTAssertThrowsError(try OriginalSurfaceSourceColors(width: 0, height: 2)) { XCTAssertEqual($0 as? OriginalSurfaceSourceColors.Boundary, .extent) }
        XCTAssertThrowsError(try OriginalSurfaceSourceColors(width: 5000, height: 5000)) { XCTAssertEqual($0 as? OriginalSurfaceSourceColors.Boundary, .pixelLimit) }
        // Invalidating every pixel of a written surface gives the untouched value.
        var source = try OriginalSurfaceSourceColors(width: 3, height: 2)
        let pixels = try OriginalDIBPixels(dib: Self.dib(width: 2, height: 1, rgb: [[1, 2, 3], [4, 5, 6]]))
        try source.copy(pixels, width: 2, height: 1, x: 1, y: 1)
        XCTAssertEqual(try source.color(x: 1, y: 1), [1, 2, 3]); XCTAssertEqual(try source.color(x: 2, y: 1), [4, 5, 6])
        XCTAssertThrowsError(try source.color(x: 0, y: 0))
        XCTAssertEqual(source.rgb, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(source.defined, [false, false, false, false, true, true])
        XCTAssertNotEqual(source, fresh)
        try source.invalidate(x: 0, y: 0, width: 3, height: 2)
        XCTAssertEqual(source, fresh); XCTAssertEqual(fresh, source)
    }

    /// A 24-bit DIB, rows bottom-up, BGR.
    static func dib(width: Int, height: Int, rgb: [[UInt8]]) -> [UInt8] {
        let stride = (width * 3 + 3) / 4 * 4
        var bytes = [UInt8](repeating: 0, count: 40 + stride * height)
        func put(_ value: UInt32, _ at: Int) { for i in 0..<4 { bytes[at + i] = UInt8(truncatingIfNeeded: value >> (8 * UInt32(i))) } }
        put(40, 0); put(UInt32(width), 4); put(UInt32(height), 8); bytes[12] = 1; bytes[14] = 24
        for row in 0..<height { for x in 0..<width {
            let c = rgb[(height - 1 - row) * width + x], at = 40 + row * stride + x * 3
            bytes[at] = c[2]; bytes[at + 1] = c[1]; bytes[at + 2] = c[0]
        } }
        return bytes
    }
}
