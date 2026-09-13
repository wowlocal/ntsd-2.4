import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationLoadedCharacterTests: XCTestCase {
    typealias C = OriginalApplicationLoadedCycleTests
    typealias M = OriginalApplicationLoadedMenuTests
    typealias A = OriginalApplicationBootstrap
    typealias R = OriginalApplicationLoadedCharacterComparison
    typealias Stop = M.Stop

    static func selected(_ reverse: Bool) throws -> (A,M.S.Input.PendingContinuation) {
        var (app,_) = try C.start(reverse)
        let state = try XCTUnwrap(app.session).state.full
        let status = try state.integer(at:0x450b4c-0x44d000,as:UInt32.self)
        let attack = try state.integer(at:0x44fb20-0x44d000+Int(status)*80+20,as:UInt32.self)
        for i in 0..<4 {
            if i == 1 { try C.key(&app,0x100,attack) }
            if i == 3 { try C.key(&app,0x101,attack) }
            let entry = try C.next(&app)
            var cycle = try app.makeLoadedCycle(pending:entry),input = C.InputEnvironment()
            let ready = try C.input(&cycle,&input)
            if i == 3 {
                XCTAssertEqual(try ready.match.actors[0].integer(at:0xd1,as:UInt8.self),1)
                XCTAssertEqual(try ready.match.globals.integer(at:0x20,as:Int32.self),3)
                return (app,ready)
            }
            var session = try M.S(pending:ready),env = M.Environment(reverse:reverse)
            let pending = try M.advance(&session,&env);try C.finish(&app,pending)
        }
        throw Stop.unexpected("Missing selected input")
    }
    static func acquire(_ app: inout A,_ acquired: [CharacterScreenReference.Acquired]) throws {
        for input in acquired {
            let state = try XCTUnwrap(app.session).state.full
            let status = try state.integer(at:0x450b4c-0x44d000+input.seat*4,as:UInt32.self)
            let config = 0x44fb20-0x44d000+Int(status)*80
            XCTAssertEqual(try state.integer(at:config,as:UInt32.self),0)
            let key = try state.integer(at:config+4+input.button*4,as:UInt32.self)
            XCTAssertEqual(input.address,0x455378+key)
            XCTAssertEqual(input.bytes,input.pressed ? "64" : "75")
            try C.key(&app,input.pressed ? 0x100 : 0x101,key)
        }
    }
    func testOwnedKeyboardCharacterChainsReachBothReadyThroughBootstrapReturns() throws {
        for reverse in [false,true] { _ = try characterChain(reverse) }
    }
    func characterChain(_ reverse: Bool) throws -> A {
            let r = try R(reverse)
            var (app,ready) = try Self.selected(reverse)
            let first = ready.match
            try r.catalogInputs(first)
            var portraitChecked = false
            for (index,item) in r.corpus.cases.enumerated() {
                if index == 0 { XCTAssertTrue(item.acquired.isEmpty);XCTAssertNil(item.cycle) }
                else {
                    try Self.acquire(&app,item.acquired)
                    let entry = try C.next(&app)
                    var cycle = try app.makeLoadedCycle(pending:entry),env = C.InputEnvironment()
                    ready = try C.input(&cycle,&env)
                    XCTAssertEqual(env.phases,[Int32](repeating:Int32((index+1)%2),count:6))
                }
                let before = app
                var own = ready.match
                XCTAssertEqual(try own.globals.integer(at:0x7c,as:UInt32.self),0)
                // Cached resource prefix unconditionally stores the current menu
                // as previous. This is expected data only, never a Native input.
                try own.globals.write(own.globals.integer(at:0x20,as:UInt32.self),at:0x4512cc-0x44d000)
                try r.entry(own,item)
                var session = try M.S(pending:ready),env = M.Environment(reverse:reverse),point = 0,screenEvents = 0
                var body: OriginalMatchPreparation?
                let returned = try M.advance(&session,&env,character:{ cp,model,e in
                    if cp.pc == 0x42e0b6 {
                        // Shared selection adds a pre-tail observation. These
                        // old34 cases have no intervening tail store.
                        let last = try XCTUnwrap(item.screen.checkpoints.last)
                        XCTAssertEqual(cp.locals,last.locals.reduce(into:[:]) { $0[Int($1.key)!] = $1.value })
                        try r.state(model,own,item.screen.before,last.state,"retained human pre-tail")
                        return
                    }
                    try r.checkpoint(cp,model,own,item,point);point += 1
                    if point == 12 { screenEvents = e.front.count;body = model }
                })
                XCTAssertEqual(point,12)
                XCTAssertEqual(env.resourcePoints.map { $0.phase.kind.rawValue },["prefix","complete"])
                for p in env.resourcePoints { try r.equal(p.globals,own.globals,"cached startup globals") }
                try r.events(Array(env.front.prefix(screenEvents)),ready,item)
                try self.returning(returned,body:XCTUnwrap(body),environment:env,screenEvents:screenEvents,reference:r,item:item)
                // The body post-state is the final checkpoint; the independently
                // recovered loading return then clears held without replaying input.
                XCTAssertEqual(try returned.snapshot.state.full.integer(at:0x457580-0x44d000,as:UInt32.self),0)
                try M.I.coherent(OriginalApplicationMatchBindings(pending:ready.entry),returned.snapshot.match,returned.snapshot.state)
                XCTAssertEqual(env.index,-1);XCTAssertEqual(env.api,0);XCTAssertTrue(env.music.isEmpty)
                XCTAssertEqual(returned.snapshot.resources.bitmaps,ready.menuResources.bitmaps)
                XCTAssertEqual(returned.snapshot.music.allocations,ready.music.allocations)
                XCTAssertEqual(returned.snapshot.match.frameAllocations,first.frameAllocations)
                XCTAssertEqual(returned.snapshot.match.backgrounds,first.backgrounds)
                try M().compareGraphics(returned,env)
                if !portraitChecked,let sourceDraw = item.screen.events.first(where:{ e in
                    e.kind == "draw" && r.catalog.bitmaps.contains { $0.address == e.arguments[0] }
                }) {
                    let bitmapIndex = try XCTUnwrap(r.catalog.bitmaps.firstIndex { $0.address == sourceDraw.arguments[0] })
                    try self.portrait(ready,parent:app,index:bitmapIndex)
                    portraitChecked = true
                }
                try C.unchanged(app,before);try C.finish(&app,returned)
                XCTAssertThrowsError(try C.finish(&app,returned))
                try OriginalApplicationBootstrapTests.sameStartup(XCTUnwrap(app.startup),XCTUnwrap(before.startup))
            }
            let final = try XCTUnwrap(app.session?.loadedOwners).match
            for (seat,ordinal) in [(0,17),(1,21)] {
                XCTAssertEqual(try final.globals.integer(at:0x451248-0x44d000+seat*4,as:Int32.self),Int32(ordinal))
                XCTAssertEqual(try final.globals.integer(at:0x451288-0x44d000+seat*4,as:Int32.self),3)
                XCTAssertEqual(try final.actors[seat].integer(at:0x368,as:UInt32.self),UInt32(ordinal))
                XCTAssertEqual(try final.actors[seat].integer(at:0x364,as:Int32.self),0)
            }
            XCTAssertEqual(try final.globals.integer(at:0x4512c8-0x44d000,as:Int32.self),0)
            XCTAssertEqual(try final.globals.integer(at:0x44d078-0x44d000,as:Int32.self),147)
            XCTAssertTrue(portraitChecked)
            XCTAssertEqual(r.points,408);XCTAssertEqual(r.draws,312);XCTAssertEqual(r.sounds,6)
            print("Owned character: 34 Bootstrap returns / \(r.points) source semantic checkpoints / \(r.draws) draws / \(r.reads) current reads / \(r.blits) Blt / 18 sound methods; reverse=\(reverse)")
            return app
    }
    func returning(_ returned: M.S.PendingReturn,body: OriginalMatchPreparation,environment: M.Environment,
                   screenEvents: Int,reference: R,item: CharacterScreenReference.Case) throws {
        let r = reference,view = returned.snapshot,entry = returned.entry
        let source = try XCTUnwrap(item.returned)
        // The two saved environments use distinct display modes. Validate
        // each complete source event against that source's current globals.
        XCTAssertEqual(source.events,[try Self.present(r.globals(source.before))])
        XCTAssertEqual(Array(environment.points.suffix(5)),source.checkpoints.map(\.kind))
        var expected = body
        try expected.globals.write(UInt32(0),at:0x457580-0x44d000)
        try r.equal(view.match.globals,expected.globals,"whole returned globals")
        try r.equal(r.pool(view.match),r.pool(expected),"whole returned pool")
        try M.I.coherent(OriginalApplicationMatchBindings(pending:entry.entry),expected,view.state)
        for range in [0xb440..<0xbb00,0xc2d8..<0xc3a8] {
            XCTAssertEqual(Array(view.state.full.bytes[range]),Array(entry.state.full.bytes[range]))
            XCTAssertEqual(Array(view.state.full.defined[range]),Array(entry.state.full.defined[range]))
        }
        let actors = Set(entry.entry.actorTokens)
        XCTAssertEqual(Set(view.state.memory.allocations.keys),Set(entry.state.memory.allocations.keys))
        for (token,value) in entry.state.memory.allocations where !actors.contains(token) {
            XCTAssertEqual(view.state.memory.allocations[token],value)
        }
        XCTAssertEqual(view.match.arithmeticPrecision,body.arithmeticPrecision);XCTAssertEqual(view.match.interface.bitmaps,body.interface.bitmaps)
        XCTAssertEqual(view.match.releasedBitmaps,body.releasedBitmaps);XCTAssertEqual(view.match.releasedBitmapOrder,body.releasedBitmapOrder)
        XCTAssertEqual(view.match.bitmaps,body.bitmaps);XCTAssertEqual(view.match.frameAllocations,body.frameAllocations)
        XCTAssertEqual(view.match.backgrounds,body.backgrounds)
        XCTAssertEqual(view.state.memory.replayPointers,entry.state.memory.replayPointers)
        XCTAssertEqual(view.state.libraryText.retainedDC,0x12345678)
        XCTAssertEqual(view.state.random,entry.state.random);XCTAssertEqual(view.state.front.bitmaps,entry.state.front.bitmaps)
        XCTAssertEqual(view.state.screenBody,entry.state.screenBody);XCTAssertEqual(view.state.settings,entry.state.settings)
        XCTAssertEqual(view.state.earlyScreen.bitmaps,entry.state.earlyScreen.bitmaps)
        XCTAssertEqual(view.state.earlyScreen.surfaces,entry.state.earlyScreen.surfaces)
        XCTAssertEqual(view.state.earlyScreen.retainedOperation,entry.state.earlyScreen.retainedOperation)
        XCTAssertEqual(Array(environment.front.dropFirst(screenEvents)),[try Self.present(expected.globals)])
        XCTAssertEqual(environment.clock,0)
    }
    static func present(_ globals: OriginalStateRecord) throws -> OriginalFrontScreenEvent {
        func word(_ address: Int) throws -> UInt32 { try globals.integer(at:address-0x44d000,as:UInt32.self) }
        let mode = try word(0x458348)
        if mode == 1 || mode == 2 { return try .init("method",[word(mode == 1 ? 0x453e0c : 0x455634),0x2c,0,1]) }
        guard mode == 3 else { throw Stop.unexpected("Unspecified character present mode") }
        return try .init("method",[word(0x455634),0x14,0x453ccc,word(0x455608),0,0x1000000,0],
            [Array(globals.bytes[0x453ccc-0x44d000..<0x453ccc-0x44d000+16])])
    }
    func portrait(_ ready: M.S.Input.PendingContinuation,parent: A,index: Int) throws {
        let token = ready.entry.entry.snapshot.bitmapTokens[index]
        var s = try M.S(pending:ready),env = M.Environment(),drawingPortrait = false;let old = env
        XCTAssertThrowsError(try M.advance(&s,&env,observeFront:{ e,_ in
            if e.kind == "draw" { drawingPortrait = e.arguments[0] == token }
            if drawingPortrait,e.kind == "blit" { throw Stop.injected("portrait") }
        })) { XCTAssertEqual($0 as? Stop,.injected("portrait")) }
        XCTAssertNil(s.pendingReturn);XCTAssertEqual(env,old)
        var model = ready.match
        // Controlled ownership sentinel: only current match bytes change. It
        // adds no original branch observation and never commits to the app.
        try model.backgroundLoader.resources.bitmaps[index].storage.write(Int32(-7),at:0xc)
        let changed = M.S.Input.PendingContinuation(entry:ready.entry,state:ready.state,match:model,
            inputContext:ready.inputContext,music:ready.music,commands:ready.commands,playbackCommands:ready.playbackCommands,
            paused:ready.paused,round:ready.round,operations:ready.operations,graphics:ready.graphics,loading:ready.loading,
            menuResources:ready.menuResources,menuBackgrounds:ready.menuBackgrounds)
        var current = try M.S(pending:changed),buffer = M.Environment(),inPortrait = false,observed = 0
        let pending = try M.advance(&current,&buffer,observeFront:{ e,_ in
            if e.kind == "draw" { inPortrait = e.arguments[0] == token }
            if inPortrait,let read = e.read,read.offset == 0xc {
                XCTAssertEqual(read.value,UInt32(bitPattern:-7));XCTAssertTrue(read.defined);observed += 1
            }
        })
        XCTAssertGreaterThan(observed,0)
        XCTAssertEqual(pending.snapshot.match.bitmaps[index].storage,model.bitmaps[index].storage)
        XCTAssertNotEqual(pending.snapshot.match.bitmaps[index].storage,ready.match.bitmaps[index].storage)
        XCTAssertEqual(try XCTUnwrap(parent.session?.loadedOwners).match.bitmaps[index],ready.match.bitmaps[index])
    }
    func testCharacterBodyAndOuterFailuresKeepPriorApplicationCommits() throws {
        let (parent,ready) = try Self.selected(false)
        for stop in [0,1,5,12] {
            var s = try M.S(pending:ready),env = M.Environment(),point = 0;let old = env
            XCTAssertThrowsError(try M.advance(&s,&env,character:{ _,_,_ in
                defer { point += 1 }
                if point == stop { throw Stop.injected("character\(stop)") }
            })) { XCTAssertEqual($0 as? Stop,.injected("character\(stop)")) }
            XCTAssertEqual(env,old);XCTAssertNil(s.pendingReturn)
            try C.unchanged(parent,parent)
        }
        for kind in ["textOut","method"] {
            var s = try M.S(pending:ready),env = M.Environment();let old = env
            XCTAssertThrowsError(try M.advance(&s,&env,observeFront:{ e,_ in
                if e.kind == kind { throw Stop.injected(kind) }
            })) { XCTAssertEqual($0 as? Stop,.injected(kind)) }
            XCTAssertEqual(env,old);XCTAssertNil(s.pendingReturn)
        }
        for stop in ["screen","matchBeforeReturn","heldCleared","commit"] {
            var s = try M.S(pending:ready),env = M.Environment(stop:stop);let old = env
            XCTAssertThrowsError(try M.advance(&s,&env)) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            XCTAssertEqual(env,old);XCTAssertNil(s.pendingReturn)
        }
        var session = try M.S(pending:ready),env = M.Environment();let returned = try M.advance(&session,&env)
        for stop in ["time","sleep","commit"] {
            var app = parent
            XCTAssertThrowsError(try C.finish(&app,returned,stop:stop)) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            try C.unchanged(app,parent)
        }
        // Retain the old controlled selection1 frontier with an observer
        // stop now that its computer/arena continuation is connected.
        var model = ready.match,state = ready.state
        try model.globals.write(Int32(1),at:0x20)
        try model.globals.write(Int32(1),at:0x4512c8-0x44d000)
        try state.replace(0,model.globals)
        let next = M.S.Input.PendingContinuation(entry:ready.entry,state:state,match:model,inputContext:ready.inputContext,
            music:ready.music,commands:ready.commands,playbackCommands:ready.playbackCommands,paused:ready.paused,round:ready.round,
            operations:ready.operations,graphics:ready.graphics,loading:ready.loading,menuResources:ready.menuResources,menuBackgrounds:ready.menuBackgrounds)
        var blocked = try M.S(pending:next),boundaryEnv = M.Environment();let oldBoundary = boundaryEnv
        XCTAssertThrowsError(try M.advance(&blocked,&boundaryEnv,character:{ cp,_,_ in
            if cp.pc == 0x42b296 { throw Stop.injected("selectionBoundary") }
        })) {
            XCTAssertEqual($0 as? Stop,.injected("selectionBoundary"))
        }
        XCTAssertNil(blocked.pendingReturn);XCTAssertEqual(boundaryEnv,oldBoundary)
        var app = parent;try C.finish(&app,returned)
        XCTAssertEqual(try app.session?.state.full.integer(at:0x20,as:Int32.self),1)
        XCTAssertThrowsError(try C.finish(&app,returned))
    }
}
