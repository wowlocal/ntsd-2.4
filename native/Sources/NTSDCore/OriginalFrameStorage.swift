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
    private var next: UInt32 = 0x10000
    var fill: UInt8 = 0xa5

    mutating func allocate(_ size: Int, kind: OriginalFrameAllocationKind,
                           address: UInt32?) throws -> UInt32 {
        let base = address ?? next
        guard size > 0, size <= 400, base != 0, UInt64(base) + UInt64(size) + 15 <= UInt64(UInt32.max),
              !allocations.contains(where: { UInt64(base) < UInt64($0.address) + UInt64($0.storage.bytes.count) && UInt64($0.address) < UInt64(base) + UInt64(size) }) else {
            throw OriginalStateError.invalidStorage("Overlapping or invalid Frame allocation")
        }
        let record = try OriginalStateRecord(bytes: Array(repeating: fill, count: size), defined: Array(repeating: false, count: size))
        allocations.append(.init(address: base, kind: kind, storage: record))
        next = max(next, (base + UInt32(size) + 15) & ~15)
        return base
    }

    mutating func write<T: FixedWidthInteger>(_ value: T, at address: UInt32, offset: Int) throws {
        guard let index = allocations.lastIndex(where: { $0.address == address }) else {
            throw OriginalStateError.invalidStorage("Unknown Frame allocation")
        }
        try allocations[index].storage.write(value, at: offset)
    }

    func words(at address: UInt32, count: Int) throws -> [Int32] {
        guard let record = allocations.last(where: { $0.address == address })?.storage else {
            throw OriginalStateError.invalidStorage("Unknown Frame box reference")
        }
        return try (0..<count).map { try record.integer(at: $0*4, as: Int32.self) }
    }

    func string(at address: UInt32) throws -> String? {
        guard let allocation = allocations.last(where: { $0.address <= address && UInt64(address) < UInt64($0.address) + UInt64($0.storage.bytes.count) }) else { return nil }
        return try Self.string(in: allocation.storage, at: Int(address - allocation.address))
    }

    static func string(in record: OriginalStateRecord, at offset: Int) throws -> String {
        var bytes: [UInt8] = []
        for position in offset..<record.bytes.count {
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
