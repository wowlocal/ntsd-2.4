import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalBitmapSurfaceLoadingTests: XCTestCase {
    typealias API = OriginalBitmapSurfaceLoading
    typealias Parent = OriginalWinMainStartupTests
    typealias Loop = OriginalApplicationMessageLoopTests
    typealias Entry = OriginalApplicationDispatchEntryTests
    struct Spec: Decodable {
        let kind: String,path: String?,flags: UInt32?,width: UInt32?,height: UInt32?,format: Bool?,surface: Bool?,bitmap: Bool?,copy: [Int32]?,windowParam: UInt32?,nulls: [Int]?,results: [String:Int32]?
    }
    struct Snapshot: Decodable { let globals: String,output: String,result: UInt32 }
    struct Parents: Decodable { let parent: Parent.Case,loop: Loop.Case,entry: Entry.Case }
    struct Event: Decodable {
        let kind: String?,index: Int?,address: UInt32?,count: UInt32?,key: String?,request: API.Request?,response: API.Response?,globals: String?
    }
    struct Allocation: Decodable { let address: UInt32,backing: String? }
    struct Record: Decodable { let address: UInt32,bytes: String,mask: String }
    struct Store: Decodable { let pc: UInt32?,address: Int,bytes: String,eventIndex: Int }
    struct Image: Decodable { let deleted: Bool }
    struct Surface: Decodable { let description: [UInt8],released: Bool }
    struct Case: Decodable {
        let spec: Spec,parents: Parents?,before: Snapshot,after: Snapshot,events: [Event],writes: [Store],allocations: [Allocation],records: [Record],images: [String:Image],surfaces: [String:Surface],dcs: [String:Bool],end: String,nullSlot: Int?
    }
    struct Asset: Decodable { let kind: String,raw: String }
    struct Corpus: Decodable { let exeSHA256: String,cases: [Case],blobs: [String:Loop.Blob],assets: [String:Asset] }
    final class Resources {
        let c: Corpus,rawCases: [[String:Any]]
        var cache: [String:[UInt8]] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_BITMAP_SURFACE_LOADING"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-bitmap-surface-loading",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:64_000_000)
            c = try JSONDecoder().decode(Corpus.self,from:data)
            rawCases = try XCTUnwrap((JSONSerialization.jsonObject(with:data) as? [String:Any])?["cases"] as? [[String:Any]])
            XCTAssertEqual(c.cases.count,69);XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let z = try XCTUnwrap(c.blobs[key]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),key);cache[key] = b;return b
        }
    }
    struct Graphics: Equatable {
        var dimensions: [UInt32] = [0x5a5a5a5a,0x5a5a5a5a],log: [String] = []
        var images: [UInt32:Bool] = [:],surfaces: [UInt32:Bool] = [:],dcs: [UInt32:Bool] = [:]
        var descriptions: [UInt32:[UInt8]] = [:]
    }
    enum Stop: Error { case required,late }
    final class Adapter {
        let c: Case,r: Resources,fail: String?
        var index = 0,writeIndex = 0,allocationIndex = 0,opaque = 0
        var shadow: [UInt8],metadataWrites: [Store],nextWrapper: UInt32
        init(_ c: Case,_ r: Resources,initial: [UInt8],nextWrapper: UInt32 = 0,fail: String? = nil) {
            self.c = c;self.r = r;self.shadow = initial;self.nextWrapper = nextWrapper;self.fail = fail
            metadataWrites = c.writes.filter { w in
                guard let pc = w.pc,0x424784 <= pc && pc < 0x427089 else { return false }
                return (0x44d000 <= w.address && w.address < 0x4593a8) || c.records.contains { Int($0.address) <= w.address && w.address < Int($0.address)+0x1f50 }
            }
        }
        func perform(_ q: API.Request,_ g: inout Graphics) throws -> API.Response {
            guard index < c.events.count else { XCTFail("Extra bitmap API \(q.kind)");throw Stop.late }
            let e = c.events[index];index += 1;let expected = try XCTUnwrap(e.request),response = try XCTUnwrap(e.response),key = try XCTUnwrap(e.key)
            XCTAssertEqual(q.kind,expected.kind,key);XCTAssertEqual(q.words,expected.words,key);XCTAssertEqual(q.strings,expected.strings,key);XCTAssertEqual(q.defined,expected.defined,key)
            if let mask = q.defined {
                let a = try XCTUnwrap(q.bytes),b = try XCTUnwrap(expected.bytes);XCTAssertEqual(a.count,b.count)
                for i in mask.indices {
                    if mask[i] { XCTAssertEqual(a[i],b[i],key+" owned byte \(i)") }
                    else { opaque += 1;XCTAssertEqual(a[i],0,"Unknown private stack was imported") }
                }
            }
            XCTAssertEqual(shadow,try r.blob(XCTUnwrap(e.globals)),key+" full globals")
            g.log.append(key)
            switch q.kind {
            case "image":if response.result != 0 { g.images[UInt32(bitPattern:response.result)] = false }
            case "createSurface":if let output = response.output { g.surfaces[output] = false;g.descriptions[output] = q.bytes }
            case "release":g.surfaces[q.words[0]] = true
            case "createDC":g.dcs[UInt32(bitPattern:response.result)] = false
            case "deleteDC":g.dcs[q.words[0]] = true // Request observed; no Windows destruction claim.
            case "deleteObject":g.images[q.words[0]] = response.result != 0
            default:break
            }
            if fail == key { throw Stop.late }
            return response
        }
        func allocate(_ i: Int) throws -> OriginalInterfaceAllocation {
            let e = c.events[index];index += 1;XCTAssertEqual(e.kind,"allocate");XCTAssertEqual(e.index,i);XCTAssertEqual(e.count,0x1f50)
            let token: UInt32 = c.spec.nulls?.contains(i) == true ? 0 : nextWrapper
            if token != 0 { nextWrapper += 0x2000 }
            XCTAssertEqual(token,e.address);XCTAssertEqual(token,c.allocations[allocationIndex].address);allocationIndex += 1
            let backing = token == 0 ? [] : [UInt8](repeating:0xa5,count:0x1f50)
            if let h = c.allocations[i].backing { XCTAssertEqual(backing,try r.blob(h)) }
            return .init(address:token,backing:backing)
        }
        func store(_ address: Int,_ bytes: [UInt8]) {
            let w = metadataWrites[writeIndex];writeIndex += 1;XCTAssertEqual(address,w.address);XCTAssertEqual(bytes,Parent.hex(w.bytes));XCTAssertEqual(w.eventIndex,index)
            if 0x44d000 <= address && address < 0x4593a8 { shadow.replaceSubrange(address-0x44d000..<address-0x44d000+bytes.count,with:bytes) }
        }
        func complete(_ g: Graphics,_ front: OriginalFrontMenuResources? = nil) throws {
            XCTAssertEqual(index,c.events.count);XCTAssertEqual(writeIndex,metadataWrites.count);XCTAssertEqual(shadow,try r.blob(c.after.globals))
            XCTAssertEqual(g.images,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
            XCTAssertEqual(g.surfaces,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
            XCTAssertEqual(g.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
            XCTAssertEqual(g.descriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
            if let front {
                XCTAssertEqual(allocationIndex,c.allocations.count);XCTAssertEqual(front.bitmaps.count,c.records.count)
                for record in c.records {
                    let bitmap = try XCTUnwrap(front.bitmaps[record.address]);var b = try r.blob(record.bytes)
                    let surface = b.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
                    if surface != 0 { XCTAssertNotNil(g.surfaces[surface]) }
                    b.replaceSubrange(0..<4,with:[surface == 0 ? 0 : 1,0,0,0])
                    XCTAssertEqual(bitmap.storage.bytes,b,"wrapper \(record.address)")
                    XCTAssertEqual(bitmap.storage.defined,try r.blob(record.mask).map { $0 != 0 })
                }
            }
        }
    }
    func testWholeLoaderAndCopyAtOwnedPlatformFields() throws {
        let r = try Resources();var matched = 0,rejected = 0
        for c in r.c.cases where c.spec.kind != "own" {
            let a = try Adapter(c,r,initial:r.blob(c.before.globals));var g = Graphics()
            if c.spec.kind == "copy" {
                // Declared direct-call objects derive their descriptor from the
                // original DIB input, never the expected surface after-state.
                let asset = try XCTUnwrap(r.c.assets[c.spec.path ?? "MENU_CLIP"]),raw = try r.blob(asset.raw),offset = asset.kind == "file" ? 14 : 0
                func word(_ at: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(raw[offset+at+$1]) << ($1*8) } }
                let height = UInt32(abs(Int64(Int32(bitPattern:word(8)))))
                var desc = [UInt8](repeating:0,count:108)
                for (i,v) in [UInt32(108),7,height,word(4)].enumerated() {
                    desc.replaceSubrange(i*4..<i*4+4,with:(0..<4).map { UInt8(truncatingIfNeeded:v >> ($0*8)) })
                }
                g.images[0x34000010] = false;g.surfaces[0x32001000] = false;g.descriptions[0x32001000] = desc
            }
            let before = g
            do {
                let result: UInt32
                if c.spec.kind == "loader" {
                    result = try API.load(path:Array((c.spec.path ?? "MENU_CLIP").utf8),device:0x32001000,flags:c.spec.flags ?? 0x40,width:c.spec.width ?? 0,height:c.spec.height ?? 0,pixelFormat:c.spec.format == true ? [32,0x40,0,32,0xff0000,0xff00,0xff,0] : nil,context:&g,dimensions:{ i,v,c in c.dimensions[i] = v },perform:a.perform)
                } else {
                    let rect = (c.spec.copy ?? [0,0,0,0]).map(UInt32.init(bitPattern:))
                    result = UInt32(bitPattern:try API.copy(surface:c.spec.surface == false ? 0 : 0x32001000,bitmap:c.spec.bitmap == false ? 0 : 0x34000010,x:rect[0],y:rect[1],width:rect[2],height:rect[3],context:&g,perform:a.perform))
                }
                XCTAssertEqual(result,c.after.result);try a.complete(g)
                let output = g.dimensions.flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded:v >> ($0*8)) } }
                XCTAssertEqual(output,try r.blob(c.after.output));matched += 1
            } catch let boundary as API.Boundary {
                XCTAssertEqual(c.spec.kind,"loader")
                XCTAssertTrue(c.spec.results?["getObject#1"] == 0 || c.spec.results?["description#1"] == -1)
                guard case .unknownField = boundary else { throw boundary }
                XCTAssertEqual(g,before);rejected += 1
            }
        }
        XCTAssertEqual(matched,59);XCTAssertEqual(rejected,2)
        print("BITMAP SURFACE 59 whole loader/copy matches;2 original returns require unknown private backing and are explicitly rejected with rollback")
    }
    struct OwnContext {
        var base: Loop.Context,front = OriginalFrontMenuResources(),graphics = Graphics()
        var settings: OriginalSettingsLoading.StartupResult? = nil, gameEntry: OriginalApplicationDispatchEntry.GameEntry? = nil
        var earlyScreen = OriginalFrontScreenPrelude()
        var outerAndWorldBytes: [UInt8] = []
    }
    func own(_ index: Int,_ r: Resources,_ er: Entry.Resources,fail: String? = nil,
             continuation: ((inout OwnContext) throws -> Void)? = nil) throws {
        let c = r.c.cases[index],parents = try XCTUnwrap(c.parents),parent = parents.parent,lc = parents.loop
        var globals = try OriginalStateRecord(bytes:r.blob(parent.initialGlobals),defined:[Bool](repeating:true,count:0xb440)),startup = OriginalWinMainStartup()
        let rawParent = try XCTUnwrap((r.rawCases[index]["parents"] as? [String:Any])?["parent"] as? [String:Any])
        let sources = Dictionary(uniqueKeysWithValues:try XCTUnwrap(parent.input).loads.map { (String(decoding:$0.path,as:UTF8.self),$0.file) })
        let initial = try Parent.Adapter(parent,rawParent,sources:sources,blob:r.blob,initial:globals.bytes)
        try startup.run(instance:0x400000,show:10,globals:&globals,platform:initial,store:initial.store);try initial.complete(startup,globals)
        let outer = try OriginalStateRecord(bytes:r.blob(lc.initialOuter),defined:[Bool](repeating:true,count:0x854)),local = try OriginalStateRecord(bytes:Array(outer.bytes[..<0x140]),defined:Array(outer.defined[..<0x140])),pointers = try OriginalStateRecord(bytes:Array(outer.bytes[0x468..<0x470]),defined:Array(outer.defined[0x468..<0x470]))
        var state = OwnContext(base:.init(globals:globals,outer:outer,local:local,memory:.init(replayPointers:pointers))),loop = try OriginalApplicationMessageLoop(baseline:startup.random.state,counter:0)
        let p = Loop.Adapter(lc,state.base,blob:r.blob)
        let firstWrapper = (startup.panel.panel.records.map(\.address).max() ?? 0x2800e020)+0x2000
        var reached = false
        for (i,step) in lc.iterations.enumerated() {
            p.stepIndex = i;try p.snapshot(state.base,loop,step.before);let before = state,previous = loop
            do {
                _ = try loop.step(context:&state,speed:{ try $0.base.globals.integer(at:0x44d02c-0x44d000,as:Int32.self) },target:{ try $0.base.globals.integer(at:0x451dac-0x44d000,as:UInt32.self) },perform:{ request,owned in
                    if request.kind != .gameDispatch { return try p.perform(request,&owned.base) }
                    XCTAssertNil(try p.next("gameDispatch",request.arguments,owned.base).response)
                    var bytes = owned.base.globals.bytes+[UInt8](repeating:0,count:0xc3a8-0xb440)
                    bytes.replaceSubrange(0xb440..<0xb440+0x854,with:owned.base.outerBytes(counter:previous.counter))
                    var full = try OriginalStateRecord(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count))
                    let ec = er.c.cases[c.spec.windowParam == 1 ? 1 : 0],entry = Entry.Stage(ec,er,bytes,fail:nil)
                    let game = try OriginalApplicationDispatchEntry.advance(incomingTarget:request.arguments[0],globals:&full,perform:entry.surface,store:entry.store)
                    owned.gameEntry = game
                    owned.outerAndWorldBytes = Array(full.bytes.dropFirst(0xb440))
                    let wo = Int(game.worldAddress)-0x44d000,world = try OriginalStateRecord(bytes:Array(full.bytes[wo..<wo+0x7d8]),defined:[Bool](repeating:true,count:0x7d8))
                    var fg = try OriginalStateRecord(bytes:Array(full.bytes[..<0xb440]),defined:Array(full.defined[..<0xb440])),front = owned.front,g = owned.graphics
                    var a: Adapter?,first = true
                    let result = try front.load(world:world,globals:&fg,allocate:{ n in
                        if first {
                            try entry.required();try entry.complete();first = false
                            a = Adapter(c,r,initial:entry.shadow,nextWrapper:firstWrapper,fail:fail)
                            XCTAssertEqual(entry.shadow,try r.blob(c.before.globals))
                        }
                        return try XCTUnwrap(a).allocate(n)
                    },source:{ _,_ in throw Stop.late },deviceResult:{ _ in throw Stop.late },constructBitmap:{ _,allocation,device,path in
                        try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:false,backing:allocation.backing,device:device,flags:0x40,context:&g,perform:XCTUnwrap(a).perform)
                    },observe:{ e in
                        if e.kind == .write {
                            let address = Int(e.arguments[0]+e.arguments[1]),value = e.arguments[3],bytes = (0..<Int(e.arguments[2])).map { UInt8(truncatingIfNeeded:value >> ($0*8)) }
                            if first { try entry.store(address,bytes) } else { try XCTUnwrap(a).store(address,bytes) }
                        }
                        if fail == "finalMetadata" && e.kind == .write && e.arguments[0] == firstWrapper+23*0x2000 && e.arguments[1] == 0x1b7c { throw Stop.late }
                    })
                    let complete = try XCTUnwrap(a);try complete.complete(g,front)
                    XCTAssertEqual(result.continuation.rawValue,c.end);XCTAssertEqual(result.nullBitmapSlot,c.nullSlot)
                    XCTAssertEqual(fg.bytes,Array(complete.shadow[..<0xb440]))
                    owned.front = front;owned.graphics = g;owned.base.globals = fg
                    if fail == "settings" { throw Stop.late }
                    try continuation?(&owned)
                    throw Stop.required
                },counterWritten:p.counter)
                try p.snapshot(state.base,loop,step.after)
            } catch {
                reached = true
                if fail == nil { guard case Stop.required = error else { throw error } }
                else { guard case Stop.late = error else { throw error } }
                XCTAssertEqual(step.end,"requiredDispatcher")
                XCTAssertEqual(state.base.globals,before.base.globals);XCTAssertEqual(state.base.outer,before.base.outer);XCTAssertEqual(state.base.local,before.base.local)
                XCTAssertEqual(state.base.memory.replayPointers,before.base.memory.replayPointers);XCTAssertEqual(state.base.memory.allocations,before.base.memory.allocations)
                XCTAssertEqual(state.front.bitmaps,before.front.bitmaps);XCTAssertEqual(state.graphics,before.graphics)
                XCTAssertEqual(state.settings,before.settings);XCTAssertEqual(state.gameEntry,before.gameEntry)
                XCTAssertEqual(state.earlyScreen.bitmaps,before.earlyScreen.bitmaps);XCTAssertEqual(state.earlyScreen.surfaces,before.earlyScreen.surfaces)
                XCTAssertEqual(state.earlyScreen.retainedOperation,before.earlyScreen.retainedOperation)
                XCTAssertEqual(state.outerAndWorldBytes,before.outerAndWorldBytes)
                XCTAssertEqual(loop.message,previous.message);XCTAssertEqual(loop.timer.baseline,previous.timer.baseline);XCTAssertEqual(loop.counter,previous.counter)
            }
        }
        XCTAssertTrue(reached);p.compareStores();XCTAssertEqual(p.index,lc.events.count);XCTAssertEqual(p.callbackIndex,1)
    }
    func testOwnFrontResourcesUseWholeImageAndCopyHelpers() throws {
        let r = try Resources(),er = try Entry.Resources()
        for i in r.c.cases.indices where r.c.cases[i].spec.kind == "own" { try own(i,r,er) }
        print("BITMAP SURFACE 8 own startup/dispatcher/front-resource continuations:7 settings boundaries,1 null metadata boundary; whole pending loop rollback")
    }
    func testLateResourceFailuresRetainCommittedStartupAndCallback() throws {
        let r = try Resources(),er = try Entry.Resources()
        for failure in ["module#1","createSurface#24","deleteObject#24","colorKey#24","finalMetadata","settings"] { try own(61,r,er,fail:failure) }
    }
}
