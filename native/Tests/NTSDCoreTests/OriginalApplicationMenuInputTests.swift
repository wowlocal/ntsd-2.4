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
        let c: Corpus,extras: [[ExtraEvent]],indices: [Int],referenceIndices: [Int]
        var cache: [String:[UInt8]] = [:]
        init(_ parent: M.Resources,supplied: Data? = nil,expectedCounts: (cases: Int,parents: Int) = (50,47),referenceIndices: [Int]? = nil) throws {
            let data: Data
            if let supplied { data = supplied }
            else {
                let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_MENU_INPUT"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-menu-input",withExtension:"json",subdirectory:"Fixtures"))
                data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:300_000_000)
            }
            c = try JSONDecoder().decode(Corpus.self,from:data);XCTAssertEqual(c.cases.count,expectedCounts.cases)
            self.referenceIndices = referenceIndices ?? Array(c.cases.indices)
            XCTAssertEqual(self.referenceIndices.count,c.cases.count)
            XCTAssertTrue(self.referenceIndices.allSatisfy { (0..<50).contains($0) })
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]),parents = try XCTUnwrap(raw["menuParents"] as? [String:[String:Any]])
            XCTAssertEqual(parents.count,expectedCounts.parents)
            indices = try c.cases.map { c in let p = try XCTUnwrap(parents[c.parent]);return try XCTUnwrap(parent.rawCases.firstIndex { sameJSONObject($0,p) }) }
            extras = try XCTUnwrap(raw["cases"] as? [[String:Any]]).map { raw in try JSONDecoder().decode([ExtraEvent].self,from:JSONSerialization.data(withJSONObject:XCTUnwrap(raw["events"]))) }
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let z = try XCTUnwrap(c.blobs[key]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),key);cache[key] = b;return b
        }
    }
    enum Stop: Error { case late }
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
            let e = try next(q.kind.rawValue),request = try XCTUnwrap(e.request);XCTAssertEqual(e.kind,"queue");XCTAssertEqual(request.kind,q.kind.rawValue);XCTAssertEqual(request.arguments,q.arguments);XCTAssertEqual(request.defined,q.defined);XCTAssertEqual(request.message,q.message);try late(q.kind.rawValue)
            if let response = e.response { return response }
            guard q.kind == .translate || q.kind == .dispatchMessage else {
                XCTFail("Missing declared reply for \(q.kind)");throw Stop.late
            }
            return .init()
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
    func run(_ index: Int,_ r: Resources,_ mr: M.Resources,_ body: Body.Resources,_ front: F.Resources,_ br: B.Resources,_ er: B.Entry.Resources,fail: String? = nil,useHost: Bool = false,
             loading: ((B.OwnContext, OriginalApplicationMenuSession.PendingLoading) throws -> Void)? = nil,
             ownerAtLoading: ((OriginalApplicationMenuSession) throws -> Void)? = nil,
             hostAtLoading: ((OriginalApplicationHostSessionTests.Host) throws -> Void)? = nil,
             beforeHostLoading: ((OriginalApplicationHostSessionTests.Host,OriginalApplicationHostSessionTests.Host.Inputs) throws -> Void)? = nil) throws {
        let c = r.c.cases[index],referenceIndex = r.referenceIndices[index];var reached = false,failed = false
        var hostApplication: OriginalApplicationHostSessionTests.Application?
        try M().run(r.indices[index],mr,body,front,br,er,useHost:useHost,hostReady:{ if useHost { hostApplication = $0 } },continuation:{ initialLoop,initial in
            reached = true
            typealias Session = OriginalApplicationMenuSession
            var session = try Session(state:initial.menuSessionState(counter:initialLoop.counter),loop:initialLoop)
            if let app = hostApplication {
                OriginalApplicationBootstrapTests.same(try XCTUnwrap(app.session),session)
                session = try XCTUnwrap(app.session)
            }
            let parentBindings = try XCTUnwrap(session.state.bitmapInputs)
            let ownExtras = r.extras[index]
            let a = Adapter(c,r,ownExtras,session.state.full.bytes,fail)
            let responses = Session.Responses(draw:c.spec.drawResult,presentation:c.spec.presentResult,
                sound:c.spec.soundResult,release:c.spec.releaseResult,dcResult:c.spec.dcResult,dc:0x12345678)
            var deliveredEffects: [Session.Effect] = []
            var graphicsSeen: [OriginalApplicationGraphics.Command] = []
            // Independent projection of saved terminal requests. This does not
            // call the Core classifier or derive expected output from Native.
            func expectedEffects(_ start: Int,_ end: Int) throws -> [Session.Effect] {
                var effects: [Session.Effect] = []
                for index in start..<end {
                    let saved = c.events[index]
                    if saved.kind == "queue" {
                        let q = try XCTUnwrap(saved.request)
                        if q.kind == "translate" {
                            let message = try q.message.map { try OriginalStateRecord(bytes:$0,defined:XCTUnwrap(q.defined)) }
                            effects.append(.translate(.init(.translate,q.arguments,message:message)))
                        } else if q.kind == "sleep" { effects.append(.sleep(try XCTUnwrap(q.arguments.first))) }
                        continue
                    }
                    if saved.kind == "windowDefault" { continue }
                    let e = try XCTUnwrap(saved.event)
                    switch e.kind {
                    case "blit":effects.append(.blit(try XCTUnwrap(e.blit),result:c.spec.drawResult))
                    case "fill":
                        let fill = try XCTUnwrap(e.fill)
                        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(fill)) as? [String:Any])
                        raw["effects"] = fill.defined.indices.map { fill.defined[$0] ? fill.effects[$0] : 0 }
                        let normalized = try JSONDecoder().decode(OriginalSurfaceFillRequest.self,from:JSONSerialization.data(withJSONObject:raw))
                        effects.append(.fill(normalized,result:c.spec.drawResult))
                    case "clear":
                        let f = try XCTUnwrap(ownExtras[index].event?.effects?.first)
                        let record = try OriginalStateRecord(bytes:f.defined.indices.map { f.defined[$0] ? f.bytes[$0] : 0 },defined:f.defined)
                        effects.append(.surface(.init("blt",[e.arguments[0],0,0,0,e.arguments[1]],structure:record),.init(result:c.spec.drawResult)))
                    case "soundMethod":effects.append(.soundMethod(e,ignoredResult:c.spec.soundResult))
                    case "method":
                        if e.arguments[1] == 8 { effects.append(.release(e,ignoredResult:c.spec.releaseResult)) }
                        else { XCTAssertEqual(e.arguments[1],0x14);effects.append(.present(e,result:c.spec.presentResult)) }
                    case "getDC":effects.append(.getDC(e,result:c.spec.dcResult,output:0x12345678))
                    case "setBackgroundMode","setTextColor","textOut","releaseDC":effects.append(.graphics(e,result:c.spec.drawResult))
                    case "free":effects.append(.free(try XCTUnwrap(e.arguments.first)))
                    case "write","writeLocal","read","clip","draw","text","stringLength","soundRequest","randomTable","panel","enter","leave":break
                    default:XCTFail("Unclassified source effect \(e.kind)");throw Stop.late
                    }
                }
                return effects
            }
            func snapshot(_ state: State,_ owned: Session.State,_ timer: Loop) throws {
                XCTAssertTrue(owned.full.bytes == (try r.blob(state.globals)),c.spec.label+" full state")
                XCTAssertTrue(owned.full.defined.allSatisfy { $0 },"Selected parent has independent PE provenance; source write masks are separate")
                try OriginalSurfaceSourceColorsTests.compareInput(owned.bitmapInputs,parent:parentBindings,inputIndex:referenceIndex,eventEnd:a.index)
                XCTAssertEqual(owned.random.state,state.random);XCTAssertEqual(owned.libraryText.retainedDC,state.retainedDC)
                XCTAssertEqual(timer.counter,state.counter);XCTAssertEqual(timer.timer.baseline,state.baseline)
                XCTAssertEqual(timer.message.bytes,try r.blob(state.message));XCTAssertEqual(timer.message.defined,try r.blob(state.messageMask).map { $0 != 0 })
                for record in state.records {
                    let actual = try XCTUnwrap(owned.memory.allocations[record.address]);XCTAssertEqual(actual.live,record.live)
                    XCTAssertEqual(actual.storage.bytes,try r.blob(record.bytes));XCTAssertEqual(actual.storage.defined,try r.blob(record.mask).map { $0 != 0 })
                }
            }
            func unchanged(_ prior: Session,_ oldEffects: [Session.Effect]) {
                let own = session.state, before = prior.state
                XCTAssertEqual(own.bitmapInputs,before.bitmapInputs)
                XCTAssertEqual(own.graphics,before.graphics)
                XCTAssertEqual(own.full,before.full)
                XCTAssertEqual(own.memory.allocations,before.memory.allocations);XCTAssertEqual(own.memory.replayPointers,before.memory.replayPointers)
                XCTAssertEqual(own.front.bitmaps,before.front.bitmaps);XCTAssertEqual(own.earlyScreen.bitmaps,before.earlyScreen.bitmaps)
                XCTAssertEqual(own.earlyScreen.surfaces,before.earlyScreen.surfaces);XCTAssertEqual(own.earlyScreen.retainedOperation,before.earlyScreen.retainedOperation)
                XCTAssertEqual(own.libraryText,before.libraryText);XCTAssertEqual(own.random,before.random);XCTAssertEqual(own.screenBody,before.screenBody)
                XCTAssertEqual(session.loop.message,prior.loop.message);XCTAssertEqual(session.loop.counter,prior.loop.counter)
                XCTAssertEqual(session.loop.timer.baseline,prior.loop.timer.baseline);XCTAssertEqual(deliveredEffects,oldEffects)
            }
            try snapshot(c.before,session.state,session.loop)
            for iteration in c.iterations {
                try snapshot(iteration.before,session.state,session.loop)
                let prior = session, oldEffects = deliveredEffects, eventStart = a.index,graphicsStart = graphicsSeen.count
                func advance(observe: @escaping (OriginalFrontScreenEvent) throws -> Void,
                    graphicsObserve: @escaping (OriginalApplicationGraphics.Command) throws -> Void,
                    checkpoint: (Session.Checkpoint,OriginalStateRecord,Int32?) throws -> Void,
                    bodyProduced: (OriginalFrontScreenBody.StartupResult) throws -> Void,
                    beforeCommit: (Session.Loop,Session.State) throws -> Void) throws -> Session.Outcome {
                    guard let app = hostApplication else {
                        return try session.step(responses:responses,queue:a.queue,windowDefault:{ q in
                            XCTAssertEqual(q.kind,.windowDefault);return try a.window(q.arguments)
                        },surface:a.clear,observe:observe,graphicsObserve:graphicsObserve,checkpoint:checkpoint,
                            bodyProduced:bodyProduced,beforeCommit:beforeCommit)
                    }
                    // Declared API replies only. Existing callbacks still compare
                    // every actual request/event; no source state initializes Core.
                    let events = c.events[eventStart..<iteration.eventEnd]
                    let loopKinds: Set<String> = ["peek","get","translate","dispatchMessage","time","sleep"]
                    let queue = try events.filter { $0.kind == "queue" && loopKinds.contains($0.request?.kind ?? "") }.map { e -> Loop.Response in
                        if let response = e.response { return response }
                        let kind = try XCTUnwrap(e.request).kind
                        guard kind == "translate" || kind == "dispatchMessage" else { throw Stop.late }
                        return .init()
                    }
                    let window = try events.filter { $0.kind == "queue" && $0.request?.kind == "windowDefault" }.map { try XCTUnwrap($0.response).result }
                    let surface = events.filter { $0.kind == "front" && $0.event?.kind == "clear" }.map { _ in OriginalWindowInitialization.Response(result:c.spec.drawResult) }
                    if iteration.end == "loading",let beforeHostLoading {
                        try beforeHostLoading(XCTUnwrap(app.host),.init(responses:responses,queue:queue,windowDefault:window,surface:surface))
                    }
                    let outcome = try app.step(responses:responses,queue:queue,windowDefault:window,surface:surface,lifecycle:[],observe:{ event in
                        switch event {
                        case .queueResponse(let q,let reply):XCTAssertEqual(reply,try a.queue(q))
                        case .windowResponse(let q,let reply):
                            XCTAssertEqual(q.kind,.windowDefault);XCTAssertEqual(reply,try a.window(q.arguments))
                        case .surfaceResponse(let q,let reply):XCTAssertEqual(reply,try a.clear(q))
                        default:XCTFail("Unexpected host input observation");throw Stop.late
                        }
                    },menuObserve:observe,graphicsObserve:graphicsObserve,checkpoint:checkpoint,
                        bodyProduced:bodyProduced,beforeCommit:beforeCommit)
                    session = try XCTUnwrap(app.session)
                    return outcome
                }
                do {
                    let outcome = try advance(observe:{ e in
                        if e.kind == "randomTable" {
                            var check = OriginalCRTRandom(state:e.arguments[0])
                            for _ in 0..<3000 {
                                let expected = c.randomCalls[a.randomIndex];a.randomIndex += 1
                                XCTAssertEqual(check.state,expected.before);XCTAssertEqual(check.next(),expected.result);XCTAssertEqual(check.state,expected.after)
                            }
                            XCTAssertEqual(check.state,e.arguments[1])
                        }
                        try a.front(e)
                    },graphicsObserve:{ graphicsSeen.append($0) },checkpoint:{ point,full,result in
                        let saved = try a.checkpoint(point.rawValue,full.bytes)
                        XCTAssertTrue(full.defined.allSatisfy { $0 })
                        if point == .dispatchReturn { XCTAssertEqual(UInt32(bitPattern:try XCTUnwrap(result)),saved.eax) }
                        else { XCTAssertNil(result) }
                    },bodyProduced:{ output in
                        let source = try r.blob(c.states[a.stateIndex].state.local)
                        for i in output.local.bytes.indices { XCTAssertEqual(output.local.bytes[i],output.local.defined[i] ? source[i] : 0) }
                        XCTAssertEqual(output.local.defined.filter { $0 }.count,96)
                    },beforeCommit:{ timer,staged in
                        try snapshot(iteration.after,staged,timer);XCTAssertEqual(a.index,iteration.eventEnd)
                        if fail == "commit" { throw Stop.late }
                    })
                    switch outcome {
                    case .committed(let batch):
                        XCTAssertEqual(iteration.end,"continued");XCTAssertEqual(batch.result,.continued)
                        XCTAssertEqual(batch.effects,try expectedEffects(eventStart,iteration.eventEnd))
                        deliveredEffects += batch.effects
                        XCTAssertEqual(batch.graphics,Array(graphicsSeen[graphicsStart...]))
                        try snapshot(iteration.after,session.state,session.loop)
                    case .loading(let pending):
                        XCTAssertEqual(iteration.end,"loading");XCTAssertNil(fail)
                        XCTAssertTrue(pending.state.full.bytes == (try r.blob(iteration.after.globals)))
                        XCTAssertTrue(pending.state.full.defined.allSatisfy { $0 })
                        XCTAssertEqual(iteration.after.pc,0x41bc90);XCTAssertEqual(iteration.after.sp,0x1000ea6c)
                        XCTAssertEqual(pending.stagedEffects,try expectedEffects(eventStart,iteration.eventEnd))
                        XCTAssertEqual(pending.stagedGraphics,Array(graphicsSeen[graphicsStart...]))
                        try OriginalApplicationGraphicsTests.compareOwner(pending.state.graphics,kind:"input",index:referenceIndex)
                        try OriginalSurfaceSourceColorsTests.compareInput(pending.state.bitmapInputs,parent:parentBindings,inputIndex:referenceIndex,eventEnd:a.index)
                        let loadingState = try initial.receivingMenuState(pending.state)
                        try OriginalSurfaceSourceColorsTests.compareInput(loadingState.bitmapInputs,parent:parentBindings,inputIndex:referenceIndex,eventEnd:a.index)
                        try ownerAtLoading?(session)
                        try loading?(loadingState,pending)
                        if let hostAtLoading { try hostAtLoading(XCTUnwrap(hostApplication?.host)) }
                        XCTAssertEqual(a.index,iteration.eventEnd);unchanged(prior,oldEffects)
                    }
                } catch {
                    guard case Stop.late = error else { throw error }
                    XCTAssertNotNil(fail);failed = true;unchanged(prior,oldEffects);break
                }
            }
            try OriginalApplicationGraphicsTests.compare(graphicsSeen,kind:"input",index:referenceIndex,stageKind:"input",prefix:fail != nil,inputs:session.state.bitmapInputs)
            if fail == nil {
                if c.iterations.last?.end != "loading" { try OriginalApplicationGraphicsTests.compareOwner(session.state.graphics,kind:"input",index:referenceIndex) }
                let sound = deliveredEffects.compactMap { e -> Int32? in if case .soundMethod(_,let result) = e { return result };return nil }
                let release = deliveredEffects.compactMap { e -> Int32? in if case .release(_,let result) = e { return result };return nil }
                XCTAssertEqual(sound,Array(repeating:c.spec.soundResult,count:c.spec.label.hasPrefix("activate-") ? 3 : 0))
                XCTAssertEqual(release,Array(repeating:c.spec.releaseResult,count:c.spec.label.hasPrefix("activate-") ? 1 : 0))
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

    func testSessionPreservesUnknownAliasesAndPublishesEffectsOnlyAfterCommit() throws {
        typealias Session = OriginalApplicationMenuSession
        var bytes = [UInt8](repeating:0,count:0xc3a8),mask = [Bool](repeating:true,count:0xc3a8)
        bytes[0x100] = 0xa7; mask[0x100] = false
        for i in 0..<8 { bytes[0xb8a8+i] = UInt8(0xb0+i);mask[0xb8a8+i] = false }
        let full = try OriginalStateRecord(bytes:bytes,defined:mask)
        let pointers = try OriginalStateRecord(bytes:Array(bytes[0xb8a8..<0xb8b0]),defined:Array(mask[0xb8a8..<0xb8b0]))
        func state(_ memory: OriginalMenuPresentationMemory) throws -> Session.State {
            try .init(full:full,memory:memory,front:.init(),frontSurfaces:[:],earlyScreen:.init(),libraryText:.init(),random:.init(),screenBody:nil)
        }
        var conflict = pointers;try conflict.write(UInt8(0xc1),at:0)
        XCTAssertThrowsError(try state(.init(replayPointers:conflict))) { error in
            guard case OriginalStateError.invalidStorage("Menu replay alias bytes or masks") = error else { return XCTFail("\(error)") }
        }
        conflict = try .init(bytes:pointers.bytes,defined:[Bool](repeating:true,count:8))
        XCTAssertThrowsError(try state(.init(replayPointers:conflict))) { error in
            guard case OriginalStateError.invalidStorage("Menu replay alias bytes or masks") = error else { return XCTFail("\(error)") }
        }
        var session = try Session(state:state(.init(replayPointers:pointers)),loop:.init(baseline:123,counter:0))
        let replies = Session.Responses(draw:0,presentation:0,sound:0,release:0,dcResult:0,dc:9)
        var message = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:28),defined:[Bool](repeating:true,count:28))
        try message.write(UInt32(0x200),at:4);try message.write(UInt32(230 << 16 | 350),at:12)
        func queue(_ q: Loop.Request) throws -> Loop.Response {
            switch q.kind {
            case .peek,.get:return .init(result:1,writes:[.init(offset:0,bytes:message.bytes)])
            case .translate,.dispatchMessage:return .init()
            default:throw Stop.late
            }
        }
        let outcome = try session.step(responses:replies,queue:queue,windowDefault:{ _ in -123 },surface:{ _ in throw Stop.late })
        guard case .committed(let batch) = outcome else { return XCTFail("Message did not commit") }
        XCTAssertEqual(batch.result,.continued);XCTAssertEqual(batch.effects.count,1)
        guard case .translate = batch.effects[0] else { return XCTFail("Helper duplicated external effects") }
        XCTAssertEqual(session.state.full.bytes[0x100],0xa7);XCTAssertFalse(session.state.full.defined[0x100])
        XCTAssertEqual(session.state.memory.replayPointers,pointers)
        XCTAssertEqual(Array(session.state.full.bytes[0xb8a8..<0xb8b0]),pointers.bytes)
        XCTAssertEqual(Array(session.state.full.defined[0xb8a8..<0xb8b0]),pointers.defined)
        let committed = session
        var returned: Session.Outcome?
        XCTAssertThrowsError(returned = try session.step(responses:replies,queue:queue,windowDefault:{ _ in -123 },surface:{ _ in throw Stop.late },beforeCommit:{ _,_ in throw Stop.late }))
        XCTAssertNil(returned);XCTAssertEqual(session.state.full,committed.state.full)
        XCTAssertEqual(session.loop.counter,committed.loop.counter);XCTAssertEqual(session.loop.message,committed.loop.message)
        XCTAssertThrowsError(try session.step(responses:replies,queue:{ q in
            if q.kind == .dispatchMessage { return .init(writes:[.init(offset:0,bytes:[1])]) }
            return try queue(q)
        },windowDefault:{ _ in XCTFail("Invalid dispatch output reached callback");return 0 },surface:{ _ in throw Stop.late })) { error in
            guard case OriginalStateError.invalidStorage("Only message retrieval owns MSG output writes") = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(session.state.full,committed.state.full);XCTAssertEqual(session.loop.message,committed.loop.message)
    }

    /// CORE_REALTIME A0: without a beforeCommit observer (`observesCommit:
    /// false`) the step skips the merged copy made for one; idle, message and
    /// quit iterations, the counter's reset and a failing hook commit or fail
    /// exactly as with an observer.
    func testCommitWithoutObserverEqualsObservedCommit() throws {
        typealias Session = OriginalApplicationMenuSession
        var bytes = [UInt8](repeating:0,count:0xc3a8)
        for i in 0..<8 { bytes[0xb8a8+i] = UInt8(0xb0+i) }
        bytes[0xb580] = 58   // the counter alias equals the loop's counter (Session.init checks it)
        let mask = [Bool](repeating:true,count:0xc3a8),full = try OriginalStateRecord(bytes:bytes,defined:mask)
        let pointers = try OriginalStateRecord(bytes:Array(bytes[0xb8a8..<0xb8b0]),defined:Array(mask[0xb8a8..<0xb8b0]))
        let state = try Session.State(full:full,memory:.init(replayPointers:pointers),front:.init(),frontSurfaces:[:],
                                      earlyScreen:.init(),libraryText:.init(),random:.init(),screenBody:nil)
        let replies = Session.Responses(draw:0,presentation:0,sound:0,release:0,dcResult:0,dc:9)
        var message = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:28),defined:[Bool](repeating:true,count:28))
        try message.write(UInt32(0x200),at:4);try message.write(UInt32(230 << 16 | 350),at:12)
        func run(_ observes: Bool) throws -> ([String],[OriginalStateRecord]) {
            var session = try Session(state:state,loop:.init(baseline:123,counter:58))
            var log: [String] = [],states: [OriginalStateRecord] = [],observed = 0
            // 0: idle (a constant clock keeps the timer from coming due), 1: a
            // message, 2: WM_QUIT; the fifth iteration's hook throws.
            for (i,kind) in [0,0,1,0,0,0,2,0].enumerated() {
                func queue(_ q: Loop.Request) throws -> Loop.Response {
                    switch q.kind {
                    case .peek: return kind == 0 ? .init(result:0) : .init(result:1,writes:[.init(offset:0,bytes:message.bytes)])
                    case .get: return .init(result:kind == 2 ? 0 : 1,writes:[.init(offset:0,bytes:message.bytes)])
                    case .translate,.dispatchMessage,.sleep: return .init()
                    case .time: return .init(result:124)
                    default: throw Stop.late
                    }
                }
                do {
                    let outcome = try session.step(responses:replies,queue:queue,windowDefault:{ _ in -123 },surface:{ _ in throw Stop.late },
                        beforeCommit:{ _,_ in observed += 1;if i == 4 { throw Stop.late } },observesCommit:observes)
                    guard case .committed(let batch) = outcome else { log.append("not committed");continue }
                    log.append("committed \(batch.result) \(batch.effects)")
                } catch { log.append("error \(error)") }
                log.append("loop \(session.loop.counter) \(session.loop.timer.baseline) \(session.loop.message.bytes) hooks \(observed)")
                states.append(session.state.full)
            }
            return (log,states)
        }
        let (observedLog,observedStates) = try run(true),(plainLog,plainStates) = try run(false)
        XCTAssertEqual(plainLog,observedLog);XCTAssertEqual(plainStates,observedStates)
        XCTAssertTrue(observedLog.contains { $0.hasPrefix("error") } && observedLog.contains { $0.contains("quit") },"failure and quit covered")
    }

    func testSessionRejectsMissingAndDeadCurrentBitmapOwners() throws {
        typealias Session = OriginalApplicationMenuSession
        let fr = try F.Resources(),body = try Body.Resources(fr),mr = try M.Resources(body,fr),br = try B.Resources(),er = try B.Entry.Resources()
        var reached = false
        try M().run(0,mr,body,fr,br,er,continuation:{ loop,initial in
            reached = true
            let original = try initial.menuSessionState(counter:loop.counter)
            let pointer = try original.full.integer(at:0x41ac,as:UInt32.self)
            XCTAssertNotNil(original.earlyScreen.bitmaps[pointer])
            for missing in [true,false] {
                var input = original
                if missing { input.memory.allocations.removeValue(forKey:pointer) }
                else { input.memory.allocations[pointer]!.live = false }
                var session = try Session(state:input,loop:loop)
                var returned: Session.Outcome?
                XCTAssertThrowsError(returned = try session.step(responses:.init(draw:0,presentation:0,sound:0,release:0,dcResult:0,dc:0x12345678),queue:{ q in
                    if q.kind == .peek { return .init() }
                    if q.kind == .time { return .init(result:Int32(bitPattern:loop.timer.baseline &+ 1000)) }
                    throw Stop.late
                },windowDefault:{ _ in throw Stop.late },surface:{ _ in .init() })) { error in
                    XCTAssertEqual(error as? Session.Boundary,.bitmapOwnership(pointer))
                }
                XCTAssertNil(returned);XCTAssertEqual(session.state.full,input.full)
                XCTAssertEqual(session.state.memory.allocations,input.memory.allocations)
                XCTAssertEqual(session.state.random,input.random);XCTAssertEqual(session.state.libraryText,input.libraryText)
                XCTAssertEqual(session.loop.message,loop.message);XCTAssertEqual(session.loop.counter,loop.counter)
                XCTAssertEqual(session.loop.timer.baseline,loop.timer.baseline)
            }
        })
        XCTAssertTrue(reached)
    }
}
