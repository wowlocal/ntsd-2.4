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

    /// Records of at least this many bytes (today only the 0x630e18-byte replay
    /// buffers) keep their bytes and masks in pages, so a copy that is then
    /// written duplicates one page instead of the whole record: each game cycle
    /// writes its replay packet into a rollback copy (MOBILE_PERFORMANCE step 3).
    /// Contents, errors and equality are those of the flat representation.
    static let pagedThreshold = 0x400000
    private static let pageShift = 14, pageMask = (1 << 14) - 1

    private var flatBytes: [UInt8]
    private var flatDefined: [Bool]
    private var pages: Pages?

    private struct Pages: Equatable, Sendable {
        var bytes: [[UInt8]]
        var defined: [[Bool]]
        /// The assembled contents, built on first read and shared by copies
        /// with the same contents; every write starts a new one.
        var whole = Whole()
        var count: Int { bytes.isEmpty ? 0 : ((bytes.count - 1) << OriginalStateRecord.pageShift) + bytes[bytes.count - 1].count }
        static func == (lhs: Pages, rhs: Pages) -> Bool { lhs.bytes == rhs.bytes && lhs.defined == rhs.defined }
        mutating func willWrite() {
            if isKnownUniquelyReferenced(&whole) { whole.clear() } else { whole = Whole() }
        }
    }

    private final class Whole: @unchecked Sendable {
        private let lock = NSLock()
        private var bytes: [UInt8]?, defined: [Bool]?
        func bytes(_ pages: [[UInt8]], _ count: Int) -> [UInt8] {
            lock.lock(); defer { lock.unlock() }
            if let bytes { return bytes }
            let made = assemble(pages, count)
            bytes = made
            return made
        }
        func defined(_ pages: [[Bool]], _ count: Int) -> [Bool] {
            lock.lock(); defer { lock.unlock() }
            if let defined { return defined }
            let made = assemble(pages, count)
            defined = made
            return made
        }
        func clear() { lock.lock(); bytes = nil; defined = nil; lock.unlock() }
    }

    private static func assemble<Element>(_ pages: [[Element]], _ count: Int) -> [Element] {
        var made = [Element](); made.reserveCapacity(count)
        for page in pages { made.append(contentsOf: page) }
        return made
    }

    /// The whole contents for a single read, without filling a paged record's
    /// cache: the replay writer reads its buffers once and then frees them,
    /// and a freed allocation keeps its storage.
    func readOnce() -> (bytes: [UInt8], defined: [Bool]) {
        guard let pages else { return (flatBytes, flatDefined) }
        return (Self.assemble(pages.bytes, pages.count), Self.assemble(pages.defined, pages.count))
    }

    /// `Array(bytes.prefix(count))` without assembling a paged record.
    func leadingBytes(_ count: Int) -> [UInt8] {
        guard let pages else { return Array(flatBytes.prefix(count)) }
        precondition(count >= 0, "Can't take a prefix of negative length from a collection")
        var made = [UInt8](); made.reserveCapacity(min(count, pages.count))
        for page in pages.bytes where made.count < count { made.append(contentsOf: page.prefix(count - made.count)) }
        return made
    }

    /// The whole contents. A paged record assembles them once per written
    /// version (code may index `bytes[i]` in a loop); hot paths use
    /// `byteCount` and the typed accessors.
    public var bytes: [UInt8] {
        guard let pages else { return flatBytes }
        return pages.whole.bytes(pages.bytes, pages.count)
    }
    public var defined: [Bool] {
        guard let pages else { return flatDefined }
        return pages.whole.defined(pages.defined, pages.count)
    }
    public var byteCount: Int { pages?.count ?? flatBytes.count }

    public init(bytes: [UInt8], defined: [Bool]) throws {
        guard bytes.count == defined.count else {
            throw OriginalStateError.invalidStorage("byte and initialization-mask lengths differ")
        }
        if bytes.count >= Self.pagedThreshold {
            let starts = stride(from: 0, to: bytes.count, by: 1 << Self.pageShift)
            pages = Pages(bytes: starts.map { Array(bytes[$0..<min($0 + (1 << Self.pageShift), bytes.count)]) },
                          defined: starts.map { Array(defined[$0..<min($0 + (1 << Self.pageShift), defined.count)]) })
            flatBytes = []
            flatDefined = []
        } else {
            flatBytes = bytes
            flatDefined = defined
            pages = nil
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.pages, rhs.pages) {
        case (nil, nil): return lhs.flatBytes == rhs.flatBytes && lhs.flatDefined == rhs.flatDefined
        case let (l?, r?): return l == r
        default: return lhs.byteCount == rhs.byteCount && lhs.bytes == rhs.bytes && lhs.defined == rhs.defined
        }
    }

    private func checkedRange(_ offset: Int, _ count: Int) throws -> Range<Int> {
        let total = byteCount
        guard offset >= 0, count >= 0, count <= total, offset <= total - count else {
            throw OriginalStateError.outOfBounds(offset: offset, count: count)
        }
        return offset..<(offset + count)
    }

    /// A typed read cannot silently promote allocator contents to a game default.
    public func integer<T: FixedWidthInteger>(at offset: Int, as type: T.Type) throws -> T {
        let region = try checkedRange(offset, T.bitWidth / 8)
        guard let pages else {
            // The checks and value of the slice and reduce this replaced, read
            // through the buffers: every byte defined, then the little-endian
            // value (CORE_REALTIME phase 4c; reads are most of the Core's record
            // traffic).
            let count = region.count
            let defined = flatDefined.withUnsafeBufferPointer { d in
                var all = true
                for i in region where !d[i] { all = false; break }
                return all
            }
            guard defined else { throw OriginalStateError.undefinedBytes(offset: offset, count: count) }
            return flatBytes.withUnsafeBytes { T(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: T.self)) }
        }
        guard region.allSatisfy({ pages.defined[$0 >> Self.pageShift][$0 & Self.pageMask] }) else {
            throw OriginalStateError.undefinedBytes(offset: offset, count: region.count)
        }
        return region.enumerated().reduce(T.zero) {
            $0 | (T(truncatingIfNeeded: pages.bytes[$1.element >> Self.pageShift][$1.element & Self.pageMask]) << ($1.offset * 8))
        }
    }

    public func binary64(at offset: Int) throws -> Double {
        Double(bitPattern: try integer(at: offset, as: UInt64.self))
    }

    /// Writes preserve exact integer/floating-point bit patterns; no host-width pointer conversion.
    public mutating func write<T: FixedWidthInteger>(_ value: T, at offset: Int) throws {
        let region = try checkedRange(offset, T.bitWidth / 8)
        if pages == nil {
            // Storing the bytes already there, all defined, changes nothing;
            // returning leaves a buffer that a rollback copy shares untouched
            // instead of copying the whole record (CORE_REALTIME phase 2d).
            if flatHolds(value, region) { return }
            for (shift, index) in region.enumerated() {
                flatBytes[index] = UInt8(truncatingIfNeeded: value >> (shift * 8))
                flatDefined[index] = true
            }
        } else {
            pages!.willWrite()
            for (shift, index) in region.enumerated() {
                pages!.bytes[index >> Self.pageShift][index & Self.pageMask] = UInt8(truncatingIfNeeded: value >> (shift * 8))
                pages!.defined[index >> Self.pageShift][index & Self.pageMask] = true
            }
        }
    }

    /// Copies `record`'s bytes and definedness over start..<start+record.byteCount
    /// in place (at most one copy if this record's storage is shared, none
    /// when the range already holds the record). The caller has
    /// checked the extent; the result equals rebuilding the record from arrays
    /// with that subrange replaced (MOBILE_PERFORMANCE step 8).
    mutating func overwrite(at start: Int, with record: OriginalStateRecord) {
        let count = record.byteCount
        precondition(start >= 0 && count <= byteCount && start <= byteCount - count, "record overwrite extent")
        if pages == nil && record.pages == nil {
            // An overwrite with the bytes and definedness already there changes
            // nothing (phase 2d, as in write).
            if flatHolds(record, at: start) { return }
            flatBytes.replaceSubrange(start..<start + count, with: record.flatBytes)
            flatDefined.replaceSubrange(start..<start + count, with: record.flatDefined)
            return
        }
        let bytes = record.bytes, defined = record.defined
        if pages == nil {
            flatBytes.replaceSubrange(start..<start + count, with: bytes)
            flatDefined.replaceSubrange(start..<start + count, with: defined)
            return
        }
        pages!.willWrite()
        for k in 0..<count {
            let index = start + k
            pages!.bytes[index >> Self.pageShift][index & Self.pageMask] = bytes[k]
            pages!.defined[index >> Self.pageShift][index & Self.pageMask] = defined[k]
        }
    }

    /// Whether the flat bytes over `region` are `value`'s little-endian bytes,
    /// all defined.
    private func flatHolds<T: FixedWidthInteger>(_ value: T, _ region: Range<Int>) -> Bool {
        for (shift, index) in region.enumerated() {
            if !flatDefined[index] || flatBytes[index] != UInt8(truncatingIfNeeded: value >> (shift * 8)) { return false }
        }
        return true
    }
    /// Whether this flat record already holds flat `record`'s bytes and
    /// definedness at `start` (the caller checked the extent).
    private func flatHolds(_ record: OriginalStateRecord, at start: Int) -> Bool {
        let count = record.flatBytes.count
        guard count > 0 else { return true }
        func same<E>(_ a: [E], _ b: [E]) -> Bool {
            a.withUnsafeBytes { a in b.withUnsafeBytes { b in
                memcmp(a.baseAddress! + start * MemoryLayout<E>.stride, b.baseAddress!, count * MemoryLayout<E>.stride) == 0
            } }
        }
        return same(flatBytes, record.flatBytes) && same(flatDefined, record.flatDefined)
    }

    public mutating func writeBinary64(_ value: Double, at offset: Int) throws {
        try write(value.bitPattern, at: offset)
    }

    private mutating func zero(_ region: Range<Int>) {
        if pages == nil {
            for index in region { flatBytes[index] = 0; flatDefined[index] = true }
        } else {
            pages!.willWrite()
            for index in region {
                pages!.bytes[index >> Self.pageShift][index & Self.pageMask] = 0
                pages!.defined[index >> Self.pageShift][index & Self.pageMask] = true
            }
        }
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
        guard byteCount == Self.actorSize else {
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
