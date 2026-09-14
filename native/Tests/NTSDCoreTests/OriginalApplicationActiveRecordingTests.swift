import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveRecordingTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveRecordingProjection
    typealias P = Q.P
    typealias M = OriginalApplicationLoadedMenuSession
    typealias Stop = OriginalApplicationLoadedCycleTests.Stop
    func sequence(_ reverse: Bool,onBody: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.Observation) throws -> Void)? = nil,onReturn: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.PendingReturn) throws -> Void)? = nil) throws {
        let sourceCount = try OriginalApplicationActiveRecordingSource(reverse).compare()
        var before: M.Snapshot?,endpoint: M.Snapshot?
        var count = 0,rollbacks = 0
        try OriginalApplicationActiveNoticesTests().sequence(reverse,onBody:{ call,ready,event in
            switch event {
            case .gameplayCheckpoint(.notices,let snapshot):
                try P.require(before == nil && endpoint == nil,"Single actual notices predecessor")
                _ = try Q.advance(snapshot.match.globals)
                before = snapshot
                if count == 0 { try Self.controls(snapshot) }
            case .gameplay(.recording(_)):
                throw Stop.unexpected("Unexpected or misplaced recording event")
            case .front where before != nil:
                throw Stop.unexpected("Unexpected primitive recording output")
            case .gameplay where before != nil:
                throw Stop.unexpected("Additional gameplay event inside recording interval")
            case .gameplayCheckpoint(.recording,let snapshot):
                let previous = try XCTUnwrap(before)
                var expected = previous.match;expected.globals = try Q.advance(previous.match.globals)
                try I.sameMatch(snapshot.match,expected)
                var state = previous.state;try state.replace(0,expected.globals)
                try I.sameState(snapshot.state,state)
                try Self.owners(snapshot,previous)
                before = nil;endpoint = snapshot;count += 1
            default:break
            }
            try onBody?(call,ready,event)
        },onReturn:{ call,ready,result in
            let snapshot = try XCTUnwrap(endpoint)
            if count == 1 { rollbacks += try Self.rollback(ready,result,snapshot) }
            print("Owned active recording: control=\(reverse), call=\(call.index), complete stage records/owners/journal, no events; later2 semantics OPEN")
            endpoint = nil
            try onReturn?(call,ready,result)
        })
        try P.require(count == 48 && rollbacks == 2 && before == nil && endpoint == nil,"Complete own recording sequence")
        print("Owned active recording comparison: control=\(reverse), \(sourceCount) source endpoints, \(count) own endpoints, no primitive effects, \(rollbacks) late rollbacks and 1 same-session retry; full tick/match/game OPEN")
    }
    static func same(_ actual: M.Snapshot,_ expected: M.Snapshot) throws {
        try I.sameMatch(actual.match,expected.match);try I.sameState(actual.state,expected.state)
        try owners(actual,expected)
    }
    static func owners(_ actual: M.Snapshot,_ expected: M.Snapshot) throws {
        try P.require(actual.operations == expected.operations,"Recording complete chronological journal")
        try P.require(actual.music.allocations == expected.music.allocations && actual.resources.bitmaps == expected.resources.bitmaps && actual.backgrounds == expected.backgrounds,"Recording retained resource owners")
        // This is the menu caller's storage, not Body.Caller.formatter.
        try P.same(actual.local,expected.local,"Recording retains menu-local record")
    }
    static func controls(_ snapshot: M.Snapshot) throws {
        let original = snapshot.match.globals,elapsedOffset = 0x450bbc-0x44d000,timerOffset = 0x450bdc-0x44d000
        for (timer,increment): (Int32,Bool) in [(99,true),(100,false),(350,false),(.min,true),(.max,false)] {
            var before = original;try before.write(timer,at:timerOffset);try before.write(Int32.max,at:elapsedOffset)
            let after = try Q.advance(before)
            var expected = before
            if increment { try expected.write(Int32.min,at:elapsedOffset) }
            try P.same(after,expected,"Signed result timer and counter wrap, all bytes/masks")
        }
        for timer: Int32 in [101,349] {
            var before = original;try before.write(timer,at:timerOffset)
            XCTAssertThrowsError(try Q.advance(before),"Result-table continuation cannot be silently skipped")
        }
        for offset in [timerOffset,elapsedOffset] {
            var mask = original.defined;mask[offset] = false
            let unknown = try OriginalStateRecord(bytes:original.bytes,defined:mask)
            XCTAssertThrowsError(try Q.advance(unknown),"Recording causal word must be known")
        }
        var unread = original;try unread.write(Int32(100),at:timerOffset)
        var mask = unread.defined;mask[elapsedOffset] = false
        unread = try .init(bytes:unread.bytes,defined:mask)
        try P.same(Q.advance(unread),unread,"Timer100 does not read or define elapsed")
        var own = snapshot.match
        mask = own.globals.defined
        for address in [0x451160,0x450be4,0x450b80,0x450b84] { for b in 0..<4 { mask[address-0x44d000+b] = false } }
        own.globals = try .init(bytes:own.globals.bytes,defined:mask)
        var expected = own;expected.globals = try Q.advance(own.globals)
        // Native application layout, not source stack or expected replay backing.
        var context = OriginalInputControlContext(savedPlayback:try OriginalApplicationMenuSession.State.slice(snapshot.state.full,0xb588,0x320),memory:snapshot.state.memory)
        let beforeContext = context
        let result = try OriginalResultRecording.apply(state:&own,context:&context,stageDefeated:nil,
            allocate:{ throw Stop.unexpected("No recording codec allocation") },
            processorSignature:{ throw Stop.unexpected("No recording processor query") },
            open:{ _ in throw Stop.unexpected("No recording file open") },
            write:{ _ in throw Stop.unexpected("No recording file write") },
            close:{ throw Stop.unexpected("No recording file close") },
            observe:{ _ in throw Stop.unexpected("No recording event") })
        try P.require(result.continuation.rawValue == Q.continuation,"Public recorder chooses indicator continuation")
        XCTAssertNil(result.writer)
        try I.sameMatch(own,expected)
        try P.require(context.memory.allocations == beforeContext.memory.allocations && context.memory.replayPointers == beforeContext.memory.replayPointers && context.savedPlayback == beforeContext.savedPlayback,"No-writer public call retains current own replay context")
    }
    struct Environment: Equatable { var observations = 0 }
    static func rollback(_ ready: OriginalApplicationInputSession.PendingContinuation,_ returned: M.PendingReturn,_ recording: M.Snapshot) throws -> Int {
        let input = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
        var session = try OriginalApplicationGameplaySession(pending:ready)
        for stop in ["recording","commit"] {
            var environment = Environment()
            XCTAssertThrowsError(try session.advance(environment:&environment,outputInput:input,observe:{ event,e in
                e.observations += 1
                if case .gameplayCheckpoint(.recording,let snapshot) = event,stop == "recording" {
                    try same(snapshot,recording);throw Stop.injected(stop)
                }
            },beforeCommit:{ _,_ in if stop == "commit" { throw Stop.injected(stop) } })) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            try P.require(environment == Environment() && session.pendingReturn == nil,"Recording failure rolls back environment and return")
            try I.sameState(session.entry.state,ready.state);try I.sameMatch(session.entry.match,ready.match)
        }
        var environment = Environment()
        let retry = try session.advance(environment:&environment,outputInput:input)
        try same(retry.snapshot,returned.snapshot)
        try P.require(retry.graphics == returned.graphics,"Recording same-session retry complete graphics")
        return 2
    }
    func testPrimaryOwnedRecordingProjection() throws { try sequence(false) }
    func testControlOwnedRecordingProjection() throws { try sequence(true) }
}
