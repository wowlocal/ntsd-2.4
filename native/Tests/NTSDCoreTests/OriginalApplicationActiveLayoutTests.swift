import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveLayoutTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveLayoutProjection
    typealias P = Q.P
    typealias M = OriginalApplicationLoadedMenuSession
    typealias Stop = OriginalApplicationLoadedCycleTests.Stop
    func sequence(_ reverse: Bool,onBody: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.Observation) throws -> Void)? = nil,onReturn: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.PendingReturn) throws -> Void)? = nil) throws {
        let sourceCount = try OriginalApplicationActiveLayoutSource(reverse).compare()
        var notices: M.Snapshot?,before: M.Snapshot?,endpoint: M.Snapshot?
        var count = 0,rollbacks = 0
        try OriginalApplicationActiveRecordingTests().sequence(reverse,onBody:{ call,ready,event in
            switch event {
            case .gameplayCheckpoint(.notices,let snapshot):
                notices = snapshot
            case .gameplayCheckpoint(.recording,let snapshot):
                try P.require(before == nil && endpoint == nil,"Single actual recording predecessor")
                _ = try Q.advance(snapshot.match.globals,continuation:Q.recordingEntry(snapshot.match.globals))
                before = snapshot
                if count == 0 { try Self.controls(try XCTUnwrap(notices),snapshot) }
            case .gameplay(.drawing(.layout,_)):
                throw Stop.unexpected("Unexpected or misplaced layout event")
            case .front where before != nil:
                throw Stop.unexpected("Unexpected primitive layout output")
            case .gameplay where before != nil:
                throw Stop.unexpected("Additional gameplay event inside layout interval")
            case .gameplayCheckpoint(.layout,let snapshot):
                let previous = try XCTUnwrap(before)
                var expected = previous.match;expected.globals = try Q.advance(previous.match.globals,continuation:Q.recordingEntry(previous.match.globals))
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
            print("Owned active layout: control=\(reverse), call=\(call.index), complete stage records/owners/journal, no events; later1 semantics OPEN")
            endpoint = nil
            try onReturn?(call,ready,result)
        })
        try P.require(count == 48 && rollbacks == 2 && before == nil && endpoint == nil,"Complete own layout sequence")
        print("Owned active layout comparison: control=\(reverse), \(sourceCount) source endpoints, \(count) own endpoints, no primitive effects, \(rollbacks) late rollbacks and 1 same-session retry; full tick/match/game OPEN")
    }
    static func same(_ actual: M.Snapshot,_ expected: M.Snapshot) throws {
        try I.sameMatch(actual.match,expected.match);try I.sameState(actual.state,expected.state)
        try owners(actual,expected)
    }
    static func owners(_ actual: M.Snapshot,_ expected: M.Snapshot) throws {
        try P.require(actual.operations == expected.operations,"Layout complete chronological journal")
        try P.require(actual.music.allocations == expected.music.allocations && actual.resources.bitmaps == expected.resources.bitmaps && actual.backgrounds == expected.backgrounds,"Layout retained resource owners")
        // This is the menu caller's storage, not Body.Caller.formatter.
        try P.same(actual.local,expected.local,"Layout retains menu-local record")
    }
    static func controls(_ notices: M.Snapshot,_ recording: M.Snapshot) throws {
        let original = recording.match.globals,flag = 0x450b84-0x44d000
        try P.same(Q.advance(original,continuation:.indicators),original,"Disabled layout exact identity")
        XCTAssertThrowsError(try Q.advance(original,continuation:.resultLayout),"Table cannot become no output")
        for value: Int32 in [1,-1,.min,.max] {
            var trial = original;try trial.write(value,at:flag)
            XCTAssertThrowsError(try Q.advance(trial,continuation:.indicators),"Any nonzero indicator requires its contract")
        }
        var mask = original.defined;mask[flag] = false
        let unknown = try OriginalStateRecord(bytes:original.bytes,defined:mask)
        XCTAssertThrowsError(try Q.advance(unknown,continuation:.indicators),"Indicator is causal")
        for (timer,entry): (Int32,OriginalResultRecording.Continuation) in [(100,.indicators),(101,.resultLayout),(349,.resultLayout),(350,.indicators),(.min,.indicators),(.max,.indicators)] {
            var trial = original;try trial.write(timer,at:0x450bdc-0x44d000)
            XCTAssertEqual(try Q.recordingEntry(trial),entry)
        }
        // Direct public composition uses current owned notices input. Its actual
        // recorder continuation is forwarded, never copied from a source endpoint.
        var own = notices.match
        var context = OriginalInputControlContext(savedPlayback:try OriginalApplicationMenuSession.State.slice(notices.state.full,0xb588,0x320),memory:notices.state.memory)
        let initialContext = context
        let result = try OriginalResultRecording.apply(state:&own,context:&context,stageDefeated:nil,
            allocate:{ throw Stop.unexpected("No layout predecessor codec allocation") },
            processorSignature:{ throw Stop.unexpected("No layout predecessor processor query") },
            open:{ _ in throw Stop.unexpected("No layout predecessor file open") },
            write:{ _ in throw Stop.unexpected("No layout predecessor file write") },
            close:{ throw Stop.unexpected("No layout predecessor file close") },
            observe:{ _ in throw Stop.unexpected("No layout predecessor event") })
        try I.sameMatch(own,recording.match)
        try P.require(result.continuation == Q.recordingEntry(recording.match.globals) && result.writer == nil,"Actual own recorder continuation and no writer")
        try P.require(context.memory.allocations == initialContext.memory.allocations && context.memory.replayPointers == initialContext.memory.replayPointers && context.savedPlayback == initialContext.savedPlayback,"Layout predecessor retains native replay context")
        // Poison only unread words. No zero value is supplied for missing backing.
        mask = own.globals.defined
        for address in [0x44d030,0x450bbc,0x451160,0x45116c,0x455608] { for b in 0..<4 { mask[address-0x44d000+b] = false } }
        own.globals = try .init(bytes:own.globals.bytes,defined:mask)
        let expected = own
        try P.same(Q.advance(own.globals,continuation:result.continuation),own.globals,"Disabled indicator skips playback and all unused reads")
        let opaque = try OriginalStateRecord(bytes:(0..<372).map { UInt8(truncatingIfNeeded:$0*37+11) },defined:(0..<372).map { $0%3 == 0 })
        for backing: OriginalStateRecord? in [nil,opaque] {
            var local = backing
            try OriginalResultLayout.apply(state:&own,context:context,continuation:result.continuation,
                stageDefeated:nil,indicatorTarget:nil,local:&local,dcResult:0,dc:0,
                surface:{ _ in throw Stop.unexpected("Disabled layout has no catalog surface") },
                resourceBitmap:{ _ in throw Stop.unexpected("Disabled layout has no bitmap read") },
                performBlit:{ _ in throw Stop.unexpected("Disabled layout has no Blt") },
                observe:{ _ in throw Stop.unexpected("Disabled layout has no event") })
            try I.sameMatch(own,expected)
            XCTAssertEqual(local,backing,"Unused formatter remains nil or byte/mask-identical")
        }
    }
    struct Environment: Equatable { var observations = 0 }
    static func rollback(_ ready: OriginalApplicationInputSession.PendingContinuation,_ returned: M.PendingReturn,_ layout: M.Snapshot) throws -> Int {
        let input = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
        var session = try OriginalApplicationGameplaySession(pending:ready)
        for stop in ["layout","commit"] {
            var environment = Environment()
            XCTAssertThrowsError(try session.advance(environment:&environment,outputInput:input,observe:{ event,e in
                e.observations += 1
                if case .gameplayCheckpoint(.layout,let snapshot) = event,stop == "layout" {
                    try same(snapshot,layout);throw Stop.injected(stop)
                }
            },beforeCommit:{ _,_ in if stop == "commit" { throw Stop.injected(stop) } })) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            try P.require(environment == Environment() && session.pendingReturn == nil,"Layout failure rolls back environment and return")
            try I.sameState(session.entry.state,ready.state);try I.sameMatch(session.entry.match,ready.match)
        }
        var environment = Environment()
        let retry = try session.advance(environment:&environment,outputInput:input)
        try same(retry.snapshot,returned.snapshot)
        try P.require(retry.graphics == returned.graphics,"Layout same-session retry complete graphics")
        return 2
    }
    func testPrimaryOwnedLayoutProjection() throws { try sequence(false) }
    func testControlOwnedLayoutProjection() throws { try sequence(true) }
}
