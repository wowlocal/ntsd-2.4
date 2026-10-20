import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5e-4: fusion's Objects (A24–A26) follow the profile. Synthetic
/// records; the contact pass's `fusion` runs directly over 20 slots, each with its
/// own Actor.
final class NTSDProfileFusionTests: XCTestCase {
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func rules(fusers: OriginalIDSet? = nil,sum: Int32? = nil,form: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(fusion: .init(fusers: fusers ?? n.fusers,fusionPartnerSum: sum ?? n.fusionPartnerSum,fusedForm: form ?? n.fusedForm))
    }
    /// 51 twice: the fuse takes the first (A25's scan stops at its first match).
    static let catalog: [Int32] = [7, 8, 51, 5, 10, 52, 51]
    func ordinal(_ id: Int32) -> UInt32 { UInt32(Self.catalog.firstIndex(of: id)!) }
    /// A contact pass over slots 0..<20 (slot k is Actor k); `set` prepares the Actors.
    func pass(rules: OriginalGameRules,flag458428: Int32 = 0,_ set: (inout [OriginalStateRecord]) throws -> Void) throws -> OriginalContactPass {
        var world = try defined(0x7d8),globals = try defined(0xb440)
        for k in 0..<20 { try world.write(UInt32(k),at: 0x194+4*k) }
        try globals.write(flag458428,at: 0x458428-0x44d000)
        var actors = try (0..<20).map { _ in try defined(0x420) }
        try set(&actors)
        for k in 0..<20 where try actors[k].integer(at: 0x2fc,as: Int32.self) != 0 { try world.write(UInt8(1),at: 4+k) }
        let headers = try Self.catalog.map { id -> OriginalStateRecord in var h = try defined(0x7a4);try h.write(id,at: 0x6f4);return h }
        var standing = try defined(0x178);try standing.write(Int32(2),at: 8)
        let frame = standing
        return OriginalContactPass(world: world,actors: actors,globals: globals,objectCount: Int32(Self.catalog.count),
            header: { headers[$0] },frame: { _,_ in frame },heapWord: { _ in 0 },rules: rules)
    }
    /// Characters with these IDs in slots 0 (x 10) and 1 (x 0), both team 0, HP `hp`, in
    /// state 2: after `fusion`, slot 0's Object ID, whether slot 1 is still active, and
    /// slot 0's saved IDs (+0x330, +0x334).
    func fuse(_ first: Int32,_ second: Int32,hp: Int32 = 100,flag458428: Int32 = 0,rules: OriginalGameRules) throws
        -> (id: Int32,ordinal: UInt32,partnerActive: Bool,saved: [Int32]) {
        var p = try pass(rules: rules,flag458428: flag458428) { actors in
            for (k,id,x): (Int,Int32,Int32) in [(0,first,10),(1,second,0)] {
                try actors[k].write(ordinal(id),at: 0x368);try actors[k].write(hp,at: 0x2fc);try actors[k].write(x,at: 0x10)
            }
        }
        try p.fusion()
        let n = try p.actors[0].integer(at: 0x368,as: UInt32.self)
        return (Self.catalog[Int(n)],n,try p.active(1) == 1,
                [try p.i(0,0x330),try p.i(0,0x334)])
    }
    func testFuseA24A25() throws {
        let n = NTSDProfile.rules
        var r = try fuse(7,8,rules: n)
        XCTAssertEqual(r.id,51);XCTAssertEqual(r.ordinal,2,"the first 51");XCTAssertFalse(r.partnerActive);XCTAssertEqual(r.saved,[7,8])
        r = try fuse(8,7,rules: n);XCTAssertEqual(r.id,51);XCTAssertEqual(r.saved,[8,7])
        // The HP-177 gate, and 0x458428 = 1 lifting it.
        XCTAssertEqual(try fuse(7,8,hp: 200,rules: n).id,7);XCTAssertEqual(try fuse(7,8,hp: 200,flag458428: 1,rules: n).id,51)
        // Moved roles: other fusers, another partner sum, another form.
        XCTAssertEqual(try fuse(7,8,rules: rules(fusers: OriginalIDSet([5,10]))).id,7)
        r = try fuse(5,10,rules: rules(fusers: OriginalIDSet([5,10])));XCTAssertEqual(r.id,51);XCTAssertEqual(r.saved,[5,10])
        XCTAssertEqual(try fuse(5,10,rules: n).id,5)
        XCTAssertEqual(try fuse(7,8,rules: rules(sum: 16)).id,7)
        XCTAssertEqual(try fuse(8,8,rules: rules(sum: 16)).id,51)
        XCTAssertEqual(try fuse(7,8,rules: rules(form: 52)).id,52)
        // The family takes part in the rules' equality.
        XCTAssertNotEqual(n,n.with(profile: n.profile,fusion: .init(fusers: n.fusers,fusionPartnerSum: 16,fusedForm: n.fusedForm)))
        XCTAssertEqual(n,n.with(profile: n.profile,fusion: n.fusion))
    }
    /// A fused slot 0 (this Object, +0x328 1, frame 300, timer 0, HP 200 of 300) that saved
    /// 7 and 8 from slot 1: after `fusion`, slot 0's ID, slot 1's ID and activity, the events.
    func defuse(form: Int32,rules: OriginalGameRules) throws -> (id: Int32,partner: Int32,partnerActive: Bool,events: [OriginalWorldContactsEvent]) {
        var p = try pass(rules: rules) { actors in
            try actors[0].write(ordinal(form),at: 0x368);try actors[0].write(Int32(200),at: 0x2fc);try actors[0].write(Int32(300),at: 0x300)
            for (o,v): (Int,Int32) in [(0x328,1),(0x70,300),(0x32c,1),(0x330,7),(0x334,8)] { try actors[0].write(v,at: o) }
        }
        var events: [OriginalWorldContactsEvent] = []
        try p.fusion(observe: { events.append($0) })
        return (Self.catalog[Int(try p.actors[0].integer(at: 0x368,as: UInt32.self))],Self.catalog[Int(try p.actors[1].integer(at: 0x368,as: UInt32.self))],
                try p.active(1) == 1,events)
    }
    func testDefuseA26() throws {
        var r = try defuse(form: 51,rules: NTSDProfile.rules)
        XCTAssertEqual(r.id,7);XCTAssertEqual(r.partner,8);XCTAssertTrue(r.partnerActive)
        XCTAssertEqual(r.events,[.reconstruct(slot: 0,created: 1)])
        r = try defuse(form: 51,rules: rules(form: 52))
        XCTAssertEqual(r.id,51);XCTAssertFalse(r.partnerActive);XCTAssertEqual(r.events,[])
        r = try defuse(form: 52,rules: rules(form: 52))
        XCTAssertEqual(r.id,7);XCTAssertEqual(r.partner,8);XCTAssertEqual(r.events,[.reconstruct(slot: 0,created: 1)])
    }
}
