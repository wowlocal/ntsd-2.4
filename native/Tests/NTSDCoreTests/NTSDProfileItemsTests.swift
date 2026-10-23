import Foundation
import XCTest
@testable import RandoriCore
import NTSDProfile

/// ENGINE_SPLIT E5c-2a: the hit pass's random item spawn (OriginalWorldHits,
/// 41eefb..) takes its item range (A39), scarce drops (A40) and full-HP item (A41)
/// from the profile. Synthetic records: no active Actor, an RNG table of ones whose
/// first draw (146, range 200) is 0 and whose second (147, range 2) is 1, one Actor
/// for the free slot 50.
final class NTSDProfileItemsTests: XCTestCase {
    func rules(range: OriginalIDRange? = nil,scarce: OriginalIDSet? = nil,hp200: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(
            items: .init(itemRange: range ?? n.itemRange,scarceDropItems: scarce ?? n.scarceDropItems,scarceRequestedItem: n.scarceRequestedItem,
                         spawnHP200: hp200 ?? n.spawnHP200,
                         keptOnScreen: n.keptOnScreen,hpDrink: n.hpDrink,mpDrink: n.mpDrink))
    }
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    /// The spawn over these catalog IDs: the created Actor, the events and a thrown error (none for a spawn).
    func spawn(_ ids: [Int32],mode: Int32 = 0,rules: OriginalGameRules) throws -> (actor: OriginalStateRecord,events: [OriginalHitEvent],error: String?) {
        let world = try defined(0x7d8),actors = [try defined(0x420)]
        var globals = try defined(0xb440)
        // The table holds no zero byte (OriginalRandom.validate); ones, with 199 for the first draw.
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        try globals.write(UInt8(199),at: 0x44ff90-0x44d000+1)
        try globals.write(mode,at: 0x451160-0x44d000)
        let headers = try ids.map { id -> OriginalStateRecord in var h = try defined(0x7a4);try h.write(id,at: 0x6f4);return h }
        var background = try defined(16);try background.write(Int32(800),at: 0);try background.write(Int32(400),at: 8)
        let frameRecord = try defined(0x178),bg = background
        var pass = OriginalHitPass(world: world,actors: actors,globals: globals,memory: OriginalContactFrameMemory([]),
            crt: OriginalCRTRandom(state: 1),objectCount: Int32(ids.count),header: { headers[$0] },frame: { _,_ in frameRecord },rules: rules,sse2: false)
        var events: [OriginalHitEvent] = []
        do { try pass.advance(background: { _ in bg },observe: { events.append($0) }) } catch { return (pass.actors[0],events,"\(error)") }
        return (pass.actors[0],events,nil)
    }
    /// The spawned Object (+0x368), after checking that a spawn into slot 50 happened.
    func object(_ r: (actor: OriginalStateRecord,events: [OriginalHitEvent],error: String?),line: UInt = #line) throws -> UInt32 {
        XCTAssertNil(r.error,line: line);XCTAssertTrue(r.events.contains(.reconstruct(slot: 50)),"a spawn",line: line)
        return try r.actor.integer(at: 0x368,as: UInt32.self)
    }
    func testItemRangeA39() throws {
        let moved = rules(range: OriginalIDRange(300..<400))
        XCTAssertEqual(try object(spawn([150,350],rules: NTSDProfile.rules)),0,"150 is an item")
        XCTAssertEqual(try object(spawn([150,350],rules: moved)),1,"under the moved range 350 is")
        XCTAssertEqual(try object(spawn([99,200,150],rules: NTSDProfile.rules)),2,"99 and 200 are outside 100..<200")
        XCTAssertEqual(try object(spawn([99,100],rules: NTSDProfile.rules)),1,"100 is inside")
        XCTAssertEqual(try object(spawn([200,199],rules: NTSDProfile.rules)),1,"199 is inside")
    }
    func testScarceDropsA40() throws {
        let draw147 = { (e: OriginalHitEvent) -> Bool in if case .random(stream: 147,_,_) = e { return true };return false }
        let ntsd = try spawn([122],rules: NTSDProfile.rules),moved = try spawn([122],rules: rules(scarce: OriginalIDSet([123])))
        XCTAssertTrue(ntsd.events.contains(where: draw147));XCTAssertFalse(moved.events.contains(where: draw147))
        XCTAssertEqual(try object(ntsd),0);XCTAssertEqual(try object(moved),0)
        // In game mode 1 a scarce drop never stays, though its coin flip is drawn: no candidate
        // is left, the stream-154 draw over none answers 0 and candidate 0 is stack the call
        // has not written (41f128); the pass stops there and nothing spawns.
        let mode1 = try spawn([122],mode: 1,rules: NTSDProfile.rules)
        let unknown = OriginalStateError.invalidStorage("Source state unknown: no item candidate; the random item reads candidate 0 "
            + "from stack this call has not written (41f128)")
        XCTAssertEqual(mode1.error,"\(unknown)")
        XCTAssertEqual(mode1.events.last,.random(stream: 154,range: 0,result: 0))
        XCTAssertTrue(mode1.events.contains(where: draw147));XCTAssertFalse(mode1.events.contains(.reconstruct(slot: 50)))
        XCTAssertEqual(try object(spawn([122],mode: 1,rules: rules(scarce: OriginalIDSet([123])))),0)
    }
    func testFullHPSpawnA41() throws {
        XCTAssertEqual(try spawn([122],rules: NTSDProfile.rules).actor.integer(at: 0x2fc,as: Int32.self),200)
        let other = try spawn([122],rules: rules(hp200: 124))
        XCTAssertNil(other.error);XCTAssertEqual(try other.actor.integer(at: 0x2fc,as: Int32.self),500,"a new Actor's HP")
        XCTAssertEqual(try spawn([124],rules: rules(hp200: 124)).actor.integer(at: 0x2fc,as: Int32.self),200)
    }
}

