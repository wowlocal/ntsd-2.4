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
/// the original tests object IDs, grouped by family. The game supplies them with
/// its content identity; code hooks travel separately. Every role lives in one
/// immutable storage, so a pass's copy of the rules is one reference (E5c-1a).
public struct OriginalGameRules: Equatable, Sendable {
    /// Reflection (OriginalHitDamage, OriginalWorldContacts).
    public struct Reflection: Equatable, Sendable {
        /// Objects a reflector sends back.
        public let reflectable: OriginalIDSet
        /// The reflecting Object: it keeps or takes over a reflectable ball, a
        /// reflectable attacker skips its interactions on it, and reflected balls
        /// are rebound to its first Object.
        public let reflector: Int32
        /// An attacker whose hit rebinds a reflectable defender to the reflector.
        public let rebinder: Int32
        /// A held attacker whose hit rebinds a reflectable defender to the
        /// reflector and credits the holder.
        public let heldRebinder: Int32
        public init(reflectable: OriginalIDSet, reflector: Int32, rebinder: Int32, heldRebinder: Int32) {
            self.reflectable = reflectable; self.reflector = reflector; self.rebinder = rebinder; self.heldRebinder = heldRebinder
        }
    }
    /// Guards: the automatic guards, the defend block and the guard sound
    /// (OriginalActorHits.guarded, OriginalHitGuard). The thresholds and
    /// conditions are the engine's; the profile names the Objects.
    public struct Armour: Equatable, Sendable {
        /// Attackers whose interactions pierce the automatic guards.
        public let guardPenetrators: OriginalIDSet
        /// Guards while its +0xb8 is at most 15, unless the interaction penetrates.
        public let steadyArmour: Int32
        /// Guards while its +0xb8 is at most 1, unless the interaction penetrates,
        /// in frames below 20 or states 5, 4 and 7.
        public let openingArmour: Int32
        /// Guards while its +0xb8 is at most 15, unless the attacker is a penetrator.
        public let attackerArmour: Int32
        /// Attackers a defending Object (body kind 7) blocks whatever the facing,
        /// as it blocks any attacker facing it or with a negative dvx.
        public let alwaysBlocked: OriginalIDSet
        /// Defenders whose guard plays sound 17 instead of 1.
        public let armourGuardSound: OriginalIDSet
        public init(guardPenetrators: OriginalIDSet, steadyArmour: Int32, openingArmour: Int32, attackerArmour: Int32,
                    alwaysBlocked: OriginalIDSet, armourGuardSound: OriginalIDSet) {
            self.guardPenetrators = guardPenetrators; self.steadyArmour = steadyArmour; self.openingArmour = openingArmour
            self.attackerArmour = attackerArmour; self.alwaysBlocked = alwaysBlocked; self.armourGuardSound = armourGuardSound
        }
    }
    private final class Roles: Sendable {
        let profile: String, reflection: Reflection, armour: Armour
        init(profile: String, reflection: Reflection, armour: Armour) {
            self.profile = profile; self.reflection = reflection; self.armour = armour
        }
    }
    private let roles: Roles
    /// The profile these rules come from (e.g. "NTSD 2.4 2.0a").
    public var profile: String { roles.profile }
    public var reflection: Reflection { roles.reflection }
    public var armour: Armour { roles.armour }
    public var reflectable: OriginalIDSet { roles.reflection.reflectable }
    public var reflector: Int32 { roles.reflection.reflector }
    public var rebinder: Int32 { roles.reflection.rebinder }
    public var heldRebinder: Int32 { roles.reflection.heldRebinder }
    public var guardPenetrators: OriginalIDSet { roles.armour.guardPenetrators }
    public var steadyArmour: Int32 { roles.armour.steadyArmour }
    public var openingArmour: Int32 { roles.armour.openingArmour }
    public var attackerArmour: Int32 { roles.armour.attackerArmour }
    public var alwaysBlocked: OriginalIDSet { roles.armour.alwaysBlocked }
    public var armourGuardSound: OriginalIDSet { roles.armour.armourGuardSound }
    public init(profile: String, reflection: Reflection, armour: Armour) {
        roles = Roles(profile: profile, reflection: reflection, armour: armour)
    }
    public static func == (a: Self, b: Self) -> Bool {
        a.roles === b.roles || (a.profile == b.profile && a.reflection == b.reflection && a.armour == b.armour)
    }
}
