import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationDispatchEntryTests: XCTestCase {
    typealias Loop = OriginalApplicationMessageLoopTests
    typealias Parent = OriginalWinMainStartupTests
    struct Snapshot: Decodable { let globals: String,world: String }
    struct Surface: Decodable { let key: String,request: OriginalWindowInitialization.Request,response: OriginalWindowInitialization.Response,fullGlobals: String }
    struct Event: Decodable { let kind: String,event: Surface?,fullGlobals: String? }
    struct Required: Decodable { let count: UInt32,world: UInt32,target: UInt32 }
    struct WorldEntry: Decodable { let world: UInt32,target: UInt32,bytes: String }
    struct Spec: Decodable { let index: Int,windowParam: UInt32 }
    struct Case: Decodable {
        let parent: String,loop: String,spec: Spec,before: Snapshot,after: Snapshot,events: [Event],stores: [Loop.Store],mask: String,worldEntry: WorldEntry,required: Required
    }
    struct Corpus: Decodable {
        let exeSHA256: String,parents: [String:Parent.Case],loops: [String:Loop.Case],cases: [Case],blobs: [String:Loop.Blob]
    }
    final class Resources {
        let c: Corpus,parents: [String:[String:Any]]
        var cache: [String:[UInt8]] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_DISPATCH_ENTRY"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-dispatch-entry",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:32_000_000)
            c = try JSONDecoder().decode(Corpus.self,from:data)
            parents = try XCTUnwrap((JSONSerialization.jsonObject(with:data) as? [String:Any])?["parents"] as? [String:[String:Any]])
            XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c");XCTAssertEqual(c.cases.count,8)
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = cache[key] { return bytes }
            let b = try XCTUnwrap(c.blobs[key]),bytes = try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)),key);cache[key] = bytes;return bytes
        }
    }
    enum Stop: Error { case resourceRequired,late }
    final class Stage {
        let c: Case,r: Resources,fail: String?
        var shadow: [UInt8],mask = [UInt8](repeating:0,count:0xc3a8),event = 0,storeIndex = 0,opaqueBytes = 0
        init(_ c: Case,_ r: Resources,_ before: [UInt8],fail: String?) { self.c = c;self.r = r;self.shadow = before;self.fail = fail }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
            let w = c.stores[storeIndex];storeIndex += 1;XCTAssertEqual(w.address,address);XCTAssertEqual(Parent.hex(w.bytes),bytes);XCTAssertEqual(w.eventIndex,event)
            let o = address-0x44d000;shadow.replaceSubrange(o..<o+bytes.count,with:bytes);mask.replaceSubrange(o..<o+bytes.count,with:repeatElement(UInt8(1),count:bytes.count))
            if fail == "frontWrite" && address == 0x4511f8 { throw Stop.late }
        }
        func surface(_ request: OriginalWindowInitialization.Request,_ globals: OriginalStateRecord) throws -> OriginalWindowInitialization.Response {
            let item = c.events[event];event += 1;XCTAssertEqual(item.kind,"surface");let e = try XCTUnwrap(item.event)
            XCTAssertEqual(request.kind,e.request.kind);XCTAssertEqual(request.words,e.request.words);XCTAssertEqual(request.strings,e.request.strings)
            XCTAssertEqual(request.defined,e.request.defined);XCTAssertEqual(globals.bytes,shadow);XCTAssertEqual(globals.bytes,try r.blob(e.fullGlobals))
            if let defined = request.defined {
                let a = try XCTUnwrap(request.bytes),b = try XCTUnwrap(e.request.bytes);XCTAssertEqual(a.count,b.count)
                for i in defined.indices {
                    if defined[i] { XCTAssertEqual(a[i],b[i]) }
                    else { opaqueBytes += 1;XCTAssertEqual(a[i],0,"Private source stack backing was not imported") }
                }
            }
            if fail == e.key { throw Stop.late }
            return e.response
        }
        func required() throws {
            let e = c.events[event];event += 1;XCTAssertEqual(e.kind,"required");XCTAssertEqual(shadow,try r.blob(XCTUnwrap(e.fullGlobals)))
            XCTAssertEqual(c.required.count,0x1f50);XCTAssertEqual(c.required.world,0x458b00)
            if fail == "required" { throw Stop.late }
        }
        func complete() throws {
            XCTAssertEqual(event,c.events.count);XCTAssertEqual(storeIndex,c.stores.count)
            XCTAssertEqual(shadow,try r.blob(c.after.globals));XCTAssertEqual(mask,try r.blob(c.mask));XCTAssertEqual(opaqueBytes,212)
        }
    }
    @discardableResult
    func run(_ c: Case,_ r: Resources,fail: String? = nil) throws -> Bool {
        let parent = try XCTUnwrap(r.c.parents[c.parent]),lc = try XCTUnwrap(r.c.loops[c.loop])
        var globals = try OriginalStateRecord(bytes:r.blob(parent.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize)),startup = OriginalWinMainStartup()
        let sources = Dictionary(uniqueKeysWithValues:try XCTUnwrap(parent.input).loads.map { (String(decoding:$0.path,as:UTF8.self),$0.file) })
        let initial = try Parent.Adapter(parent,XCTUnwrap(r.parents[c.parent]),sources:sources,blob:r.blob,initial:globals.bytes)
        try startup.run(instance:0x400000,show:10,globals:&globals,platform:initial,store:initial.store);try initial.complete(startup,globals)
        let outer = try OriginalStateRecord(bytes:r.blob(lc.initialOuter),defined:[Bool](repeating:true,count:0x854))
        let local = try OriginalStateRecord(bytes:Array(outer.bytes[..<0x140]),defined:Array(outer.defined[..<0x140])),pointers = try OriginalStateRecord(bytes:Array(outer.bytes[0x468..<0x470]),defined:Array(outer.defined[0x468..<0x470]))
        var state = Loop.Context(globals:globals,outer:outer,local:local,memory:.init(replayPointers:pointers)),loop = try OriginalApplicationMessageLoop(baseline:startup.random.state,counter:0)
        let p = Loop.Adapter(lc,state,blob:r.blob);var stage: Stage?,reached = false
        for (i,step) in lc.iterations.enumerated() {
            p.stepIndex = i;try p.snapshot(state,loop,step.before);let before = state,previous = loop
            do {
                _ = try loop.step(context:&state,speed:{ try $0.globals.integer(at:0x44d02c-0x44d000,as:Int32.self) },target:{ try $0.globals.integer(at:0x451dac-0x44d000,as:UInt32.self) },perform:{ request,owned in
                    if request.kind != .gameDispatch { return try p.perform(request,&owned) }
                    let event = try p.next("gameDispatch",request.arguments,owned);XCTAssertNil(event.response)
                    XCTAssertEqual(request.arguments,[c.spec.windowParam == 1 ? 0 : 1])
                    // Outside the bounded globals is independently verified PE
                    // zero-fill, overlaid with this loop's own outer state.
                    var bytes = owned.globals.bytes+[UInt8](repeating:0,count:0xc3a8-0xb440)
                    bytes.replaceSubrange(0xb440..<0xb440+0x854,with:owned.outerBytes(counter:previous.counter))
                    var full = try OriginalStateRecord(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count))
                    XCTAssertEqual(full.bytes,try r.blob(c.before.globals))
                    let a = Stage(c,r,bytes,fail:fail);stage = a
                    let entry = try OriginalApplicationDispatchEntry.advance(incomingTarget:request.arguments[0],globals:&full,perform:a.surface,store:a.store)
                    XCTAssertEqual(entry.worldAddress,c.worldEntry.world);XCTAssertEqual(entry.target,c.worldEntry.target);XCTAssertEqual(entry.target,0x31003000)
                    let offset = Int(entry.worldAddress)-0x44d000
                    let world = try OriginalStateRecord(bytes:Array(full.bytes[offset..<offset+0x7d8]),defined:Array(full.defined[offset..<offset+0x7d8]))
                    XCTAssertEqual(world.bytes,[UInt8](repeating:0,count:0x7d8));XCTAssertEqual(world.bytes,try r.blob(c.worldEntry.bytes))
                    var frontGlobals = try OriginalStateRecord(bytes:Array(full.bytes[..<0xb440]),defined:Array(full.defined[..<0xb440])),front = OriginalFrontMenuResources(),allocationObserved = false
                    _ = try front.load(world:world,globals:&frontGlobals,allocate:{ index in
                        XCTAssertEqual(index,0);XCTAssertTrue(allocationObserved);try a.required();throw Stop.resourceRequired
                    },source:{ _,_ in XCTFail("Resource allocation has not returned");throw Stop.late },deviceResult:{ _ in XCTFail("Resource allocation has not returned");throw Stop.late },observe:{ event in
                        switch event.kind {
                        case .write:
                            XCTAssertEqual(event.arguments[0],0);XCTAssertEqual(event.arguments[2],4)
                            let value = event.arguments[3];try a.store(Int(event.arguments[1]),(0..<4).map { UInt8(truncatingIfNeeded:value >> ($0*8)) })
                        case .allocate:XCTAssertEqual(event.arguments,[0x1f50]);allocationObserved = true
                        default:XCTFail("Unexpected pre-allocation event")
                        }
                    })
                    XCTFail("Required allocation returned");throw Stop.late
                },counterWritten:p.counter)
                XCTAssertEqual(step.end,"continued");try p.snapshot(state,loop,step.after)
            } catch {
                reached = true;XCTAssertEqual(step.end,"requiredDispatcher")
                if fail == nil { guard case Stop.resourceRequired = error else { throw error };try XCTUnwrap(stage).complete() }
                else { guard case Stop.late = error else { throw error } }
                XCTAssertEqual(state.globals,before.globals);XCTAssertEqual(state.outer,before.outer);XCTAssertEqual(state.local,before.local)
                XCTAssertEqual(state.memory.replayPointers,before.memory.replayPointers);XCTAssertEqual(state.memory.allocations,before.memory.allocations)
                XCTAssertEqual(loop.message,previous.message);XCTAssertEqual(loop.timer.baseline,previous.timer.baseline);XCTAssertEqual(loop.counter,previous.counter)
            }
        }
        p.compareStores();XCTAssertEqual(p.index,lc.events.count);XCTAssertEqual(p.callbackIndex,1)
        XCTAssertTrue(reached);return reached
    }
    func testOwnDispatcherToRequiredBitmapAllocation() throws {
        let r = try Resources();for c in r.c.cases { try run(c,r) }
        print("APPLICATION DISPATCH ENTRY 8 own startup/loop/dispatcher/staticWorld chains to required allocation;1696 opaque request bytes remain unknown")
    }
    func testLateFailuresRetainStartupAndCommittedWindowCallback() throws {
        let r = try Resources(),c = r.c.cases[0]
        for failure in ["pixelFormat#1","blt#1","debug#1","blt#2","frontWrite","required"] { try run(c,r,fail:failure) }
    }
}