/// ENGINE_SPLIT E5c-2b: the camera's clamp (OriginalWorldCamera.bounds, A42) and
/// the held drinks (OriginalWorldLinks.apply, A43/A44) take their IDs from the
/// profile. Synthetic records.
final class NTSDProfileItemsCameraLinksTests: XCTestCase {
    func rules(kept: OriginalIDSet? = nil,hp: Int32? = nil,mp: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(
            items: .init(itemRange: n.itemRange,scarceDropItems: n.scarceDropItems,scarceRequestedItem: n.scarceRequestedItem,spawnHP200: n.spawnHP200,
                         keptOnScreen: kept ?? n.keptOnScreen,hpDrink: hp ?? n.hpDrink,mpDrink: mp ?? n.mpDrink))
    }
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    /// A type-1 Object with this ID at x (5 by default) in an 800-wide arena, through
    /// the camera's bounds: its x afterwards.
    func cameraX(id: Int32,x: Double = 5,team: Int32 = 1,mode: Int32 = 0,stage: Int32 = 0,rules: OriginalGameRules) throws -> Double {
        try NTSDProfileCamera.run(id: id,x: x,team: team,mode: mode,stage: stage,rules: rules).x
    }
    /// The same, with whether its slot stays active.
    func camera(id: Int32,x: Double,team: Int32,mode: Int32,stage: Int32,rules: OriginalGameRules) throws -> (x: Double,active: Bool) {
        try NTSDProfileCamera.run(id: id,x: x,team: team,mode: mode,stage: stage,rules: rules)
    }
    func testKeptOnScreenA42() throws {
        XCTAssertEqual(try cameraX(id: 122,rules: NTSDProfile.rules),10,"122 with a team is held 10 inside")
        XCTAssertEqual(try cameraX(id: 123,rules: NTSDProfile.rules),10)
        XCTAssertEqual(try cameraX(id: 122,rules: rules(kept: OriginalIDSet([124]))),5,"not under a moved profile")
        XCTAssertEqual(try cameraX(id: 124,rules: rules(kept: OriginalIDSet([124]))),10)
        // The mode-1 stage 50–59 case is behind the same ID test.
        XCTAssertEqual(try cameraX(id: 123,team: 0,mode: 1,stage: 55,rules: NTSDProfile.rules),10)
        XCTAssertEqual(try cameraX(id: 123,team: 0,mode: 1,stage: 55,rules: rules(kept: OriginalIDSet([124]))),5)
        XCTAssertEqual(try cameraX(id: 123,team: 0,rules: NTSDProfile.rules),5,"no team, not mode 1: not held")
        // Past the left edge with y 0: held at 10 and kept, or deactivated where it is.
        var r = try camera(id: 122,x: -5,team: 1,mode: 0,stage: 0,rules: NTSDProfile.rules)
        XCTAssertEqual(r.x,10);XCTAssertTrue(r.active)
        r = try camera(id: 122,x: -5,team: 1,mode: 0,stage: 0,rules: rules(kept: OriginalIDSet([124])))
        XCTAssertEqual(r.x,-5);XCTAssertFalse(r.active)
    }
    /// A holder (slot 0, state 17) holding the item with this ID and HP (slot 1),
    /// through the links pass: the item's HP and the holder's MP afterwards, and the draws.
    func drink(id: Int32,hp: Int32,rules: OriginalGameRules) throws -> (itemHP: Int32,holderMP: Int32,events: [OriginalWorldLinksEvent]) {
        var world = try defined(0x7d8),actors = [try defined(0x420),try defined(0x420)],globals = try defined(0xb440)
        for slot in [0,1] { try world.write(UInt8(1),at: 4+slot) }
        try world.write(UInt32(1),at: 0x194+4)
        for (a,o,v): (Int,Int,Int32) in [(0,0x9c,1),(1,0x98,-1),(1,0xa0,0),(1,0x368,1),(1,0x2fc,hp)] { try actors[a].write(v,at: o) }
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        var character = try defined(0x7a4),item = try defined(0x7a4)
        try item.write(id,at: 0x6f4);try item.write(Int32(1),at: 0x6f8);try character.write(Int32(0),at: 0x6f8)
        var frame = try defined(0x178);try frame.write(Int32(17),at: 8)
        let bg = try defined(0x990),c = character,i = item,f = frame
        var events: [OriginalWorldLinksEvent] = []
        try OriginalWorldLinks.apply(world: world,actors: &actors,globals: &globals,header: { $0 == 0 ? c : i },frame: { _,_ in f },
                                     background: { _ in bg },rules: rules,observe: { events.append($0) })
        return (try actors[1].integer(at: 0x2fc,as: Int32.self),try actors[0].integer(at: 0x308,as: Int32.self),events)
    }
    func spent(_ events: [OriginalWorldLinksEvent],stream: Int32) -> Bool {
        events.contains { if case .random(slot: 1,stream: stream,range: 7,_) = $0 { return true };return false }
    }
    func testHPDrinkA43() throws {
        var r = try drink(id: 122,hp: 100,rules: NTSDProfile.rules)
        XCTAssertEqual(r.itemHP,99);XCTAssertEqual(r.holderMP,0)
        r = try drink(id: 122,hp: 100,rules: rules(hp: 124));XCTAssertEqual(r.itemHP,100,"not a drink under a moved profile")
        r = try drink(id: 124,hp: 100,rules: rules(hp: 124));XCTAssertEqual(r.itemHP,99)
        r = try drink(id: 122,hp: 1,rules: NTSDProfile.rules);XCTAssertEqual(r.itemHP,0);XCTAssertTrue(spent(r.events,stream: 136))
        r = try drink(id: 122,hp: 1,rules: rules(hp: 124));XCTAssertEqual(r.itemHP,1);XCTAssertFalse(spent(r.events,stream: 136))
    }
    func testMPDrinkA44() throws {
        var r = try drink(id: 123,hp: 100,rules: NTSDProfile.rules)
        XCTAssertEqual(r.itemHP,98);XCTAssertEqual(r.holderMP,3)
        r = try drink(id: 123,hp: 100,rules: rules(mp: 124));XCTAssertEqual(r.itemHP,100);XCTAssertEqual(r.holderMP,0)
        r = try drink(id: 124,hp: 100,rules: rules(mp: 124));XCTAssertEqual(r.itemHP,98);XCTAssertEqual(r.holderMP,3)
        r = try drink(id: 123,hp: 2,rules: NTSDProfile.rules);XCTAssertEqual(r.itemHP,0);XCTAssertTrue(spent(r.events,stream: 137))
        // Both roles on one ID: the HP drink's block runs first, then the MP drink's
        // reads the header again.
        r = try drink(id: 122,hp: 100,rules: rules(mp: 122));XCTAssertEqual(r.itemHP,97);XCTAssertEqual(r.holderMP,3)
        // Spent by the HP drink's block, it skips the MP drink's (no 137 draw, MP only
        // the HP drink's +5 at HP 0).
        r = try drink(id: 122,hp: 1,rules: rules(mp: 122));XCTAssertEqual(r.itemHP,0);XCTAssertEqual(r.holderMP,5)
        XCTAssertTrue(spent(r.events,stream: 136));XCTAssertFalse(spent(r.events,stream: 137))
    }
}

