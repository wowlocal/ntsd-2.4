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

    /// overwrite(at:with:) equals rebuilding the record from arrays with the
    /// subrange replaced, for flat and paged records, and leaves copies alone.
    func testOverwriteEqualsRebuilding() throws {
        for count in [0xc3a8, OriginalReplayRecording.byteCount] {
            let (bytes, defined) = contents(count, seed: UInt64(count) ^ 0x55)
            let (pieceBytes, pieceDefined) = contents(0x7d8, seed: 9)
            let piece = try OriginalStateRecord(bytes: pieceBytes, defined: pieceDefined)
            for start in [0, 0x3f00, count - 0x7d8] {
                var record = try OriginalStateRecord(bytes: bytes, defined: defined)
                let copy = record
                record.overwrite(at: start, with: piece)
                var b = bytes, d = defined
                b.replaceSubrange(start..<start + 0x7d8, with: pieceBytes)
                d.replaceSubrange(start..<start + 0x7d8, with: pieceDefined)
                XCTAssertEqual(record, try OriginalStateRecord(bytes: b, defined: d), "count \(count) start \(start)")
                XCTAssertEqual(record.bytes, b)
                XCTAssertEqual(record.defined, d)
                XCTAssertEqual(copy.bytes, bytes, "a copy keeps its contents")
                XCTAssertEqual(copy.defined, defined)
                XCTAssertEqual(copy, try OriginalStateRecord(bytes: bytes, defined: defined))
            }
            // A sole holder whose assembled contents were read first (State.replace
            // reads full.bytes in its guard), an empty piece, and a whole-size piece.
            var sole = try OriginalStateRecord(bytes: bytes, defined: defined)
            XCTAssertEqual(sole.bytes.count, count)
            sole.overwrite(at: 5, with: piece)
            var b = bytes, d = defined
            b.replaceSubrange(5..<5 + 0x7d8, with: pieceBytes); d.replaceSubrange(5..<5 + 0x7d8, with: pieceDefined)
            XCTAssertEqual(sole.bytes, b)
            XCTAssertEqual(sole.defined, d)
            let empty = try OriginalStateRecord(bytes: [], defined: [])
            sole.overwrite(at: count, with: empty)
            XCTAssertEqual(sole.bytes, b)
            let (wholeBytes, wholeDefined) = contents(count, seed: 11)
            sole.overwrite(at: 0, with: try OriginalStateRecord(bytes: wholeBytes, defined: wholeDefined))
            XCTAssertEqual(sole.bytes, wholeBytes)
            XCTAssertEqual(sole.defined, wholeDefined)
            XCTAssertEqual(sole, try OriginalStateRecord(bytes: wholeBytes, defined: wholeDefined))
        }
    }

    /// Writes and overwrites that store what is already there return early
    /// (CORE_REALTIME phase 2d): matching but undefined bytes still become
    /// defined, a matching mask difference is still written, and copies that
    /// share storage stay equal and independent.
    func testUnchangingWritesKeepContentsAndDefinedness() throws {
        let count = 0xc3a8
        var (bytes, defined) = contents(count, seed: 21)
        for i in 0x100..<0x104 { defined[i] = false }
        var record = try OriginalStateRecord(bytes: bytes, defined: defined)
        let value = UInt32(bytes[0x100]) | UInt32(bytes[0x101]) << 8 | UInt32(bytes[0x102]) << 16 | UInt32(bytes[0x103]) << 24
        try record.write(value, at: 0x100)
        for i in 0x100..<0x104 { defined[i] = true }
        XCTAssertEqual(record.defined, defined, "matching undefined bytes become defined")
        XCTAssertEqual(record, try OriginalStateRecord(bytes: bytes, defined: defined))

        let copy = record
        try record.write(value, at: 0x100)
        XCTAssertEqual(record, copy)
        XCTAssertEqual(try record.integer(at: 0x100, as: UInt32.self), value)
        try record.write(UInt8(bytes[0x200] &+ 1), at: 0x200)
        XCTAssertNotEqual(record, copy)
        XCTAssertEqual(copy.bytes, bytes, "a later change leaves the copy alone")
        XCTAssertEqual(copy.defined, defined)
        XCTAssertEqual(error { try record.write(UInt16(1), at: count - 1) },
                       String(describing: OriginalStateError.outOfBounds(offset: count - 1, count: 2)))

        let pieceBytes = Array(bytes[0x300..<0x308])
        var pieceDefined = Array(defined[0x300..<0x308])
        pieceDefined[2].toggle()
        var target = try OriginalStateRecord(bytes: bytes, defined: defined)
        let original = target
        target.overwrite(at: 0x300, with: try OriginalStateRecord(bytes: pieceBytes, defined: pieceDefined))
        var expected = defined
        expected[0x302].toggle()
        XCTAssertEqual(target.bytes, bytes)
        XCTAssertEqual(target.defined, expected, "the same bytes with another mask update the mask")
        XCTAssertEqual(original.defined, defined)

        let before = target
        target.overwrite(at: 0x300, with: try OriginalStateRecord(bytes: pieceBytes, defined: pieceDefined))
        XCTAssertEqual(target, before)
        XCTAssertEqual(target.defined, expected)
        target.overwrite(at: count, with: try OriginalStateRecord(bytes: [], defined: []))
        XCTAssertEqual(target, before)
    }

    /// Flat records read through their buffers (CORE_REALTIME phase 4c):
    /// values, signed types and errors at every edge equal the plain arrays.
    func testFlatReadsMatchTheirArrays() throws {
        let count = 0xc3a8
        let (bytes, mask) = contents(count, seed: 33)
        var defined = mask
        for i in 0x40..<0x48 { defined[i] = true }
        defined[0x44] = false
        for i in 0x80..<0x88 { defined[i] = true }
        let record = try OriginalStateRecord(bytes: bytes, defined: defined)
        func expected(_ offset: Int, _ size: Int) -> UInt64 {
            var v: UInt64 = 0
            for i in 0..<size { v |= UInt64(bytes[offset + i]) << (8 * i) }
            return v
        }
        for offset in [0, 1, 0x3f, 0x40, 0x41, 0x43, 0x44, 0x45, count - 8, count - 4, count - 2, count - 1, count, -1, Int.max] {
            for size in [1, 2, 4, 8] {
                let outcome = error {
                    let value: UInt64, signed: Int64
                    switch size {
                    case 1: value = UInt64(try record.integer(at: offset, as: UInt8.self)); signed = Int64(try record.integer(at: offset, as: Int8.self))
                    case 2: value = UInt64(try record.integer(at: offset, as: UInt16.self)); signed = Int64(try record.integer(at: offset, as: Int16.self))
                    case 4: value = UInt64(try record.integer(at: offset, as: UInt32.self)); signed = Int64(try record.integer(at: offset, as: Int32.self))
                    default: value = try record.integer(at: offset, as: UInt64.self); signed = try record.integer(at: offset, as: Int64.self)
                    }
                    XCTAssertEqual(value, expected(offset, size), "read \(size) at \(offset)")
                    let shift = UInt64(64 - 8 * size)
                    XCTAssertEqual(signed, Int64(bitPattern: expected(offset, size) << shift) >> Int64(shift), "signed \(size) at \(offset)")
                }
                if offset < 0 || size > count || offset > count - size {
                    XCTAssertEqual(outcome, String(describing: OriginalStateError.outOfBounds(offset: offset, count: size)))
                } else if !defined[offset..<offset + size].allSatisfy({ $0 }) {
                    XCTAssertEqual(outcome, String(describing: OriginalStateError.undefinedBytes(offset: offset, count: size)))
                } else {
                    XCTAssertNil(outcome, "read \(size) at \(offset)")
                }
            }
        }
        XCTAssertEqual(try record.binary64(at: 0x80).bitPattern, expected(0x80, 8))
    }

    func testFlatRecordsBelowTheThreshold() throws {
        let (bytes, defined) = contents(OriginalStateRecord.pagedThreshold - 1, seed: 7)
        let record = try OriginalStateRecord(bytes: bytes, defined: defined)
        XCTAssertEqual(record.byteCount, bytes.count)
        XCTAssertEqual(record.bytes, bytes)
        XCTAssertEqual(record.defined, defined)
    }

    /// Pages sit in groups of 16 (CORE_REALTIME tier 3 S1): reads and writes
    /// across group boundaries match the arrays, and a copy written once keeps
    /// sharing every other group and page with the original.
    func testPageGroupsShareAllButTheWrittenOne() throws {
        let count = OriginalReplayRecording.byteCount
        var (bytes, defined) = contents(count, seed: 41)
        let original = try OriginalStateRecord(bytes: bytes, defined: defined)
        let layout = try XCTUnwrap(original.pageLayout)
        XCTAssertEqual(layout.pages, (count + 0x3fff) >> 14)
        XCTAssertEqual(layout.groups, (layout.pages + 15) >> 4)
        XCTAssertEqual(original.sharedPages(with: original)?.groups, layout.groups)
        XCTAssertEqual(original.sharedPages(with: original)?.pages, layout.pages)

        XCTAssertEqual(original.byteCount, count)
        for offset in [0x3fffe, 0x3ffff, 0x40000, 0x7fffd, 0x80000 - 4, 0x5c0000 - 3, count - 8] {
            for size in [2, 4, 8] {
                let read = error {
                    let value: UInt64
                    switch size {
                    case 2: value = UInt64(try original.integer(at: offset, as: UInt16.self))
                    case 4: value = UInt64(try original.integer(at: offset, as: UInt32.self))
                    default: value = try original.integer(at: offset, as: UInt64.self)
                    }
                    var expected: UInt64 = 0
                    for i in 0..<size { expected |= UInt64(bytes[offset + i]) << (8 * i) }
                    XCTAssertEqual(value, expected, "read \(size) at \(offset)")
                }
                if defined[offset..<offset + size].allSatisfy({ $0 }) {
                    XCTAssertNil(read, "read \(size) at \(offset)")
                } else {
                    XCTAssertEqual(read, String(describing: OriginalStateError.undefinedBytes(offset: offset, count: size)))
                }
            }
            var expected: UInt32 = 0
            for i in 0..<4 { expected |= UInt32(bytes[offset + i]) << (8 * i) }
            XCTAssertEqual(original.rawWord(at: offset), expected)
        }

        var copy = original
        try copy.write(UInt32(0x01020304), at: 0x3fffe)
        let shared = try XCTUnwrap(copy.sharedPages(with: original))
        XCTAssertEqual(shared.groups, layout.groups - 2, "a write across a group boundary unshares two groups")
        XCTAssertEqual(shared.pages, layout.pages - 2)
        var single = original
        try single.write(UInt8(9), at: 0x123456)
        XCTAssertEqual(single.sharedPages(with: original)?.groups, layout.groups - 1)
        XCTAssertEqual(single.sharedPages(with: original)?.pages, layout.pages - 1)
        let before = try XCTUnwrap(single.pageAddresses(at: 0x123457))
        try single.write(UInt8(10), at: 0x123457)
        XCTAssertEqual(single.pageAddresses(at: 0x123457), before, "the same page again is written in place")
        XCTAssertEqual(single.sharedPages(with: original)?.pages, layout.pages - 1)
        XCTAssertNotEqual(original.pageAddresses(at: 0x123457), before)

        for (i, b) in [0x04, 0x03, 0x02, 0x01].enumerated() { bytes[0x3fffe + i] = UInt8(b); defined[0x3fffe + i] = true }
        XCTAssertEqual(copy.bytes, bytes)
        XCTAssertEqual(copy.defined, defined)
        XCTAssertEqual(original.bytes, contents(count, seed: 41).0)
        XCTAssertEqual(original.defined, contents(count, seed: 41).1)
        XCTAssertEqual(copy, try OriginalStateRecord(bytes: bytes, defined: defined))
        XCTAssertNotEqual(copy, original)
        var overwritten = copy
        let piece = try OriginalStateRecord(bytes: (0..<0x20).map { UInt8($0) }, defined: (0..<0x20).map { $0 % 3 != 0 })
        overwritten.overwrite(at: 0x3fff0, with: piece)
        for i in 0..<0x20 { bytes[0x3fff0 + i] = UInt8(i); defined[0x3fff0 + i] = i % 3 != 0 }
        XCTAssertEqual(overwritten.bytes, bytes)
        XCTAssertEqual(overwritten.defined, defined)
        XCTAssertEqual(overwritten.sharedPages(with: copy)?.groups, layout.groups - 2)
    }
}
