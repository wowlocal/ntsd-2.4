import XCTest
@testable import RandoriCore
import NTSDProfile

/// ENGINE_SPLIT E5c-1g/1i: the post-draw opoint's children (A55–A57), the
/// lifecycle's spawned Objects (N2–N4) and the object input's spawns (A58, A59)
/// follow the profile. Synthetic records
/// after OriginalPostDrawOpointTests' and OriginalPostDrawLifecycleTests' own.
final class NTSDProfileEffectsTests: XCTestCase {
    func zero(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: size), defined: [Bool](repeating: true, count: size))
    }
    func effects(fixed: OriginalIDSet? = nil, quarter: Int32? = nil, weak: OriginalIDSet? = nil, command: Int32? = nil,
                 death: Int32? = nil, fire: Int32? = nil, burst: Int32? = nil, escort: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(effects: .init(fixedDepthChildren: fixed ?? n.fixedDepthChildren, quarterDepthChild: quarter ?? n.quarterDepthChild,
            weakChildren: weak ?? n.weakChildren, commandEffect: command ?? n.commandEffect, deathParticles: death ?? n.deathParticles,
            fireParticles: fire ?? n.fireParticles, burstChild: burst ?? n.burstChild, escortChild: escort ?? n.escortChild))
    }
    func bootstrap() throws -> OriginalWorldBootstrap {
        try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5, count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5, count: 0x420), count: 400), selector: 2)
    }
    /// One opoint child (state 3000) of an Object with this ID, the parent holding Up:
    /// the child's z speed (+0x50) and HP (+0x2fc).
    func child(_ id: Int32, rules: OriginalGameRules) throws -> (vz: Double, hp: Int32) {
        let b = try bootstrap()
        var world = b.world, actors = b.actors, header = try zero(0x7a4), frame = try zero(0x178)
        for slot in 0..<400 { try world.write(UInt8(slot == 0 ? 1 : 0), at: 4+slot) }
        try actors[0].write(Int32(300), at: 0x10); try actors[0].writeBinary64(479.75, at: 0x68); try actors[0].write(UInt8(1), at: 0xcd)
        try header.write(id, at: 0x6f4)
        for (offset, value): (Int, Int32) in [(8, 3000), (0x58, 2), (0x64, 0), (0x68, 8), (0x70, id), (0x74, 0)] { try frame.write(value, at: offset) }
        let h = header, f = frame
        _ = try OriginalPostDrawOpoint.apply(world: &world, actors: &actors, slot: 0, precision: .bits53, sse2: false, objectCount: 1,
            header: { _ in h }, frame: { _, _ in f }, rules: rules)
        let c = Int(try world.integer(at: 0x194+50*4, as: UInt32.self))
        return (try actors[c].binary64(at: 0x50), try actors[c].integer(at: 0x2fc, as: Int32.self))
    }
    func testOpointChildrenA55A56A57() throws {
        let n = NTSDProfile.rules
        XCTAssertEqual(try child(5, rules: n).vz, -2.5); XCTAssertEqual(try child(223, rules: n).vz, 0); XCTAssertEqual(try child(224, rules: n).vz, 0)
        XCTAssertEqual(try child(211, rules: n).vz, -0.625, "a quarter")
        XCTAssertEqual(try child(5, rules: effects(fixed: OriginalIDSet([5]))).vz, 0)
        XCTAssertEqual(try child(223, rules: effects(fixed: OriginalIDSet([5]))).vz, -2.5)
        XCTAssertEqual(try child(211, rules: effects(quarter: 5)).vz, -2.5); XCTAssertEqual(try child(5, rules: effects(quarter: 5)).vz, -0.625)
        XCTAssertEqual(try child(5, rules: n).hp, 10); XCTAssertEqual(try child(52, rules: n).hp, 10); XCTAssertEqual(try child(6, rules: n).hp, 500)
        XCTAssertEqual(try child(5, rules: effects(weak: OriginalIDSet([6]))).hp, 500); XCTAssertEqual(try child(6, rules: effects(weak: OriginalIDSet([6]))).hp, 10)
    }
    /// The lifecycle for one slot: a character (header ID `id`, type 0) whose
    /// previous frame (+0x78) is frame 1 in state `previous` and current frame 0 in
    /// state 3; the reconstructions and the scratch's request slot afterwards.
    func lifecycle(id: Int32, previous: Int32, command: Bool = false, rules: OriginalGameRules) throws
        -> (created: Int, slot: OriginalRequestSlotWord?, error: String?) {
        let b = try bootstrap()
        var world = b.world, actors = b.actors, globals = try zero(0xb440), header = try zero(0x7a4), first = try zero(0x178), second = try zero(0x178)
        for slot in 0..<400 { try world.write(UInt8(slot == 0 ? 1 : 0), at: 4+slot) }
        try header.write(id, at: 0x6f4); try header.write(Int32(20), at: 0x90)
        try first.write(Int32(3), at: 8); try first.write(Int32(-1), at: 0x174)
        try second.write(previous, at: 8); try second.write(Int32(-1), at: 0x174)
        for i in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+i) }
        for (o, v): (Int, Int32) in [(0x78, 1), (0x70, 0), (0x2fc, 100), (0x2f4, -1)] { try actors[0].write(v, at: o) }
        if command { for (k, v) in [Int32(9), 0, 9, 0].enumerated() { try actors[0].write(v, at: 0x40c+4*k) } }
        let h = header, frames = [first, second]
        var scratch = OriginalPostDrawScratch(), created = 0
        do {
            try OriginalPostDrawLifecycle.apply(world: &world, actors: &actors, globals: &globals, scratch: &scratch, wholeLoop: false, slot: 0,
                precision: .bits53, sse2: false, objectCount: 1, header: { _ in h }, frame: { _, number in frames[Int(number)] }, rules: rules,
                observe: { if case .reconstruct = $0 { created += 1 } })
        } catch { return (created, scratch.requestSlot, "\(error)") }
        return (created, scratch.requestSlot, nil)
    }
    func testCommandEffectN2() throws {
        var r = try lifecycle(id: 998, previous: 3, command: true, rules: NTSDProfile.rules)
        XCTAssertNil(r.error); XCTAssertEqual(r.created, 1, "998 found: the effect spawned")
        r = try lifecycle(id: 998, previous: 3, command: true, rules: effects(command: 997))
        XCTAssertNil(r.error); XCTAssertEqual(r.created, 0)
        XCTAssertEqual(r.slot, .catalogCursor(1), "not found: the cursor still runs to the count")
        XCTAssertEqual(try lifecycle(id: 997, previous: 3, command: true, rules: effects(command: 997)).created, 1)
        XCTAssertEqual(try lifecycle(id: 998, previous: 3, command: false, rules: NTSDProfile.rules).created, 0, "no command")
    }
    func testDeathAndFireParticlesN3N4() throws {
        XCTAssertGreaterThan(try lifecycle(id: 999, previous: 13, rules: NTSDProfile.rules).created, 0)
        XCTAssertEqual(try lifecycle(id: 999, previous: 13, rules: effects(death: 998)).created, 0)
        XCTAssertGreaterThan(try lifecycle(id: 998, previous: 13, rules: effects(death: 998)).created, 0)
        var r = try lifecycle(id: 999, previous: 18, rules: NTSDProfile.rules)
        XCTAssertNil(r.error); XCTAssertGreaterThan(r.created, 0)
        r = try lifecycle(id: 999, previous: 18, rules: effects(fire: 998))
        XCTAssertEqual(r.error, "\(OriginalStateError.invalidStorage("Post-draw lifecycle: Fire Object index provenance"))", "no fire Object found")
        XCTAssertNil(try lifecycle(id: 998, previous: 18, rules: effects(fire: 998)).error)
    }
    /// The object input pass for slot 10 (an Object of type 1 whose frame has this
    /// hit_Fa) over these extra catalog Objects, an ally (a type-0 character of the
    /// same team) in slot 11: the reconstructions.
    func objectInput(hit: Int32, ids: [Int32], rules: OriginalGameRules) throws -> Int {
        var world = try zero(0x7d8), globals = try zero(0xb440)
        for (slot, actor): (Int, UInt32) in [(10, 0), (11, 1), (50, 2), (51, 3), (52, 4), (53, 5)] { try world.write(actor, at: 0x194+4*slot) }
        for slot in [10, 11] { try world.write(UInt8(1), at: 4+slot) }
        for n in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+n) }
        var actors = try (0..<6).map { _ in try zero(0x420) }
        try actors[0].write(UInt32(0), at: 0x368); try actors[1].write(UInt32(1), at: 0x368)
        for a in [0, 1] { try actors[a].write(Int32(1), at: 0x364); try actors[a].write(Int32(100), at: 0x2fc) }
        func object(_ id: Int32, type: Int32, hit: Int32 = 0) throws -> OriginalLoadedObject {
            var header = try zero(0x7a4); try header.write(id, at: 0x6f4); try header.write(type, at: 0x6f8)
            var frame = try zero(0x178); try frame.write(hit, at: 0x30)
            return OriginalLoadedObject(header: header, nameTail: try zero(0x3c), frames: [], frameStorage: [frame], weaponSoundPaths: [:])
        }
        let objects = try [object(5, type: 1, hit: hit), object(2, type: 0)] + ids.map { try object($0, type: 1) }
        var pass = OriginalObjectInputPass(world: world, actors: actors, globals: globals, objects: objects, objectCount: Int32(objects.count),
                                           precision: .bits64)
        var created = 0
        try pass.run(10, rules: rules, observe: { if case .reconstruct = $0 { created += 1 } })
        XCTAssertEqual(try pass.world.integer(at: 4+10, as: UInt8.self), 0, "the slot deactivated")
        if created > 0 { XCTAssertEqual(try pass.actors[2].integer(at: 0x368, as: UInt32.self), 2, "the child is the role's Object") }
        return created
    }
    func testObjectInputSpawnsA58A59() throws {
        let n = NTSDProfile.rules
        XCTAssertEqual(try objectInput(hit: 8, ids: [225], rules: n), 3, "three birds without enemies")
        XCTAssertEqual(try objectInput(hit: 8, ids: [225], rules: effects(burst: 77)), 0)
        XCTAssertEqual(try objectInput(hit: 8, ids: [77], rules: effects(burst: 77)), 3)
        XCTAssertEqual(try objectInput(hit: 5, ids: [219], rules: n), 1, "one for the living ally")
        XCTAssertEqual(try objectInput(hit: 5, ids: [219], rules: effects(escort: 77)), 0)
        XCTAssertEqual(try objectInput(hit: 5, ids: [77], rules: effects(escort: 77)), 1)
    }
}
