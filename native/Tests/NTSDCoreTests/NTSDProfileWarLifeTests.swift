import XCTest
@testable import RandoriCore
import NTSDProfile

/// ENGINE_SPLIT E5e-3: War's reserve spawn takes a unit's life and a side-0
/// character's +0x318 mark from the profile's tables (A67). The chain the engine
/// had is kept here as the reference the tables must equal.
final class NTSDProfileWarLifeTests: XCTestCase {
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func rules(life: [Int32: Int32]? = nil,marks: [Int32: Int32]? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(modes: .init(survivalStages: n.survivalStages,numberedStages: n.numberedStages,finalStageSet: n.finalStageSet,
            stageWeightPlus1: n.stageWeightPlus1,stageWeightPlus2: n.stageWeightPlus2,warTroops: n.warTroops,stageBackgrounds: n.stageBackgrounds,
            killRequestSpared: n.killRequestSpared,fixedDifficultyHP: n.fixedDifficultyHP,heroSpawnWord: n.heroSpawnWord,
            troopSpawnWord: n.troopSpawnWord,troopOrBossSpawnWord: n.troopOrBossSpawnWord,spawnTroops: n.spawnTroops,bossTroop: n.bossTroop,
            warUnitLife: life ?? n.warUnitLife,warSideZeroMarks: marks ?? n.warSideZeroMarks))
    }
    /// 43abe2..43ac75 as the engine had it before E5e-3: the life and, for a side-0
    /// character, the last +0x318 store.
    static func chain(unit: Int32,sideZeroCharacter: Bool) -> (life: Int32,mark: Int32?) {
        var life: Int32 = 500,at43 = false,mark: Int32? = nil
        if sideZeroCharacter {
            mark = 0x8c
            if unit == 0x25 { mark = 0x72;at43 = true }
        }
        if !at43 && unit == 0x24 { life = 250 }
        else {
            if at43 || unit == 0x25 || unit == 0x23 || unit == 0x20 { life = 200 }
            if unit == 0x27 || unit == 0x21 { life = 150 }
            if unit == 0x22 { life = 100 }
            else {
                if unit == 0x1f || unit == 0x1e { life = 50 }
                if unit == 0x7a { life = 200 }
            }
        }
        return (life,mark)
    }
    func testTablesEqualTheChain() {
        let n = NTSDProfile.rules
        let units = Array(Int32(-2048)...Int32(2048)) + [Int32.min,Int32.min + 1,Int32.max - 1,Int32.max,0x10025,-0x25]
            + Array(n.warUnitLife.keys) + Array(n.warSideZeroMarks.keys)
        for unit in units {
            for side in [false,true] {
                let old = Self.chain(unit: unit,sideZeroCharacter: side)
                XCTAssertEqual(n.warUnitLife[unit] ?? 500,old.life,"life of \(unit)")
                XCTAssertEqual(side ? (n.warSideZeroMarks[unit] ?? 0x8c) : nil,old.mark,"mark of \(unit)")
            }
        }
    }
    /// War's spawn (43aaab) of this unit into seat 20 for side `side` (0 or 1, of a count
    /// of 1), the Object of type `type`: the Actor's life (+0x300, +0x2fc, +0x304) and +0x318.
    func spawn(unit: Int32,side: Int32,type: Int32 = 0,rules: OriginalGameRules) throws -> (life: [Int32],mark: Int32) {
        var globals = try defined(0xb440)
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        var header = try defined(0x7a4);try header.write(unit,at: 0x6f4);try header.write(type,at: 0x6f8)
        var bg = try defined(16);try bg.write(Int32(800),at: 0);try bg.write(Int32(400),at: 8)
        var p = OriginalWarBattlePass(world: try defined(0x7d8),actors: [try defined(0x420)],globals: globals,
            objects: [OriginalLoadedObject(header: header,nameTail: try defined(0x3c),frames: [],frameStorage: [],weaponSoundPaths: [:])],
            rules: rules,objectCount: 1,backgrounds: [bg])
        try p.spawn(seat: 20,ordinal: 0,unit: unit,side: side,count: 1)
        return (try [0x300,0x2fc,0x304].map { try p.i(0,$0) },try p.i(0,0x318))
    }
    func testWarSpawnLifeAndMarkA67() throws {
        let n = NTSDProfile.rules
        for (unit,life): (Int32,Int32) in [(36,250),(37,200),(35,200),(32,200),(39,150),(33,150),(34,100),(31,50),(30,50),(122,200),(38,500),(7,500)] {
            XCTAssertEqual(try spawn(unit: unit,side: 1,rules: n).life,[life,life,life],"\(unit)")
        }
        XCTAssertEqual(try spawn(unit: 37,side: 0,rules: n).mark,0x72);XCTAssertEqual(try spawn(unit: 36,side: 0,rules: n).mark,0x8c)
        XCTAssertEqual(try spawn(unit: 37,side: 1,rules: n).mark,0,"side 1: no store")
        XCTAssertEqual(try spawn(unit: 37,side: 0,type: 1,rules: n).mark,0,"not a character: no store")
        XCTAssertEqual(try spawn(unit: 37,side: 0,type: 1,rules: n).life,[200,200,200],"life for any type")
        let moved = rules(life: [7: 999],marks: [36: 0x50])
        XCTAssertEqual(try spawn(unit: 36,side: 1,rules: moved).life,[500,500,500]);XCTAssertEqual(try spawn(unit: 7,side: 1,rules: moved).life,[999,999,999])
        XCTAssertEqual(try spawn(unit: 37,side: 0,rules: moved).mark,0x8c);XCTAssertEqual(try spawn(unit: 36,side: 0,rules: moved).mark,0x50)
    }
}
