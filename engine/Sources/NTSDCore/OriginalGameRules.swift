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

/// An object ID with an inclusive window of its frame numbers, for a rule that
/// tests both (ENGINE_SPLIT E5d-1a): the frames are that object's own.
public struct OriginalIDFrames: Equatable, Sendable {
    public let id: Int32, first: Int32, last: Int32
    public init(_ id: Int32, frames: ClosedRange<Int32>) { self.id = id; first = frames.lowerBound; last = frames.upperBound }
}

/// One bitmap's rectangle sheet (ENGINE_SPLIT E5f): the global slot that holds
/// the bitmap and its frames' x, y, width and height, in the order they are
/// written (x at +0x10, y at +0x7e0, width at +0xfb0, height at +0x1780, four
/// bytes a frame; then the count at +0x0c).
public struct OriginalBitmapSheet: Equatable, Sendable {
    public let slot: Int
    public let frames: [[Int32]]
    public init(slot: Int, frames: [[Int32]]) {
        precondition(frames.allSatisfy { $0.count == 4 }, "A frame is x, y, width and height")
        self.slot = slot; self.frames = frames
    }
}

/// A game's rules (ENGINE_SPLIT E5): the values the engine's passes test where
/// the original tests object IDs, grouped by family. The game supplies them with
/// its content identity, LF2 2.0a's families from the engine (OriginalGameRules.lf2,
/// E6b); the AI's special moves travel with them as a code hook (E5d-2). Every role lives in one immutable storage, so a pass's copy of the
/// rules is one reference (E5c-1a).
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
        /// A defender an unguarded kind-0 hit (`damageHit`) leaves undamaged (A7):
        /// when its frame has a body (+0x12c above 0) whose first word is above
        /// 1000, it joins team 1 (+0x364) at frame (+0x70) word − 1000 with +0xb4
        /// −3, the attacker's +0xb4 3; +0xb8 = 45 is still written; this
        /// contact's spark and the attacker's remaining contacts in this
        /// `resolve` are skipped. Guarded and special (kind ≠ 0) hits are not
        /// affected.
        public let hitConverted: Int32
        public init(vanishingAttacker: Int32, spentAttacker: Int32, heavyHeldWeapon: Int32, hitConverted: Int32) {
            self.vanishingAttacker = vanishingAttacker; self.spentAttacker = spentAttacker; self.heavyHeldWeapon = heavyHeldWeapon
            self.hitConverted = hitConverted
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
    /// and their life and marks (OriginalWarBattle). The decade arithmetic (ten stages a set, sixty stages)
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
        /// The post-draw commands' request 2 (0x450bb8) in stage mode (0x451160
        /// = 1) zeroes the HP and MP of team-5 characters (type 0) except this
        /// Object's (A51).
        public let killRequestSpared: Int32
        /// A mission stage spawn word the difficulty's HP factor (×1.5 at −1,
        /// ×0.75 at 2) skips (A60; tested before the pseudo-IDs are replaced).
        public let fixedDifficultyHP: Int32
        /// The mission stage's pseudo spawn words (A61–A63), each replaced before
        /// the catalog scan: `heroSpawnWord` by the entry at the cursor (0x44d34c)
        /// of the ten-word hero table at 0x44d324 (game data in the record), the
        /// cursor then stored plus one; at a cursor of 10 or −1 the table is
        /// first shuffled by 50 swaps (streams 0x10f/0x110, range 10) and the
        /// cursor restarts at 0. `troopSpawnWord` by a troop drawn from
        /// `spawnTroops` (stream 0x111: `draw(upper &− lower) &+ lower`);
        /// `troopOrBossSpawnWord` by `bossTroop` on a 1-in-7 roll (stream 0x112)
        /// with four times the HP (after the difficulty factor, wrapping), else a
        /// troop drawn from `spawnTroops` (stream 0x113). An empty or wrapped
        /// range draws 0 without advancing the random state, so it spawns
        /// `lowerBound`.
        public let heroSpawnWord: Int32, troopSpawnWord: Int32, troopOrBossSpawnWord: Int32
        public let spawnTroops: OriginalIDRange
        public let bossTroop: Int32
        /// War's reserve spawn (A67): a unit's life (+0x300, +0x2fc, +0x304) by
        /// its War-table word, 500 for a unit not listed; and for a character
        /// (type 0) of the first side (`s == 0`, team 1) +0x318: 0x8c, then the
        /// unit's mark if listed.
        public let warUnitLife: [Int32: Int32], warSideZeroMarks: [Int32: Int32]
        public init(survivalStages: OriginalIDRange, numberedStages: OriginalIDRange, finalStageSet: OriginalIDRange,
                    stageWeightPlus1: Int32, stageWeightPlus2: Int32, warTroops: OriginalIDSet, stageBackgrounds: [Int32: Int32],
                    killRequestSpared: Int32, fixedDifficultyHP: Int32, heroSpawnWord: Int32, troopSpawnWord: Int32,
                    troopOrBossSpawnWord: Int32, spawnTroops: OriginalIDRange, bossTroop: Int32,
                    warUnitLife: [Int32: Int32], warSideZeroMarks: [Int32: Int32]) {
            self.survivalStages = survivalStages; self.numberedStages = numberedStages; self.finalStageSet = finalStageSet
            self.stageWeightPlus1 = stageWeightPlus1; self.stageWeightPlus2 = stageWeightPlus2; self.warTroops = warTroops
            self.stageBackgrounds = stageBackgrounds; self.killRequestSpared = killRequestSpared; self.fixedDifficultyHP = fixedDifficultyHP
            self.heroSpawnWord = heroSpawnWord; self.troopSpawnWord = troopSpawnWord; self.troopOrBossSpawnWord = troopOrBossSpawnWord
            self.spawnTroops = spawnTroops; self.bossTroop = bossTroop; self.warUnitLife = warUnitLife; self.warSideZeroMarks = warSideZeroMarks
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
    /// Drawing: the Objects the world drawing gives no shadow, and the computer
    /// characters it leaves without the "Com" label (OriginalWorldDrawing).
    public struct Drawing: Equatable, Sendable {
        /// Objects drawn without a shadow.
        public let shadowless: OriginalIDSet
        /// Team-5 characters (type 0) in slots from 20 drawn without a label; every
        /// other such character is labelled "Com".
        public let unlabelledComputers: OriginalIDSet
        public init(shadowless: OriginalIDSet, unlabelledComputers: OriginalIDSet) {
            self.shadowless = shadowless; self.unlabelledComputers = unlabelledComputers
        }
    }
    /// Effects: how the post-draw opoint treats the Objects it creates
    /// (OriginalPostDrawOpoint), the Objects the post-draw lifecycle spawns
    /// (OriginalPostDrawLifecycle) and the object input's two spawns
    /// (OriginalObjectInput).
    public struct Effects: Equatable, Sendable {
        /// Children (in states 3000, 1002, 3006) that do not take their z speed
        /// from the parent's up/down input.
        public let fixedDepthChildren: OriginalIDSet
        /// The child whose z speed, so taken, is quartered.
        public let quarterDepthChild: Int32
        /// Children created with +0x2fc, +0x304 and +0x300 (HP, maximum and
        /// recoverable HP) 10 and +0x308 (MP) 5.
        public let weakChildren: OriginalIDSet
        /// The Object a fighter's command (100, 102 or 104) spawns.
        public let commandEffect: Int32
        /// The particles an Actor sheds when its previous frame was in state 13 or
        /// numbered 200 and its current one is neither (named after the engine's
        /// `deathSlot`; state 13's meaning is not recorded here).
        public let deathParticles: Int32
        /// The particles an Actor sheds whose previous frame was in state 18 or 19:
        /// seven on leaving it, else one when draw(203, 4) gives 0.
        public let fireParticles: Int32
        /// The Objects an Object's hit_Fa 8 splits into: three for up to four
        /// enemies (active type-0 characters of another team with HP above 0), else
        /// (n−3)/2+3; each aims at a random enemy, or at the splitting Object's own
        /// slot without one; the splitting Object's slot is then deactivated.
        public let burstChild: Int32
        /// The Object an Object's hit_Fa 5 sends to each ally (a slot whose activity
        /// is exactly 1 holding a type-0 character of the same team with HP above 0);
        /// the sending Object's slot is then deactivated.
        public let escortChild: Int32
        public init(fixedDepthChildren: OriginalIDSet, quarterDepthChild: Int32, weakChildren: OriginalIDSet, commandEffect: Int32,
                    deathParticles: Int32, fireParticles: Int32, burstChild: Int32, escortChild: Int32) {
            self.fixedDepthChildren = fixedDepthChildren; self.quarterDepthChild = quarterDepthChild; self.weakChildren = weakChildren
            self.commandEffect = commandEffect; self.deathParticles = deathParticles; self.fireParticles = fireParticles
            self.burstChild = burstChild; self.escortChild = escortChild
        }
    }
    /// Lifecycle: the slot prefix's Objects (OriginalPostDrawSlotPrefix), the
    /// characters the scheduler gives no invulnerability on rising
    /// (OriginalActorScheduler), the input's held-back transformation
    /// (OriginalActorInput) and the
    /// round restore's reverted form (OriginalMatchRound).
    public struct Lifecycle: Equatable, Sendable {
        /// Characters whose MP regenerates from half their HP.
        public let halfHPRegen: OriginalIDSet
        /// The Object a character (type 0) in state 9995 becomes, at frame 0.
        public let state9995Object: Int32
        /// The pieces a character in state 9996 sheds (+0x88 = 1): `pieces` for the
        /// first four, `lastPiece` for the fifth; a missing one keeps the retained
        /// index.
        public let pieces: Int32, lastPiece: Int32
        /// Special characters (team 5, or +0x344 not 0) that, in modes 1 and 4, get
        /// no invulnerability countdown (+8 = 15) when they leave a frame in state 14
        /// for one not in state 13 (difficulty 2, 0x450c30, skips it for every
        /// special character first).
        public let noRiseInvulnerability: OriginalIDSet
        /// A character with Object `roundRevertFrom` reverts at a round restore to
        /// the first Object `roundRevertTo` (when 0x458428 is 0).
        public let roundRevertFrom: Int32, roundRevertTo: Int32
        /// The character whose combo 8 (the hit_ja route) to frame 300 is held back
        /// while its HP is above 177 and 0x458428 is 0 (OriginalActorInput). In NTSD
        /// the same character as `roundRevertTo`; that its frame 300 leads to the
        /// `state9995Object` form is the survey's inference, not checked against the DAT.
        public let guardedTransformer: Int32
        public init(halfHPRegen: OriginalIDSet, state9995Object: Int32, pieces: Int32, lastPiece: Int32, noRiseInvulnerability: OriginalIDSet,
                    roundRevertFrom: Int32, roundRevertTo: Int32, guardedTransformer: Int32) {
            self.halfHPRegen = halfHPRegen; self.state9995Object = state9995Object; self.pieces = pieces; self.lastPiece = lastPiece
            self.noRiseInvulnerability = noRiseInvulnerability; self.roundRevertFrom = roundRevertFrom; self.roundRevertTo = roundRevertTo
            self.guardedTransformer = guardedTransformer
        }
    }
    /// Fusion (OriginalWorldFusion, the tail of each contact pass, which is
    /// skipped when 0x44d05c = 2; slots 0..<20). An active slot whose Object is
    /// one of `fusers`, with HP above 0, in state 2, its timer (+0x338) at 0 and
    /// HP below 177 (or 0x458428 = 1), fuses with an active slot of the same
    /// team (+0x364) whose Object ID is `fusionPartnerSum` minus its own (that
    /// one also with HP above 0, timer 0, HP below 177 or 0x458428 = 1, a frame
    /// in 0..<400, in state 2 or (not 14, y 0, slot above 9), less than 50 away
    /// in x and 8 in z, and to the left of the first or in a slot above 9; the
    /// first in a slot below 10) into the first catalog Object `fusedForm`: the
    /// HP merged, frame 290, +0x328 1, the partner's slot at +0x32c, timer
    /// 4500, both IDs at +0x330/+0x334, MP 500, the partner's slot deactivated.
    /// Only when that test fails: a `fusedForm` whose +0x328 is 1, at a frame
    /// below 9 or above 260 with its timer at or below 0, splits back into the
    /// two saved IDs (the partner reconstructed and reactivated in its slot;
    /// HP halved, frame 112, timer 900, MP 0, the team copied). The record
    /// layout, thresholds and timers are engine code (A27 and the input's
    /// route 8 read it too). A `fusionPartnerSum` twice a fuser's ID pairs two
    /// of that ID, which the defuse cannot restore (its scan matches +0x330
    /// first): the partner stays inactive.
    public struct Fusion: Equatable, Sendable {
        public let fusers: OriginalIDSet
        public let fusionPartnerSum: Int32
        public let fusedForm: Int32
        public init(fusers: OriginalIDSet, fusionPartnerSum: Int32, fusedForm: Int32) {
            self.fusers = fusers; self.fusionPartnerSum = fusionPartnerSum; self.fusedForm = fusedForm
        }
    }
    /// A weapon's break (OriginalPostDrawLifecycle, on a weapon creation: an
    /// Object of type 1, 2, 4 or 6 whose +0x31c went below 0). `fragments`: how
    /// many pieces each weapon breaks into at most (a weapon not listed: none;
    /// counts are not negative; the loop stops when no slot from 50 is free);
    /// each piece takes the catalog Object `fragmentObject` (found after its
    /// slot; the last one found is kept for later pieces and calls). Each
    /// piece's own draws then follow its weapon, each test re-reading the
    /// weapon's ID: `highToss` and `lowToss` draw its upward speed (streams 168
    /// and 169), and one role per frame branch picks its frame among four from
    /// that branch's bases (named by the first base; streams 171–196, the
    /// ordinal tiers, 101's base drawn from 177 and the speed redrawn by the 70
    /// and 160 branches (191, 195) are engine code).
    public struct WeaponBreak: Equatable, Sendable {
        public let fragments: [Int32: Int32]
        public let fragmentObject: Int32
        public let highToss: OriginalIDSet, lowToss: OriginalIDSet
        public let frames0: Int32, frames10: Int32, frames150: Int32, frames20: Int32, frames40: Int32, frames54: Int32
        public let frame170: Int32, frame60: Int32, frames70: Int32, frames160: Int32
        public let frame174: OriginalIDSet
        public init(fragments: [Int32: Int32], fragmentObject: Int32, highToss: OriginalIDSet, lowToss: OriginalIDSet,
                    frames0: Int32, frames10: Int32, frames150: Int32, frames20: Int32, frames40: Int32, frames54: Int32,
                    frame170: Int32, frame60: Int32, frames70: Int32, frames160: Int32, frame174: OriginalIDSet) {
            precondition(fragments.values.allSatisfy { $0 >= 0 }, "A weapon's piece count is not negative")
            self.fragments = fragments; self.fragmentObject = fragmentObject; self.highToss = highToss; self.lowToss = lowToss
            self.frames0 = frames0; self.frames10 = frames10; self.frames150 = frames150; self.frames20 = frames20
            self.frames40 = frames40; self.frames54 = frames54; self.frame170 = frame170; self.frame60 = frame60
            self.frames70 = frames70; self.frames160 = frames160; self.frame174 = frame174
        }
    }
    /// The game's interface data (ENGINE_SPLIT E5f): the front menu's bitmaps in
    /// load order (one name per `OriginalFrontMenuResources.slots` entry; the
    /// same name may appear twice) and the rectangle sheets it writes into the
    /// first eleven of them at startup (OriginalFrontMenuResources), the ENDING
    /// screen reading its sheet back (OriginalStageEnding); the initial
    /// interface's bitmaps (OriginalInitialInterfaceLoading, one per slot) and
    /// the common WAVs loading reads before the catalog (OriginalInitialSoundLoading,
    /// one per destination from 0x451db0), the character menu's bitmaps
    /// (OriginalMenuResourceLoading, one per slot), War's two (OriginalWarSetup,
    /// one per slot; the War-menu package) and the menu WAVs WinMain's input
    /// startup loads (OriginalMenuSoundStartup, one per destination from
    /// 0x45560c), each list in load order; the information panel's atlas
    /// rectangles WinMain's panel stage writes (OriginalMenuPanelBitmap) and
    /// BATTLEMODE's War's setup writes (OriginalWarSetup), each frame x, y, width
    /// and height, in frame order.
    public struct Interface: Equatable, Sendable {
        public let frontBitmaps: [String]
        public let frontSheets: [OriginalBitmapSheet]
        public let interfaceBitmaps: [String]
        public let commonSounds: [String]
        /// The character menu's bitmaps (OriginalMenuResourceLoading, one per slot)
        /// and War's two (the War-menu package), in load order.
        public let menuBitmaps: [String], warBitmaps: [String]
        public let menuSounds: [String]
        public let panelFrames: [[Int32]], warModeFrames: [[Int32]]
        public init(frontBitmaps: [String], frontSheets: [OriginalBitmapSheet], interfaceBitmaps: [String], commonSounds: [String],
                    menuBitmaps: [String], warBitmaps: [String], menuSounds: [String], panelFrames: [[Int32]], warModeFrames: [[Int32]]) {
            precondition((panelFrames + warModeFrames).allSatisfy { $0.count == 4 }, "A frame is x, y, width and height")
            self.frontBitmaps = frontBitmaps; self.frontSheets = frontSheets
            self.interfaceBitmaps = interfaceBitmaps; self.commonSounds = commonSounds
            self.menuBitmaps = menuBitmaps; self.warBitmaps = warBitmaps; self.menuSounds = menuSounds
            self.panelFrames = panelFrames; self.warModeFrames = warModeFrames
        }
    }
    /// The character AI (OriginalCharacterAI): the IDs its target choice and fight test.
    /// The names follow the AI's own tests, not what the Objects are in the DAT.
    public struct CharacterAI: Equatable, Sendable {
        /// When 0x450c2c is 1 every character plays at AI level 0 and the bound is
        /// not read. Otherwise, in mode 1, a character of a team other than 5 plays
        /// at level 0 when in slots below 20 or with an ID below this bound (read
        /// only for slots 20 and up); every other character at max(0x450c30, 0).
        public let stageAllyBound: Int32
        /// The AI's ball: one of another team in frames 60–69, or, for `healers`
        /// passing an HP test, of its own team in frames 50–59, makes the character
        /// keep the search's target over items (`near48`) and, within 25 in z and
        /// 150 in x, sets `ball30` and the steering flags; one of its own team in
        /// frames 50–59 within 300×90 ends the item search for later slots
        /// (`seen44`, whatever the HP) and becomes the target of a character
        /// passing another HP test; a target one is walked onto (within 7 in x and
        /// 2 in z) before the special roll.
        public let healBall: Int32
        /// Characters that head for their own team's `healBall`, and that, holding
        /// one of `drinks`, may set its command instead of drinking.
        public let healers: OriginalIDSet
        /// Dangers the AI steps away from: `stateDanger` in state 18,
        /// `frameDanger` in frames 150–170.
        public let stateDanger: Int32, frameDanger: Int32
        /// Objects the AI may pick up (in states 1004 and 2004, not held): the
        /// range and one more ID.
        public let pickupItems: OriginalIDRange
        public let pickupExtra: Int32
        /// `soughtDrink`: skipped by a healthy character, the only pick-up of one
        /// with +0x404 = 1, and, in state 1004, the target of a hurt character
        /// holding nothing; `avoidedDrink`: skipped by a character that avoids it
        /// (+0x2f4 above −1, +0x308 above 250, team 1 in mode 1, or slots 20 and up
        /// in mode 4). Items has the links pass's own drink roles.
        public let soughtDrink: Int32, avoidedDrink: Int32
        /// With no target, a character in one of these frame windows of its own
        /// presses defend.
        public let idleDefenders: [OriginalIDFrames]
        /// The fight. `drinks`: a held one, when +0x404 is 1, is drunk (attack) at
        /// once; a target one is walked to even when far; otherwise a held one
        /// makes the character clear its buttons and steer (out of a corner, which
        /// may lead toward the target, or away within 350×70; each steering
        /// branch ends the step); once clear, on a 1-in-5 roll (stream 0x34) it
        /// drinks, unless it is one of `healers` with `ball30` 0, +0x308 above 150
        /// and a non-zero roll 0x35: that one sets the command 0xd8 or 0xd9 to 3
        /// and goes on to the tactics.
        public let drinks: OriginalIDSet
        /// `rangedBand`: characters whose approach starts beyond 170 (others'
        /// beyond 60), who skip the close attack unless the target is in state 16
        /// and who, empty-handed, strike from up to 350 at a target in state 16,
        /// else step away from a target less than 100 ahead in x (signed) within
        /// 80 in z and strike from up to 300. `rangedJoiner` shares only the
        /// empty-handed stepping away and 300 strike.
        public let rangedBand: OriginalIDSet, rangedJoiner: Int32
        /// Held weapons swung within 115 in x and 6 in z and carried toward a
        /// target within 600×20; `rollingWeapon` (counted only among them) also
        /// swings on an extra roll (stream 0x2b).
        public let meleeWeapons: OriginalIDSet, rollingWeapon: Int32
        /// Held weapons thrown from within 300 (stream 0x2d) unless `weapon`'s scan
        /// of slots 0–19 sets its flag (a live actor of a nonzero team within 15
        /// in z between the two in x, counted only when the target's team is the
        /// character's own).
        public let thrownWeapons: OriginalIDSet
        /// `dashCounters`: characters that defend when the target (its x plus
        /// twice its x speed) is more than 100 and less than 900 away within 5 in
        /// z, and dash (in frame 110 or from 235) at one beyond 90 within 13 in z;
        /// in that dash `dashJumper` jumps instead of attacking on a coin flip
        /// (stream 0x3a). `shortDasher` defends at more than 100 and less than 300
        /// and dashes within 7 in z.
        public let dashCounters: OriginalIDSet, dashJumper: Int32, shortDasher: Int32
        public init(stageAllyBound: Int32, healBall: Int32, healers: OriginalIDSet, stateDanger: Int32, frameDanger: Int32,
                    pickupItems: OriginalIDRange, pickupExtra: Int32, soughtDrink: Int32, avoidedDrink: Int32, idleDefenders: [OriginalIDFrames],
                    drinks: OriginalIDSet, rangedBand: OriginalIDSet, rangedJoiner: Int32, meleeWeapons: OriginalIDSet, rollingWeapon: Int32,
                    thrownWeapons: OriginalIDSet, dashCounters: OriginalIDSet, dashJumper: Int32, shortDasher: Int32) {
            self.stageAllyBound = stageAllyBound; self.healBall = healBall; self.healers = healers
            self.stateDanger = stateDanger; self.frameDanger = frameDanger; self.pickupItems = pickupItems; self.pickupExtra = pickupExtra
            self.soughtDrink = soughtDrink; self.avoidedDrink = avoidedDrink; self.idleDefenders = idleDefenders
            self.drinks = drinks; self.rangedBand = rangedBand; self.rangedJoiner = rangedJoiner; self.meleeWeapons = meleeWeapons
            self.rollingWeapon = rollingWeapon; self.thrownWeapons = thrownWeapons; self.dashCounters = dashCounters
            self.dashJumper = dashJumper; self.shortDasher = shortDasher
        }
    }
    private final class Roles: Sendable {
        let profile: String, reflection: Reflection, armour: Armour, interaction: Interaction, impact: Impact, items: Items, roster: Roster
        let modes: Modes, physics: Physics, drawing: Drawing, effects: Effects, lifecycle: Lifecycle, fusion: Fusion
        let weaponBreak: WeaponBreak, interface: Interface, characterAI: CharacterAI
        let characterAISpecial: any OriginalCharacterAISpecial
        let library: OriginalLibData?
        init(profile: String, reflection: Reflection, armour: Armour, interaction: Interaction, impact: Impact, items: Items, roster: Roster,
             modes: Modes, physics: Physics, drawing: Drawing, effects: Effects, lifecycle: Lifecycle, fusion: Fusion,
             weaponBreak: WeaponBreak, interface: Interface, characterAI: CharacterAI,
             characterAISpecial: any OriginalCharacterAISpecial, library: OriginalLibData?) {
            self.profile = profile; self.reflection = reflection; self.armour = armour; self.interaction = interaction; self.impact = impact
            self.items = items; self.roster = roster; self.modes = modes; self.physics = physics; self.drawing = drawing; self.effects = effects
            self.lifecycle = lifecycle; self.fusion = fusion; self.weaponBreak = weaponBreak; self.interface = interface
            self.characterAI = characterAI
            self.characterAISpecial = characterAISpecial
            self.library = library
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
    public var drawing: Drawing { roles.drawing }
    public var effects: Effects { roles.effects }
    public var lifecycle: Lifecycle { roles.lifecycle }
    public var fusion: Fusion { roles.fusion }
    public var weaponBreak: WeaponBreak { roles.weaponBreak }
    public var interface: Interface { roles.interface }
    public var characterAI: CharacterAI { roles.characterAI }
    /// The game's special moves: a code hook, compared by its type.
    public var characterAISpecial: any OriginalCharacterAISpecial { roles.characterAISpecial }
    /// The bundled lib.dll's extensions (E6d): NTSD 2.4's; nil for LF2 2.0a.
    public var library: OriginalLibData? { roles.library }
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
    public var hitConverted: Int32 { roles.impact.hitConverted }
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
    public var killRequestSpared: Int32 { roles.modes.killRequestSpared }
    public var fixedDifficultyHP: Int32 { roles.modes.fixedDifficultyHP }
    public var heroSpawnWord: Int32 { roles.modes.heroSpawnWord }
    public var troopSpawnWord: Int32 { roles.modes.troopSpawnWord }
    public var troopOrBossSpawnWord: Int32 { roles.modes.troopOrBossSpawnWord }
    public var spawnTroops: OriginalIDRange { roles.modes.spawnTroops }
    public var bossTroop: Int32 { roles.modes.bossTroop }
    public var warUnitLife: [Int32: Int32] { roles.modes.warUnitLife }
    public var warSideZeroMarks: [Int32: Int32] { roles.modes.warSideZeroMarks }
    public var extraDrift: Int32 { roles.physics.extraDrift }
    public var reverseDrift: Int32 { roles.physics.reverseDrift }
    public var lowGravityThrow: Int32 { roles.physics.lowGravityThrow }
    public var midGravityThrow: Int32 { roles.physics.midGravityThrow }
    public var highGravityThrow: Int32 { roles.physics.highGravityThrow }
    public var restingPiece: Int32 { roles.physics.restingPiece }
    public var revivalPicture: OriginalIDRange { roles.physics.revivalPicture }
    public var revivalEffect: Int32 { roles.physics.revivalEffect }
    public var shadowless: OriginalIDSet { roles.drawing.shadowless }
    public var unlabelledComputers: OriginalIDSet { roles.drawing.unlabelledComputers }
    public var fixedDepthChildren: OriginalIDSet { roles.effects.fixedDepthChildren }
    public var quarterDepthChild: Int32 { roles.effects.quarterDepthChild }
    public var weakChildren: OriginalIDSet { roles.effects.weakChildren }
    public var commandEffect: Int32 { roles.effects.commandEffect }
    public var deathParticles: Int32 { roles.effects.deathParticles }
    public var fireParticles: Int32 { roles.effects.fireParticles }
    public var burstChild: Int32 { roles.effects.burstChild }
    public var escortChild: Int32 { roles.effects.escortChild }
    public var halfHPRegen: OriginalIDSet { roles.lifecycle.halfHPRegen }
    public var state9995Object: Int32 { roles.lifecycle.state9995Object }
    public var pieces: Int32 { roles.lifecycle.pieces }
    public var lastPiece: Int32 { roles.lifecycle.lastPiece }
    public var noRiseInvulnerability: OriginalIDSet { roles.lifecycle.noRiseInvulnerability }
    public var roundRevertFrom: Int32 { roles.lifecycle.roundRevertFrom }
    public var roundRevertTo: Int32 { roles.lifecycle.roundRevertTo }
    public var guardedTransformer: Int32 { roles.lifecycle.guardedTransformer }
    public var fusers: OriginalIDSet { roles.fusion.fusers }
    public var fusionPartnerSum: Int32 { roles.fusion.fusionPartnerSum }
    public var fusedForm: Int32 { roles.fusion.fusedForm }
    public var stageAllyBound: Int32 { roles.characterAI.stageAllyBound }
    public var healBall: Int32 { roles.characterAI.healBall }
    public var healers: OriginalIDSet { roles.characterAI.healers }
    public var stateDanger: Int32 { roles.characterAI.stateDanger }
    public var frameDanger: Int32 { roles.characterAI.frameDanger }
    public var pickupItems: OriginalIDRange { roles.characterAI.pickupItems }
    public var pickupExtra: Int32 { roles.characterAI.pickupExtra }
    public var soughtDrink: Int32 { roles.characterAI.soughtDrink }
    public var avoidedDrink: Int32 { roles.characterAI.avoidedDrink }
    public var idleDefenders: [OriginalIDFrames] { roles.characterAI.idleDefenders }
    public var drinks: OriginalIDSet { roles.characterAI.drinks }
    public var rangedBand: OriginalIDSet { roles.characterAI.rangedBand }
    public var rangedJoiner: Int32 { roles.characterAI.rangedJoiner }
    public var meleeWeapons: OriginalIDSet { roles.characterAI.meleeWeapons }
    public var rollingWeapon: Int32 { roles.characterAI.rollingWeapon }
    public var thrownWeapons: OriginalIDSet { roles.characterAI.thrownWeapons }
    public var dashCounters: OriginalIDSet { roles.characterAI.dashCounters }
    public var dashJumper: Int32 { roles.characterAI.dashJumper }
    public var shortDasher: Int32 { roles.characterAI.shortDasher }
    public init(profile: String, reflection: Reflection, armour: Armour, interaction: Interaction, impact: Impact, items: Items,
                roster: Roster, modes: Modes, physics: Physics, drawing: Drawing, effects: Effects, lifecycle: Lifecycle,
                fusion: Fusion, weaponBreak: WeaponBreak, interface: Interface, characterAI: CharacterAI,
                characterAISpecial: any OriginalCharacterAISpecial, library: OriginalLibData? = nil) {
        roles = Roles(profile: profile, reflection: reflection, armour: armour, interaction: interaction, impact: impact, items: items,
                      roster: roster, modes: modes, physics: physics, drawing: drawing, effects: effects, lifecycle: lifecycle,
                      fusion: fusion, weaponBreak: weaponBreak, interface: interface, characterAI: characterAI,
                      characterAISpecial: characterAISpecial, library: library)
    }
    public static func == (a: Self, b: Self) -> Bool {
        a.roles === b.roles || (a.profile == b.profile && a.reflection == b.reflection && a.armour == b.armour && a.interaction == b.interaction
                                && a.impact == b.impact && a.items == b.items && a.roster == b.roster
                                && a.modes == b.modes && a.physics == b.physics
                                && a.drawing == b.drawing && a.effects == b.effects && a.lifecycle == b.lifecycle && a.fusion == b.fusion
                                && a.weaponBreak == b.weaponBreak && a.interface == b.interface
                                && a.characterAI == b.characterAI && a.library == b.library
                                && ObjectIdentifier(type(of: a.characterAISpecial)) == ObjectIdentifier(type(of: b.characterAISpecial)))
    }
}
