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
/// identity; code hooks travel separately. Every role lives in one immutable
/// storage, so a pass's copy of the rules is one reference (E5c-1a).
public struct OriginalGameRules: Equatable, Sendable {
    private final class Roles: Sendable {
        let profile: String, reflectable: OriginalIDSet, reflector: Int32, rebinder: Int32, heldRebinder: Int32
        init(profile: String, reflectable: OriginalIDSet, reflector: Int32, rebinder: Int32, heldRebinder: Int32) {
            self.profile = profile; self.reflectable = reflectable; self.reflector = reflector
            self.rebinder = rebinder; self.heldRebinder = heldRebinder
        }
    }
    private let roles: Roles
    /// The profile these rules come from (e.g. "NTSD 2.4 2.0a").
    public var profile: String { roles.profile }
    /// Objects a reflector sends back (OriginalHitDamage, OriginalWorldContacts).
    public var reflectable: OriginalIDSet { roles.reflectable }
    /// The reflecting Object: it keeps or takes over a reflectable ball, a
    /// reflectable attacker skips its interactions on it, and reflected balls
    /// are rebound to its first Object (OriginalHitDamage, OriginalWorldContacts).
    public var reflector: Int32 { roles.reflector }
    /// An attacker whose hit rebinds a reflectable defender to the reflector.
    public var rebinder: Int32 { roles.rebinder }
    /// A held attacker whose hit rebinds a reflectable defender to the reflector
    /// and credits the holder.
    public var heldRebinder: Int32 { roles.heldRebinder }
    public init(profile: String, reflectable: OriginalIDSet, reflector: Int32, rebinder: Int32, heldRebinder: Int32) {
        roles = Roles(profile: profile, reflectable: reflectable, reflector: reflector, rebinder: rebinder, heldRebinder: heldRebinder)
    }
    public static func == (a: Self, b: Self) -> Bool {
        a.roles === b.roles || (a.profile == b.profile && a.reflectable == b.reflectable && a.reflector == b.reflector
                                && a.rebinder == b.rebinder && a.heldRebinder == b.heldRebinder)
    }
}
