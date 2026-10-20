import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5e-1: the ID-300 exemption's three roles (A7 in the hits, A51
/// in the post-draw commands' recovery, A60 on the mission spawn word) follow
/// the profile. Synthetic records, the passes built directly.
final class NTSDProfileExemptionTests: XCTestCase {
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func rules(converted: Int32? = nil,spared: Int32? = nil,fixed: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(impact: .init(vanishingAttacker: n.vanishingAttacker,spentAttacker: n.spentAttacker,heavyHeldWeapon: n.heavyHeldWeapon,
                                    hitConverted: converted ?? n.hitConverted),
                      modes: .init(survivalStages: n.survivalStages,numberedStages: n.numberedStages,finalStageSet: n.finalStageSet,
                                   stageWeightPlus1: n.stageWeightPlus1,stageWeightPlus2: n.stageWeightPlus2,warTroops: n.warTroops,
                                   stageBackgrounds: n.stageBackgrounds,killRequestSpared: spared ?? n.killRequestSpared,
                                   fixedDifficultyHP: fixed ?? n.fixedDifficultyHP,heroSpawnWord: n.heroSpawnWord,
                                   troopSpawnWord: n.troopSpawnWord,troopOrBossSpawnWord: n.troopOrBossSpawnWord,
                                   spawnTroops: n.spawnTroops,bossTroop: n.bossTroop))
    }

    /// A7: damageHit by attacker actor 0 (ID 7) with injury 20 (+0x44) on a type-0 defender
    /// actor 1 with this ID and HP 100, whose frame has a body (+0x12c 1) at 0x1000 whose
    /// first word is 1005.
    func hit(defender: Int32,rules: OriginalGameRules) throws -> (whole: Bool,pass: OriginalHitPass) {
        var world = try defined(0x7d8),actors = [try defined(0x420),try defined(0x420)]
        for slot in 0..<2 { try world.write(UInt32(slot),at: 0x194+slot*4);try world.write(UInt8(1),at: 4+slot);try actors[slot].write(UInt32(slot),at: 0x368) }
        for a in 0..<2 { try actors[a].write(Int32(100),at: 0x2fc) }
        var headers = [try defined(0x7a4),try defined(0x7a4)]
        try headers[0].write(Int32(7),at: 0x6f4);try headers[1].write(defender,at: 0x6f4)
        var body = try defined(0x178);try body.write(Int32(1),at: 0x12c);try body.write(Int32(0x1000),at: 0x134)
        var words = try defined(0x40);try words.write(Int32(1005),at: 0)
        let plain = try defined(0x178),fixed = headers,bodyFrame = body
        var pass = OriginalHitPass(world: world,actors: actors,globals: try defined(0xb440),
            memory: OriginalContactFrameMemory([OriginalFrameAllocation(address: 0x1000,kind: .bodies,storage: words)]),
            crt: OriginalCRTRandom(state: 1),objectCount: 2,header: { fixed[$0] },frame: { n,_ in n == 1 ? bodyFrame : plain },rules: rules,sse2: false)
        pass.itrWords = [Int32](repeating: 0,count: 20);pass.itrWords[0x44/4] = 20
        var spark: Int32 = 0
        let whole = try pass.damageHit(0,1,try defined(0x40),spark: &spark,observe: { _ in })
        return (whole,pass)
    }
    func testHitConvertedA7() throws {
        let ntsd = try hit(defender: 300,rules: NTSDProfile.rules)
        XCTAssertTrue(ntsd.whole,"the whole-function return")
        XCTAssertEqual(try ntsd.pass.actors[1].integer(at: 0x364,as: Int32.self),1);XCTAssertEqual(try ntsd.pass.actors[1].integer(at: 0x70,as: Int32.self),5)
        XCTAssertEqual(try ntsd.pass.actors[0].integer(at: 0xb4,as: Int32.self),3);XCTAssertEqual(try ntsd.pass.actors[1].integer(at: 0xb4,as: Int32.self),-3)
        XCTAssertEqual(try ntsd.pass.actors[1].integer(at: 0x2fc,as: Int32.self),100,"no damage")
        let moved = try hit(defender: 300,rules: rules(converted: 301))
        XCTAssertFalse(moved.whole);XCTAssertEqual(try moved.pass.actors[1].integer(at: 0x364,as: Int32.self),0)
        XCTAssertLessThan(try moved.pass.actors[1].integer(at: 0x2fc,as: Int32.self),100,"the injury applies")
        let other = try hit(defender: 301,rules: rules(converted: 301))
        XCTAssertTrue(other.whole);XCTAssertEqual(try other.pass.actors[1].integer(at: 0x70,as: Int32.self),5)
    }

