import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5e-2: the mission stage's pseudo spawn words (A61–A63) follow
/// the profile. Synthetic records, the mission stage pass built directly.
final class NTSDProfileMissionSpawnTests: XCTestCase {
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func rules(hero: Int32? = nil,troop: Int32? = nil,troopOrBoss: Int32? = nil,troops: OriginalIDRange? = nil,boss: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(modes: .init(survivalStages: n.survivalStages,numberedStages: n.numberedStages,finalStageSet: n.finalStageSet,
            stageWeightPlus1: n.stageWeightPlus1,stageWeightPlus2: n.stageWeightPlus2,warTroops: n.warTroops,stageBackgrounds: n.stageBackgrounds,
            killRequestSpared: n.killRequestSpared,fixedDifficultyHP: n.fixedDifficultyHP,heroSpawnWord: hero ?? n.heroSpawnWord,
            troopSpawnWord: troop ?? n.troopSpawnWord,troopOrBossSpawnWord: troopOrBoss ?? n.troopOrBossSpawnWord,
            spawnTroops: troops ?? n.spawnTroops,bossTroop: boss ?? n.bossTroop))
    }
    static let catalog: [Int32] = [7, 30, 31, 32, 40, 41, 42, 77]
    /// The mission stage's spawn (437400) of this word with HP 300 (difficulty 0), the
    /// hero table's first entry 7 and its cursor at `cursor`, the random counter at
    /// `counter` (a table of ones): the spawned Object's ID (nil when the scan missed),
    /// its HP, the cursor afterwards and the random streams with their ranges.
    func spawn(_ word: Int32,rules: OriginalGameRules,cursor: Int32 = 0,counter: Int32 = 0) throws
        -> (id: Int32?,hp: Int32,cursor: Int32,draws: [(stream: Int32,range: Int32)]) {
        var stage = try defined(0x100)
        for (o,v): (Int,Int32) in [(0xac,word),(0xb0,100),(0xb4,300)] { try stage.write(v,at: o) }
        var globals = try defined(0xb440)
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        for k in 0..<10 { try globals.write(k == 0 ? Int32(7) : Int32(77),at: 0x44d324-0x44d000+4*k) }
        try globals.write(cursor,at: 0x44d34c-0x44d000);try globals.write(counter,at: 0x450c34-0x44d000)
        let objects = try Self.catalog.map { id -> OriginalLoadedObject in
            var header = try defined(0x7a4);try header.write(id,at: 0x6f4);try header.write(Int32(1),at: 0x6f8)
            return OriginalLoadedObject(header: header,nameTail: try defined(0x3c),frames: [],frameStorage: [],weaponSoundPaths: [:])
        }
        var bg = try defined(16);try bg.write(Int32(400),at: 8)
        var pass = OriginalMissionStagePass(world: try defined(0x7d8),actors: [try defined(0x420)],globals: globals,stages: [stage],
            objects: objects,rules: rules,objectCount: Int32(objects.count),backgrounds: [bg],precision: .bits64,sse2: false,target: 0)
        try pass.spawn(0,0,0)
        let spawned = pass.events.contains(.constructor(seat: 20))
        let id = spawned ? Self.catalog[Int(try pass.actors[0].integer(at: 0x368,as: UInt32.self))] : nil
        let draws = pass.events.compactMap { e -> (stream: Int32,range: Int32)? in
            if case let .random(stream,range,_) = e { return (stream,range) };return nil
        }
        return (id,try pass.actors[0].integer(at: 0x2fc,as: Int32.self),try pass.globals.integer(at: 0x44d34c-0x44d000,as: Int32.self),draws)
    }
    func testHeroSpawnWordA61() throws {
        var r = try spawn(1000,rules: NTSDProfile.rules)
        XCTAssertEqual(r.id,7);XCTAssertEqual(r.cursor,1);XCTAssertFalse(r.draws.contains { $0.stream == 0x10f || $0.stream == 0x110 },"no shuffle mid-table")
        r = try spawn(1000,rules: NTSDProfile.rules,cursor: -1)
        XCTAssertEqual(r.cursor,1);XCTAssertEqual(r.draws.filter { $0.stream == 0x10f && $0.range == 10 }.count,50)
        XCTAssertEqual(r.draws.filter { $0.stream == 0x110 && $0.range == 10 }.count,50)
        XCTAssertNil(try spawn(1000,rules: rules(hero: 999)).id,"1000 is then an ordinary word the catalog lacks")
        r = try spawn(999,rules: rules(hero: 999));XCTAssertEqual(r.id,7);XCTAssertEqual(r.cursor,1)
    }
    func testTroopSpawnWordsA62A63() throws {
        let n = NTSDProfile.rules
        // From counter 0 a range of 2 draws 0 first, then 1; a range of 3 draws 2, then 0.
        var r = try spawn(3000,rules: n)
        XCTAssertEqual(r.id,30);XCTAssertEqual(r.draws.first.map { [$0.stream,$0.range] },[0x111,2]);XCTAssertEqual(r.hp,300)
        XCTAssertNil(try spawn(3000,rules: rules(troop: 2999)).id)
        XCTAssertEqual(try spawn(2999,rules: rules(troop: 2999)).id,30)
        r = try spawn(3000,rules: rules(troops: OriginalIDRange(40..<43)))
        XCTAssertEqual(r.id,42);XCTAssertEqual(r.draws.first.map { [$0.stream,$0.range] },[0x111,3])
        // 3001: from counter 5 the 1-in-7 roll (stream 0x112) comes out 0: the boss with four times the HP.
        r = try spawn(3001,rules: n,counter: 5)
        XCTAssertEqual(r.id,32);XCTAssertEqual(r.hp,1200)
        XCTAssertEqual(r.draws.prefix(2).map { [$0.stream,$0.range] },[[0x112,7],[0x114,400]],"no troop draw after the boss")
        r = try spawn(3001,rules: rules(boss: 77),counter: 5);XCTAssertEqual(r.id,77);XCTAssertEqual(r.hp,1200)
        r = try spawn(3001,rules: n,counter: 0)
        XCTAssertEqual(r.id,31);XCTAssertEqual(r.hp,300)
        XCTAssertEqual(r.draws.prefix(2).map { [$0.stream,$0.range] },[[0x112,7],[0x113,2]])
        r = try spawn(3001,rules: rules(troops: OriginalIDRange(40..<43)),counter: 0)
        XCTAssertEqual(r.id,40);XCTAssertEqual(r.draws.prefix(2).map { [$0.stream,$0.range] },[[0x112,7],[0x113,3]])
        XCTAssertNil(try spawn(3001,rules: rules(troopOrBoss: 2999),counter: 5).id)
        XCTAssertEqual(try spawn(2999,rules: rules(troopOrBoss: 2999),counter: 5).id,32)
    }
}
