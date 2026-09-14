import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Saved pristine EXE/VC80 stages. No source after-state feeds the owned game.
final class OriginalApplicationActiveLifecycleSource {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveLifecycleProjection
    typealias P = Q.P
    struct Trace: Decodable {
        struct Boundary: Decodable {
            let kind: String, before: String,after: String
            let entryPC: UInt32,entrySP: UInt32,returnPC: UInt32,actualReturnPC: UInt32,returnSP: UInt32,result: UInt32
            let arguments: [UInt32],savedBefore: [UInt32],savedAfter: [UInt32]
        }
        struct Section: Decodable {
            struct Slot: Decodable { let slot: Int? }
            let boundaries: [Boundary],checkpoints: [MatchLaunchReference.Control.Checkpoint]
            let helpers: [Slot]
        }
        struct Access: Decodable { let address: UInt32,size: UInt32,phase: String }
        struct Call: Decodable { let stages: [Section],stackAccesses: [Access] }
        let cases: [Call]
    }
    let input: I,trace: Trace
    init(_ reverse: Bool) throws {
        input = try I(reverse)
        let name = "original-active-gameplay"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        trace = try JSONDecoder().decode(Trace.self,from:MatchPreparationReference.unpack(data,maximumCount:256_000_000))
        try P.require(trace.cases.count == 48,"Lifecycle trace extent")
    }
    @discardableResult func compare() throws -> Int {
        var count = 0,helpers = 0,sounds = 0,constructors = 0
        for (index,call) in input.document.corpus.cases.enumerated() {
            let section = call.stages[12],record = trace.cases[index].stages[12]
            try P.require(section.label == "post-draw-lifecycle" && section.end.pc == 0x4214d5 && section.end.sp == 0x1000e9bc,"Source full lifecycle boundary")
            try P.require(section.before == call.stages[11].after && section.after == call.stages[13].before,"Source consecutive impulse/lifecycle/command joins")
            let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
            let acquired = try input.document.snapshot(XCTUnwrap(call.acquired)),objects = try XCTUnwrap(acquired.objects)
            try P.require(objects.map(\.address) == input.document.corpus.objectAddresses,"Source current catalog order")
            let records = try Dictionary(uniqueKeysWithValues:objects.map { ($0.address,try input.record($0.storage.bytes,$0.storage.defined)) })
            let state = try Q.S(pool:input.record(before.state.poolBytes,before.state.poolMask),globals:input.record(before.state.globals),objects:records,actorTokens:input.document.corpus.actorAddresses)
            var model = Q(state,objects:input.document.corpus.objectAddresses)
            try model.advance()
            try P.same(model.state.pool,input.record(after.state.poolBytes,after.state.poolMask),"Source complete lifecycle pool \(call.index)")
            try P.same(model.state.globals,input.record(after.state.globals),"Source complete lifecycle globals \(call.index)")
            try P.require(model.events == (section.events.lifecycle ?? []),"Source complete ordered lifecycle events")
            try P.require(section.effects?.isEmpty == true && record.checkpoints.isEmpty,"Source lifecycle empty primitive effects/checkpoints")
            try P.require((section.events.camera ?? []).isEmpty && (section.events.drawing ?? []).isEmpty && (section.events.impulses ?? []).isEmpty && (section.events.commands ?? []).isEmpty,"No additional lifecycle event groups")
            try P.require(section.helpers.count == model.helpers.count,"Source complete lifecycle helper extent")
            try P.require(record.helpers.count == model.helpers.count,"Lifecycle helper slot metadata extent")
            for (ordinal,pair) in zip(model.helpers,section.helpers).enumerated() {
                let (a,b) = pair
                try P.require(record.helpers[ordinal].slot == a.slot,"Source lifecycle saved caller slot")
                try P.require(a.entry == b.entry && a.returnPC == b.returnPC && a.args == b.arguments,"Source lifecycle helper order/arguments/returnPC")
                try P.require(b.pop == (a.entry == 0x40d960 ? 8 : 0) && b.returnSP == b.entrySP+4+b.pop && b.saved.count == 4,"Source lifecycle helper stack shape")
                if let receiver = a.receiver { try P.require(receiver == b.this,"Source lifecycle Actor receiver") }
                try P.require(try XCTUnwrap(a.result) == b.result,"Source lifecycle helper result \(String(a.entry,radix:16))")
            }
            try P.require(record.boundaries.count == model.created.count,"Source constructor boundary count")
            for (boundary,slot) in zip(record.boundaries,model.created) {
                let token = input.document.corpus.actorAddresses[slot]
                try P.require(boundary.kind == "memset" && boundary.entryPC == 0x4450a0 && boundary.arguments == [token+0xf0,0,400],"Source declared constructor memset arguments")
                try P.require(boundary.returnPC == 0x406447 && boundary.actualReturnPC == boundary.returnPC && boundary.returnSP == boundary.entrySP+4 && boundary.result == token+0xf0 && boundary.savedBefore == boundary.savedAfter,"Source constructor adapter return")
                let prior = try Q.S.slice(state.pool,model.at(slot,0xf0),400)
                try P.require(prior.defined.allSatisfy { $0 } && prior.bytes == [UInt8](repeating:0,count:400),"Source current known constructor subrange")
                try P.same(input.record(boundary.before),prior,"Source constructor before adapter")
                try P.same(input.record(boundary.after),prior,"Source constructor after adapter")
            }
            for access in trace.cases[index].stackAccesses where access.phase == "gameplay-post-draw-lifecycle" {
                for offset: UInt32 in [0x44,0x50,0x5c,0x60,0x6c,0x70] {
                    try P.require(!(UInt64(access.address) < UInt64(0x1000e9bc+offset+4) && UInt64(access.address)+UInt64(access.size) > UInt64(0x1000e9bc+offset)),"Unread lifecycle scratch remains unknown")
                }
            }
            try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"Source lifecycle recording owners")
            try P.require(section.before.filter { !["state","early"].contains($0.key) } == section.after.filter { !["state","early"].contains($0.key) },"Source all available retained lifecycle components")
            try P.same(input.record(before.early.globals),state.globals,"Source before early current globals")
            try P.same(input.record(after.early.globals),model.state.globals,"Source after early current globals")
            try P.same(input.record(before.early.world.bytes,before.early.world.defined),input.record(after.early.world.bytes,after.early.world.defined),"Source retained early World")
            try P.require(before.early.crtState == after.early.crtState && before.early.pointers == after.early.pointers && before.early.records.count == after.early.records.count,"Source retained early metadata")
            for (a,b) in zip(before.early.records,after.early.records) {
                try P.require(a.address == b.address && a.live == b.live,"Source lifecycle early owner identity")
                try P.same(input.record(a.storage.bytes,a.storage.defined),input.record(b.storage.bytes,b.storage.defined),"Source lifecycle early full storage")
            }
            count += 1;helpers += model.helpers.count;sounds += model.events.filter { $0.kind == "catalogSound" }.count;constructors += model.created.count
        }
        try P.require(count == 48 && helpers == 108 && sounds == 7 && constructors == 1,"Complete source lifecycle totals")
        return count
    }
}
