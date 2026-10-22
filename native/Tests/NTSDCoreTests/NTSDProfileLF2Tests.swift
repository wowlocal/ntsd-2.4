import XCTest
import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E6b: NTSD's profile composes the engine's LF2 2.0a rules
/// (OriginalGameRules.lf2) instead of spelling them out; every family must
/// equal the literal NTSDProfile.swift held before (copied verbatim from
/// acea378c's native/Sources/NTSDProfile/NTSDProfile.swift).
final class NTSDProfileLF2Tests: XCTestCase {
    static let before = OriginalGameRules(profile: "NTSD 2.4 2.0a",
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
            impact: .init(vanishingAttacker: 201, spentAttacker: 214, heavyHeldWeapon: 100, hitConverted: 300),
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
                         stageBackgrounds: [0: 1, 10: 2, 20: 3, 30: 4, 40: 5, 50: 6], killRequestSpared: 300, fixedDifficultyHP: 300,
                         heroSpawnWord: 1000, troopSpawnWord: 3000, troopOrBossSpawnWord: 3001, spawnTroops: OriginalIDRange(30..<32),
                         bossTroop: 32,
                         warUnitLife: [36: 250, 37: 200, 35: 200, 32: 200, 39: 150, 33: 150, 34: 100, 31: 50, 30: 50, 122: 200],
                         warSideZeroMarks: [37: 0x72]),
            // The actor physics' special Objects and the revival's (OriginalActorPhysics, OriginalWorldPhysics).
            physics: .init(extraDrift: 120, reverseDrift: 101, lowGravityThrow: 124, midGravityThrow: 120, highGravityThrow: 101,
                           restingPiece: 999, revivalPicture: OriginalIDRange(30..<37), revivalEffect: 998),
            // The world drawing: no shadow; team-5 computers left without the "Com" label.
            drawing: .init(shadowless: OriginalIDSet([223, 224]),
                           unlabelledComputers: OriginalIDSet([30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49])),
            // The post-draw opoint's children and the lifecycle's spawned Objects.
            effects: .init(fixedDepthChildren: OriginalIDSet([223, 224]), quarterDepthChild: 211, weakChildren: OriginalIDSet([5, 52]),
                           commandEffect: 998, deathParticles: 999, fireParticles: 999, burstChild: 225, escortChild: 219),
            // The slot prefix, the scheduler's invulnerability on rising, the round restore.
            lifecycle: .init(halfHPRegen: OriginalIDSet([51, 52]), state9995Object: 50, pieces: 217, lastPiece: 218,
                             noRiseInvulnerability: OriginalIDSet([30, 31, 32, 33, 34, 35, 36, 37, 39]), roundRevertFrom: 50, roundRevertTo: 6,
                             guardedTransformer: 6),
            // Fusion: 7 and 8 fuse into 51 (their IDs add to 15).
            fusion: .init(fusers: OriginalIDSet([7, 8]), fusionPartnerSum: 15, fusedForm: 51),
            // A weapon's break: its pieces, their Object and each weapon's draws.
            weaponBreak: .init(fragments: [101: 7, 218: 7, 100: 5, 213: 5, 217: 5, 201: 3, 150: 13, 151: 15, 120: 3, 124: 3, 121: 4, 122: 9,
                                           123: 9],
                               fragmentObject: 999, highToss: OriginalIDSet([150, 151, 213]),
                               lowToss: OriginalIDSet([100, 201, 101, 120, 121, 122, 123, 124, 217, 218]),
                               frames0: 150, frames10: 100, frames150: 213, frames20: 101, frames40: 151, frames54: 120, frame170: 124,
                               frame60: 121, frames70: 122, frames160: 123, frame174: OriginalIDSet([217, 218])),
            interface: NTSDProfile.rules.interface,
            // The character AI's target choice and fight.
            characterAI: .init(stageAllyBound: 30, healBall: 200, healers: OriginalIDSet([2, 34]), stateDanger: 211, frameDanger: 212,
                               pickupItems: OriginalIDRange(100..<200), pickupExtra: 213, soughtDrink: 122, avoidedDrink: 123,
                               idleDefenders: [OriginalIDFrames(7, frames: 255...261), OriginalIDFrames(9, frames: 280...290),
                                               OriginalIDFrames(32, frames: 240...245)],
                               drinks: OriginalIDSet([122, 123]), rangedBand: OriginalIDSet([4, 5, 31]), rangedJoiner: 36,
                               meleeWeapons: OriginalIDSet([100, 101, 120, 121, 124]), rollingWeapon: 124, thrownWeapons: OriginalIDSet([150, 151]),
                               dashCounters: OriginalIDSet([2, 4, 6, 9, 10, 11, 8, 7, 33, 34]), dashJumper: 34, shortDasher: 1),
            characterAISpecial: NTSDProfile.rules.characterAISpecial,
            library: OriginalLibData())

    func testEveryFamilyEqualsTheEarlierLiteral() {
        let now = NTSDProfile.rules,before = Self.before
        XCTAssertEqual(now.profile,before.profile)
        XCTAssertEqual(now.reflection,before.reflection);XCTAssertEqual(now.armour,before.armour)
        XCTAssertEqual(now.interaction,before.interaction);XCTAssertEqual(now.impact,before.impact)
        XCTAssertEqual(now.items,before.items);XCTAssertEqual(now.roster,before.roster)
        XCTAssertEqual(now.modes,before.modes);XCTAssertEqual(now.physics,before.physics)
        XCTAssertEqual(now.drawing,before.drawing);XCTAssertEqual(now.effects,before.effects)
        XCTAssertEqual(now.lifecycle,before.lifecycle);XCTAssertEqual(now.fusion,before.fusion)
        XCTAssertEqual(now.weaponBreak,before.weaponBreak);XCTAssertEqual(now.characterAI,before.characterAI)
        XCTAssertEqual(now.library,before.library)
        XCTAssertEqual(now,before)
    }

    /// E6d-1: NTSD carries its bundled library; copies keep it unless they replace it.
    func testNTSDCarriesTheLibraryAndCopiesKeepIt() {
        XCTAssertEqual(NTSDProfile.rules.library, OriginalLibData())
        XCTAssertEqual(NTSDProfile.rules.with(profile: "copy").library, OriginalLibData())
        XCTAssertNil(NTSDProfile.rules.with(library: .some(nil)).library)
        XCTAssertNotEqual(NTSDProfile.rules, NTSDProfile.rules.with(profile: NTSDProfile.rules.profile, library: .some(nil)))
    }

    /// The engine's LF2 2.0a values are the same families.
    func testTheEngineFamiliesAreTheEarlierLiteral() {
        let before = Self.before
        XCTAssertEqual(OriginalGameRules.Reflection.lf2,before.reflection);XCTAssertEqual(OriginalGameRules.Armour.lf2,before.armour)
        XCTAssertEqual(OriginalGameRules.Interaction.lf2,before.interaction);XCTAssertEqual(OriginalGameRules.Impact.lf2,before.impact)
        XCTAssertEqual(OriginalGameRules.Items.lf2,before.items);XCTAssertEqual(OriginalGameRules.Roster.lf2,before.roster)
        XCTAssertEqual(OriginalGameRules.Modes.lf2,before.modes);XCTAssertEqual(OriginalGameRules.Physics.lf2,before.physics)
        XCTAssertEqual(OriginalGameRules.Drawing.lf2,before.drawing);XCTAssertEqual(OriginalGameRules.Effects.lf2,before.effects)
        XCTAssertEqual(OriginalGameRules.Lifecycle.lf2,before.lifecycle);XCTAssertEqual(OriginalGameRules.Fusion.lf2,before.fusion)
        XCTAssertEqual(OriginalGameRules.WeaponBreak.lf2,before.weaponBreak);XCTAssertEqual(OriginalGameRules.CharacterAI.lf2,before.characterAI)
    }
}
