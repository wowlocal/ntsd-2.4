import XCTest
@testable import NTSDCore

/// CORE_REALTIME 4s: `rawWord(at:)` is the little-endian value of the four
/// bytes at an offset, defined or not, for flat, parted and paged records, and
/// bitmap draws read the same words and definedness as through `bytes`.
final class OriginalStateRecordRawWordTests: XCTestCase {
    private func contents(_ count: Int, seed: UInt64) -> ([UInt8], [Bool]) {
        var x = seed, bytes = [UInt8](repeating: 0, count: count), defined = [Bool](repeating: false, count: count)
        for i in 0..<count {
            x = x &* 6364136223846793005 &+ 1442695040888963407
            bytes[i] = UInt8(truncatingIfNeeded: x >> 33)
            defined[i] = (x >> 61) != 0
        }
        return (bytes, defined)
    }
    private func word(_ bytes: [UInt8], _ i: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[i + $1]) << ($1 * 8) }
    }

    func testRawWordsMatchTheBytes() throws {
        let (bytes, defined) = contents(0x1f50, seed: 7)
        let flat = try OriginalStateRecord(bytes: bytes, defined: defined)
        XCTAssertTrue(defined.contains(false), "some undefined bytes")
        for i in 0...(0x1f50 - 4) { XCTAssertEqual(flat.rawWord(at: i), word(bytes, i), "flat \(i)") }
        let parted = flat.partitioned(at: [0, 0x100, 0x1000, 0x1f4d])
        XCTAssertTrue(parted.isPartitioned)
        for i in 0...(0x1f50 - 4) { XCTAssertEqual(parted.rawWord(at: i), word(bytes, i), "parted \(i)") }
        let count = OriginalStateRecord.pagedThreshold + 8
        let (large, largeDefined) = contents(count, seed: 9)
        let paged = try OriginalStateRecord(bytes: large, defined: largeDefined)
        // Page boundaries, including the one into the short last page.
        let last = OriginalStateRecord.pagedThreshold
        for i in [0, 1, 0x3ffd, 0x3ffe, 0x3fff, 0x4000, last - 3, last - 2, last - 1, last, count - 5, count - 4] {
            XCTAssertEqual(paged.rawWord(at: i), word(large, i), "paged \(i)")
        }
    }

    func testBitmapWordsReadTheSameValuesAndDefinedness() throws {
        let (bytes, defined) = contents(0x1f50, seed: 11)
        let bitmap = try OriginalStateRecord(bytes: bytes, defined: defined)
        for record in [bitmap, bitmap.partitioned(at: [0, 0x7e0, 0x1780])] {
            for offset in stride(from: 4, through: 0x1f4c, by: 2) {
                var reads: [OriginalBitmapDrawRead] = []
                let value = try OriginalBitmapDrawing.word(UInt32(offset), bitmap: record, surface: 0x1234, observe: { reads.append($0) })
                XCTAssertEqual(value, Int32(bitPattern: word(bytes, offset)))
                XCTAssertEqual(reads, [.init(offset: offset, value: word(bytes, offset), defined: !defined[offset..<offset + 4].contains(false))])
            }
            // The extent check, as before.
            XCTAssertThrowsError(try OriginalBitmapDrawing.word(0x1f4d, bitmap: record, surface: 0, observe: { _ in })) { error in
                XCTAssertEqual("\(error)", "\(OriginalStateError.outOfBounds(offset: 0x1f4d, count: 4))")
            }
        }
        // Offset 0, the surface binding: 1 with a surface or 0 without becomes
        // the surface; anything else throws.
        for (stored, surface, result) in [(UInt32(1), UInt32(0x1234), Int32(0x1234)), (0, 0, 0)] {
            var bound = bitmap
            try bound.write(stored, at: 0)
            var reads: [OriginalBitmapDrawRead] = []
            XCTAssertEqual(try OriginalBitmapDrawing.word(0, bitmap: bound, surface: surface, observe: { reads.append($0) }), result)
            XCTAssertEqual(reads, [.init(offset: 0, value: UInt32(bitPattern: result), defined: true)])
        }
        for (stored, surface) in [(UInt32(0), UInt32(0x1234)), (1, 0), (2, 0x1234)] {
            var bound = bitmap
            try bound.write(stored, at: 0)
            XCTAssertThrowsError(try OriginalBitmapDrawing.word(0, bitmap: bound, surface: surface, observe: { _ in })) { error in
                XCTAssertEqual("\(error)", "\(OriginalStateError.invalidStorage("Bitmap surface binding"))")
            }
        }
        let short = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 0x1f4f), defined: [Bool](repeating: true, count: 0x1f4f))
        XCTAssertThrowsError(try OriginalBitmapDrawing.word(4, bitmap: short, surface: 0, observe: { _ in })) { error in
            XCTAssertEqual("\(error)", "\(OriginalStateError.invalidStorage("Bitmap draw extent"))")
        }
    }
}
