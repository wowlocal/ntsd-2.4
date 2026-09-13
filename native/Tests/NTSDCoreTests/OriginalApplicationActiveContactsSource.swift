import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveContactsSource {
    typealias C = OriginalApplicationActiveBodySource
    typealias Q = OriginalApplicationActiveContactsProjection
    typealias S = Q.S
    typealias P = Q.P
    let reader: C
    init(_ reverse: Bool) throws { reader = try C(reverse) }
    @discardableResult func compare() throws -> Int {
        let input = reader.input
        var endpoints = 0,points = 0,helpers = 0,pairs = 0
        let labels = ["depth-attachments","contacts","hits-items","cpoint-actions","cpoint-placement","cpoint-cleanup","cpoint-attachments"]
        let ends: [UInt32] = [0x41eed8,0x41eefb,0x41f2ac,0x41f2b3,0x41f2b8,0x41f47d,0x41f484]
        for (index,call) in input.document.corpus.cases.enumerated() {
            let acquired = try input.document.snapshot(XCTUnwrap(call.acquired))
            let savedObjects = try XCTUnwrap(acquired.objects)
            try P.require(savedObjects.map(\.address) == input.document.corpus.objectAddresses,"Contact source current Object identity")
            let objects = try Dictionary(uniqueKeysWithValues:savedObjects.map { ($0.address,try input.record($0.storage.bytes,$0.storage.defined)) })
            let heap = try XCTUnwrap(acquired.frameHeap).map { OriginalFrameAllocation(address:$0.address,kind:$0.kind,storage:try input.record($0.storage.bytes,$0.storage.defined)) }
            for (n,stage) in Q.stages.enumerated() {
                let section = call.stages[n+2]
                try P.require(section.label == labels[n] && section.end.pc == ends[n] && section.end.sp == 0x1000e9bc,"Contact source stage/return boundary")
                let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
                let state = try S(pool:input.record(before.state.poolBytes,before.state.poolMask),globals:input.record(before.state.globals),objects:objects,actorTokens:input.document.corpus.actorAddresses)
                let backgrounds = try before.backgrounds.map { try input.record($0.bytes,$0.defined) }
                var expected = Q(state:state,backgrounds:backgrounds,heap:heap)
                try expected.advance(stage)
                try P.same(expected.state.pool,input.record(after.state.poolBytes,after.state.poolMask),"Source full \(section.label) pool \(index+1)")
                try P.same(expected.state.globals,input.record(after.state.globals),"Source full \(section.label) globals \(index+1)")
                try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"Contact source recording owners")
                try P.require(section.before.filter { !["state","early"].contains($0.key) } == section.after.filter { !["state","early"].contains($0.key) },"Contact source available non-state components")
                try P.same(input.record(before.early.globals),state.globals,"Contact before early current globals")
                try P.same(input.record(after.early.globals),expected.state.globals,"Contact after early current globals")
                try P.same(input.record(before.early.world.bytes,before.early.world.defined),input.record(after.early.world.bytes,after.early.world.defined),"Contact retained early World")
                try P.require(before.early.crtState == after.early.crtState && before.early.pointers == after.early.pointers && before.early.records.count == after.early.records.count,"Contact early metadata")
                for (a,b) in zip(before.early.records,after.early.records) {
                    try P.require(a.address == b.address && a.live == b.live,"Contact early identity/lifetime")
                    try P.same(input.record(a.storage.bytes,a.storage.defined),input.record(b.storage.bytes,b.storage.defined),"Contact early complete storage")
                }
                // Middle heap/Object snapshots are absent. Acquired inputs plus
                // the recovered no-write path are used, not invented snapshots.
                let captured = reader.trace.cases[index].stages[n+2].checkpoints
                try P.require(captured.count == expected.points.count,"Contact source full Actor checkpoint count")
                for (a,b) in zip(expected.points,captured) {
                    try P.require(a.slot == b.slot && a.label == b.label && a.pc == b.pc,"Contact source checkpoint order/identity")
                    try P.same(a.actor,input.record(b.actor.bytes,b.actor.defined),"Contact source Actor checkpoint")
                    points += 1
                }
                try P.require(section.helpers.count == expected.helpers.count,"Contact source full helper count")
                for (a,b) in zip(expected.helpers,section.helpers) {
                    try P.require(a.entry == b.entry && a.args == b.arguments && a.returnPC == b.returnPC,"Contact helper order/arguments/return PC")
                    if let result = a.result { try P.require(result == b.result,"Contact helper result") }
                    try P.require(b.returnSP == b.entrySP+4+b.pop && b.saved.count == 4,"Contact helper saved register/stack shape")
                    helpers += 1
                }
                let effects = try XCTUnwrap(section.effects)
                if let draw = expected.random {
                    try P.require(effects.count == 1,"Contact source sole item RNG effect")
                    let e = effects[0]
                    try P.require(e.kind == "random" && e.arguments == [146,200,UInt32(bitPattern:draw)] && e.context.pc == 0x417170 && e.context.sp == 0x1000e9b0,"Contact source item RNG identity")
                } else { try P.require(effects.isEmpty,"Contact source no primitive effects") }
                let e = section.events
                try P.require((e.camera ?? []).isEmpty && (e.drawing ?? []).isEmpty && (e.impulses ?? []).isEmpty && (e.lifecycle ?? []).isEmpty && (e.commands ?? []).isEmpty,"Contact source no grouped effects")
                endpoints += 1;pairs += expected.broadPairs
            }
        }
        try P.require(endpoints == 336 && points == 288 && helpers == 745 && pairs == 11,"Complete finite contact source totals")
        return endpoints
    }
}
