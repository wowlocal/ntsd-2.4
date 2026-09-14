import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveNoticesTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveNoticesProjection
    typealias P = Q.P
    typealias M = OriginalApplicationLoadedMenuSession
    typealias Stop = OriginalApplicationLoadedCycleTests.Stop
    func sequence(_ reverse: Bool,onBody: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.Observation) throws -> Void)? = nil,onReturn: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.PendingReturn) throws -> Void)? = nil) throws {
        let sourceCount = try OriginalApplicationActiveNoticesSource(reverse).compare()
        var before: M.Snapshot?,endpoint: M.Snapshot?
        var count = 0,rollbacks = 0
        try OriginalApplicationActiveHUDTests().sequence(reverse,onBody:{ call,ready,event in
            switch event {
            case .gameplayCheckpoint(.hud,let snapshot):
                try P.require(before == nil && endpoint == nil,"Single actual HUD predecessor")
                try Q.requireNoOutput(snapshot.match.globals)
                before = snapshot
                if count == 0 { try Self.controls(snapshot.match) }
            case .gameplay(.drawing(.notices,_)):
                throw Stop.unexpected("Unexpected notice output or misplaced notice annotation")
            case .front where before != nil:
                throw Stop.unexpected("Unexpected primitive notice output")
            case .gameplay where before != nil:
                throw Stop.unexpected("Additional gameplay event inside notice interval")
            case .gameplayCheckpoint(.notices,let snapshot):
                let previous = try XCTUnwrap(before)
                try Self.same(snapshot,previous)
                before = nil;endpoint = snapshot;count += 1
            default:break
            }
            try onBody?(call,ready,event)
        },onReturn:{ call,ready,result in
            let snapshot = try XCTUnwrap(endpoint)
            if count == 1 { rollbacks += try Self.rollback(ready,result,snapshot) }
            print("Owned active notices: control=\(reverse), call=\(call.index), complete stage records/owners/journal, no events; later3 semantics OPEN")
            endpoint = nil
            try onReturn?(call,ready,result)
        })
        try P.require(count == 48 && rollbacks == 2 && before == nil && endpoint == nil,"Complete own notice sequence")
        print("Owned active notices comparison: control=\(reverse), \(sourceCount) source endpoints, \(count) own endpoints, no primitive effects, \(rollbacks) late rollbacks and 1 same-session retry; full tick/match/game OPEN")
    }
    static func same(_ actual: M.Snapshot,_ expected: M.Snapshot) throws {
        try I.sameMatch(actual.match,expected.match);try I.sameState(actual.state,expected.state)
        try P.require(actual.operations == expected.operations,"Notices complete chronological journal")
        try P.require(actual.music.allocations == expected.music.allocations && actual.resources.bitmaps == expected.resources.bitmaps && actual.backgrounds == expected.backgrounds,"Notices retained resource owners")
        // This is the menu caller's storage, not Body.Caller.formatter.
        try P.same(actual.local,expected.local,"Notices retains menu-local record")
    }
    static func controls(_ own: OriginalMatchPreparation) throws {
        let original = own.globals
        try Q.requireNoOutput(original)
        for (address,value) in [(0x450bec,Int32(-1)),(0x450c2c,1),(0x450c28,1),(0x450c28,2)] {
            var g = original;try g.write(value,at:address-0x44d000)
            XCTAssertThrowsError(try Q.requireNoOutput(g),"Selected notice cannot be silently omitted")
        }
        for address in [0x450bec,0x450c2c,0x450c28] {
            var mask = original.defined;mask[address-0x44d000] = false
            let unknown = try OriginalStateRecord(bytes:original.bytes,defined:mask)
            XCTAssertThrowsError(try Q.requireNoOutput(unknown),"Notice branch requires known causal word")
        }
        var independent = original
        try independent.write(Int32(-2),at:0x450c2c-0x44d000)
        try independent.write(Int32(-3),at:0x450c28-0x44d000)
        var mask = independent.defined
        for b in 0..<4 { mask[0x451160-0x44d000+b] = false }
        independent = try .init(bytes:independent.bytes,defined:mask)
        try Q.requireNoOutput(independent)
        var varied = own;varied.globals = independent
        for state in [own,varied] {
            let opaque = try OriginalStateRecord(bytes:(0..<340).map { UInt8(truncatingIfNeeded:$0*13+17) },defined:(0..<340).map { $0%3 == 0 })
            for backing: OriginalStateRecord? in [nil,opaque] {
                var local = backing
                try OriginalPostHUDNotices.apply(state:state,local:&local,dcResult:0,dc:0,
                    fillBacking:{ throw Stop.unexpected("Unread notice fill backing") },
                    resourceBitmap:{ _ in throw Stop.unexpected("Unused notice bitmap") },
                    performFill:{ _ in throw Stop.unexpected("Unused notice fill") },
                    performBlit:{ _ in throw Stop.unexpected("Unused notice blit") },
                    observe:{ _ in throw Stop.unexpected("No disabled notice event") })
                XCTAssertEqual(local,backing,"Unused optional/owned strings retain exact bytes and masks")
            }
        }
    }
    struct Environment: Equatable { var observations = 0 }
    static func rollback(_ ready: OriginalApplicationInputSession.PendingContinuation,_ returned: M.PendingReturn,_ notices: M.Snapshot) throws -> Int {
        let input = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
        var session = try OriginalApplicationGameplaySession(pending:ready)
        for stop in ["notices","commit"] {
            var environment = Environment()
            XCTAssertThrowsError(try session.advance(environment:&environment,outputInput:input,observe:{ event,e in
                e.observations += 1
                if case .gameplayCheckpoint(.notices,let snapshot) = event,stop == "notices" {
                    try same(snapshot,notices);throw Stop.injected(stop)
                }
            },beforeCommit:{ _,_ in if stop == "commit" { throw Stop.injected(stop) } })) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            try P.require(environment == Environment() && session.pendingReturn == nil,"Notice failure rolls back environment and return")
            try I.sameState(session.entry.state,ready.state);try I.sameMatch(session.entry.match,ready.match)
        }
        var environment = Environment()
        let retry = try session.advance(environment:&environment,outputInput:input)
        try same(retry.snapshot,returned.snapshot)
        try P.require(retry.graphics == returned.graphics,"Notice same-session retry complete graphics")
        return 2
    }
    func testPrimaryOwnedNoticesProjection() throws { try sequence(false) }
    func testControlOwnedNoticesProjection() throws { try sequence(true) }
}
