import Foundation
import XCTest
@testable import RandoriCore
import NTSDProfile

/// ENGINE_SPLIT E5c-1d: the impact rows take their Objects from the profile:
/// A11 (a held heavy weapon) through hitHorizontal, A9 and A10 through damageHit,
/// and A8 (the reflector keeping a state-3000 ball, E5c-1a) through damageHit too,
/// each under NTSD's profile and a moved one.
final class NTSDProfileImpactTests: XCTestCase {
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func rules(heavy: Int32) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(impact: .init(vanishingAttacker: n.vanishingAttacker,spentAttacker: n.spentAttacker,heavyHeldWeapon: heavy,
            hitConverted: n.hitConverted))
    }
    /// A held attacker (+0x98 -1, facing right) with dvx 3 hits a type-4 defender at rest:
    /// the facing impulse gives the defender's +0x28 3; the heavy weapon then makes it 7.5, raised to 10.
    func swing(attacker: Int32,rules: OriginalGameRules) throws -> (impulse: Double,events: [OriginalHitEvent]) {
        var world = try defined(0x7d8),actors = [try defined(0x420),try defined(0x420)]
        for slot in 0..<2 { try world.write(UInt32(slot),at: 0x194+slot*4);try actors[slot].write(UInt32(slot),at: 0x368) }
        try actors[0].write(Int32(-1),at: 0x98)
        var headers = [try defined(0x7a4),try defined(0x7a4)]
        try headers[0].write(attacker,at: 0x6f4);try headers[1].write(Int32(150),at: 0x6f4);try headers[1].write(Int32(4),at: 0x6f8)
        let frameRecord = try defined(0x178),fixed = headers
        var pass = OriginalHitPass(world: world,actors: actors,globals: try defined(0xb440),memory: OriginalContactFrameMemory([]),
            crt: OriginalCRTRandom(state: 1),objectCount: 2,header: { fixed[$0] },frame: { _,_ in frameRecord },rules: rules,sse2: false)
        pass.itrWords = [Int32](repeating: 0,count: 20);pass.itrWords[5] = 3
        var events: [OriginalHitEvent] = []
        try pass.hitHorizontal(0,1,observe: { events.append($0) })
        return (try pass.actors[1].binary64(at: 0x28),events)
    }
    func testHeavyHeldWeaponA11() throws {
        let ntsd = try swing(attacker: 100,rules: NTSDProfile.rules),moved = try swing(attacker: 100,rules: rules(heavy: 101))
        XCTAssertEqual(ntsd.impulse,10);XCTAssertEqual(ntsd.events,[.builtinSound(x: 0,index: 13)])
        XCTAssertEqual(moved.impulse,3);XCTAssertEqual(moved.events,[])
        XCTAssertEqual(try swing(attacker: 101,rules: rules(heavy: 101)).impulse,10)
    }

    func rules(vanishing: Int32? = nil,spent: Int32? = nil,reflector: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(
            reflection: .init(reflectable: n.reflectable,reflector: reflector ?? n.reflector,rebinder: n.rebinder,heldRebinder: n.heldRebinder),
            impact: .init(vanishingAttacker: vanishing ?? n.vanishingAttacker,spentAttacker: spent ?? n.spentAttacker,heavyHeldWeapon: n.heavyHeldWeapon,
                hitConverted: n.hitConverted))
    }
    /// damageHit by attacker actor 0 on defender actor 1 (World slots 0 and 1 active, the attacker's HP 100).
    func damage(attacker: Int32,defender: Int32,defenderType: Int32,attackerState: Int32 = 0,rules: OriginalGameRules) throws -> OriginalHitPass {
        var world = try defined(0x7d8),actors = [try defined(0x420),try defined(0x420)]
        for slot in 0..<2 { try world.write(UInt32(slot),at: 0x194+slot*4);try world.write(UInt8(1),at: 4+slot);try actors[slot].write(UInt32(slot),at: 0x368) }
        try actors[0].write(Int32(100),at: 0x2fc);try actors[1].write(Int32(100),at: 0x2fc);try actors[0].write(Int32(7),at: 0x70)
        var headers = [try defined(0x7a4),try defined(0x7a4)]
        try headers[0].write(attacker,at: 0x6f4);try headers[1].write(defender,at: 0x6f4);try headers[1].write(defenderType,at: 0x6f8)
        var attackerFrame = try defined(0x178);try attackerFrame.write(attackerState,at: 8)
        let plain = try defined(0x178),fixed = headers,ownFrame = attackerFrame
        var pass = OriginalHitPass(world: world,actors: actors,globals: try defined(0xb440),memory: OriginalContactFrameMemory([]),
            crt: OriginalCRTRandom(state: 1),objectCount: 2,header: { fixed[$0] },frame: { n,_ in n == 0 ? ownFrame : plain },rules: rules,sse2: false)
        pass.itrWords = [Int32](repeating: 0,count: 20)
        var spark: Int32 = 0
        _ = try pass.damageHit(0,1,try defined(0x40),spark: &spark,observe: { _ in })
        return pass
    }
    func testVanishingAttackerA9() throws {
        XCTAssertEqual(try damage(attacker: 201,defender: 1,defenderType: 0,rules: NTSDProfile.rules).world.integer(at: 4,as: UInt8.self),0)
        XCTAssertEqual(try damage(attacker: 201,defender: 1,defenderType: 0,rules: rules(vanishing: 202)).world.integer(at: 4,as: UInt8.self),1)
        XCTAssertEqual(try damage(attacker: 202,defender: 1,defenderType: 0,rules: rules(vanishing: 202)).world.integer(at: 4,as: UInt8.self),0)
    }
    func testSpentAttackerA10() throws {
        XCTAssertEqual(try damage(attacker: 214,defender: 1,defenderType: 0,rules: NTSDProfile.rules).actors[0].integer(at: 0x2fc,as: Int32.self),0)
        XCTAssertEqual(try damage(attacker: 214,defender: 1,defenderType: 0,rules: rules(spent: 215)).actors[0].integer(at: 0x2fc,as: Int32.self),100)
        XCTAssertEqual(try damage(attacker: 215,defender: 1,defenderType: 0,rules: rules(spent: 215)).actors[0].integer(at: 0x2fc,as: Int32.self),0)
    }
    /// A8: a reflector in state 3000 keeps going (+0x70 unchanged) after hitting a reflectable ball; otherwise frame 10.
    func testReflectorKeepsGoingA8() throws {
        XCTAssertEqual(try damage(attacker: 209,defender: 200,defenderType: 3,attackerState: 3000,rules: NTSDProfile.rules).actors[0].integer(at: 0x70,as: Int32.self),7)
        XCTAssertEqual(try damage(attacker: 209,defender: 200,defenderType: 3,attackerState: 3000,rules: rules(reflector: 210)).actors[0].integer(at: 0x70,as: Int32.self),10)
        XCTAssertEqual(try damage(attacker: 210,defender: 200,defenderType: 3,attackerState: 3000,rules: rules(reflector: 210)).actors[0].integer(at: 0x70,as: Int32.self),7)
    }
}
