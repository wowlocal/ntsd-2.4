import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationMessageLoopTests: XCTestCase {
    typealias Parent = OriginalWinMainStartupTests
    struct Blob: Decodable { let count: Int,deflate: String }
    struct Store: Decodable { let address: Int,bytes: String,eventIndex: Int }
    struct Request: Decodable { let kind: String,arguments: [UInt32],message: [UInt8]?,defined: [Bool]? }
    struct Event: Decodable { let request: Request,response: OriginalApplicationMessageLoop.Response?,globals: String,outer: String,baseline: UInt32 }
    struct Snapshot: Decodable { let globals: String,outer: String,message: String,messageMask: String,baseline: UInt32,counter: UInt32,eax: UInt32,sp: UInt32,registers: [UInt32],events: Int }
    struct Spec: Decodable { let label: String,requireDispatcher: Bool? }
    struct StepSpec: Decodable { let bridge: Bool? }
    struct Iteration: Decodable { let spec: StepSpec,before: Snapshot,after: Snapshot,end: String }
    struct Callback: Decodable { let input: OriginalWindowInput.Message,result: UInt32,globals: String,outer: String }
    struct Case: Decodable {
        let spec: Spec,parent: String,initialOuter: String,stimulus: [Parent.Store],before: Snapshot,after: Snapshot
        let iterations: [Iteration],events: [Event],callbacks: [Callback],globalStores: [Store],outerStores: [Store],globalMask: String,outerMask: String,end: String,controlWord: UInt32
    }
    struct Corpus: Decodable { let exeSHA256: String,parents: [String:Parent.Case],cases: [Case],blobs: [String:Blob] }
    struct Context {
        var globals: OriginalStateRecord,outer: OriginalStateRecord,local: OriginalStateRecord,memory: OriginalMenuPresentationMemory
        func outerBytes(counter: UInt32) -> [UInt8] {
            var bytes = outer.bytes;bytes.replaceSubrange(0..<0x140,with:local.bytes);bytes.replaceSubrange(0x468..<0x470,with:memory.replayPointers.bytes)
            bytes.replaceSubrange(0x140..<0x144,with:(0..<4).map { UInt8(truncatingIfNeeded:counter >> ($0*8)) });return bytes
        }
    }
    enum Stop: Error { case required,late }
    func read() throws -> (Corpus,[String:[String:Any]]) {
        let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_MESSAGE_LOOP"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-message-loop",withExtension:"json",subdirectory:"Fixtures"))
        let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:100_000_000),raw = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        return (try JSONDecoder().decode(Corpus.self,from:data),try XCTUnwrap(raw["parents"] as? [String:[String:Any]]))
    }
    final class Adapter {
        let c: Case,blob: (String) throws -> [UInt8]
        var fail: String?
        var index = 0,globalIndex = 0,outerIndex = 0,callbackIndex = 0,stepIndex = 0
        var shadow: [UInt8],outerShadow: [UInt8],expected: [UInt8],outerExpected: [UInt8],globalMask: [UInt8],outerMask: [UInt8]
        init(_ c: Case,_ initial: Context,blob: @escaping (String) throws -> [UInt8],fail: String? = nil) {
            self.c = c;self.blob = blob;self.fail = fail;shadow = initial.globals.bytes;expected = shadow;outerShadow = initial.outer.bytes;outerExpected = outerShadow
            globalMask = [UInt8](repeating:0,count:shadow.count);outerMask = [UInt8](repeating:0,count:outerShadow.count)
        }
        func store(_ address: Int,_ bytes: [UInt8]) {
            if address < 0x458440 {
                let o = address-OriginalMatchPreparation.globalBase;shadow.replaceSubrange(o..<o+bytes.count,with:bytes);globalMask.replaceSubrange(o..<o+bytes.count,with:repeatElement(UInt8(1),count:bytes.count))
            } else {
                let o = address-0x458440;outerShadow.replaceSubrange(o..<o+bytes.count,with:bytes);outerMask.replaceSubrange(o..<o+bytes.count,with:repeatElement(UInt8(1),count:bytes.count))
            }
        }
        func counter(_ value: UInt32) throws {
            store(0x458580,(0..<4).map { UInt8(truncatingIfNeeded:value >> ($0*8)) })
            if fail == "counter" { throw Stop.late }
        }
        func compareStores() {
            while globalIndex < c.globalStores.count && c.globalStores[globalIndex].eventIndex <= index {
                let w = c.globalStores[globalIndex];globalIndex += 1;let b = Parent.hex(w.bytes),o = w.address-OriginalMatchPreparation.globalBase;expected.replaceSubrange(o..<o+b.count,with:b)
            }
            while outerIndex < c.outerStores.count && c.outerStores[outerIndex].eventIndex <= index {
                let w = c.outerStores[outerIndex];outerIndex += 1;let b = Parent.hex(w.bytes),o = w.address-0x458440;outerExpected.replaceSubrange(o..<o+b.count,with:b)
            }
            XCTAssertTrue(shadow == expected,c.spec.label+" global order at \(index)");XCTAssertTrue(outerShadow == outerExpected,c.spec.label+" outer order at \(index)")
        }
        func next(_ kind: String,_ args: [UInt32],_ state: Context,message: [UInt8]? = nil,defined: [Bool]? = nil) throws -> Event {
            guard index < c.events.count else { XCTFail("Extra loop event \(kind)");throw Stop.late }
            compareStores();let e = c.events[index];index += 1
            XCTAssertEqual(kind,e.request.kind,c.spec.label);XCTAssertEqual(args,e.request.arguments,c.spec.label)
            XCTAssertEqual(defined,e.request.defined);XCTAssertEqual(message?.count,e.request.message?.count)
            if let mask = defined { let a = try XCTUnwrap(message),b = try XCTUnwrap(e.request.message);XCTAssertTrue(mask.indices.allSatisfy { !mask[$0] || a[$0] == b[$0] },c.spec.label+" owned MSG request") }
            XCTAssertTrue(state.globals.bytes == (try blob(e.globals)),c.spec.label+" request state");XCTAssertTrue(outerShadow == (try blob(e.outer)),c.spec.label+" request outer state")
            return e
        }
        func perform(_ request: OriginalApplicationMessageLoop.Request,_ state: inout Context) throws -> OriginalApplicationMessageLoop.Response {
            let e = try next(request.kind.rawValue,request.arguments,state,message:request.message,defined:request.defined)
            if request.kind == .gameDispatch && c.spec.requireDispatcher == true { XCTAssertNil(e.response);throw Stop.required }
            let response = try XCTUnwrap(e.response)
            if request.kind == .dispatchMessage && c.iterations[stepIndex].spec.bridge == true {
                let msg = try OriginalStateRecord(bytes:XCTUnwrap(request.message),defined:XCTUnwrap(request.defined))
                let input = try OriginalWindowInput.Message(window:msg.integer(at:0,as:UInt32.self),message:msg.integer(at:4,as:UInt32.self),wParam:msg.integer(at:8,as:UInt32.self),lParam:msg.integer(at:12,as:UInt32.self))
                let cb = c.callbacks[callbackIndex];callbackIndex += 1;XCTAssertEqual(input,cb.input)
                let returned: Int32
                // The callback owns a value-semantic copy and commits its fields
                // only inside the encompassing loop transaction.
                var g = state.globals,l = state.local,m = state.memory
                let inputs: Set<UInt32> = [0x100,0x101,0x200,0x201,0x202,0x203,0x204,0x205,0x3a0,0x3a1,0x3b5,0x3b6,0x3b7,0x3b8]
                if inputs.contains(input.message) {
                    returned = try OriginalWindowInput.receive(input,globals:&g,local:&l,memory:&m,request:{ r in
                        var live = state;live.globals = try .init(bytes:self.shadow,defined:state.globals.defined)
                        let event = try self.next(r.kind.rawValue,r.arguments,live)
                        XCTAssertTrue(r.strings.isEmpty);return try XCTUnwrap(event.response).result
                    },store:store)
                } else {
                    returned = try OriginalWindowLifecycle.receive(input,globals:&g,memory:&m,backing:{ _,count in [UInt8](repeating:0,count:count) },perform:{ r in
                        var live = state;live.globals = try .init(bytes:self.shadow,defined:state.globals.defined)
                        let event = try self.next(r.kind,r.kind == "debug" ? r.strings.flatMap { $0.map(UInt32.init) } : r.words,live)
                        return .init(result:try XCTUnwrap(event.response).result)
                    },store:store)
                }
                state.globals = g;state.local = l;state.memory = m
                XCTAssertEqual(UInt32(bitPattern:returned),cb.result);XCTAssertEqual(returned,response.result)
                XCTAssertTrue(g.bytes == (try blob(cb.globals)));XCTAssertTrue(outerShadow == (try blob(cb.outer)))
                if fail == "callback" { throw Stop.late }
            }
            if fail == request.kind.rawValue { throw Stop.late }
            return response
        }
        func snapshot(_ state: Context,_ loop: OriginalApplicationMessageLoop,_ s: Snapshot) throws {
            XCTAssertTrue(state.globals.bytes == (try blob(s.globals)),c.spec.label+" globals")
            XCTAssertTrue(state.outerBytes(counter:loop.counter) == (try blob(s.outer)),c.spec.label+" outer")
            // At the real epilogue ESI has been restored to the saved caller value.
            // The semantic timer retains the last observed pre-epilogue ESI.
            XCTAssertEqual(loop.timer.baseline,s.sp == 0x1000f04c ? c.events[s.events-1].baseline : s.baseline);XCTAssertEqual(loop.counter,s.counter);XCTAssertEqual(index,s.events)
            let bytes = try blob(s.message),mask = try blob(s.messageMask);XCTAssertEqual(loop.message.defined,mask.map { $0 == 1 })
            XCTAssertTrue(mask.indices.allSatisfy { mask[$0] == 0 || loop.message.bytes[$0] == bytes[$0] },c.spec.label+" MSG values")
        }
    }
    func testWholeLoopAndOwnStartupCallbacks() throws {
        let (corpus,rawParents) = try read();var cache: [String:[UInt8]] = [:]
        func blob(_ h: String) throws -> [UInt8] { if let b = cache[h] { return b };let p = try XCTUnwrap(corpus.blobs[h]),b = try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:10_000_000);XCTAssertEqual(MatchPreparationReference.digest(Data(b)),h);cache[h] = b;return b }
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        var returned = 0,required = 0,iterations = 0,callbacks = 0,events = 0
        for c in corpus.cases {
            let parent = try XCTUnwrap(corpus.parents[c.parent])
            var globals = try OriginalStateRecord(bytes:blob(parent.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize)),startup = OriginalWinMainStartup()
            let sources = Dictionary(uniqueKeysWithValues:try XCTUnwrap(parent.input).loads.map { (String(decoding:$0.path,as:UTF8.self),$0.file) })
            let initialAdapter = try Parent.Adapter(parent,XCTUnwrap(rawParents[c.parent]),sources:sources,blob:blob,initial:globals.bytes)
            try startup.run(instance:0x400000,show:10,globals:&globals,platform:initialAdapter,store:initialAdapter.store);try initialAdapter.complete(startup,globals)
            var outer = try OriginalStateRecord(bytes:blob(c.initialOuter),defined:[Bool](repeating:true,count:0x854))
            // The independent verifier binds this earlier outer region to PE
            // bytes; no expected later counter/input state initializes Native.
            for w in c.stimulus {
                for (i,b) in Parent.hex(w.bytes).enumerated() {
                    if w.address < 0x458440 { try globals.write(b,at:w.address-OriginalMatchPreparation.globalBase+i) }
                    else { try outer.write(b,at:w.address-0x458440+i) }
                }
            }
            let local = try OriginalStateRecord(bytes:Array(outer.bytes[..<0x140]),defined:Array(outer.defined[..<0x140])),pointers = try OriginalStateRecord(bytes:Array(outer.bytes[0x468..<0x470]),defined:Array(outer.defined[0x468..<0x470]))
            var state = Context(globals:globals,outer:outer,local:local,memory:.init(replayPointers:pointers)),loop = try OriginalApplicationMessageLoop(baseline:startup.random.state,counter:outer.integer(at:0x140,as:UInt32.self))
            let p = Adapter(c,state,blob:blob);try p.snapshot(state,loop,c.before)
            for (i,step) in c.iterations.enumerated() {
                p.stepIndex = i;try p.snapshot(state,loop,step.before);let before = state,previous = loop
                do {
                    let result = try loop.step(context:&state,speed:{ try $0.globals.integer(at:0x44d02c-OriginalMatchPreparation.globalBase,as:Int32.self) },target:{ try $0.globals.integer(at:0x451dac-OriginalMatchPreparation.globalBase,as:UInt32.self) },perform:p.perform,counterWritten:p.counter)
                    try p.snapshot(state,loop,step.after)
                    if case .quit(let value) = result { XCTAssertEqual(step.end,"quit");XCTAssertEqual(value,step.after.eax);XCTAssertEqual(step.after.sp,0x1000f04c);returned += 1 }
                    else { XCTAssertEqual(step.end,"continued");XCTAssertEqual(step.after.sp,0x1000effc) }
                    iterations += 1
                } catch Stop.required {
                    XCTAssertEqual(step.end,"requiredDispatcher");XCTAssertEqual(c.end,"requiredDispatcher");required += 1
                    XCTAssertEqual(loop.counter,previous.counter);XCTAssertEqual(loop.timer.baseline,previous.timer.baseline);XCTAssertEqual(loop.message,previous.message)
                    XCTAssertEqual(state.globals,before.globals);XCTAssertEqual(state.local,before.local);XCTAssertEqual(state.memory.replayPointers,before.memory.replayPointers)
                }
            }
            p.compareStores();XCTAssertEqual(p.index,c.events.count);XCTAssertEqual(p.callbackIndex,c.callbacks.count);XCTAssertEqual(p.globalIndex,c.globalStores.count);XCTAssertEqual(p.outerIndex,c.outerStores.count)
            XCTAssertTrue(p.shadow == (try blob(c.after.globals)));XCTAssertTrue(p.outerShadow == (try blob(c.after.outer)))
            XCTAssertTrue(p.globalMask == (try blob(c.globalMask)));XCTAssertTrue(p.outerMask == (try blob(c.outerMask)));XCTAssertEqual(c.controlWord,0x37f)
            callbacks += p.callbackIndex;events += p.index
        }
        XCTAssertEqual(corpus.cases.count,64);XCTAssertEqual(returned,63);XCTAssertEqual(required,1)
        print("ApplicationMessageLoop:",returned,"loop returns at declared platform/body boundaries",required,"own required-dispatch stop",iterations,"completed iterations",callbacks,"actual callback comparisons",events,"ordered events")
    }
    func testOwnKeyReleaseCallbackFailureRetainsCommittedPress() throws {
        let (corpus,raw) = try read(),c = try XCTUnwrap(corpus.cases.first { $0.spec.label == "own-input-and-quit" }),parent = try XCTUnwrap(corpus.parents[c.parent])
        func blob(_ h: String) throws -> [UInt8] { let p = try XCTUnwrap(corpus.blobs[h]);return try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:10_000_000) }
        var globals = try OriginalStateRecord(bytes:blob(parent.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize)),startup = OriginalWinMainStartup()
        let sources = Dictionary(uniqueKeysWithValues:try XCTUnwrap(parent.input).loads.map { (String(decoding:$0.path,as:UTF8.self),$0.file) })
        let initial = try Parent.Adapter(parent,XCTUnwrap(raw[c.parent]),sources:sources,blob:blob,initial:globals.bytes)
        try startup.run(instance:0x400000,show:10,globals:&globals,platform:initial,store:initial.store);try initial.complete(startup,globals)
        let outer = try OriginalStateRecord(bytes:blob(c.initialOuter),defined:[Bool](repeating:true,count:0x854))
        let local = try OriginalStateRecord(bytes:Array(outer.bytes[..<0x140]),defined:Array(outer.defined[..<0x140])),pointers = try OriginalStateRecord(bytes:Array(outer.bytes[0x468..<0x470]),defined:Array(outer.defined[0x468..<0x470]))
        var state = Context(globals:globals,outer:outer,local:local,memory:.init(replayPointers:pointers)),loop = try OriginalApplicationMessageLoop(baseline:startup.random.state,counter:0)
        let p = Adapter(c,state,blob:blob)
        func speed(_ s: Context) throws -> Int32 { try s.globals.integer(at:0x44d02c-OriginalMatchPreparation.globalBase,as:Int32.self) }
        func target(_ s: Context) throws -> UInt32 { try s.globals.integer(at:0x451dac-OriginalMatchPreparation.globalBase,as:UInt32.self) }
        XCTAssertEqual(try loop.step(context:&state,speed:speed,target:target,perform:p.perform,counterWritten:p.counter),.continued)
        try p.snapshot(state,loop,c.iterations[0].after)
        let previous = loop,before = state;p.stepIndex = 1;p.fail = "callback"
        XCTAssertThrowsError(try loop.step(context:&state,speed:speed,target:target,perform:p.perform,counterWritten:p.counter)) { XCTAssertTrue($0 is Stop) }
        XCTAssertEqual(p.callbackIndex,2);XCTAssertFalse(p.shadow == before.globals.bytes,"The staged key release must actually change globals before failure")
        XCTAssertEqual(state.globals,before.globals);XCTAssertEqual(state.local,before.local);XCTAssertEqual(state.outer,before.outer)
        XCTAssertEqual(state.memory.replayPointers,before.memory.replayPointers);XCTAssertEqual(state.memory.allocations,before.memory.allocations)
        XCTAssertEqual(loop.timer.baseline,previous.timer.baseline);XCTAssertEqual(loop.counter,previous.counter);XCTAssertEqual(loop.message,previous.message)
    }
    func testLateFailureRollsBackContextMessageCounterAndBaseline() throws {
        struct State: Equatable { var value: UInt32 = 0 }
        for phase in ["get","dispatchMessage","sleep","counter","after"] {
            var state = State(),loop = try OriginalApplicationMessageLoop(baseline:100,counter:60),clock = 0,reached = false
            let before = state,old = loop
            do {
                _ = try loop.step(context:&state,speed:{ _ in 1 },target:{ _ in 7 },perform:{ r,s in
                    s.value &+= 1
                    if r.kind.rawValue == phase { reached = true;throw Stop.late }
                    switch r.kind {
                    case .peek:
                        if phase == "sleep" { return .init(result:0) }
                        return .init(result:1,writes:[.init(offset:0,bytes:[UInt8](repeating:0,count:28))])
                    case .get:return .init(result:1)
                    case .time:clock += 1;return .init(result:clock == 1 ? 134 : 135)
                    default:return .init(result:1)
                    }
                },counterWritten:{ _ in if phase == "counter" { reached = true;throw Stop.late } },beforeCommit:{ _,_,_ in if phase == "after" { reached = true;throw Stop.late } })
                XCTFail("Missing failure")
            } catch Stop.late {}
            XCTAssertTrue(reached);XCTAssertEqual(state,before);XCTAssertEqual(loop.counter,old.counter);XCTAssertEqual(loop.timer.baseline,old.timer.baseline);XCTAssertEqual(loop.message,old.message)
        }
        // Missing required platform output remains unknown; zero GetMessage
        // cannot import the original stack's wParam to manufacture a return.
        var state = State(),loop = try OriginalApplicationMessageLoop(baseline:1,counter:0)
        XCTAssertThrowsError(try loop.step(context:&state,speed:{ _ in 1 },target:{ _ in 0 },perform:{ r,_ in .init(result:r.kind == .peek ? 1 : 0) })) {
            guard case OriginalStateError.undefinedBytes(offset:8,count:4) = $0 else { return XCTFail("Wrong unknown MSG boundary") }
        }
        XCTAssertTrue(loop.message.defined.allSatisfy { !$0 });XCTAssertEqual(loop.counter,0)
    }
}
