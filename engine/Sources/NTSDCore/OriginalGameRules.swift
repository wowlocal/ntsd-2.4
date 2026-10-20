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

/// A half-open range of object IDs (or stage numbers) for one rule of a game
/// profile (ENGINE_SPLIT E5c-2a): `contains` is `lowerBound <= id && id < upperBound`
/// for every Int32,
/// the complement of the original's `id < lowerBound || id >= upperBound`. Two
/// ranges are equal when their bounds are (two empty ranges may differ).
public struct OriginalIDRange: Equatable, Sendable {
    public let lowerBound: Int32, upperBound: Int32
    public init(_ range: Range<Int32>) { lowerBound = range.lowerBound; upperBound = range.upperBound }
    func contains(_ id: Int32) -> Bool { id >= lowerBound && id < upperBound }
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
    /// Special interactions in the hit and contact passes (OriginalHitSpecial,
    /// OriginalWorldContacts).
    public struct Interaction: Equatable, Sendable {
        /// Objects whose kind-7 pick-up (any type) or kind-2 pick-up as a type-1
        /// weapon gives the holder hold kind 101 instead of 1 (the 4/6 overrides of
        /// kind 7 still follow for types 4 and 6).
        public let holdKind101: OriginalIDSet
        /// Type 1, 4 and 6 Objects a pulling hit leaves as they are.
        public let pullImmune: OriginalIDSet
        /// A defender that passes the same-team filters (the actors' teams, and for
        /// kind 5 the held owner's team): against any other attacker, and against
        /// its own ID when the defender's frame %10 is 5 and the attacker's is 0.
        public let teamBypass: Int32
        /// Non-character attackers that count as characters in game mode 1.
        public let countsAsCharacter: OriginalIDSet
        public init(holdKind101: OriginalIDSet, pullImmune: OriginalIDSet, teamBypass: Int32, countsAsCharacter: OriginalIDSet) {
            self.holdKind101 = holdKind101; self.pullImmune = pullImmune; self.teamBypass = teamBypass; self.countsAsCharacter = countsAsCharacter
        }
    }
    /// What an attacker's hit does to the attacker or to the defender's x impulse
    /// (+0x28) (OriginalHitDamage).
    public struct Impact: Equatable, Sendable {
        /// An attacker deactivated (its World activity byte cleared) when it hits a type-0 defender.
        public let vanishingAttacker: Int32
        /// An attacker whose HP goes to 0 when it hits a type-0 defender.
        public let spentAttacker: Int32
        /// A held attacker whose hit on a type-4 or type-6 defender multiplies the
        /// defender's x impulse (+0x28) by 2.5 with sound 13; a non-zero result under
        /// 10 in magnitude becomes ±10.
        public let heavyHeldWeapon: Int32
        public init(vanishingAttacker: Int32, spentAttacker: Int32, heavyHeldWeapon: Int32) {
            self.vanishingAttacker = vanishingAttacker; self.spentAttacker = spentAttacker; self.heavyHeldWeapon = heavyHeldWeapon
        }
    }
    /// Items: which Objects a random item spawn picks from and how it treats
    /// some of them (OriginalWorldHits), which ones a requested item spawn
    /// creates (OriginalPostDrawCommands), the item a mission stage's spawn gives
    /// HP 200 (OriginalMissionStage), which ones the camera keeps in the arena
    /// (OriginalWorldCamera), and the held drinks (OriginalWorldLinks).
    public struct Items: Equatable, Sendable {
        /// The items: a random item spawn picks one of them; a requested spawn
        /// (0x450bb8 = 1) creates an Actor for every one of them it keeps.
        public let itemRange: OriginalIDRange
        /// Items a random spawn keeps only on a coin flip (stream 147), and never in
        /// game modes 1–4.
        public let scarceDropItems: OriginalIDSet
        /// The item (inside `itemRange`) a requested spawn (0x450bb8 = 1) keeps
        /// only when a coin flip (stream 208) comes up 1; no mode test.
        public let scarceRequestedItem: Int32
        /// The item a spawn (random, requested, or a mission stage's) creates with
        /// HP 200: of the 500 a new Actor starts with in the random and requested
        /// spawns; in a mission stage's, of the stage's maximum HP.
        public let spawnHP200: Int32
        /// Objects of a type other than 0 and 3 that the camera holds within
        /// [10, width − 10] while their team (+0x344) is positive or, in mode 1,
        /// on stages 50–59; otherwise such an Object past an edge with y (+0x14)
        /// 0 is deactivated.
        public let keptOnScreen: OriginalIDSet
        /// The drink that, held by an Actor in state 17, loses 1 HP each links
        /// pass (twice a tick); at every 5th and 6th of its HP it restores some of
        /// the holder's HP and MP. Spent, it is dropped (stream 136).
        public let hpDrink: Int32
        /// The drink that, held by an Actor in state 17, loses 2 HP each links
        /// pass (twice a tick) and adds 3 to the holder's MP (capped at 500, and set
        /// to 150 under the item's +0x2f4/+0x308 test). Spent, it is dropped
        /// (stream 137).
        public let mpDrink: Int32
        public init(itemRange: OriginalIDRange, scarceDropItems: OriginalIDSet, scarceRequestedItem: Int32, spawnHP200: Int32,
                    keptOnScreen: OriginalIDSet, hpDrink: Int32, mpDrink: Int32) {
            self.itemRange = itemRange; self.scarceDropItems = scarceDropItems; self.scarceRequestedItem = scarceRequestedItem
            self.spawnHP200 = spawnHP200
            self.keptOnScreen = keptOnScreen; self.hpDrink = hpDrink; self.mpDrink = mpDrink
        }
    }
    /// Roster: which characters the menus list only on request, which ones Random
    /// picks from, and which ones a computer-only bracket match favours (the
    /// character screen, computer selection, match selection, continuation, the
    /// tournaments, War).
    public struct Roster: Equatable, Sendable {
        /// Characters the roster lists only when 0x458428 is 1 (that word is read
        /// only for them): the character screen, computer selection and both
        /// tournaments' setups.
        public let hiddenRoster: OriginalIDSet
        /// Characters Random picks from (type 0, never ordinal 0, not already
        /// selected): OriginalMatchContinuation's candidates (continuation, computer
        /// selection, match selection), both tournaments' setups and War.
        public let randomCandidates: OriginalIDRange
        /// Characters that beat a non-member in a computer-only bracket match (a
        /// team with one beats a team without); otherwise a coin flip whose stream
        /// follows the first side's membership.
        public let bracketFavourites: OriginalIDSet
        public init(hiddenRoster: OriginalIDSet, randomCandidates: OriginalIDRange, bracketFavourites: OriginalIDSet) {
            self.hiddenRoster = hiddenRoster; self.randomCandidates = randomCandidates; self.bracketFavourites = bracketFavourites
        }
    }
    /// Modes: what the stage numbers mean in stage mode (OriginalMissionStage, the
    /// camera, match selection, the match prelude) and which characters War counts as troops
    /// (OriginalWarBattle). The decade arithmetic (ten stages a set, sixty stages)
    /// stays engine code.
    public struct Modes: Equatable, Sendable {
        /// Survival stages: the blink flag at a stage's start, the dead players'
        /// revive to HP 5, and (with `keptOnScreen`) the camera holding items.
        public let survivalStages: OriginalIDRange
        /// Numbered stages: "STAGE q-r" and the set/stage digits (the others show
        /// the survival line or bitmap); match selection's set digit.
        public let numberedStages: OriginalIDRange
        /// The last stage set: its end does not advance to the next set (it goes
        /// to the menu 0x12c, or waits through 0x450bdc). Survival and numbered
        /// stages are not complements: stages from 60 are neither.
        public let finalStageSet: OriginalIDRange
        /// Players a mission stage's start counts one (`stageWeightPlus1`) or two
        /// (`stageWeightPlus2`) extra in its weight, each tested on its own.
        public let stageWeightPlus1: Int32, stageWeightPlus2: Int32
        /// Characters War counts as troops (sides 1–2, seats from 20).
        public let warTroops: OriginalIDSet
        /// The arena (background ordinal) a stage-mode match starts on, by stage
        /// (OriginalMatchPrelude); other stages keep the arena they have.
        public let stageBackgrounds: [Int32: Int32]
        public init(survivalStages: OriginalIDRange, numberedStages: OriginalIDRange, finalStageSet: OriginalIDRange,
                    stageWeightPlus1: Int32, stageWeightPlus2: Int32, warTroops: OriginalIDSet, stageBackgrounds: [Int32: Int32]) {
            self.survivalStages = survivalStages; self.numberedStages = numberedStages; self.finalStageSet = finalStageSet
            self.stageWeightPlus1 = stageWeightPlus1; self.stageWeightPlus2 = stageWeightPlus2; self.warTroops = warTroops
            self.stageBackgrounds = stageBackgrounds
        }
    }
    /// Physics: the Objects the actor physics moves or drops their own way
    /// (OriginalActorPhysics) and the two Object roles of a revival
    /// (OriginalWorldPhysics). The gravities stay engine values (F5).
    public struct Physics: Equatable, Sendable {
        /// Moves a further 0.2·vx in x each tick, as every type-4 Object does.
        public let extraDrift: Int32
        /// Moves 0.2·vx back in x each tick (a damped drift: 0.8·vx in all).
        public let reverseDrift: Int32
        /// Thrown (state 1002) and in the air, these fall with gravity 0.17, 0.425
        /// and 1.133 instead of 0.567, tested in that order (types other than 3, 4
        /// and 6; the first match wins).
        public let lowGravityThrow: Int32, midGravityThrow: Int32, highGravityThrow: Int32
        /// The Object (of a type other than 0, 1, 2, 4 and 6) that, on the ground
        /// (y above −0.0001, frame +0x88 not 2), stops at frame 101 with y, vy and vx 0,
        /// on every such tick.
        public let restingPiece: Int32
        /// The Objects (the reviving Actor's +0x368, read after the revival's writes;
        /// no type test) whose revival sets +0x318 to 140.
        public let revivalPicture: OriginalIDRange
        /// The Object a revival spawns into a free slot from 50.
        public let revivalEffect: Int32
        public init(extraDrift: Int32, reverseDrift: Int32, lowGravityThrow: Int32, midGravityThrow: Int32, highGravityThrow: Int32,
                    restingPiece: Int32, revivalPicture: OriginalIDRange, revivalEffect: Int32) {
            self.extraDrift = extraDrift; self.reverseDrift = reverseDrift
            self.lowGravityThrow = lowGravityThrow; self.midGravityThrow = midGravityThrow; self.highGravityThrow = highGravityThrow
            self.restingPiece = restingPiece; self.revivalPicture = revivalPicture; self.revivalEffect = revivalEffect
        }
    }
    private final class Roles: Sendable {
        let profile: String, reflection: Reflection, armour: Armour, interaction: Interaction, impact: Impact, items: Items, roster: Roster
        let modes: Modes, physics: Physics
        init(profile: String, reflection: Reflection, armour: Armour, interaction: Interaction, impact: Impact, items: Items, roster: Roster,
             modes: Modes, physics: Physics) {
            self.profile = profile; self.reflection = reflection; self.armour = armour; self.interaction = interaction; self.impact = impact
            self.items = items; self.roster = roster; self.modes = modes; self.physics = physics
        }
    }
    private let roles: Roles
    /// The profile these rules come from (e.g. "NTSD 2.4 2.0a").
    public var profile: String { roles.profile }
    public var reflection: Reflection { roles.reflection }
    public var armour: Armour { roles.armour }
    public var interaction: Interaction { roles.interaction }
    public var impact: Impact { roles.impact }
    public var items: Items { roles.items }
    public var roster: Roster { roles.roster }
    public var modes: Modes { roles.modes }
    public var physics: Physics { roles.physics }
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
    public var holdKind101: OriginalIDSet { roles.interaction.holdKind101 }
    public var pullImmune: OriginalIDSet { roles.interaction.pullImmune }
    public var teamBypass: Int32 { roles.interaction.teamBypass }
    public var countsAsCharacter: OriginalIDSet { roles.interaction.countsAsCharacter }
    public var vanishingAttacker: Int32 { roles.impact.vanishingAttacker }
    public var spentAttacker: Int32 { roles.impact.spentAttacker }
    public var heavyHeldWeapon: Int32 { roles.impact.heavyHeldWeapon }
    public var itemRange: OriginalIDRange { roles.items.itemRange }
    public var scarceDropItems: OriginalIDSet { roles.items.scarceDropItems }
    public var scarceRequestedItem: Int32 { roles.items.scarceRequestedItem }
    public var spawnHP200: Int32 { roles.items.spawnHP200 }
    public var keptOnScreen: OriginalIDSet { roles.items.keptOnScreen }
    public var hpDrink: Int32 { roles.items.hpDrink }
    public var mpDrink: Int32 { roles.items.mpDrink }
    public var hiddenRoster: OriginalIDSet { roles.roster.hiddenRoster }
    public var randomCandidates: OriginalIDRange { roles.roster.randomCandidates }
    public var bracketFavourites: OriginalIDSet { roles.roster.bracketFavourites }
    public var survivalStages: OriginalIDRange { roles.modes.survivalStages }
    public var numberedStages: OriginalIDRange { roles.modes.numberedStages }
    public var finalStageSet: OriginalIDRange { roles.modes.finalStageSet }
    public var stageWeightPlus1: Int32 { roles.modes.stageWeightPlus1 }
    public var stageWeightPlus2: Int32 { roles.modes.stageWeightPlus2 }
    public var warTroops: OriginalIDSet { roles.modes.warTroops }
    public var stageBackgrounds: [Int32: Int32] { roles.modes.stageBackgrounds }
    public var extraDrift: Int32 { roles.physics.extraDrift }
    public var reverseDrift: Int32 { roles.physics.reverseDrift }
    public var lowGravityThrow: Int32 { roles.physics.lowGravityThrow }
    public var midGravityThrow: Int32 { roles.physics.midGravityThrow }
    public var highGravityThrow: Int32 { roles.physics.highGravityThrow }
    public var restingPiece: Int32 { roles.physics.restingPiece }
    public var revivalPicture: OriginalIDRange { roles.physics.revivalPicture }
    public var revivalEffect: Int32 { roles.physics.revivalEffect }
    public init(profile: String, reflection: Reflection, armour: Armour, interaction: Interaction, impact: Impact, items: Items,
                roster: Roster, modes: Modes, physics: Physics) {
        roles = Roles(profile: profile, reflection: reflection, armour: armour, interaction: interaction, impact: impact, items: items,
                      roster: roster, modes: modes, physics: physics)
    }
    public static func == (a: Self, b: Self) -> Bool {
        a.roles === b.roles || (a.profile == b.profile && a.reflection == b.reflection && a.armour == b.armour && a.interaction == b.interaction
                                && a.impact == b.impact && a.items == b.items && a.roster == b.roster
                                && a.modes == b.modes && a.physics == b.physics)
    }
}
