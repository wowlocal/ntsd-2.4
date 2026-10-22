import Foundation
import XCTest
@testable import RandoriCore
import NTSDProfile

/// ENGINE_SPLIT E5c-1c: the special interactions (A17–A19, A21) take their Objects
/// from the profile: each case holds under NTSD's profile and changes under a
/// profile moving only that row's IDs. Synthetic records. A22 (the held-owner
/// team filter) and A23 (contact mode 1) are covered by the mapping only.
final class NTSDProfileInteractionTests: XCTestCase {
    func profile(light: OriginalIDSet? = nil,pull: OriginalIDSet? = nil,bypass: Int32? = nil,character: OriginalIDSet? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules.interaction
        return NTSDProfile.rules.with(
            interaction: .init(holdKind101: light ?? n.holdKind101,pullImmune: pull ?? n.pullImmune,teamBypass: bypass ?? n.teamBypass,
                               countsAsCharacter: character ?? n.countsAsCharacter))
    }
    let ntsd = NTSDProfile.rules
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    /// Attacker actor 0 (an ID-1 character), defender actor 1 with the given ID and type; interaction kind as given.
    func pass(defender: Int32,type: Int32,kind: Int32,rules: OriginalGameRules) throws -> OriginalHitPass {
        var world = try defined(0x7d8),actors = [try defined(0x420),try defined(0x420)]
        for slot in 0..<2 { try world.write(UInt32(slot),at: 0x194+slot*4);try actors[slot].write(UInt32(slot),at: 0x368) }
        try actors[1].write(Int32(50),at: 0x70)
        var headers = [try defined(0x7a4),try defined(0x7a4)]
        try headers[0].write(Int32(1),at: 0x6f4);try headers[1].write(defender,at: 0x6f4);try headers[1].write(type,at: 0x6f8)
        let frameRecord = try defined(0x178),fixed = headers
        var pass = OriginalHitPass(world: world,actors: actors,globals: try defined(0xb440),memory: OriginalContactFrameMemory([]),
            crt: OriginalCRTRandom(state: 1),objectCount: 2,header: { fixed[$0] },frame: { _,_ in frameRecord },rules: rules,sse2: false)
        pass.itrWords = [Int32](repeating: 0,count: 20);pass.itrWords[0] = kind
        return pass
    }
    /// The holder's hold kind after a special hit of this kind on this defender.
    func holdKind(defender: Int32,type: Int32,kind: Int32,rules: OriginalGameRules) throws -> Int32 {
        var p = try pass(defender: defender,type: type,kind: kind,rules: rules)
        try p.specialHit(0,1,observe: { _ in })
        return try p.actors[0].integer(at: 0x98,as: Int32.self)
    }
    func testLightWeaponCatchA17() throws {
        let moved = profile(light: OriginalIDSet([121]))
        XCTAssertEqual(try holdKind(defender: 120,type: 0,kind: 7,rules: ntsd),101);XCTAssertEqual(try holdKind(defender: 120,type: 0,kind: 7,rules: moved),1)
        XCTAssertEqual(try holdKind(defender: 121,type: 0,kind: 7,rules: moved),101)
    }
    func testLightWeaponPickUpA18() throws {
        let moved = profile(light: OriginalIDSet([121]))
        XCTAssertEqual(try holdKind(defender: 124,type: 1,kind: 2,rules: ntsd),101);XCTAssertEqual(try holdKind(defender: 124,type: 1,kind: 2,rules: moved),1)
        XCTAssertEqual(try holdKind(defender: 121,type: 1,kind: 2,rules: moved),101)
    }
    func testPullImmuneA19() throws {
        func frameAfterPull(_ defender: Int32,_ rules: OriginalGameRules) throws -> Int32 {
            var p = try pass(defender: defender,type: 1,kind: 15,rules: rules)
            try p.pullingHit(0,1,damped: false)
            return try p.actors[1].integer(at: 0x70,as: Int32.self)
        }
        let moved = profile(pull: OriginalIDSet([203]))
        XCTAssertEqual(try frameAfterPull(201,ntsd),50,"left as it is");XCTAssertEqual(try frameAfterPull(201,moved),0)
        XCTAssertEqual(try frameAfterPull(203,moved),50)
    }
    /// OriginalWorldContacts' same-team filter (A21): a 212 defender on the attacker's team still takes the contact.
    func contacts(defender: Int32,attacker: Int32 = 2,defenderFrame: Int32 = 0,attackerFrame: Int32 = 0,rules: OriginalGameRules) throws -> [OriginalWorldContactsEvent] {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5,count: 0x7d8),actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5,count: 0x420),count: 400),selector: 2)
        var world = bootstrap.world,actors = bootstrap.actors
        var globals = try defined(0xb440),frame = try defined(0x178),boxes = try defined(120)
        var headers = [try defined(0x7a4),try defined(0x7a4)]
        try headers[0].write(attacker,at: 0x6f4);try headers[1].write(defender,at: 0x6f4)
        let fixed = headers
        for slot in 0..<400 { try actors[slot].write(UInt32(slot < 2 ? slot : 0),at: 0x368);try world.write(UInt8(slot < 2 ? 1 : 0),at: 4+slot) }
        for slot in 0..<2 {
            try actors[slot].write(Int32(0),at: 8);try actors[slot].write(Int32(123),at: 0x7c)
            try actors[slot].write(Int32(0),at: 0x2e8);try actors[slot].write(Int32(1),at: 0x364)
        }
        try actors[0].write(attackerFrame,at: 0x70);try actors[1].write(defenderFrame,at: 0x70)
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        try frame.write(Int32(1),at: 0x128);try frame.write(Int32(1),at: 0x12c)
        try frame.write(UInt32(0x51000000),at: 0x130);try frame.write(UInt32(0x51000050),at: 0x134)
        for base in [0x138,0x148] { for (n,v): (Int,Int32) in [-20,-20,40,40].enumerated() { try frame.write(v,at: base+n*4) } }
        for base in [0,80] { for (n,v): (Int,Int32) in [-20,-20,40,40].enumerated() { try boxes.write(v,at: base+4+n*4) } }
        let memory = OriginalContactFrameMemory([.init(address: 0x51000000,kind: .interactions,storage: boxes)])
        var events: [OriginalWorldContactsEvent] = []
        do {
            try OriginalWorldContacts.apply(world: &world,actors: &actors,globals: &globals,objectCount: 2,header: { fixed[$0] },
                frame: { _,_ in frame },heapWord: { try memory.word($0) },rules: rules,observe: { events.append($0) })
        } catch {}
        return events
    }
    func testTeamBypassA21() throws {
        let moved = profile(bypass: 213)
        let hit = { (e: OriginalWorldContactsEvent) -> Bool in if case .random(attacker: 0,defender: 1,_,_,_) = e { return true };return false }
        XCTAssertTrue(try contacts(defender: 212,rules: ntsd).contains(where: hit),"212 takes a teammate's contact")
        XCTAssertFalse(try contacts(defender: 212,rules: moved).contains(where: hit))
        XCTAssertTrue(try contacts(defender: 213,rules: moved).contains(where: hit))
        XCTAssertFalse(try contacts(defender: 2,rules: ntsd).contains(where: hit),"an ordinary teammate is filtered")
        // Against its own ID only in frames %10 5 (defender) and 0 (attacker).
        XCTAssertFalse(try contacts(defender: 212,attacker: 212,rules: ntsd).contains(where: hit))
        XCTAssertTrue(try contacts(defender: 212,attacker: 212,defenderFrame: 5,attackerFrame: 10,rules: ntsd).contains(where: hit))
        XCTAssertFalse(try contacts(defender: 212,attacker: 212,defenderFrame: 5,attackerFrame: 10,rules: moved).contains(where: hit))
        XCTAssertTrue(try contacts(defender: 213,attacker: 213,defenderFrame: 5,attackerFrame: 10,rules: moved).contains(where: hit))
    }
}
