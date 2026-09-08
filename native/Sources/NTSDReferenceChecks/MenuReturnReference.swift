import Foundation
import NTSDCore

public enum MenuReturnReference {
    public struct Result {
        public let parent: ModeScreenReference.Result
        public let cases: Int, events: Int, helpers: Int, records: Int, bytes: Int, draws: Int, checkpoints: Int
    }
    private typealias Blob = InputControlReference.Blob
    private typealias Snapshot = InputControlReference.Snapshot
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Retained: Decodable {
        struct Record: Decodable { let address: UInt32, live: Bool, storage: Storage }
        let globals: String, world: Storage, crtState: UInt32, pointers: [UInt8], records: [Record]
    }
    private struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32, result: UInt32 }
    private struct Input: Decodable { let presentation: OriginalMenuPresentationInput, milliseconds: UInt32, drawResults: [Int32] }
    private struct Checkpoint: Decodable { let kind: String, pc: UInt32, sp: UInt32, saved: [UInt32], seh: UInt32, globals: String }
    private struct Case: Decodable {
        let label: String, inherited: Bool, stimulus: [InputControlReference.GlobalWrite], input: Input
        let before: Snapshot, after: Snapshot, earlyBefore: Retained, earlyAfter: Retained
        let fills: [String], events: [OriginalFrontScreenEvent], helpers: [Helper], checkpoints: [Checkpoint]
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, parent: InputControlReference.Parent, worldAddress: UInt32
        let actorAddresses: [UInt32], objectAddresses: [UInt32], cases: [Case], blobs: [String:Blob]
    }
    private static func error(_ s: String) -> OriginalStateError { .invalidStorage("Menu return reference: "+s) }
    public static func compare(returning: Data,screen: Data,startup: Data,menu: Data,loading: Data,catalog: Data,sounds: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(returning,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.parent.sha256 == MatchPreparationReference.digest(screen),c.worldAddress == 0x22000020,
              c.actorAddresses.count == 400,c.objectAddresses.count == 137,!c.cases.isEmpty else { throw error("Source/parent identity") }
        let objects = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let actors = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let helperReturns: [UInt32:Set<UInt32>] = [0x415160:[0x422a09],0x43f010:[0x422a2e],0x43ef70:[0x43f0d5,0x43f212],
            0x401290:[0x422a52,0x40293d,0x4029cd,0x402a09,0x402a47],0x4028a0:[0x422a68],0x402810:[0x4028ea],0x401f30:[0x40283e],0x43e940:[0x422a74]]
        var blobs: [String:[UInt8]] = [:], cached: [String:OriginalStateRecord] = [:]
        var cases = 0,events = 0,helpers = 0,records = 0,bytes = 0,draws = 0,checkpoints = 0,callbacks = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value }
            guard let b = c.blobs[key] else { throw error("Missing blob") }
            let value = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 8_000_000)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw error("Blob SHA") };blobs[key] = value;return value
        }
        func storage(_ s: Storage) throws -> OriginalStateRecord {
            let key = s.bytes+s.defined;if let value = cached[key] { return value }
            let raw = try blob(s.bytes),mask = try blob(s.defined)
            guard raw.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Mask extent") }
            let value = try OriginalStateRecord(bytes: raw,defined: mask.map { $0 != 0 });cached[key] = value;return value
        }
        func defined(_ key: String) throws -> OriginalStateRecord {
            if let value = cached[key] { return value }
            let raw = try blob(key),value = try OriginalStateRecord(bytes: raw,defined: [Bool](repeating: true,count: raw.count));cached[key] = value;return value
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if let i = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw error(label+"+"+String(i,radix:16)+" actual \(actual.bytes[i])/\(actual.defined[i]) expected \(expected.bytes[i])/\(expected.defined[i])")
            };records += 1;bytes += actual.bytes.count
        }
        func world(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var result = raw
            guard raw.bytes.count == 0x7d8,try raw.integer(at: 0x7d4,as: UInt32.self) == 0x60000020 else { throw error("World catalog") }
            try result.write(UInt32(0),at: 0x7d4)
            for i in 0..<400 {
                guard let ref = actors[try raw.integer(at: 0x194+i*4,as: UInt32.self)] else { throw error("World Actor") }
                try result.write(ref,at: 0x194+i*4)
            };return result
        }
        func snapshot(_ state: OriginalMatchPreparation,_ context: OriginalInputControlContext,_ value: Snapshot,_ label: String) throws {
            let raw = try blob(value.poolBytes),mask = try blob(value.poolMask)
            guard raw.count == 0x7d8+400*0x420,mask.count == raw.count,value.memory.isEmpty else { throw error("Pool/replay extent") }
            func part(_ at: Int,_ count: Int) throws -> OriginalStateRecord {
                try .init(bytes: Array(raw[at..<at+count]),defined: mask[at..<at+count].map { $0 != 0 })
            }
            try check(state.world,world(part(0,0x7d8)),label+" World")
            for i in 0..<400 {
                var record = try part(0x7d8+i*0x420,0x420)
                guard let ref = objects[try record.integer(at: 0x368,as: UInt32.self)] else { throw error("Actor Object") }
                try record.write(ref,at: 0x368);try check(state.actors[i],record,label+" Actor\(i)")
            }
            try check(state.globals,defined(value.globals),label+" globals")
            try check(context.savedPlayback,defined(value.saved),label+" saved playback")
            try check(context.memory.replayPointers,defined(value.pointers),label+" replay pointers")
        }
        func retained(_ state: OriginalMatchPreparation,_ context: OriginalInputControlContext,_ crt: OriginalCRTRandom,_ expected: Retained,_ label: String) throws {
            try check(state.world,world(storage(expected.world)),label+" early World")
            try check(state.globals,defined(expected.globals),label+" early globals")
            guard context.memory.allocations.count == expected.records.count,crt.state == expected.crtState,
                  context.memory.replayPointers.bytes == expected.pointers else { throw error("Early ownership/CRT") }
            for r in expected.records {
                guard let actual = context.memory.allocations[r.address],actual.live == r.live else { throw error(label+" liveness") }
                try check(actual.storage,storage(r.storage),label+" retained bitmap")
            }
        }
        let parent = try ModeScreenReference.compare(screen: screen,startup: startup,menu: menu,loading: loading,catalog: catalog,sounds: sounds) { own,initialContext,crt,_,_ in
            callbacks += 1;var state = own,context = initialContext
            for (i,item) in c.cases.enumerated() {
                guard item.inherited == (i == 0),i != 0 || item.stimulus.isEmpty,!item.input.drawResults.isEmpty else { throw error("Own return entry") }
                for w in item.stimulus {
                    let chars = Array(w.bytes)
                    guard chars.count%2 == 0,w.address >= 0x44d000,UInt64(w.address)+UInt64(chars.count/2) <= 0x458440 else { throw error("Global stimulus extent") }
                    for j in stride(from: 0,to: chars.count,by: 2) {
                        guard let b = UInt8(String(chars[j...j+1]),radix:16) else { throw error("Stimulus hex") }
                        try state.globals.write(b,at: Int(w.address)-0x44d000+j/2)
                    }
                }
                try snapshot(state,context,item.before,item.label+" before");try retained(state,context,crt,item.earlyBefore,item.label+" before")
                guard item.fills.count <= 1 else { throw error("Notice fill count") }
                var eventIndex = 0,checkpointIndex = 0,blits = 0
                func event(_ e: OriginalFrontScreenEvent) throws {
                    guard eventIndex < item.events.count,e == item.events[eventIndex] else { throw error(item.label+" event\(eventIndex) actual \(e), expected \(eventIndex < item.events.count ? String(describing:item.events[eventIndex]) : "end")") }
                    eventIndex += 1;events += 1;if e.kind == "draw" { draws += 1 }
                }
                try OriginalMenuReturn.advance(state: &state,memory: &context.memory,input: item.input.presentation,milliseconds: item.input.milliseconds,
                    fillBacking: try item.fills.first.map(blob),wholeEarlyReturn: item.inherited,draw: { args,globals,memory in
                        guard let allocation = memory.allocations[args[0]],allocation.live else { throw error("Bitmap ownership") }
                        var bitmap = allocation.storage;let surface = try bitmap.integer(at: 0,as: UInt32.self)
                        try bitmap.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                        let request = try OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],mirrored: args[5],
                            sourceSurface: surface,targetSurface: args[6],viewportWidth: globals.integer(at: 0x44d78c-0x44d000,as: Int32.self),viewportHeight: globals.integer(at: 0x44d790-0x44d000,as: Int32.self))
                        _ = try OriginalBitmapDrawing.draw(request,bitmap: bitmap,observeRead: { r in
                            var e = OriginalFrontScreenEvent("read");e.read = r;try event(e)
                        },observeClip: { clip in
                            var e = OriginalFrontScreenEvent("clip");e.clip = clip;try event(e)
                        },perform: { blit in
                            var e = OriginalFrontScreenEvent("blit");e.blit = blit;try event(e)
                            defer { blits += 1 };return item.input.drawResults[blits%item.input.drawResults.count]
                        })
                    },observe: event,checkpoint: { kind,own in
                        guard checkpointIndex < item.checkpoints.count else { throw error("Unexpected checkpoint") }
                        let p = item.checkpoints[checkpointIndex];checkpointIndex += 1;checkpoints += 1
                        let points: [String:(UInt32,UInt32)] = ["menuReturned":(0x4229e2,0x1000e9bc),"matchBeforeReturn":(0x422a95,0x1000e9bc),
                            "loadingReturned":(0x424746,0x1000f000),"heldCleared":(0x4287de,0x1000f000),"earlyReturned":(0x30000000,0x1000f42c)]
                        guard p.kind == kind,let expected = points[kind],p.pc == expected.0,p.sp == expected.1,p.saved.count == 4 else { throw error("Return checkpoint ABI "+kind) }
                        if item.inherited {
                            let seh: UInt32 = kind == "earlyReturned" ? 0x12345678 : (kind == "loadingReturned" || kind == "heldCleared") ? 0x1000f418 : 0x1000efb4
                            guard p.seh == seh else { throw error("Restored SEH "+kind) }
                            if kind == "earlyReturned" { guard p.saved == [0x11223344,0x22334455,0x33445566,0x44556677] else { throw error("Outer saved registers") } }
                        }
                        try check(own.globals,defined(p.globals),item.label+" "+kind)
                    })
                guard eventIndex == item.events.count,checkpointIndex == item.checkpoints.count else { throw error("Completion") }
                for h in item.helpers {
                    let pop: UInt32 = h.entry == 0x43f010 ? 24 : 0
                    guard h.saved.count == 4,h.pop == pop,h.returnSP == h.entrySP+4+pop,helperReturns[h.entry]?.contains(h.returnPC) == true else { throw error("Helper ABI "+String(h.entry,radix:16)+" to "+String(h.returnPC,radix:16)) }
                }
                helpers += item.helpers.count
                try snapshot(state,context,item.after,item.label+" after");try retained(state,context,crt,item.earlyAfter,item.label+" after")
                cases += 1
            }
        }
        guard callbacks == 1 else { throw error("Missing own first screen") }
        return .init(parent: parent,cases: cases,events: events,helpers: helpers,records: records,bytes: bytes,draws: draws,checkpoints: checkpoints)
    }
}
