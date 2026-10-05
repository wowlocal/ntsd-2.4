import Foundation
import XCTest
@testable import NTSDCore

/// Records of at least `pagedThreshold` bytes are stored in pages
/// (MOBILE_PERFORMANCE step 3). Reads, writes, errors, equality and copies must
/// match the plain byte/mask arrays the record was built from.
final class OriginalStateRecordPagingTests: XCTestCase {
    private func contents(_ count: Int, seed: UInt64) -> ([UInt8], [Bool]) {
        var x = seed, bytes = [UInt8](repeating: 0, count: count), defined = [Bool](repeating: false, count: count)
        for i in 0..<count {
            x = x &* 6364136223846793005 &+ 1442695040888963407
            bytes[i] = UInt8(truncatingIfNeeded: x >> 33)
            defined[i] = (x >> 61) != 0
        }
        return (bytes, defined)
    }

    private func error(_ body: () throws -> Void) -> String? {
        do { try body(); return nil } catch { return String(describing: error) }
    }

    func testPagedRecordMatchesItsArrays() throws {
        for count in [OriginalStateRecord.pagedThreshold, OriginalStateRecord.pagedThreshold + 1, OriginalReplayRecording.byteCount] {
            var (bytes, defined) = contents(count, seed: UInt64(count))
            var record = try OriginalStateRecord(bytes: bytes, defined: defined)
            XCTAssertEqual(record.byteCount, count)
            XCTAssertEqual(record.bytes, bytes)
            XCTAssertEqual(record.defined, defined)

            // Reads across page boundaries, at the end, and out of range.
            for offset in [0, 0x3ffd, 0x3ffe, 0x3fff, 0x4000, 0x7ffc, count - 8, count - 4, count - 1, count, -1, Int.max] {
                for size in [1, 2, 4, 8] {
                    let read = error {
                        let value: UInt64
                        switch size {
                        case 1: value = UInt64(try record.integer(at: offset, as: UInt8.self))
                        case 2: value = UInt64(try record.integer(at: offset, as: UInt16.self))
                        case 4: value = UInt64(try record.integer(at: offset, as: UInt32.self))
                        default: value = try record.integer(at: offset, as: UInt64.self)
                        }
                        var expected: UInt64 = 0
                        for i in 0..<size { expected |= UInt64(bytes[offset + i]) << (8 * i) }
                        XCTAssertEqual(value, expected, "read \(size) at \(offset) of \(count)")
                    }
                    if offset < 0 || size > count || offset > count - size {
                        XCTAssertEqual(read, String(describing: OriginalStateError.outOfBounds(offset: offset, count: size)))
                    } else if !defined[offset..<offset + size].allSatisfy({ $0 }) {
                        XCTAssertEqual(read, String(describing: OriginalStateError.undefinedBytes(offset: offset, count: size)))
                    } else {
                        XCTAssertNil(read, "read \(size) at \(offset) of \(count)")
                    }
                }
            }

            // A copy keeps its own contents when the original is written.
            let copy = record
            XCTAssertEqual(copy, record)
            try record.write(UInt32(0xa1b2c3d4), at: 0x3ffe)
            for (i, b) in [0xd4, 0xc3, 0xb2, 0xa1].enumerated() { bytes[0x3ffe + i] = UInt8(b); defined[0x3ffe + i] = true }
            try record.write(Int8(-2), at: count - 1)
            bytes[count - 1] = 0xfe; defined[count - 1] = true
            XCTAssertEqual(record.bytes, bytes)
            XCTAssertEqual(record.defined, defined)
            XCTAssertEqual(try record.integer(at: 0x3ffe, as: UInt32.self), 0xa1b2c3d4)
            XCTAssertNotEqual(copy, record)
            XCTAssertEqual(copy.bytes, contents(count, seed: UInt64(count)).0)
            XCTAssertEqual(copy.defined, contents(count, seed: UInt64(count)).1)
            XCTAssertEqual(error { try record.write(UInt16(1), at: count - 1) },
                           String(describing: OriginalStateError.outOfBounds(offset: count - 1, count: 2)))
            XCTAssertEqual(record.bytes, bytes, "a rejected write changes nothing")

            // Equality is by contents: rebuilt records compare equal, and a
            // mask difference alone is a difference.
            XCTAssertEqual(try OriginalStateRecord(bytes: bytes, defined: defined), record)
            var mask = defined
            if let i = mask.firstIndex(of: false) { mask[i] = true }
            XCTAssertNotEqual(try OriginalStateRecord(bytes: bytes, defined: mask), record)
        }
    }

    /// The assembled contents are cached per written version: copies that
    /// share contents share it, a write on either side starts a new one, and
    /// per-index reads stay cheap.
    func testAssembledContentsFollowWrites() throws {
        let count = OriginalReplayRecording.byteCount
        let (bytes, defined) = contents(count, seed: 3)
        let a = try OriginalStateRecord(bytes: bytes, defined: defined)
        XCTAssertEqual(a.bytes, bytes)
        var b = a
        XCTAssertEqual(b.bytes, bytes)
        try b.write(UInt8(bytes[100] &+ 1), at: 100)
        XCTAssertEqual(b.bytes[100], bytes[100] &+ 1)
        XCTAssertTrue(b.defined[100])
        XCTAssertEqual(a.bytes[100], bytes[100])
        XCTAssertEqual(a.defined[100], defined[100])
        var c = b
        try c.write(UInt8(7), at: count - 1)
        XCTAssertEqual(b.bytes[count - 1], bytes[count - 1])
        XCTAssertEqual(c.bytes[count - 1], 7)
        XCTAssertEqual(c.bytes[100], bytes[100] &+ 1)
        var sum = 0
        for i in stride(from: 0, to: count, by: 300) { sum &+= Int(c.bytes[i]) + (c.defined[i] ? 1 : 0) }
        var expected = 0
        for i in stride(from: 0, to: count, by: 300) {
            let byte = i == 100 ? bytes[100] &+ 1 : i == count - 1 ? 7 : bytes[i]
            expected &+= Int(byte) + (i == 100 || i == count - 1 || defined[i] ? 1 : 0)
        }
        XCTAssertEqual(sum, expected)

        // The only holder of a filled cache clears it on write.
        var d = try OriginalStateRecord(bytes: bytes, defined: defined)
        XCTAssertEqual(d.bytes[5], bytes[5])
        try d.write(UInt8(bytes[5] &+ 9), at: 5)
        XCTAssertEqual(d.bytes[5], bytes[5] &+ 9)
        XCTAssertTrue(d.defined[5])

        // Single reads and prefixes match the cached contents.
        let once = c.readOnce()
        XCTAssertEqual(once.bytes, c.bytes)
        XCTAssertEqual(once.defined, c.defined)
        for n in [0, 1, 0x3fff, 0x4000, 0x4001, 11_000, count, count + 5] {
            XCTAssertEqual(c.leadingBytes(n), Array(c.bytes.prefix(n)))
        }
        let small = try OriginalStateRecord(bytes: [1, 2, 3], defined: [true, false, true])
        XCTAssertEqual(small.leadingBytes(2), [1, 2])
        XCTAssertEqual(small.readOnce().defined, [true, false, true])
    }

    func testFlatRecordsBelowTheThreshold() throws {
        let (bytes, defined) = contents(OriginalStateRecord.pagedThreshold - 1, seed: 7)
        let record = try OriginalStateRecord(bytes: bytes, defined: defined)
        XCTAssertEqual(record.byteCount, bytes.count)
        XCTAssertEqual(record.bytes, bytes)
        XCTAssertEqual(record.defined, defined)
    }
}
