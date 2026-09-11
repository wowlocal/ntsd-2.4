import Foundation
import XCTest
import NTSDCore

/// Explicit numeric/rectangle entry inputs extracted from whole source War
/// calls. This does not compare the whole Native War menu or own participant join.
final class OriginalWarDependenciesTests: XCTestCase {
    struct Parameters: Decodable {
        let side: Int
        let preset: Int?,strength: Int32?,unit: Int?,change: String?
        let attack: Bool?,jump: Bool?,defense: Bool?
    }
    struct Inputs: Decodable { let parameters: Parameters,words: [[Int64]],known: Bool }
    struct Operation: Decodable { let label: String,kind: String,inputs: Inputs,stores: [[Int64]] }
    struct Frame: Decodable { let pulse: Bool,arguments: [UInt32],fills: [OriginalSurfaceFillRequest] }
    struct Call: Decodable { let label: String,fresh: Bool,initialPhase: Int32?,afterPhase: Int32,frames: [Frame] }
    struct Corpus: Decodable { let cases: Int,operations: [Operation],frames: [Call] }
    enum Trial: Error { case stop }
    func corpus() throws -> Corpus {
        guard let path=ProcessInfo.processInfo.environment["NTSD_WAR_DEPENDENCIES"] else {
            throw XCTSkip("War dependency evidence is pending packaging and whole menu composition")
        }
        return try JSONDecoder().decode(Corpus.self,from:Data(contentsOf:URL(fileURLWithPath:path)))
    }
    func initial() throws -> OriginalStateRecord {
        var g=try OriginalStateRecord(bytes:[UInt8](repeating:0,count:OriginalMatchPreparation.globalSize),defined:[Bool](repeating:false,count:OriginalMatchPreparation.globalSize))
        try OriginalWarTroops.initializeFileData(&g)
        return g
    }
    func apply(_ op: Operation,to g: inout OriginalStateRecord,observe: OriginalWarTroops.Store) throws {
        let p=op.inputs.parameters
        switch op.kind {
        case "initialize":try OriginalWarTroops.initialize(&g,observe:observe)
        case "selectPreset":try OriginalWarTroops.selectPreset(&g,side:p.side,preset:XCTUnwrap(p.preset),observe:observe)
        case "selectStrength":try OriginalWarTroops.selectStrength(&g,side:p.side,strength:XCTUnwrap(p.strength),observe:observe)
        case "selectNone":try OriginalWarTroops.selectNone(&g,side:p.side,observe:observe)
        case "selectAll":try OriginalWarTroops.selectAll(&g,side:p.side,observe:observe)
        case "adjust":try OriginalWarTroops.adjust(&g,side:p.side,unit:XCTUnwrap(p.unit),change:p.change == "active" ? .active : .reserve,
            attack:XCTUnwrap(p.attack),jump:XCTUnwrap(p.jump),defense:XCTUnwrap(p.defense),observe:observe)
        case "backup":try OriginalWarTroops.backup(&g,side:p.side,observe:observe)
        case "restoreJump","restoreCancel":try OriginalWarTroops.restore(&g,side:p.side,jump:op.kind == "restoreJump",observe:observe)
        case "finalize":try OriginalWarTroops.finalize(&g,observe:observe)
        default:XCTFail("Unknown dependency \(op.kind)");throw Trial.stop
        }
    }
    func testTroopStoresAgainstOriginalBranches() throws {
        let c=try corpus();XCTAssertEqual(c.cases,574)
        var kinds=Set<String>()
        for op in c.operations {
            XCTAssertTrue(op.inputs.known);var g=try initial()
            for pair in op.inputs.words { try g.write(Int32(pair[1]),at:Int(pair[0])-OriginalMatchPreparation.globalBase) }
            var stores: [[Int64]]=[]
            try apply(op,to:&g) { stores.append([Int64($0),Int64($1)]) }
            XCTAssertEqual(stores,op.stores,op.label+" "+op.kind)
            kinds.insert(op.kind)
        }
        XCTAssertEqual(kinds,["initialize","selectPreset","selectStrength","selectNone","selectAll","adjust","backup","restoreJump","restoreCancel","finalize"])
    }
    func testOrderedFrameRequestsAgainstOriginalHelpers() throws {
        let c=try corpus();var g=try initial(),count=0
        try g.write(UInt32(0x26006000),at:0x455608-OriginalMatchPreparation.globalBase)
        for call in c.frames {
            if call.fresh { try g.write(XCTUnwrap(call.initialPhase),at:0x451b80-OriginalMatchPreparation.globalBase) }
            for frame in call.frames {
                let a=frame.arguments;XCTAssertEqual(a.count,5);var fills: [OriginalSurfaceFillRequest]=[]
                try OriginalWarFrames.draw(globals:&g,pulse:frame.pulse,x:Int32(bitPattern:a[0]),y:Int32(bitPattern:a[1]),width:Int32(bitPattern:a[2]),height:Int32(bitPattern:a[3]),color:a[4],backing:[UInt8](repeating:0,count:100)) { fills.append($0) }
                XCTAssertEqual(fills.count,frame.fills.count,call.label)
                for (actual,expected) in zip(fills,frame.fills) {
                    XCTAssertEqual(actual.target,expected.target,call.label)
                    XCTAssertEqual(actual.rectangle,expected.rectangle,call.label)
                    XCTAssertEqual(actual.flags,expected.flags,call.label)
                    XCTAssertEqual(actual.defined,expected.defined,call.label)
                    for i in actual.effects.indices where actual.defined[i] { XCTAssertEqual(actual.effects[i],expected.effects[i],call.label) }
                }
                count+=1
            }
            XCTAssertEqual(try g.integer(at:0x451b80-OriginalMatchPreparation.globalBase,as:Int32.self),call.afterPhase,call.label)
        }
        XCTAssertGreaterThan(count,574)
    }
    func testLateDependencyObserverRollsBack() throws {
        let c=try corpus();var checked=Set<String>()
        for op in c.operations where !checked.contains(op.kind) && op.stores.count>1 {
            var g=try initial()
            for pair in op.inputs.words { try g.write(Int32(pair[1]),at:Int(pair[0])-OriginalMatchPreparation.globalBase) }
            let before=g;var count=0
            XCTAssertThrowsError(try apply(op,to:&g) { _,_ in count+=1;if count==op.stores.count { throw Trial.stop } })
            XCTAssertEqual(g,before);checked.insert(op.kind)
        }
        XCTAssertEqual(checked.count,10)
    }
    func testLateFrameObserverRollsBack() throws {
        var g=try initial();try g.write(UInt32(0x26006000),at:0x455608-OriginalMatchPreparation.globalBase)
        let before=g;var fills=0
        XCTAssertThrowsError(try OriginalWarFrames.draw(globals:&g,pulse:true,x:10,y:20,width:30,height:40,color:0xffffff,backing:[UInt8](repeating:0,count:100)) { _ in fills+=1;if fills==4 { throw Trial.stop } })
        XCTAssertEqual(g,before)
    }
}
