import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Full retained application preflight. Acquisition/local input compare against
/// saved evidence; active body equivalence remains explicitly unaccepted.
final class OriginalApplicationActiveGameplayTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias P = I.P
    typealias C = OriginalApplicationLoadedCycleTests
    typealias G = OriginalApplicationGameplaySession
    typealias N = OriginalApplicationGameplayProjectionTests
    struct InputEnvironment {
        var projected: I.Local?
        var phases: [OriginalLoadedMatchEntry.Checkpoint] = []
        var requests = 0
        var replayToken: UInt32?
        var replayBefore: OriginalMenuPresentationMemory.Allocation?
        var replayAfter: OriginalMenuPresentationMemory.Allocation?
        var replayEvents = 0,roundEvents = 0
    }
    static let order: [OriginalLoadedMatchEntry.Checkpoint] = [.localBeforeDispatch,.local,.control,.received,.replay,.round]
    static func input(_ cycle: inout OriginalApplicationLoadedCycleSession,
                      _ source: ContinuousGameplayReference.Case,stop: String? = nil) throws -> OriginalApplicationInputSession.PendingContinuation {
        let bindings = cycle.bindings,initial = cycle.entry.state,globals = cycle.entry.state.full
        let initialOperations = cycle.entry.stagedEffects.map(OriginalApplicationInputSession.Operation.menu)
        func word(_ address: Int) throws -> UInt32 { try globals.integer(at:address-0x44d000,as:UInt32.self) }
        let expected: [OriginalInputControlRequest] = try [
            .init(.asyncSelect,[word(0x44f1b4),word(0x4546f4),0,0]),.init(.asyncSelect,[word(0x44f46c),word(0x4546f4),0,0]),
            .init(.ioctl,[word(0x44f1b4),0x8004667e,0]),.init(.ioctl,[word(0x44f46c),0x8004667e,1],[[0,0,0,0]])]
        var env = InputEnvironment()
        do {
            let result = try cycle.advance(environment:&env,controlBoundary:{ q,e in
                try P.require(e.requests < expected.count && q == expected[e.requests],"Active input API order")
                try P.require(e.phases == Array(order.prefix(2)) && e.replayEvents == 0 && e.roundEvents == 0,"Control requests precede replay/round")
                let n = e.requests;e.requests += 1
                return .init(result:[-1,1,-1,0][n],bytes:n == 3 ? [120,86,52,18] : [])
            },replayEvent:{ event,e in
                let packet = try XCTUnwrap(e.projected).commands,token = try XCTUnwrap(e.replayToken)
                try P.require(e.replayEvents == 0 && e.roundEvents == 0 && e.phases == Array(order.prefix(4)),"Ordered active replay observation")
                try P.require(event == .init(.writePacket,[UInt32(16+source.index),token],[packet]),"Own recording event arguments")
                e.replayEvents += 1
            },roundEvent:{ event,e in
                var teams = [UInt32](repeating:0,count:40);teams[10] = 1;teams[11] = 1
                try P.require(e.replayEvents == 1 && e.roundEvents == 0 && e.phases == Array(order.prefix(5)),"Ordered active team observation")
                try P.require(event == .init(.teams,teams),"Own complete team observation")
                e.roundEvents += 1
            },prologue:{ model,state,paused,commands,playback,e in
                try P.require(!paused && commands == [UInt8](repeating:0,count:10) && playback == commands,"Active fresh call prologue")
                try P.require(model.globals.integer(at:0x450b90-0x44d000,as:UInt32.self) == source.cycle.prefix.phase,"Active phase agrees with retained source schedule")
                var expectedState = initial
                try expectedState.replace(0,I.prologue(globals))
                try I.sameState(state,expectedState)
                try C.M.I.coherent(bindings,model,state)
                let p = try P(model)
                for slot in 0..<2 { try P.require(p.h(slot,0x6f8) == 0,"Round fighter Object type") }
                e.projected = try I.local(pool:p.pool,globals:p.globals,actorTokens:(0..<400).map(UInt32.init))
                let token = try state.memory.replayPointers.integer(at:0,as:UInt32.self)
                let before = try XCTUnwrap(state.memory.allocations[token])
                let tick = try model.globals.integer(at:0x450b8c-0x44d000,as:Int32.self)
                try P.require(before.live && before.storage.bytes.count == 0x630e18 && tick == 16+source.index,"Own recording owner/tick")
                // REPLAY_TICK: these ticks do not touch a checksum cell. Preserve
                // the entire allocation including metadata and future packets.
                var after = before
                let packet = try XCTUnwrap(e.projected).commands
                for n in 0..<10 { try after.storage.write(packet[n],at:0x2b38+10*Int(tick)+n) }
                e.replayToken = token;e.replayBefore = before;e.replayAfter = after
            },checkpoint:{ phase,model,state,commands,e in
                try P.require(e.phases.count < order.count && phase == order[e.phases.count],"Active input checkpoint order")
                var expected = try XCTUnwrap(e.projected)
                try P.require(commands == expected.commands && commands == source.cycle.local.commandsAfter,"Own/source complete active command packets")
                try I.inputStage(phase,&expected)
                let p = try P(model)
                try P.same(p.pool,expected.pool,"Own full input pool \(phase)")
                try P.same(p.globals,expected.globals,"Own full input globals \(phase)")
                e.projected = expected
                try C.M.I.coherent(bindings,model,state)
                let recording = state.memory.allocations[try XCTUnwrap(e.replayToken)]
                try P.require(recording == (phase == .replay || phase == .round ? e.replayAfter : e.replayBefore),"Complete active recording allocation at \(phase)")
                e.phases.append(phase)
                if phase.rawValue == stop { throw C.Stop.injected(phase.rawValue) }
            },beforeCommit:{ _,_ in if stop == "commit" { throw C.Stop.injected("commit") } })
            try P.require(env.phases == order && env.requests == (source.cycle.prefix.phase == 0 ? 4 : 0),"Whole active input traversal")
            try P.require(env.replayEvents == 1 && env.roundEvents == 1,"Complete input semantic event stream")
            var operations = initialOperations
            for n in 0..<env.requests { operations.append(.control(expected[n],.init(result:[-1,1,-1,0][n],bytes:n == 3 ? [120,86,52,18] : []))) }
            try P.require(result.operations == operations,"Complete active input journal")
            try P.require(result.round.continuation == .gameplay && !result.paused,"Own active gameplay branch")
            return result
        } catch {
            if cycle.pendingContinuation == nil {
                try P.require(env.projected == nil && env.phases.isEmpty && env.requests == 0 && env.replayEvents == 0 && env.roundEvents == 0 && env.replayToken == nil && env.replayBefore == nil && env.replayAfter == nil,"Rejected input environment rollback")
            }
            throw error
        }
    }
    struct BodyEnvironment {
        var stages: [OriginalGameplayBody.Stage] = []
        var events: [String] = []
        var fronts = 0
    }
    func sequence(_ reverse: Bool) throws {
        let source = try I(reverse)
        var sourceHeld = Set<UInt32>()
        // Independent saved-data checks precede the application candidate.
        for index in 0..<48 {
            try source.sourceAcquisition(index,&sourceHeld);try source.sourceLocal(index);try source.sourceReplay(index)
        }
        try N().sequence(reverse,onComplete:{ origin in
            var app = origin,held = Set<UInt32>(),messages = 0,stages = 0
            for index in 0..<48 {
                let call = source.document.corpus.cases[index]
                messages += try I.acquire(&app,I.A.schedule[index],&held)
                let acquired = app,loading = try C.next(&app)
                var cycle = try app.makeLoadedCycle(pending:loading)
                if [0,16,47].contains(index) {
                    for stop in ["local","replay","commit"] {
                        var failed = try app.makeLoadedCycle(pending:loading)
                        XCTAssertThrowsError(try Self.input(&failed,call,stop:stop)) { XCTAssertEqual($0 as? C.Stop,.injected(stop)) }
                        try P.require(failed.pendingContinuation == nil,"No rejected input publication")
                        try I.sameState(failed.entry.state,loading.state)
                        try P.require(I.keyboard(XCTUnwrap(app.session).state.full) == I.keyboard(XCTUnwrap(acquired.session).state.full),"Acquisition survives rejected input")
                    }
                }
                let ready = try Self.input(&cycle,call)
                var session = try G(pending:ready),env = BodyEnvironment()
                let presentation = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,
                    audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
                let result = try session.advance(environment:&env,outputInput:presentation,observe:{ event,e in
                    switch event {
                    case .front:e.fronts += 1
                    case .gameplay(let value):
                        switch value {
                        case .drawing,.impulses:break
                        default:e.events.append(String(describing:value))
                        }
                    case .gameplayCheckpoint(let stage,let snapshot):
                        try P.require(e.stages.count < OriginalGameplayBody.Stage.allCases.count && stage == OriginalGameplayBody.Stage.allCases[e.stages.count],"Complete active body stage order")
                        try C.M.I.coherent(OriginalApplicationMatchBindings(pending:ready.entry),snapshot.match,snapshot.state)
                        let token = try ready.state.memory.replayPointers.integer(at:0,as:UInt32.self)
                        try P.require(snapshot.state.memory.replayPointers == ready.state.memory.replayPointers && snapshot.state.memory.allocations[token] == ready.state.memory.allocations[token],"Active body retains input recording")
                        e.stages.append(stage)
                    default:throw C.Stop.unexpected("Non-gameplay observation in active body")
                    }
                })
                try P.require(env.stages == OriginalGameplayBody.Stage.allCases,"Whole active body return")
                if [0,16,47].contains(index) {
                    var failed = try G(pending:ready),tentative = 0
                    XCTAssertThrowsError(try failed.advance(environment:&tentative,outputInput:presentation,observe:{ _,n in n += 1 },beforeCommit:{ _,_ in throw C.Stop.injected("body") })) { XCTAssertEqual($0 as? C.Stop,.injected("body")) }
                    try P.require(failed.pendingReturn == nil && tentative == 0,"Active body late rollback")
                    try I.sameState(failed.entry.state,ready.state)
                    try I.unchanged(app,acquired)
                    var retry = try app.makeLoadedCycle(pending:loading)
                    let repeated = try Self.input(&retry,call)
                    try I.sameState(repeated.state,ready.state)
                    try I.sameMatch(repeated.match,ready.match)
                    for stop in ["time","sleep","commit"] {
                        let parent = app
                        XCTAssertThrowsError(try C.finish(&app,result,stop:stop)) { XCTAssertEqual($0 as? C.Stop,.injected(stop)) }
                        try I.unchanged(app,parent)
                        try I.unchanged(app,acquired)
                    }
                }
                try C.finish(&app,result);stages += env.stages.count
                let p = try P(result.snapshot.match)
                let actors = try (0..<400).filter { try p.pool.integer(at:4+$0,as:UInt8.self) != 0 }
                let fighters = try (0..<2).map { slot in try ["slot":Int32(slot),"x":p.i(slot,0x10),"y":p.i(slot,0x14),"z":p.i(slot,0x18),"frame":p.i(slot,0x70),"hp":p.i(slot,0x2fc),"mp":p.i(slot,0x308)] }
                let row: [String:Any] = ["control":reverse,"call":index+1,"fighters":fighters,"activeSlots":actors,
                    "rng":[try p.g(0x450bcc),try p.g(0x450c34)],"events":env.events,"frontEvents":env.fronts,
                    "bodyDifferentialAccepted":false]
                print("Owned active preflight "+String(decoding:try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]),as:UTF8.self))
            }
            try P.require(held.isEmpty && stages == 48*19,"Own complete active schedule")
            print("Owned active input/preflight: control=\(reverse), 48 Bootstrap returns, \(messages) WndProc transitions, \(stages) body stages; local input compared, active body differential OPEN")
        })
    }
    func testPrimaryOwnedActiveInputAndBodyPreflight() throws { try sequence(false) }
    func testControlOwnedActiveInputAndBodyPreflight() throws { try sequence(true) }
}
