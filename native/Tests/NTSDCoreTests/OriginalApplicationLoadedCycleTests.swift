import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationLoadedCycleTests: XCTestCase {
    typealias A = OriginalApplicationBootstrap
    typealias C = OriginalApplicationLoadedCycleSession
    typealias M = OriginalApplicationLoadedMenuTests
    typealias F = OriginalApplicationCatalogFullTests
    typealias Q = OriginalApplicationMenuInputTests
    typealias Session = A.Session
    typealias Stop = M.Stop
    struct Parent { let application: A,input: C.Input.PendingContinuation }
    // First-menu allocation/settings work is already committed. Cached pre-loading
    // prefix/body calls retain the declared zero graphics replies; observations
    // reject new allocations/settings IO. Subsequent World2 skips that prefix.
    static let cachedInputs = A.MenuInputs(settings:.init(bytes:[],file:0,scratchAddress:0,closeResult:0),
        prefix:.init(drawTarget:0,milliseconds:0,threadHandle:0,threadID:0,lastError:0,fillResult:0,drawResults:[0]),
        body:.init(dcResult:0,dc:0x12345678,methodResult:0,drawResults:[0],shellResult:33),
        frontAllocations:[],backgroundAllocation:.init(address:0,backing:[]),frontResponses:[],backgroundResponses:[])
    static let responses = Session.Responses(draw:0,presentation:0,sound:0,release:0,dcResult:0,dc:0x12345678)
    static let parent: Result<Parent,Error> = Result {
        let r = try F.reference.get(),prefix = try OriginalApplicationCatalogSessionReference(parentIndex:0)
        let fr = try Q.F.Resources(),br = try Q.Body.Resources(fr),mr = try Q.M.Resources(br,fr),ir = try Q.Resources(mr)
        let bitmap = try Q.B.Resources(),entry = try Q.B.Entry.Resources()
        let index = prefix.prefix.spec.parentIndex,c = ir.c.cases[index]
        var result: Parent?,origin: A?
        try Q.M().run(ir.indices[index],mr,br,fr,bitmap,entry,continuation:{ _,initial in
            origin = try XCTUnwrap(initial.bootstrap)
        })
        var app = try XCTUnwrap(origin)
        let adapter = Q.Adapter(c,ir,ir.extras[index],try XCTUnwrap(app.session).state.full.bytes,nil)
            var eventStart = 0
            for iteration in c.iterations {
                let events = Array(c.events[eventStart..<iteration.eventEnd])
                let outcome = try app.step(inputs:cachedInputs,
                    responses:.init(draw:c.spec.drawResult,presentation:c.spec.presentResult,sound:c.spec.soundResult,
                                    release:c.spec.releaseResult,dcResult:c.spec.dcResult,dc:0x12345678),
                    queue:events.filter { $0.kind == "queue" && $0.request?.kind != "windowDefault" }.map { $0.response ?? .init() },
                    windowDefault:try events.filter { $0.request?.kind == "windowDefault" }.map { try XCTUnwrap($0.response).result },
                    surface:events.filter { $0.event?.kind == "clear" }.map { _ in .init(result:c.spec.drawResult) },lifecycle:[],
                    observe:{ o in
                        switch o {
                        case let .queueResponse(q,r):XCTAssertEqual(try adapter.queue(q),r)
                        case let .windowResponse(q,r):XCTAssertEqual(try adapter.window(q.arguments),r)
                        case let .surfaceResponse(q,r):XCTAssertEqual(try adapter.clear(q),r)
                        case .front(_,let event):try adapter.front(event)
                        case .resource(let e):
                            guard e.kind == .write else { throw Stop.unexpected("Uncached front resource") }
                            try adapter.front(.init("write",[e.arguments[1],e.arguments[2],e.arguments[3]]))
                        case .loopRequest,.callback,.dispatchSurface,.prefixReturn,.panelReturn,.bodyReturn:break
                        default:throw Stop.unexpected("Repeated first-menu initialization")
                        }
                    },menuObserve:adapter.front,checkpoint:{ p,s,_ in _ = try adapter.checkpoint(p.rawValue,s.bytes) })
                let state: Session.State
                switch outcome {
                case .committed:state = try XCTUnwrap(app.session).state
                case .loading(let pending):
                    state = pending.state
                    var loading = try pending.makeLoadingSession()
                    let common = try loading.prepareCommon(inputs:OriginalApplicationLoadingPrefixTests.commonInputs.get(),
                        waves:prefix.prefix.loads.map(\.input),drawResult:c.spec.drawResult,presentationResult:c.spec.presentResult)
                    XCTAssertEqual(common.state.full.bytes,try prefix.blob(prefix.c.before.globals))
                    let startup = try XCTUnwrap(app.startup)
                    var catalog = try C.Input.Pool.Catalog(pending:common,startup:.init(owner:XCTUnwrap(startup.input?.sounds),
                        platforms:prefix.startupWaveInputs,music:startup.output.music))
                    let checksum = try common.state.full.integer(at:0x44f620-0x44d000,as:UInt32.self)
                    let cache = Array(common.state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)])
                    let controls = F.Provider(r,checksum,cache)
                    let loaded = try catalog.load(resources:F().resources(r,common.target),makeControls:controls.controls,
                        observe:controls.observe,afterChild:controls.afterChild,beforeCommit:{ try r.complete($0);try F().checkPublication($0,r,controls) })
                    let provider = try M.P.Provider(loaded);var pool = try C.Input.Pool(pending:loaded)
                    let p = try pool.prepare(inputs:OriginalApplicationInterfaceInputsTests.inputs.get(),makeControls:provider.controls,
                        observe:provider.observe,beforeCommit:provider.complete)
                    var input = try C.Input(pending:p,arithmeticPrecision:.bits53),env: Void = ()
                    let ready = try input.advance(environment:&env,controlBoundary:{ _,_ in throw Stop.unexpected("first input API") })
                    result = .init(application:app,input:ready)
                }
                XCTAssertEqual(state.full.bytes,try ir.blob(iteration.after.globals))
                XCTAssertTrue(state.full.defined.allSatisfy { $0 })
                for record in iteration.after.records {
                    let a = try XCTUnwrap(state.memory.allocations[record.address])
                    XCTAssertEqual(a.live,record.live);XCTAssertEqual(a.storage.bytes,try ir.blob(record.bytes))
                    XCTAssertEqual(a.storage.defined,try ir.blob(record.mask).map { $0 != 0 })
                }
                XCTAssertEqual(adapter.index,iteration.eventEnd);eventStart = iteration.eventEnd
            }
        return try XCTUnwrap(result)
    }
    struct InputEnvironment: Equatable {
        var requests: [OriginalInputControlRequest] = [],points: [String] = [],phases: [Int32] = []
        var stop: String?
        mutating func point(_ name: String) throws { points.append(name);if name == stop { throw Stop.injected(name) } }
    }
    static func input(_ cycle: inout C,_ env: inout InputEnvironment) throws -> C.Input.PendingContinuation {
        let bindings = cycle.bindings,globals = cycle.entry.state.full
        func word(_ address: Int) throws -> UInt32 { try globals.integer(at:address-0x44d000,as:UInt32.self) }
        let expected: [OriginalInputControlRequest] = try [
            .init(.asyncSelect,[word(0x44f1b4),word(0x4546f4),0,0]),.init(.asyncSelect,[word(0x44f46c),word(0x4546f4),0,0]),
            .init(.ioctl,[word(0x44f1b4),0x8004667e,0]),.init(.ioctl,[word(0x44f46c),0x8004667e,1],[[0,0,0,0]])]
        return try cycle.advance(environment:&env,controlBoundary:{ q,e in
            let i = e.requests.count
            guard i < expected.count else { throw Stop.unexpected("Extra control request") }
            XCTAssertEqual(q,expected[i]);e.requests.append(q);try e.point("control\(i)")
            return .init(result:[-1,1,-1,0][i],bytes:i == 3 ? [120,86,52,18] : [])
        },prologue:{ model,state,paused,commands,playback,e in
            XCTAssertFalse(paused);XCTAssertEqual(commands,[UInt8](repeating:0,count:10));XCTAssertEqual(playback,commands)
            try M.I.coherent(bindings,model,state);try e.point("prologue")
        },checkpoint:{ phase,model,state,_,e in
            try M.I.coherent(bindings,model,state)
            e.phases.append(try model.globals.integer(at:0x450b90-0x44d000,as:Int32.self));try e.point(phase.rawValue)
        },beforeCommit:{ _,e in try e.point("commit") })
    }
    static func finish(_ app: inout A,_ pending: M.S.PendingReturn,stop: String? = nil) throws {
        var env: [String] = []
        let time = try XCTUnwrap(app.session).loop.timer.baseline &+ 1000
        do {
        let completed = try app.finishLoadedMenu(pending,environment:&env,perform:{ q,e in
            e.append(q.kind.rawValue)
            if q.kind.rawValue == stop { throw Stop.injected(q.kind.rawValue) }
            guard q.kind == .time || q.kind == .sleep else { throw Stop.unexpected("Outer tail") }
            return .init(result:stop == "sleep" ? 1_000_000 : Int32(bitPattern:time))
        },beforeCommit:{ _,_,e in e.append("commit");if stop == "commit" { throw Stop.injected("commit") } })
        let current = try XCTUnwrap(app.session),owners = try XCTUnwrap(current.loadedOwners)
        XCTAssertEqual(completed.result,.continued)
        XCTAssertEqual(completed.operations,pending.snapshot.operations+[.loop(.init(.time),.init(result:Int32(bitPattern:time)))])
        XCTAssertEqual(completed.graphics,pending.graphics)
        var expected = pending.snapshot.state,full = expected.full
        let counter = try full.integer(at:0xb580,as:UInt32.self) &+ 1
        try full.write(counter > 60 ? UInt32(0) : counter,at:0xb580);try expected.replace(0,full)
        OriginalApplicationCatalogSessionTests.retained(current.state,expected)
        XCTAssertEqual(current.state.earlyScreen.bitmaps,expected.earlyScreen.bitmaps)
        XCTAssertEqual(current.state.earlyScreen.surfaces,expected.earlyScreen.surfaces)
        XCTAssertEqual(current.state.earlyScreen.retainedOperation,expected.earlyScreen.retainedOperation)
        XCTAssertEqual(current.loop.counter,counter > 60 ? UInt32(0) : counter)
        XCTAssertEqual(owners.match.world,pending.snapshot.match.world);XCTAssertEqual(owners.match.actors,pending.snapshot.match.actors)
        XCTAssertEqual(owners.match.globals,pending.snapshot.match.globals);XCTAssertEqual(owners.match.frameAllocations,pending.snapshot.match.frameAllocations)
        XCTAssertEqual(owners.match.backgrounds,pending.snapshot.match.backgrounds);XCTAssertEqual(owners.match.bitmaps,pending.snapshot.match.bitmaps)
        XCTAssertEqual(owners.match.releasedBitmapOrder,pending.snapshot.match.releasedBitmapOrder)
        XCTAssertEqual(owners.music.allocations,pending.snapshot.music.allocations)
        XCTAssertEqual(owners.resources.bitmaps,pending.snapshot.resources.bitmaps);XCTAssertEqual(owners.backgrounds,pending.snapshot.backgrounds)
        } catch {
            XCTAssertEqual(env,[]);throw error
        }
        XCTAssertEqual(env,["time","commit"])
    }
    static func start(_ reverse: Bool) throws -> (A,M.S.PendingReturn) {
        let p = try parent.get();var app = p.application,s = try M.S(pending:p.input),env = M.Environment(reverse:reverse)
        let pending = try M.advance(&s,&env);try finish(&app,pending);return (app,pending)
    }
    static func key(_ app: inout A,_ message: UInt32,_ key: UInt32) throws {
        let before = try XCTUnwrap(app.session)
        var bytes = [UInt8](repeating:0,count:28)
        for (offset,value) in [(0,try before.state.full.integer(at:0x4546f4-0x44d000,as:UInt32.self)),(4,message),(8,key)] {
            for i in 0..<4 { bytes[offset+i] = UInt8(truncatingIfNeeded:value >> (8*i)) }
        }
        var windowCalls = 0
        let result = try app.step(inputs:cachedInputs,responses:responses,
            queue:[.init(result:1),.init(result:1,writes:[.init(offset:0,bytes:bytes)]),.init(),.init()],
            windowDefault:[0],surface:[],lifecycle:[],observe:{ event in
                if case .windowResponse(let q,let r) = event {
                    windowCalls += 1;XCTAssertEqual(q.kind,.windowDefault)
                    XCTAssertEqual(q.arguments,[try before.state.full.integer(at:0x4546f4-0x44d000,as:UInt32.self),message,key,0])
                    XCTAssertEqual(r,0)
                }
            })
        XCTAssertEqual(windowCalls,1)
        guard case .committed(let batch) = result else { throw Stop.unexpected("Keyboard iteration") }
        XCTAssertEqual(batch.effects.count,1) // TranslateMessage; recovered WndProc owns the key store.
        XCTAssertEqual(try app.session?.state.full.integer(at:0x455378-0x44d000+Int(key),as:UInt8.self),message == 0x100 ? 100 : 117)
    }
    static func next(_ app: inout A) throws -> Session.PendingLoading {
        let time = Int32(bitPattern:try XCTUnwrap(app.session).loop.timer.baseline &+ 1000)
        let result = try app.step(inputs:cachedInputs,responses:responses,
            queue:[.init(),.init(result:time),.init(result:time),.init(result:time)],
            windowDefault:[],surface:[.init()],lifecycle:[])
        guard case .loading(let pending) = result else { throw Stop.unexpected("World2 loading ticket") }
        return pending
    }
    static func unchanged(_ a: A,_ b: A) throws {
        let x = try XCTUnwrap(a.session),y = try XCTUnwrap(b.session)
        OriginalApplicationCatalogSessionTests.retained(x.state,y.state)
        XCTAssertEqual(x.loop.counter,y.loop.counter);XCTAssertEqual(x.loop.message,y.loop.message)
        XCTAssertEqual(x.loop.timer.baseline,y.loop.timer.baseline)
        XCTAssertEqual(x.loadedOwners?.match.frameAllocations,y.loadedOwners?.match.frameAllocations)
        XCTAssertEqual(x.loadedOwners?.match.backgrounds,y.loadedOwners?.match.backgrounds)
        XCTAssertEqual(x.loadedOwners?.music.allocations,y.loadedOwners?.music.allocations)
    }
    func testActualBootstrapCyclesKeepCachedOwnersAndReachHeldSelectionBoundary() throws {
        for reverse in [false,true] {
            var (app,first) = try Self.start(reverse)
            let original = try XCTUnwrap(app.session),originalOwners = try XCTUnwrap(original.loadedOwners)
            let status = try original.state.full.integer(at:0x450b4c-0x44d000,as:UInt32.self)
            let attack = try original.state.full.integer(at:0x44fb20-0x44d000+Int(status)*80+20,as:UInt32.self)
            XCTAssertEqual(attack,UInt32(74))
            for i in 0..<4 {
                if i == 1 { try Self.key(&app,0x100,attack) }
                if i == 3 { try Self.key(&app,0x101,attack) }
                let before = app,pending = try Self.next(&app)
                try Self.unchanged(app,before)
                var cycle = try app.makeLoadedCycle(pending:pending),inputEnv = InputEnvironment()
                let ready = try Self.input(&cycle,&inputEnv)
                XCTAssertEqual(inputEnv.phases,[Int32](repeating:Int32(i % 2),count:6))
                XCTAssertEqual(inputEnv.requests.count,i % 2 == 0 ? 4 : 0)
                XCTAssertEqual(inputEnv.points.filter { !$0.hasPrefix("control") || $0 == "control" },
                    ["prologue","localBeforeDispatch","local","control","received","replay","round","commit"])
                let controlOperations = inputEnv.requests.enumerated().map { index,q in
                    C.Input.Operation.control(q,.init(result:[-1,1,-1,0][index],bytes:index == 3 ? [120,86,52,18] : []))
                }
                XCTAssertEqual(Array(ready.operations.dropFirst(pending.stagedEffects.count)),controlOperations)
                XCTAssertEqual(ready.music.allocations,originalOwners.music.allocations)
                XCTAssertEqual(ready.match.frameAllocations,originalOwners.match.frameAllocations)
                XCTAssertEqual(ready.match.backgrounds,originalOwners.match.backgrounds)
                XCTAssertEqual(ready.match.arithmeticPrecision,.bits53)
                XCTAssertEqual(Array(ready.operations.prefix(pending.stagedEffects.count)),pending.stagedEffects.map(C.Input.Operation.menu))
                XCTAssertEqual(ready.operations.count,pending.stagedEffects.count+inputEnv.requests.count)
                XCTAssertEqual(try ready.match.actors[0].integer(at:0xd1,as:UInt8.self),i >= 2 ? 1 : 0)
                XCTAssertThrowsError(try Self.input(&cycle,&inputEnv))
                var menu = try M.S(pending:ready),env = M.Environment(reverse:reverse)
                if i == 3 {
                    XCTAssertEqual(try ready.match.globals.integer(at:0x20,as:Int32.self),3)
                    let old = env
                    // The next study connects this child. Retain this test's input
                    // frontier by injecting an observer stop at the first body checkpoint.
                    XCTAssertThrowsError(try M.advance(&menu,&env,character:{ _,_,_ in throw Stop.injected("characterBoundary") })) {
                        XCTAssertEqual($0 as? Stop,.injected("characterBoundary"))
                    }
                    XCTAssertNil(menu.pendingReturn);XCTAssertEqual(env,old);try Self.unchanged(app,before)
                    continue
                }
                if i == 2 {
                    var failed = try M.S(pending:ready),late = M.Environment(stop:"free");let beforeFree = late
                    XCTAssertThrowsError(try M.advance(&failed,&late)) { XCTAssertEqual($0 as? Stop,.injected("free")) }
                    XCTAssertEqual(late,beforeFree);XCTAssertNil(failed.pendingReturn);try Self.unchanged(app,before)
                }
                let returned = try M.advance(&menu,&env)
                XCTAssertEqual(Array(returned.snapshot.operations.dropFirst(ready.operations.count)),env.expectedOperations)
                XCTAssertEqual(env.index,-1);XCTAssertEqual(env.api,0);XCTAssertTrue(env.music.isEmpty)
                XCTAssertEqual(returned.snapshot.resources.bitmaps,originalOwners.resources.bitmaps)
                XCTAssertEqual(returned.snapshot.music.allocations,originalOwners.music.allocations)
                XCTAssertEqual(try returned.snapshot.match.globals.integer(at:0x20,as:Int32.self),i == 2 ? 3 : 10)
                if i == 2 {
                    let events = env.front,draw = try XCTUnwrap(events.firstIndex { $0.kind == "blit" && $0.blit?.sourceSurface == 0x7f2000b0 })
                    let release = try XCTUnwrap(events.firstIndex { $0.kind == "method" && $0.arguments == [0x7f2000b0,8] })
                    let free = try XCTUnwrap(events.firstIndex { $0.kind == "free" && $0.arguments == [0x7e230020] })
                    XCTAssertLessThan(draw,release);XCTAssertLessThan(release,free)
                    XCTAssertEqual(returned.snapshot.state.memory.allocations[0x7e230020]?.live,false)
                    XCTAssertEqual(try returned.snapshot.state.memory.allocations[0x7e230020]?.storage.integer(at:0,as:UInt32.self),0)
                    XCTAssertEqual(try returned.snapshot.match.globals.integer(at:0x4511ac-0x44d000,as:UInt32.self),0)
                } else {
                    XCTAssertEqual(returned.snapshot.state.memory.allocations[0x7e230020],original.state.memory.allocations[0x7e230020])
                }
                try M().compareGraphics(returned,env)
                try Self.finish(&app,returned)
                let speed = try XCTUnwrap(before.session).state.full.integer(at:0x2c,as:Int32.self)
                let interval: UInt32 = speed == 0 ? 3 : 33
                XCTAssertEqual(try XCTUnwrap(app.session).loop.timer.baseline,try XCTUnwrap(before.session).loop.timer.baseline &+ 900 &+ interval)
                XCTAssertEqual(try XCTUnwrap(app.session).loop.counter,try XCTUnwrap(before.session).loop.counter+1)
                XCTAssertThrowsError(try app.makeLoadedCycle(pending:pending))
                XCTAssertThrowsError(try Self.finish(&app,first))
                try OriginalApplicationBootstrapTests.sameStartup(XCTUnwrap(app.startup),XCTUnwrap(before.startup))
            }
        }
    }
    func testRepeatedInputMenuAndOuterRollbackPreservesEarlierCommits() throws {
        var (app,_) = try Self.start(false)
        let pending = try Self.next(&app),prior = app
        for name in ["prologue","control3","commit"] {
            var cycle = try app.makeLoadedCycle(pending:pending),env = InputEnvironment(stop:name);let old = env
            XCTAssertThrowsError(try Self.input(&cycle,&env)) { XCTAssertEqual($0 as? Stop,.injected(name)) }
            XCTAssertEqual(env,old);XCTAssertNil(cycle.pendingContinuation);try Self.unchanged(app,prior)
        }
        var cycle = try app.makeLoadedCycle(pending:pending),input = InputEnvironment()
        let ready = try Self.input(&cycle,&input)
        for name in ["screen","earlyReturned","commit"] {
            var menu = try M.S(pending:ready),env = M.Environment(stop:name);let old = env
            XCTAssertThrowsError(try M.advance(&menu,&env)) { XCTAssertEqual($0 as? Stop,.injected(name)) }
            XCTAssertEqual(env,old);XCTAssertNil(menu.pendingReturn);try Self.unchanged(app,prior)
        }
        var menu = try M.S(pending:ready),env = M.Environment();let returned = try M.advance(&menu,&env)
        for name in ["time","sleep","commit"] {
            XCTAssertThrowsError(try Self.finish(&app,returned,stop:name)) { XCTAssertEqual($0 as? Stop,.injected(name)) }
            try Self.unchanged(app,prior)
        }
        try Self.finish(&app,returned)
        XCTAssertThrowsError(try Self.finish(&app,returned))
        XCTAssertThrowsError(try A().makeLoadedCycle(pending:pending))
        var foreign = try Session(state:XCTUnwrap(prior.session).state,loop:XCTUnwrap(prior.session).loop)
        XCTAssertThrowsError(try foreign.makeLoadedCycle(pending:pending))
        var tail: Void = ()
        XCTAssertThrowsError(try foreign.finishLoadedMenu(returned,environment:&tail,perform:{ _,_ in throw Stop.unexpected("Foreign IO") }))
    }
    func testBindingRefreshKeepsMutableFramesArenasAndReleaseHistory() throws {
        let p = try Self.parent.get(),bindings = try OriginalApplicationMatchBindings(pending:p.input.entry)
        var match = p.input.match
        // Declared native ownership sentinel, not an additional original game case.
        try match.setBackgroundPerspectiveInput(0x12345678,background:0)
        match.releasedBitmapOrder = [9,3]
        let frames = match.frameAllocations
        match.frameAllocations = Array(frames.reversed())
        let current = try bindings.read(p.input.state,retaining:match)
        XCTAssertEqual(current.backgrounds,match.backgrounds);XCTAssertEqual(current.releasedBitmapOrder,[9,3])
        XCTAssertEqual(current.frameAllocations,Array(frames.reversed()))
        XCTAssertEqual(current.world,p.input.match.world);XCTAssertEqual(current.actors,p.input.match.actors)
        XCTAssertEqual(current.globals,p.input.match.globals);XCTAssertEqual(current.arithmeticPrecision,.bits53)
    }
}
