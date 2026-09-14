import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveCommandsSource {
    typealias Q = OriginalApplicationActiveCommandsProjection
    typealias P = Q.P
    let saved: OriginalApplicationActiveLifecycleSource
    init(_ reverse: Bool) throws { saved = try .init(reverse) }
    func compare() throws -> Int {
        let input = saved.input
        var count = 0
        for (index,call) in input.document.corpus.cases.enumerated() {
            let section = call.stages[13],trace = saved.trace.cases[index].stages[13]
            try P.require(section.label == "post-draw-commands" && section.end.pc == 0x421a15 && section.end.sp == 0x1000e9bc,"Source full commands boundary")
            try P.require(section.before == call.stages[12].after && section.after == call.stages[14].before,"Source lifecycle/commands/HUD joins")
            let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
            let acquired = try input.document.snapshot(XCTUnwrap(call.acquired)),objects = try XCTUnwrap(acquired.objects)
            try P.require(objects.map(\.address) == input.document.corpus.objectAddresses,"Commands current source Object bindings")
            let records = try Dictionary(uniqueKeysWithValues:objects.map { ($0.address,try input.record($0.storage.bytes,$0.storage.defined)) })
            var model = try Q(.init(pool:input.record(before.state.poolBytes,before.state.poolMask),globals:input.record(before.state.globals),objects:records,actorTokens:input.document.corpus.actorAddresses))
            try model.advance()
            try P.require(model.cleaned == [0,1],"Saved finite active command slots")
            try P.same(model.state.pool,input.record(after.state.poolBytes,after.state.poolMask),"Source complete command pool/masks")
            try P.same(model.state.globals,input.record(after.state.globals),"Source full command globals; flags remain set until HUD")
            try P.require(section.effects?.isEmpty == true && section.helpers.isEmpty && trace.helpers.isEmpty && trace.boundaries.isEmpty && trace.checkpoints.isEmpty,"Commands declared empty effects/helpers/boundaries/checkpoints")
            try P.require((section.events.camera ?? []).isEmpty && (section.events.drawing ?? []).isEmpty && (section.events.impulses ?? []).isEmpty && (section.events.lifecycle ?? []).isEmpty && (section.events.commands ?? []).isEmpty,"Source no additional command event family")
            try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"Commands retain recording owners")
            try P.require(section.before.filter { $0.key != "state" } == section.after.filter { $0.key != "state" },"Source all available non-state components unchanged")
            for access in saved.trace.cases[index].stackAccesses where access.phase == "gameplay-post-draw-commands" {
                try P.require(!(UInt64(access.address) < 0x1000e9f4 && UInt64(access.address)+UInt64(access.size) > 0x1000e9f0),"Unread retained command slot stays unknown")
            }
            count += 1
        }
        try P.require(count == 48,"Complete saved command sequence")
        return count
    }
}
