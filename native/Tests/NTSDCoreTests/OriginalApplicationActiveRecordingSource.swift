import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveRecordingSource {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveRecordingProjection
    typealias P = Q.P
    struct Trace: Decodable {
        typealias Section = OriginalApplicationActiveNoticesSource.Trace.Section
        struct Call: Decodable {
            enum CodingKeys: String,CodingKey { case stages,globalsWrites,stackAccesses }
            let section: Section
            let globalsWrites: [OriginalApplicationActiveHUDSource.Trace.Write]
            let stackAccesses: [OriginalApplicationActiveHUDSource.Trace.Access]
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy:CodingKeys.self)
                var stages = try c.nestedUnkeyedContainer(forKey:.stages)
                var found: Section?,count = 0
                while !stages.isAtEnd {
                    let d = try stages.superDecoder()
                    if count == 16 { found = try Section(from:d) }
                    count += 1
                }
                try P.require(count == 18,"Saved stages before separate output")
                section = try XCTUnwrap(found)
                globalsWrites = try c.decode([OriginalApplicationActiveHUDSource.Trace.Write].self,forKey:.globalsWrites)
                stackAccesses = try c.decode([OriginalApplicationActiveHUDSource.Trace.Access].self,forKey:.stackAccesses)
            }
        }
        let cases: [Call]
    }
    let input: I,trace: Trace
    init(_ reverse: Bool) throws {
        input = try I(reverse)
        let name = "original-active-gameplay"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        trace = try JSONDecoder().decode(Trace.self,from:MatchPreparationReference.unpack(data,maximumCount:256_000_000))
        try P.require(trace.cases.count == 48,"Recording complete saved trace")
    }
    func compare() throws -> Int {
        for (n,call) in input.document.corpus.cases.enumerated() {
            let section = call.stages[16],saved = trace.cases[n],t = saved.section
            try P.require(section.label == "result-recording" && section.end.pc == Q.continuation && section.end.sp == 0x1000e9bc,"Source complete recording boundary")
            try P.require(section.before == call.stages[15].after && section.after == call.stages[17].before,"Source notices/recording/layout joins")
            let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
            let globals = try input.record(before.state.globals),expected = try Q.advance(globals)
            try P.same(expected,input.record(after.state.globals),"Source full recording globals")
            try P.same(input.record(before.state.poolBytes,before.state.poolMask),input.record(after.state.poolBytes,after.state.poolMask),"Source recording complete pool and masks")
            try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"Source recording buffers, saved state and pointer owners")
            try P.require(section.before.filter { !["state","early"].contains($0.key) } == section.after.filter { !["state","early"].contains($0.key) },"Source all other retained component identities")
            try P.require(before.early.globals == before.state.globals && after.early.globals == after.state.globals,"Early/state globals are one source record")
            try P.same(input.record(before.early.world.bytes,before.early.world.defined),input.record(after.early.world.bytes,after.early.world.defined),"Recording retains early World")
            try P.require(before.early.crtState == after.early.crtState && before.early.pointers == after.early.pointers && before.early.records.count == after.early.records.count,"Recording early metadata")
            for (a,b) in zip(before.early.records,after.early.records) {
                try P.require(a.address == b.address && a.live == b.live,"Recording early lifetime")
                try P.same(input.record(a.storage.bytes,a.storage.defined),input.record(b.storage.bytes,b.storage.defined),"Recording early full backing")
            }
            try P.require(t.events.isEmpty && t.effects.isEmpty && t.helpers.isEmpty && t.boundaries.isEmpty && t.checkpoints.isEmpty && t.readsBeforeWrites.isEmpty,"Source no recording event/helper/boundary or undefined reads")
            try P.require(saved.stackAccesses.filter { $0.phase == "gameplay-result-recording" }.isEmpty,"Source round word and watched locals unread/unwritten")
            let writes = saved.globalsWrites.filter { (0x421cdc..<0x422218).contains($0.pc) }
            try P.require(writes.count == 1,"Source one recording counter store")
            let w = try XCTUnwrap(writes.first)
            try P.require(w.address == 0x450bbc && w.pc == 0x421ce6 && w.size == 4 && w.value == expected.integer(at:0x450bbc-0x44d000,as:UInt32.self),"Source exact counter store address/width/value")
            try P.require(t.instructions == [0x421cdc,0x421ce1,0x421ce4,0x421ce6,0x421ced,0x421cf0,0x421cf6,0x422944],"Seven executed source addresses plus unexecuted stop, not ordered trace")
            let b = t.boundary
            try P.require(b.fpuBefore.count == 3 && b.fpuBefore[0] == 0x23f && [0,0x4000].contains(b.fpuBefore[1]) && b.fpuBefore[2] == 0xffff && b.fpuBefore == b.fpuAfter,"Source FPU retention; no Native FPU equivalence")
            try P.require(b.scratchBefore == b.scratchAfter && b.spawnBefore == b.spawnAfter && b.stageDefeatedBefore == b.stageDefeatedAfter && b.noticeFillInputs.isEmpty && b.cameraFillInputs.isEmpty,"Source retained caller words; no backing supplied")
        }
        try P.require(input.document.corpus.cases.count == 48,"Full saved recording sequence")
        return 48
    }
}
