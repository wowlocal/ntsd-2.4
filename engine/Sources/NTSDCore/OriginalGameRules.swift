/// A set of object IDs for one rule of a game profile (ENGINE_SPLIT E5c): a
/// membership test with the old literal list's answer for every `Int32` a
/// catalog header can hold. The profile's own IDs lie in 0..<65536; any other
/// value (negative or larger) is not a member. Two sets are equal when their
/// lists are (order and repeats included), not merely their members.
public struct OriginalIDSet: Equatable, Sendable {
    /// The IDs as the profile lists them.
    public let ids: [Int32]
    private let words: [UInt64]
    public init(_ ids: [Int32]) {
        precondition(ids.allSatisfy { (0..<65536).contains($0) }, "Profile IDs lie in 0..<65536")
        var words = [UInt64](repeating: 0, count: Int(ids.max().map { ($0 >> 6) + 1 } ?? 0))
        for id in ids { words[Int(id >> 6)] |= 1 << UInt64(id & 63) }
        self.ids = ids; self.words = words
    }
    /// A negative ID's bit pattern lies above every word, as does any ID beyond the last.
    func contains(_ id: Int32) -> Bool {
        let bits = UInt32(bitPattern: id), word = Int(bits &>> 6)
        return word < words.count && words[word] &>> UInt64(bits & 63) & 1 != 0
    }
}

/// A game's rules (ENGINE_SPLIT E5): the values the engine's passes test where
/// the original tests object IDs. The game supplies them with its content
/// identity; code hooks travel separately.
public struct OriginalGameRules: Equatable, Sendable {
    /// The profile these rules come from (e.g. "NTSD 2.4 2.0a").
    public let profile: String
    /// Objects a reflector sends back (OriginalHitDamage, OriginalWorldContacts).
    public let reflectable: OriginalIDSet
    public init(profile: String, reflectable: OriginalIDSet) {
        self.profile = profile; self.reflectable = reflectable
    }
}
