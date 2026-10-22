/// LF2 2.0a's object-ID rules (ENGINE_SPLIT E6b): each family's values as LF2
/// 2.0a's lf2.exe tests them. NTSD 2.4.exe is that file's code plus a lib.dll
/// loader (with its own resources), and no lib.dll hook always bypasses one of
/// these tests: each runs with and without the library, except that the 4214d7
/// hook skips the requested-item filter (itemRange, scarceRequestedItem) for
/// command word 3 (E6a, docs/evidence/es-e6a-classification.json). So NTSD's
/// profile composes them unchanged. A game supplies its interface (names and
/// rectangles of its content); LF2 2.0a's special moves are the default
/// (OriginalLF2CharacterAISpecial, E6c).
extension OriginalGameRules {
    /// LF2 2.0a's rules with a game's interface and, by default, LF2 2.0a's special moves.
    public static func lf2(profile: String, interface: Interface,
                           characterAISpecial: any OriginalCharacterAISpecial = OriginalLF2CharacterAISpecial()) -> OriginalGameRules {
        OriginalGameRules(profile: profile, reflection: .lf2, armour: .lf2, interaction: .lf2, impact: .lf2, items: .lf2, roster: .lf2,
                          modes: .lf2, physics: .lf2, drawing: .lf2, effects: .lf2, lifecycle: .lf2, fusion: .lf2, weaponBreak: .lf2,
                          interface: interface, characterAI: .lf2, characterAISpecial: characterAISpecial)
    }
}

extension OriginalGameRules.Reflection {
    /// Objects a reflector sends back, the reflector, and the attackers whose hit (8)
    /// or held hit (213) rebinds them to it: OriginalHitDamage, OriginalWorldContacts.
    public static let lf2 = Self(reflectable: OriginalIDSet([200, 203, 205, 206, 207, 215, 216]), reflector: 209, rebinder: 8, heldRebinder: 213)
}

extension OriginalGameRules.Armour {
    /// The automatic guards: OriginalActorHits.guarded, OriginalHitGuard.
    public static let lf2 = Self(guardPenetrators: OriginalIDSet([214, 208]), steadyArmour: 37, openingArmour: 6, attackerArmour: 52,
                                 alwaysBlocked: OriginalIDSet([124, 220, 221, 222]), armourGuardSound: OriginalIDSet([37, 6]))
}

extension OriginalGameRules.Interaction {
    /// Special interactions: OriginalHitSpecial, OriginalWorldContacts.
    public static let lf2 = Self(holdKind101: OriginalIDSet([120, 124]), pullImmune: OriginalIDSet([201, 202]), teamBypass: 212,
                                 countsAsCharacter: OriginalIDSet([201, 202]))
}

extension OriginalGameRules.Impact {
    /// What an attacker's hit does to it or to the defender's x impulse: OriginalHitDamage.
    public static let lf2 = Self(vanishingAttacker: 201, spentAttacker: 214, heavyHeldWeapon: 100, hitConverted: 300)
}

extension OriginalGameRules.Items {
    /// The random and requested item spawns (OriginalWorldHits, OriginalPostDrawCommands), the
    /// mission stage's spawn, the camera, the held drinks (OriginalWorldLinks).
    public static let lf2 = Self(itemRange: OriginalIDRange(100..<200), scarceDropItems: OriginalIDSet([122, 123]), scarceRequestedItem: 122, spawnHP200: 122,
                                 keptOnScreen: OriginalIDSet([122, 123]), hpDrink: 122, mpDrink: 123)
}

extension OriginalGameRules.Roster {
    /// The menus' roster: hidden characters (shown when 0x458428 is 1), Random's
    /// candidates, the bracket's favourites.
    public static let lf2 = Self(hiddenRoster: OriginalIDSet([30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59]),
                                 randomCandidates: OriginalIDRange(Int32.min..<30),
                                 bracketFavourites: OriginalIDSet([50, 51, 52, 53, 54, 55, 56, 57, 58, 59]))
}

