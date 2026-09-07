import Foundation

public enum OriginalStateError: Error, CustomStringConvertible {
    case invalidStorage(String)
    case outOfBounds(offset: Int, count: Int)
    case undefinedBytes(offset: Int, count: Int)

    public var description: String {
        switch self {
        case .invalidStorage(let detail): return "Original state storage: \(detail)"
        case .outOfBounds(let offset, let count): return "State access outside storage: \(offset), \(count) bytes"
        case .undefinedBytes(let offset, let count): return "State bytes have no recovered initialization: \(offset), \(count) bytes"
        }
    }
}

/// Original little-endian storage, including opaque and untouched bytes.
/// `defined` describes recovered initialization, not whether a backing byte is zero.
/// This is the R02 state foundation; the practice still uses its bounded FighterState.
public struct OriginalStateRecord: Equatable, Sendable {
    public static let actorSize = 0x420
    /// Observed World prefix through the catalog pointer, not a recovered sizeof(World).
    public static let worldPrefixSize = 0x7d8

    public private(set) var bytes: [UInt8]
    public private(set) var defined: [Bool]

    public init(bytes: [UInt8], defined: [Bool]) throws {
        guard bytes.count == defined.count else {
            throw OriginalStateError.invalidStorage("byte and initialization-mask lengths differ")
        }
        self.bytes = bytes
        self.defined = defined
    }

    private func checkedRange(_ offset: Int, _ count: Int) throws -> Range<Int> {
        guard offset >= 0, count >= 0, count <= bytes.count, offset <= bytes.count - count else {
            throw OriginalStateError.outOfBounds(offset: offset, count: count)
        }
        return offset..<(offset + count)
    }

    /// A typed read cannot silently promote allocator contents to a game default.
    public func integer<T: FixedWidthInteger>(at offset: Int, as type: T.Type) throws -> T {
        let region = try checkedRange(offset, T.bitWidth / 8)
        guard defined[region].allSatisfy({ $0 }) else {
            throw OriginalStateError.undefinedBytes(offset: offset, count: region.count)
        }
        return region.enumerated().reduce(T.zero) { $0 | (T(truncatingIfNeeded: bytes[$1.element]) << ($1.offset * 8)) }
    }

    public func binary64(at offset: Int) throws -> Double {
        Double(bitPattern: try integer(at: offset, as: UInt64.self))
    }

    /// Writes preserve exact integer/floating-point bit patterns; no host-width pointer conversion.
    public mutating func write<T: FixedWidthInteger>(_ value: T, at offset: Int) throws {
        let region = try checkedRange(offset, T.bitWidth / 8)
        for (shift, index) in region.enumerated() {
            bytes[index] = UInt8(truncatingIfNeeded: value >> (shift * 8))
            defined[index] = true
        }
    }

    public mutating func writeBinary64(_ value: Double, at offset: Int) throws {
        try write(value.bitPattern, at: offset)
    }

    private mutating func zero(_ region: Range<Int>) {
        for index in region { bytes[index] = 0; defined[index] = true }
    }

    private static func backing(_ bytes: [UInt8], size: Int, kind: String) throws -> Self {
        guard bytes.count == size else {
            throw OriginalStateError.invalidStorage("\(kind) needs \(size) bytes, received \(bytes.count)")
        }
        return try Self(bytes: bytes, defined: Array(repeating: false, count: size))
    }

    /// Final writes of EXE 0x4061d0..0x4064cc. This is not a spawned fighter default.
    /// Constructor execution has no intermediate callbacks except memset.
    public static func actor(over initialBytes: [UInt8]) throws -> Self {
        var record = try backing(initialBytes, size: actorSize, kind: "Actor")
        try record.reconstructActor()
        return record
    }

    /// Calling the constructor on an existing allocation preserves untouched bytes
    /// AND their prior initialization provenance (e.g. Object* and +0x31c).
    public mutating func reconstructActor() throws {
        guard bytes.count == Self.actorSize else {
            throw OriginalStateError.invalidStorage("Actor reconstruction needs \(Self.actorSize) bytes")
        }
        // Sparse ranges deliberately omit untouched bytes, Object*, and the opaque 0x370..0x3e7 area.
        for range in [0..<0x24, 0x58..<0x81, 0x84..<0xbd, 0xbe..<0xdd,
                      0xe0..<0x31c, 0x320..<0x368, 0x36c..<0x370, 0x3e8..<0x41c] {
            zero(range)
        }
        // Exact binary64 constant at 0x447920, loaded/stored with x87 in the EXE.
        for offset in stride(from: 0x28, through: 0x50, by: 8) {
            try write(UInt64(0x3fb999999999999a), at: offset)
        }
        for offset in [0x2e8, 0x2ec, 0x2f0] { try write(Int32(1000), at: offset) }
        for offset in [0x2f4, 0x2f8, 0x324, 0x328, 0x32c, 0x33c, 0x360, 0x3f8] {
            try write(Int32(-1), at: offset)
        }
        for offset in [0x2fc, 0x300, 0x304, 0x308] { try write(Int32(500), at: offset) }
        try write(Int32(99), at: 0x354)
        for offset in [0x3fc, 0x400] { try write(Int32(-1000), at: offset) }
    }

    /// EXE 0x419e40..0x419e5f only clears selector + 400 activity bytes.
    /// Actor pointers and catalog pointer are assigned later, not by this constructor.
    public static func worldPrefix(over initialBytes: [UInt8]) throws -> Self {
        var record = try backing(initialBytes, size: worldPrefixSize, kind: "World prefix")
        record.zero(0..<0x194)
        return record
    }
}
