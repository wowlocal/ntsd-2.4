import AppKit
import XCTest
@testable import NTSDMacPlatform
@testable import NTSDRuntime

/// The portable framebuffer becomes exactly the CGImage the display backend
/// built before the split: same bytes, sRGB, 32-bit noneSkipFirst little-endian.
final class OriginalFramebufferTests: XCTestCase {
    func testCGImageKeepsBytesAndFormat() throws {
        var words: [UInt32] = [0x00112233, 0x00445566, 0x00ffffff, 0x00000000, 0x0080ff01, 0x00010203]
        let pixels = Data(bytes: &words, count: words.count * 4)
        let image = try OriginalFramebuffer(width: 3, height: 2, pixels: pixels).cgImage()
        XCTAssertEqual(image.width, 3); XCTAssertEqual(image.height, 2)
        XCTAssertEqual(image.bitsPerComponent, 8); XCTAssertEqual(image.bitsPerPixel, 32); XCTAssertEqual(image.bytesPerRow, 12)
        XCTAssertEqual(image.alphaInfo, .noneSkipFirst)
        XCTAssertEqual(image.bitmapInfo.intersection(.byteOrderMask), .byteOrder32Little)
        XCTAssertEqual(image.colorSpace?.name, CGColorSpace.sRGB)
        XCTAssertFalse(image.shouldInterpolate)
        XCTAssertEqual(image.dataProvider?.data as Data?, pixels)
    }
}
