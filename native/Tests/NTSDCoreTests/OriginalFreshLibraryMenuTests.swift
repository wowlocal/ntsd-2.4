import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalFreshLibraryMenuTests: XCTestCase {
    typealias Base = OriginalCharacterMenuSurfaceTests
    typealias Music = OriginalCharacterMenuMusicSurfaceTests
    struct Environment: Equatable {
        var front: [OriginalFrontScreenEvent] = []
        var graphics = Base.Context()
        var music: [OriginalMusicEvent] = []
    }
    struct Startup: Decodable {
        let musicBoundary: Music.Boundary, musicAllocations: [Base.Record], events: [Music.Event]
    }
    struct MusicSpec: Decodable { let nullAllocation: Bool? }
    struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    struct Storage: Decodable { let bytes: String, defined: String }
    struct Record: Decodable { let address: UInt32, storage: Storage, live: Bool? }
    struct Spec: Decodable { let label: String, control: Bool, music: MusicSpec?, chain: Bool?, dcResult: Int32?, dc: UInt32?, methodResult: Int32?, milliseconds: UInt32? }
    struct Point: Decodable { let kind: String,records: [Record],eventCount: Int }
    struct Helper: Decodable { let entry: UInt32,firstStore: Int,lastStore: Int? }
    struct Write: Decodable { let address: UInt32,bytes: String }
    struct Read: Decodable { let address: UInt32,count: Int,storeCount: Int }
    struct Case: Decodable {
        let helpers: [Helper],pending: [Helper],writes: [Write],reads: [Read],apiReads: [Read]
        let spec: Spec, before: [Record], after: [Record], actorAddresses: [UInt32]
        let events: [OriginalFrontScreenEvent], end: String, endSP: UInt32, cw: UInt32
        let startup: Startup, screenSP: UInt32?,output: OriginalMenuPresentationInput,points: [Point]
    }
    struct Corpus: Decodable {
        let exeSHA256: String, libSHA256: String, cases: [Case], blobs: [String:Blob]
        let worldAddress: UInt32, bitmapAddress: UInt32, target: UInt32, libraryAddress: UInt32, stackAddress: UInt32, entrySP: UInt32, tailSP: UInt32
    }
    enum Stop: Error, Equatable { case injected, unexpected }
    final class Resources {
        let corpus: Corpus
        let startup: Base.Resources
        var decoded: [String:[UInt8]] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_FRESH_LIBRARY_MENU"].map { URL(fileURLWithPath:$0) }
                ?? XCTUnwrap(Bundle.module.url(forResource:"original-fresh-library-menu",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:128_000_000)
            corpus = try JSONDecoder().decode(Corpus.self,from:data)
            // A lossless projection into the retained startup comparator schema.
            // Full source bytes remain in the new fixture; no expected fields change.
            let document = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            var projected = document
            projected["cases"] = try XCTUnwrap(document["cases"] as? [[String:Any]]).map { $0["startup"]! }
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-fresh-menu-"+UUID().uuidString+".json")
            try JSONSerialization.data(withJSONObject:projected).write(to:temporary)
            defer { try? FileManager.default.removeItem(at:temporary) }
            startup = try Base.Resources(url:temporary,expectedCases:26)
            XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(corpus.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
            XCTAssertEqual(corpus.cases.count,26)
            XCTAssertEqual(corpus.worldAddress,0x22000020);XCTAssertEqual(corpus.bitmapAddress,0x27000020)
            XCTAssertEqual(corpus.target,0x26006000);XCTAssertEqual(corpus.libraryAddress,0x36000000)
            XCTAssertEqual(corpus.stackAddress,0x10000000);XCTAssertEqual(corpus.entrySP,0x1000f000);XCTAssertEqual(corpus.tailSP,0x1000e9bc)
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes=decoded[key] { return bytes }
            let b=try XCTUnwrap(corpus.blobs[key]);XCTAssertEqual(b.sha256,key)
            let bytes=try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:2_000_000)
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
    /// Separate the mode screen's own writes from prior music/bitmap helper
    /// lifetimes in the same original stack span. Original full masks stay intact.
    func screenLocalWrites(_ item: Case,_ origin: Int) throws -> [Bool] {
        let h=try XCTUnwrap((item.helpers+item.pending).first { $0.entry==0x431d10 })
        let first=h.firstStore,last=h.lastStore ?? item.writes.count
        var mask=[Bool](repeating:false,count:0x704)
        let reads=Dictionary(grouping:(item.reads+item.apiReads).filter {
            first<=$0.storeCount && $0.storeCount<=last && Int($0.address)<origin+mask.count && origin<Int($0.address)+$0.count
        },by:{ $0.storeCount })
        for step in first...last {
            for read in reads[step] ?? [] {
                let lo=max(origin,Int(read.address))-origin,hi=min(origin+mask.count,Int(read.address)+read.count)-origin
                guard mask[lo..<hi].allSatisfy({ $0 }) else {
                    XCTFail("Screen consumed a prior helper's local bytes");throw Stop.unexpected
                }
            }
            if step<last {
                let w=item.writes[step],lo=max(origin,Int(w.address)),hi=min(origin+mask.count,Int(w.address)+w.bytes.count/2)
                if lo<hi { for i in lo-origin..<hi-origin { mask[i]=true } }
            }
        }
        XCTAssertEqual(mask.filter { $0 }.count,108)
        return mask
    }
    @discardableResult
    func run(_ item: Case,_ r: Resources,_ library: inout OriginalLibSurfaceText,failure: String? = nil) throws -> Int {
        let c=r.corpus,base=OriginalMatchPreparation.globalBase
        let before=try Dictionary(uniqueKeysWithValues:item.before.map { ($0.address,try r.record($0)) })
        let after=try Dictionary(uniqueKeysWithValues:item.after.map { ($0.address,try r.record($0)) })
        var globals=try XCTUnwrap(before[UInt32(base)])
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
        for record in item.before where record.live == true { memory.allocations[record.address] = .init(storage:try r.record(record),live:record.live!) }
        XCTAssertEqual(memory.allocations.count,8)
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
        let panelAddress=c.bitmapAddress+(item.spec.control ? 0xc000 : 0xa000)
        var panel=try OriginalStateRecord(bytes:(0..<0x1f50).map { item.spec.control ? UInt8(($0*37+11)&255) : 0xa5 },defined:[Bool](repeating:false,count:0x1f50))
        for (offset,value): (Int,UInt32) in [(0,0x26004050),(4,794),(8,550),(12,11)] { try panel.write(value,at:offset) }
        let rects:[[UInt32]]=[[0,0,397,34],[397,0,397,34],[0,34,198,194],[198,34,198,194],[396,34,198,194],[594,34,198,194],[0,228,198,194],[198,228,198,194],[396,228,198,194],[594,228,198,194],[0,422,794,128]]
        for i in 0..<13 {
            let rect=i<11 ? rects[i] : [UInt32(i%8*8),UInt32(i%8*8),8,8]
            for (offset,value) in zip([0x10,0x7e0,0xfb0,0x1780],rect) { try panel.write(value,at:offset+i*4) }
        }
        try compare(panel,try XCTUnwrap(before[panelAddress]),item.spec.label+" own panel input")
        memory.allocations[panelAddress] = .init(storage:panel)
        let beforeLibrary=try XCTUnwrap(before[c.libraryAddress])
        XCTAssertEqual(library.retainedDC,try beforeLibrary.integer(at:0x306e,as:UInt32.self),item.spec.label+" own retained DC entry")
        // No source private stack or DDBLTFX backing enters the native call.
        var local=try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x704),defined:[Bool](repeating:false,count:0x704))
        let initialGlobals=globals,initialMemory=memory,initialLocal=local,initialLibrary=library,initialWorld=world
        var music=OriginalMusicMemory(),resources=OriginalMenuResourceLoading()
        let startupIndex = try XCTUnwrap(r.startup.c.cases.firstIndex { $0.spec.label == item.spec.label })
        let a = try Base.Adapter(r.startup.c.cases[startupIndex],r.startup)
        var eventIndex=0,keyCount=0,committed=Environment()
        func compareMusic(_ records: [Base.Record],_ memory: OriginalMusicMemory) throws {
            XCTAssertEqual(records.count,memory.allocations.count)
            for record in records {
                XCTAssertEqual(record.kind,"music-wide");XCTAssertEqual(record.count,26)
                XCTAssertEqual(try r.startup.blob(record.initial),a.pattern(record.count))
                let value=try XCTUnwrap(memory.allocations[record.address])
                XCTAssertEqual(value.bytes,try r.startup.blob(record.bytes))
                XCTAssertEqual(value.defined,try r.startup.blob(record.mask).map { $0 != 0 })
            }
        }
        func event(_ e: OriginalFrontScreenEvent,_ environment: inout Environment) throws {
            guard eventIndex<item.events.count else { XCTFail("Unexpected event \(e)");throw Stop.unexpected }
            let expected=item.events[eventIndex]
            if e.kind == "fill" {
                let a=try XCTUnwrap(e.fill),b=try XCTUnwrap(expected.fill)
                XCTAssertEqual(a.target,b.target);XCTAssertEqual(a.rectangle,b.rectangle);XCTAssertEqual(a.flags,b.flags);XCTAssertEqual(a.defined,b.defined)
                for i in a.effects.indices { XCTAssertEqual(a.effects[i],a.defined[i] ? b.effects[i] : 0) }
            } else if e != expected { XCTFail("\(item.spec.label) event\(eventIndex): \(e), expected \(expected)");throw Stop.unexpected }
            eventIndex += 1;environment.front.append(e)
            if e.kind == "keyName" { keyCount += 1 }
            if failure == "network" && e.kind == "textOut" && e.strings == [Array("Waiting for opponent...".utf8)] || failure == "volume" && e.kind == "method" && environment.front.filter({ $0.kind == "method" && $0.arguments[1] == 0x3c }).count == 5 || failure == "present" && e.kind == "method" && e.arguments[1] == 0x14 { throw Stop.injected }
        }
        do {
            let end=try OriginalModeMenuContinuation.advance(world:&world,actors:actors,globals:&globals,memory:&memory,music:&music,resources:&resources,local:&local,libraryText:&library,environment:&committed,
                worldAddress:c.worldAddress,target:c.target,
                screenInput:.init(dcResult:item.spec.dcResult ?? 0,dc:item.spec.dc ?? 0x76543210,methodResult:item.spec.methodResult ?? -1,drawResults:[-1],shellResult:33),
                outputInput:item.output,milliseconds:item.spec.milliseconds ?? 17,
                musicRequest:{ e,env in
                    let expected=try XCTUnwrap(item.startup.events[a.index].music);_ = try a.next("music")
                    XCTAssertEqual(e,.init(expected.kind,expected.arguments,expected.strings))
                    var response=expected.response
                    if e.kind == .allocate {
                        let pointer: UInt32 = item.spec.music?.nullAllocation == true ? 0 : 0x2c010020
                        response = .init(pointer:pointer,bytes:pointer == 0 ? nil : a.pattern(Int(e.arguments[0])))
                    } else if e.kind == .convert {
                        XCTAssertTrue(e.strings[0].allSatisfy { $0<128 })
                        let bytes=(e.strings[0]+[0]).flatMap { [$0,UInt8(0)] }
                        response = .init(result:e.arguments[3] == 0 ? 0 : Int32(e.strings[0].count+1),bytes:e.arguments[3] == 0 ? [] : bytes)
                    }
                    XCTAssertEqual(response,expected.response,"Own music allocation/conversion output")
                    env.music.append(e);try event(.init("startup"),&env);return response
                },allocate:{ i,env in
                    let value=try a.allocate(i,&env.graphics);try event(.init("startup"),&env);return value
                },perform:{ q,env in
                    let response=try a.perform(q,&env.graphics);try event(.init("startup"),&env);return response
                },resourceEvent:{ e,env in
                    try a.observe(e,&env.graphics)
                    if e.kind != .allocate { try event(.init("startup"),&env) }
                },afterMusic:{ entered,state,memory,env in
                    XCTAssertEqual(entered,!env.music.isEmpty);XCTAssertEqual(a.index,item.startup.musicBoundary.eventCount)
                    a.shadow=state.bytes+a.suffix;XCTAssertEqual(a.shadow,try r.startup.blob(item.startup.musicBoundary.snapshot.globals))
                    try compareMusic(item.startup.musicBoundary.allocations,memory)
                    if failure == "afterMusic" { throw Stop.injected }
                },resourceCheckpoint:{ try a.stored($0,$1,$2,&$3.graphics) },afterStartup:{ _,state,memory,images,env in
                    XCTAssertEqual(state.bytes+a.suffix,try r.startup.blob(a.c.after.globals))
                    XCTAssertEqual(a.index,a.events.count);XCTAssertEqual(a.stores,a.c.checkpoints.count)
                    try compareMusic(item.startup.musicAllocations,memory);try a.compare(a.c.records,images.bitmaps,env.graphics)
                    if failure == "afterStartup" { throw Stop.injected }
                },background:{ _,_,_ in throw Stop.unexpected },
                update:{ state,buffer in
                    let result=try OriginalMenuPanelUpdate.run(globals:&state,content:{ _ in throw Stop.unexpected },bitmap:{ _ in throw Stop.unexpected },write:{ _,_ in throw Stop.unexpected }) { e,_ in
                        if e.kind == "enter" || e.kind == "leave" { try event(.init(e.kind,e.arguments),&buffer) }
                    }
                    XCTAssertEqual(result,.ready)
                },draw:{ args,state,owned,buffer in
                    if buffer.front.contains(where:{ $0.kind == "free" && $0.arguments == [c.bitmapAddress] }) {
                        XCTAssertFalse(try XCTUnwrap(owned.allocations[c.bitmapAddress]).live,"Draw must see the screen's current resource ownership")
                    }
                    let allocation=try XCTUnwrap(owned.allocations[args[0]]);XCTAssertTrue(allocation.live)
                    var bitmap=allocation.storage;let surface=try bitmap.integer(at:0,as:UInt32.self);try bitmap.write(UInt32(surface == 0 ? 0 : 1),at:0)
                    let request=try OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:surface,targetSurface:args[6],viewportWidth:state.integer(at:0x44d78c-base,as:Int32.self),viewportHeight:state.integer(at:0x44d790-base,as:Int32.self))
                    _ = try OriginalBitmapDrawing.draw(request,bitmap:bitmap,observeRead:{ read in var e=OriginalFrontScreenEvent("read");e.read=read;try event(e,&buffer) },observeClip:{ clip in var e=OriginalFrontScreenEvent("clip");e.clip=clip;try event(e,&buffer) },perform:{ blit in var e=OriginalFrontScreenEvent("blit");e.blit=blit;try event(e,&buffer);return -1 })
                },observe:event,afterScreen:{ end,state,owned,scratch,text,buffer in
                    let point=item.points.first { $0.kind == "screenReturned" }
                    let records=point?.records ?? item.after
                    let expected=try Dictionary(uniqueKeysWithValues:records.map { ($0.address,try r.record($0)) })
                    try compare(state,try XCTUnwrap(expected[UInt32(base)]),item.spec.label+" screen globals")
                    for record in records where record.live != nil && record.address < 0x2c000000 {
                        let allocation=try XCTUnwrap(owned.allocations[record.address]);XCTAssertEqual(allocation.live,record.live);try compare(allocation.storage,try r.record(record),"screen resources")
                    }
                    let stack=try XCTUnwrap(expected[c.stackAddress]),start=Int(try XCTUnwrap(item.screenSP)-0x718+0x10-c.stackAddress)
                    let current=try screenLocalWrites(item,Int(c.stackAddress)+start)
                    XCTAssertEqual(scratch.defined,current,item.spec.label+" current screen writes")
                    for i in current.indices {
                        if current[i] {
                            XCTAssertTrue(stack.defined[start+i]);XCTAssertEqual(scratch.bytes[i],stack.bytes[start+i])
                        } else { XCTAssertEqual(scratch.bytes[i],0,"Private prior helper bytes imported") }
                    }
                    XCTAssertEqual(text.retainedDC,try XCTUnwrap(expected[c.libraryAddress]).integer(at:0x306e,as:UInt32.self))
                    XCTAssertEqual(eventIndex,point?.eventCount ?? item.events.count)
                    if failure == "screen" { XCTAssertTrue(buffer.front.contains { $0.kind == "free" });throw Stop.injected }
                },checkpoint:{ name,scene,state,buffer in
                    let point=try XCTUnwrap(item.points.first { $0.kind == name });XCTAssertEqual(eventIndex,point.eventCount)
                    let expected=try XCTUnwrap(point.records.first { $0.address == UInt32(base) });try compare(state,try r.record(expected),name+" globals");XCTAssertEqual(scene,initialWorld)
                    if failure == "beforeReturn" && name == "matchBeforeReturn" { throw Stop.injected }
                })
            XCTAssertNil(failure);XCTAssertEqual(end.rawValue,item.end);XCTAssertEqual(eventIndex,item.events.count)
            XCTAssertEqual(item.cw,0x23f)
            let expectedSP = end == .returned ? c.entrySP+8 : try XCTUnwrap(item.screenSP)-0x718
            XCTAssertEqual(item.endSP,expectedSP)
            try compare(globals,try XCTUnwrap(after[UInt32(base)]),item.spec.label+" globals")
            try compare(memory.replayPointers,try XCTUnwrap(after[0x4588a8]),item.spec.label+" replay pointers")
            for record in item.after where record.live != nil && record.address < 0x2c000000 {
                let allocation=try XCTUnwrap(memory.allocations[record.address]);XCTAssertEqual(allocation.live,record.live)
                try compare(allocation.storage,try r.record(record),item.spec.label+" retained allocation")
            }
            for address in [c.worldAddress]+item.actorAddresses { XCTAssertEqual(before[address],after[address],"Read-only World/Actor") }
            XCTAssertEqual(world,initialWorld)
            try compareMusic(item.startup.musicAllocations,music);try a.compare(a.c.records,resources.bitmaps,committed.graphics)
            XCTAssertEqual(committed.graphics.imagesDeleted,Dictionary(uniqueKeysWithValues:a.c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
            XCTAssertEqual(committed.graphics.surfacesReleased,Dictionary(uniqueKeysWithValues:a.c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
            XCTAssertEqual(committed.graphics.surfaceDescriptions,Dictionary(uniqueKeysWithValues:a.c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
            XCTAssertEqual(committed.graphics.dcs,Dictionary(uniqueKeysWithValues:a.c.dcs.map { (UInt32($0.key)!,$0.value) }))
            XCTAssertEqual(library.retainedDC,try XCTUnwrap(after[c.libraryAddress]).integer(at:0x306e,as:UInt32.self))
            XCTAssertEqual(committed.front.count,item.events.count)
        } catch OriginalCharacterMenuStartupError.nullSpark {
            XCTAssertNil(failure);XCTAssertEqual(item.end,"nullSpark");XCTAssertEqual(eventIndex,item.events.count)
            XCTAssertEqual(globals,initialGlobals);XCTAssertEqual(memory.allocations,initialMemory.allocations);XCTAssertEqual(memory.replayPointers,initialMemory.replayPointers)
            XCTAssertEqual(local,initialLocal);XCTAssertEqual(library,initialLibrary);XCTAssertEqual(committed,Environment())
            XCTAssertEqual(world,initialWorld);XCTAssertTrue(music.allocations.isEmpty);XCTAssertTrue(resources.bitmaps.isEmpty)
        } catch let error as OriginalMenuPanelDrawingError {
            XCTAssertNil(failure);XCTAssertEqual(item.end,error == .zeroTimerRange ? "zeroTimerRange" : "noSelectableRow")
            XCTAssertEqual(eventIndex,item.events.count)
            XCTAssertEqual(globals,initialGlobals);XCTAssertEqual(memory.allocations,initialMemory.allocations);XCTAssertEqual(memory.replayPointers,initialMemory.replayPointers)
            XCTAssertEqual(local,initialLocal);XCTAssertEqual(library,initialLibrary);XCTAssertEqual(committed,Environment())
            XCTAssertEqual(world,initialWorld);XCTAssertTrue(music.allocations.isEmpty);XCTAssertTrue(resources.bitmaps.isEmpty)
        } catch let error as Stop {
            guard error == .injected else { throw error };XCTAssertNotNil(failure)
            XCTAssertEqual(globals,initialGlobals);XCTAssertEqual(memory.allocations,initialMemory.allocations);XCTAssertEqual(memory.replayPointers,initialMemory.replayPointers)
            XCTAssertEqual(local,initialLocal);XCTAssertEqual(library,initialLibrary);XCTAssertEqual(committed,Environment())
            XCTAssertEqual(world,initialWorld);XCTAssertTrue(music.allocations.isEmpty);XCTAssertTrue(resources.bitmaps.isEmpty)

        }
        return eventIndex
    }
    func testFreshMusicResourcesScreenAndActualReturns() throws {
        let r=try Resources();var retained=OriginalLibSurfaceText(),events=0
        for item in r.corpus.cases {
            if item.spec.chain == true { events += try run(item,r,&retained) }
            else { var library=OriginalLibSurfaceText();events += try run(item,r,&library) }
        }
        XCTAssertGreaterThan(events,3_000)
    }
    func testLateFreshMenuFailuresRollBackEveryOwner() throws {
        let r=try Resources()
        for (label,failure) in [("nominal","afterMusic"),("nominal","afterStartup"),("confirm-release","screen"),("network-overlay","network"),("volume-up","volume"),("nominal","present"),("panel-click","beforeReturn")] {
            let item=try XCTUnwrap(r.corpus.cases.first { $0.spec.label == label });var library=OriginalLibSurfaceText()
            _ = try run(item,r,&library,failure:failure)
        }
    }
}
