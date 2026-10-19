import Foundation
import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5c-2a: the hit pass's random item spawn (OriginalWorldHits,
/// 41eefb..) takes its item range (A39), scarce drops (A40) and full-HP item (A41)
/// from the profile. Synthetic records: no active Actor, an RNG table of ones whose
/// first draw (146, range 200) is 0 and whose second (147, range 2) is 1, one Actor
/// for the free slot 50.
final class NTSDProfileItemsTests: XCTestCase {
    func rules(range: OriginalIDRange? = nil,scarce: OriginalIDSet? = nil,hp200: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return OriginalGameRules(profile: "moved",reflection: n.reflection,armour: n.armour,interaction: n.interaction,impact: n.impact,
            items: .init(itemRange: range ?? n.itemRange,scarceDropItems: scarce ?? n.scarceDropItems,spawnHP200: hp200 ?? n.spawnHP200))
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
        // is left and the stream-154 draw over none fails; nothing spawns.
        let mode1 = try spawn([122],mode: 1,rules: NTSDProfile.rules)
        XCTAssertEqual(mode1.error,"\(OriginalStateError.invalidStorage("Original hit RNG division by zero"))")
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
