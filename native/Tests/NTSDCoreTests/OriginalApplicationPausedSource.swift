import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Read only the pinned saved pause captures. All computed records remain on
/// the comparison side; the Native candidate starts from its own neutral parent.
final class OriginalApplicationPausedSource {
    typealias R = PausedGameplayReference
    typealias S = OriginalApplicationGameplaySource
    typealias X = OriginalApplicationPausedProjection
    typealias P = X.P
    typealias D = X.D
    typealias Q = X.Q
    struct Raw: Decodable {
        struct Call: Decodable {
            let stages: [ContinuousGameplayReference.Section]
            let output: ContinuousGameplayReference.Output
            struct Rendering: Decodable { let instructions: [UInt32] }
            let rendering: Rendering?
        }
        let cases: [Call]
    }
    let document: R.Document,source: S,trace: S.Trace,raw: Raw
    var rawRenderingPCs: [Set<UInt32>] { raw.cases.map { Set($0.rendering?.instructions ?? []) } }
    init(_ reverse: Bool) throws {
        let name = "original-paused-gameplay"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        let sha = reverse ? "be991d1fe0001ffbe5098da526782034d66791e47a225470a497c8e560b7094c" : "0c2e53bbe82ab643161f0f336142920d9eac3f56f0852ec7c63bd97c0ef51889"
        try P.require(MatchPreparationReference.digest(data) == sha,"Pinned paused fixture")
        document = try .init(data);source = try .init(paused:document,reverse:reverse)
        let bytes = try MatchPreparationReference.unpack(data,maximumCount:256_000_000)
        trace = try JSONDecoder().decode(S.Trace.self,from:bytes);raw = try JSONDecoder().decode(Raw.self,from:bytes)
        let c = document.corpus
        try P.require(c.parent.sha256 == S.fixtureSHA256["original-continuous-gameplay"+(reverse ? "-control" : "")],"Pause neutral parent hash")
        try P.require(trace.cases.count == 14 && raw.cases.count == 14 && c.cases.count == 14,"Complete paused call inventory")
    }
    func record(_ key: String) throws -> OriginalStateRecord {
        let bytes = try source.bytes(key)
        return try .init(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count))
    }
    func state(_ refs: R.Refs) throws -> MatchLaunchReference.State { try document.snapshot(refs) }
    func sections(_ index: Int) throws -> [S.Section] {
        let c = raw.cases[index],pcs = trace.cases[index]
        try P.require(c.stages.count == 18 && pcs.stages.count == 18,"Unpaused stage inventory")
        var result: [S.Section] = []
        for (n,stage) in c.stages.enumerated() {
            let spec = S.specifications[n]
            try P.require(stage.label == spec.1 && stage.end.pc == spec.2,"Unpaused stage boundary")
            if n > 0 { try P.require(stage.before == c.stages[n-1].after,"Unpaused stage continuity") }
            result.append(.init(stage:spec.0,before:try state(stage.before),after:try state(stage.after),pcs:Set(pcs.stages[n].instructions),end:stage.end.pc,
                first:nil,continued:stage,output:nil,writes:pcs.stages[n].writes ?? []))
        }
        try P.require(c.output.before == c.stages.last?.after,"Unpaused output join")
        result.append(.init(stage:.output,before:try state(c.output.before),after:try state(c.output.after),pcs:Set(pcs.output.instructions),end:c.output.end.pc,
            first:nil,continued:nil,output:c.output,writes:pcs.output.writes ?? []))
        return result
    }
    func input(_ index: Int) throws -> X.I.Local {
        let c = document.corpus.cases[index],cycle = c.cycle,before = try state(c.before)
        try P.require(c.index == index+1 && c.before == (index == 0 ? document.corpus.initial : document.corpus.cases[index-1].after),"Source pause retained entry")
        var globals = try source.globals(before)
        try P.require(X.I.keyboard(globals) == c.acquisition.before,"Source pause keyboard before")
        let keys: [UInt32] = index == 0 || index == 10 ? [0x4553e8] : index == 4 ? [0x4553e9] : []
        try P.require(c.acquisition.plan.index == index+1 && c.acquisition.plan.keys == keys,"Source pause acquisition plan")
        var changes: [R.Acquisition.Change] = []
        for address in [UInt32(0x4553e8),0x4553e9] {
            let value: UInt8 = keys.contains(address) ? 100 : 117
            if try globals.integer(at:Int(address)-0x44d000,as:UInt8.self) != value {
                try globals.write(value,at:Int(address)-0x44d000)
                changes.append(.init(address:address,bytes:value == 100 ? "64" : "75"))
            }
        }
        try P.require(changes == c.acquisition.changes && X.I.keyboard(globals) == c.acquisition.after,"Source pause acquired changes")
        globals = try X.I.prologue(globals)
        let p = cycle.prefix.after,isPaused = try X.paused(globals)
        try P.same(globals,record(p.globals),"Source paused prologue full globals")
        try P.require(p.poolBytes == before.state.poolBytes && p.poolMask == before.state.poolMask,"Source prologue retains pool")
        let zero = [UInt8](repeating:0,count:10)
        try P.require(cycle.stimulus.isEmpty && cycle.prefix.commands == zero && cycle.prefix.playback == zero,"Source both cleared input buffers")
        try P.require(c.paused == isPaused && isPaused == !X.unpaused.contains(index+1) && cycle.local.paused == (isPaused ? 1 : 0),"Source pause continuation schedule")
        try P.require(cycle.local.parent && cycle.local.natural && cycle.local.dispatch.isEmpty && (cycle.local.call == nil) == isPaused && (cycle.local.beforeDispatch == nil) == isPaused,"Source local skip and provenance")
        let pool = try source.record(p.poolBytes,p.poolMask)
        var projected = try X.local(pool,globals,document.corpus.actorAddresses)
        try P.require(projected.commands == zero && cycle.local.commandsAfter == zero,"Source neutral pause commands")
        for local in [cycle.local.beforeDispatch,cycle.local.after].compactMap({ $0 }) {
            let world = try source.record(local.world.bytes,local.world.defined)
            let actors = try local.actors.map { try source.record($0.bytes,$0.defined) }
            let all = try OriginalStateRecord(bytes:world.bytes+actors.flatMap(\.bytes),defined:world.defined+actors.flatMap(\.defined))
            try P.same(projected.pool,all,"Source paused local pool")
            try P.same(projected.globals,record(local.globals),"Source paused local globals")
        }
        let controls = try X.control(projected.globals)
        // Native platform replies are declared separately. This source inventory
        // checks the actual ordered requests including semantic action observers.
        try P.require(cycle.inputControl.events.map { OriginalInputControlRequest($0.kind,$0.arguments,$0.data) } == controls,"Source exact input request inventory")
        for (n,event) in cycle.inputControl.events.enumerated() {
            try P.require(event.response == (event.kind == .action ? nil : .init(result:[-1,1,-1,0][n],bytes:n == 3 ? [120,86,52,18] : [])),"Source exact input response")
        }
        for (stage,snapshot): (OriginalLoadedMatchEntry.Checkpoint,InputControlReference.Snapshot) in [
            (.control,cycle.inputControl.control),(.received,cycle.inputControl.after),(.replay,cycle.replay.after),(.round,cycle.round.after)] {
            try X.inputStage(stage,&projected)
            try P.same(projected.pool,source.record(snapshot.poolBytes,snapshot.poolMask),"Source pause input pool \(stage)")
            try P.same(projected.globals,record(snapshot.globals),"Source pause input globals \(stage)")
        }
        let start = cycle.inputControl.after,end = cycle.replay.after
        let tick = try record(start.globals).integer(at:0x450b8c-0x44d000,as:Int32.self)
        try P.require(start.memory.count == 1 && end.memory.count == 1 && start.memory[0].live && end.memory[0].live,"Source pause replay owner")
        var allocation = try source.record(start.memory[0].bytes,start.memory[0].defined)
        let pointer = try record(start.pointers).integer(at:0,as:UInt32.self)
        if !isPaused { for n in 0..<10 { try allocation.write(zero[n],at:0x2b38+10*Int(tick)+n) } }
        try P.same(allocation,source.record(end.memory[0].bytes,end.memory[0].defined),"Source paused complete recording")
        try P.require(start.pointers == end.pointers && start.saved == end.saved,"Source retained replay metadata")
        try P.require(cycle.replay.events == (isPaused ? [] : [.init(.writePacket,[UInt32(tick),pointer],[zero])]),"Source exact pause replay events")
        var teams = [UInt32](repeating:0,count:40);teams[10] = 1;teams[11] = 1
        try P.require(cycle.round.events == (isPaused ? [] : [.init(.teams,teams)]) && cycle.round.continuation == (isPaused ? .pausedRendering : .gameplay),"Source exact pause round events")
        try P.require(projected.globals.integer(at:0x450b8c-0x44d000,as:Int32.self) == X.counters[index],"Source retained replay counter")
        return projected
    }
    func output(_ index: Int,_ p: inout P) throws -> [OriginalFrontScreenEvent] {
        let c = document.corpus.cases[index],before = try state(c.output.before),after = try state(c.output.after)
        try OriginalApplicationGameplayProjectionTests.sourceEqual(p,before,source,"Source output before")
        var q = Q(globals:p.globals,drawing:try D(before,source),liveSounds:Set(document.corpus.platform.loadedSoundBuffers))
        if c.paused { try q.advancePausedNoticeOne(false) } else { try q.advance(false) }
        let writes = trace.cases[index].output.writes ?? []
        try P.require(writes.map { Q.Write(address:$0.address,pc:$0.pc,size:$0.size,value:UInt32($0.value)) } == q.writes,"Complete paused source output store sequence")
        try D.compare(c.output.events,q.drawing.events,"Source complete pause output")
        p.globals = q.globals
        try OriginalApplicationGameplayProjectionTests.sourceEqual(p,after,source,"Source output after")
        try P.require(c.output.end.pc == 0x30000000 && c.output.end.sp == 0x1000f42c && c.end.pc == 0x30000000 && c.end.sp == 0x1000f42c,"Both actual paused source returns")
        return q.drawing.events
    }
    /// Every available source endpoint includes these retained owners. Compare
    /// aliases too; no missing Object or middle Frame storage becomes known.
    func checkRetainedComponents(_ refs: R.Refs) throws {
        let c = document.corpus,initial = try state(c.initial),after = try state(refs)
        for name in ["bitmaps","menuBitmaps","music","released"] {
            try P.require(refs[name] == c.initial[name],"Source stage retained component \(name)")
        }
        if refs["frameHeap"] != nil { try P.require(refs["frameHeap"] == c.initial["frameHeap"],"Available source Frame retention") }
        try P.require(after.objects == nil && after.objectStrings == nil,"No invented whole Object snapshots")
        try P.require(after.state.memory == initial.state.memory && after.state.pointers == initial.state.pointers && after.state.saved == initial.state.saved,"Source stage neutral replay backing retention")
        try P.require(after.early.crtState == initial.early.crtState && after.early.pointers == initial.early.pointers && after.early.records.count == initial.early.records.count,"Source stage retained early owners/CRT")
        for (a,b) in zip(after.early.records,initial.early.records) {
            try P.require(a.address == b.address && a.live == b.live,"Source stage early resource identity")
            try P.same(source.record(a.storage.bytes,a.storage.defined),source.record(b.storage.bytes,b.storage.defined),"Source stage early resource bytes/masks")
        }
        try P.same(record(after.early.globals),source.globals(after),"Source stage duplicate early globals")
        let raw = try source.record(after.state.poolBytes,after.state.poolMask)
        let world = try OriginalStateRecord(bytes:Array(raw.bytes.prefix(0x7d8)),defined:Array(raw.defined.prefix(0x7d8)))
        try P.same(source.record(after.early.world.bytes,after.early.world.defined),world,"Source stage duplicate early World")
    }
    func compare(_ objects: [OriginalLoadedObject]) throws -> Int {
        let c = document.corpus,initial = try state(c.initial)
        var p = try P(initial,source:source,objects:objects),count = 0
        let stops: [UInt32] = [0x41d74d,0x41d762,0x41d76a,0x41d78b,0x422994]
        for index in 0..<14 {
            let call = c.cases[index],before = try state(call.before)
            try checkRetainedComponents(call.before)
            try checkRetainedComponents(call.output.before);try checkRetainedComponents(call.output.after)
            for section in call.stages {
                try checkRetainedComponents(section.before);try checkRetainedComponents(section.after)
            }
            if let r = call.rendering {
                try checkRetainedComponents(r.before);try checkRetainedComponents(r.after)
                for point in r.checkpoints { try checkRetainedComponents(point.state) }
            }
            try OriginalApplicationGameplayProjectionTests.sourceEqual(p,before,source,"Retained source pause entry")
            let next = try input(index)
            p.pool = try source.normalizedPool(next.pool);p.globals = next.globals
            if call.paused {
                let r = try XCTUnwrap(call.rendering)
                try P.require(call.stages.isEmpty && trace.cases[index].stages.isEmpty && r.checkpoints.count == 5 && r.checkpoints.map(\.pc) == stops && r.fillInputs.isEmpty && r.fillResult == 0 && r.drawResults == [0,1],"Complete paused rendering boundary")
                try P.require(r.target == UInt32(bitPattern:p.g(0x455608)),"Source own paused target")
                var previous = r.before
                var bodyWrites: [Q.Write] = []
                for (n,point) in r.checkpoints.enumerated() {
                    let stage = OriginalPausedGameplay.Stage.allCases[n]
                    try P.require(point.stage == stage.rawValue,"Source paused stage order")
                    let before = try state(previous)
                    try OriginalApplicationGameplayProjectionTests.sourceEqual(p,before,source,"Source paused stage before")
                    var drawing = try D(before,source)
                    _ = try X.body(stage,&p,&drawing,r.target,false,Set(c.platform.loadedSoundBuffers))
                    for store in p.stores {
                        try P.require(rawRenderingPCs[index].contains(store.pc),"Observed paused scalar store PC")
                        if store.region == "globals" {
                            let value = store.bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8*$1.offset) }
                            bodyWrites.append(.init(address:UInt32(0x44d000+store.offset),pc:store.pc,size:store.bytes.count,value:value))
                        }
                    }
                    try D.compare(point.events,drawing.events,"Source complete paused \(stage)")
                    try OriginalApplicationGameplayProjectionTests.sourceEqual(p,state(point.state),source,"Source paused stage after")
                    previous = point.state;count += 1
                }
                try P.require(r.after == previous && r.after == call.output.before && r.events == r.checkpoints.flatMap(\.events),"Whole paused rendering event extent")
                let writes = trace.cases[index].globalsWrites
                let begins = writes.indices.filter { writes[$0].pc == 0x41d742 }
                try P.require(begins.count == 1,"Unique source paused body global-store boundary")
                let expected = bodyWrites+(trace.cases[index].output.writes ?? []).map { Q.Write(address:$0.address,pc:$0.pc,size:$0.size,value:UInt32($0.value)) }
                let suffix = writes.dropFirst(try XCTUnwrap(begins.first)).map { Q.Write(address:$0.address,pc:$0.pc,size:$0.size,value:UInt32($0.value)) }
                try P.require(suffix == expected,"Entire source paused body/output global-store suffix")
            } else {
                try P.require(call.rendering == nil,"Unpaused has no paused stages")
                for section in try sections(index).dropLast() {
                    try OriginalApplicationGameplayProjectionTests.sourceEqual(p,section.before,source,"Source resumed stage before")
                    let old = p;try p.advance(section,sourceValues:true)
                    var drawing = try D(section.before,source)
                    try drawing.validateSourcePlatform(section,source,old)
                    let events = try drawing.stage(section.stage,old,p,UInt32(bitPattern:old.g(0x455608)),installed:false)
                    try D.compare(D.sourceEvents(section),events,"Source resumed complete front")
                    try P.require(D.sourceOther(section) == D.other(p),"Source resumed complete non-front")
                    try OriginalApplicationGameplayProjectionTests.sourceEqual(p,section.after,source,"Source resumed stage after")
                    count += 1
                }
            }
            _ = try output(index,&p);count += 1
            let after = try state(call.after)
            try OriginalApplicationGameplayProjectionTests.sourceEqual(p,after,source,"Source enclosing paused return")
            try P.require(p.g(0x450bbc) == X.counters[index] && call.output.after == call.after.filter { $0.key != "frameHeap" },"Source elapsed counter and complete output/return bridge")
            try checkRetainedComponents(call.after)
        }
        try P.require(count == 162,"All source pause/resume stage endpoints")
        return count
    }
}