    /// A51: the post-draw commands with request 2 (0x450bb8) in stage mode (0x451160 1)
    /// over one active team-5 character (type 0) with this ID and HP 100: its HP afterwards.
    func killRequest(id: Int32,rules: OriginalGameRules) throws -> Int32 {
        let (hp,mp) = try killRequestHPMP(id: id,rules: rules)
        XCTAssertEqual(hp,mp,"HP and MP go together")
        return hp
    }
    func killRequestHPMP(id: Int32,rules: OriginalGameRules) throws -> (Int32,Int32) {
        var world = try defined(0x7d8),actors = [try defined(0x420)],globals = try defined(0xb440)
        try world.write(UInt32(0),at: 0x194);try world.write(UInt8(1),at: 4)
        try actors[0].write(Int32(5),at: 0x364);try actors[0].write(Int32(100),at: 0x2fc);try actors[0].write(Int32(100),at: 0x308)
        try globals.write(Int32(2),at: 0x450bb8-0x44d000);try globals.write(Int32(1),at: 0x451160-0x44d000)
        var header = try defined(0x7a4);try header.write(id,at: 0x6f4)
        let h = header,frame = try defined(0x178),bg = try defined(16)
        var slot: OriginalRequestSlotWord? = nil
        try OriginalPostDrawCommands.apply(world: &world,actors: &actors,globals: &globals,requestSlot: &slot,sse2: false,objectCount: 1,
            header: { _ in h },frame: { _,_ in frame },background: { _ in bg },rules: rules)
        return (try actors[0].integer(at: 0x2fc,as: Int32.self),try actors[0].integer(at: 0x308,as: Int32.self))
    }
    func testKillRequestSparedA51() throws {
        XCTAssertEqual(try killRequest(id: 300,rules: NTSDProfile.rules),100)
        XCTAssertEqual(try killRequest(id: 7,rules: NTSDProfile.rules),0)
        XCTAssertEqual(try killRequest(id: 300,rules: rules(spared: 7)),0)
        XCTAssertEqual(try killRequest(id: 7,rules: rules(spared: 7)),100)
    }

    /// A60: the mission stage's spawn (437400) of this word with HP 300 at this difficulty
    /// (0x450c30): the spawned Actor's HP.
    func missionHP(id: Int32,difficulty: Int32,rules: OriginalGameRules) throws -> Int32 {
        var stage = try defined(0x100)
        for (o,v): (Int,Int32) in [(0xac,id),(0xb0,100),(0xb4,300)] { try stage.write(v,at: o) }
        var header = try defined(0x7a4);try header.write(id,at: 0x6f4);try header.write(Int32(1),at: 0x6f8)
        var globals = try defined(0xb440)
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        try globals.write(difficulty,at: 0x450c30-0x44d000)
        var bg = try defined(16);try bg.write(Int32(400),at: 8)
        var pass = OriginalMissionStagePass(world: try defined(0x7d8),actors: [try defined(0x420)],globals: globals,stages: [stage],
            objects: [OriginalLoadedObject(header: header,nameTail: try defined(0x3c),frames: [],frameStorage: [],weaponSoundPaths: [:])],
            rules: rules,objectCount: 1,backgrounds: [bg],precision: .bits64,sse2: false,target: 0)
        try pass.spawn(0,0,0)
        XCTAssertTrue(pass.events.contains(.constructor(seat: 20)))
        return try pass.actors[0].integer(at: 0x2fc,as: Int32.self)
    }
    func testFixedDifficultyHPA60() throws {
        let n = NTSDProfile.rules
        XCTAssertEqual(try missionHP(id: 300,difficulty: -1,rules: n),300);XCTAssertEqual(try missionHP(id: 300,difficulty: 2,rules: n),300)
        XCTAssertEqual(try missionHP(id: 7,difficulty: -1,rules: n),450);XCTAssertEqual(try missionHP(id: 7,difficulty: 2,rules: n),225)
        XCTAssertEqual(try missionHP(id: 7,difficulty: 0,rules: n),300)
        XCTAssertEqual(try missionHP(id: 300,difficulty: -1,rules: rules(fixed: 7)),450)
        XCTAssertEqual(try missionHP(id: 7,difficulty: 2,rules: rules(fixed: 7)),300)
    }
}
