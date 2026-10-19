import Foundation
import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5c-1b: the automatic guards (A1–A6) take their Objects from the
/// profile. Each case passes under NTSD's profile and changes under a profile
/// that moves only that row's IDs. Synthetic records.
final class NTSDProfileArmourTests: XCTestCase {
    /// NTSD's profile with the given armour roles moved.
    func profile(pen: OriginalIDSet? = nil,steady: Int32? = nil,opening: Int32? = nil,attacker: Int32? = nil,
                 blocked: OriginalIDSet? = nil,sound: OriginalIDSet? = nil) -> OriginalGameRules {
        let a = NTSDProfile.rules.armour
        return OriginalGameRules(profile: "moved",reflection: NTSDProfile.rules.reflection,
            armour: .init(guardPenetrators: pen ?? a.guardPenetrators,steadyArmour: steady ?? a.steadyArmour,openingArmour: opening ?? a.openingArmour,
                          attackerArmour: attacker ?? a.attackerArmour,alwaysBlocked: blocked ?? a.alwaysBlocked,armourGuardSound: sound ?? a.armourGuardSound),
            interaction: NTSDProfile.rules.interaction,impact: NTSDProfile.rules.impact,items: NTSDProfile.rules.items)
    }
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    /// Attacker actor 0 (Object 0), defender actor 1 (Object 1); the interaction's
    /// defense 0, effect 0; the defender's +0xb8, frame and HP as given.
    func pass(attacker: Int32,defender: Int32,b8: Int32,frame: Int32 = 0,rules: OriginalGameRules) throws -> OriginalHitPass {
        var world = try defined(0x7d8),actors = [try defined(0x420),try defined(0x420)]
        for slot in 0..<2 { try world.write(UInt32(slot),at: 0x194+slot*4);try actors[slot].write(UInt32(slot),at: 0x368) }
        try actors[1].write(b8,at: 0xb8);try actors[1].write(frame,at: 0x70);try actors[1].write(Int32(10),at: 0x2fc)
        var headers = [try defined(0x7a4),try defined(0x7a4)]
        try headers[0].write(attacker,at: 0x6f4);try headers[1].write(defender,at: 0x6f4)
        let frameRecord = try defined(0x178),fixed = headers
        var pass = OriginalHitPass(world: world,actors: actors,globals: try defined(0xb440),memory: OriginalContactFrameMemory([]),
            crt: OriginalCRTRandom(state: 1),objectCount: 2,header: { fixed[$0] },frame: { _,_ in frameRecord },rules: rules,sse2: false)
        pass.itrWords = [Int32](repeating: 0,count: 20)
        return pass
    }
    func guarded(attacker: Int32,defender: Int32,b8: Int32,frame: Int32 = 0,bodyKind: Int32 = 0,rules: OriginalGameRules) throws -> Bool {
        var body = try defined(0x40);try body.write(bodyKind,at: 8)
        return try pass(attacker: attacker,defender: defender,b8: b8,frame: frame,rules: rules).guarded(0,1,body)
    }
    let ntsd = NTSDProfile.rules

    func testPenetratorsA1A4() throws {
        let moved = profile(pen: OriginalIDSet([215]))
        XCTAssertFalse(try guarded(attacker: 214,defender: 37,b8: 10,rules: ntsd));XCTAssertTrue(try guarded(attacker: 214,defender: 37,b8: 10,rules: moved))
        XCTAssertFalse(try guarded(attacker: 214,defender: 52,b8: 10,rules: ntsd));XCTAssertTrue(try guarded(attacker: 214,defender: 52,b8: 10,rules: moved))
        XCTAssertTrue(try guarded(attacker: 215,defender: 37,b8: 10,rules: ntsd));XCTAssertFalse(try guarded(attacker: 215,defender: 37,b8: 10,rules: moved))
    }
    func testSteadyArmourA2() throws {
        let moved = profile(steady: 38)
        XCTAssertTrue(try guarded(attacker: 1,defender: 37,b8: 10,rules: ntsd));XCTAssertFalse(try guarded(attacker: 1,defender: 37,b8: 10,rules: moved))
        XCTAssertTrue(try guarded(attacker: 1,defender: 38,b8: 10,rules: moved));XCTAssertFalse(try guarded(attacker: 1,defender: 37,b8: 16,rules: ntsd))
    }
    func testOpeningArmourA3() throws {
        let moved = profile(opening: 7)
        XCTAssertTrue(try guarded(attacker: 1,defender: 6,b8: 1,frame: 5,rules: ntsd));XCTAssertFalse(try guarded(attacker: 1,defender: 6,b8: 1,frame: 5,rules: moved))
        XCTAssertTrue(try guarded(attacker: 1,defender: 7,b8: 1,frame: 5,rules: moved));XCTAssertFalse(try guarded(attacker: 1,defender: 6,b8: 2,frame: 5,rules: ntsd))
    }
    func testAttackerArmourA4() throws {
        let moved = profile(attacker: 53)
        XCTAssertTrue(try guarded(attacker: 1,defender: 52,b8: 10,rules: ntsd));XCTAssertFalse(try guarded(attacker: 1,defender: 52,b8: 10,rules: moved))
        XCTAssertTrue(try guarded(attacker: 1,defender: 53,b8: 10,rules: moved))
    }
    func testAlwaysBlockedA5() throws {
        let moved = profile(blocked: OriginalIDSet([125]))
        // Defending (body kind 7), same facing, no armour: only the listed attackers are blocked.
        XCTAssertTrue(try guarded(attacker: 124,defender: 1,b8: 100,bodyKind: 7,rules: ntsd))
        XCTAssertFalse(try guarded(attacker: 124,defender: 1,b8: 100,bodyKind: 7,rules: moved))
        XCTAssertTrue(try guarded(attacker: 125,defender: 1,b8: 100,bodyKind: 7,rules: moved))
    }
    func testArmourGuardSoundA6() throws {
        enum Stop: Error { case afterSound }
        func firstSound(_ defender: Int32,_ rules: OriginalGameRules) throws -> OriginalHitEvent? {
            var p = try pass(attacker: 1,defender: defender,b8: 0,rules: rules),seen: OriginalHitEvent?
            do { try p.guardHit(0,1,try defined(0x40),observe: { seen = $0;throw Stop.afterSound }) } catch Stop.afterSound {}
            return seen
        }
        let moved = profile(sound: OriginalIDSet([38]))
        XCTAssertEqual(try firstSound(37,ntsd),.builtinSound(x: 0,index: 17));XCTAssertEqual(try firstSound(37,moved),.builtinSound(x: 0,index: 1))
        XCTAssertEqual(try firstSound(38,moved),.builtinSound(x: 0,index: 17));XCTAssertEqual(try firstSound(1,ntsd),.builtinSound(x: 0,index: 1))
    }
}
