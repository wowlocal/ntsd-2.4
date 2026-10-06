import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// CORE_REALTIME 4d: a gameplay tick without drawing detail (the runtime's
/// setting: no observer consumes read, clip, draw or rectangle events) commits
/// exactly what the tick with detail commits, and observers see the same
/// events minus those four kinds.
final class OriginalGameplayDetailTests: XCTestCase {
    typealias M = OriginalApplicationLoadedMenuSession
    typealias P = OriginalApplicationActiveOutputProjection.P
    static let detailKinds: Set<String> = ["read","clip","draw","rectangle"]

    struct Run { var events: [String] = [],checkpoints: [M.Snapshot] = [],detail = 0 }
    static func record(_ observation: M.Observation,_ run: inout Run) {
        switch observation {
        case .front(let e) where detailKinds.contains(e.kind): run.detail += 1
        case .gameplay(.drawing(_,let e)) where detailKinds.contains(e.kind): run.detail += 1
        case .front(let e): run.events.append("front \(e)")
        case .gameplay(let g): run.events.append("gameplay \(g)")
        case .gameplayCheckpoint(let stage,let snapshot): run.events.append("checkpoint \(stage)");run.checkpoints.append(snapshot)
        default: run.events.append("other \(observation)")
        }
    }

    func compare(_ reverse: Bool) throws {
        var ticks = 0,detailEvents = 0
        try OriginalApplicationActiveLayoutTests().sequence(reverse,onReturn:{ _,ready,result in
            let input = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,
                audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
            func run(_ detail: Bool) throws -> (M.PendingReturn,Run) {
                var session = try OriginalApplicationGameplaySession(pending:ready),run = Run()
                let returned = try session.advance(environment:&run,outputInput:input,observe:{ o,r in Self.record(o,&r) },detail:detail)
                return (returned,run)
            }
            let (full,withDetail) = try run(true),(plain,withoutDetail) = try run(false)
            // The detail run reproduces the driver's tick.
            try OriginalApplicationActiveLayoutTests.same(full.snapshot,result.snapshot)
            try P.require(full.graphics == result.graphics && full.dispatcherResult == result.dispatcherResult,"Detail run equals the driver")
            // Without detail: the same tick, the same other events in the same order.
            try OriginalApplicationActiveLayoutTests.same(plain.snapshot,full.snapshot)
            try P.require(plain.graphics == full.graphics && plain.dispatcherResult == full.dispatcherResult,"Same graphics and result")
            XCTAssertEqual(withoutDetail.events,withDetail.events)
            XCTAssertEqual(withoutDetail.detail,0,"No detail events without detail")
            XCTAssertEqual(withoutDetail.checkpoints.count,withDetail.checkpoints.count)
            for (a,b) in zip(withoutDetail.checkpoints,withDetail.checkpoints) { try OriginalApplicationActiveLayoutTests.same(a,b) }
            ticks += 1;detailEvents += withDetail.detail
        })
        XCTAssertGreaterThan(ticks,0)
        XCTAssertGreaterThan(detailEvents,ticks,"The detail runs observed detail events")
    }
    func testPrimaryOwnedTicksWithoutDetail() throws { try compare(false) }
    func testControlOwnedTicksWithoutDetail() throws { try compare(true) }
}
