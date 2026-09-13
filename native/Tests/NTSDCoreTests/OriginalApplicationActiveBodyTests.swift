import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveBodyTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias P = I.P
    typealias S = OriginalApplicationActiveBodyControl
    typealias M = OriginalApplicationLoadedMenuSession
    func control(_ reverse: Bool) throws {
        let source = try OriginalApplicationActiveBodySource(reverse)
        let sourcePoints = try source.compareControl()
        for n in [Double.leastNonzeroMagnitude,Double.infinity,1e-101] {
            XCTAssertThrowsError(try S.Actor.finite(n),"Reject unsupported numeric comparison domain")
        }
        var draws: [S.Draw] = [],controls = 0,primitiveDraws = 0
        try OriginalApplicationActiveGameplayTests().sequence(reverse,onBody:{ call,ready,event in
            switch event {
            case .gameplay(.control(let slot,let value)):
                switch value {
                case let .random(stream,range,result):draws.append(.init(slot:slot,stream:stream,range:range,result:result))
                case .sound:throw OriginalApplicationLoadedCycleTests.Stop.unexpected("Active control sound outside finite formula")
                }
            case .gameplayCheckpoint(.control,let snapshot):
                var expected = try S(ready.match)
                if controls == 0 {
                    var alias = expected
                    try alias.pool.write(UInt32(0),at:0x198)
                    XCTAssertThrowsError(try alias.advance(),"Finite comparator must reject live slot alias")
                    var unknown = expected,mask = expected.pool.defined
                    mask[0x7d8+0xcd] = false
                    unknown.pool = try .init(bytes:expected.pool.bytes,defined:mask)
                    XCTAssertThrowsError(try unknown.advance(),"Unknown causal input must not become zero")
                    var transfer = expected
                    try transfer.pool.write(UInt8(3),at:0x7d8+0xd4)
                    XCTAssertThrowsError(try transfer.advance(),"Unimplemented transfer remains an explicit boundary")
                }
                try expected.advance()
                try P.require(draws == expected.draws,"Own ordered complete control RNG effects")
                primitiveDraws += draws.count;draws = []
                let actual = try P(snapshot.match)
                try P.same(actual.pool,expected.pool,"Own full active control pool \(call.index)")
                try P.same(actual.globals,expected.globals,"Own full active control globals \(call.index)")
                // Expected storage remains solely a comparison value. It is never
                // passed to a gameplay handler or a Bootstrap commit.
                var model = ready.match
                model.world = try S.slice(expected.pool,0,0x7d8)
                model.actors = try (0..<400).map { try S.slice(expected.pool,0x7d8+$0*0x420,0x420) }
                model.globals = expected.globals
                try I.sameMatch(snapshot.match,model)
                var state = ready.state
                try state.replace(0,expected.globals)
                let tokens = ready.entry.actorTokens,objects = ready.entry.entry.snapshot.objectTokens
                for slot in 0..<2 {
                    var record = model.actors[slot]
                    let ordinal = try record.integer(at:0x368,as:UInt32.self)
                    try P.require(ordinal < objects.count,"Own control Object ordinal")
                    try record.write(objects[Int(ordinal)],at:0x368)
                    var allocation = try XCTUnwrap(state.memory.allocations[tokens[slot]])
                    try P.require(allocation.live,"Own control live Actor owner")
                    allocation.storage = record;state.memory.allocations[tokens[slot]] = allocation
                }
                try I.sameState(snapshot.state,state)
                try P.require(snapshot.music.allocations == ready.music.allocations && snapshot.resources.bitmaps == ready.menuResources.bitmaps && snapshot.backgrounds == ready.menuBackgrounds,"Control retained current resource owners")
                try P.require(snapshot.operations == ready.operations.map(M.Operation.preceding),"Control full caller journal")
                let local = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x704),defined:[Bool](repeating:false,count:0x704))
                try P.same(snapshot.local,local,"Control caller unknown local record")
                controls += 1
            default:break // The remaining18 body stages keep their explicit open comparator gate.
            }
        })
        try P.require(controls == 48 && draws.isEmpty,"Own complete active control sequence")
        print("Owned active control comparison: control=\(reverse), \(sourcePoints) source Actor checkpoints, \(controls) own complete control endpoints, \(primitiveDraws) own control RNG events; remaining18 body stages OPEN")
    }
    func testPrimaryOwnedControlProjection() throws { try control(false) }
    func testControlOwnedControlProjection() throws { try control(true) }
}
