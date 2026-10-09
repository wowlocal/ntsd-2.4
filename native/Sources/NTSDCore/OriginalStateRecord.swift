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

    /// A flat record's bytes and definedness (nil when it is empty, paged or
    /// parted) and its byte count (0 then): one allocation with a bit mask
    /// instead of a byte array and a Bool array per record, so a copy that is
    /// written duplicates one buffer of count + count/8 bytes (CORE_REALTIME
    /// tier 3 S2b). The count sits inline: byteCount is read everywhere, and
    /// the record stays 40 bytes.
    private var flat: Flat?
    private var flatCount: Int
    /// Paged or parted storage, nil for a flat record: one field, so a flat
    /// record (nearly every record) copies as before the parts existed
    /// (CORE_REALTIME B1: a separate optional field cost the phone ~1 ms per
    /// tick in copies).
    private var large: Large?
    private enum Large { case pages(Pages), parts(Parts) }

    /// A flat record's storage: the bytes, then the definedness bit mask
    /// (bit i&7 of mask byte i>>3 is byte i's; bits at and past the count stay
    /// zero), then 8 zero bytes so a two-byte mask load and the widest
    /// unaligned load stay inside. Never empty: an empty record has none.
    /// Written only while uniquely referenced (as an Array's buffer).
    private struct FlatHeader { var count: Int; var whole: FlatWhole? }
    /// A flat record's whole arrays, built on the first whole read of a
    /// written version and dropped by the next in-place write, so code that
    /// indexes `bytes[i]` in a loop stays linear as with the old arrays
    /// (guarded by `flatWholeLock`; S2b).
    private final class FlatWhole: @unchecked Sendable { var bytes: [UInt8]?, defined: [Bool]? }
    fileprivate static let flatWholeLock = NSLock()
    private final class Flat: ManagedBuffer<FlatHeader, UInt8>, @unchecked Sendable {
        static func make(count n: Int) -> Flat {
            let size = n + (n + 7) / 8 + 8
            let made = unsafeDowncast(Flat.create(minimumCapacity: size) { _ in FlatHeader(count: n, whole: nil) }, to: Flat.self)
            made.withUnsafeMutablePointers { _, elements in elements.initialize(repeating: 0, count: size) }
            return made
        }
        static func make(bytes: [UInt8], defined: [Bool]) -> Flat? {
            guard !bytes.isEmpty else { return nil }
            let made = make(count: bytes.count)
            made.with { n, b, m in
                bytes.withUnsafeBufferPointer { b.update(from: $0.baseAddress!, count: n) }
                defined.withUnsafeBufferPointer { d in
                    var i = 0
                    while i < n {
                        var v: UInt8 = 0
                        for k in 0..<min(8, n - i) where d[i + k] { v |= 1 << UInt8(k) }
                        m[i >> 3] = v; i += 8
                    }
                }
            }
            return made
        }
        /// The count, the bytes and the mask.
        @inline(__always) func with<R>(_ body: (Int, UnsafeMutablePointer<UInt8>, UnsafeMutablePointer<UInt8>) throws -> R) rethrows -> R {
            try withUnsafeMutablePointers { header, elements in try body(header.pointee.count, elements, elements + header.pointee.count) }
        }
        /// A copy: the bytes and mask (its padding bits zero) copied once, the
        /// 8 pad bytes zeroed, nothing written twice.
        func copy() -> Flat {
            with { n, bytes, _ in
                let used = n + (n + 7) / 8
                let made = unsafeDowncast(Flat.create(minimumCapacity: used + 8) { _ in FlatHeader(count: n, whole: nil) }, to: Flat.self)
                made.withUnsafeMutablePointers { _, elements in
                    elements.initialize(from: bytes, count: used)
                    (elements + used).initialize(repeating: 0, count: 8)
                }
                return made
            }
        }
        func bytesArray(_ range: Range<Int>) -> [UInt8] {
            with { _, b, _ in Array(UnsafeBufferPointer(start: b + range.lowerBound, count: range.count)) }
        }
        func definedArray(_ range: Range<Int>) -> [Bool] { with { _, _, m in range.map { Flat.bit(m, $0) } } }
        /// The whole bytes and definedness, cached per written version.
        func wholeBytes() -> [UInt8] {
            OriginalStateRecord.flatWholeLock.lock(); defer { OriginalStateRecord.flatWholeLock.unlock() }
            return withUnsafeMutablePointers { header, elements in
                if let made = header.pointee.whole?.bytes { return made }
                let made = Array(UnsafeBufferPointer(start: elements, count: header.pointee.count))
                if header.pointee.whole == nil { header.pointee.whole = FlatWhole() }
                header.pointee.whole!.bytes = made
                return made
            }
        }
        func wholeDefined() -> [Bool] {
            OriginalStateRecord.flatWholeLock.lock(); defer { OriginalStateRecord.flatWholeLock.unlock() }
            return withUnsafeMutablePointers { header, elements in
                if let made = header.pointee.whole?.defined { return made }
                let n = header.pointee.count, mask = elements + n
                let made = (0..<n).map { Flat.bit(mask, $0) }
                if header.pointee.whole == nil { header.pointee.whole = FlatWhole() }
                header.pointee.whole!.defined = made
                return made
            }
        }
        /// Drops the cached whole arrays: called only while uniquely
        /// referenced, before an in-place write.
        func clearWhole() { withUnsafeMutablePointers { header, _ in if header.pointee.whole != nil { header.pointee.whole = nil } } }
        static func equal(_ a: Flat?, _ b: Flat?) -> Bool {
            if a === b { return true }
            guard let a, let b else { return false }
            return a.with { n, ab, _ in b.with { bn, bb, _ in n == bn && memcmp(ab, bb, n + (n + 7) / 8) == 0 } }
        }
        @inline(__always) static func bit(_ m: UnsafeMutablePointer<UInt8>, _ i: Int) -> Bool { m[i >> 3] & (1 << UInt8(i & 7)) != 0 }
        @inline(__always) static func set(_ m: UnsafeMutablePointer<UInt8>, _ i: Int) { m[i >> 3] |= 1 << UInt8(i & 7) }
        @inline(__always) static func put(_ m: UnsafeMutablePointer<UInt8>, _ i: Int, _ on: Bool) {
            if on { m[i >> 3] |= 1 << UInt8(i & 7) } else { m[i >> 3] &= ~(1 << UInt8(i & 7)) }
        }
        /// Whether bits offset..<offset+count are all set: one two-byte load for
        /// the widths integers use (1...8 bytes), the range check otherwise.
        @inline(__always) static func allSet(_ m: UnsafeMutablePointer<UInt8>, _ offset: Int, small count: Int) -> Bool {
            guard count <= 8 else { return allSet(m, offset..<offset + count) }
            let want = UInt16(truncatingIfNeeded: (1 << count) - 1) << UInt16(offset & 7)
            return UInt16(littleEndian: UnsafeRawPointer(m + (offset >> 3)).loadUnaligned(as: UInt16.self)) & want == want
        }
        @inline(__always) static func setAll(_ m: UnsafeMutablePointer<UInt8>, _ offset: Int, small count: Int) {
            guard count <= 8 else { setAll(m, offset..<offset + count); return }
            let want = UInt16(truncatingIfNeeded: (1 << count) - 1) << UInt16(offset & 7)
            let p = UnsafeMutableRawPointer(m + (offset >> 3))
            p.storeBytes(of: (UInt16(littleEndian: p.loadUnaligned(as: UInt16.self)) | want).littleEndian, as: UInt16.self)
        }
        static func allSet(_ m: UnsafeMutablePointer<UInt8>, _ range: Range<Int>) -> Bool {
            var i = range.lowerBound
            while i < range.upperBound && i & 7 != 0 { if !bit(m, i) { return false }; i += 1 }
            while i + 8 <= range.upperBound { if m[i >> 3] != 0xff { return false }; i += 8 }
            while i < range.upperBound { if !bit(m, i) { return false }; i += 1 }
            return true
        }
        static func setAll(_ m: UnsafeMutablePointer<UInt8>, _ range: Range<Int>) {
            var i = range.lowerBound
            while i < range.upperBound && i & 7 != 0 { set(m, i); i += 1 }
            while i + 8 <= range.upperBound { m[i >> 3] = 0xff; i += 8 }
            while i < range.upperBound { set(m, i); i += 1 }
        }
        /// Copies `count` bits from `source` at `from` to `target` at `to`.
        static func copyBits(_ source: UnsafeMutablePointer<UInt8>, _ from: Int, _ target: UnsafeMutablePointer<UInt8>, _ to: Int, _ count: Int) {
            var k = 0
            if from & 7 == 0 && to & 7 == 0 {
                let whole = count >> 3
                if whole > 0 { (target + (to >> 3)).update(from: source + (from >> 3), count: whole) }
                k = whole << 3
            }
            while k < count { put(target, to + k, bit(source, from + k)); k += 1 }
        }
        /// Whether `count` bits of `a` at `from` equal those of `b` at `to`.
        static func sameBits(_ a: UnsafeMutablePointer<UInt8>, _ from: Int, _ b: UnsafeMutablePointer<UInt8>, _ to: Int, _ count: Int) -> Bool {
            var k = 0
            if from & 7 == 0 && to & 7 == 0 {
                let whole = count >> 3
                if whole > 0 && memcmp(a + (from >> 3), b + (to >> 3), whole) != 0 { return false }
                k = whole << 3
            }
            while k < count { if bit(a, from + k) != bit(b, to + k) { return false }; k += 1 }
            return true
        }
    }
    private init(flat: Flat?, count: Int) { self.flat = flat; flatCount = count; large = nil }
    /// Before writing flat storage: a shared buffer is copied (the copy has no
    /// cached whole arrays), a unique one drops its cached whole arrays.
    private mutating func makeFlatUnique() {
        if isKnownUniquelyReferenced(&flat) { flat!.clearWhole() } else { flat = flat!.copy() }
    }
    /// One flat byte stored and marked defined (the parted paths' per-byte stores).
    private mutating func setFlatByte(_ index: Int, _ value: UInt8) {
        precondition(index >= 0 && index < flatCount, "Index out of range")
        makeFlatUnique()
        flat!.with { _, b, m in b[index] = value; Flat.set(m, index) }
    }
    /// A flat record's bytes and definedness over `range` as a new flat record.
    private func flatSlice(_ range: Range<Int>) -> OriginalStateRecord {
        guard let flat, !range.isEmpty else { return Self(flat: nil, count: 0) }
        let made = Flat.make(count: range.count)
        flat.with { _, b, m in made.with { n, mb, mm in mb.update(from: b + range.lowerBound, count: n); Flat.copyBits(m, range.lowerBound, mm, 0, n) } }
        return Self(flat: made, count: range.count)
    }
    private func flatDefinedArray(_ range: Range<Int>) -> [Bool] { flat?.definedArray(range) ?? [] }
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
        func byte(_ index: Int) -> UInt8 { let k = self.index(of: index); return records[k].byte(at: index - starts[k]) }
        func isDefined(_ index: Int) -> Bool { let k = self.index(of: index); return records[k].isDefined(at: index - starts[k]) }
        /// The same parts and an empty cache (for a copy about to be written).
        func copy() -> Parts { Parts(records: records, starts: starts) }
        func clearCache() {
            OriginalStateRecord.assemblyLock.lock(); bytes = nil; defined = nil; OriginalStateRecord.assemblyLock.unlock()
        }
        func wholeBytes() -> [UInt8] {
            OriginalStateRecord.assemblyLock.lock(); defer { OriginalStateRecord.assemblyLock.unlock() }
            if let bytes { return bytes }
            OriginalStateRecord.assemblies += 1
            let made = records.flatMap(\.bytes); bytes = made; return made
        }
        func wholeDefined() -> [Bool] {
            OriginalStateRecord.assemblyLock.lock(); defer { OriginalStateRecord.assemblyLock.unlock() }
            if let defined { return defined }
            OriginalStateRecord.assemblies += 1
            let made = records.flatMap(\.defined); defined = made; return made
        }
        /// Calls `body(part, local range)` for each run of `range`, in order.
        func forEachRun(_ range: Range<Int>, _ body: (OriginalStateRecord, Range<Int>) -> Void) {
            var index = range.lowerBound
            while index < range.upperBound {
                let k = self.index(of: index), local = index - starts[k]
                let n = min(range.upperBound - index, records[k].flatCount - local)
                body(records[k], local..<local + n)
                index += n
            }
        }
        func runBytes(_ range: Range<Int>) -> [UInt8] {
            var bytes = [UInt8](); bytes.reserveCapacity(range.count)
            forEachRun(range) { part, local in bytes.append(contentsOf: part.bytes(in: local)) }
            return bytes
        }
        func runAllDefined(_ range: Range<Int>) -> Bool {
            var all = true
            forEachRun(range) { part, local in if all && !part.allDefined(in: local) { all = false } }
            return all
        }
        /// Whether these parts hold flat `record`'s bytes and definedness, part
        /// by part without assembling.
        func equalsFlat(_ record: OriginalStateRecord) -> Bool {
            guard record.flatCount == count else { return false }
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
                let n = min(range.upperBound - index, records[k].flatCount - local)
                bytes.append(contentsOf: records[k].bytes(in: local..<local + n))
                defined.append(contentsOf: records[k].flatDefinedArray(local..<local + n))
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
        made.flat = nil; made.flatCount = 0
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
    /// The address of a non-empty flat record's storage, twice (the bytes and
    /// definedness share one buffer since S2b; nil for an empty, paged or
    /// parted record). Two flat records with the same identity share it and
    /// are equal, provided the caller keeps a record holding it alive
    /// (CORE_REALTIME 4j).
    var storageIdentity: (UInt, UInt)? {
        guard large == nil, let flat else { return nil }
        let address = UInt(bitPattern: Unmanaged.passUnretained(flat).toOpaque())
        return (address, address)
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
    /// Whether both are flat and share their storage (two empty records do).
    func sharesStorage(with other: OriginalStateRecord) -> Bool {
        guard pages == nil, parts == nil, other.pages == nil, other.parts == nil, flatCount == other.flatCount else { return false }
        return flat === other.flat
    }
    /// `try! Self(bytes: Array(bytes[range]), defined: Array(defined[range]))`
    /// (the caller has checked `range`), sharing a part's buffers when
    /// `range` is exactly that part.
    func extract(_ range: Range<Int>) -> OriginalStateRecord {
        if parts != nil && range.isEmpty { return try! Self(bytes: [], defined: []) }
        if let parts {
            let k = parts.index(of: range.lowerBound), local = range.lowerBound - parts.starts[k]
            if local == 0 && range.count == parts.records[k].flatCount { return parts.records[k] }
            let runs = parts.runs(range)
            return try! Self(bytes: runs.bytes, defined: runs.defined)
        }
        if large == nil {
            precondition(range.lowerBound >= 0 && range.upperBound <= flatCount, "Range out of bounds")
            return flatSlice(range)
        }
        return try! Self(bytes: Array(bytes[range]), defined: Array(defined[range]))
    }
    /// `Array(bytes[range])` without assembling a parted record.
    public func bytes(in range: Range<Int>) -> [UInt8] {
        if let parts {
            precondition(range.lowerBound >= 0 && range.upperBound <= parts.count, "Range out of bounds")
            return parts.runBytes(range)
        }
        if large == nil {
            precondition(range.lowerBound >= 0 && range.upperBound <= flatCount, "Range out of bounds")
            return flat?.bytesArray(range) ?? []
        }
        return Array(bytes[range])
    }
    /// `bytes[index]` without the whole contents (CORE_REALTIME tier 3 S2a).
    public func byte(at index: Int) -> UInt8 {
        if let parts { precondition(index >= 0 && index < parts.count, "Index out of range"); return parts.byte(index) }
        if let pages { precondition(index >= 0 && index < pages.count, "Index out of range"); return pages.byte(index) }
        precondition(index >= 0 && index < flatCount, "Index out of range")
        return flat!.with { _, b, _ in b[index] }
    }
    /// `defined[index]` without the whole mask (S2a).
    public func isDefined(at index: Int) -> Bool {
        if let parts { precondition(index >= 0 && index < parts.count, "Index out of range"); return parts.isDefined(index) }
        if let pages { precondition(index >= 0 && index < pages.count, "Index out of range"); return pages.isDefined(index) }
        precondition(index >= 0 && index < flatCount, "Index out of range")
        return flat!.with { _, _, m in Flat.bit(m, index) }
    }
    /// Whether every byte in `range` is defined (`!defined[range].contains(false)`).
    public func allDefined(in range: Range<Int>) -> Bool {
        if let parts {
            precondition(range.lowerBound >= 0 && range.upperBound <= parts.count, "Range out of bounds")
            return parts.runAllDefined(range)
        }
        if large == nil {
            precondition(range.lowerBound >= 0 && range.upperBound <= flatCount, "Range out of bounds")
            guard let flat else { return true }
            return flat.with { _, _, m in Flat.allSet(m, range) }
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
        guard let pages else { return (flat?.bytesArray(0..<flatCount) ?? [], flatDefinedArray(0..<flatCount)) }
        return (Self.assemble(pages.bytes, pages.count), Self.assemble(pages.defined, pages.count))
    }

    /// `Array(bytes.prefix(count))` without assembling a paged record.
    func leadingBytes(_ count: Int) -> [UInt8] {
        if let parts {
            precondition(count >= 0, "Can't take a prefix of negative length from a collection")
            return parts.runs(0..<min(count, parts.count)).bytes
        }
        guard let pages else {
            precondition(count >= 0, "Can't take a prefix of negative length from a collection")
            return flat?.bytesArray(0..<min(count, flatCount)) ?? []
        }
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
        guard let pages else { return flat?.wholeBytes() ?? [] }
        return pages.whole.bytes(pages.bytes, pages.count)
    }
    public var defined: [Bool] {
        if let parts { return parts.wholeDefined() }
        guard let pages else { return flat?.wholeDefined() ?? [] }
        return pages.whole.defined(pages.defined, pages.count)
    }
    public var byteCount: Int {
        if large == nil { return flatCount }
        return parts?.count ?? pages?.count ?? flatCount
    }

    public init(bytes: [UInt8], defined: [Bool]) throws {
        guard bytes.count == defined.count else {
            throw OriginalStateError.invalidStorage("byte and initialization-mask lengths differ")
        }
        if bytes.count >= Self.pagedThreshold {
            large = .pages(Pages(bytes: bytes, defined: defined))
            flat = nil
            flatCount = 0
        } else {
            flat = Flat.make(bytes: bytes, defined: defined)
            flatCount = bytes.count
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
        case (nil, nil): return lhs.flatCount == rhs.flatCount && Flat.equal(lhs.flat, rhs.flat)
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
    /// The flat, in-range, defined case runs inline at the call site; every
    /// other case and every error is `checkedInteger`'s, unchanged (CORE_REALTIME
    /// tier 3 L1: the game passes read records through here, and the call
    /// itself was 6% of the A12's main thread).
    @inline(__always)
    public func integer<T: FixedWidthInteger>(at offset: Int, as type: T.Type) throws -> T {
        let count = T.bitWidth / 8
        if large == nil, offset >= 0, count <= flatCount, offset <= flatCount - count, let flat,
           let value = flat.with({ _, b, m -> T? in
               Flat.allSet(m, offset, small: count) ? T(littleEndian: UnsafeRawPointer(b).loadUnaligned(fromByteOffset: offset, as: T.self)) : nil
           }) {
            return value
        }
        return try checkedInteger(at: offset, as: type)
    }
    @inline(never)
    func checkedInteger<T: FixedWidthInteger>(at offset: Int, as type: T.Type) throws -> T {
        if large == nil {
            // A flat record (nearly every one): the range check, definedness
            // and value with one load each, the same errors in the same order
            // as below (CORE_REALTIME 4w).
            let count = T.bitWidth / 8, total = flatCount
            guard offset >= 0, count <= total, offset <= total - count else {
                throw OriginalStateError.outOfBounds(offset: offset, count: count)
            }
            return try flat!.with { _, b, m in
                guard Flat.allSet(m, offset, small: count) else {
                    throw OriginalStateError.undefinedBytes(offset: offset, count: count)
                }
                return T(littleEndian: UnsafeRawPointer(b).loadUnaligned(fromByteOffset: offset, as: T.self))
            }
        }
        let region = try checkedRange(offset, T.bitWidth / 8)
        if let parts {
            // Within one part, as the flat read below at the part's offset;
            // across a boundary, every byte checked, then assembled. Errors
            // carry the logical offset.
            let count = region.count, k = parts.index(of: offset), local = offset - parts.starts[k]
            if local + count <= parts.records[k].flatCount {
                let part = parts.records[k]
                guard part.flat!.with({ _, _, m in Flat.allSet(m, local..<local + count) }) else {
                    throw OriginalStateError.undefinedBytes(offset: offset, count: count)
                }
                return part.flat!.with { _, b, _ in T(littleEndian: UnsafeRawPointer(b).loadUnaligned(fromByteOffset: local, as: T.self)) }
            }
            guard region.allSatisfy({ parts.isDefined($0) }) else { throw OriginalStateError.undefinedBytes(offset: offset, count: count) }
            return region.enumerated().reduce(T.zero) { $0 | (T(truncatingIfNeeded: parts.byte($1.element)) << ($1.offset * 8)) }
        }
        // Paged (a flat record took the first branch).
        let pages = self.pages!
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
        return flat!.with { _, b, _ in UInt32(littleEndian: UnsafeRawPointer(b).loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
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
        guard let flat else { return [] }
        return flat.with({ _, _, m in Flat.allSet(m, range) }) ? flat.bytesArray(range) : nil
    }

    /// Replaces the `count` little-endian words from `start` with `map(word)`
    /// in one pass when the record is flat, the words are in range, all their
    /// bytes are defined and every word maps; otherwise changes nothing and
    /// returns false (the caller then converts word by word for the exact
    /// error). The result equals writing the mapped words one by one in
    /// order: storage stays shared when no word changes (CORE_REALTIME
    /// tier 3 M1).
    mutating func mapWords(at start: Int, count: Int, _ map: (UInt32) -> UInt32?) -> Bool {
        if count == 0 { return true }
        guard large == nil, count > 0, count <= flatCount / 4, start >= 0, start <= flatCount - count * 4 else { return false }
        let n = count * 4
        return withUnsafeTemporaryAllocation(of: UInt32.self, capacity: count) { mapped in
            var changed = false
            let mapsAll = flat!.with { _, b, m -> Bool in
                guard Flat.allSet(m, start..<start + n) else { return false }
                for k in 0..<count {
                    let word = UInt32(littleEndian: UnsafeRawPointer(b).loadUnaligned(fromByteOffset: start + 4 * k, as: UInt32.self))
                    guard let value = map(word) else { return false }
                    mapped[k] = value; changed = changed || value != word
                }
                return true
            }
            guard mapsAll else { return false }
            guard changed else { return true }
            makeFlatUnique()
            flat!.with { _, b, _ in
                for k in 0..<count { UnsafeMutableRawPointer(b).storeBytes(of: mapped[k].littleEndian, toByteOffset: start + 4 * k, as: UInt32.self) }
            }
            return true
        }
    }

    public func binary64(at offset: Int) throws -> Double {
        Double(bitPattern: try integer(at: offset, as: UInt64.self))
    }

    /// Writes preserve exact integer/floating-point bit patterns; no host-width pointer conversion.
    /// The flat, in-range case (`checkedWrite`'s flat branch) runs inline at
    /// the call site; every other case and every error is `checkedWrite`'s,
    /// unchanged (CORE_REALTIME tier 3 L2, as L1 for reads).
    @inline(__always)
    public mutating func write<T: FixedWidthInteger>(_ value: T, at offset: Int) throws {
        let count = T.bitWidth / 8
        if large == nil, offset >= 0, count <= flatCount, offset <= flatCount - count {
            if flat!.with({ _, b, m in
                T(littleEndian: UnsafeRawPointer(b).loadUnaligned(fromByteOffset: offset, as: T.self)) == value && Flat.allSet(m, offset, small: count)
            }) { return }
            makeFlatUnique()
            flat!.with { _, b, m in
                UnsafeMutableRawPointer(b).storeBytes(of: value.littleEndian, toByteOffset: offset, as: T.self)
                Flat.setAll(m, offset, small: count)
            }
            return
        }
        try checkedWrite(value, at: offset)
    }
    @inline(never)
    mutating func checkedWrite<T: FixedWidthInteger>(_ value: T, at offset: Int) throws {
        if large == nil {
            // A flat record: the same check and no-op return as below, then
            // one store each for the bytes and their definedness (at most one
            // copy of each array if shared, as the per-byte stores made;
            // CORE_REALTIME 4w).
            let count = T.bitWidth / 8, total = flatCount
            guard offset >= 0, count <= total, offset <= total - count else {
                throw OriginalStateError.outOfBounds(offset: offset, count: count)
            }
            if flat!.with({ _, b, m in
                T(littleEndian: UnsafeRawPointer(b).loadUnaligned(fromByteOffset: offset, as: T.self)) == value && Flat.allSet(m, offset, small: count)
            }) { return }
            makeFlatUnique()
            flat!.with { _, b, m in
                UnsafeMutableRawPointer(b).storeBytes(of: value.littleEndian, toByteOffset: offset, as: T.self)
                Flat.setAll(m, offset, small: count)
            }
            return
        }
        let region = try checkedRange(offset, T.bitWidth / 8)
        if parts != nil {
            // Within one part as the flat write (the same no-op return keeps
            // the part shared); across a boundary byte by byte.
            let count = region.count, k = parts!.index(of: offset), local = offset - parts!.starts[k]
            if local + count <= parts!.records[k].flatCount {
                if parts!.records[k].flatHolds(value, local..<local + count) { return }
                makePartsUnique()
                for (shift, index) in (local..<local + count).enumerated() {
                    parts!.records[k].setFlatByte(index, UInt8(truncatingIfNeeded: value >> (shift * 8)))
                }
                return
            }
            if region.enumerated().allSatisfy({ parts!.isDefined($1) && parts!.byte($1) == UInt8(truncatingIfNeeded: value >> ($0 * 8)) }) { return }
            makePartsUnique()
            for (shift, index) in region.enumerated() {
                let k = parts!.index(of: index), local = index - parts!.starts[k]
                parts!.records[k].setFlatByte(local, UInt8(truncatingIfNeeded: value >> (shift * 8)))
            }
            return
        }
        if pages == nil {
            // Storing the bytes already there, all defined, changes nothing;
            // returning leaves a buffer that a rollback copy shares untouched
            // instead of copying the whole record (CORE_REALTIME phase 2d).
            if flatHolds(value, region) { return }
            for (shift, index) in region.enumerated() { setFlatByte(index, UInt8(truncatingIfNeeded: value >> (shift * 8))) }
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
            let k = parts!.index(of: start), local = start - parts!.starts[k], partCount = parts!.records[k].flatCount
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
                let n = min(count - offset, parts!.records[k].flatCount - local)
                parts!.records[k].overwrite(at: local, with: source.extract(offset..<offset + n))
                offset += n
            }
            return
        }
        if pages == nil && record.pages == nil && record.parts == nil {
            // An overwrite with the bytes and definedness already there changes
            // nothing (phase 2d, as in write).
            if flatHolds(record, at: start) { return }
            makeFlatUnique()
            record.flat!.with { _, sb, sm in flat!.with { _, b, m in
                (b + start).update(from: sb, count: count); Flat.copyBits(sm, 0, m, start, count)
            } }
            return
        }
        if pages == nil, let source = record.parts {
            // A parted source onto a flat target, run by run without assembling.
            var index = start
            source.forEachRun(0..<count) { part, local in
                makeFlatUnique()
                part.flat!.with { _, sb, sm in flat!.with { _, b, m in
                    (b + index).update(from: sb + local.lowerBound, count: local.count)
                    Flat.copyBits(sm, local.lowerBound, m, index, local.count)
                } }
                index += local.count
            }
            return
        }
        let bytes = record.bytes, defined = record.defined
        if pages == nil {
            makeFlatUnique()
            flat!.with { _, b, m in
                bytes.withUnsafeBufferPointer { (b + start).update(from: $0.baseAddress!, count: count) }
                for k in 0..<count { Flat.put(m, start + k, defined[k]) }
            }
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
        guard let flat else { return region.isEmpty }
        return flat.with { _, b, m in
            for (shift, index) in region.enumerated() {
                if !Flat.bit(m, index) || b[index] != UInt8(truncatingIfNeeded: value >> (shift * 8)) { return false }
            }
            return true
        }
    }
    /// Whether this flat record equals flat `record`'s window starting at
    /// `start` (same length as this record).
    private func flatHolds(_ record: OriginalStateRecord, from start: Int) -> Bool {
        let count = flatCount
        guard count > 0 else { return true }
        return flat!.with { _, b, m in record.flat!.with { _, rb, rm in
            memcmp(b, rb + start, count) == 0 && Flat.sameBits(m, 0, rm, start, count)
        } }
    }
    /// Whether this flat record already holds flat `record`'s bytes and
    /// definedness at `start` (the caller checked the extent).
    private func flatHolds(_ record: OriginalStateRecord, at start: Int) -> Bool {
        let count = record.flatCount
        guard count > 0 else { return true }
        return flat!.with { _, b, m in record.flat!.with { _, rb, rm in
            memcmp(b + start, rb, count) == 0 && Flat.sameBits(m, start, rm, 0, count)
        } }
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
                parts!.records[k].setFlatByte(index - parts!.starts[k], 0)
            }
            return
        }
        if pages == nil {
            guard !region.isEmpty else { return }
            precondition(region.lowerBound >= 0 && region.upperBound <= flatCount, "Index out of range")
            makeFlatUnique()
            flat!.with { _, b, m in (b + region.lowerBound).update(repeating: 0, count: region.count); Flat.setAll(m, region) }
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
