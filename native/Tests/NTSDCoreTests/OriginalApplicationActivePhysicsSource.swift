import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Saved-source verification before any own physics comparison.
final class OriginalApplicationActivePhysicsSource {
    typealias C = OriginalApplicationActiveBodySource
    typealias Q = OriginalApplicationActivePhysicsProjection
    typealias S = Q.S
    typealias P = Q.P
    let control: C
    init(_ reverse: Bool) throws { control = try C(reverse) }
    @discardableResult func compare() throws -> Int {
        let input = control.input
        var count = 0
        for (index,call) in input.document.corpus.cases.enumerated() {
            let section = call.stages[1]
            try P.require(section.label == "physics" && section.end.pc == 0x41eed1 && section.end.sp == 0x1000e9bc,"Source physics caller boundary")
            let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
            let acquired = try input.document.snapshot(XCTUnwrap(call.acquired))
            let savedObjects = try XCTUnwrap(acquired.objects)
            try P.require(savedObjects.map(\.address) == input.document.corpus.objectAddresses,"Source physics live Object identities")
            let objects = try Dictionary(uniqueKeysWithValues:savedObjects.map { ($0.address,try input.record($0.storage.bytes,$0.storage.defined)) })
            var expected = try Q(S(pool:input.record(before.state.poolBytes,before.state.poolMask),globals:input.record(before.state.globals),objects:objects,actorTokens:input.document.corpus.actorAddresses))
            try expected.advance()
            try P.same(expected.state.pool,input.record(after.state.poolBytes,after.state.poolMask),"Source complete physics pool \(index+1)")
            try P.same(expected.state.globals,input.record(after.state.globals),"Source complete physics globals \(index+1)")
            try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"Source physics recording owners")
            // Unlike control RNG, physics has no global change in these calls;
            // the retained early.globals mirror is included in this exact check.
            try P.require(section.before.filter { $0.key != "state" } == section.after.filter { $0.key != "state" },"Source available non-state physics records")
            let checkpoints = control.trace.cases[index].stages[1].checkpoints
            try P.require(checkpoints.count == 2 && expected.points.count == 2 && section.helpers.count == 2,"Source complete physics checkpoint/helper count")
            for (slot,pair) in zip(expected.points,checkpoints).enumerated() {
                let (a,b) = pair,h = section.helpers[slot],token = input.document.corpus.actorAddresses[slot]
                try P.require(a.slot == slot && b.slot == slot && b.label == "physics-return" && b.pc == 0x41e657,"Source physics checkpoint order/PC")
                try P.same(a.actor,input.record(b.actor.bytes,b.actor.defined),"Source physics Actor return \(index+1)/\(slot)")
                try P.require(h.entry == 0x40e490 && h.entrySP == 0x1000e9b8 && h.returnSP == 0x1000e9bc && h.returnPC == 0x41e657 && h.pop == 0 && h.arguments.isEmpty && h.this == token && h.saved.count == 4 && h.saved[3] == UInt32(slot),"Source physics helper identity/return")
                try P.require(h.result == a.actor.integer(at:0x368,as:UInt32.self),"Source physics return Object identity")
                count += 1
            }
            try P.require(try XCTUnwrap(section.effects).isEmpty,"Source physics complete primitive effects")
            let e = section.events
            try P.require((e.camera ?? []).isEmpty && (e.drawing ?? []).isEmpty && (e.impulses ?? []).isEmpty && (e.lifecycle ?? []).isEmpty && (e.commands ?? []).isEmpty,"Source physics grouped effects")
        }
        try P.require(count == 96,"Source physics total Actor returns")
        return count
    }
}
