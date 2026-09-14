import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveLayoutSource {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveLayoutProjection
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
                    if count == 17 { found = try Section(from:d) }
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
        try P.require(trace.cases.count == 48,"Layout complete saved trace")
    }
    func compare() throws -> Int {
        for (n,call) in input.document.corpus.cases.enumerated() {
            let section = call.stages[17],saved = trace.cases[n],t = saved.section
            try P.require(section.label == "result-layout" && section.end.pc == 0x422994 && section.end.sp == 0x1000e9bc,"Source complete layout boundary")
            try P.require(section.before == call.stages[16].after && section.after == call.output.before && call.stages[16].end.pc == 0x422944,"Source recording/layout/output joins")
            try P.require(section.before == section.after,"Source every retained component identity")
            let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
            let globals = try input.record(before.state.globals),expected = try Q.advance(globals,continuation:.indicators)
            try P.same(expected,input.record(after.state.globals),"Source full layout globals")
            try P.same(input.record(before.state.poolBytes,before.state.poolMask),input.record(after.state.poolBytes,after.state.poolMask),"Source layout complete pool and masks")
            try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"Source layout buffers, saved state and pointer owners")
            try P.require(section.before.filter { !["state","early"].contains($0.key) } == section.after.filter { !["state","early"].contains($0.key) },"Source all other retained component identities")
            try P.require(before.early.globals == before.state.globals && after.early.globals == after.state.globals,"Early/state globals are one source record")
            try P.same(input.record(before.early.world.bytes,before.early.world.defined),input.record(after.early.world.bytes,after.early.world.defined),"Layout retains early World")
            try P.require(before.early.crtState == after.early.crtState && before.early.pointers == after.early.pointers && before.early.records.count == after.early.records.count,"Layout early metadata")
            for (a,b) in zip(before.early.records,after.early.records) {
                try P.require(a.address == b.address && a.live == b.live,"Layout early lifetime")
                try P.same(input.record(a.storage.bytes,a.storage.defined),input.record(b.storage.bytes,b.storage.defined),"Layout early full backing")
            }
            try P.require(t.events.isEmpty && t.effects.isEmpty && t.helpers.isEmpty && t.boundaries.isEmpty && t.checkpoints.isEmpty && t.readsBeforeWrites.isEmpty,"Source no layout event/helper/boundary or undefined reads")
            try P.require(saved.stackAccesses.filter { $0.phase == "gameplay-result-layout" }.isEmpty,"Source round word and watched locals unread/unwritten")
            let writes = saved.globalsWrites.filter { (0x422218..<0x422994).contains($0.pc) }
            try P.require(writes.isEmpty,"Source layout has no global store")
            try P.require(t.instructions == [0x422944,0x42294b,0x422994],"Two executed source addresses plus unexecuted stop, not ordered trace")
            let b = t.boundary
            try P.require(b.fpuBefore.count == 3 && b.fpuBefore[0] == 0x23f && [0,0x4000].contains(b.fpuBefore[1]) && b.fpuBefore[2] == 0xffff && b.fpuBefore == b.fpuAfter,"Source FPU retention; no Native FPU equivalence")
            try P.require(b.scratchBefore == b.scratchAfter && b.spawnBefore == b.spawnAfter && b.stageDefeatedBefore == b.stageDefeatedAfter && b.noticeFillInputs.isEmpty && b.cameraFillInputs.isEmpty,"Source retained caller words; no backing supplied")
        }
        try P.require(input.document.corpus.cases.count == 48,"Full saved layout sequence")
        return 48
    }
}
