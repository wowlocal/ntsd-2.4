import XCTest
@testable import NTSDCore

/// CORE_REALTIME B1 (stage 3a): a record in parts gives every result and
/// error of the same flat record, shares a part's buffers at its exact extent,
/// and keeps earlier copies unchanged.
final class OriginalStateRecordPartsTests: XCTestCase {
    struct Random {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state >> 11 }
        mutating func below(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
    }
    func outcome<T>(_ body: () throws -> T) -> String {
        do { return "value \(try body())" } catch { return "error \(error)" }
    }
    func record(_ count: Int, _ random: inout Random) throws -> OriginalStateRecord {
        let bytes = (0..<count).map { _ in UInt8(truncatingIfNeeded: random.next()) }
        let defined = (0..<count).map { _ in random.below(10) != 0 }
        return try .init(bytes: bytes, defined: defined)
    }
    /// Random operations on a flat record and its parted twin, compared after each.
    func compare(_ starts: [Int], total: Int, seed: UInt64, operations: Int = 1500) throws {
        var random = Random(state: seed)
        var flat = try record(total, &random), parted = flat.partitioned(at: starts)
        XCTAssertTrue(parted.isPartitioned); XCTAssertEqual(parted, flat); XCTAssertEqual(parted.byteCount, total)
        let bounds = starts + [total]
        func offset() -> Int {
            switch random.below(6) {
            case 0: return bounds[random.below(bounds.count)] + random.below(17) - 8
            case 1: return [-1, total, total - 1, total - 3, Int.max, Int.min][random.below(6)]
            default: return random.below(total)
            }
        }
        var copies: [(OriginalStateRecord, OriginalStateRecord)] = []
        for step in 0..<operations {
            let label = "seed \(seed) step \(step)"
            switch random.below(11) {
            case 0, 1:
                let at = offset()
                switch random.below(4) {
                case 0: XCTAssertEqual(outcome { try parted.integer(at: at, as: UInt8.self) }, outcome { try flat.integer(at: at, as: UInt8.self) }, label)
                case 1: XCTAssertEqual(outcome { try parted.integer(at: at, as: UInt16.self) }, outcome { try flat.integer(at: at, as: UInt16.self) }, label)
                case 2: XCTAssertEqual(outcome { try parted.integer(at: at, as: Int32.self) }, outcome { try flat.integer(at: at, as: Int32.self) }, label)
                default: XCTAssertEqual(outcome { try parted.binary64(at: at) }.description, outcome { try flat.binary64(at: at) }.description, label)
                }
            case 2, 3:
                let at = offset()
                // Sometimes the value already there (the no-op path).
                let value: UInt32 = random.below(3) == 0 ? ((try? flat.integer(at: at, as: UInt32.self)) ?? 7) : UInt32(truncatingIfNeeded: random.next())
                let a = outcome { try parted.write(value, at: at) }, b = outcome { try flat.write(value, at: at) }
                XCTAssertEqual(a, b, label)
                if random.below(2) == 0 { XCTAssertEqual(outcome { try parted.write(UInt8(truncatingIfNeeded: value), at: at) }, outcome { try flat.write(UInt8(truncatingIfNeeded: value), at: at) }, label) }
            case 4:
                // An overwrite at an exact part, inside one, or spanning parts.
                let start: Int, count: Int
                switch random.below(3) {
                case 0: let k = random.below(starts.count); start = bounds[k]; count = bounds[k + 1] - bounds[k]
                case 1: let k = random.below(starts.count); let size = bounds[k + 1] - bounds[k]; start = bounds[k] + random.below(size); count = random.below(bounds[k + 1] - start + 1)
                default: start = random.below(total); count = random.below(total - start + 1)
                }
                let source = try record(count, &random)
                parted.overwrite(at: start, with: source); flat.overwrite(at: start, with: source)
            case 5:
                let start = random.below(total + 1), count = random.below(total - start + 1)
                let a = parted.extract(start..<start + count), b = flat.extract(start..<start + count)
                XCTAssertEqual(a, b, label); XCTAssertEqual(a.bytes, b.bytes, label); XCTAssertEqual(a.defined, b.defined, label)
                XCTAssertEqual(parted.bytes(in: start..<start + count), flat.bytes(in: start..<start + count), label)
                XCTAssertEqual(parted.allDefined(in: start..<start + count), flat.allDefined(in: start..<start + count), label)
            case 6:
                let start = offset(), count = random.below(64) + (random.below(3) == 0 ? -1 : 0)
                XCTAssertEqual(parted.definedBytes(start, count), flat.definedBytes(start, count), label)
                let lead = random.below(total + 10)
                XCTAssertEqual(parted.leadingBytes(lead), flat.leadingBytes(lead), label)
            case 7:
                copies.append((parted, flat))
            case 8:
                // Wider writes across boundaries, and the whole contents between writes.
                let at = offset(), v16 = UInt16(truncatingIfNeeded: random.next()), value = random.next()
                XCTAssertEqual(outcome { try parted.write(v16, at: at) }, outcome { try flat.write(v16, at: at) }, label)
                XCTAssertEqual(outcome { try parted.write(value, at: at) }, outcome { try flat.write(value, at: at) }, label)
                XCTAssertEqual(outcome { try parted.writeBinary64(Double(bitPattern: value), at: at) }, outcome { try flat.writeBinary64(Double(bitPattern: value), at: at) }, label)
                XCTAssertEqual(parted.bytes, flat.bytes, label); XCTAssertEqual(parted.defined, flat.defined, label)
            case 9:
                // A parted source, onto the parted record, onto the flat twin, and a
                // whole parted record onto another flat record.
                let count = 1 + random.below(total), start = random.below(total - count + 1)
                let source = try record(count, &random).partitioned(at: count > 1 ? [0, count / 2] : [0])
                parted.overwrite(at: start, with: source); flat.overwrite(at: start, with: source)
                var other = try record(total, &random), reference = other
                other.overwrite(at: 0, with: parted); reference.overwrite(at: 0, with: flat)
                XCTAssertEqual(other, reference, label); XCTAssertFalse(other.isPartitioned, label)
            default:
                XCTAssertEqual(parted, flat, label); XCTAssertEqual(parted.byteCount, flat.byteCount, label)
            }
        }
        XCTAssertEqual(parted, flat); XCTAssertEqual(parted.bytes, flat.bytes); XCTAssertEqual(parted.defined, flat.defined)
        XCTAssertEqual(parted.readOnce().bytes, flat.readOnce().bytes); XCTAssertEqual(parted.readOnce().defined, flat.readOnce().defined)
        XCTAssertTrue(parted.isPartitioned, "operations keep the parts")
        for (p, f) in copies { XCTAssertEqual(p.bytes, f.bytes); XCTAssertEqual(p.defined, f.defined) }
    }
    func testPartsMatchAFlatRecord() throws {
        // The menu state's layout, random layouts and one-byte parts.
        let menu = [0, 0xb440, 0xb580, 0xb588, 0xb8a8, 0xb8b0, 0xbb00, 0xc2d8]
        try compare(menu, total: 0xc3a8, seed: 1)
        try compare(menu, total: 0xc3a8, seed: 2)
        for seed in UInt64(3)...8 {
            var random = Random(state: seed &* 7919)
            let total = 16 + random.below(400)
            var starts = Set([0]); for _ in 0..<random.below(8) { starts.insert(random.below(total)) }
            try compare(starts.sorted(), total: total, seed: seed)
        }
        try compare(Array(0..<24), total: 24, seed: 9)
    }
    func testWholeOverwritesZeroingAndLayouts() throws {
        var random = Random(state: 14)
        let flat = try record(0x420, &random)
        var parted = flat.partitioned(at: [0, 0x100, 0x2f0]), plain = flat
        // Constructor writes (zeroed ranges and writes across parts).
        try parted.reconstructActor(); try plain.reconstructActor()
        XCTAssertEqual(parted, plain); XCTAssertEqual(parted.bytes, plain.bytes); XCTAssertEqual(parted.defined, plain.defined)
        // A whole-extent and an empty overwrite at the end.
        let whole = try record(0x420, &random)
        parted.overwrite(at: 0, with: whole); plain.overwrite(at: 0, with: whole)
        parted.overwrite(at: 0x420, with: try OriginalStateRecord(bytes: [], defined: []))
        XCTAssertEqual(parted, plain); XCTAssertEqual(parted.bytes, whole.bytes)
        // Different layouts of the same contents are equal.
        XCTAssertEqual(plain.partitioned(at: [0, 7]), plain.partitioned(at: [0, 0x200, 0x300]))
        // An extracted part keeps its contents when the parent writes that part.
        let part = parted.extract(0x100..<0x2f0)
        try parted.write(((try? parted.integer(at: 0x100, as: UInt32.self)) ?? 0) &+ 1, at: 0x100)
        XCTAssertEqual(part, plain.extract(0x100..<0x2f0))
        XCTAssertNotEqual(parted.extract(0x100..<0x2f0), part)
    }
    func testErrorsCarryLogicalOffsets() throws {
        var random = Random(state: 11)
        var flat = try record(0xc3a8, &random)
        try flat.write(UInt32(0x01020304), at: 0xb43c)
        var mask = flat.defined; mask[0xb441] = false
        flat = try .init(bytes: flat.bytes, defined: mask)
        let parted = flat.partitioned(at: [0, 0xb440, 0xb580])
        XCTAssertEqual(outcome { try parted.integer(at: 0xb43e, as: UInt32.self) }, "error \(OriginalStateError.undefinedBytes(offset: 0xb43e, count: 4))")
        XCTAssertEqual(outcome { try parted.integer(at: 0xc3a6, as: UInt32.self) }, "error \(OriginalStateError.outOfBounds(offset: 0xc3a6, count: 4))")
        XCTAssertEqual(outcome { try parted.integer(at: 0xb43c, as: UInt32.self) }, outcome { try flat.integer(at: 0xb43c, as: UInt32.self) })
    }
    func testExactExtentsShareBuffers() throws {
        var random = Random(state: 12)
        let starts = [0, 100, 108, 300]
        var parted = try record(400, &random).partitioned(at: starts)
        let part = parted.extract(100..<108)
        XCTAssertTrue(parted.extract(100..<108).sharesStorage(with: part), "an exact part is shared")
        let source = try record(192, &random)
        parted.overwrite(at: 108, with: source)
        XCTAssertTrue(parted.extract(108..<300).sharesStorage(with: source), "an exact install shares the source")
        // A write copies only its own part.
        var copy = parted
        try copy.write(((try? copy.integer(at: 0, as: UInt32.self)) ?? 0) &+ 1, at: 0)
        XCTAssertTrue(copy.extract(108..<300).sharesStorage(with: parted.extract(108..<300)))
        XCTAssertFalse(copy.extract(0..<100).sharesStorage(with: parted.extract(0..<100)))
        XCTAssertNotEqual(copy, parted)
        // Equality across representations, including a mask-only difference.
        let flat = parted.flattened()
        XCTAssertEqual(parted, flat); XCTAssertEqual(flat, parted); XCTAssertFalse(flat.isPartitioned)
        var mask = flat.defined; mask[5].toggle()
        XCTAssertNotEqual(parted, try OriginalStateRecord(bytes: flat.bytes, defined: mask))
        XCTAssertEqual(parted.partitioned(at: starts), parted)
    }
    func testOnlyWholeReadsAssemble() throws {
        var random = Random(state: 13)
        var parted = try record(0xc3a8, &random).partitioned(at: [0, 0xb440, 0xb580])
        let before = OriginalStateRecord.partAssemblies
        _ = try? parted.integer(at: 10, as: UInt32.self)
        try parted.write(UInt32(9), at: 0xb43e)
        _ = parted.extract(0..<0xb440); _ = parted.bytes(in: 0..<20); _ = parted.byteCount
        XCTAssertEqual(OriginalStateRecord.partAssemblies, before, "no whole assembly")
        let flat = parted.flattened()
        _ = parted.readOnce(); _ = parted.leadingBytes(40); _ = parted.definedBytes(0xb43c, 8)
        _ = parted.allDefined(in: 0..<0xc000); _ = parted == flat; _ = parted.extract(5..<5)
        XCTAssertEqual(OriginalStateRecord.partAssemblies, before, "no whole assembly")
        _ = parted.bytes; _ = parted.bytes
        XCTAssertEqual(OriginalStateRecord.partAssemblies, before + 1, "one assembly, then cached")
        // An install of the part already there changes nothing and keeps the cache.
        parted.overwrite(at: 0, with: parted.extract(0..<0xb440))
        _ = parted.bytes
        XCTAssertEqual(OriginalStateRecord.partAssemblies, before + 1, "a no-op install keeps the cache")
        var plain = flat
        try parted.write(UInt32(10), at: 0xb43e); try plain.write(UInt32(10), at: 0xb43e)
        XCTAssertEqual(parted.bytes, plain.bytes, "the write is seen")
        XCTAssertEqual(OriginalStateRecord.partAssemblies, before + 2, "a write drops the cache")
    }
}
