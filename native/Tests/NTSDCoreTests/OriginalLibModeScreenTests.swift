import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibModeScreenTests: XCTestCase {
    struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    struct Storage: Decodable { let bytes: String, defined: String }
    struct Record: Decodable { let address: UInt32, storage: Storage, live: Bool? }
    struct Spec: Decodable { let label: String, chain: Bool?, dcResult: Int32?, dc: UInt32?, methodResult: Int32? }
    struct Case: Decodable {
        let spec: Spec, before: [Record], after: [Record], actorAddresses: [UInt32]
        let events: [OriginalFrontScreenEvent], end: String, endSP: UInt32, cw: UInt32
    }
    struct Corpus: Decodable {
        let exeSHA256: String, libSHA256: String, cases: [Case], blobs: [String:Blob]
        let worldAddress: UInt32, bitmapAddress: UInt32, target: UInt32, libraryAddress: UInt32, stackAddress: UInt32, entrySP: UInt32, bodySP: UInt32
    }
    enum Stop: Error, Equatable { case injected, panel, worker, unexpected }
    final class Resources {
        let corpus: Corpus
        var decoded: [String:[UInt8]] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_LIB_MODE_SCREEN"].map { URL(fileURLWithPath:$0) }
                ?? XCTUnwrap(Bundle.module.url(forResource:"original-lib-mode-screen",withExtension:"json",subdirectory:"Fixtures"))
            corpus = try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:128_000_000))
            XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(corpus.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
            XCTAssertEqual(corpus.cases.count,112)
            XCTAssertEqual(corpus.worldAddress,0x22000020);XCTAssertEqual(corpus.bitmapAddress,0x27000020)
            XCTAssertEqual(corpus.target,0x26006000);XCTAssertEqual(corpus.libraryAddress,0x36000000)
            XCTAssertEqual(corpus.stackAddress,0x10000000);XCTAssertEqual(corpus.entrySP,0x1000f000);XCTAssertEqual(corpus.bodySP,0x1000e8e8)
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes=decoded[key] { return bytes }
            let b=try XCTUnwrap(corpus.blobs[key]);XCTAssertEqual(b.sha256,key)
            let bytes=try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:100_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)),key);decoded[key]=bytes;return bytes
        }
        func record(_ record: Record) throws -> OriginalStateRecord {
            let raw=try blob(record.storage.bytes),mask=try blob(record.storage.defined)
            XCTAssertEqual(raw.count,mask.count);XCTAssertTrue(mask.allSatisfy { $0<2 })
            return try .init(bytes:raw,defined:mask.map { $0 != 0 })
        }
    }
    func compare(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String, privateZero: Bool = false) throws {
        XCTAssertEqual(actual.bytes.count,expected.bytes.count,label)
        for i in actual.bytes.indices {
            if actual.defined[i] != expected.defined[i] || (expected.defined[i] || !privateZero) && actual.bytes[i] != expected.bytes[i] || privateZero && !actual.defined[i] && actual.bytes[i] != 0 {
                XCTFail("\(label)+\(String(i,radix:16)): \(actual.bytes[i])/\(actual.defined[i]) expected \(expected.bytes[i])/\(expected.defined[i])");throw Stop.unexpected
            }
        }
    }
    @discardableResult
    func run(_ item: Case,_ r: Resources,_ library: inout OriginalLibSurfaceText,failure: String? = nil) throws -> Int {
        let c=r.corpus,base=OriginalMatchPreparation.globalBase
        let before=try Dictionary(uniqueKeysWithValues:item.before.map { ($0.address,try r.record($0)) })
        let after=try Dictionary(uniqueKeysWithValues:item.after.map { ($0.address,try r.record($0)) })
        var globals=try XCTUnwrap(before[UInt32(base)])
        if item.end == "workerChild" {
            // Source masks here record writes. This untouched toggle is -99
            // in the pinned EXE data, independently verified by the read audit.
            XCTAssertEqual(Array(globals.bytes[0x784..<0x788]),[0x9d,0xff,0xff,0xff])
            try globals.write(Int32(-99),at:0x784)
        }
        // These are explicitly declared controlled entry bytes, never after-state.
        // World/Actor backing stays opaque; only the eight owned seat pointers bind.
        var world=try XCTUnwrap(before[c.worldAddress])
        let actors=try item.actorAddresses.map { try XCTUnwrap(before[$0]) }
        XCTAssertEqual(actors.count,9)
        for i in 0..<8 {
            let pointer=try world.integer(at:0x194+i*4,as:UInt32.self)
            let index=try XCTUnwrap(item.actorAddresses.firstIndex(of:pointer));try world.write(UInt32(index),at:0x194+i*4)
        }
        var memory=OriginalMenuPresentationMemory(replayPointers:try XCTUnwrap(before[0x4588a8]))
        for record in item.before where record.live != nil { memory.allocations[record.address] = .init(storage:try r.record(record),live:record.live!) }
        XCTAssertEqual(memory.allocations.count,7)
        // Build all five declared bitmap records ourselves; source bytes are checks.
        for i in 0..<5 {
            var bitmap=try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x1f50),defined:[Bool](repeating:true,count:0x1f50))
            for (offset,value): (Int,UInt32) in [(0,0x26004000+UInt32(i*16)),(4,64),(8,64),(12,500)] { try bitmap.write(value,at:offset) }
            for j in 0..<500 {
                for (offset,value): (Int,UInt32) in [(0x10,UInt32(j%8*8)),(0x7e0,UInt32(j%8*8)),(0xfb0,8),(0x1780,8)] { try bitmap.write(value,at:offset+j*4) }
            }
            let address=c.bitmapAddress+UInt32(i*0x2000)
            try compare(bitmap,try XCTUnwrap(before[address]),item.spec.label+" bitmap input")
            memory.allocations[address] = .init(storage:bitmap)
        }
        let beforeLibrary=try XCTUnwrap(before[c.libraryAddress])
        XCTAssertEqual(library.retainedDC,try beforeLibrary.integer(at:0x306e,as:UInt32.self),item.spec.label+" own retained DC entry")
        // No source private stack or DDBLTFX backing enters the native call.
        var local=try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x704),defined:[Bool](repeating:false,count:0x704))
        let initialGlobals=globals,initialMemory=memory,initialLocal=local,initialLibrary=library
        var eventIndex=0,keyCount=0,buffer:[OriginalFrontScreenEvent]=[],committed:[OriginalFrontScreenEvent]=[]
        func event(_ e: OriginalFrontScreenEvent) throws {
            guard eventIndex<item.events.count else { XCTFail("Unexpected event \(e)");throw Stop.unexpected }
            let expected=item.events[eventIndex]
            if e.kind == "fill" {
                let a=try XCTUnwrap(e.fill),b=try XCTUnwrap(expected.fill)
                XCTAssertEqual(a.target,b.target);XCTAssertEqual(a.rectangle,b.rectangle);XCTAssertEqual(a.flags,b.flags);XCTAssertEqual(a.defined,b.defined)
                for i in a.effects.indices { XCTAssertEqual(a.effects[i],a.defined[i] ? b.effects[i] : 0) }
            } else if e != expected { XCTFail("\(item.spec.label) event\(eventIndex): \(e), expected \(expected)");throw Stop.unexpected }
            eventIndex += 1;buffer.append(e)
            if e.kind == "keyName" { keyCount += 1 }
            if failure == "text" && e.kind == "textOut" || failure == "key" && e.kind == "textOut" && keyCount == 27 || failure == "cursor" && e.kind == "blit" && eventIndex == item.events.count { throw Stop.injected }
        }
        do {
            let end=try OriginalModeScreen.advanceWithLibrary(world:world,actors:actors,globals:&globals,memory:&memory,local:&local,libraryText:&library,
                worldAddress:c.worldAddress,target:c.target,
                input:.init(dcResult:item.spec.dcResult ?? 0,dc:item.spec.dc ?? 0x76543210,methodResult:item.spec.methodResult ?? -1,drawResults:[-1],shellResult:33),
                fillBacking:[UInt8](repeating:0,count:100),background:{ _,_ in throw Stop.unexpected },
                update:{ state in
                    let result=try OriginalMenuPanelUpdate.run(globals:&state,content:{ prefix in
                        try compare(prefix,try XCTUnwrap(after[UInt32(base)]),item.spec.label+" worker prefix")
                        throw Stop.worker
                    },bitmap:{ _ in throw Stop.unexpected },write:{ _,_ in throw Stop.unexpected }) { e,_ in
                        if e.kind == "enter" || e.kind == "leave" { try event(.init(e.kind,e.arguments)) }
                    }
                    XCTAssertEqual(result,.ready)
                },panel:{ state in
                    if failure == "released" { throw Stop.injected }
                    if try state.integer(at:0x458420-base,as:UInt32.self) != 0 {
                        try compare(state,try XCTUnwrap(after[UInt32(base)]),item.spec.label+" panel prefix")
                        throw Stop.panel
                    }
                },draw:{ args,state,owned in
                    let allocation=try XCTUnwrap(owned.allocations[args[0]]);XCTAssertTrue(allocation.live)
                    var bitmap=allocation.storage;let surface=try bitmap.integer(at:0,as:UInt32.self);try bitmap.write(UInt32(surface == 0 ? 0 : 1),at:0)
                    let request=try OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:surface,targetSurface:args[6],viewportWidth:state.integer(at:0x44d78c-base,as:Int32.self),viewportHeight:state.integer(at:0x44d790-base,as:Int32.self))
                    _ = try OriginalBitmapDrawing.draw(request,bitmap:bitmap,observeRead:{ read in var e=OriginalFrontScreenEvent("read");e.read=read;try event(e) },observeClip:{ clip in var e=OriginalFrontScreenEvent("clip");e.clip=clip;try event(e) },perform:{ blit in var e=OriginalFrontScreenEvent("blit");e.blit=blit;try event(e);return -1 })
                },observe:event)
            XCTAssertNil(failure);XCTAssertEqual(end.rawValue,item.end);XCTAssertEqual(eventIndex,item.events.count)
            XCTAssertEqual(item.cw,0x23f);XCTAssertEqual(item.endSP,end == .returned ? c.entrySP+20 : c.bodySP)
            try compare(globals,try XCTUnwrap(after[UInt32(base)]),item.spec.label+" globals")
            try compare(memory.replayPointers,try XCTUnwrap(after[0x4588a8]),item.spec.label+" replay pointers")
            for record in item.after where record.live != nil {
                let allocation=try XCTUnwrap(memory.allocations[record.address]);XCTAssertEqual(allocation.live,record.live)
                try compare(allocation.storage,try r.record(record),item.spec.label+" retained allocation")
            }
            for address in [c.worldAddress]+item.actorAddresses { XCTAssertEqual(before[address],after[address],"Read-only World/Actor") }
            let stack=try XCTUnwrap(after[c.stackAddress]),start=Int(c.bodySP+0x10-c.stackAddress)
            let expectedLocal=try OriginalStateRecord(bytes:Array(stack.bytes[start..<start+0x704]),defined:Array(stack.defined[start..<start+0x704]))
            try compare(local,expectedLocal,item.spec.label+" own local",privateZero:true)
            XCTAssertEqual(library.retainedDC,try XCTUnwrap(after[c.libraryAddress]).integer(at:0x306e,as:UInt32.self))
            committed=buffer;XCTAssertEqual(committed.count,item.events.count)
        } catch let error as Stop {
            switch error {
            case .injected:XCTAssertNotNil(failure)
            case .panel:XCTAssertEqual(item.end,"enabledPanel")
            case .worker:XCTAssertEqual(item.end,"workerChild")
            case .unexpected:throw error
            }
            XCTAssertEqual(globals,initialGlobals);XCTAssertEqual(memory.allocations,initialMemory.allocations);XCTAssertEqual(memory.replayPointers,initialMemory.replayPointers)
            XCTAssertEqual(local,initialLocal);XCTAssertEqual(library,initialLibrary);XCTAssertTrue(committed.isEmpty)
            if error == .panel || error == .worker { XCTAssertEqual(eventIndex,item.events.count) }
            if failure == "released" { XCTAssertTrue(buffer.contains { $0.kind == "free" });XCTAssertTrue(buffer.contains { $0.kind == "soundMethod" }) }
        }
        return eventIndex
    }
    func testWholeInstalledLibraryScreenAndOwnRetainedDC() throws {
        let r=try Resources();var retained=OriginalLibSurfaceText(),events=0
        for item in r.corpus.cases {
            if item.spec.chain == true { events += try run(item,r,&retained) }
            else { var library=OriginalLibSurfaceText();events += try run(item,r,&library) }
        }
        XCTAssertGreaterThan(events,10_000)
    }
    func testLateTextReleaseKeyAndCursorFailuresRollBackTogether() throws {
        let r=try Resources()
        for (label,failure) in [("row-0-0","text"),("buttons-0-4","released"),("keys-0","key"),("row-0-0","cursor")] {
            let item=try XCTUnwrap(r.corpus.cases.first { $0.spec.label == label });var library=OriginalLibSurfaceText()
            _ = try run(item,r,&library,failure:failure)
        }
    }
}
