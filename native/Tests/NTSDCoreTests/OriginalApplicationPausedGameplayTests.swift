import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationPausedGameplayTests: XCTestCase {
    typealias X = OriginalApplicationPausedProjection
    typealias I = X.I
    typealias P = X.P
    typealias D = X.D
    typealias Q = X.Q
    typealias C = I.C
    typealias N = OriginalApplicationGameplayProjectionTests
    typealias M = OriginalApplicationLoadedMenuSession
    typealias G = OriginalApplicationGameplaySession
    typealias Ready = OriginalApplicationInputSession.PendingContinuation
    struct Environment {
        var expected: P
        var front: [OriginalFrontScreenEvent] = []
        var other: [String] = []
        var operations: [M.Operation]
        var graphics: [OriginalApplicationCatalogGraphicsComparison.Event] = []
        var active: [OriginalGameplayBody.Stage] = []
        var paused: [OriginalPausedGameplay.Stage] = []
        var pauseEvents: [OriginalFrontScreenEvent] = []
        var endpoint: M.Snapshot?
        var count = 0
    }
    static func output(_ ready: Ready) -> OriginalMenuPresentationInput {
        .init(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,audioSetResult:0,
            queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
    }
    static func compare(_ snapshot: M.Snapshot,_ ready: Ready,_ e: inout Environment,
                        _ events: [OriginalFrontScreenEvent],_ textUsed: Bool) throws {
        try D.compare(e.front,events,"Own complete pause/resume front stream")
        let journal = try Q.journal(events,ready)
        e.operations += journal.operations;e.graphics += journal.graphics
        try P.require(snapshot.operations == e.operations,"Own pause/resume complete chronological journal")
        var match = ready.match
        match.globals = e.expected.globals;match.backgrounds = e.expected.backgrounds
        let pool = e.expected.pool
        func part(_ at: Int,_ size: Int) throws -> OriginalStateRecord {
            try .init(bytes:Array(pool.bytes[at..<at+size]),defined:Array(pool.defined[at..<at+size]))
        }
        match.world = try part(0,0x7d8);match.actors = try (0..<400).map { try part(0x7d8+$0*0x420,0x420) }
        try I.sameMatch(snapshot.match,match)
        var state = ready.state
        try OriginalApplicationMatchBindings(pending:ready.entry).store(match,context:ready.inputContext,in:&state)
        if textUsed { state.libraryText = .init(retainedDC:0x12345678) }
        var actual = snapshot.state;actual.graphics = state.graphics
        try I.sameState(actual,state)
        try C.M.I.coherent(OriginalApplicationMatchBindings(pending:ready.entry),snapshot.match,snapshot.state)
        try P.require(snapshot.local.bytes == [UInt8](repeating:0,count:0x704) && snapshot.local.defined == [Bool](repeating:false,count:0x704),"Pause menu-local backing remains unknown, separate from Caller.formatter")
        try P.require(snapshot.music.allocations == ready.music.allocations && snapshot.resources.bitmaps == ready.menuResources.bitmaps && snapshot.backgrounds == ready.menuBackgrounds,"Pause retained music/resource owners")
        e.front = [];e.other = [];e.count += 1;e.endpoint = snapshot
    }
    static func next(_ app: inout C.A) throws -> C.Session.PendingLoading {
        let before = try XCTUnwrap(app.session)
        let keys = I.keyboard(before.state.full)
        try P.require(before.state.full.integer(at:0x450bec-0x44d000,as:UInt32.self) == 0 && before.state.full.integer(at:0x4593a0-0x44d000,as:UInt32.self) == 0,"Finite pause outer diagnostics/mode")
        try P.require(keys.enumerated().allSatisfy { $0.element != 100 || [112,113].contains($0.offset) },"Only declared pause keys acquired")
        var full = before.state.full
        if keys[112] == 100 || keys[113] == 100 { try full.write(UInt32(0),at:0x4593a4-0x44d000) }
        let pending = try C.next(&app)
        try P.same(pending.state.full,full,"Whole outer key scan globals; diagnostics remain disabled")
        try P.require(I.keyboard(pending.state.full) == keys,"Outer scan does not consume pause keys")
        return pending
    }
    func sequence(_ reverse: Bool) throws {
        let source = try OriginalApplicationPausedSource(reverse)
        try N().sequence(reverse,onComplete:{ origin in
            let owners = try XCTUnwrap(origin.session?.loadedOwners)
            let sourceCount = try source.compare(owners.match.loadedObjects)
            var app = origin,messages = 0,paused = 0,stages = 0,events = 0,rollbacks = 0,retries = 0
            for index in 0..<14 {
                let call = source.document.corpus.cases[index]
                messages += try X.acquire(&app,index+1)
                let acquired = app,loading = try Self.next(&app)
                var inputRetry: Ready?
                if [0,2].contains(index) {
                    var failed = try app.makeLoadedCycle(pending:loading)
                    for stop in ["local","replay","commit"] {
                        XCTAssertThrowsError(try OriginalApplicationPausedInput.advance(&failed,index+1,stop:stop)) { XCTAssertEqual($0 as? C.Stop,.injected(stop)) }
                        try P.require(failed.pendingContinuation == nil,"No paused rejected input publication")
                        try I.sameState(failed.entry.state,loading.state);try I.unchanged(app,acquired)
                        rollbacks += 1
                    }
                    inputRetry = try OriginalApplicationPausedInput.advance(&failed,index+1)
                    retries += 1
                }
                var cycle = try app.makeLoadedCycle(pending:loading)
                let ready = try OriginalApplicationPausedInput.advance(&cycle,index+1)
                if let retry = inputRetry {
                    try I.sameState(retry.state,ready.state);try I.sameMatch(retry.match,ready.match)
                    try P.require(retry.commands == ready.commands && retry.playbackCommands == ready.playbackCommands && retry.paused == ready.paused && retry.round.continuation == ready.round.continuation && retry.round.stageDefeated == ready.round.stageDefeated,"Same input-session retry complete continuation")
                    try P.require(retry.operations == ready.operations && retry.graphics == ready.graphics && retry.inputContext.savedPlayback == ready.inputContext.savedPlayback && retry.inputContext.memory.allocations == ready.inputContext.memory.allocations && retry.inputContext.memory.replayPointers == ready.inputContext.memory.replayPointers,"Same input-session retry complete input owners and journal")
                    try P.require(retry.music.allocations == ready.music.allocations && retry.menuResources.bitmaps == ready.menuResources.bitmaps && retry.menuBackgrounds == ready.menuBackgrounds,"Same input-session retry retained resource owners")
                    try I.sameState(retry.loading.state,ready.loading.state);try I.sameState(retry.entry.state,ready.entry.state)
                    try I.unchanged(app,acquired)
                }
                try P.require(ready.paused == call.paused,"Own and saved pause schedule branches")
                let sections = call.paused ? [] : try source.sections(index)
                let drawing = try D(ready.match,ready.state)
                var e = Environment(expected:try P(ready.match),operations:ready.operations.map(M.Operation.preceding))
                var session = try G(pending:ready)
                let result = try session.advance(environment:&e,outputInput:Self.output(ready),observe:{ observation,e in
                    switch observation {
                    case .front(let event):e.front.append(event)
                    case .gameplay(let event):
                        try P.require(!ready.paused,"No simulation observation on pause")
                        switch event {
                        case .drawing,.impulses:break
                        case .hits(.random(let stream,let range,let value)):e.other.append("random:\(stream):\(range):\(value)")
                        case .lifecycle(.catalogSound(let slot,let x,let index)):e.other.append("sound:\(slot):\(x):\(index)")
                        default:throw C.Stop.unexpected("Pause finite unpaused event \(event)")
                        }
                    case .gameplayCheckpoint(let stage,let snapshot):
                        try P.require(!ready.paused && sections.indices.contains(e.active.count) && stage == sections[e.active.count].stage,"Resumed complete stage order")
                        let before = e.expected;var d = drawing
                        let expected: [OriginalFrontScreenEvent]
                        if stage == .output {
                            var q = Q(globals:before.globals,drawing:d,liveSounds:Q.sounds(ready));try q.advance(true)
                            e.expected.globals = q.globals;e.expected.sounds = [];e.expected.draw = nil
                            expected = q.drawing.events
                        } else {
                            try e.expected.advance(sections[e.active.count],sourceValues:false)
                            expected = try d.stage(stage,before,e.expected,ready.loading.target,installed:true)
                        }
                        try P.require(e.other == D.other(e.expected),"Resumed complete non-front events")
                        events += e.front.count
                        let textUsed = try XCTUnwrap(OriginalGameplayBody.Stage.allCases.firstIndex(of:stage)) >= XCTUnwrap(OriginalGameplayBody.Stage.allCases.firstIndex(of:.impulses))
                        try Self.compare(snapshot,ready,&e,expected,textUsed);e.active.append(stage)
                    default:throw C.Stop.unexpected("Unexpected pause application observation")
                    }
                },pausedObserve:{ stage,event,e in
                    try P.require(ready.paused && e.paused.count < OriginalPausedGameplay.Stage.allCases.count && stage == OriginalPausedGameplay.Stage.allCases[e.paused.count],"Paused event stage annotation")
                    e.pauseEvents.append(event)
                },pausedCheckpoint:{ stage,snapshot,e in
                    try P.require(ready.paused && e.active.isEmpty && e.paused.count < OriginalPausedGameplay.Stage.allCases.count && stage == OriginalPausedGameplay.Stage.allCases[e.paused.count],"Six ordered pause checkpoints")
                    try D.compare(e.pauseEvents,e.front,"Paused annotation is one observation of the same front stream")
                    var d = drawing
                    _ = try X.body(stage,&e.expected,&d,ready.loading.target,true,Q.sounds(ready))
                    events += e.front.count
                    try Self.compare(snapshot,ready,&e,d.events,stage == .output)
                    e.paused.append(stage);e.pauseEvents = []
                })
                try P.require(e.active == (ready.paused ? [] : OriginalGameplayBody.Stage.allCases) && e.paused == (ready.paused ? OriginalPausedGameplay.Stage.allCases : []) && e.front.isEmpty && e.other.isEmpty && e.pauseEvents.isEmpty,"Complete pause/resume traversal with no suffix")
                try OriginalApplicationActiveLayoutTests.same(result.snapshot,XCTUnwrap(e.endpoint))
                try P.require(result.dispatcherResult == 1 && result.graphics.count == ready.graphics.count+e.graphics.count,"Actual retained return and complete graphics extent")
                try OriginalApplicationCatalogGraphicsComparison(resources:[:],state:ready.state,graphics:ready.graphics).compare(state:result.snapshot.state,graphics:result.graphics,events:e.graphics)
                try P.require(result.snapshot.match.globals.integer(at:0x450bbc-0x44d000,as:Int32.self) == X.counters[index],"Own elapsed pause counter")
                if [0,2].contains(index) {
                    rollbacks += try Self.rollback(ready,result);retries += 1
                    for stop in ["time","sleep","commit"] {
                        XCTAssertThrowsError(try C.finish(&app,result,stop:stop)) { XCTAssertEqual($0 as? C.Stop,.injected(stop)) }
                        try I.unchanged(app,acquired);rollbacks += 1
                    }
                }
                try C.finish(&app,result)
                stages += e.count;if ready.paused { paused += 1 }
            }
            try P.require(messages == 6 && paused == 8 && stages == 162 && rollbacks == 18 && retries == 4,"Complete own pause schedule/rollback extent")
            print("Owned pause composition: control=\(reverse), \(sourceCount) source and \(stages) own endpoints, 14 retained Bootstrap returns, \(paused) paused, \(messages) explicit WndProc messages, \(events) exact own events, \(rollbacks) rollback checks/\(retries) same-session retries; full original application/match/game OPEN")
        })
    }
    static func rollback(_ ready: Ready,_ returned: M.PendingReturn) throws -> Int {
        var session = try G(pending:ready)
        for stop in ["dispatcher","checkpoint","commit"] {
            var environment = 0
            XCTAssertThrowsError(try session.advance(environment:&environment,outputInput:output(ready),observe:{ event,n in
                n += 1
                if case .front(let value) = event,stop == "dispatcher",value.kind == "dispatcherWrite" { throw C.Stop.injected(stop) }
                if case .gameplayCheckpoint(.output,_) = event,stop == "checkpoint" { throw C.Stop.injected(stop) }
            },pausedCheckpoint:{ stage,_,n in
                n += 1;if stage == .output && stop == "checkpoint" { throw C.Stop.injected(stop) }
            },beforeCommit:{ _,_ in if stop == "commit" { throw C.Stop.injected(stop) } })) { XCTAssertEqual($0 as? C.Stop,.injected(stop)) }
            try P.require(environment == 0 && session.pendingReturn == nil,"Late paused rollback environment/publication")
            try I.sameState(session.entry.state,ready.state);try I.sameMatch(session.entry.match,ready.match)
        }
        var environment = 0
        let retry = try session.advance(environment:&environment,outputInput:output(ready))
        try OriginalApplicationActiveLayoutTests.same(retry.snapshot,returned.snapshot)
        try P.require(retry.graphics == returned.graphics && retry.dispatcherResult == returned.dispatcherResult,"Same paused session retry full return")
        return 3
    }
    func testPrimaryOwnedPauseStepResume() throws { try sequence(false) }
    func testControlOwnedPauseStepResume() throws { try sequence(true) }
}
