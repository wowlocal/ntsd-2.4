import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveNoticesSource {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveNoticesProjection
    typealias P = Q.P
    struct Trace: Decodable {
        struct Section: Decodable {
            struct Boundary: Decodable {
                let fpuBefore: [UInt32],fpuAfter: [UInt32]
                let scratchBefore: [UInt32],scratchAfter: [UInt32]
                let spawnBefore: UInt32,spawnAfter: UInt32
                let stageDefeatedBefore: UInt32,stageDefeatedAfter: UInt32
                let noticeFillInputs: [String],cameraFillInputs: [String]
            }
            // Empty collections have a deliberately narrow element type: an
            // unexpected populated family is a decoding failure, not ignored.
            let events: [String:[Int]]
            let effects: [Int],helpers: [Int],boundaries: [Int],checkpoints: [Int],readsBeforeWrites: [Int]
            let instructions: [UInt32],boundary: Boundary
        }
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
                    if count == 15 { found = try Section(from:d) }
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
        try P.require(trace.cases.count == 48,"Notices complete saved trace")
    }
    func compare() throws -> Int {
        for (n,call) in input.document.corpus.cases.enumerated() {
            let section = call.stages[15],saved = trace.cases[n],t = saved.section
            try P.require(section.label == "post-hud-notices" && section.end.pc == 0x421cdc && section.end.sp == 0x1000e9bc,"Source complete notices boundary")
            try P.require(section.before == call.stages[14].after && section.after == call.stages[16].before,"Source HUD/notices/recording joins")
            let predecessor = try XCTUnwrap(call.stages[14].helpers.last)
            try P.require(predecessor.entry == 0x41ae60 && predecessor.returnPC == 0x421a2d && predecessor.saved.count == 4 && predecessor.saved[3] == 0,"Source HUD retains EDI zero for notice comparisons")
            let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
            try Q.requireNoOutput(input.record(before.state.globals))
            try P.same(input.record(before.state.poolBytes,before.state.poolMask),input.record(after.state.poolBytes,after.state.poolMask),"Source notices complete pool and masks")
            try P.same(input.record(before.state.globals),input.record(after.state.globals),"Source notices complete globals")
            try P.require(section.before == section.after,"Source all retained component identities")
            try P.require(t.events.isEmpty && t.effects.isEmpty && t.helpers.isEmpty && t.boundaries.isEmpty && t.checkpoints.isEmpty && t.readsBeforeWrites.isEmpty,"Source no notice event/helper/boundary or undefined reads")
            try P.require(saved.stackAccesses.filter { $0.phase == "gameplay-post-hud-notices" }.isEmpty,"Source watched caller words and local strings unread/unwritten")
            try P.require(saved.globalsWrites.filter { (0x421a2d..<0x421cdc).contains($0.pc) }.isEmpty,"Source no notice global stores")
            try P.require(t.instructions == [0x421a2d,0x421a33,0x421a39,0x421b30,0x421b37,0x421c0a,0x421c0f,0x421c12,0x421ca8,0x421cab,0x421cdc],"Saved set of ten actual source notice PCs and unexecuted stop")
            let b = t.boundary
            try P.require(b.fpuBefore.count == 3 && b.fpuBefore[0] == 0x23f && [0,0x4000].contains(b.fpuBefore[1]) && b.fpuBefore[2] == 0xffff && b.fpuBefore == b.fpuAfter,"Source FPU retention; no Native FPU equivalence")
            try P.require(b.scratchBefore == b.scratchAfter && b.spawnBefore == b.spawnAfter && b.stageDefeatedBefore == b.stageDefeatedAfter && b.noticeFillInputs.isEmpty && b.cameraFillInputs.isEmpty,"Source retained caller words and no fill backing")
        }
        try P.require(input.document.corpus.cases.count == 48,"Full saved notices sequence")
        return 48
    }
}
