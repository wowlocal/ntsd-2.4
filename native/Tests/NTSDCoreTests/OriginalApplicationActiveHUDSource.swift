import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveHUDSource {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveHUDProjection
    typealias P = Q.P
    typealias D = Q.D
    struct Trace: Decodable {
        struct Write: Decodable { let address: UInt32,pc: UInt32,size: Int,value: UInt32 }
        struct Access: Decodable { let address: UInt32,pc: UInt32,size: Int,write: Bool,phase: String,bytesBefore: String }
        struct Section: Decodable {
            struct Boundary: Decodable { let fpuBefore: [UInt32],fpuAfter: [UInt32] }
            struct Item: Decodable { let kind: String }
            let boundary: Boundary,boundaries: [Item],checkpoints: [MatchLaunchReference.Control.Checkpoint]
        }
        struct Call: Decodable { let stages: [Section],globalsWrites: [Write],stackAccesses: [Access] }
        let cases: [Call]
    }
    let input: I,trace: Trace
    init(_ reverse: Bool) throws {
        input = try I(reverse)
        let name = "original-active-gameplay"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        trace = try JSONDecoder().decode(Trace.self,from:MatchPreparationReference.unpack(data,maximumCount:256_000_000))
        try P.require(trace.cases.count == 48,"HUD full trace extent")
    }
    func helpers(_ model: Q,_ section: ContinuousGameplayReference.Section,_ argument: UInt32) throws {
        let actual = section.helpers
        var index = 0,blits = 0
        func next(_ entry: UInt32,_ pc: UInt32,_ args: [UInt32],_ result: UInt32,_ sp: UInt32,_ pop: UInt32,_ receiver: UInt32?) throws {
            try P.require(index < actual.count,"HUD helper exists")
            let h = actual[index];index += 1
            try P.require(h.entry == entry && h.returnPC == pc && h.arguments == args && h.result == result,"HUD helper order/arguments/result")
            try P.require(h.entrySP == sp && h.pop == pop && h.returnSP == sp+4+pop && h.saved.count == 4,"HUD source helper ABI shape")
            if let receiver { try P.require(model.drawing.resourceToken(h.this) == receiver,"HUD source current helper receiver") }
        }
        for request in model.requests {
            let events = Array(model.drawing.events[request.events]),first = try XCTUnwrap(events.first)
            if first.kind == "rectangle" {
                try P.require(events.count == 3 && events[1].read?.offset == 0 && events[2].blit != nil,"HUD rectangle expansion")
                try next(0x43f310,request.pc,Array(first.arguments.dropFirst()),UInt32(blits%2),0x1000e97c,28,request.token)
                blits += 1;continue
            }
            try P.require(first.kind == "draw" && first.arguments.count == 7,"HUD bitmap request")
            let frame = Int32(bitPattern:first.arguments[3])
            let count = Int32(bitPattern:try XCTUnwrap(events.first { $0.read?.offset == 12 }?.read?.value))
            var clipIndex = 0,result = UInt32(bitPattern:frame)
            for e in events {
                if let clip = e.clip {
                    let whole = clipIndex == 0 && (frame < 0 || count == 0),sp: UInt32 = 0x1000e89c
                    let offsets: [UInt32] = whole ? [0x48,0x38,0x44,0x3c,0x4c,0x40] : [0x40,0x4c,0x30,0x34,0x38,0x48]
                    try next(0x43ef70,whole ? 0x43f0d5 : 0x43f212,offsets.map { sp+$0 },clip.visible ? 1 : 0,sp,0,nil)
                    if !whole { result = clip.visible ? 1 : 0 }
                    clipIndex += 1
                }
                if e.blit != nil {
                    if frame < count && clipIndex == ((frame < 0 || count == 0) ? 2 : 1) { result = UInt32(blits%2) }
                    blits += 1
                }
            }
            try next(0x43f010,request.pc,Array(first.arguments.dropFirst()),result,0x1000e980,24,request.token)
        }
        try next(0x41ae60,0x421a2d,[argument],17,0x1000e9b4,4,input.document.corpus.worldAddress)
        try P.require(index == actual.count,"HUD complete helper extent")
    }
    func compare() throws -> Int {
        var count = 0,events = 0,unknown = 0
        for (index,call) in input.document.corpus.cases.enumerated() {
            let section = call.stages[14],record = trace.cases[index].stages[14]
            try P.require(section.label == "world-hud" && section.end.pc == 0x421a2d && section.end.sp == 0x1000e9bc,"Source whole HUD boundary")
            try P.require(section.before == call.stages[13].after && section.after == call.stages[15].before,"Source commands/HUD/notices joins")
            let before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
            let acquired = try input.document.snapshot(XCTUnwrap(call.acquired)),objects = try XCTUnwrap(acquired.objects)
            try P.require(objects.map(\.address) == input.document.corpus.objectAddresses,"HUD source Object bindings")
            let records = try Dictionary(uniqueKeysWithValues:objects.map { ($0.address,try input.record($0.storage.bytes,$0.storage.defined)) })
            let state = try Q.S(pool:input.record(before.state.poolBytes,before.state.poolMask),globals:input.record(before.state.globals),objects:records,actorTokens:input.document.corpus.actorAddresses)
            var model = try Q(state:state,drawing:D(active:before,input))
            let platform = input.document.corpus.platform
            try P.require(platform.drawResults == [0,1] && platform.input.targetSurface == UInt32(bitPattern:model.g(0x455608)),"HUD declared synthetic Blt results and global destination")
            for (key,surface) in platform.resourceSurfaces {
                let token = try XCTUnwrap(UInt32(key))
                try P.require(model.drawing.resolve(model.drawing.resourceToken(token),false).surface == surface,"HUD saved resource surface binding")
            }
            try model.advance()
            try P.require(model.selected == [0,1],"Source finite selected HUD Actors")
            try P.same(model.state.pool,input.record(after.state.poolBytes,after.state.poolMask),"Source complete HUD pool/masks")
            try P.same(model.state.globals,input.record(after.state.globals),"Source complete HUD globals")
            let drawing = try XCTUnwrap(section.events.drawing)
            try D.compare(drawing,model.drawing.events,"Source full HUD event sequence")
            try P.require(section.effects?.isEmpty == true && record.boundaries.isEmpty && record.checkpoints.isEmpty,"HUD explicit empty effects/boundaries/checkpoints")
            try P.require((section.events.camera ?? []).isEmpty && (section.events.impulses ?? []).isEmpty && (section.events.lifecycle ?? []).isEmpty && (section.events.commands ?? []).isEmpty,"No other HUD event families")
            try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"HUD source recording retention")
            try P.require(section.before.filter { $0.key != "state" } == section.after.filter { $0.key != "state" },"Source all non-state HUD components retained")
            let writes = trace.cases[index].globalsWrites.filter { [0x421a1c,0x421a22].contains($0.pc) }
            try P.require(writes.count == 2,"HUD two source command stores")
            for (w,pair) in zip(writes,[(UInt32(0x421a1c),UInt32(0x450bc0)),(0x421a22,0x450bb8)]) {
                try P.require(w.pc == pair.0 && w.address == pair.1 && w.size == 4 && w.value == 0,"HUD source command reset order/width/value")
            }
            let accesses = trace.cases[index].stackAccesses.filter { $0.phase == "gameplay-world-hud" }
            try P.require(accesses.count == 1,"Saved HUD selected caller-stack access extent")
            let access = try XCTUnwrap(accesses.first)
            try P.require(access.pc == 0x421a15 && access.address == 0x1000ea24 && access.size == 4 && !access.write && access.bytesBefore.count == 8,"Source HUD retained argument read")
            let raw = Array(access.bytesBefore.utf8)
            let argument = try (0..<4).reduce(UInt32(0)) { result,n in
                result | UInt32(try XCTUnwrap(UInt8(String(decoding:raw[2*n..<2*n+2],as:UTF8.self),radix:16))) << (n*8)
            }
            try helpers(model,section,argument)
            let fpu = record.boundary.fpuBefore
            try P.require(fpu.count == 3 && fpu[0] == 0x23f && [0,0x4000].contains(fpu[1]) && fpu[2] == 0xffff && fpu == record.boundary.fpuAfter,"Source HUD FPU preservation; no Native FPU comparison")
            count += 1;events += drawing.count;unknown += drawing.filter { $0.read?.defined == false }.count
        }
        let control = input.document.corpus.control
        try P.require(count == 48 && events == (control ? 8640 : 5952) && unknown == (control ? 2496 : 960),"Source complete finite HUD totals")
        print("Active HUD source: control=\(control), \(count) endpoints, \(events) events, \(unknown) unknown bitmap reads")
        return count
    }
}
