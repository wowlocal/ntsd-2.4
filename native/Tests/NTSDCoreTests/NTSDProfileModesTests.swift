import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5c-2e: the mission stage pass's stage start (`run`: D2's blink,
/// D3's survival revive, D4's banner), stage line (`hud`, D6) and set end
/// (`setTail`, D7), the camera's survival case (D14), War's troop count (A65) and
/// the match prelude's arena and replay name (D8, D9) follow the profile. Synthetic records, the passes built directly.
final class NTSDProfileModesTests: XCTestCase {
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func modes(survival: OriginalIDRange? = nil,numbered: OriginalIDRange? = nil,final: OriginalIDRange? = nil,troops: OriginalIDSet? = nil,
               backgrounds: [Int32: Int32]? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(modes: .init(survivalStages: survival ?? n.survivalStages,numberedStages: numbered ?? n.numberedStages,
            finalStageSet: final ?? n.finalStageSet,stageWeightPlus1: n.stageWeightPlus1,stageWeightPlus2: n.stageWeightPlus2,warTroops: troops ?? n.warTroops,
            stageBackgrounds: backgrounds ?? n.stageBackgrounds))
    }
    func pass(stage: Int32,rules: OriginalGameRules,globals set: [(Int,Int32)] = []) throws -> OriginalMissionStagePass {
        var globals = try defined(0xb440)
        try globals.write(stage,at: 0x450b94-0x44d000)
        for (a,v) in set { try globals.write(v,at: a-0x44d000) }
        return OriginalMissionStagePass(world: try defined(0x7d8),actors: [try defined(0x420)],globals: globals,stages: [try defined(0x100)],
            objects: [],rules: rules,objectCount: 0,backgrounds: [],precision: .bits64,sse2: false,target: 0)
    }
    /// The stage line `hud` formats: its caller (0x438759 numbered, 0x4387bb survival) and text.
    func stageLine(_ stage: Int32,rules: OriginalGameRules) throws -> (caller: UInt32,text: String)? {
        var p = try pass(stage: stage,rules: rules,globals: [(0x44f880,3)])
        try p.hud()
        for case .call(let c) in p.events where c.kind == .format && [0x438759,0x4387bb].contains(c.caller) {
            return (c.caller,String(decoding: c.text ?? [],as: UTF8.self))
        }
        return nil
    }
    func testNumberedStagesD6() throws {
        XCTAssertEqual(try stageLine(15,rules: NTSDProfile.rules)?.text,"STAGE 2-6")
        XCTAssertEqual(try stageLine(55,rules: NTSDProfile.rules)?.text,"Survival Stage: 3")
        XCTAssertEqual(try stageLine(-1,rules: NTSDProfile.rules)?.caller,0x438759,"below 50, negatives included")
        XCTAssertEqual(try stageLine(49,rules: NTSDProfile.rules)?.caller,0x438759);XCTAssertEqual(try stageLine(50,rules: NTSDProfile.rules)?.caller,0x4387bb)
        let moved = modes(numbered: OriginalIDRange(Int32.min..<60))
        XCTAssertEqual(try stageLine(55,rules: moved)?.text,"STAGE 6-6")
        XCTAssertEqual(try stageLine(15,rules: modes(numbered: OriginalIDRange(0..<10)))?.text,"Survival Stage: 3")
    }
    /// `setTail(3)` on the wipe's last step: menu 0x44d020, the next stage 0x450b94.
    func setEnd(_ stage: Int32,rules: OriginalGameRules) throws -> (menu: Int32,stage: Int32) {
        var p = try pass(stage: stage,rules: rules,globals: [(0x450ba4,20),(0x44d020,7)])
        try p.setTail(3)
        return (try p.g(0x44d020),try p.g(0x450b94))
    }
    func testFinalStageSetD7() throws {
        var r = try setEnd(45,rules: NTSDProfile.rules)
        XCTAssertEqual(r.menu,0x12c,"the last set's end goes to the menu");XCTAssertEqual(r.stage,45)
        r = try setEnd(40,rules: NTSDProfile.rules);XCTAssertEqual(r.menu,0x12c)
        r = try setEnd(35,rules: NTSDProfile.rules)
        XCTAssertEqual(r.menu,7);XCTAssertEqual(r.stage,40,"the next set")
        r = try setEnd(45,rules: modes(final: OriginalIDRange(30..<40)))
        XCTAssertEqual(r.menu,7);XCTAssertEqual(r.stage,50)
        r = try setEnd(35,rules: modes(final: OriginalIDRange(30..<40)))
        XCTAssertEqual(r.menu,0x12c);XCTAssertEqual(r.stage,35)
    }
    func testSurvivalCameraD14() throws {
        func x(_ stage: Int32,_ rules: OriginalGameRules) throws -> Double {
            try NTSDProfileCamera.run(id: 123,x: 5,team: 0,mode: 1,stage: stage,rules: rules).x
        }
        XCTAssertEqual(try x(55,NTSDProfile.rules),10);XCTAssertEqual(try x(59,NTSDProfile.rules),10);XCTAssertEqual(try x(60,NTSDProfile.rules),5)
        XCTAssertEqual(try x(55,modes(survival: OriginalIDRange(60..<70))),5)
        XCTAssertEqual(try x(65,modes(survival: OriginalIDRange(60..<70))),10)
    }
    /// The mission pass's `run` on stage 0 (one phase, every slot empty) with the
    /// banner timer: the blink flag 0x450ba0, the first player's HP and the banner's
    /// bitmap frames (3 is the survival bitmap; the digits otherwise).
    func stageStart(timer: Int32,rules: OriginalGameRules) throws -> (blink: Int32,hp: Int32,banner: [UInt32]) {
        var stage = try defined(OriginalMissionStagePass.stride)
        try stage.write(Int32(1),at: 0)
        for k in 0..<60 { try stage.write(Int32(-1),at: 0x40+k*OriginalMissionStagePass.slot+0xac) }
        var p = try pass(stage: 0,rules: rules,globals: [(0x44fb6c,-1),(0x450b9c,timer)])
        p = OriginalMissionStagePass(world: p.world,actors: p.actors,globals: p.globals,stages: [stage,try defined(OriginalMissionStagePass.stride)],
            objects: [],rules: rules,objectCount: 0,backgrounds: [],precision: .bits64,sse2: false,target: 0)
        for n in 0..<3000 { try p.globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        try p.run()
        var banner: [UInt32] = []
        for case .call(let c) in p.events where c.kind == .bitmapDraw && [0x438202,0x438162,0x43817e,0x4381b2].contains(c.caller) {
            banner.append(c.arguments[2])
        }
        return (try p.g(0x450ba0),try p.i(0,0x2fc),banner)
    }
    func testSurvivalStartD2D3() throws {
        var r = try stageStart(timer: 0,rules: NTSDProfile.rules)
        XCTAssertEqual(r.blink,0);XCTAssertEqual(r.hp,0,"stage 0 is no survival stage")
        r = try stageStart(timer: 0,rules: modes(survival: OriginalIDRange(0..<10)))
        XCTAssertEqual(r.blink,1);XCTAssertEqual(r.hp,5,"the survival revive")
    }
    func testBannerD4() throws {
        XCTAssertEqual(try stageStart(timer: 50,rules: NTSDProfile.rules).banner,[0x19,0x24,0x1b,0x1b],"STAGE, '-' and the digits 1-1")
        XCTAssertEqual(try stageStart(timer: 50,rules: modes(numbered: OriginalIDRange(10..<50))).banner,[3])
    }
    /// War's troop count (43a910): one side-1 troop of unit 31 at seat 20 against a
    /// limit of 1 and a reserve of 1; the reserve afterwards, whether a unit spawned,
    /// and whether the pass got past the spawn step (it sets 0x451b7c there).
    func war(rules: OriginalGameRules) throws -> (reserve: Int32,spawned: Bool,past: Bool) {
        var globals = try defined(0xb440)
        for (a,v): (Int,Int32) in [(0x44d37c,1),(0x44d350,31),(0x44d6a8,1),(0x44d700,1)] { try globals.write(v,at: a-0x44d000) }
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        var world = try defined(0x7d8);try world.write(UInt8(1),at: 4+20)
        var actor = try defined(0x420);try actor.write(Int32(1),at: 0x344)
        var header = try defined(0x7a4);try header.write(Int32(31),at: 0x6f4)
        var bg = try defined(16);try bg.write(Int32(800),at: 0);try bg.write(Int32(400),at: 8)
        var p = OriginalWarBattlePass(world: world,actors: [actor],globals: globals,
            objects: [OriginalLoadedObject(header: header,nameTail: try defined(0x3c),frames: [],frameStorage: [],weaponSoundPaths: [:])],
            rules: rules,objectCount: 1,backgrounds: [bg])
        // What follows the spawn step is not under test; the reserve and events before it are.
        do { try p.run() } catch {}
        return (try p.g(0x44d6a8),p.events.contains { if case .constructor = $0 { return true };return false },try p.g(0x451b7c) == 1)
    }
    func testWarTroopsA65() throws {
        var r = try war(rules: NTSDProfile.rules)
        XCTAssertTrue(r.past);XCTAssertEqual(r.reserve,1);XCTAssertFalse(r.spawned,"31 is a troop: the limit is reached")
        r = try war(rules: modes(troops: OriginalIDSet([32])))
        XCTAssertTrue(r.past);XCTAssertEqual(r.reserve,0);XCTAssertTrue(r.spawned,"31 is no troop under a moved list")
    }
    /// The match prelude in stage mode for this stage, from arena 77: the arena it
    /// leaves and the replay name's suffix.
    func prelude(_ stage: Int32,rules: OriginalGameRules) throws -> (arena: Int32,name: String) {
        var g = try defined(OriginalMatchPreparation.globalSize)
        for (a,v): (Int,Int32) in [(0x451160,1),(0x450b94,stage),(0x44d024,77)] { try g.write(v,at: a-OriginalMatchPreparation.globalBase) }
        let name = try OriginalMatchPrelude.apply(globals: &g,localTime: .init(year: 2026,month: 10,dayOfWeek: 1,day: 19,hour: 20,minute: 0,second: 0,milliseconds: 0),
                                                  rules: rules)
        return (try g.integer(at: 0x44d024-OriginalMatchPreparation.globalBase,as: Int32.self),String(name.dropFirst(15)))
    }
    func testPreludeD8D9() throws {
        let n = NTSDProfile.rules
        XCTAssertEqual(try prelude(10,rules: n).arena,2);XCTAssertEqual(try prelude(10,rules: n).name,"_Stage_2.lfr")
        XCTAssertEqual(try prelude(49,rules: n).arena,77,"no set start: the arena stays");XCTAssertEqual(try prelude(49,rules: n).name,"_Stage_5.lfr")
        XCTAssertEqual(try prelude(50,rules: n).arena,6);XCTAssertEqual(try prelude(50,rules: n).name,"_Survival.lfr")
        XCTAssertEqual(try prelude(55,rules: n).arena,77);XCTAssertEqual(try prelude(55,rules: n).name,"_Survival.lfr")
        let moved = modes(numbered: OriginalIDRange(Int32.min..<60),backgrounds: [55: 9])
        XCTAssertEqual(try prelude(55,rules: moved).arena,9);XCTAssertEqual(try prelude(55,rules: moved).name,"_Stage_6.lfr")
        XCTAssertEqual(try prelude(10,rules: moved).arena,77);XCTAssertEqual(try prelude(10,rules: moved).name,"_Stage_2.lfr")
        XCTAssertEqual(try prelude(10,rules: modes(numbered: OriginalIDRange(Int32.min..<10))).name,"_Survival.lfr","a narrowed numbered range")
    }
}
