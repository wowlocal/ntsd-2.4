import Foundation

public enum OriginalFrameAllocationKind: String, Codable, Sendable {
    case interactions, bodies, sound
}

public struct OriginalFrameAllocation: Equatable, Sendable {
    public let address: UInt32
    public let kind: OriginalFrameAllocationKind
    public internal(set) var storage: OriginalStateRecord
}

/// Native data storage with explicit 32-bit references, never host pointers.
/// The allocator is an external boundary: reference checks supply captured
/// addresses; the application can use the default monotonically allocated arena.
/// Byte writes to a DAT name can affect a reference without unsafe Swift memory.
struct OriginalFrameHeap {
    private(set) var allocations: [OriginalFrameAllocation] = []
    /// The allocations' ranges in address order with their index. Ranges never
    /// overlap (every allocation is checked), so a new range overlaps one exactly
    /// when it overlaps its neighbours here, and an address starts or lies in at
    /// most one: lookups by binary search give what the scans over all
    /// allocations gave (~15,000 of them by the end of the catalog;
    /// MEMORY_LOADING L6).
    private var ordered: [(start: UInt64, end: UInt64, index: Int)] = []
    private var next: UInt32 = 0x10000
    var fill: UInt8 = 0xa5

    /// The first position in `ordered` whose start is at least `address`.
    private func position(_ address: UInt64) -> Int {
        var low = 0, high = ordered.count
        while low < high { let middle = (low + high) / 2; if ordered[middle].start < address { low = middle + 1 } else { high = middle } }
        return low
    }
    private func index(startingAt address: UInt32) -> Int? {
        let i = position(UInt64(address))
        return i < ordered.count && ordered[i].start == UInt64(address) ? ordered[i].index : nil
    }

    mutating func allocate(_ size: Int, kind: OriginalFrameAllocationKind,
                           address: UInt32?) throws -> UInt32 {
        let base = address ?? next
        guard size > 0, size <= 400, base != 0, UInt64(base) + UInt64(size) + 15 <= UInt64(UInt32.max) else {
            throw OriginalStateError.invalidStorage("Overlapping or invalid Frame allocation")
        }
        let low = UInt64(base), high = low + UInt64(size), i = position(low)
        guard !(i > 0 && ordered[i - 1].end > low), !(i < ordered.count && ordered[i].start < high) else {
            throw OriginalStateError.invalidStorage("Overlapping or invalid Frame allocation")
        }
        let record = try OriginalStateRecord(bytes: Array(repeating: fill, count: size), defined: Array(repeating: false, count: size))
        ordered.insert((low, high, allocations.count), at: i)
        allocations.append(.init(address: base, kind: kind, storage: record))
        next = max(next, (base + UInt32(size) + 15) & ~15)
        return base
    }

    mutating func write<T: FixedWidthInteger>(_ value: T, at address: UInt32, offset: Int) throws {
        guard let index = index(startingAt: address) else {
            throw OriginalStateError.invalidStorage("Unknown Frame allocation")
        }
        try allocations[index].storage.write(value, at: offset)
    }

    func words(at address: UInt32, count: Int) throws -> [Int32] {
        guard let index = index(startingAt: address) else {
            throw OriginalStateError.invalidStorage("Unknown Frame box reference")
        }
        let record = allocations[index].storage
        return try (0..<count).map { try record.integer(at: $0*4, as: Int32.self) }
    }

    func string(at address: UInt32) throws -> String? {
        // The last range starting at or before the address, if it contains it.
        let i = position(UInt64(address) + 1)
        guard i > 0, UInt64(address) < ordered[i - 1].end else { return nil }
        let allocation = allocations[ordered[i - 1].index]
        return try Self.string(in: allocation.storage, at: Int(address - allocation.address))
    }

    static func string(in record: OriginalStateRecord, at offset: Int) throws -> String {
        var bytes: [UInt8] = []
        for position in offset..<record.byteCount {
            let byte = try record.integer(at: position, as: UInt8.self)
            if byte == 0 { return String(String.UnicodeScalarView(bytes.map { UnicodeScalar($0) })) }
            bytes.append(byte)
        }
        throw OriginalStateError.invalidStorage("Unterminated Frame string")
    }
}

extension OriginalStateRecord {
    public static let frameSize = 0x178

    /// Exact constructor writes, 40bbf0..40bd83. Presence is one byte;
    /// its padding, c4..d4, array pointers and name bytes retain backing/masks.
    public static func frame(over backing: [UInt8]) throws -> Self {
        guard backing.count == frameSize else { throw OriginalStateError.invalidStorage("Frame backing size") }
        var record = try Self(bytes: backing, defined: Array(repeating: false, count: frameSize))
        try record.write(UInt8(0), at: 0)
        for range in [0x04...0xc0, 0xd8...0x12c, 0x138...0x158] {
            for offset in stride(from: range.lowerBound, through: range.upperBound, by: 4) {
                try record.write(Int32(0), at: offset)
            }
        }
        try record.write(UInt32(0), at: 0x170)
        try record.write(Int32(-1), at: 0x174)
        return record
    }
}
