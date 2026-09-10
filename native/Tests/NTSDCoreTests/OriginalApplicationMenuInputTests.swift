import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationMenuInputTests: XCTestCase {
    typealias M = OriginalApplicationMenuReturnTests
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias F = OriginalApplicationFrontScreenTests
    typealias Body = OriginalApplicationScreenBodyTests
    typealias Loop = OriginalApplicationMessageLoop
    struct Spec: Decodable { let label: String,parentIndex: Int,drawResult: Int32,presentResult: Int32,soundResult: Int32,releaseResult: Int32,dcResult: Int32 }
    struct Record: Decodable { let address: UInt32,live: Bool,bytes: String,mask: String }
    struct State: Decodable { let globals: String,mask: String,local: String,retainedDC: UInt32,message: String,messageMask: String,random: UInt32,counter: UInt32,baseline: UInt32,pc: UInt32,sp: UInt32,eax: UInt32,records: [Record] }
    struct Request: Decodable { let kind: String,arguments: [UInt32],message: [UInt8]?,defined: [Bool]? }
    struct Effect: Decodable { let bytes: [UInt8],defined: [Bool] }
    struct Event: Decodable { let kind: String,event: OriginalFrontScreenEvent?,request: Request?,response: Loop.Response?,globals: String }
    struct ExtraEvent: Decodable { struct Inner: Decodable { let effects: [Effect]? };let event: Inner? }
    struct Checkpoint: Decodable { let kind: String,state: State,eventIndex: Int }
    struct Iteration: Decodable { let before: State,after: State,eventEnd: Int,end: String }
    struct Random: Decodable { let before: UInt32,after: UInt32,result: UInt32 }
    struct Case: Decodable { let spec: Spec,parent: String,before: State,after: State,events: [Event],states: [Checkpoint],iterations: [Iteration],randomCalls: [Random],end: String }
    struct Corpus: Decodable { let cases: [Case],blobs: [String:OriginalApplicationMessageLoopTests.Blob] }
    final class Resources {
        let c: Corpus,extras: [[ExtraEvent]],indices: [Int]
        var cache: [String:[UInt8]] = [:]
        init(_ parent: M.Resources) throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_MENU_INPUT"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-menu-input",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:300_000_000)
            c = try JSONDecoder().decode(Corpus.self,from:data);XCTAssertEqual(c.cases.count,50)
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]),parents = try XCTUnwrap(raw["menuParents"] as? [String:[String:Any]])
            XCTAssertEqual(parents.count,47)
            indices = try c.cases.map { c in let p = try XCTUnwrap(parents[c.parent]);return try XCTUnwrap(parent.rawCases.firstIndex { NSDictionary(dictionary:$0).isEqual(to:p) }) }
            extras = try XCTUnwrap(raw["cases"] as? [[String:Any]]).map { raw in try JSONDecoder().decode([ExtraEvent].self,from:JSONSerialization.data(withJSONObject:XCTUnwrap(raw["events"]))) }
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let z = try XCTUnwrap(c.blobs[key]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),key);cache[key] = b;return b
        }
    }
    enum Stop: Error { case loading,late }
    final class Adapter {
        let c: Case,r: Resources,extras: [ExtraEvent],fail: String?
        var index = 0,stateIndex = 0,randomIndex = 0,shadow: [UInt8],mask = [UInt8](repeating:0,count:0xc3a8),counts: [String:Int] = [:]
        init(_ c: Case,_ r: Resources,_ extras: [ExtraEvent],_ initial: [UInt8],_ fail: String?) { self.c = c;self.r = r;self.extras = extras;shadow = initial;self.fail = fail }
        func next(_ kind: String) throws -> Event {
            guard index < c.events.count else { XCTFail("Extra \(kind)");throw Stop.late }
            let e = c.events[index];index += 1
            XCTAssertTrue(shadow == (try r.blob(e.globals)),c.spec.label+" globals before \(index) \(kind)")
            counts[kind,default:0] += 1;return e
        }
        func late(_ kind: String) throws { if fail == kind+"#\(counts[kind] ?? 0)" { throw Stop.late } }
        func front(_ q: OriginalFrontScreenEvent) throws {
            let e = try next(q.kind),expected = try XCTUnwrap(e.event);XCTAssertEqual(e.kind,"front")
            if let fill = q.fill {
                let f = try XCTUnwrap(expected.fill);XCTAssertEqual(fill.target,f.target);XCTAssertEqual(fill.rectangle,f.rectangle);XCTAssertEqual(fill.flags,f.flags);XCTAssertEqual(fill.defined,f.defined)
                for i in f.defined.indices { XCTAssertEqual(fill.effects[i],f.defined[i] ? f.effects[i] : 0) }
            } else { XCTAssertEqual(q,expected,c.spec.label+" event \(index)") }
            if q.kind == "write" {
                let p = Int(q.arguments[0])-0x44d000,n = Int(q.arguments[1]),v = q.arguments[2]
                shadow.replaceSubrange(p..<p+n,with:(0..<n).map { UInt8(truncatingIfNeeded:v >> ($0*8)) });mask.replaceSubrange(p..<p+n,with:repeatElement(1,count:n))
            }
            try late(q.kind)
        }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
            let v = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) };try front(.init("write",[UInt32(address),UInt32(bytes.count),v]))
        }
        func world(_ offset: Int,_ value: UInt32) throws { try front(.init("write",[0x458b00+UInt32(offset),4,value])) }
        func queue(_ q: Loop.Request) throws -> Loop.Response {
            let e = try next(q.kind.rawValue),request = try XCTUnwrap(e.request);XCTAssertEqual(e.kind,"queue");XCTAssertEqual(request.kind,q.kind.rawValue);XCTAssertEqual(request.arguments,q.arguments);XCTAssertEqual(request.defined,q.defined);XCTAssertEqual(request.message,q.message);try late(q.kind.rawValue);return e.response ?? .init()
        }
        func window(_ args: [UInt32]) throws -> Int32 {
            let e = try next("windowDefault"),q = try XCTUnwrap(e.request);XCTAssertEqual(q.kind,"windowDefault");XCTAssertEqual(q.arguments,args);try late("windowDefault");return try XCTUnwrap(e.response).result
        }
        func clear(_ q: OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response {
            let e = try next("clear"),expected = try XCTUnwrap(e.event),f = try XCTUnwrap(extras[index-1].event?.effects?.first)
            XCTAssertEqual(q.kind,"blt");XCTAssertEqual(q.words,[expected.arguments[0],0,0,0,expected.arguments[1]])
            XCTAssertEqual(q.defined,f.defined)
            let bytes = try XCTUnwrap(q.bytes)
            for i in f.defined.indices { XCTAssertEqual(bytes[i],f.defined[i] ? f.bytes[i] : 0) }
            try late("clear");return .init(result:c.spec.drawResult)
        }
        func checkpoint(_ name: String,_ full: [UInt8]) throws -> State {
            let s = c.states[stateIndex];stateIndex += 1;XCTAssertEqual(s.kind,name);XCTAssertEqual(s.eventIndex,index)
            XCTAssertTrue(full == (try r.blob(s.state.globals)),c.spec.label+" checkpoint "+name);return s.state
        }
    }
    func run(_ index: Int,_ r: Resources,_ mr: M.Resources,_ body: Body.Resources,_ front: F.Resources,_ br: B.Resources,_ er: B.Entry.Resources,fail: String? = nil,
             loading: ((B.OwnContext, UInt32) throws -> Void)? = nil) throws {
        let c = r.c.cases[index];var reached = false,failed = false
        try M().run(r.indices[index],mr,body,front,br,er,continuation:{ initialLoop,initial in
            reached = true;var own = initial,loop = initialLoop
            // Transfer own live wrappers into the existing menu allocator registry.
            // Their raw surface tokens come from native CreateSurface bindings.
            for (p,bitmap) in own.front.bitmaps.merging(own.earlyScreen.bitmaps,uniquingKeysWith:{ _,_ in fatalError("Duplicate owned bitmap") }) {
                let surface = try XCTUnwrap(own.frontSurfaces[p] ?? own.earlyScreen.surfaces[p]);var record = bitmap.storage;try record.write(surface,at:0)
                XCTAssertNil(own.base.memory.allocations.updateValue(.init(storage:record),forKey:p))
            }
            func full(_ owned: B.OwnContext,_ counter: UInt32) -> [UInt8] { owned.base.globals.bytes+owned.base.outerBytes(counter:counter)+owned.outerAndWorldBytes.dropFirst(0x854) }
            let a = Adapter(c,r,r.extras[index],full(own,loop.counter),fail)
            func snapshot(_ state: State,_ owned: B.OwnContext,_ timer: Loop) throws {
                XCTAssertTrue(full(owned,timer.counter) == (try r.blob(state.globals)),c.spec.label+" full state")
                XCTAssertEqual(owned.random.state,state.random);XCTAssertEqual(owned.libraryText.retainedDC,state.retainedDC)
                XCTAssertEqual(timer.counter,state.counter);XCTAssertEqual(timer.timer.baseline,state.baseline)
                XCTAssertEqual(timer.message.bytes,try r.blob(state.message));XCTAssertEqual(timer.message.defined,try r.blob(state.messageMask).map { $0 != 0 })
                for record in state.records {
                    let actual = try XCTUnwrap(owned.base.memory.allocations[record.address]);XCTAssertEqual(actual.live,record.live)
                    XCTAssertEqual(actual.storage.bytes,try r.blob(record.bytes));XCTAssertEqual(actual.storage.defined,try r.blob(record.mask).map { $0 != 0 })
                }
            }
            try snapshot(c.before,own,loop)
            for iteration in c.iterations {
                try snapshot(iteration.before,own,loop);let prior = own,old = loop
                do {
                    _ = try loop.step(context:&own,speed:{ try $0.base.globals.integer(at:0x44d02c-0x44d000,as:Int32.self) },target:{ try $0.base.globals.integer(at:0x451dac-0x44d000,as:UInt32.self) },perform:{ q,owned in
                        if q.kind != .gameDispatch {
                            let response = try a.queue(q)
                            if q.kind == .dispatchMessage {
                                let msg = try OriginalStateRecord(bytes:XCTUnwrap(q.message),defined:XCTUnwrap(q.defined))
                                let code = try msg.integer(at:4,as:UInt32.self),lParam = try msg.integer(at:12,as:UInt32.self)
                                let input = try OriginalWindowInput.Message(window:msg.integer(at:0,as:UInt32.self),message:code,wParam:msg.integer(at:8,as:UInt32.self),lParam:lParam)
                                let result = try OriginalWindowInput.receive(input,globals:&owned.base.globals,local:&owned.base.local,memory:&owned.base.memory,request:{ request in
                                    XCTAssertEqual(request.kind,.windowDefault);return try a.window(request.arguments)
                                },store:a.store)
                                return .init(result:result)
                            }
                            return response
                        }
                        var bytes = full(owned,old.counter);_ = try a.checkpoint("dispatch",bytes)
                        var dispatchGlobals = try OriginalStateRecord(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count))
                        let game = try OriginalApplicationDispatchEntry.advance(incomingTarget:q.arguments[0],globals:&dispatchGlobals,perform:{ request,_ in try a.clear(request) },store:a.store)
                        bytes = dispatchGlobals.bytes;_ = try a.checkpoint("world",bytes)
                        let wo = 0x458b00-0x44d000
                        var world = try OriginalStateRecord(bytes:Array(bytes[wo..<wo+0x7d8]),defined:[Bool](repeating:true,count:0x7d8)),g = try OriginalStateRecord(bytes:Array(bytes.prefix(0xb440)),defined:[Bool](repeating:true,count:0xb440))
                        var suffix = Array(bytes.dropFirst(0xb440)),resources = owned.front,screen = owned.earlyScreen,library = owned.libraryText,random = owned.random,memory = owned.base.memory
                        func combined(_ state: OriginalStateRecord,_ w: OriginalStateRecord? = nil) -> [UInt8] {
                            var result = state.bytes+suffix
                            if let w { result.replaceSubrange(wo..<wo+0x7d8,with:w.bytes) };return result
                        }
                        let width = try g.integer(at:0x44d78c-0x44d000,as:Int32.self),height = try g.integer(at:0x44d790-0x44d000,as:Int32.self)
                        let drawing = memory.allocations
                        func draw(_ args: [UInt32]) throws {
                            let bitmap = try XCTUnwrap(drawing[args[0]]);XCTAssertTrue(bitmap.live)
                            let surface = try bitmap.storage.integer(at:0,as:UInt32.self);var canonical = bitmap.storage;try canonical.write(UInt32(surface == 0 ? 0 : 1),at:0)
                            let input = OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:surface,targetSurface:args[6],viewportWidth:width,viewportHeight:height)
                            _ = try OriginalBitmapDrawing.draw(input,bitmap:canonical,observeRead:{ read in var e = OriginalFrontScreenEvent("read");e.read = read;try a.front(e) },observeClip:{ clip in var e = OriginalFrontScreenEvent("clip");e.clip = clip;try a.front(e) },perform:{ b in var e = OriginalFrontScreenEvent("blit");e.blit = b;try a.front(e);return c.spec.drawResult })
                        }
                        let continuation = try OriginalFrontMenuLoop.run(world:&world,globals:&g,initialize:{ w,state in
                            try resources.load(world:w,globals:&state,allocate:{ _ in throw Stop.late },source:{ _,_ in throw Stop.late },deviceResult:{ _ in throw Stop.late },observe:{ e in
                                XCTAssertEqual(e.kind,.write);try a.front(.init("write",[e.arguments[1],e.arguments[2],e.arguments[3]]))
                            })
                        },prefix:{ state in
                            _ = try a.checkpoint("prefix",combined(state))
                            return try screen.advance(globals:&state,input:.init(drawTarget:game.target,milliseconds:0,threadHandle:0,threadID:0,lastError:0,fillResult:c.spec.drawResult,drawResults:[c.spec.drawResult]),fillBacking:[UInt8](repeating:0,count:100),allocate:{ throw Stop.late },source:{ _ in throw Stop.late },observe:a.front)
                        },update:{ state in
                            _ = try a.checkpoint("panel",combined(state))
                            return try OriginalMenuPanelUpdate.run(globals:&state,content:{ _ in throw Stop.late },bitmap:{ _ in throw Stop.late },write:{ _,_ in throw Stop.late },observe:{ e,_ in try a.front(.init(e.kind,e.arguments)) })
                        },body:{ state in
                            _ = try a.checkpoint("body",combined(state))
                            let output = try OriginalFrontScreenBody.advanceOwnStartup(globals:&state,target:game.target,libraryText:&library,input:.init(dcResult:c.spec.dcResult,dc:0x12345678,methodResult:c.spec.drawResult,drawResults:[c.spec.drawResult],shellResult:33),draw:draw,observe:a.front)
                            let source = try r.blob(c.states[a.stateIndex].state.local)
                            for i in output.local.bytes.indices { XCTAssertEqual(output.local.bytes[i],output.local.defined[i] ? source[i] : 0) }
                            XCTAssertEqual(output.local.defined.filter { $0 }.count,96);owned.screenBody = output
                            return output.continuation
                        },alternate:{ state,selector in
                            _ = try a.checkpoint("alternate",combined(state))
                            return try OriginalFrontScreenAlternate.advance(globals:&state,input:.init(selector:selector,drawTarget:game.target,timers:[],methodResult:0,drawResults:[c.spec.drawResult],fillResult:0,threadHandle:0,threadID:0,lastError:0),draw:draw,fill:{ _ in throw Stop.late },writeSettings:{ _ in throw Stop.late },observe:a.front)
                        },completion:{ entry,w,state in
                            let presentation: OriginalMenuPresentationEntry
                            if entry == .main {
                                _ = try a.checkpoint("main",combined(state,w))
                                let input: [String:Any] = ["targetSurface":game.target,"network":["startupResult":0,"version":0,"hostnameResult":0,"hostname":[],"hostEntryAddress":0,"addresses":[],"socketResult":0,"asyncResult":0,"bindResult":0,"listenResult":0]]
                                let end = try OriginalMainMenu.run(world:&w,globals:&state,crt:&random,input:JSONDecoder().decode(OriginalMainMenuInput.self,from:JSONSerialization.data(withJSONObject:input)),store:a.store,worldStored:a.world,observe:{ e in
                                    if e.kind == .bitmap { try a.front(.init("draw",e.arguments));try draw(e.arguments) }
                                    else {
                                        if e.kind == .randomTable {
                                            var check = OriginalCRTRandom(state:e.arguments[0])
                                            for _ in 0..<3000 { let expected = c.randomCalls[a.randomIndex];a.randomIndex += 1;XCTAssertEqual(check.state,expected.before);XCTAssertEqual(check.next(),expected.result);XCTAssertEqual(check.state,expected.after) }
                                            XCTAssertEqual(check.state,e.arguments[1])
                                        }
                                        try a.front(.init(e.kind.rawValue,e.arguments,e.strings))
                                    }
                                });XCTAssertEqual(end,.present);presentation = .tail
                            } else { presentation = entry == .worldOne ? .worldOne : .tail }
                            if presentation == .tail { _ = try a.checkpoint("tail",combined(state,w)) }
                            let input: [String:Any] = ["targetSurface":game.target,"methodResult":c.spec.presentResult,"queryResult":0,"audioGetResult":0,"audioSetResult":0,"queriedAudio":0,"audioVolume":0,"dcResult":0,"dc":0,"postResult":0]
                            try OriginalMenuPresentation.applyWithLibrary(presentation,input:JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:input)),world:&w,globals:&state,memory:&memory,libraryText:&library,store:a.store,worldStored:a.world,observe:{ e in
                                if e.kind == .bitmap { try a.front(.init("draw",e.arguments));try draw(e.arguments) }
                                else { try a.front(.init(e.kind.rawValue,e.arguments,e.strings)) }
                            })
                        })
                        let resultBytes = combined(g,world)
                        if continuation == .loading {
                            XCTAssertEqual(iteration.end,"loading");XCTAssertTrue(resultBytes == (try r.blob(iteration.after.globals)));XCTAssertEqual(iteration.after.pc,0x41bc90);XCTAssertEqual(iteration.after.sp,0x1000ea6c)
                            if let loading {
                                var pending = owned
                                pending.base.globals = g;pending.outerAndWorldBytes = Array(resultBytes.dropFirst(0xb440))
                                pending.base.outer = try .init(bytes:Array(pending.outerAndWorldBytes.prefix(0x854)),defined:[Bool](repeating:true,count:0x854))
                                pending.base.local = try .init(bytes:Array(pending.outerAndWorldBytes.prefix(0x140)),defined:[Bool](repeating:true,count:0x140))
                                try loading(pending,game.target)
                            }
                            XCTAssertEqual(a.index,iteration.eventEnd);throw Stop.loading
                        }
                        XCTAssertEqual(continuation,.returned);_ = try a.checkpoint("worldReturn",resultBytes)
                        let result = try OriginalApplicationDispatchEntry.finishWorldCall(globals:.init(bytes:resultBytes,defined:[Bool](repeating:true,count:0xc3a8)))
                        let returned = try a.checkpoint("dispatchReturn",resultBytes);XCTAssertEqual(UInt32(bitPattern:result),returned.eax)
                        owned.base.globals = g;owned.front = resources;owned.earlyScreen = screen;owned.libraryText = library;owned.random = random;owned.base.memory = memory
                        suffix = Array(resultBytes.dropFirst(0xb440));owned.outerAndWorldBytes = suffix
                        owned.base.outer = try .init(bytes:Array(suffix.prefix(0x854)),defined:[Bool](repeating:true,count:0x854));owned.base.local = try .init(bytes:Array(suffix.prefix(0x140)),defined:[Bool](repeating:true,count:0x140))
                        return .init(result:result)
                    },counterWritten:{ try a.front(.init("write",[0x458580,4,$0])) },beforeCommit:{ next,staged,_ in
                        try snapshot(iteration.after,staged,next);XCTAssertEqual(a.index,iteration.eventEnd)
                        if fail == "commit" { throw Stop.late }
                    })
                    XCTAssertEqual(iteration.end,"continued");try snapshot(iteration.after,own,loop)
                } catch {
                    if case Stop.loading = error { XCTAssertEqual(iteration.end,"loading");XCTAssertNil(fail) }
                    else { guard case Stop.late = error else { throw error };XCTAssertNotNil(fail);failed = true }
                    XCTAssertEqual(own.base.globals,prior.base.globals);XCTAssertEqual(own.base.outer,prior.base.outer);XCTAssertEqual(own.base.local,prior.base.local)
                    XCTAssertEqual(own.base.memory.allocations,prior.base.memory.allocations);XCTAssertEqual(own.base.memory.replayPointers,prior.base.memory.replayPointers)
                    XCTAssertEqual(own.front.bitmaps,prior.front.bitmaps);XCTAssertEqual(own.earlyScreen.bitmaps,prior.earlyScreen.bitmaps);XCTAssertEqual(own.earlyScreen.surfaces,prior.earlyScreen.surfaces)
                    XCTAssertEqual(own.graphics,prior.graphics);XCTAssertEqual(own.libraryText,prior.libraryText);XCTAssertEqual(own.random,prior.random);XCTAssertEqual(own.screenBody,prior.screenBody);XCTAssertEqual(own.outerAndWorldBytes,prior.outerAndWorldBytes)
                    XCTAssertEqual(loop.message,old.message);XCTAssertEqual(loop.counter,old.counter);XCTAssertEqual(loop.timer.baseline,old.timer.baseline);break
                }
            }
            if fail == nil { XCTAssertEqual(a.index,c.events.count);XCTAssertEqual(a.stateIndex,c.states.count);XCTAssertEqual(a.randomIndex,c.randomCalls.count);XCTAssertEqual(a.mask,try r.blob(c.after.mask)) }
        })
        XCTAssertTrue(reached);XCTAssertEqual(failed,fail != nil)
    }
    func testOwnQueuedInputAndRepeatedMenusReachActualLoadingEntry() throws {
        let fr = try F.Resources(),body = try Body.Resources(fr),mr = try M.Resources(body,fr),r = try Resources(mr),br = try B.Resources(),er = try B.Entry.Resources()
        for i in r.c.cases.indices { try run(i,r,mr,body,fr,br,er) }
    }
    func testLateInputMenuAndReleaseFailuresRetainPreviousIterations() throws {
        let fr = try F.Resources(),body = try Body.Resources(fr),mr = try M.Resources(body,fr),r = try Resources(mr),br = try B.Resources(),er = try B.Entry.Resources()
        for fail in ["windowDefault#1","blit#3","soundMethod#3","write#1500","randomTable#1","free#1","method#3","commit"] { try run(47,r,mr,body,fr,br,er,fail:fail) }
    }
}
