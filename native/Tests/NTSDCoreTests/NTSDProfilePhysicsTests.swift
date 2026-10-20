import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5c-1e: the actor physics' special Objects (A33–A36) and the
/// revival's (A37, A38) follow the profile. Synthetic records.
final class NTSDProfilePhysicsTests: XCTestCase {
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func physics(extra: Int32? = nil,reverse: Int32? = nil,low: Int32? = nil,mid: Int32? = nil,high: Int32? = nil,resting: Int32? = nil,
                 picture: OriginalIDRange? = nil,effect: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(physics: .init(extraDrift: extra ?? n.extraDrift,reverseDrift: reverse ?? n.reverseDrift,lowGravityThrow: low ?? n.lowGravityThrow,
            midGravityThrow: mid ?? n.midGravityThrow,highGravityThrow: high ?? n.highGravityThrow,restingPiece: resting ?? n.restingPiece,
            revivalPicture: picture ?? n.revivalPicture,revivalEffect: effect ?? n.revivalEffect))
    }
    /// One actor physics step for an Object with this ID and type in a frame of this
    /// state: x from 100 with vx 10 (+0x58), vy (+0x48) from y (+0x60), frame (+0x70).
    func step(id: Int32,type: Int32,state: Int32 = 0,y: Double = 0,rules: OriginalGameRules) throws -> (x: Double,vy: Double,frame: Int32) {
        var actor = try defined(0x420),globals = try defined(0xb440),header = try defined(0x7a4),frame = try defined(0x178)
        try actor.writeBinary64(100,at: 0x58);try actor.writeBinary64(10,at: 0x40);try actor.writeBinary64(y,at: 0x60)
        try header.write(id,at: 0x6f4);try header.write(type,at: 0x6f8);try frame.write(state,at: 8)
        let f = frame
        try OriginalActorPhysics.apply(actor: &actor,header: header,globals: &globals,rules: rules,frame: { _ in f })
        return (try actor.binary64(at: 0x58),try actor.binary64(at: 0x48),try actor.integer(at: 0x70,as: Int32.self))
    }
    func testDriftA33A34() throws {
        let base = try step(id: 5,type: 1,rules: NTSDProfile.rules).x
        XCTAssertEqual(try step(id: 120,type: 1,rules: NTSDProfile.rules).x - base,2,accuracy: 1e-9)
        XCTAssertEqual(try step(id: 101,type: 1,rules: NTSDProfile.rules).x - base,-2,accuracy: 1e-9)
        XCTAssertEqual(try step(id: 120,type: 1,rules: physics(extra: 77)).x,base,"not under a moved profile")
        XCTAssertEqual(try step(id: 77,type: 1,rules: physics(extra: 77)).x - base,2,accuracy: 1e-9)
        XCTAssertEqual(try step(id: 101,type: 1,rules: physics(reverse: 77)).x,base)
        XCTAssertEqual(try step(id: 77,type: 1,rules: physics(reverse: 77)).x - base,-2,accuracy: 1e-9)
        // Every type-4 Object drifts, whatever the role.
        let type4 = try step(id: 5,type: 4,rules: NTSDProfile.rules).x
        XCTAssertEqual(try step(id: 5,type: 4,rules: physics(extra: 77)).x,type4)
    }
    func testThrownGravityA35() throws {
        func vy(_ id: Int32,_ rules: OriginalGameRules) throws -> Double { try step(id: id,type: 1,state: 1002,y: -100,rules: rules).vy }
        XCTAssertEqual(try vy(124,NTSDProfile.rules),0.16999999999999998);XCTAssertEqual(try vy(120,NTSDProfile.rules),0.425)
        XCTAssertEqual(try vy(101,NTSDProfile.rules),1.1333333333333333);XCTAssertEqual(try vy(5,NTSDProfile.rules),0.5666666666666667)
        XCTAssertEqual(try vy(124,physics(low: 77)),0.5666666666666667,"not under a moved profile")
        XCTAssertEqual(try vy(77,physics(low: 77)),0.16999999999999998)
        XCTAssertEqual(try vy(120,physics(mid: 77)),0.5666666666666667);XCTAssertEqual(try vy(77,physics(mid: 77)),0.425)
        XCTAssertEqual(try vy(101,physics(high: 77)),0.5666666666666667);XCTAssertEqual(try vy(77,physics(high: 77)),1.1333333333333333)
        XCTAssertEqual(try vy(120,physics(low: 120)),0.16999999999999998,"the first match wins")
    }
    func testRestingPieceA36() throws {
        XCTAssertEqual(try step(id: 999,type: 3,rules: NTSDProfile.rules).frame,101)
        XCTAssertEqual(try step(id: 999,type: 3,rules: physics(resting: 998)).frame,0)
        XCTAssertEqual(try step(id: 998,type: 3,rules: physics(resting: 998)).frame,101)
        XCTAssertEqual(try step(id: 999,type: 1,rules: NTSDProfile.rules).frame,0,"a weapon does not stop so")
    }
    /// The world physics' revival (41e634): a dead character (ID `id`, frame state
    /// 14, revive HP 50 at +0x314) in slot 0; Object 1 has ID 998. +0x318 afterwards
    /// and whether the revival effect spawned.
    func revive(id: Int32,rules: OriginalGameRules) throws -> (picture: Int32,spawned: Bool) {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5,count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5,count: 0x420),count: 400),selector: 2)
        var world = bootstrap.world,actors = bootstrap.actors
        try world.write(UInt8(1),at: 4)
        for (offset,value): (Int,Int32) in [(0xb4,1),(0x70,300),(0x2fc,0),(0x2f4,0),(8,1),(0x314,50),(0x318,7)] { try actors[0].write(value,at: offset) }
        var globals = try defined(0xb440)
        var character = try defined(0x7a4),effect = try defined(0x7a4)
        try character.write(id,at: 0x6f4);try effect.write(Int32(998),at: 0x6f4)
        var frame = try defined(0x178);try frame.write(Int32(14),at: 8)
        let c = character,e = effect,f = frame
        var spawned = false
        try OriginalWorldPhysics.apply(world: &world,actors: &actors,globals: &globals,objectCount: 2,header: { $0 == 0 ? c : e },frame: { _,_ in f },
            rules: rules,observe: { if case .reconstruct = $0 { spawned = true } })
        return (try actors[0].integer(at: 0x318,as: Int32.self),spawned)
    }
    func testRevivalA37A38() throws {
        var r = try revive(id: 31,rules: NTSDProfile.rules);XCTAssertEqual(r.picture,140);XCTAssertTrue(r.spawned)
        r = try revive(id: 37,rules: NTSDProfile.rules);XCTAssertEqual(r.picture,7,"30…36 only");XCTAssertTrue(r.spawned)
        r = try revive(id: 31,rules: physics(picture: OriginalIDRange(40..<50)));XCTAssertEqual(r.picture,7)
        r = try revive(id: 31,rules: physics(effect: 997));XCTAssertEqual(r.picture,140);XCTAssertFalse(r.spawned,"no Object with the moved ID")
    }
}