/// ENGINE_SPLIT E5c-2c: the requested item spawn (OriginalPostDrawCommands with
/// 0x450bb8 = 1: A48–A50) and the mission stage's spawn (A64) take their IDs from
/// the profile. Synthetic records: one Actor for the free slot (50, or seat 20).
final class NTSDProfileItemsRequestedMissionTests: XCTestCase {
    func rules(range: OriginalIDRange? = nil,scarce: Int32? = nil,hp200: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(
            items: .init(itemRange: range ?? n.itemRange,scarceDropItems: n.scarceDropItems,scarceRequestedItem: scarce ?? n.scarceRequestedItem,
                         spawnHP200: hp200 ?? n.spawnHP200,keptOnScreen: n.keptOnScreen,hpDrink: n.hpDrink,mpDrink: n.mpDrink))
    }
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    /// Globals with an RNG table of ones whose first draw over 2 is `firstOf2`.
    func globals(firstOf2: Int32) throws -> OriginalStateRecord {
        var globals = try defined(0xb440)
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        try globals.write(UInt8(firstOf2 == 0 ? 1 : 2),at: 0x44ff90-0x44d000+1)
        return globals
    }
    /// The requested item spawn over these catalog IDs: the Actor, the events.
    func requested(_ ids: [Int32],coin: Int32 = 1,rules: OriginalGameRules) throws -> (actor: OriginalStateRecord,events: [OriginalPostDrawCommandEvent]) {
        var world = try defined(0x7d8),actors = [try defined(0x420)],globals = try globals(firstOf2: coin)
        try globals.write(Int32(1),at: 0x450bb8-0x44d000)
        let headers = try ids.map { id -> OriginalStateRecord in var h = try defined(0x7a4);try h.write(id,at: 0x6f4);try h.write(Int32(1),at: 0x6f8);return h }
        var bg = try defined(16);try bg.write(Int32(800),at: 0);try bg.write(Int32(400),at: 8)
        let frame = try defined(0x178),b = bg
        var slot: OriginalRequestSlotWord? = nil,events: [OriginalPostDrawCommandEvent] = []
        try OriginalPostDrawCommands.apply(world: &world,actors: &actors,globals: &globals,requestSlot: &slot,sse2: false,objectCount: Int32(ids.count),
            header: { headers[$0] },frame: { _,_ in frame },background: { _ in b },rules: rules,observe: { events.append($0) })
        return (actors[0],events)
    }
    func spawned(_ r: (actor: OriginalStateRecord,events: [OriginalPostDrawCommandEvent])) throws -> UInt32? {
        r.events.contains(.reconstruct(slot: 50)) ? try r.actor.integer(at: 0x368,as: UInt32.self) : nil
    }
    let draw208 = { (e: OriginalPostDrawCommandEvent) -> Bool in if case .random(stream: 208,_,_) = e { return true };return false }
    func testRequestedItemRangeA48() throws {
        XCTAssertEqual(try spawned(requested([150,350],rules: NTSDProfile.rules)),0)
        XCTAssertEqual(try spawned(requested([150,350],rules: rules(range: OriginalIDRange(300..<400)))),1)
        XCTAssertNil(try spawned(requested([99,200],rules: NTSDProfile.rules)),"no item: no spawn")
        XCTAssertEqual(try spawned(requested([99,200],rules: rules(range: OriginalIDRange(0..<100)))),0)
    }
    func testScarceRequestedItemA49() throws {
        // The coin flip (stream 208) comes up 0: 122 is not kept under NTSD's profile.
        let ntsd = try requested([122],coin: 0,rules: NTSDProfile.rules)
        XCTAssertTrue(ntsd.events.contains(where: draw208));XCTAssertNil(try spawned(ntsd))
        XCTAssertEqual(try spawned(requested([122],coin: 1,rules: NTSDProfile.rules)),0)
        let moved = try requested([122],coin: 0,rules: rules(scarce: 124))
        XCTAssertFalse(moved.events.contains(where: draw208));XCTAssertEqual(try spawned(moved),0)
        XCTAssertNil(try spawned(requested([124],coin: 0,rules: rules(scarce: 124))))
    }
    func testRequestedSpawnHP200A50() throws {
        var r = try requested([122],rules: NTSDProfile.rules);XCTAssertEqual(try spawned(r),0)
        XCTAssertEqual(try r.actor.integer(at: 0x2fc,as: Int32.self),200)
        r = try requested([122],rules: rules(hp200: 124));XCTAssertEqual(try spawned(r),0)
        XCTAssertEqual(try r.actor.integer(at: 0x2fc,as: Int32.self),500,"a new Actor's HP")
        r = try requested([124],rules: rules(hp200: 124));XCTAssertEqual(try spawned(r),0)
        XCTAssertEqual(try r.actor.integer(at: 0x2fc,as: Int32.self),200)
    }
    /// The mission stage's spawn (437400) of this ID with HP 300 into seat 20: the Actor, the events.
    func mission(id: Int32,rules: OriginalGameRules) throws -> (actor: OriginalStateRecord,events: [OriginalMissionStageEvent]) {
        var stage = try defined(0x100)
        for (o,v): (Int,Int32) in [(0xac,id),(0xb0,100),(0xb4,300)] { try stage.write(v,at: o) }
        var header = try defined(0x7a4);try header.write(id,at: 0x6f4);try header.write(Int32(1),at: 0x6f8)
        var bg = try defined(16);try bg.write(Int32(400),at: 8)
        var pass = OriginalMissionStagePass(world: try defined(0x7d8),actors: [try defined(0x420)],globals: try globals(firstOf2: 1),stages: [stage],
            objects: [OriginalLoadedObject(header: header,nameTail: try defined(0x3c),frames: [],frameStorage: [],weaponSoundPaths: [:])],
            rules: rules,objectCount: 1,backgrounds: [bg],precision: .bits64,sse2: false,target: 0)
        try pass.spawn(0,0,0)
        return (pass.actors[0],pass.events)
    }
    func testMissionSpawnHP200A64() throws {
        var r = try mission(id: 122,rules: NTSDProfile.rules)
        XCTAssertTrue(r.events.contains(.constructor(seat: 20)));XCTAssertEqual(try r.actor.integer(at: 0x2fc,as: Int32.self),200)
        r = try mission(id: 122,rules: rules(hp200: 124))
        XCTAssertTrue(r.events.contains(.constructor(seat: 20)));XCTAssertEqual(try r.actor.integer(at: 0x2fc,as: Int32.self),300,"the stage's HP")
        r = try mission(id: 124,rules: rules(hp200: 124));XCTAssertEqual(try r.actor.integer(at: 0x2fc,as: Int32.self),200)
    }
}

