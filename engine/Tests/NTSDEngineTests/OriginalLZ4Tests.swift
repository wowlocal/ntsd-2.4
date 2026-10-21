import XCTest
@testable import NTSDCore

/// MEMORY_LOADING M1: bitmap bytes kept compressed must read back exactly.
/// ENGINE_SPLIT E4c-2: the synthetic half of native's OriginalLZ4Tests; the content-reading tests stay there.
final class OriginalLZ4Tests: XCTestCase {
    struct Generator: RandomNumberGenerator {
        var state: UInt64
        // splitmix64: every output bit mixed (an LCG's low byte repeats every 256 values).
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }
    func roundTrip(_ bytes: [UInt8], _ label: @autoclosure () -> String) throws {
        let packed = bytes.withUnsafeBytes { OriginalLZ4.compress($0) }
        XCTAssertEqual(try OriginalLZ4.decompress(packed, count: bytes.count), bytes, label())
    }

    func testEveryShapeOfInputReadsBackExactly() throws {
        var random = Generator(state: 7)
        for length in 0...300 {
            try roundTrip((0..<length).map { _ in UInt8.random(in: 0...255, using: &random) }, "random \(length)")
            try roundTrip([UInt8](repeating: UInt8(length & 255), count: length), "run \(length)")
            try roundTrip((0..<length).map { UInt8(($0 % 3) * 40) }, "pixels \(length)")
        }
        // Sprite-like rows: a keyed background with sprites, repeated rows, noise.
        var sheet: [UInt8] = []
        for row in 0..<300 {
            for x in 0..<400 {
                let sprite = (x / 80 + row / 60) % 2 == 0 && (x % 80) > 10 && (x % 80) < 70
                if sprite { sheet += [UInt8(x & 255), UInt8(row & 255), UInt8.random(in: 0...3, using: &random)] } else { sheet += [0, 0, 0] }
            }
        }
        try roundTrip(sheet, "sheet")
        let packed = sheet.withUnsafeBytes { OriginalLZ4.compress($0) }
        XCTAssertLessThan(packed.count, sheet.count / 2)
        try roundTrip((0..<300_000).map { _ in UInt8.random(in: 0...255, using: &random) }, "incompressible")
        try roundTrip([UInt8](repeating: 9, count: 1_000_003), "long run")
    }

    func testDamagedDataIsRejectedNotRead() throws {
        let bytes = (0..<5000).map { UInt8(($0 / 7) & 255) }
        let packed = bytes.withUnsafeBytes { OriginalLZ4.compress($0) }
        XCTAssertThrowsError(try OriginalLZ4.decompress(Array(packed.dropLast()), count: bytes.count))
        XCTAssertThrowsError(try OriginalLZ4.decompress(packed, count: bytes.count + 1))
        XCTAssertThrowsError(try OriginalLZ4.decompress(packed, count: bytes.count - 1))
        XCTAssertThrowsError(try OriginalLZ4.decompress([0x0f, 0x00, 0x00], count: 100))   // a match length extension cut off
        XCTAssertThrowsError(try OriginalLZ4.decompress([0x10, 0x41, 0x00, 0x00], count: 5))   // offset 0
        XCTAssertThrowsError(try OriginalLZ4.decompress([0x10, 0x41, 0x05, 0x00], count: 20))   // offset beyond the output
        XCTAssertThrowsError(try OriginalLZ4.decompress([0x10, 0x41, 0x01], count: 20))   // offset cut off
        XCTAssertThrowsError(try OriginalLZ4.decompress([0x1f, 0x41, 0x01, 0x00, 0x10], count: 10))   // match past the output
        XCTAssertThrowsError(try OriginalLZ4.decompress([], count: 0))
        // The largest offset reaches back 65535 bytes.
        var far = [UInt8](repeating: 0, count: 70_000)
        for i in 0..<16 { far[i] = UInt8(i + 1); far[65535 + i] = UInt8(i + 1) }
        for i in 16..<65535 { far[i] = UInt8(truncatingIfNeeded: i &* 2654435761 >> 13) }
        try roundTrip(far, "offset 65535")
    }

    func testBitmapBytesCompressLargeImagesOnlyWhenSmaller() {
        let small = [UInt8](repeating: 7, count: OriginalBitmapBytes.threshold - 1)
        let large = [UInt8](repeating: 7, count: OriginalBitmapBytes.threshold)
        var random = Generator(state: 3)
        let noise = (0..<OriginalBitmapBytes.threshold * 2).map { _ in UInt8.random(in: 0...255, using: &random) }
        XCTAssertFalse(OriginalBitmapBytes(small).isCompressed); XCTAssertEqual(OriginalBitmapBytes(small).dib, small)
        XCTAssertTrue(OriginalBitmapBytes(large).isCompressed); XCTAssertEqual(OriginalBitmapBytes(large).dib, large)
        // A compressed image holds about its compressed size, not the buffer the compressor reserved (M3).
        let packedCount = large.withUnsafeBytes { OriginalLZ4.compress($0) }.count
        XCTAssertLessThanOrEqual(OriginalBitmapBytes(large).heldCapacity, packedCount + packedCount / 8 + 64)
        XCTAssertLessThan(packedCount + packedCount / 8 + 64, large.count / 8)
        XCTAssertFalse(OriginalBitmapBytes(noise).isCompressed); XCTAssertEqual(OriginalBitmapBytes(noise).dib, noise)
    }

    func testBitmapEqualityComparesEveryField() throws {
        func file(width: Int32, pixel: UInt8) -> [UInt8] {
            let stride = (Int(width) * 3 + 3) / 4 * 4, size = 54 + stride * 300
            var b = [UInt8](repeating: pixel, count: size)
            func put(_ v: UInt32, _ at: Int) { for i in 0..<4 { b[at + i] = UInt8(truncatingIfNeeded: v >> (8 * UInt32(i))) } }
            b[0] = 0x42; b[1] = 0x4d; put(UInt32(size), 2); put(0, 6); put(54, 10); put(40, 14); put(UInt32(width), 18); put(300, 22)
            b[26] = 1; b[27] = 0; b[28] = 24; b[29] = 0; put(0, 30); put(0, 34); put(0, 46)
            return b
        }
        let a = try OriginalApplicationStartupInputs.Bitmap(bitmapFile: file(width: 300, pixel: 1))
        XCTAssertEqual(a, try OriginalApplicationStartupInputs.Bitmap(bitmapFile: file(width: 300, pixel: 1)))
        XCTAssertNotEqual(a, try OriginalApplicationStartupInputs.Bitmap(bitmapFile: file(width: 300, pixel: 2)))   // bytes
        XCTAssertNotEqual(a, try OriginalApplicationStartupInputs.Bitmap(bitmapFile: file(width: 299, pixel: 1)))   // fields
        XCTAssertNotEqual(a, try OriginalApplicationStartupInputs.Bitmap(dib: Array(file(width: 300, pixel: 1).dropFirst(14))))   // header, offset
    }
}
