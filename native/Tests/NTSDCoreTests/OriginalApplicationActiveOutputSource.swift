import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveOutputSource {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveOutputProjection
    typealias P = Q.P
    typealias D = Q.D
    struct Trace: Decodable {
        struct Position: Decodable { let pc: UInt32,sp: UInt32,seh: UInt32,saved: [UInt32] }
        struct Output: Decodable {
            struct Item: Decodable { let pc: UInt32 }
            let writes: [Q.Write],entryObservations: [Position],returnObservations: [Position]
            let instructions: [UInt32],checkpoints: [Item],readsBeforeWrites: [Item]
        }
        struct FPU: Decodable {
            struct Checkpoint: Decodable { let pc: UInt32,sp: UInt32,fpcw: UInt32,fpsw: UInt32 }
            let checkpoints: [Checkpoint]
        }
        struct Call: Decodable { let output: Output,fpuStart: Int,fpuEnd: Int }
        let cases: [Call]
        let fpu: FPU
    }
    let input: I,trace: Trace
    init(_ reverse: Bool) throws {
        input = try I(reverse)
        let name = "original-active-gameplay"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        trace = try JSONDecoder().decode(Trace.self,from:MatchPreparationReference.unpack(data,maximumCount:256_000_000))
        try P.require(trace.cases.count == 48,"Output full trace extent")
    }
    func compare() throws -> Int {
        var events = 0,stores = 0,plays = 0,helpers = 0
        for (n,call) in input.document.corpus.cases.enumerated() {
            let s = call.output,t = trace.cases[n].output,platform = input.document.corpus.platform
            try P.require(s.before == call.stages[17].after && call.stages[17].end.pc == 0x422994,"Source layout/output join")
            try P.require(s.label == "gameplay-return" && s.end.pc == 0x30000000 && s.end.sp == 0x1000f42c,"Source complete declared return")
            try P.require(s.after.allSatisfy { call.after[$0.key] == $0.value } && Set(call.after.keys).subtracting(s.after.keys) == ["objects","objectStrings","frameHeap"],"Source output subset and explicit missing middle snapshots")
            let before = try input.document.snapshot(s.before),after = try input.document.snapshot(s.after)
            let sourceGlobals = try input.record(before.state.globals)
            var model = try Q(globals:sourceGlobals,drawing:D(active:before,input),liveSounds:Set(platform.loadedSoundBuffers))
            let p = platform.input
            try P.require(p.targetSurface == UInt32(bitPattern:model.g(0x455608)) && p.dc == 0x12345678 && p.dcResult == 0 && p.methodResult == 0 && p.queryResult == 0 && p.audioGetResult == 0 && p.audioSetResult == 0 && p.postResult == 0 && platform.drawResults == [0,1],"Declared source output platform responses")
            try P.require(Set(platform.loadedSoundBuffers).count == platform.loadedSoundBuffers.count && !platform.loadedSoundBuffers.contains(0),"Source unique declared live sound inventory")
            for (name,surface) in platform.resourceSurfaces {
                let token = try XCTUnwrap(UInt32(name))
                try P.require(model.drawing.resolve(model.drawing.resourceToken(token),false).surface == surface,"Source current resource bitmap surface")
            }
            try model.advance(false)
            try D.compare(s.events,model.drawing.events,"Source complete output events")
            try P.require(t.writes == model.writes,"Source exact output store PC/address/width/value order")
            try P.same(model.globals,input.record(after.state.globals),"Source full output globals and masks")
            try P.same(input.record(before.state.poolBytes,before.state.poolMask),input.record(after.state.poolBytes,after.state.poolMask),"Source retained World/Actor backing")
            try P.require(before.state.memory == after.state.memory && before.state.pointers == after.state.pointers && before.state.saved == after.state.saved,"Source output live replay/memory retention")
            try P.require(s.before.filter { !["state","early"].contains($0.key) } == s.after.filter { !["state","early"].contains($0.key) },"Source all other available components")
            try P.require(before.early.globals == before.state.globals && after.early.globals == after.state.globals,"Source early globals alias")
            try P.same(input.record(before.early.world.bytes,before.early.world.defined),input.record(after.early.world.bytes,after.early.world.defined),"Source retained early World")
            try P.require(before.early.crtState == after.early.crtState && before.early.pointers == after.early.pointers && before.early.records.count == after.early.records.count,"Source early metadata")
            for (a,b) in zip(before.early.records,after.early.records) {
                try P.require(a.address == b.address && a.live == b.live,"Source early allocation identity/lifetime")
                try P.same(input.record(a.storage.bytes,a.storage.defined),input.record(b.storage.bytes,b.storage.defined),"Source early full storage/masks")
            }
            let playCount = s.events.filter { $0.kind == "play" }.count
            try P.require(s.helpers.count == 166+playCount,"Complete source helper extent")
            for h in s.helpers {
                try P.require(h.saved.count == 4 && h.returnSP == h.entrySP+4+h.pop,"Source helper ABI shape; no new full Native ABI claim")
                let returns: [UInt32:UInt32] = [0x41b130:0x4229a8,0x4028a0:0x4229b4,0x43e940:0x4229bf,0x419e60:0x4229c7,0x401a30:0x419f4d]
                if let pc = returns[h.entry] { try P.require(h.returnPC == pc,"Source known output helper call site") }
            }
            try P.require(t.checkpoints.isEmpty && t.readsBeforeWrites.isEmpty,"Source explicit output auxiliary observations")
            let a = t.entryObservations,b = t.returnObservations
            try P.require(a.map(\.pc) == [0x4246b0,0x41bc90] && b.map(\.pc) == [0x422a95,0x424746,0x4287de,0x30000000],"Source both caller frames and returns")
            try P.require(b.map(\.sp) == [0x1000e9bc,0x1000f000,0x1000f000,0x1000f42c],"Source retained stack cleanup")
            try P.require(b[1].saved == a[1].saved && b[1].seh == a[1].seh && b[2].saved == b[1].saved && b[2].seh == b[1].seh && b[3].saved == a[0].saved && b[3].seh == a[0].seh,"Source normal saved-register and SEH restoration")
            try P.require([UInt32(0x422994),0x422ab8,0x424746,0x428805].allSatisfy(t.instructions.contains),"Source actual output and both ret4 instructions")
            let range = trace.cases[n]
            try P.require(range.fpuStart <= range.fpuEnd-8 && range.fpuEnd <= trace.fpu.checkpoints.count,"Source whole-call FPU index bounds")
            let fpu = Array(trace.fpu.checkpoints[range.fpuEnd-8..<range.fpuEnd])
            try P.require(fpu.map(\.pc) == [0x422994,0x41b130,0x4028a0,0x43e940,0x419e60,0x422a95,0x424746,0x4287de],"Source actual output FPU checkpoints")
            try P.require(fpu.allSatisfy { $0.fpcw == 0x23f && [0,0x4000].contains($0.fpsw) } && Set(fpu.map(\.fpsw)).count == 1,"Source output FPU retention, not a Native hardware comparison")
            events += s.events.count;stores += t.writes.count;plays += playCount;helpers += s.helpers.count
        }
        try P.require(input.document.corpus.cases.count == 48 && events == 37825 && stores == 583 && plays == 7 && helpers == 7975,"Complete saved output totals")
        print("Active output source: control=\(input.document.corpus.control), 48 endpoints, \(events) events, \(stores) stores, \(plays) plays, \(helpers) helpers; full Native ABI/FPU OPEN")
        return 48
    }
}
