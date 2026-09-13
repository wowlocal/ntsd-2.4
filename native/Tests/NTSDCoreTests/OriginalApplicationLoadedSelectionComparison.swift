import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Expected state only. The actual Bootstrap RNG table remains an engine input;
/// this independent arithmetic projection never calls a Core random/selection helper.
final class OriginalApplicationLoadedSelectionComparison {
    typealias H = OriginalApplicationLoadedCharacterComparison
    typealias R = CharacterScreenReference
    typealias M = OriginalApplicationLoadedMenuTests
    let human: H
    struct RandomState {
        var selected: [Int32],objects: [UInt32],path: [UInt8]
    }
    let table: [UInt8],sourceTable: [UInt8]
    var ownRandom: [RandomState] = [],sourceRandom: [RandomState] = []
    var events: [[OriginalFrontScreenEvent]] = []
    var points = 0
    init(_ reverse: Bool,_ own: OriginalMatchPreparation) throws {
        human = try H(reverse,selection:true)
        try human.catalogInputs(own)
        let joinSound = try own.globals.integer(at:0x45560c-0x44d000,as:UInt32.self)
        let confirmationSound = try own.globals.integer(at:0x455610-0x44d000,as:UInt32.self)
        XCTAssertNotEqual(joinSound,0);XCTAssertNotEqual(confirmationSound,0)
        XCTAssertNotEqual(joinSound,confirmationSound)
        let bgCount = try XCTUnwrap(own.catalog.registry.records[0x4d82380]).integer(at:4,as:Int32.self)
        XCTAssertEqual(bgCount,Int32(human.sourceCatalog.children.filter { $0.kind == "background" }.count))
        XCTAssertEqual(bgCount,17)
        let source = try human.globals(human.corpus.cases[0].screen.before)
        let pool = try human.pool(human.corpus.cases[0].screen.before)
        let lo = 0x44ff90-0x44d000
        table = Array(own.globals.bytes[lo..<lo+3001]);sourceTable = Array(source.bytes[lo..<lo+3001])
        XCTAssertEqual(MatchPreparationReference.digest(Data(table)),"5352f941c619060669587370c1974685877d4899a6ad0d1b165f54ecd4aa89c7")
        XCTAssertEqual(MatchPreparationReference.digest(Data(sourceTable)),"b9bb523689370aff4f314eeee77ff25110268723a416190b498563afa10244a2")
        XCTAssertTrue(own.globals.defined[lo..<lo+3001].allSatisfy { $0 })
        for state in [source,own.globals] {
            XCTAssertEqual(try state.integer(at:0x450bcc-0x44d000,as:UInt32.self),0)
            XCTAssertEqual(try state.integer(at:0x450c34-0x44d000,as:UInt32.self),0)
        }
        let selected = try (0..<8).map { try source.integer(at:0x451248-0x44d000+$0*4,as:Int32.self) }
        let objects = try (0..<8).map { try pool.integer(at:0x7d8+$0*0x420+0x368,as:UInt32.self) }
        let pathRange = (0x44eed0-0x44d000)..<(0x44eed0-0x44d000+52)
        ownRandom = [.init(selected:selected,objects:objects,path:Array(own.globals.bytes[pathRange]))]
        sourceRandom = [.init(selected:selected,objects:objects,path:Array(source.bytes[pathRange]))]
        let ids = try own.loadedObjects.map { try $0.header.integer(at:0x6f4,as:Int32.self) }
        let types = try own.loadedObjects.map { try $0.header.integer(at:0x6f8,as:Int32.self) }
        func choices(_ selected: [Int32]) -> [UInt32] {
            (1..<ids.count).filter { types[$0] == 0 && ids[$0] < 30 && !selected.contains(Int32($0)) }.map(UInt32.init)
        }
        let paths = ["bgm\\main.wma","bgm\\stage1.wma","bgm\\stage2.wma","bgm\\stage3.wma",
                     "bgm\\stage4.wma","bgm\\stage5.wma","bgm\\boss1.wma","bgm\\boss2.wma"]
        var count = 0,pending: (Int,[UInt32],[UInt32])?
        for (caseIndex,item) in human.corpus.cases.enumerated() {
            let calls = item.screen.helpers.filter { $0.entry == 0x401a30 }
            if [21,29,33].contains(caseIndex) {
                XCTAssertEqual(calls.count,1)
                XCTAssertEqual(calls.first?.returnPC,caseIndex == 21 ? 0x42b570 : 0x42df16)
                XCTAssertEqual(try human.globals(item.screen.before).integer(at:0x455610-0x44d000,as:UInt32.self),0)
            } else { XCTAssertTrue(calls.isEmpty) }
            XCTAssertEqual(item.screen.events.filter { $0.kind == "soundRequest" }.count,calls.count)
            var projected: [OriginalFrontScreenEvent] = []
            for original in item.screen.events {
                var event = original
                if event.kind == "candidates" {
                    XCTAssertNil(pending)
                    let a = choices(sourceRandom[count].selected),b = choices(ownRandom[count].selected)
                    XCTAssertEqual(Array(event.arguments.dropFirst()),a)
                    XCTAssertEqual(a.count,b.count)
                    let seat = Int(event.arguments[0]);XCTAssertEqual(seat,count+2)
                    pending = (seat,a,b);event.arguments = [UInt32(seat)]+b
                } else if event.kind == "random" {
                    let args = event.arguments,range = Int(args[1]),next = count+1
                    XCTAssertEqual(args.count,7);XCTAssertEqual(args[3],UInt32(count));XCTAssertEqual(args[4],UInt32(count))
                    XCTAssertEqual(args[5],UInt32(next));XCTAssertEqual(args[6],UInt32(next))
                    let sourceResult = (Int(sourceTable[next])+next)%range
                    let ownResult = (Int(table[next])+next)%range
                    XCTAssertEqual(args[2],UInt32(sourceResult));event.arguments[2] = UInt32(ownResult)
                    var a = sourceRandom[count],b = ownRandom[count]
                    if count < 6 {
                        XCTAssertEqual(args[0],0xd7)
                        let (seat,sourceChoices,ownChoices) = try XCTUnwrap(pending)
                        XCTAssertEqual(range,sourceChoices.count)
                        a.selected[seat] = Int32(sourceChoices[sourceResult]);a.objects[seat] = sourceChoices[sourceResult]
                        b.selected[seat] = Int32(ownChoices[ownResult]);b.objects[seat] = ownChoices[ownResult]
                        pending = nil
                    } else {
                        XCTAssertNil(pending);XCTAssertEqual(args[0],1);XCTAssertEqual(range,8)
                        // Copy only through NUL, retaining every byte of the old tail.
                        for (i,value) in (Array(paths[sourceResult].utf8)+[0]).enumerated() { a.path[i] = value }
                        for (i,value) in (Array(paths[ownResult].utf8)+[0]).enumerated() { b.path[i] = value }
                    }
                    sourceRandom.append(a);ownRandom.append(b);count = next
                }
                projected.append(event)
            }
            events.append(projected)
        }
        XCTAssertNil(pending);XCTAssertEqual(count,35)
        XCTAssertEqual(sourceRandom.last?.selected,[17,21,24,38,39,32,22,36])
        XCTAssertEqual(ownRandom.last?.selected,[17,21,36,37,32,41,18,31])
    }
    func projection(_ snapshot: InputControlReference.Snapshot) throws -> (OriginalStateRecord,OriginalStateRecord) {
        var globals = try human.globals(snapshot),pool = try human.pool(snapshot)
        let count = Int(try globals.integer(at:0x450c34-0x44d000,as:UInt32.self))
        XCTAssertEqual(try globals.integer(at:0x450bcc-0x44d000,as:UInt32.self),UInt32(count))
        guard ownRandom.indices.contains(count) else { throw M.Stop.unexpected("RNG checkpoint prefix") }
        let source = sourceRandom[count],own = ownRandom[count]
        for seat in 0..<8 {
            let offset = 0x451248-0x44d000+seat*4,actor = 0x7d8+seat*0x420+0x368
            XCTAssertEqual(try globals.integer(at:offset,as:Int32.self),source.selected[seat])
            XCTAssertEqual(try pool.integer(at:actor,as:UInt32.self),source.objects[seat])
            try globals.write(own.selected[seat],at:offset);try pool.write(own.objects[seat],at:actor)
        }
        for i in table.indices {
            let offset = 0x44ff90-0x44d000+i
            XCTAssertEqual(globals.bytes[offset],sourceTable[i]);try globals.write(table[i],at:offset)
        }
        for i in own.path.indices {
            let offset = 0x44eed0-0x44d000+i
            XCTAssertEqual(globals.bytes[offset],source.path[i]);try globals.write(own.path[i],at:offset)
        }
        return (pool,globals)
    }
    func entry(_ own: OriginalMatchPreparation,_ item: R.Case) throws {
        let (pool,globals) = try projection(item.screen.before)
        try human.entry(own,item,projectedPool:pool,projectedGlobals:globals)
        // Whole possible selector/music write footprint, including idempotent
        // stores; table/name/bitmap reads have their independent input joins.
        let ranges = [0x44d010..<0x44d014,0x44d024..<0x44d02c,0x44d06c..<0x44d078,
                      0x44eed0..<0x44ef04,0x44f060..<0x44f0a0,0x44f128..<0x44f148,
                      0x44f18c..<0x44f190,0x450b98..<0x450b9c,0x450bcc..<0x450bd0,0x450c30..<0x450c38,
                      0x4511fc..<0x451248]
        for range in ranges { for address in range {
            let i = address-0x44d000
            guard own.globals.bytes[i] == globals.bytes[i],own.globals.defined[i] == globals.defined[i] else {
                throw M.Stop.unexpected("Selection entry footprint "+String(address,radix:16))
            }
        } }
    }
    func checkpoint(_ point: OriginalCharacterScreenCheckpoint,_ actual: OriginalMatchPreparation,
                    _ own: OriginalMatchPreparation,_ item: R.Case,_ index: Int) throws {
        let expected = item.screen.checkpoints[index]
        XCTAssertEqual(point.pc,expected.pc)
        if point.pc == 0x42a25a { XCTAssertEqual(point.seat,Int(expected.seat)) }
        XCTAssertEqual(point.locals,expected.locals.reduce(into:[:]) { $0[Int($1.key)!] = $1.value })
        let (beforePool,beforeGlobals) = try projection(item.screen.before)
        let (afterPool,afterGlobals) = try projection(expected.state)
        try human.transition(human.pool(actual),human.pool(own),beforePool,afterPool,item.label+" pool")
        try human.transition(actual.globals,own.globals,beforeGlobals,afterGlobals,item.label+" globals")
        XCTAssertEqual(actual.arithmeticPrecision,own.arithmeticPrecision)
        XCTAssertEqual(actual.interface.bitmaps,own.interface.bitmaps);XCTAssertEqual(actual.bitmaps,own.bitmaps)
        XCTAssertEqual(actual.backgrounds,own.backgrounds);XCTAssertEqual(actual.frameAllocations,own.frameAllocations)
        XCTAssertEqual(actual.releasedBitmaps,own.releasedBitmaps);XCTAssertEqual(actual.releasedBitmapOrder,own.releasedBitmapOrder)
        points += 1
    }
    func compareEvents(_ actual: [OriginalFrontScreenEvent],_ ready: M.S.Input.PendingContinuation,
                       _ item: R.Case,_ index: Int) throws {
        let source = try human.globals(item.screen.before)
        let sourceToken = try source.integer(at:0x451178-0x44d000,as:UInt32.self)
        let token = try ready.match.globals.integer(at:0x451178-0x44d000,as:UInt32.self)
        let own = try XCTUnwrap(ready.state.memory.allocations[token]);XCTAssertTrue(own.live)
        let record = try XCTUnwrap(item.screen.earlyBefore.records.first { $0.address == sourceToken })
        let expected = try OriginalStateRecord(bytes:human.bytes(record.storage.bytes),defined:human.bytes(record.storage.defined).map { $0 != 0 })
        XCTAssertTrue(record.live);XCTAssertEqual(expected.bytes.count,0x1f50)
        XCTAssertEqual(own.storage.defined,expected.defined)
        // Different undeclared allocator padding stays current and unknown.
        for i in 4..<expected.bytes.count where expected.defined[i] { XCTAssertEqual(own.storage.bytes[i],expected.bytes[i]) }
        let surface = try own.storage.integer(at:0,as:UInt32.self)
        XCTAssertNotEqual(surface,0);XCTAssertEqual(ready.state.graphics?.currentResources[surface]?.kind,"bitmapSurface")
        for event in item.screen.events where event.kind == "textOut" && event.arguments.count == 4 && event.arguments[1] == 174 && event.arguments[2] == 91 {
            let arena = Int(try source.integer(at:0x44d024-0x44d000,as:UInt32.self))
            let background = ready.match.backgrounds[arena]
            let end = try XCTUnwrap(background.bytes[0x3cc...].firstIndex(of:0))
            XCTAssertTrue(background.defined[0x3cc...end].allSatisfy { $0 })
            XCTAssertEqual(event.strings.first,Array(background.bytes[0x3cc..<end]))
        }
        try human.events(actual,ready,item,sourceEvents:events[index],extraDraws:[sourceToken:(token,own.storage,surface)],confirmationSlot:0x455610)
    }
}
