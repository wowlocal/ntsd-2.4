import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationLoadedSelectionTests: XCTestCase {
    typealias H = OriginalApplicationLoadedCharacterTests
    typealias C = OriginalApplicationLoadedCycleTests
    typealias M = OriginalApplicationLoadedMenuTests
    typealias A = OriginalApplicationBootstrap
    typealias S = OriginalApplicationLoadedSelectionComparison
    typealias Stop = M.Stop
    struct Frontier { let application: A,input: M.S.Input.PendingContinuation }
    func sequence(_ reverse: Bool,
        onStart: (A,M.S.PendingMatchPrelude) throws -> Void = { _,_ in }) throws -> [Int:Frontier] {
        var app = try H().characterChain(reverse)
        let initial = try XCTUnwrap(app.session?.loadedOwners).match
        let r = try S(reverse,initial)
        var frontiers: [Int:Frontier] = [:],returns = 0
        for (index,item) in r.human.corpus.cases.enumerated() {
            try H.acquire(&app,item.acquired)
            let entry = try C.next(&app)
            var cycle = try app.makeLoadedCycle(pending:entry),input = C.InputEnvironment()
            let ready = try C.input(&cycle,&input),before = app
            XCTAssertEqual(input.phases,[Int32](repeating:Int32((index+1)%2),count:6))
            if [21,29,49].contains(index) { frontiers[index] = .init(application:app,input:ready) }
            var own = ready.match
            try own.globals.write(own.globals.integer(at:0x20,as:UInt32.self),at:0x4512cc-0x44d000)
            try r.entry(own,item)
            var menu = try M.S(pending:ready),env = M.Environment(reverse:reverse),point = 0,screenEvents = 0
            var body: OriginalMatchPreparation?,last: OriginalCharacterScreenCheckpoint?
            let outcome = try M.advanceUntilBoundary(&menu,&env,character:{ cp,model,e in
                try r.checkpoint(cp,model,own,item,point);point += 1;last = cp
                if point == item.screen.checkpoints.count { body = model;screenEvents = e.front.count }
            })
            XCTAssertEqual(point,item.screen.checkpoints.count)
            for cp in env.resourcePoints { try r.human.equal(cp.globals,own.globals,"selection cached startup") }
            XCTAssertEqual(env.resourcePoints.map { $0.phase.kind.rawValue },["prefix","complete"])
            try r.compareEvents(Array(env.front.prefix(screenEvents)),ready,item,index)
            let snapshot: M.S.Snapshot,graphics: [OriginalApplicationGraphics.Command]
            switch outcome {
            case .returned(let returned):
                XCTAssertEqual(item.screen.continuation,.returned);XCTAssertNotNil(item.returned)
                try H().returning(returned,body:XCTUnwrap(body),environment:env,screenEvents:screenEvents,reference:r.human,item:item)
                snapshot = returned.snapshot;graphics = returned.graphics
                try C.unchanged(app,before);try C.finish(&app,returned);returns += 1
                XCTAssertThrowsError(try C.finish(&app,returned))
            case .matchPrelude(let pending):
                XCTAssertEqual(index,49);XCTAssertEqual(item.screen.continuation,.matchPrelude);XCTAssertNil(item.returned)
                XCTAssertEqual(pending.confirmation,1)
                XCTAssertTrue(menu.pendingReturn == nil);XCTAssertTrue(menu.pendingMatchPrelude != nil)
                XCTAssertEqual(last?.pc,0x42cf8a);XCTAssertEqual(pending.locals,last?.locals)
                XCTAssertEqual(screenEvents,env.front.count);XCTAssertEqual(env.points.last,"matchPrelude")
                XCTAssertFalse(env.points.contains("heldCleared"));XCTAssertEqual(env.clock,0)
                let checked = try XCTUnwrap(body)
                try r.human.equal(pending.snapshot.match.globals,checked.globals,"pending prelude globals")
                try r.human.equal(r.human.pool(pending.snapshot.match),r.human.pool(checked),"pending prelude pool")
                try M.I.coherent(OriginalApplicationMatchBindings(pending:ready.entry),checked,pending.snapshot.state)
                let view = pending.snapshot.state,old = ready.state,actors = Set(ready.entry.actorTokens)
                XCTAssertEqual(Set(view.memory.allocations.keys),Set(old.memory.allocations.keys))
                for (token,value) in old.memory.allocations where !actors.contains(token) {
                    XCTAssertEqual(view.memory.allocations[token],value)
                }
                for range in [0xb440..<0xbb00,0xc2d8..<0xc3a8] {
                    XCTAssertEqual(Array(view.full.bytes[range]),Array(old.full.bytes[range]))
                    XCTAssertEqual(Array(view.full.defined[range]),Array(old.full.defined[range]))
                }
                XCTAssertEqual(view.memory.replayPointers,old.memory.replayPointers)
                XCTAssertEqual(view.front.bitmaps,old.front.bitmaps);XCTAssertEqual(view.screenBody,old.screenBody)
                XCTAssertEqual(view.settings,old.settings);XCTAssertEqual(view.libraryText.retainedDC,0x12345678)
                XCTAssertEqual(view.earlyScreen.bitmaps,old.earlyScreen.bitmaps)
                XCTAssertEqual(view.earlyScreen.surfaces,old.earlyScreen.surfaces)
                XCTAssertEqual(view.earlyScreen.retainedOperation,old.earlyScreen.retainedOperation)
                XCTAssertEqual(try checked.actors[0].integer(at:0xd1,as:UInt8.self),1)
                XCTAssertEqual(try checked.globals.integer(at:0x451268-0x44d000,as:UInt32.self),1)
                for (address,value): (Int,Int32) in [(0x44d020,1),(0x451160,0),(0x4512c8,3),(0x44d070,0),
                    (0x44d06c,0),(0x44d024,0),(0x44d028,0),(0x44d078,-53),(0x450bcc,35),(0x450c34,35)] {
                    XCTAssertEqual(try checked.globals.integer(at:address-0x44d000,as:Int32.self),value)
                }
                XCTAssertEqual(try (0..<8).map { try checked.globals.integer(at:0x451248-0x44d000+$0*4,as:Int32.self) },[17,21,36,37,32,41,18,31])
                let path = Array(checked.globals.bytes[(0x44eed0-0x44d000)...].prefix { $0 != 0 })
                XCTAssertEqual(path,Array("bgm\\stage5.wma".utf8))
                snapshot = pending.snapshot;graphics = pending.graphics
                try C.unchanged(app,before)
                let oldEnvironment = env
                XCTAssertThrowsError(try M.advanceUntilBoundary(&menu,&env)) { XCTAssertEqual($0 as? M.S.Boundary,.alreadyPrepared) }
                XCTAssertEqual(env,oldEnvironment)
                try onStart(app,pending)
            }
            XCTAssertEqual(snapshot.match.bitmaps,initial.bitmaps);XCTAssertEqual(snapshot.match.backgrounds,initial.backgrounds)
            XCTAssertEqual(snapshot.match.frameAllocations,initial.frameAllocations)
            XCTAssertEqual(snapshot.resources.bitmaps,ready.menuResources.bitmaps)
            XCTAssertEqual(snapshot.music.allocations,ready.music.allocations)
            XCTAssertEqual(snapshot.state.random,ready.state.random)
            XCTAssertEqual(env.index,-1);XCTAssertEqual(env.api,0);XCTAssertTrue(env.music.isEmpty)
            try M().compareGraphics(ready,snapshot,graphics,env)
        }
        XCTAssertEqual(returns,49);XCTAssertEqual(r.points,768)
        XCTAssertEqual(r.human.draws,349);XCTAssertEqual(r.human.sounds,3)
        print("Owned selection: 50 input entries / 49 Bootstrap returns / pending Start / 768 source body points / 35 own-table RNG draws / 349 draws / \(r.human.reads) current reads / \(r.human.blits) Blt; reverse=\(reverse)")
        return frontiers
    }
    func testOwnCountdownDistrictAndStartRetainTheActualApplication() throws {
        for reverse in [false,true] { _ = try sequence(reverse) }
    }
    func testSelectionAndPendingStartFailuresPreserveEarlierCommits() throws {
        let frontiers = try sequence(false)
        for (index,kind) in [(21,"random"),(21,"musicConfiguration"),(29,"textOut")] {
            let f = try XCTUnwrap(frontiers[index])
            var menu = try M.S(pending:f.input),env = M.Environment();let old = env
            XCTAssertThrowsError(try M.advanceUntilBoundary(&menu,&env,observeFront:{ e,_ in
                if e.kind == kind && (kind != "random" || e.arguments[5] == 6) { throw Stop.injected(kind) }
            })) { XCTAssertEqual($0 as? Stop,.injected(kind)) }
            XCTAssertEqual(env,old);XCTAssertTrue(menu.pendingReturn == nil);XCTAssertTrue(menu.pendingMatchPrelude == nil)
        }
        for (index,pc): (Int,UInt32) in [(21,0x42cf6c),(29,0x42e0d2),(49,0x42cf8a)] {
            let f = try XCTUnwrap(frontiers[index])
            var menu = try M.S(pending:f.input),env = M.Environment();let old = env
            XCTAssertThrowsError(try M.advanceUntilBoundary(&menu,&env,character:{ cp,_,_ in
                if cp.pc == pc { throw Stop.injected("selectionPoint") }
            })) { XCTAssertEqual($0 as? Stop,.injected("selectionPoint")) }
            XCTAssertEqual(env,old);XCTAssertTrue(menu.pendingReturn == nil);XCTAssertTrue(menu.pendingMatchPrelude == nil)
        }
        let f = try XCTUnwrap(frontiers[49])
        for stop in ["matchPrelude","commit"] {
            var menu = try M.S(pending:f.input),env = M.Environment(stop:stop);let old = env
            XCTAssertThrowsError(try M.advanceUntilBoundary(&menu,&env)) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            XCTAssertEqual(env,old);XCTAssertTrue(menu.pendingReturn == nil);XCTAssertTrue(menu.pendingMatchPrelude == nil)
        }
        // The return-only API rejects an unreturned Start transactionally.
        var legacy = try M.S(pending:f.input),env = M.Environment();let old = env
        XCTAssertThrowsError(try legacy.advance(inputs:OriginalApplicationMenuInputsTests.inputs.get(),environment:&env,
            screenInput:.init(dcResult:0,dc:0x12345678,methodResult:0,drawResults:[0],shellResult:33),outputInput:M.output(f.input.loading.target),
            allocate:{ try $2.allocate($0,$1) },bitmap:{ try $1.bitmap($0) },music:{ try $1.sound($0) },milliseconds:{ try $0.time() },
            observe:{ if case .front(let e) = $0 { $1.front.append(e) } })) {
            XCTAssertEqual($0 as? M.S.Boundary,.dependency("Match prelude requires retained continuation"))
        }
        XCTAssertEqual(env,old);XCTAssertTrue(legacy.pendingReturn == nil);XCTAssertTrue(legacy.pendingMatchPrelude == nil)
        guard case .matchPrelude(let retained) = try M.advanceUntilBoundary(&legacy,&env) else { throw Stop.unexpected("Lost Start") }
        XCTAssertEqual(retained.entry.loading.target,f.input.loading.target)
        XCTAssertEqual(retained.snapshot.state.random,f.input.state.random)
    }
}
