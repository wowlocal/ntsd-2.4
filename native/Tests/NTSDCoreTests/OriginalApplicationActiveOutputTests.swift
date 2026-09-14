import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveOutputTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveOutputProjection
    typealias P = Q.P
    typealias D = Q.D
    typealias M = OriginalApplicationLoadedMenuSession
    typealias G = OriginalApplicationCatalogGraphicsComparison
    typealias Stop = OriginalApplicationLoadedCycleTests.Stop
    func sequence(_ reverse: Bool) throws {
        let sourceCount = try OriginalApplicationActiveOutputSource(reverse).compare()
        var before: M.Snapshot?,endpoint: M.Snapshot?
        var earlier: [OriginalFrontScreenEvent] = [],front: [OriginalFrontScreenEvent] = [],prefix: [G.Event] = []
        var stages: [OriginalGameplayBody.Stage] = []
        var count = 0,events = 0,plays = 0,rollbacks = 0,retries = 0,currentPlays = 0
        var soundRollback = false
        try OriginalApplicationActiveLayoutTests().sequence(reverse,onBody:{ call,ready,event in
            if case .gameplayCheckpoint(let stage,_) = event { stages.append(stage) }
            switch event {
            case .front(let value):
                if before != nil { front.append(value) }
                else {
                    try P.require(endpoint == nil,"No effect after final output checkpoint")
                    earlier.append(value)
                }
            case .gameplayCheckpoint(.layout,let snapshot):
                try P.require(before == nil && endpoint == nil && front.isEmpty && prefix.isEmpty,"Single current layout predecessor")
                before = snapshot;prefix = try Q.journal(earlier,ready).graphics;earlier = []
            case .gameplay(.drawing(.output,_)):
                try P.require(before != nil && endpoint == nil,"Output family belongs to its interval")
            case .gameplay where before != nil:
                throw Stop.unexpected("Additional output gameplay family")
            case .gameplayCheckpoint(.output,let snapshot):
                let previous = try XCTUnwrap(before)
                var model = try Q(globals:previous.match.globals,drawing:D(previous.match,previous.state),liveSounds:Q.sounds(ready))
                if count == 0 { try Self.controls(model) }
                try model.advance(true)
                try D.compare(front,model.drawing.events,"Own complete output event sequence")
                let journal = try Q.journal(model.drawing.events,ready)
                try P.require(snapshot.operations == previous.operations+journal.operations,"Whole output chronological graphics/audio journal")
                prefix += journal.graphics
                var expected = previous.match;expected.globals = model.globals
                try I.sameMatch(snapshot.match,expected)
                var state = previous.state;try state.replace(0,expected.globals)
                state.libraryText = .init(retainedDC:0x12345678)
                var nonGraphics = snapshot.state;nonGraphics.graphics = state.graphics
                try I.sameState(nonGraphics,state)
                try P.require(snapshot.music.allocations == previous.music.allocations && snapshot.resources.bitmaps == previous.resources.bitmaps && snapshot.backgrounds == previous.backgrounds,"Output retained resource owners")
                try P.same(snapshot.local,previous.local,"Output retains menu-local record")
                count += 1;events += front.count;currentPlays = front.filter { $0.kind == "play" }.count;plays += currentPlays
                before = nil;endpoint = snapshot;front = []
            default:break
            }
        },onReturn:{ call,ready,result in
            let snapshot = try XCTUnwrap(endpoint)
            try P.require(stages == OriginalGameplayBody.Stage.allCases,"All19 stage contracts run in the actual complete order")
            try OriginalApplicationActiveLayoutTests.same(result.snapshot,snapshot)
            try P.require(snapshot.state.full.integer(at:0x4593a0-0x44d000,as:UInt32.self) != 2 && result.dispatcherResult == 1,"Own enclosing dispatcher result")
            let relation = try G(resources:[:],state:ready.state,graphics:ready.graphics)
            try P.require(result.graphics.count == ready.graphics.count+prefix.count,"Complete returned graphics extent, no unexamined suffix")
            try relation.compare(state:snapshot.state,graphics:result.graphics,events:prefix)
            if count == 1 {
                rollbacks += try Self.rollback(ready,result,snapshot,["seventh-blit","dispatcher","commit"]);retries += 1
            }
            if currentPlays >= 2 && !soundRollback {
                rollbacks += try Self.rollback(ready,result,snapshot,["eighth-sound"]);retries += 1;soundRollback = true
            }
            print("Owned active output: control=\(reverse), call=\(call.index), complete output records/events/owners/journal and return, 19 ordered stage comparisons; full original application OPEN")
            endpoint = nil;prefix = [];stages = []
        })
        try P.require(count == 48 && plays == 7 && events == 37825 && rollbacks == 4 && retries == 2 && soundRollback && before == nil && endpoint == nil && front.isEmpty && earlier.isEmpty && prefix.isEmpty && stages.isEmpty,"Complete own active output schedule")
        print("Owned active output comparison: control=\(reverse), \(sourceCount) source endpoints, \(count) own endpoints, \(events) own events, \(plays) plays, \(rollbacks) late rollbacks and \(retries) same-session retries; finite19 composition compared, full original application/match/game OPEN")
    }
    static func controls(_ input: Q) throws {
        var base = input
        for (count,pending) in [(400,0x457588),(80,0x453e10)] {
            for n in 0..<count { try base.globals.write(Int32(0),at:pending+4*n-0x44d000) }
        }
        let buffer = try XCTUnwrap(base.liveSounds.sorted().first)
        func compare(_ original: Q) throws -> Q {
            var expected = original;expected.drawing.events = [];expected.writes = [];try expected.drain()
            var actual = original.globals,events: [OriginalFrontScreenEvent] = []
            try OriginalQueuedSound.drain(globals:&actual) { e in events.append(.init(e.kind.rawValue,e.arguments));return -1 }
            try P.same(actual,expected.globals,"Controlled queue full bytes/masks")
            try D.compare(events,expected.drawing.events,"Controlled queue exact order and ignored failure results")
            return expected
        }
        for (master,right,left): (Int32,Int32,Int32) in [(100,30,70),(0,30,70),(-100,30,70),(100,-25,25),(100,.max,.max),(100,.min,-1),(.max,.max,1)] {
            var q = base
            for (at,value) in [(0x44eecc,Int32(1)),(0x44d000,master),(0x457588,Int32(2)),(0x452170,right),(0x457bc8,left)] { try q.globals.write(value,at:at-0x44d000) }
            try q.globals.write(buffer,at:0x452948-0x44d000)
            let result = try compare(q)
            try P.require(result.globals.integer(at:0x457588-0x44d000,as:Int32.self) == 0,"Positive flag always clears")
        }
        var ordered = base
        for (pending,right,left,buffers,n): (Int,Int,Int,Int,Int) in [(0x457588,0x452170,0x457bc8,0x452948,0),(0x457588,0x452170,0x457bc8,0x452948,399),(0x453e10,0x4554c8,0x4527e8,0x451db0,0),(0x453e10,0x4554c8,0x4527e8,0x451db0,79)] {
            for (at,value) in [(pending+4*n,Int32(1)),(right+4*n,Int32(50)),(left+4*n,Int32(50))] { try ordered.globals.write(value,at:at-0x44d000) }
            try ordered.globals.write(buffer,at:buffers+4*n-0x44d000)
        }
        let result = try compare(ordered)
        try P.require(result.drawing.events.filter { $0.kind == "queueWrite" }.map { $0.arguments[0] } == [0x457588,0x457bc4,0x453e10,0x453f4c],"Catalog before builtin, full extents, shared buffer not deduplicated")
        var masked = base
        masked.globals = try .init(bytes:base.globals.bytes,defined:.init(repeating:false,count:base.globals.bytes.count))
        try masked.globals.write(Int32(0),at:0x44eecc-0x44d000)
        _ = try compare(masked)
        var inactive = base,mask = base.globals.defined
        for at in [0x452170,0x457bc8,0x452948] { for n in 0..<4 { mask[at-0x44d000+n] = false } }
        inactive.globals = try .init(bytes:base.globals.bytes,defined:mask)
        try inactive.globals.write(Int32(-1),at:0x457588-0x44d000);_ = try compare(inactive)
        var silent = base,unknownBuffer = base.globals.defined
        for n in 0..<4 { unknownBuffer[0x452948-0x44d000+n] = false }
        silent.globals = try .init(bytes:base.globals.bytes,defined:unknownBuffer)
        for (at,value): (Int,Int32) in [(0x457588,1),(0x452170,-25),(0x457bc8,25)] { try silent.globals.write(value,at:at-0x44d000) }
        let cleared = try compare(silent)
        try P.require(cleared.drawing.events == [.init("queueWrite",[0x457588,0])],"Nonpositive sum clears without reading unknown buffer")
        var output = input;try output.advance(true)
        var reversed = output.drawing.events;reversed.swapAt(0,1)
        XCTAssertThrowsError(try D.compare(reversed,output.drawing.events,"Output event order discriminator"))
        var corrupted = output.drawing.events
        let index = try XCTUnwrap(corrupted.firstIndex { $0.read != nil }),read = try XCTUnwrap(corrupted[index].read)
        corrupted[index].read = .init(offset:read.offset,value:read.value,defined:!read.defined)
        XCTAssertThrowsError(try D.compare(corrupted,output.drawing.events,"Output bitmap defined mask discriminator"))
    }
    struct Environment: Equatable { var inOutput = false,sound = false;var blits = 0,methods = 0,observations = 0 }
    static func rollback(_ ready: OriginalApplicationInputSession.PendingContinuation,_ returned: M.PendingReturn,_ output: M.Snapshot,_ stops: [String]) throws -> Int {
        let input = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
        var session = try OriginalApplicationGameplaySession(pending:ready)
        for stop in stops {
            var env = Environment()
            XCTAssertThrowsError(try session.advance(environment:&env,outputInput:input,observe:{ event,e in
                e.observations += 1
                switch event {
                case .gameplayCheckpoint(.layout,_):e.inOutput = true
                case .front(let value) where e.inOutput:
                    if value.kind == "stage" && value.arguments == [0x419e60] { e.sound = true }
                    if value.kind == "blit" { e.blits += 1;if stop == "seventh-blit" && e.blits == 7 { throw Stop.injected(stop) } }
                    if e.sound && value.kind == "method" { e.methods += 1;if stop == "eighth-sound" && e.methods == 8 { throw Stop.injected(stop) } }
                    if stop == "dispatcher" && value.kind == "dispatcherWrite" { throw Stop.injected(stop) }
                case .gameplayCheckpoint(.output,let snapshot):try OriginalApplicationActiveLayoutTests.same(snapshot,output)
                default:break
                }
            },beforeCommit:{ _,_ in if stop == "commit" { throw Stop.injected(stop) } })) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            try P.require(env == Environment() && session.pendingReturn == nil,"Output failure rolls back buffered environment and publication")
            try I.sameState(session.entry.state,ready.state);try I.sameMatch(session.entry.match,ready.match)
        }
        var env = Environment();let retry = try session.advance(environment:&env,outputInput:input)
        try OriginalApplicationActiveLayoutTests.same(retry.snapshot,returned.snapshot)
        try P.require(retry.graphics == returned.graphics && retry.dispatcherResult == returned.dispatcherResult,"Output same-session retry full graphics and return")
        return stops.count
    }
    func testPrimaryOwnedOutputProjection() throws { try sequence(false) }
    func testControlOwnedOutputProjection() throws { try sequence(true) }
}