/// The camera's bounds over one type-1 Object in an 800-wide arena (shared by the
/// items and modes tests; no suite instantiates another).
enum NTSDProfileCamera {
    static func record(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    static func run(id: Int32,x: Double,team: Int32,mode: Int32,stage: Int32,rules: OriginalGameRules) throws -> (x: Double,active: Bool) {
        var world = try record(0x7d8),actors = [try record(0x420)],globals = try record(0xb440)
        try world.write(UInt8(1),at: 4)
        try actors[0].writeBinary64(x,at: 0x58);try actors[0].writeBinary64(100,at: 0x68);try actors[0].write(team,at: 0x344)
        try globals.write(stage,at: 0x450b94-0x44d000)
        var header = try record(0x7a4);try header.write(id,at: 0x6f4);try header.write(Int32(1),at: 0x6f8)
        var bg = try record(0x990);try bg.write(Int32(800),at: 0);try bg.write(Int32(400),at: 8)
        let frame = try record(0x178),h = header,b = bg
        try OriginalWorldCamera.bounds(world: &world,actors: &actors,globals: &globals,mode: mode,header: { _ in h },frame: { _,_ in frame },
                                       background: { _ in b },rules: rules)
        return (try actors[0].binary64(at: 0x58),try world.integer(at: 4,as: UInt8.self) != 0)
    }
}
