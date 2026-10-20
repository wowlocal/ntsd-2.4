@testable import NTSDCore

/// ENGINE_SPLIT E5c-2c: the engine tests' own game rules (a game's profile, such
/// as NTSD's, is not visible here). Synthetic: every ID role is −1 and every set
/// or other range empty (no record these tests build carries −1 or a member at +0x6f4),
/// except the item range 100..<200, which the requested-items tests' pools
/// (Object ID 100) are built on, and the effects' 998/999 (the lifecycle
/// pools: three of the request-slot tests depend on them). No engine test reaches the menus (Random would
/// find no candidate there), stage mode, the camera or War.
extension OriginalGameRules {
    static let engineTests = OriginalGameRules(profile: "engine tests (synthetic)",
        reflection: .init(reflectable: OriginalIDSet([]), reflector: -1, rebinder: -1, heldRebinder: -1),
        armour: .init(guardPenetrators: OriginalIDSet([]), steadyArmour: -1, openingArmour: -1, attackerArmour: -1,
                      alwaysBlocked: OriginalIDSet([]), armourGuardSound: OriginalIDSet([])),
        interaction: .init(holdKind101: OriginalIDSet([]), pullImmune: OriginalIDSet([]), teamBypass: -1, countsAsCharacter: OriginalIDSet([])),
        impact: .init(vanishingAttacker: -1, spentAttacker: -1, heavyHeldWeapon: -1),
        items: .init(itemRange: OriginalIDRange(100..<200), scarceDropItems: OriginalIDSet([]), scarceRequestedItem: -1, spawnHP200: -1,
                     keptOnScreen: OriginalIDSet([]), hpDrink: -1, mpDrink: -1),
        roster: .init(hiddenRoster: OriginalIDSet([]), randomCandidates: OriginalIDRange(0..<0), bracketFavourites: OriginalIDSet([])),
        modes: .init(survivalStages: OriginalIDRange(0..<0), numberedStages: OriginalIDRange(0..<0), finalStageSet: OriginalIDRange(0..<0),
                     stageWeightPlus1: -1, stageWeightPlus2: -1, warTroops: OriginalIDSet([]), stageBackgrounds: [:]),
        physics: .init(extraDrift: -1, reverseDrift: -1, lowGravityThrow: -1, midGravityThrow: -1, highGravityThrow: -1, restingPiece: -1,
                       revivalPicture: OriginalIDRange(0..<0), revivalEffect: -1),
        drawing: .init(shadowless: OriginalIDSet([]), unlabelledComputers: OriginalIDSet([])),
        // The request-slot tests' lifecycle pools are built on Objects 998 and 999.
        effects: .init(fixedDepthChildren: OriginalIDSet([]), quarterDepthChild: -1, weakChildren: OriginalIDSet([]),
                       commandEffect: 998, deathParticles: 999, fireParticles: 999, burstChild: -1, escortChild: -1),
        // The request-slot tests' slot prefix pool is built on Object 217.
        lifecycle: .init(halfHPRegen: OriginalIDSet([]), state9995Object: -1, pieces: 217, lastPiece: 218, noRiseInvulnerability: OriginalIDSet([]),
                         roundRevertFrom: -1, roundRevertTo: -1))
}
