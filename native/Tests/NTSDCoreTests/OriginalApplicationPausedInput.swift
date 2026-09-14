import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

enum OriginalApplicationPausedInput {
    typealias X = OriginalApplicationPausedProjection
    typealias I = X.I
    typealias P = X.P
    typealias C = I.C
    typealias Ready = OriginalApplicationInputSession.PendingContinuation
    struct Environment {
        var model: I.Local?
        var phases: [OriginalLoadedMatchEntry.Checkpoint] = []
        var controls: [OriginalInputControlRequest] = []
        var requests = 0,replay = 0,round = 0
        var token: UInt32?
        var replayBefore: OriginalMenuPresentationMemory.Allocation?
        var replayAfter: OriginalMenuPresentationMemory.Allocation?
    }
    static func advance(_ cycle: inout OriginalApplicationLoadedCycleSession,_ call: Int,stop: String? = nil) throws -> Ready {
        let initial = cycle.entry.state,bindings = cycle.bindings
        let initialMatch = try bindings.read(initial,retaining:cycle.owners.match)
        let paused = try X.paused(I.prologue(initial.full))
        let order = OriginalApplicationActiveGameplayTests.order.filter { !paused || $0 != .localBeforeDispatch }
        let tick = try initial.full.integer(at:0x450b8c-0x44d000,as:Int32.self)
        var environment = Environment()
        do {
        let ready = try cycle.advance(environment:&environment,controlBoundary:{ q,e in
            try P.require(e.requests < e.controls.count && q == e.controls[e.requests],"Own exact paused input requests")
            try P.require(e.phases == Array(order.prefix(paused ? 1 : 2)) && e.replay == 0 && e.round == 0,"Pause control ordering")
            let n = e.requests;e.requests += 1
            return q.kind == .action ? .init() : .init(result:[-1,1,-1,0][n],bytes:n == 3 ? [120,86,52,18] : [])
        },replayEvent:{ event,e in
            try P.require(!paused && e.replay == 0 && e.round == 0 && e.phases == Array(order.prefix(4)),"Pause replay observation order")
            try P.require(event == .init(.writePacket,[UInt32(tick),try XCTUnwrap(e.token)],[[UInt8](repeating:0,count:10)]),"Own pause replay packet")
            e.replay += 1
        },roundEvent:{ event,e in
            var teams = [UInt32](repeating:0,count:40);teams[10] = 1;teams[11] = 1
            try P.require(!paused && e.replay == 1 && e.round == 0 && e.phases == Array(order.prefix(5)) && event == .init(.teams,teams),"Own pause round events")
            e.round += 1
        },prologue:{ match,state,cached,commands,playback,e in
            let zero = [UInt8](repeating:0,count:10)
            try P.require(cached == paused && commands == zero && playback == zero,"Pause own prologue buffers")
            var expected = initial;try expected.replace(0,I.prologue(initial.full))
            try I.sameState(state,expected);try C.M.I.coherent(bindings,match,state)
            let p = try P(match)
            e.model = try X.local(p.pool,p.globals,(0..<400).map(UInt32.init))
            e.controls = try X.control(XCTUnwrap(e.model).globals)
            let token = try state.memory.replayPointers.integer(at:0,as:UInt32.self)
            let before = try XCTUnwrap(state.memory.allocations[token])
            try P.require(before.live && before.storage.bytes.count == 0x630e18 && (17...22).contains(tick),"Own pause full replay owner")
            var after = before
            if !paused { for n in 0..<10 { try after.storage.write(UInt8(0),at:0x2b38+10*Int(tick)+n) } }
            e.token = token;e.replayBefore = before;e.replayAfter = after
        },checkpoint:{ phase,match,state,commands,e in
            try P.require(e.phases.count < order.count && phase == order[e.phases.count],"Own pause input checkpoint order")
            var projected = try XCTUnwrap(e.model);try X.inputStage(phase,&projected)
            try P.require(commands == projected.commands && commands == [UInt8](repeating:0,count:10),"Own neutral pause commands")
            let p = try P(match)
            try P.same(p.pool,projected.pool,"Own pause input full pool \(phase)")
            try P.same(p.globals,projected.globals,"Own pause input full globals \(phase)")
            try C.M.I.coherent(bindings,match,state)
            let token = try XCTUnwrap(e.token),allocation = phase == .replay || phase == .round ? e.replayAfter : e.replayBefore
            // Compare every non-Actor allocation and all non-model state. The
            // binding comparator independently checks the Actor aliases above.
            let actors = Set(bindings.actorTokens)
            for (address,record) in initial.memory.allocations where !actors.contains(address) {
                try P.require(state.memory.allocations[address] == (address == token ? allocation : record),"Pause full non-Actor allocation retention")
            }
            try P.require(state.memory.allocations.keys.sorted() == initial.memory.allocations.keys.sorted() && state.memory.replayPointers == initial.memory.replayPointers,"Pause exact memory identities/aliases")
            try P.require(state.libraryText == initial.libraryText && state.libraryHits == initial.libraryHits && state.libraryTransforms == initial.libraryTransforms && state.random == initial.random,"Pause input library/CRT retention")
            var expectedMatch = initialMatch
            func part(_ at: Int,_ size: Int) throws -> OriginalStateRecord {
                try .init(bytes:Array(projected.pool.bytes[at..<at+size]),defined:Array(projected.pool.defined[at..<at+size]))
            }
            expectedMatch.world = try part(0,0x7d8)
            expectedMatch.actors = try (0..<400).map { try part(0x7d8+$0*0x420,0x420) }
            expectedMatch.globals = projected.globals
            try I.sameMatch(match,expectedMatch)
            var expectedState = initial,context = try bindings.inputContext(initial)
            context.memory.allocations[token] = allocation
            try bindings.store(expectedMatch,context:context,in:&expectedState)
            try I.sameState(state,expectedState)
            e.model = projected;e.phases.append(phase)
            if phase.rawValue == stop { throw C.Stop.injected(phase.rawValue) }
        },beforeCommit:{ _,_ in if stop == "commit" { throw C.Stop.injected("commit") } })
        try P.require(environment.phases == order && environment.requests == environment.controls.count && environment.replay == (paused ? 0 : 1) && environment.round == (paused ? 0 : 1),"Complete paused input traversal")
        var operations = cycle.entry.stagedEffects.map(OriginalApplicationInputSession.Operation.menu)
        for (n,q) in environment.controls.enumerated() where q.kind != .action {
            operations.append(.control(q,.init(result:[-1,1,-1,0][n],bytes:n == 3 ? [120,86,52,18] : [])))
        }
        try P.require(ready.operations == operations,"Own complete pause input journal")
        try P.require(ready.paused == paused && ready.round.continuation == (paused ? .pausedRendering : .gameplay),"Own paused continuation")
        try P.require(ready.match.globals.integer(at:0x450b8c-0x44d000,as:Int32.self) == X.counters[call-1],"Own retained pause replay counter")
        return ready
        } catch {
            if cycle.pendingContinuation == nil {
                try P.require(environment.model == nil && environment.phases.isEmpty && environment.requests == 0 && environment.replay == 0 && environment.round == 0 && environment.token == nil,"Paused input environment rollback")
            }
            throw error
        }
    }
}
