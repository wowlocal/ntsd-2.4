import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActivePhysicsTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActivePhysicsProjection
    typealias S = Q.S
    typealias P = Q.P
    typealias M = OriginalApplicationLoadedMenuSession
    func sequence(_ reverse: Bool,onBody: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.Observation) throws -> Void)? = nil,onReturn: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,OriginalApplicationLoadedMenuSession.PendingReturn) throws -> Void)? = nil) throws {
        let source = try OriginalApplicationActivePhysicsSource(reverse)
        let sourcePoints = try source.compare()
        var previous: M.Snapshot?,count = 0
        try OriginalApplicationActiveBodyTests().control(reverse,onBody:{ call,ready,event in
            switch event {
            case .gameplay(.physics):
                throw OriginalApplicationLoadedCycleTests.Stop.unexpected("Physics event requires extended comparison")
            case .gameplayCheckpoint(.control,let snapshot):
                try P.require(previous == nil,"One retained control predecessor")
                previous = snapshot
            case .gameplayCheckpoint(.physics,let snapshot):
                let before = try XCTUnwrap(previous)
                var expected = try Q(before.match)
                if count == 0 {
                    var unknown = expected,mask = expected.state.pool.defined
                    mask[0x7d8+0x40] = false
                    unknown.state.pool = try .init(bytes:expected.state.pool.bytes,defined:mask)
                    XCTAssertThrowsError(try unknown.advance(),"Physics unknown velocity remains unknown")
                    var alias = expected
                    try alias.state.pool.write(UInt32(0),at:0x198)
                    XCTAssertThrowsError(try alias.advance(),"Physics finite slot alias boundary")
                    var reversion = expected
                    try reversion.state.pool.write(Int32(2),at:0x7d8+0x324)
                    XCTAssertThrowsError(try reversion.advance(),"Reversion requires its complete caller comparison")
                    var landing = expected
                    try landing.state.pool.writeBinary64(1,at:0x7d8+0x60)
                    try landing.state.pool.writeBinary64(1,at:0x7d8+0x48)
                    XCTAssertThrowsError(try landing.advance(),"Landing remains an explicit open comparison")
                }
                try expected.advance()
                let actual = try P(snapshot.match)
                try P.same(actual.pool,expected.state.pool,"Own complete physics pool \(call.index)")
                try P.same(actual.globals,expected.state.globals,"Own complete physics globals \(call.index)")
                var model = before.match
                model.world = try S.slice(expected.state.pool,0,0x7d8)
                model.actors = try (0..<400).map { try S.slice(expected.state.pool,0x7d8+$0*0x420,0x420) }
                model.globals = expected.state.globals
                try I.sameMatch(snapshot.match,model)
                var state = before.state
                try state.replace(0,expected.state.globals)
                for slot in 0..<2 {
                    var record = model.actors[slot]
                    let ordinal = try record.integer(at:0x368,as:UInt32.self),objects = ready.entry.entry.snapshot.objectTokens
                    try P.require(ordinal < objects.count,"Physics current Object ordinal")
                    try record.write(objects[Int(ordinal)],at:0x368)
                    let token = ready.entry.actorTokens[slot]
                    var allocation = try XCTUnwrap(state.memory.allocations[token]);try P.require(allocation.live,"Physics retained Actor owner")
                    allocation.storage = record;state.memory.allocations[token] = allocation
                }
                try I.sameState(snapshot.state,state)
                try P.require(snapshot.music.allocations == before.music.allocations && snapshot.resources.bitmaps == before.resources.bitmaps && snapshot.backgrounds == before.backgrounds,"Physics complete retained resource owners")
                try P.require(snapshot.operations == before.operations,"Physics complete caller journal")
                try P.same(snapshot.local,before.local,"Physics complete caller local record")
                previous = nil;count += 1
            default:break // Remaining17 stages retain their open comparison gate.
            }
            try onBody?(call,ready,event)
        },onReturn:onReturn)
        try P.require(count == 48 && previous == nil,"Complete own physics sequence")
        print("Owned active physics comparison: control=\(reverse), \(sourcePoints) source Actor checkpoints, \(count) own full physics endpoints, no primitive effects; remaining17 body stages OPEN")
    }
    func testPrimaryOwnedPhysicsProjection() throws { try sequence(false) }
    func testControlOwnedPhysicsProjection() throws { try sequence(true) }
}
