import Foundation
import XCTest
@testable import NTSDCore

/// Flat records keep their bytes and a definedness bit mask in one buffer
/// (CORE_REALTIME tier 3 S2b). A plain model of a byte array and a Bool array
/// is the oracle: random reads, writes, overwrites and slices over sizes and
/// offsets of every alignment give the model's values and errors, copies stay
/// independent, and copy-on-write shares and unshares as the arrays did.
final class OriginalStateRecordStorageTests: XCTestCase {
    private struct Generator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 17
        }
        mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() % UInt64(range.count)) }
        mutating func chance(_ percent: Int) -> Bool { int(0...99) < percent }
    }

    private struct Model: Equatable {
        var bytes: [UInt8], defined: [Bool]
        func integer(_ offset: Int, _ width: Int) throws -> UInt64 {
            guard offset >= 0, width <= bytes.count, offset <= bytes.count - width else {
                throw OriginalStateError.outOfBounds(offset: offset, count: width)
            }
            guard defined[offset..<offset + width].allSatisfy({ $0 }) else {
                throw OriginalStateError.undefinedBytes(offset: offset, count: width)
            }
            return (0..<width).reduce(UInt64(0)) { $0 | UInt64(bytes[offset + $1]) << (8 * UInt64($1)) }
        }
        mutating func write(_ value: UInt64, _ offset: Int, _ width: Int) throws {
            guard offset >= 0, width <= bytes.count, offset <= bytes.count - width else {
                throw OriginalStateError.outOfBounds(offset: offset, count: width)
            }
            for i in 0..<width { bytes[offset + i] = UInt8(truncatingIfNeeded: value >> (8 * UInt64(i))); defined[offset + i] = true }
        }
    }

    private func read(_ record: OriginalStateRecord, _ offset: Int, _ width: Int) throws -> UInt64 {
        switch width {
        case 1: return UInt64(try record.integer(at: offset, as: UInt8.self))
        case 2: return UInt64(try record.integer(at: offset, as: UInt16.self))
        case 4: return UInt64(try record.integer(at: offset, as: UInt32.self))
        default: return try record.integer(at: offset, as: UInt64.self)
        }
    }
    private func write(_ record: inout OriginalStateRecord, _ value: UInt64, _ offset: Int, _ width: Int, signed: Bool) throws {
        switch (width, signed) {
        case (1, false): try record.write(UInt8(truncatingIfNeeded: value), at: offset)
        case (1, true): try record.write(Int8(truncatingIfNeeded: value), at: offset)
        case (2, false): try record.write(UInt16(truncatingIfNeeded: value), at: offset)
        case (2, true): try record.write(Int16(truncatingIfNeeded: value), at: offset)
        case (4, false): try record.write(UInt32(truncatingIfNeeded: value), at: offset)
        case (4, true): try record.write(Int32(truncatingIfNeeded: value), at: offset)
        case (_, false): try record.write(value, at: offset)
        default: try record.write(Int64(bitPattern: value), at: offset)
        }
    }
    private func outcome<T: Equatable>(_ body: () throws -> T) -> String {
        do { return "value \(try body())" } catch { return "error \(error)" }
    }
    private func model(_ count: Int, _ g: inout Generator) -> Model {
        var bytes = [UInt8](repeating: 0, count: count), defined = [Bool](repeating: false, count: count)
        let density = g.int(0...100)
        for i in 0..<count { bytes[i] = UInt8(truncatingIfNeeded: g.next()); defined[i] = g.int(0...99) < density }
        return Model(bytes: bytes, defined: defined)
    }

    func testFlatRecordsMatchTheModel() throws {
        var g = Generator(state: 0x52b)
        var checked = 0, errors = 0
        for count in [1, 7, 8, 9, 15, 16, 17, 63, 64, 65, 0x178, 0x420, 0x7d8, 0x1f50, 0xb440] {
            var m = model(count, &g)
            var record = try OriginalStateRecord(bytes: m.bytes, defined: m.defined)
            var snapshots: [(OriginalStateRecord, Model)] = []
            for step in 0..<(count < 100 ? 400 : 900) {
                let width = [1, 2, 4, 8][g.int(0...3)]
                let offset = g.chance(4) ? [-1, count, count - width + 1, Int.min, Int.max - 3][g.int(0...4)] : g.int(0...max(0, count - 1))
                switch g.int(0...9) {
                case 0...3:
                    XCTAssertEqual(outcome { try read(record, offset, width) }, outcome { try m.integer(offset, width) }, "read \(width)@\(offset) of \(count)")
                case 4...6:
                    // Same-value writes (defined or not) as well as new values.
                    let value = g.chance(30) && offset >= 0 && offset <= count - width
                        ? (0..<width).reduce(UInt64(0)) { $0 | UInt64(m.bytes[offset + $1]) << (8 * UInt64($1)) } : g.next() &* 0x9e3779b97f4a7c15
                    let signed = g.chance(50)
                    let a = outcome { try write(&record, value, offset, width, signed: signed); return 0 }
                    let b = outcome { try m.write(value, offset, width); return 0 }
                    XCTAssertEqual(a, b, "write \(width)@\(offset) of \(count)")
                    if a.hasPrefix("error") { errors += 1 }
                case 7:
                    // An overwrite from a fresh record, a slice of this one or a copy.
                    let n = g.int(0...min(count, 40)), start = g.int(0...(count - n))
                    let source: Model
                    if g.chance(50) { source = self.model(n, &g) }
                    else { let from = g.int(0...(count - n)); source = Model(bytes: Array(m.bytes[from..<from + n]), defined: Array(m.defined[from..<from + n])) }
                    record.overwrite(at: start, with: try OriginalStateRecord(bytes: source.bytes, defined: source.defined))
                    m.bytes.replaceSubrange(start..<start + n, with: source.bytes)
                    m.defined.replaceSubrange(start..<start + n, with: source.defined)
                case 8:
                    let lo = g.int(0...count), hi = g.int(lo...count)
                    let slice = record.extract(lo..<hi)
                    XCTAssertEqual(slice.bytes, Array(m.bytes[lo..<hi])); XCTAssertEqual(slice.defined, Array(m.defined[lo..<hi]))
                    XCTAssertEqual(record.bytes(in: lo..<hi), Array(m.bytes[lo..<hi]))
                    XCTAssertEqual(record.allDefined(in: lo..<hi), m.defined[lo..<hi].allSatisfy { $0 })
                    XCTAssertEqual(record.definedBytes(lo, hi - lo), m.defined[lo..<hi].allSatisfy { $0 } ? Array(m.bytes[lo..<hi]) : nil)
                    XCTAssertEqual(record.leadingBytes(hi), Array(m.bytes.prefix(hi)))
                    if count >= 4 { let w = g.int(0...(count - 4)); XCTAssertEqual(record.rawWord(at: w), UInt32(m.bytes[w]) | UInt32(m.bytes[w + 1]) << 8 | UInt32(m.bytes[w + 2]) << 16 | UInt32(m.bytes[w + 3]) << 24) }
                default:
                    snapshots.append((record, m))
                }
                if step % 37 == 0 {
                    XCTAssertEqual(record.bytes, m.bytes); XCTAssertEqual(record.defined, m.defined)
                    XCTAssertEqual(record.byteCount, count)
                    let i = g.int(0...(count - 1))
                    XCTAssertEqual(record.byte(at: i), m.bytes[i]); XCTAssertEqual(record.isDefined(at: i), m.defined[i])
                    let rebuilt = try OriginalStateRecord(bytes: m.bytes, defined: m.defined)
                    XCTAssertEqual(record, rebuilt, "equality with a record built from the arrays")
                    XCTAssertEqual(record.readOnce().bytes, m.bytes); XCTAssertEqual(record.readOnce().defined, m.defined)
                }
                checked += 1
            }
            XCTAssertEqual(record.bytes, m.bytes); XCTAssertEqual(record.defined, m.defined)
            for (copy, expected) in snapshots {
                XCTAssertEqual(copy.bytes, expected.bytes, "a copy keeps its contents"); XCTAssertEqual(copy.defined, expected.defined)
            }
            // A mask difference alone makes records unequal, at every bit position.
            if let i = m.defined.firstIndex(of: false) {
                var mask = m.defined; mask[i] = true
                XCTAssertNotEqual(try OriginalStateRecord(bytes: m.bytes, defined: mask), record)
            }
        }
        XCTAssertEqual(checked, 10 * 400 + 5 * 900, "every step of the corpus ran")
        XCTAssertGreaterThan(errors, 100)
        XCTAssertEqual(OriginalStateRecord.vacant.byteCount, 0)
        XCTAssertEqual(OriginalStateRecord.vacant, try OriginalStateRecord(bytes: [], defined: []))
        XCTAssertTrue(OriginalStateRecord.vacant.sharesStorage(with: try OriginalStateRecord(bytes: [], defined: [])))
    }

    /// Copy-on-write: a copy shares the storage, a write that stores the
    /// bytes already there (all defined) keeps sharing, any other write gives
    /// the writer its own storage once, and later writes keep it.
    func testCopyOnWriteSharesAndUnshares() throws {
        var g = Generator(state: 0x77)
        let m = model(0x420, &g)
        let base = try OriginalStateRecord(bytes: m.bytes, defined: m.defined)
        for width in [1, 2, 4, 8] {
            guard let at = (0..<(0x420 - width)).first(where: { i in (i..<i + width).allSatisfy { m.defined[$0] } }) else { continue }
            var copy = base
            XCTAssertTrue(copy.sharesStorage(with: base))
            let same = (0..<width).reduce(UInt64(0)) { $0 | UInt64(m.bytes[at + $1]) << (8 * UInt64($1)) }
            try write(&copy, same, at, width, signed: false)
            XCTAssertTrue(copy.sharesStorage(with: base), "a no-op write of \(width) keeps sharing")
        }
        var copy = base
        let undefined = try XCTUnwrap(m.defined.firstIndex(of: false))
        try copy.write(m.bytes[undefined], at: undefined)
        XCTAssertFalse(copy.sharesStorage(with: base), "storing the same byte while it is undefined unshares")
        XCTAssertFalse(base.isDefined(at: undefined)); XCTAssertTrue(copy.isDefined(at: undefined))
        let identity = try XCTUnwrap(copy.storageIdentity)
        try copy.write(UInt32(0xdeadbeef), at: 0x100)
        XCTAssertEqual(copy.storageIdentity?.0, identity.0, "a unique record is written in place")
        XCTAssertEqual(try copy.integer(at: 0x100, as: UInt32.self), 0xdeadbeef)
        XCTAssertNotEqual(try? base.integer(at: 0x100, as: UInt32.self), 0xdeadbeef)
    }

    /// The actor and world-prefix constructors' zeroed ranges and writes equal
    /// the same steps on the model.
    func testConstructorsMatchTheModel() throws {
        var g = Generator(state: 0x1f)
        for _ in 0..<5 {
            var m = model(OriginalStateRecord.actorSize, &g)
            m.defined = [Bool](repeating: false, count: m.bytes.count)
            let actor = try OriginalStateRecord.actor(over: m.bytes)
            for range in [0..<0x24, 0x58..<0x81, 0x84..<0xbd, 0xbe..<0xdd, 0xe0..<0x31c, 0x320..<0x368, 0x36c..<0x370, 0x3e8..<0x41c] {
                for i in range { m.bytes[i] = 0; m.defined[i] = true }
            }
            for offset in stride(from: 0x28, through: 0x50, by: 8) { try m.write(0x3fb999999999999a, offset, 8) }
            for offset in [0x2e8, 0x2ec, 0x2f0] { try m.write(1000, offset, 4) }
            for offset in [0x2f4, 0x2f8, 0x324, 0x328, 0x32c, 0x33c, 0x360, 0x3f8] { try m.write(UInt64(UInt32(bitPattern: -1)), offset, 4) }
            for offset in [0x2fc, 0x300, 0x304, 0x308] { try m.write(500, offset, 4) }
            try m.write(99, 0x354, 4)
            for offset in [0x3fc, 0x400] { try m.write(UInt64(UInt32(bitPattern: -1000)), offset, 4) }
            XCTAssertEqual(actor.bytes, m.bytes); XCTAssertEqual(actor.defined, m.defined)

            var w = model(OriginalStateRecord.worldPrefixSize, &g)
            w.defined = [Bool](repeating: false, count: w.bytes.count)
            let world = try OriginalStateRecord.worldPrefix(over: w.bytes)
            for i in 0..<0x194 { w.bytes[i] = 0; w.defined[i] = true }
            XCTAssertEqual(world.bytes, w.bytes); XCTAssertEqual(world.defined, w.defined)
        }
    }

    /// The review's gaps: the empty record, whole and large overwrites, an
    /// overwrite from an extracted slice or a copy of itself, a no-op
    /// overwrite keeping storage shared, zeroing a shared copy, and inequality
    /// by a byte or by size.
    func testEdgeCasesAgainstTheModel() throws {
        // The empty record.
        let empty = try OriginalStateRecord(bytes: [], defined: [])
        XCTAssertEqual(outcome { try read(empty, 0, 1) }, outcome { try Model(bytes: [], defined: []).integer(0, 1) })
        var written = empty
        XCTAssertEqual(outcome { try write(&written, 1, 0, 1, signed: false); return 0 },
                       outcome { var m = Model(bytes: [], defined: []); try m.write(1, 0, 1); return 0 })
        XCTAssertEqual(empty.extract(0..<0).byteCount, 0)
        XCTAssertEqual(empty.definedBytes(0, 0), [])
        XCTAssertTrue(empty.allDefined(in: 0..<0))
        XCTAssertEqual(empty.leadingBytes(5), [])
        XCTAssertEqual(empty.bytes, []); XCTAssertEqual(empty.defined, [])

        var g = Generator(state: 0xe0)
        for count in [9, 0x420, 0xb440] {
            var m = model(count, &g)
            var record = try OriginalStateRecord(bytes: m.bytes, defined: m.defined)
            // A whole-record overwrite and a large one at an unaligned start.
            let whole = model(count, &g)
            record.overwrite(at: 0, with: try OriginalStateRecord(bytes: whole.bytes, defined: whole.defined))
            m = whole
            XCTAssertEqual(record.bytes, m.bytes); XCTAssertEqual(record.defined, m.defined)
            if count > 64 {
                let n = count / 2, start = 3
                let piece = model(n, &g)
                record.overwrite(at: start, with: try OriginalStateRecord(bytes: piece.bytes, defined: piece.defined))
                m.bytes.replaceSubrange(start..<start + n, with: piece.bytes); m.defined.replaceSubrange(start..<start + n, with: piece.defined)
                XCTAssertEqual(record.bytes, m.bytes); XCTAssertEqual(record.defined, m.defined)
                // From an extracted slice of itself, shifted.
                let slice = record.extract(5..<5 + n - 7)
                record.overwrite(at: 1, with: slice)
                let movedBytes = Array(m.bytes[5..<5 + n - 7]), movedDefined = Array(m.defined[5..<5 + n - 7])
                m.bytes.replaceSubrange(1..<1 + n - 7, with: movedBytes); m.defined.replaceSubrange(1..<1 + n - 7, with: movedDefined)
                XCTAssertEqual(record.bytes, m.bytes); XCTAssertEqual(record.defined, m.defined)
                XCTAssertEqual(slice, try OriginalStateRecord(bytes: movedBytes, defined: movedDefined))
            }
            // From a copy of itself: the same contents, so nothing changes and
            // the storage stays shared.
            let copy = record
            record.overwrite(at: 0, with: copy)
            XCTAssertTrue(record.sharesStorage(with: copy), "a no-op overwrite keeps sharing")
            XCTAssertEqual(record.bytes, m.bytes)
            // A one-byte difference and a size difference.
            var bytes = m.bytes; bytes[count - 1] &+= 1
            XCTAssertNotEqual(try OriginalStateRecord(bytes: bytes, defined: m.defined), record)
            XCTAssertNotEqual(try OriginalStateRecord(bytes: Array(m.bytes.dropLast()), defined: Array(m.defined.dropLast())), record)
        }
        // Zeroing a shared copy (the actor constructor on an existing record)
        // leaves the original alone.
        let actor = try OriginalStateRecord(bytes: model(OriginalStateRecord.actorSize, &g).bytes, defined: [Bool](repeating: true, count: OriginalStateRecord.actorSize))
        var reused = actor
        try reused.reconstructActor()
        XCTAssertFalse(reused.sharesStorage(with: actor))
        XCTAssertNotEqual(reused.bytes, actor.bytes)
        XCTAssertEqual(actor.defined, [Bool](repeating: true, count: OriginalStateRecord.actorSize))
        XCTAssertEqual(try reused.integer(at: 0x354, as: Int32.self), 99)
    }

    /// Whole reads are cached per written version: a whole read after an
    /// in-place write or after a write to a copy sees the new contents, and
    /// the other record keeps its own.
    func testWholeReadsFollowWrites() throws {
        var g = Generator(state: 0x3c)
        var m = model(0x420, &g)
        var record = try OriginalStateRecord(bytes: m.bytes, defined: m.defined)
        XCTAssertEqual(record.bytes, m.bytes); XCTAssertEqual(record.defined, m.defined)
        try record.write(UInt16(0xbeef), at: 9); try m.write(0xbeef, 9, 2)
        XCTAssertEqual(record.bytes, m.bytes, "in place"); XCTAssertEqual(record.defined, m.defined)
        let copy = record
        XCTAssertEqual(copy.bytes, m.bytes)
        try record.write(UInt8(1), at: 0x41f)
        XCTAssertEqual(copy.bytes, m.bytes, "the copy keeps its contents and its cache")
        try m.write(1, 0x41f, 1)
        XCTAssertEqual(record.bytes, m.bytes, "after a copy-on-write"); XCTAssertEqual(record.defined, m.defined)
        var zeroed = record
        _ = zeroed.bytes
        try zeroed.reconstructActor()
        XCTAssertEqual(zeroed.byte(at: 0), 0); XCTAssertEqual(zeroed.bytes[0], 0); XCTAssertTrue(zeroed.defined[0])
        XCTAssertEqual(record.bytes, m.bytes)
    }
}
