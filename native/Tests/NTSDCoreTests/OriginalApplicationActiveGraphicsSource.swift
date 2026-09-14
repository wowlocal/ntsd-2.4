import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveGraphicsSource {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveGraphicsProjection
    typealias P = Q.P
    typealias D = Q.D
    struct Trace: Decodable {
        struct Write: Decodable { let address: Int,pc: UInt32,size: Int,value: UInt32 }
        struct Call: Decodable {
            // Later stages contain structured boundary records. We require
            // an empty array only for the three selected stages; their absence
            // does not imply that the rest of the original caller has none.
            struct Boundary: Decodable { let kind: String }
            struct Section: Decodable { let boundaries: [Boundary],checkpoints: [MatchLaunchReference.Control.Checkpoint] }
            let globalsWrites: [Write],stages: [Section]
        }
        let cases: [Call]
    }
    let input: I,trace: Trace
    init(_ reverse: Bool) throws {
        input = try I(reverse)
        let name = "original-active-gameplay"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        trace = try JSONDecoder().decode(Trace.self,from:MatchPreparationReference.unpack(data,maximumCount:256_000_000))
        try P.require(trace.cases.count == 48,"Graphics source trace extent")
    }
    func platform(_ drawing: D,_ state: Q) throws {
        let p = input.document.corpus.platform,q = p.input
        try P.require(q.targetSurface == UInt32(bitPattern:state.g(0x455608)) && q.methodResult == 0 && q.queryResult == 0 && q.audioGetResult == 0 && q.audioSetResult == 0 && q.postResult == 0,"Graphics source declared platform responses")
        try P.require(q.queriedAudio == 0x31002400 && q.audioVolume == -1234 && q.dcResult == 0 && q.dc == 0x12345678 && p.drawResults == [0,1],"Graphics synthetic DC/draw inputs")
        for (key,surface) in p.resourceSurfaces {
            let token = try XCTUnwrap(UInt32(key))
            try P.require(drawing.resolve(drawing.resourceToken(token),false).surface == surface,"Graphics current source surface owner")
        }
    }
    func compareHelpers(_ model: Q,_ section: ContinuousGameplayReference.Section) throws {
        let expected = model.helpers,actual = section.helpers
        try P.require(expected.count == actual.count,"Graphics helper count \(section.label): \(expected.count)/\(actual.count)")
        let drawCalls = model.drawing.events.filter { $0.kind == "draw" }
        var draw = 0
        for (index,pair) in zip(expected,actual).enumerated() {
            let (a,b) = pair
            try P.require(a.entry == b.entry && a.returnPC == b.returnPC,"Graphics helper order/return PC \(section.label) \(index)")
            if let result = a.result { try P.require(result == b.result,"Graphics helper result \(String(a.entry,radix:16))") }
            try P.require(b.returnSP == b.entrySP+4+b.pop && b.saved.count == 4,"Graphics helper stack/register shape")
            if a.entry == 0x43ef70 {
                // Controlled caller stack addresses, not a native/private ABI.
                let owner = try XCTUnwrap(actual.dropFirst(index+1).first { $0.entry == 0x43f010 })
                let sp: UInt32 = owner.returnPC == 0x41a3ce ? 0x1000e860 : [0x40bf08,0x40bf1b].contains(owner.returnPC) ? 0x1000e1d4 : 0x1000e228
                let offsets: [UInt32] = a.returnPC == 0x43f0d5 ? [0x48,0x38,0x44,0x3c,0x4c,0x40] : [0x40,0x4c,0x30,0x34,0x38,0x48]
                try P.require(b.entrySP == sp && b.arguments == offsets.map { sp+$0 } && b.pop == 0,"Graphics source clip pointer arguments")
            } else { try P.require(a.args == b.arguments,"Graphics helper arguments \(String(a.entry,radix:16))") }
            if a.entry == 0x43f010 {
                try P.require(draw < drawCalls.count,"Graphics helper draw owner count")
                try P.require(model.drawing.resourceToken(b.this) == drawCalls[draw].arguments[0],"Graphics source draw current wrapper identity")
                draw += 1
            }
        }
        try P.require(draw == drawCalls.count,"All source draw requests have helper returns")
    }
    @discardableResult func compare() throws -> Int {
        let ends: [UInt32] = [0x41f496,0x41f4ac,0x41f550]
        let labels = ["camera-background","world-drawing","post-draw-impulses"]
        var endpoints = 0,unknown = 0,events = 0,globalStores = 0
        for (index,call) in input.document.corpus.cases.enumerated() {
            let acquired = try input.document.snapshot(XCTUnwrap(call.acquired)),objects = try XCTUnwrap(acquired.objects)
            try P.require(objects.map(\.address) == input.document.corpus.objectAddresses,"Graphics current source Object identity")
            let objectRecords = try Dictionary(uniqueKeysWithValues:objects.map { ($0.address,try input.record($0.storage.bytes,$0.storage.defined)) })
            for (n,stage) in Q.stages.enumerated() {
                let section = call.stages[n+9],before = try input.document.snapshot(section.before),after = try input.document.snapshot(section.after)
                try P.require(section.before == call.stages[n+8].after && section.after == call.stages[n+10].before,"Graphics source consecutive caller joins")
                try P.require(section.label == labels[n] && section.end.pc == ends[n] && section.end.sp == 0x1000e9bc,"Graphics complete source boundary")
                let state = try Q.S(pool:input.record(before.state.poolBytes,before.state.poolMask),globals:input.record(before.state.globals),objects:objectRecords,actorTokens:input.document.corpus.actorAddresses)
                var model = try Q(state:state,backgrounds:before.backgrounds.map { try input.record($0.bytes,$0.defined) },drawing:D(active:before,input))
                try platform(model.drawing,model)
                try model.advance(stage,input.document.corpus.platform.input.targetSurface,false)
                try P.same(model.state.pool,input.record(after.state.poolBytes,after.state.poolMask),"Source full graphics pool \(call.index) \(stage)")
                try P.same(model.state.globals,input.record(after.state.globals),"Source full graphics globals \(call.index) \(stage)")
                try P.require(model.backgrounds.count == after.backgrounds.count,"Source all BG records")
                for j in model.backgrounds.indices { try P.same(model.backgrounds[j],input.record(after.backgrounds[j].bytes,after.backgrounds[j].defined),"Source full graphics BG \(j)") }
                let captured: [OriginalFrontScreenEvent]
                switch stage {
                case .camera:captured = try XCTUnwrap(section.events.camera)
                case .drawing:captured = try XCTUnwrap(section.events.drawing)
                default:captured = try XCTUnwrap(section.events.impulses).map { .init($0.kind.rawValue,$0.arguments,$0.strings) }
                }
                try D.compare(captured,model.drawing.events,"Source complete graphics events \(call.index) \(stage)")
                try compareHelpers(model,section)
                let record = trace.cases[index].stages[n+9]
                try P.require(record.boundaries.isEmpty && record.checkpoints.isEmpty && section.effects?.isEmpty == true,"Graphics source explicit empty boundaries/checkpoints/primitive effects")
                try P.require((section.events.lifecycle ?? []).isEmpty && (section.events.commands ?? []).isEmpty,"No extra source groups")
                try P.require(stage == .camera || (section.events.camera ?? []).isEmpty,"No out-of-stage camera events")
                try P.require(stage == .drawing || (section.events.drawing ?? []).isEmpty,"No out-of-stage drawing events")
                try P.require(stage == .impulses || (section.events.impulses ?? []).isEmpty,"No out-of-stage impulse events")
                try P.require(before.state.memory == after.state.memory && before.state.saved == after.state.saved && before.state.pointers == after.state.pointers,"Graphics source recording owner retention")
                try P.require(section.before.filter { !["state","early","backgrounds"].contains($0.key) } == section.after.filter { !["state","early","backgrounds"].contains($0.key) },"Graphics source all available other components")
                try P.same(input.record(before.early.globals),state.globals,"Graphics before early current globals")
                try P.same(input.record(after.early.globals),model.state.globals,"Graphics after early current globals")
                try P.same(input.record(before.early.world.bytes,before.early.world.defined),input.record(after.early.world.bytes,after.early.world.defined),"Graphics retained early World")
                try P.require(before.early.crtState == after.early.crtState && before.early.pointers == after.early.pointers && before.early.records.count == after.early.records.count,"Graphics early metadata")
                for (a,b) in zip(before.early.records,after.early.records) {
                    try P.require(a.address == b.address && a.live == b.live,"Graphics early identity/lifetime")
                    try P.same(input.record(a.storage.bytes,a.storage.defined),input.record(b.storage.bytes,b.storage.defined),"Graphics early complete storage")
                }
                if stage == .camera {
                    let writes = trace.cases[index].globalsWrites.filter { (0x41b5d0...0x41bc87).contains($0.pc) }
                    let expected = model.stores.filter { $0.region == "globals" }
                    try P.require(writes.count == expected.count,"Camera ordered global stores")
                    for (a,b) in zip(writes,expected) {
                        let bytes = (0..<4).map { UInt8(truncatingIfNeeded:a.value >> (8*$0)) }
                        try P.require(a.pc == b.pc && a.address == b.offset+0x44d000 && a.size == 4 && bytes == b.bytes,"Camera numeric store PC/order/value")
                    }
                    globalStores += writes.count
                }
                unknown += captured.filter { $0.read?.defined == false }.count;events += captured.count;endpoints += 1
            }
        }
        try P.require(endpoints == 144 && unknown == 864 && events == 5280 && globalStores == 110,"Complete source active graphics totals")
        return endpoints
    }
}
