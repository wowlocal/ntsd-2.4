import NTSDCore

/// NTSD 2.4's game profile (ENGINE_SPLIT E5): the object IDs the engine's passes
/// test, as the 2.0a EXE tests them. Which of these rules are LF2 2.0a's and
/// which NTSD's stays open until the second reference (D1, E6).
public enum NTSDProfile {
    public static let rules = OriginalGameRules(profile: "NTSD 2.4 2.0a",
        // Objects a reflector sends back, the reflector, and the attackers whose hit (8)
        // or held hit (213) rebinds them to it: OriginalHitDamage, OriginalWorldContacts.
        reflection: .init(reflectable: OriginalIDSet([200, 203, 205, 206, 207, 215, 216]), reflector: 209, rebinder: 8, heldRebinder: 213),
        // The automatic guards: OriginalActorHits.guarded, OriginalHitGuard.
        armour: .init(guardPenetrators: OriginalIDSet([214, 208]), steadyArmour: 37, openingArmour: 6, attackerArmour: 52,
                      alwaysBlocked: OriginalIDSet([124, 220, 221, 222]), armourGuardSound: OriginalIDSet([37, 6])),
        // Special interactions: OriginalHitSpecial, OriginalWorldContacts.
        interaction: .init(holdKind101: OriginalIDSet([120, 124]), pullImmune: OriginalIDSet([201, 202]), teamBypass: 212,
                           countsAsCharacter: OriginalIDSet([201, 202])),
        // What an attacker's hit does to it or to the defender's x impulse: OriginalHitDamage.
        impact: .init(vanishingAttacker: 201, spentAttacker: 214, heavyHeldWeapon: 100),
        // The random and requested item spawns (OriginalWorldHits, OriginalPostDrawCommands), the
        // mission stage's spawn, the camera, the held drinks (OriginalWorldLinks).
        items: .init(itemRange: OriginalIDRange(100..<200), scarceDropItems: OriginalIDSet([122, 123]), scarceRequestedItem: 122, spawnHP200: 122,
                     keptOnScreen: OriginalIDSet([122, 123]), hpDrink: 122, mpDrink: 123),
        // The menus' roster: hidden characters (shown when 0x458428 is 1), Random's
        // candidates, the bracket's favourites.
        roster: .init(hiddenRoster: OriginalIDSet([30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59]),
                      randomCandidates: OriginalIDRange(Int32.min..<30),
                      bracketFavourites: OriginalIDSet([50, 51, 52, 53, 54, 55, 56, 57, 58, 59])),
        // Stage mode's stage numbers (survival, numbered, the last set), the players a mission
        // stage weighs more, War's troops, the arenas the stage sets start on.
        modes: .init(survivalStages: OriginalIDRange(50..<60), numberedStages: OriginalIDRange(Int32.min..<50),
                     finalStageSet: OriginalIDRange(40..<50), stageWeightPlus1: 51, stageWeightPlus2: 52,
                     warTroops: OriginalIDSet([30, 31, 32, 33, 34, 35, 36, 37, 39, 122, 123]),
                     stageBackgrounds: [0: 1, 10: 2, 20: 3, 30: 4, 40: 5, 50: 6]),
        // The actor physics' special Objects and the revival's (OriginalActorPhysics, OriginalWorldPhysics).
        physics: .init(extraDrift: 120, reverseDrift: 101, lowGravityThrow: 124, midGravityThrow: 120, highGravityThrow: 101,
                       restingPiece: 999, revivalPicture: OriginalIDRange(30..<37), revivalEffect: 998))
}
