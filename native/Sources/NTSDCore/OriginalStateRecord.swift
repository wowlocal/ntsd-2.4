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
    /// Pages of 16 KiB in groups of 16 pages (CORE_REALTIME tier 3 S1): a
    /// copy that is then written duplicates the group table (~25 references
    /// per array), one group (16) and one page, not the whole page table
    /// (~400 references per array).
    private static let pageShift = 14, pageMask = (1 << 14) - 1
    private static let groupShift = 18, groupPageMask = (1 << (18 - 14)) - 1

    private var flatBytes: [UInt8]
    private var flatDefined: [Bool]
    /// Paged or parted storage, nil for a flat record: one field, so a flat
    /// record (nearly every record) copies as before the parts existed
    /// (CORE_REALTIME B1: a separate optional field cost the phone ~1 ms per
    /// tick in copies).
    private var large: Large?
    private enum Large { case pages(Pages), parts(Parts) }
    /// Read-only: paged writes go through `withPages`, which moves the pages
    /// out so their buffers stay uniquely referenced.
    private var pages: Pages? { if case .pages(let value)? = large { return value }; return nil }
    /// The menu state's `full` record in fixed flat parts (CORE_REALTIME B1,
    /// docs/research/CORE_REALTIME_B1.md): a slice or overwrite at one part's
    /// exact extent shares or installs that part's buffers; every other
    /// operation runs over the logical offsets with the flat record's results
    /// and errors. Set only by `partitioned(at:)`. `_modify` moves the object
    /// out so `isKnownUniquelyReferenced` sees the only reference.
    private var parts: Parts? {
        get { if case .parts(let value)? = large { return value }; return nil }
        _modify {
            var value: Parts? = nil, was = false
            if case .parts(let current)? = large { value = current; large = nil; was = true }
            defer { if let value { large = .parts(value) } else if was { large = nil } }
            yield &value
        }
    }

    private final class Parts: @unchecked Sendable {
        /// Flat records; `starts[i]` is part i's first byte, `starts.last` the total.
        var records: [OriginalStateRecord]
        let starts: [Int]
        /// The assembled contents for whole reads (tests and diagnostics),
        /// guarded by `OriginalStateRecord.assemblyLock`: one lock for every
        /// parts object, so copying one before a write allocates no lock.
        private var bytes: [UInt8]?, defined: [Bool]?
        init(records: [OriginalStateRecord], starts: [Int]) { self.records = records; self.starts = starts }
        var count: Int { starts[starts.count - 1] }
        /// The part holding `offset` (0 <= offset < count).
        func index(of offset: Int) -> Int {
            var k = 0
            while starts[k + 1] <= offset { k += 1 }
            return k
        }
        func byte(_ index: Int) -> UInt8 { let k = self.index(of: index); return records[k].flatBytes[index - starts[k]] }
        func isDefined(_ index: Int) -> Bool { let k = self.index(of: index); return records[k].flatDefined[index - starts[k]] }
        /// The same parts and an empty cache (for a copy about to be written).
        func copy() -> Parts { Parts(records: records, starts: starts) }
        func clearCache() {
            OriginalStateRecord.assemblyLock.lock(); bytes = nil; defined = nil; OriginalStateRecord.assemblyLock.unlock()
        }
        func wholeBytes() -> [UInt8] {
            OriginalStateRecord.assemblyLock.lock(); defer { OriginalStateRecord.assemblyLock.unlock() }
            if let bytes { return bytes }
            OriginalStateRecord.assemblies += 1
            let made = records.flatMap(\.flatBytes); bytes = made; return made
        }
        func wholeDefined() -> [Bool] {
            OriginalStateRecord.assemblyLock.lock(); defer { OriginalStateRecord.assemblyLock.unlock() }
            if let defined { return defined }
            OriginalStateRecord.assemblies += 1
            let made = records.flatMap(\.flatDefined); defined = made; return made
        }
        /// Calls `body(part, local range)` for each run of `range`, in order.
        func forEachRun(_ range: Range<Int>, _ body: (OriginalStateRecord, Range<Int>) -> Void) {
            var index = range.lowerBound
            while index < range.upperBound {
                let k = self.index(of: index), local = index - starts[k]
                let n = min(range.upperBound - index, records[k].flatBytes.count - local)
                body(records[k], local..<local + n)
                index += n
            }
        }
        func runBytes(_ range: Range<Int>) -> [UInt8] {
            var bytes = [UInt8](); bytes.reserveCapacity(range.count)
            forEachRun(range) { part, local in bytes.append(contentsOf: part.flatBytes[local]) }
            return bytes
        }
        func runAllDefined(_ range: Range<Int>) -> Bool {
            var all = true
            forEachRun(range) { part, local in if all && part.flatDefined[local].contains(false) { all = false } }
            return all
        }
        /// Whether these parts hold flat `record`'s bytes and definedness, part
        /// by part without assembling.
        func equalsFlat(_ record: OriginalStateRecord) -> Bool {
            guard record.flatBytes.count == count else { return false }
            for (k, part) in records.enumerated() where !part.flatHolds(record, from: starts[k]) { return false }
            return true
        }
        /// The bytes and definedness over `range`, run by run, without the
        /// cache. Reading the whole record this way (`readOnce`, `flattened`,
        /// `==` across layouts) counts as an assembly too.
        func runs(_ range: Range<Int>) -> (bytes: [UInt8], defined: [Bool]) {
            if range == 0..<count { OriginalStateRecord.countAssembly() }
            var bytes = [UInt8](), defined = [Bool]()
            bytes.reserveCapacity(range.count); defined.reserveCapacity(range.count)
            var index = range.lowerBound
            while index < range.upperBound {
                let k = self.index(of: index), local = index - starts[k]
                let n = min(range.upperBound - index, records[k].flatBytes.count - local)
                bytes.append(contentsOf: records[k].flatBytes[local..<local + n])
                defined.append(contentsOf: records[k].flatDefined[local..<local + n])
                index += n
            }
            return (bytes, defined)
        }
    }
    fileprivate static let assemblyLock = NSLock()
    nonisolated(unsafe) fileprivate static var assemblies = 0
    fileprivate static func countAssembly() { assemblyLock.lock(); assemblies += 1; assemblyLock.unlock() }
    /// Whole-record reads of parted records, cached or not (a probe:
    /// production ticks should never read the menu state's `full` whole).
    public static var partAssemblies: Int { assemblyLock.lock(); defer { assemblyLock.unlock() }; return assemblies }

    /// Runs `body` on the pages moved out of `large` (so they are uniquely
    /// referenced and written in place), then puts them back.
    private mutating func withPages(_ body: (inout Pages) -> Void) {
        guard case .pages(var paged)? = large else { preconditionFailure("paged record") }
        large = nil; body(&paged); large = .pages(paged)
    }
    /// Before writing a part: a shared parts object is copied, a unique one's
    /// assembled contents are dropped.
    private mutating func makePartsUnique() {
        if isKnownUniquelyReferenced(&parts) { parts!.clearCache() } else { parts = parts!.copy() }
    }

    /// This record split into flat parts at `starts` (0 first, strictly
    /// increasing, below the total): the same contents (CORE_REALTIME B1).
    func partitioned(at starts: [Int]) -> OriginalStateRecord {
        let total = byteCount, bounds = starts + [total]
        precondition(starts.first == 0 && zip(bounds, bounds.dropFirst()).allSatisfy { $0 < $1 } && total < Self.pagedThreshold,
                     "record parts")
        if let parts, parts.starts == bounds { return self }
        let all = readOnce()
        var made = self
        made.large = .parts(Parts(records: (0..<starts.count).map { i in
            try! Self(bytes: Array(all.bytes[bounds[i]..<bounds[i + 1]]), defined: Array(all.defined[bounds[i]..<bounds[i + 1]]))
        }, starts: bounds))
        made.flatBytes = []; made.flatDefined = []
        return made
    }
    var isPartitioned: Bool { parts != nil }
    /// A parted record as one flat record with the same contents; any other
    /// record unchanged.
    func flattened() -> OriginalStateRecord {
        guard parts != nil else { return self }
        let all = readOnce()
        return try! Self(bytes: all.bytes, defined: all.defined)
    }
    /// The addresses of a non-empty flat record's byte and definedness
    /// buffers (nil for an empty, paged or parted record). Two flat records
    /// with the same identity share both buffers and are equal, provided the
    /// caller keeps a record holding them alive (CORE_REALTIME 4j).
    var storageIdentity: (UInt, UInt)? {
        guard large == nil, !flatBytes.isEmpty else { return nil }
        let bytes = flatBytes.withUnsafeBufferPointer { UInt(bitPattern: $0.baseAddress) }
        return (bytes, flatDefined.withUnsafeBufferPointer { UInt(bitPattern: $0.baseAddress) })
    }
    /// For two paged records of the same size: how many groups and pages share
    /// both their byte and definedness buffers (a probe, CORE_REALTIME tier 3
    /// S1: a copy that is then written once keeps all but one of each).
    func sharedPages(with other: OriginalStateRecord) -> (groups: Int, pages: Int)? {
        guard let a = pages, let b = other.pages, a.count == b.count else { return nil }
        func base<Element>(_ array: [Element]) -> UnsafeRawPointer? { array.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) } }
        var groups = 0, shared = 0
        for g in a.bytes.indices {
            if base(a.bytes[g]) == base(b.bytes[g]) && base(a.defined[g]) == base(b.defined[g]) { groups += 1 }
            for p in a.bytes[g].indices where base(a.bytes[g][p]) == base(b.bytes[g][p]) && base(a.defined[g][p]) == base(b.defined[g][p]) {
                shared += 1
            }
        }
        return (groups, shared)
    }
    /// The addresses of the group table, the group and the byte page holding
    /// `index` in a paged record (a probe: a write that finds them unique
    /// leaves them where they were).
    func pageAddresses(at index: Int) -> [UnsafeRawPointer?]? {
        guard let pages else { return nil }
        func base<Element>(_ array: [Element]) -> UnsafeRawPointer? { array.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) } }
        let group = index >> Self.groupShift, page = (index >> Self.pageShift) & Self.groupPageMask
        return [base(pages.bytes), base(pages.bytes[group]), base(pages.bytes[group][page]),
                base(pages.defined), base(pages.defined[group]), base(pages.defined[group][page])]
    }
    /// The number of groups and pages of a paged record (nil otherwise).
    var pageLayout: (groups: Int, pages: Int)? {
        guard let pages else { return nil }
        return (pages.bytes.count, pages.bytes.reduce(0) { $0 + $1.count })
    }
    /// An empty record that allocates nothing: what an in-place pass leaves in
    /// a caller's field while it holds the value (CORE_REALTIME B2).
    static let vacant = try! OriginalStateRecord(bytes: [], defined: [])
    /// Whether both are flat and share their byte and definedness buffers.
    func sharesStorage(with other: OriginalStateRecord) -> Bool {
        guard pages == nil, parts == nil, other.pages == nil, other.parts == nil, flatBytes.count == other.flatBytes.count else { return false }
        let bytes = flatBytes.withUnsafeBufferPointer { a in other.flatBytes.withUnsafeBufferPointer { b in a.baseAddress == b.baseAddress } }
        return bytes && flatDefined.withUnsafeBufferPointer { a in other.flatDefined.withUnsafeBufferPointer { b in a.baseAddress == b.baseAddress } }
    }
    /// `try! Self(bytes: Array(bytes[range]), defined: Array(defined[range]))`
    /// (the caller has checked `range`), sharing a part's buffers when
    /// `range` is exactly that part.
    func extract(_ range: Range<Int>) -> OriginalStateRecord {
        if parts != nil && range.isEmpty { return try! Self(bytes: [], defined: []) }
        if let parts {
            let k = parts.index(of: range.lowerBound), local = range.lowerBound - parts.starts[k]
            if local == 0 && range.count == parts.records[k].flatBytes.count { return parts.records[k] }
            let runs = parts.runs(range)
            return try! Self(bytes: runs.bytes, defined: runs.defined)
        }
        return try! Self(bytes: Array(bytes[range]), defined: Array(defined[range]))
    }
    /// `Array(bytes[range])` without assembling a parted record.
    public func bytes(in range: Range<Int>) -> [UInt8] {
        if let parts {
            precondition(range.lowerBound >= 0 && range.upperBound <= parts.count, "Range out of bounds")
            return parts.runBytes(range)
        }
        return Array(bytes[range])
    }
    /// `bytes[index]` without the whole contents (CORE_REALTIME tier 3 S2a).
    public func byte(at index: Int) -> UInt8 {
        if let parts { precondition(index >= 0 && index < parts.count, "Index out of range"); return parts.byte(index) }
        if let pages { precondition(index >= 0 && index < pages.count, "Index out of range"); return pages.byte(index) }
        return flatBytes[index]
    }
    /// `defined[index]` without the whole mask (S2a).
    public func isDefined(at index: Int) -> Bool {
        if let parts { precondition(index >= 0 && index < parts.count, "Index out of range"); return parts.isDefined(index) }
        if let pages { precondition(index >= 0 && index < pages.count, "Index out of range"); return pages.isDefined(index) }
        return flatDefined[index]
    }
    /// Whether every byte in `range` is defined (`!defined[range].contains(false)`).
    public func allDefined(in range: Range<Int>) -> Bool {
        if let parts {
            precondition(range.lowerBound >= 0 && range.upperBound <= parts.count, "Range out of bounds")
            return parts.runAllDefined(range)
        }
        return !defined[range].contains(false)
    }

    private struct Pages: Equatable, Sendable {
        /// Groups of pages: `bytes[group][page][offset]`.
        var bytes: [[[UInt8]]]
        var defined: [[[Bool]]]
        /// The assembled contents, built on first read and shared by copies
        /// with the same contents; every write starts a new one.
        var whole = Whole()
        init(bytes: [UInt8], defined: [Bool]) {
            self.bytes = Self.split(bytes)
            self.defined = Self.split(defined)
        }
        /// Computed, not stored: `Large` sits inline in every record, and a
        /// fourth word in `Pages` would grow every record past 40 bytes
        /// (CORE_REALTIME B1: that cost the phone ~1 ms per tick).
        var count: Int {
            guard let last = bytes.last, let page = last.last else { return 0 }
            return ((bytes.count - 1) << OriginalStateRecord.groupShift) + ((last.count - 1) << OriginalStateRecord.pageShift) + page.count
        }
        private static func split<Element>(_ all: [Element]) -> [[[Element]]] {
            let page = 1 << OriginalStateRecord.pageShift, group = 1 << OriginalStateRecord.groupShift
            return stride(from: 0, to: all.count, by: group).map { first in
                stride(from: first, to: min(first + group, all.count), by: page).map { Array(all[$0..<min($0 + page, all.count)]) }
            }
        }
        static func == (lhs: Pages, rhs: Pages) -> Bool { lhs.bytes == rhs.bytes && lhs.defined == rhs.defined }
        func byte(_ index: Int) -> UInt8 {
            bytes[index >> OriginalStateRecord.groupShift][(index >> OriginalStateRecord.pageShift) & OriginalStateRecord.groupPageMask][index & OriginalStateRecord.pageMask]
        }
        func isDefined(_ index: Int) -> Bool {
            defined[index >> OriginalStateRecord.groupShift][(index >> OriginalStateRecord.pageShift) & OriginalStateRecord.groupPageMask][index & OriginalStateRecord.pageMask]
        }
        mutating func set(_ index: Int, _ byte: UInt8, defined isDefined: Bool = true) {
            let group = index >> OriginalStateRecord.groupShift
            let page = (index >> OriginalStateRecord.pageShift) & OriginalStateRecord.groupPageMask
            let offset = index & OriginalStateRecord.pageMask
            bytes[group][page][offset] = byte
            defined[group][page][offset] = isDefined
        }
        mutating func willWrite() {
            if isKnownUniquelyReferenced(&whole) { whole.clear() } else { whole = Whole() }
        }
    }

    private final class Whole: @unchecked Sendable {
        private let lock = NSLock()
        private var bytes: [UInt8]?, defined: [Bool]?
        func bytes(_ pages: [[[UInt8]]], _ count: Int) -> [UInt8] {
            lock.lock(); defer { lock.unlock() }
            if let bytes { return bytes }
            let made = assemble(pages, count)
            bytes = made
            return made
        }
        func defined(_ pages: [[[Bool]]], _ count: Int) -> [Bool] {
            lock.lock(); defer { lock.unlock() }
            if let defined { return defined }
            let made = assemble(pages, count)
            defined = made
            return made
        }
        func clear() { lock.lock(); bytes = nil; defined = nil; lock.unlock() }
    }

    private static func assemble<Element>(_ groups: [[[Element]]], _ count: Int) -> [Element] {
        var made = [Element](); made.reserveCapacity(count)
        for group in groups { for page in group { made.append(contentsOf: page) } }
        return made
    }

    /// The whole contents for a single read, without filling a paged record's
    /// cache: the replay writer reads its buffers once and then frees them,
    /// and a freed allocation keeps its storage.
    func readOnce() -> (bytes: [UInt8], defined: [Bool]) {
        if let parts { return parts.runs(0..<parts.count) }
        guard let pages else { return (flatBytes, flatDefined) }
        return (Self.assemble(pages.bytes, pages.count), Self.assemble(pages.defined, pages.count))
    }

    /// `Array(bytes.prefix(count))` without assembling a paged record.
    func leadingBytes(_ count: Int) -> [UInt8] {
        if let parts {
            precondition(count >= 0, "Can't take a prefix of negative length from a collection")
            return parts.runs(0..<min(count, parts.count)).bytes
        }
        guard let pages else { return Array(flatBytes.prefix(count)) }
        precondition(count >= 0, "Can't take a prefix of negative length from a collection")
        var made = [UInt8](); made.reserveCapacity(min(count, pages.count))
        for group in pages.bytes { for page in group where made.count < count { made.append(contentsOf: page.prefix(count - made.count)) } }
        return made
    }

    /// The whole contents. A paged record assembles them once per written
    /// version (code may index `bytes[i]` in a loop); hot paths use
    /// `byteCount` and the typed accessors.
    public var bytes: [UInt8] {
        if let parts { return parts.wholeBytes() }
        guard let pages else { return flatBytes }
        return pages.whole.bytes(pages.bytes, pages.count)
    }
    public var defined: [Bool] {
        if let parts { return parts.wholeDefined() }
        guard let pages else { return flatDefined }
        return pages.whole.defined(pages.defined, pages.count)
    }
    public var byteCount: Int {
        if large == nil { return flatBytes.count }
        return parts?.count ?? pages?.count ?? flatBytes.count
    }

    public init(bytes: [UInt8], defined: [Bool]) throws {
        guard bytes.count == defined.count else {
            throw OriginalStateError.invalidStorage("byte and initialization-mask lengths differ")
        }
        if bytes.count >= Self.pagedThreshold {
            large = .pages(Pages(bytes: bytes, defined: defined))
            flatBytes = []
            flatDefined = []
        } else {
            flatBytes = bytes
            flatDefined = defined
            large = nil
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.parts != nil || rhs.parts != nil {
            guard lhs.byteCount == rhs.byteCount else { return false }
            if let l = lhs.parts, let r = rhs.parts, l.starts == r.starts { return l === r || l.records == r.records }
            if let l = lhs.parts, rhs.parts == nil, rhs.pages == nil { return l.equalsFlat(rhs) }
            if let r = rhs.parts, lhs.parts == nil, lhs.pages == nil { return r.equalsFlat(lhs) }
            let l = lhs.readOnce(), r = rhs.readOnce()
            return l.bytes == r.bytes && l.defined == r.defined
        }
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

    /// Whether `count` mask bytes from `offset` are all `true`: one load
    /// against 0x01 bytes for the widths integers use (a Bool is stored as
    /// one byte, 0 or 1), the general check otherwise (CORE_REALTIME 4w).
    @inline(__always) private static func allDefined(_ mask: UnsafeRawBufferPointer, _ offset: Int, _ count: Int) -> Bool {
        switch count {
        case 1: return mask.load(fromByteOffset: offset, as: UInt8.self) == 1
        case 2: return mask.loadUnaligned(fromByteOffset: offset, as: UInt16.self) == 0x0101
        case 4: return mask.loadUnaligned(fromByteOffset: offset, as: UInt32.self) == 0x0101_0101
        case 8: return mask.loadUnaligned(fromByteOffset: offset, as: UInt64.self) == 0x0101_0101_0101_0101
        default: return !mask[offset..<(offset + count)].contains(0)
        }
    }
    /// Marks `count` mask bytes from `offset` defined (the widths integers use
    /// in one store).
    @inline(__always) private static func setDefined(_ mask: UnsafeMutableRawBufferPointer, _ offset: Int, _ count: Int) {
        switch count {
        case 1: mask.storeBytes(of: UInt8(1), toByteOffset: offset, as: UInt8.self)
        case 2: mask.storeBytes(of: UInt16(0x0101), toByteOffset: offset, as: UInt16.self)
        case 4: mask.storeBytes(of: UInt32(0x0101_0101), toByteOffset: offset, as: UInt32.self)
        case 8: mask.storeBytes(of: UInt64(0x0101_0101_0101_0101), toByteOffset: offset, as: UInt64.self)
        default: for i in offset..<(offset + count) { mask[i] = 1 }
        }
    }

    /// A typed read cannot silently promote allocator contents to a game default.
    public func integer<T: FixedWidthInteger>(at offset: Int, as type: T.Type) throws -> T {
        if large == nil {
            // A flat record (nearly every one): the range check, definedness
            // and value with one load each, the same errors in the same order
            // as below (CORE_REALTIME 4w).
            let count = T.bitWidth / 8, total = flatBytes.count
            guard offset >= 0, count <= total, offset <= total - count else {
                throw OriginalStateError.outOfBounds(offset: offset, count: count)
            }
            guard flatDefined.withUnsafeBytes({ Self.allDefined($0, offset, count) }) else {
                throw OriginalStateError.undefinedBytes(offset: offset, count: count)
            }
            return flatBytes.withUnsafeBytes { T(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: T.self)) }
        }
        let region = try checkedRange(offset, T.bitWidth / 8)
        if let parts {
            // Within one part, as the flat read below at the part's offset;
            // across a boundary, every byte checked, then assembled. Errors
            // carry the logical offset.
            let count = region.count, k = parts.index(of: offset), local = offset - parts.starts[k]
            if local + count <= parts.records[k].flatBytes.count {
                let part = parts.records[k]
                let defined = part.flatDefined.withUnsafeBufferPointer { d in !d[local..<local + count].contains(false) }
                guard defined else { throw OriginalStateError.undefinedBytes(offset: offset, count: count) }
                return part.flatBytes.withUnsafeBytes { T(littleEndian: $0.loadUnaligned(fromByteOffset: local, as: T.self)) }
            }
            guard region.allSatisfy({ parts.isDefined($0) }) else { throw OriginalStateError.undefinedBytes(offset: offset, count: count) }
            return region.enumerated().reduce(T.zero) { $0 | (T(truncatingIfNeeded: parts.byte($1.element)) << ($1.offset * 8)) }
        }
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
        guard region.allSatisfy({ pages.isDefined($0) }) else {
            throw OriginalStateError.undefinedBytes(offset: offset, count: region.count)
        }
        return region.enumerated().reduce(T.zero) { $0 | (T(truncatingIfNeeded: pages.byte($1.element)) << ($1.offset * 8)) }
    }

    /// The little-endian word at `offset`, defined or not (`bytes[offset..<offset+4]`
    /// as a value), read in place: the caller checks the range. Bitmap draws
    /// read allocator words this way many times per frame, and each `bytes`
    /// read retained and released the whole array (CORE_REALTIME 4s).
    func rawWord(at offset: Int) -> UInt32 {
        precondition(offset >= 0 && offset <= byteCount - 4, "Range out of bounds")
        if let parts { return (0..<4).reduce(UInt32(0)) { $0 | UInt32(parts.byte(offset + $1)) << ($1 * 8) } }
        if let pages {
            return (0..<4).reduce(UInt32(0)) { $0 | UInt32(pages.byte(offset + $1)) << ($1 * 8) }
        }
        return flatBytes.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
    }

    /// The bytes start..<start+count when all are in range and defined, else
    /// nil (the caller then reads them one by one for the exact error).
    func definedBytes(_ start: Int, _ count: Int) -> [UInt8]? {
        guard start >= 0, count >= 0, count <= byteCount, start <= byteCount - count else { return nil }
        let range = start..<(start + count)
        if let parts {
            let runs = parts.runs(range)
            return runs.defined.contains(false) ? nil : runs.bytes
        }
        if let pages {
            return range.allSatisfy({ pages.isDefined($0) }) ? range.map { pages.byte($0) } : nil
        }
        let all = flatDefined.withUnsafeBufferPointer { d in !d[range].contains(false) }
        return all ? Array(flatBytes[range]) : nil
    }

    public func binary64(at offset: Int) throws -> Double {
        Double(bitPattern: try integer(at: offset, as: UInt64.self))
    }

    /// Writes preserve exact integer/floating-point bit patterns; no host-width pointer conversion.
    public mutating func write<T: FixedWidthInteger>(_ value: T, at offset: Int) throws {
        if large == nil {
            // A flat record: the same check and no-op return as below, then
            // one store each for the bytes and their definedness (at most one
            // copy of each array if shared, as the per-byte stores made;
            // CORE_REALTIME 4w).
            let count = T.bitWidth / 8, total = flatBytes.count
            guard offset >= 0, count <= total, offset <= total - count else {
                throw OriginalStateError.outOfBounds(offset: offset, count: count)
            }
            if flatBytes.withUnsafeBytes({ T(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: T.self)) }) == value,
               flatDefined.withUnsafeBytes({ Self.allDefined($0, offset, count) }) { return }
            flatBytes.withUnsafeMutableBytes { $0.storeBytes(of: value.littleEndian, toByteOffset: offset, as: T.self) }
            flatDefined.withUnsafeMutableBytes { Self.setDefined($0, offset, count) }
            return
        }
        let region = try checkedRange(offset, T.bitWidth / 8)
        if parts != nil {
            // Within one part as the flat write (the same no-op return keeps
            // the part shared); across a boundary byte by byte.
            let count = region.count, k = parts!.index(of: offset), local = offset - parts!.starts[k]
            if local + count <= parts!.records[k].flatBytes.count {
                if parts!.records[k].flatHolds(value, local..<local + count) { return }
                makePartsUnique()
                for (shift, index) in (local..<local + count).enumerated() {
                    parts!.records[k].flatBytes[index] = UInt8(truncatingIfNeeded: value >> (shift * 8))
                    parts!.records[k].flatDefined[index] = true
                }
                return
            }
            if region.enumerated().allSatisfy({ parts!.isDefined($1) && parts!.byte($1) == UInt8(truncatingIfNeeded: value >> ($0 * 8)) }) { return }
            makePartsUnique()
            for (shift, index) in region.enumerated() {
                let k = parts!.index(of: index), local = index - parts!.starts[k]
                parts!.records[k].flatBytes[local] = UInt8(truncatingIfNeeded: value >> (shift * 8))
                parts!.records[k].flatDefined[local] = true
            }
            return
        }
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
            withPages { pages in
                pages.willWrite()
                for (shift, index) in region.enumerated() { pages.set(index, UInt8(truncatingIfNeeded: value >> (shift * 8))) }
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
        if parts != nil {
            // An exact part extent installs the source (shared); within one
            // part as the flat overwrite; across parts part by part.
            guard count > 0 else { return }
            let source = record.pages == nil && record.parts == nil ? record : record.flattened()
            let k = parts!.index(of: start), local = start - parts!.starts[k], partCount = parts!.records[k].flatBytes.count
            if local == 0 && count == partCount {
                if parts!.records[k].sharesStorage(with: source) { return }
                makePartsUnique(); parts!.records[k] = source; return
            }
            if local + count <= partCount {
                if parts!.records[k].flatHolds(source, at: local) { return }
                makePartsUnique(); parts!.records[k].overwrite(at: local, with: source); return
            }
            makePartsUnique()
            var offset = 0
            while offset < count {
                let index = start + offset, k = parts!.index(of: index), local = index - parts!.starts[k]
                let n = min(count - offset, parts!.records[k].flatBytes.count - local)
                parts!.records[k].overwrite(at: local, with: source.extract(offset..<offset + n))
                offset += n
            }
            return
        }
        if pages == nil && record.pages == nil && record.parts == nil {
            // An overwrite with the bytes and definedness already there changes
            // nothing (phase 2d, as in write).
            if flatHolds(record, at: start) { return }
            flatBytes.replaceSubrange(start..<start + count, with: record.flatBytes)
            flatDefined.replaceSubrange(start..<start + count, with: record.flatDefined)
            return
        }
        if pages == nil, let source = record.parts {
            // A parted source onto a flat target, run by run without assembling.
            var index = start
            source.forEachRun(0..<count) { part, local in
                flatBytes.replaceSubrange(index..<index + local.count, with: part.flatBytes[local])
                flatDefined.replaceSubrange(index..<index + local.count, with: part.flatDefined[local])
                index += local.count
            }
            return
        }
        let bytes = record.bytes, defined = record.defined
        if pages == nil {
            flatBytes.replaceSubrange(start..<start + count, with: bytes)
            flatDefined.replaceSubrange(start..<start + count, with: defined)
            return
        }
        withPages { pages in
            pages.willWrite()
            for k in 0..<count {
                pages.set(start + k, bytes[k], defined: defined[k])
            }
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
    /// Whether this flat record equals flat `record`'s window starting at
    /// `start` (same length as this record).
    private func flatHolds(_ record: OriginalStateRecord, from start: Int) -> Bool {
        let count = flatBytes.count
        guard count > 0 else { return true }
        func same<E>(_ a: [E], _ b: [E]) -> Bool {
            a.withUnsafeBytes { a in b.withUnsafeBytes { b in
                memcmp(a.baseAddress!, b.baseAddress! + start * MemoryLayout<E>.stride, count * MemoryLayout<E>.stride) == 0
            } }
        }
        return same(flatBytes, record.flatBytes) && same(flatDefined, record.flatDefined)
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
        if parts != nil {
            guard !region.isEmpty else { return }
            makePartsUnique()
            for index in region {
                let k = parts!.index(of: index)
                parts!.records[k].flatBytes[index - parts!.starts[k]] = 0
                parts!.records[k].flatDefined[index - parts!.starts[k]] = true
            }
            return
        }
        if pages == nil {
            for index in region { flatBytes[index] = 0; flatDefined[index] = true }
        } else {
            withPages { pages in
                pages.willWrite()
                for index in region { pages.set(index, 0) }
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

/// Moves `value` out, leaving `placeholder` (CORE_REALTIME B2): an in-place
/// pass then holds the only reference, so its writes change no shared buffer.
@inline(__always) func inPlaceTake<T>(_ value: inout T, leaving placeholder: T) -> T {
    var taken = placeholder
    swap(&taken, &value)
    return taken
}
