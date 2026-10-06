/// The presentation memory's allocations by token (CORE_REALTIME R3 stage 1,
/// docs/research/CORE_REALTIME_R3.md). It behaves as the dictionary it
/// replaces: every read returns the logical entry, every change produces what
/// the same dictionary operation would, and equality compares the logical
/// entries.
///
/// While a match is loaded the 400 actor records live in an actor tier, in the
/// match model's form (the Object ordinal at +0x368), owned by the match
/// bindings' shape: the logical entry of `tokens[i]` is `records[i]` with the
/// Object token written back at +0x368, live. The bindings read and store the
/// tier without converting or copying the table; any other change to an actor
/// entry first moves the tier back into the dictionary (today's form).
public struct OriginalAllocationTable: Equatable, Sequence, ExpressibleByDictionaryLiteral {
    public typealias Allocation = OriginalMenuPresentationMemory.Allocation
    public typealias Element = (key: UInt32, value: Allocation)
    /// The actors of one loaded session: their tokens in bindings order, the
    /// Object tokens indexed by ordinal and the bindings' pair memo.
    final class ActorShape {
        let tokens: [UInt32], index: [UInt32: Int], objectTokens: [UInt32]
        let pairs: OriginalApplicationMatchBindings.ActorPairs
        init(tokens: [UInt32],objectTokens: [UInt32],pairs: OriginalApplicationMatchBindings.ActorPairs) {
            self.tokens = tokens;self.objectTokens = objectTokens;self.pairs = pairs
            index = Dictionary(uniqueKeysWithValues:tokens.enumerated().map { ($0.element,$0.offset) })
        }
        /// The session form of model record `i`. Installed records hold a
        /// defined ordinal below `objectTokens.count` at +0x368 (checked by the
        /// bindings' store before installing).
        func stored(_ i: Int,_ model: OriginalStateRecord) -> OriginalStateRecord {
            if let record = pairs.stored(i,for:model) { return record }
            var record = model
            let ordinal = try! record.integer(at:0x368,as:UInt32.self)
            try! record.write(objectTokens[Int(ordinal)],at:0x368)
            pairs.set(i,stored:record,model:model)
            return record
        }
    }
    struct ActorTier {
        let shape: ActorShape
        var records: [OriginalStateRecord]
        func allocation(_ i: Int) -> Allocation { .init(storage:shape.stored(i,records[i])) }
    }
    private var general: [UInt32: Allocation]
    private(set) var actors: ActorTier?

    public init() { general = [:] }
    public init(_ entries: [UInt32: Allocation]) { general = entries }
    public init(dictionaryLiteral elements: (UInt32, Allocation)...) {
        general = Dictionary(uniqueKeysWithValues: elements)
    }

    public subscript(key: UInt32) -> Allocation? {
        get {
            if let tier = actors,let i = tier.shape.index[key] { return tier.allocation(i) }
            return general[key]
        }
        _modify {
            if let tier = actors,tier.shape.index[key] != nil { dissolveActors() }
            yield &general[key]
        }
    }
    public var count: Int { general.count+(actors?.records.count ?? 0) }
    public var isEmpty: Bool { count == 0 }
    /// The entries as a dictionary.
    public var dictionary: [UInt32: Allocation] {
        guard let tier = actors else { return general }
        var all = general
        for i in tier.records.indices { all[tier.shape.tokens[i]] = tier.allocation(i) }
        return all
    }
    public var keys: [UInt32] { Array(general.keys)+(actors?.shape.tokens ?? []) }
    public var values: [Allocation] { map(\.value) }
    public func makeIterator() -> Iterator { Iterator(general:general.makeIterator(),actors:actors) }
    public struct Iterator: IteratorProtocol {
        fileprivate var general: Dictionary<UInt32, Allocation>.Iterator
        fileprivate let actors: ActorTier?
        fileprivate var position = 0
        public mutating func next() -> Element? {
            if let entry = general.next() { return entry }
            guard let tier = actors,position < tier.records.count else { return nil }
            defer { position += 1 }
            return (tier.shape.tokens[position],tier.allocation(position))
        }
    }
    public func filter(_ isIncluded: (Element) throws -> Bool) rethrows -> [UInt32: Allocation] {
        try dictionary.filter(isIncluded)
    }
    @discardableResult
    public mutating func removeValue(forKey key: UInt32) -> Allocation? {
        if let tier = actors,tier.shape.index[key] != nil { dissolveActors() }
        return general.removeValue(forKey: key)
    }
    public static func == (lhs: OriginalAllocationTable, rhs: OriginalAllocationTable) -> Bool {
        switch (lhs.actors,rhs.actors) {
        case (nil,nil): return lhs.general == rhs.general
        case let (a?,b?) where a.shape === b.shape: return lhs.general == rhs.general && a.records == b.records
        default: return lhs.dictionary == rhs.dictionary
        }
    }

    /// The actor tier of `shape`, if this table holds it.
    func actorRecords(_ shape: ActorShape) -> [OriginalStateRecord]? {
        guard let tier = actors,tier.shape === shape else { return nil }
        return tier.records
    }
    /// Whether this table and `other` both hold the actor tier of `shape` with
    /// equal records, so every actor entry is equal in both (O(1) when the
    /// records are shared).
    func sameActors(_ shape: ActorShape,as other: OriginalAllocationTable) -> Bool {
        guard let a = actors,let b = other.actors,a.shape === shape,b.shape === shape else { return false }
        return a.records == b.records
    }
    /// Install the actors of `shape` as model records: the logical entries
    /// become `stored(records[i])`, live, replacing those tokens' entries.
    /// The caller has checked every record (0x420 bytes, a defined ordinal
    /// below the Object count at +0x368).
    mutating func installActors(_ shape: ActorShape,_ records: [OriginalStateRecord]) {
        assert(records.count == shape.tokens.count && records.allSatisfy { record in
            record.byteCount == OriginalStateRecord.actorSize
                && (try? record.integer(at:0x368,as:UInt32.self)).map { Int($0) < shape.objectTokens.count } == true
        },"actor tier records")
        if let tier = actors,tier.shape !== shape { dissolveActors() }
        if actors == nil { for token in shape.tokens { general.removeValue(forKey:token) } }
        actors = ActorTier(shape:shape,records:records)
    }
    private mutating func dissolveActors() {
        guard let tier = actors else { return }
        actors = nil
        for i in tier.records.indices { general[tier.shape.tokens[i]] = tier.allocation(i) }
    }
}
