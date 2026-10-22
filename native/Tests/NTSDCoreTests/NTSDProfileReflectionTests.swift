import Foundation
import XCTest
@testable import RandoriCore
import NTSDProfile

/// ENGINE_SPLIT E5c-0: the reflection rule reaches both of its sites through the
/// profile (the corpus fixtures load only IDs 2, 7, 8 and 51 and never reach it).
/// Synthetic records; with no rule, IDs 200 and 209 behave like any other ID there.
final class NTSDProfileReflectionTests: XCTestCase {
    /// No reflection rule (no reflectable Object, no reflector); NTSD's other families.
    static let empty = NTSDProfile.rules.with(profile: "empty",
        reflection: .init(reflectable: OriginalIDSet([]),reflector: .max,rebinder: .max,heldRebinder: .max))
    /// The same reflectables with other reflector IDs: behaviour must follow the profile, not 209/8/213.
    static let moved = NTSDProfile.rules.with(
        reflection: .init(reflectable: NTSDProfile.rules.reflectable,reflector: 210,rebinder: 9,heldRebinder: 214))

    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func header(_ id: Int32) throws -> OriginalStateRecord { var h = try defined(0x7a4);try h.write(id,at: 0x6f4);return h }

    /// OriginalWorldContacts' 419380: an attacker whose ID the rule lists skips its interaction on a 209 defender.
    func contacts(attacker: Int32,defender: Int32,rules: OriginalGameRules) throws -> (events: [OriginalWorldContactsEvent],error: String?) {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5,count: 0x7d8),actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5,count: 0x420),count: 400),selector: 2)
        var world = bootstrap.world,actors = bootstrap.actors
        var globals = try defined(0xb440),frame = try defined(0x178),boxes = try defined(120)
        let headers = [try header(attacker),try header(defender)]
        for slot in 0..<400 { try actors[slot].write(UInt32(slot < 2 ? slot : 0),at: 0x368);try world.write(UInt8(slot < 2 ? 1 : 0),at: 4+slot) }
        for slot in 0..<2 {
            try actors[slot].write(Int32(0),at: 8);try actors[slot].write(Int32(123),at: 0x7c)
            try actors[slot].write(Int32(0),at: 0x2e8);try actors[slot].write(Int32(slot+1),at: 0x364)
        }
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        try frame.write(Int32(1),at: 0x128);try frame.write(Int32(1),at: 0x12c)
        try frame.write(UInt32(0x51000000),at: 0x130);try frame.write(UInt32(0x51000050),at: 0x134)
        for base in [0x138,0x148] { for (n,v): (Int,Int32) in [-20,-20,40,40].enumerated() { try frame.write(v,at: base+n*4) } }
        for base in [0,80] { for (n,v): (Int,Int32) in [-20,-20,40,40].enumerated() { try boxes.write(v,at: base+4+n*4) } }
        let memory = OriginalContactFrameMemory([.init(address: 0x51000000,kind: .interactions,storage: boxes)])
        var events: [OriginalWorldContactsEvent] = []
        do {
            try OriginalWorldContacts.apply(world: &world,actors: &actors,globals: &globals,objectCount: 2,header: { headers[$0] },
                frame: { _,_ in frame },heapWord: { try memory.word($0) },rules: rules,observe: { events.append($0) })
            return (events,nil)
        } catch { return (events,"\(error)") }
    }
    func testContactsSkipAReflectableAttackerOnA209Defender() throws {
        let baseline = try contacts(attacker: 2,defender: 2,rules: NTSDProfile.rules)
        let none = try contacts(attacker: 200,defender: 209,rules: Self.empty)
        let reflected = try contacts(attacker: 200,defender: 209,rules: NTSDProfile.rules)
        XCTAssertEqual(none.events,baseline.events,"without the rule, 200 on 209 is an ordinary contact");XCTAssertEqual(none.error,baseline.error)
        XCTAssertTrue(none.events.contains { if case .random(attacker: 0,defender: 1,_,_,_) = $0 { return true };return false })
        XCTAssertFalse(reflected.events.contains { if case .random(attacker: 0,defender: 1,_,_,_) = $0 { return true };return false })
        XCTAssertNotEqual(reflected.events,none.events)
        // A non-member attacker is not skipped.
        XCTAssertEqual(try contacts(attacker: 201,defender: 209,rules: NTSDProfile.rules).events,try contacts(attacker: 201,defender: 209,rules: Self.empty).events)
    }

    /// OriginalHitDamage's projectileHit (42f70f..): a 209 attacker takes over a defender whose ID the rule
    /// lists (A14); an 8 attacker (A15) or a held 213 (A16) rebinds it to the first 209 Object (here Object 2).
    func projectileHit(attacker: Int32,defender: Int32,held: Bool = false,reflectorObject: Int32 = 209,rules: OriginalGameRules) throws -> OriginalStateRecord {
        var world = try defined(0x7d8),actors = [try defined(0x420),try defined(0x420)]
        for slot in 0..<2 { try world.write(UInt32(slot),at: 0x194+slot*4);try actors[slot].write(UInt32(slot),at: 0x368) }
        try actors[0].write(Int32(5),at: 0x364);try actors[1].write(Int32(9),at: 0x364)
        if held { try actors[0].write(Int32(-1),at: 0x98);try actors[0].write(Int32(0),at: 0xa0) }
        let headers = [try header(attacker),try header(defender),try header(reflectorObject)],frame = try defined(0x178)
        var pass = OriginalHitPass(world: world,actors: actors,globals: try defined(0xb440),memory: OriginalContactFrameMemory([]),
            crt: OriginalCRTRandom(state: 1),objectCount: 3,header: { headers[$0] },frame: { _,_ in frame },rules: rules,sse2: false)
        pass.itrWords = [Int32](repeating: 0,count: 20)
        try pass.projectileHit(0,1)
        return pass.actors[1]
    }
    func testProjectileHitRebindsAReflectableDefenderTo209() throws {
        let reflected = try projectileHit(attacker: 209,defender: 200,rules: NTSDProfile.rules)
        XCTAssertEqual(try reflected.integer(at: 0x368,as: UInt32.self),0,"rebound to the reflector's Object")
        for o in [0x70,0x74,0x78] { XCTAssertEqual(try reflected.integer(at: o,as: Int32.self),40) }
        XCTAssertEqual(try reflected.integer(at: 0x364,as: Int32.self),5)
        let none = try projectileHit(attacker: 209,defender: 200,rules: Self.empty)
        XCTAssertEqual(try none.integer(at: 0x368,as: UInt32.self),1);XCTAssertEqual(try none.integer(at: 0x70,as: Int32.self),30)
        XCTAssertEqual(try projectileHit(attacker: 209,defender: 201,rules: NTSDProfile.rules),
                       try projectileHit(attacker: 209,defender: 201,rules: Self.empty),"a non-member defender is not rebound")
    }
    func testProjectileHitByAn8OrAHeld213RebindsAReflectableDefenderToThe209Object() throws {
        for (attacker,held) in [(Int32(8),false),(Int32(213),true)] {
            let reflected = try projectileHit(attacker: attacker,defender: 200,held: held,rules: NTSDProfile.rules)
            XCTAssertEqual(try reflected.integer(at: 0x368,as: UInt32.self),2,"\(attacker): rebound to the first 209 Object")
            XCTAssertEqual(try reflected.integer(at: 0x74,as: Int32.self),30);XCTAssertEqual(try reflected.integer(at: 0x78,as: Int32.self),30)
            let none = try projectileHit(attacker: attacker,defender: 200,held: held,rules: Self.empty)
            XCTAssertEqual(try none.integer(at: 0x368,as: UInt32.self),1,"\(attacker): not rebound without the rule")
            XCTAssertEqual(try projectileHit(attacker: attacker,defender: 201,held: held,rules: NTSDProfile.rules),
                           try projectileHit(attacker: attacker,defender: 201,held: held,rules: Self.empty))
        }
    }

    /// E5c-1a: the reflector, rebinder and held rebinder are the profile's (A13–A16, A20; A8 by mapping only).
    func testReflectorIDsComeFromTheProfile() throws {
        // A14: 210 takes over a reflectable defender under the moved profile; 209 no longer does.
        XCTAssertEqual(try projectileHit(attacker: 210,defender: 200,reflectorObject: 210,rules: Self.moved).integer(at: 0x368,as: UInt32.self),0)
        XCTAssertEqual(try projectileHit(attacker: 209,defender: 200,reflectorObject: 210,rules: Self.moved).integer(at: 0x70,as: Int32.self),30)
        // A15/A16 with A13: 9 and a held 214 rebind to the first 210 Object.
        for (attacker,held) in [(Int32(9),false),(Int32(214),true)] {
            XCTAssertEqual(try projectileHit(attacker: attacker,defender: 200,held: held,reflectorObject: 210,rules: Self.moved).integer(at: 0x368,as: UInt32.self),2)
            XCTAssertEqual(try projectileHit(attacker: attacker,defender: 200,held: held,reflectorObject: 210,rules: NTSDProfile.rules).integer(at: 0x368,as: UInt32.self),1)
        }
        // A20: a reflectable attacker skips its interaction on the profile's reflector only.
        let on210 = try contacts(attacker: 200,defender: 210,rules: Self.moved),plain = try contacts(attacker: 200,defender: 210,rules: NTSDProfile.rules)
        XCTAssertNotEqual(on210.events,plain.events)
        XCTAssertEqual(try contacts(attacker: 200,defender: 209,rules: Self.moved).events,try contacts(attacker: 2,defender: 2,rules: NTSDProfile.rules).events)
    }

    /// The rules travel from the game's identity into the loaded catalog.
    func testCatalogInputsCarryTheGameRules() throws {
        let inputs = try OriginalApplicationCatalogInputs.bundled()
        XCTAssertEqual(inputs.rules,NTSDProfile.rules)
        XCTAssertEqual(inputs.rules.profile,"NTSD 2.4 2.0a")
        let name = try XCTUnwrap(inputs.files.keys.sorted().first)
        XCTAssertEqual(try inputs.replacingFile(name,with: nil).rules,NTSDProfile.rules)
    }
}