extension OriginalGameRules.Modes {
    /// Stage mode's stage numbers (survival, numbered, the last set), the players a mission
    /// stage weighs more, War's troops, the arenas the stage sets start on.
    public static let lf2 = Self(survivalStages: OriginalIDRange(50..<60), numberedStages: OriginalIDRange(Int32.min..<50),
                                 finalStageSet: OriginalIDRange(40..<50), stageWeightPlus1: 51, stageWeightPlus2: 52,
                                 warTroops: OriginalIDSet([30, 31, 32, 33, 34, 35, 36, 37, 39, 122, 123]),
                                 stageBackgrounds: [0: 1, 10: 2, 20: 3, 30: 4, 40: 5, 50: 6], killRequestSpared: 300, fixedDifficultyHP: 300,
                                 heroSpawnWord: 1000, troopSpawnWord: 3000, troopOrBossSpawnWord: 3001, spawnTroops: OriginalIDRange(30..<32),
                                 bossTroop: 32,
                                 warUnitLife: [36: 250, 37: 200, 35: 200, 32: 200, 39: 150, 33: 150, 34: 100, 31: 50, 30: 50, 122: 200],
                                 warSideZeroMarks: [37: 0x72])
}

extension OriginalGameRules.Physics {
    /// The actor physics' special Objects and the revival's (OriginalActorPhysics, OriginalWorldPhysics).
    public static let lf2 = Self(extraDrift: 120, reverseDrift: 101, lowGravityThrow: 124, midGravityThrow: 120, highGravityThrow: 101,
                                 restingPiece: 999, revivalPicture: OriginalIDRange(30..<37), revivalEffect: 998)
}

extension OriginalGameRules.Drawing {
    /// The world drawing: no shadow; team-5 computers left without the "Com" label.
    public static let lf2 = Self(shadowless: OriginalIDSet([223, 224]),
                                 unlabelledComputers: OriginalIDSet([30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49]))
}

extension OriginalGameRules.Effects {
    /// The post-draw opoint's children and the lifecycle's spawned Objects.
    public static let lf2 = Self(fixedDepthChildren: OriginalIDSet([223, 224]), quarterDepthChild: 211, weakChildren: OriginalIDSet([5, 52]),
                                 commandEffect: 998, deathParticles: 999, fireParticles: 999, burstChild: 225, escortChild: 219)
}

extension OriginalGameRules.Lifecycle {
    /// The slot prefix, the scheduler's invulnerability on rising, the round restore.
    public static let lf2 = Self(halfHPRegen: OriginalIDSet([51, 52]), state9995Object: 50, pieces: 217, lastPiece: 218,
                                 noRiseInvulnerability: OriginalIDSet([30, 31, 32, 33, 34, 35, 36, 37, 39]), roundRevertFrom: 50, roundRevertTo: 6,
                                 guardedTransformer: 6)
}

extension OriginalGameRules.Fusion {
    /// Fusion: 7 and 8 fuse into 51 (their IDs add to 15).
    public static let lf2 = Self(fusers: OriginalIDSet([7, 8]), fusionPartnerSum: 15, fusedForm: 51)
}

extension OriginalGameRules.WeaponBreak {
    /// A weapon's break: its pieces, their Object and each weapon's draws.
    public static let lf2 = Self(fragments: [101: 7, 218: 7, 100: 5, 213: 5, 217: 5, 201: 3, 150: 13, 151: 15, 120: 3, 124: 3, 121: 4, 122: 9,
                                             123: 9],
                                 fragmentObject: 999, highToss: OriginalIDSet([150, 151, 213]),
                                 lowToss: OriginalIDSet([100, 201, 101, 120, 121, 122, 123, 124, 217, 218]),
                                 frames0: 150, frames10: 100, frames150: 213, frames20: 101, frames40: 151, frames54: 120, frame170: 124,
                                 frame60: 121, frames70: 122, frames160: 123, frame174: OriginalIDSet([217, 218]))
}

extension OriginalGameRules.CharacterAI {
    /// The character AI's target choice and fight.
    public static let lf2 = Self(stageAllyBound: 30, healBall: 200, healers: OriginalIDSet([2, 34]), stateDanger: 211, frameDanger: 212,
                                 pickupItems: OriginalIDRange(100..<200), pickupExtra: 213, soughtDrink: 122, avoidedDrink: 123,
                                 idleDefenders: [OriginalIDFrames(7, frames: 255...261), OriginalIDFrames(9, frames: 280...290),
                                                 OriginalIDFrames(32, frames: 240...245)],
                                 drinks: OriginalIDSet([122, 123]), rangedBand: OriginalIDSet([4, 5, 31]), rangedJoiner: 36,
                                 meleeWeapons: OriginalIDSet([100, 101, 120, 121, 124]), rollingWeapon: 124, thrownWeapons: OriginalIDSet([150, 151]),
                                 dashCounters: OriginalIDSet([2, 4, 6, 9, 10, 11, 8, 7, 33, 34]), dashJumper: 34, shortDasher: 1)
}
