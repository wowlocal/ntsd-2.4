import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Reads existing immutable active control records, including interior Actor
/// checkpoints. No record from this reader is supplied to the application.
final class OriginalApplicationActiveBodySource {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias P = I.P
    typealias S = OriginalApplicationActiveBodyControl
    struct Trace: Decodable {
        struct Call: Decodable {
            struct Section: Decodable { let checkpoints: [MatchLaunchReference.Control.Checkpoint] }
            let stages: [Section]
        }
        let cases: [Call]
    }
    let input: I,trace: Trace
    init(_ reverse: Bool) throws {
        input = try I(reverse)
        let name = "original-active-gameplay"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        let expected = reverse ? "d3abb578f36ac74716fa6e71eb12091c6f0eed5adb02f1b59a550275c73fc0b3" : "3b074ff960538fde6e13b1b65bda4f833b22bbc9cafcef990de12f71aaed511c"
        try P.require(MatchPreparationReference.digest(data) == expected,"Active control trace fixture")
        trace = try JSONDecoder().decode(Trace.self,from:MatchPreparationReference.unpack(data,maximumCount:256_000_000))
        try P.require(trace.cases.count == 48 && trace.cases.allSatisfy { $0.stages.count == 18 },"Active control trace shape")
    }
    @discardableResult func compareControl() throws -> Int {
        var points = 0
        for (index,call) in input.document.corpus.cases.enumerated() {
            let section = call.stages[0]
            try P.require(section.label == "control" && section.end.pc == 0x41e634 && section.end.sp == 0x1000e9bc,"Source control boundary")
            let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
            let acquired = try input.document.snapshot(XCTUnwrap(call.acquired))
            let savedObjects = try XCTUnwrap(acquired.objects)
            try P.require(savedObjects.map(\.address) == input.document.corpus.objectAddresses,"Source live Object identities")
            let objects = try Dictionary(uniqueKeysWithValues:savedObjects.map {
                ($0.address,try input.record($0.storage.bytes,$0.storage.defined))
            })
            var expected = try S(pool:input.record(before.state.poolBytes,before.state.poolMask),globals:input.record(before.state.globals),objects:objects,actorTokens:input.document.corpus.actorAddresses)
            try expected.advance()
            try P.same(expected.pool,input.record(after.state.poolBytes,after.state.poolMask),"Source complete active control pool \(index+1)")
            try P.same(expected.globals,input.record(after.state.globals),"Source complete active control globals \(index+1)")
            try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"Source control retains recording owners")
            try P.require(section.before.filter { !["state","early"].contains($0.key) } == section.after.filter { !["state","early"].contains($0.key) },"Source available resource control endpoints")
            // early.globals is another snapshot of current globals, not frozen
            // startup history. Its RNG changes must match the same calculation.
            try P.same(input.record(before.early.globals),input.record(before.state.globals),"Source early current globals before")
            try P.same(input.record(after.early.globals),expected.globals,"Source early current globals after")
            try P.same(input.record(before.early.world.bytes,before.early.world.defined),input.record(after.early.world.bytes,after.early.world.defined),"Source retained early World")
            try P.require(before.early.crtState == after.early.crtState && before.early.pointers == after.early.pointers && before.early.records.count == after.early.records.count,"Source early owner metadata")
            for (a,b) in zip(before.early.records,after.early.records) {
                try P.require(a.address == b.address && a.live == b.live,"Source early owner identity/lifetime")
                try P.same(input.record(a.storage.bytes,a.storage.defined),input.record(b.storage.bytes,b.storage.defined),"Source early complete owner storage")
            }
            // Middle Object/Frame snapshots were not captured by this stage.
            // The actual acquired records are read-only inputs to the control
            // contract; whole-call retention alone is not an interior-write proof.
            let captured = trace.cases[index].stages[0].checkpoints
            let checkpointPCs: [String:UInt32] = ["buffers":0x413208,"combos":0x41324c,"frame-input":0x4132ef,"movement":0x414247,"control-return":0x41e364]
            try P.require(captured.count == expected.points.count,"Complete source control Actor checkpoint count")
            for (a,b) in zip(expected.points,captured) {
                try P.require(a.slot == b.slot && a.label == b.label && checkpointPCs[a.label] == b.pc,"Source control checkpoint order/PC")
                try P.same(a.actor,input.record(b.actor.bytes,b.actor.defined),"Source active control \(index+1)/\(a.slot)/\(a.label)")
                points += 1
            }
            let events = try XCTUnwrap(section.effects)
            let randomHelpers = section.helpers.filter { $0.entry == 0x417170 }
            try P.require(events.count == expected.draws.count,"Source complete control primitive effects")
            try P.require(randomHelpers.count == events.count,"Source RNG helper count")
            for (ordinal,pair) in zip(expected.draws,events).enumerated() {
                let (draw,event) = pair,helper = randomHelpers[ordinal]
                try P.require(event.kind == "random" && event.context.pc == 0x417170 && event.arguments == [draw.stream,draw.range,draw.result].map(UInt32.init(bitPattern:)),"Source control RNG arguments/PC")
                let parent = event.context.parents.filter { $0.entry == 0x413080 }
                try P.require(parent.count == 1 && parent[0].this == input.document.corpus.actorAddresses[draw.slot] && parent[0].returnPC == 0x41e364 && event.context.root3c == UInt32(draw.slot),"Source control RNG parent/slot")
                try P.require(helper.entrySP == event.context.sp && helper.this == event.context.this && helper.arguments == Array(event.arguments.prefix(2)) && helper.result == event.arguments[2] && helper.returnPC == 0x413641 && helper.pop == 0 && helper.returnSP == helper.entrySP+4,"Source RNG helper return join")
            }
        }
        try P.require(points == 480,"Source active control endpoint total")
        return points
    }
}
