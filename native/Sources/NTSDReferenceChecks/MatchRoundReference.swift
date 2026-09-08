import Foundation
import NTSDCore

public enum MatchRoundReference {
    public struct Result {
        public let parent: ReplayTickReference.Result
        public let cases: Int, records: Int, bytes: Int, events: Int, constructors: Int, teams: Int, stages: Int
        public let continuations: [String:Int]
    }
    private typealias Blob = InputControlReference.Blob
    private typealias Snapshot = InputControlReference.Snapshot
    private typealias Memory = InputControlReference.Memory
    private typealias Parent = InputControlReference.Parent
    private struct Stimulus: Decodable {
        let base: InputControlReference.Stimulus, bindings: [Int]
        private enum CodingKeys: String, CodingKey { case bindings }
        init(from decoder: Decoder) throws {
            base = try InputControlReference.Stimulus(from: decoder)
            bindings = try decoder.container(keyedBy: CodingKeys.self).decode([Int].self,forKey: .bindings)
        }
    }
    private struct Event: Decodable { let kind: OriginalMatchRoundEvent.Kind, arguments: [UInt32], response: Int32? }
    private struct Call: Decodable { let entry: UInt32, entrySP: UInt32, returnAddress: UInt32, this: UInt32, arguments: [UInt32], saved: [UInt32], returnSP: UInt32 }
    private struct Case: Decodable {
        let label: String, stimulus: Stimulus, paused: Int32, inherited: Bool, methodResult: Int32, events: [Event], calls: [Call]
        let stackBefore: [UInt8], stackAfter: [UInt8], stageDefeated: UInt32?, continuation: OriginalMatchRoundContinuation, endPC: UInt32, after: Snapshot
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, control: Bool, parents: [String:Parent], worldAddress: UInt32, objectAddresses: [UInt32], actorAddresses: [UInt32]
        let bodySP: UInt32, bufferAddresses: [UInt32], initialContext: Snapshot, cases: [Case], blobs: [String:Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Match round reference: \(message)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let text = Array(text.utf8); guard text.count%2 == 0 else { throw error("Hex extent") }
        func digit(_ c: UInt8) throws -> UInt8 { switch c { case 48...57:return c-48;case 97...102:return c-87;default:throw error("Hex digit") } }
        return try stride(from: 0,to: text.count,by: 2).map { try digit(text[$0])*16+digit(text[$0+1]) }
    }

    public static func compare(round: Data, replay: Data, control: Data, local: Data, loading: Data, catalog: Data, sounds: Data,
                               onNatural: ((OriginalMatchPreparation, OriginalInputControlContext, OriginalMatchRoundContinuation) throws -> Void)? = nil) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(round,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.worldAddress == 0x68000020, c.bodySP == 0x1000e9fc, c.objectAddresses.count == 137, Set(c.objectAddresses).count == 137,
              c.actorAddresses.count == 400, Set(c.actorAddresses).count == 400, c.bufferAddresses == [0x2a000020,0x2b000020], !c.cases.isEmpty else { throw error("Source identity") }
        for (key,data) in [("replay-tick",replay),("input-control",control),("local-input",local),("initial-loading",loading),("initial-loading-catalog",catalog),("initial-loading-sounds",sounds)] {
            guard let p = c.parents[key], MatchPreparationReference.digest(data) == p.sha256 else { throw error("Parent SHA \(key)") }
        }
        let actorMap = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objectMap = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        var blobs: [String:[UInt8]] = [:], memoryRecords: [String:OriginalStateRecord] = [:], pools: [String:OriginalStateRecord] = [:]
        var memoryMasks: [String:[Bool]] = [:]
        var records = 0, bytes = 0, events = 0, constructors = 0, teams = 0, stages = 0, callbacks = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value }
            guard let b = c.blobs[key], (0...8_000_000).contains(b.count) else { throw error("Blob extent") }
            let value = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 8_000_000)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw error("Blob SHA") }
            blobs[key] = value; return value
        }
        func memory(_ item: Memory) throws -> OriginalStateRecord {
            let key = item.bytes+item.defined
            if let value = memoryRecords[key] { return value }
            let raw = try blob(item.bytes)
            guard raw.count == OriginalReplayRecording.byteCount else { throw error("Supplied buffer extent") }
            // Packet writes change whole-buffer snapshots but share the same
            // initialization mask. Validate/convert each immutable mask once;
            // snapshot() still compares every native byte and mask value.
            let mask: [Bool]
            if let cached = memoryMasks[item.defined] { mask = cached }
            else {
                let source = try blob(item.defined)
                guard source.count == raw.count, source.allSatisfy({ $0 == 1 }) else { throw error("Supplied buffer mask") }
                mask = [Bool](repeating: true,count: source.count); memoryMasks[item.defined] = mask
            }
            let value = try OriginalStateRecord(bytes: raw,defined: mask); memoryRecords[key] = value; return value
        }
        func defined(_ key: String, _ count: Int) throws -> OriginalStateRecord {
            let value = try blob(key); guard value.count == count else { throw error("Defined record extent") }
            return try .init(bytes: value,defined: [Bool](repeating: true,count: count))
        }
        // Debug Array.== otherwise performs generic element comparisons over
        // every multi-megabyte replay buffer at each checkpoint. Compare the
        // complete storage; this does not sample bytes or trust cached hashes.
        func sameRepresentation<T>(_ lhs: [T], _ rhs: [T]) -> Bool {
            guard lhs.count == rhs.count else { return false }
            return lhs.withUnsafeBytes { left in rhs.withUnsafeBytes { right in
                left.isEmpty || memcmp(left.baseAddress!,right.baseAddress!,left.count) == 0
            } }
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String, count: Int = 1) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            // Equal Bool representations imply equal values. If representations
            // differ, retain semantic equality instead of assuming a Bool ABI.
            let sameMask = sameRepresentation(actual.defined,expected.defined) || actual.defined == expected.defined
            if !sameRepresentation(actual.bytes,expected.bytes) || !sameMask {
                let i = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                throw error("\(label)+\(String(i,radix:16)): \(actual.bytes[i])/\(actual.defined[i]) vs \(expected.bytes[i])/\(expected.defined[i])")
            }
            bytes += actual.bytes.count; records += count
        }
        func snapshot(_ state: OriginalMatchPreparation, _ context: OriginalInputControlContext, _ expected: Snapshot, _ label: String) throws {
            let key = expected.poolBytes+expected.poolMask
            let pool: OriginalStateRecord
            if let cached = pools[key] { pool = cached }
            else {
                let raw = try blob(expected.poolBytes), mask = try blob(expected.poolMask)
                guard raw.count == 0x7d8+400*0x420, mask.count == raw.count, mask.allSatisfy({ $0<2 }) else { throw error("Whole pool extent/mask") }
                var value = try OriginalStateRecord(bytes: raw,defined: mask.map { $0 != 0 })
                guard try value.integer(at: 0x7d4,as: UInt32.self) == 0x60000020 else { throw error("World catalog binding") }
                try value.write(UInt32(0),at: 0x7d4)
                for i in 0..<400 {
                    guard let actor = actorMap[try value.integer(at: 0x194+i*4,as: UInt32.self)],
                          let object = objectMap[try value.integer(at: 0x7d8+i*0x420+0x368,as: UInt32.self)] else { throw error("Known pool pointers") }
                    try value.write(actor,at: 0x194+i*4); try value.write(object,at: 0x7d8+i*0x420+0x368)
                }
                pools[key] = value; pool = value
            }
            let actual = try OriginalStateRecord(bytes: state.world.bytes+state.actors.flatMap(\.bytes),defined: state.world.defined+state.actors.flatMap(\.defined))
            try check(actual,pool,label+" World/400 Actor",count: 401)
            try check(state.globals,defined(expected.globals,OriginalMatchPreparation.globalSize),label+" globals")
            try check(context.savedPlayback,defined(expected.saved,0x320),label+" saved playback")
            try check(context.memory.replayPointers,defined(expected.pointers,8),label+" replay pointers")
            guard expected.memory.count == 2, context.memory.allocations.count == 2 else { throw error("Owned replay buffers") }
            for (index,address) in c.bufferAddresses.enumerated() {
                guard let allocation = context.memory.allocations[address], allocation.live == expected.memory[index].live else { throw error(label+" allocation lifetime") }
                try check(allocation.storage,memory(expected.memory[index]),label+" buffer\(index)")
            }
        }
        var continuations: [String:Int] = [:]
        let parent = try ReplayTickReference.compare(replay: replay,control: control,local: local,loading: loading,catalog: catalog,sounds: sounds,onNatural: { initial,initialContext,initialPaused in
            callbacks += 1; guard callbacks == 1, initialPaused == c.control else { throw error("Natural replay parent") }
            var state = initial, context = initialContext
            try snapshot(state,context,c.initialContext,"Initial round state")
            for (caseIndex,item) in c.cases.enumerated() {
                guard item.inherited == (caseIndex == 0), item.stackBefore.count == 28, item.stackBefore == item.stackAfter else { throw error("Case shape/stack") }
                if item.inherited { guard item.paused == (initialPaused ? 1 : 0) else { throw error("Natural pause provenance") } }
                let s = item.stimulus.base
                for w in s.globals { for (i,b) in try hex(w.bytes).enumerated() { try state.globals.write(b,at: Int(w.address)-OriginalMatchPreparation.globalBase+i) } }
                for w in s.actors {
                    guard state.actors.indices.contains(w.slot) else { throw error("Actor input") }
                    for (i,b) in try hex(w.bytes).enumerated() { try state.actors[w.slot].write(b,at: w.offset+i) }
                }
                for w in s.world { for (i,b) in try hex(w.bytes).enumerated() { try state.world.write(b,at: w.offset+i) } }
                guard s.seats.isEmpty || s.seats.count == 400, item.stimulus.bindings.isEmpty || item.stimulus.bindings.count == 400 else { throw error("World/Actor input extents") }
                for (seat,actor) in s.seats.enumerated() {
                    guard (0..<400).contains(actor) else { throw error("Actor input ordinal") }; try state.world.write(UInt32(actor),at: 0x194+seat*4)
                }
                for (actor,object) in item.stimulus.bindings.enumerated() {
                    guard (0..<137).contains(object) else { throw error("Object input ordinal") }; try state.actors[actor].write(UInt32(object),at: 0x368)
                }
                if let saved = s.saved { guard saved.count == 0x320 else { throw error("Saved input extent") }; context.savedPlayback = try .init(bytes: saved,defined: [Bool](repeating: true,count: saved.count)) }
                if let pointers = s.pointers {
                    guard pointers.count == 2 else { throw error("Pointer input extent") }
                    for (i,p) in pointers.enumerated() { try context.memory.replayPointers.write(p,at: i*4) }
                }
                guard s.live == nil, s.commands == nil, s.playback == nil else { throw error("Unsupported round stimulus") }
                for w in s.buffers {
                    guard (0..<2).contains(w.index) else { throw error("Buffer input") }
                    for (i,b) in try hex(w.bytes).enumerated() { try context.memory.allocations[c.bufferAddresses[w.index]]!.storage.write(b,at: w.offset+i) }
                }
                var eventIndex = 0, callIndex = 0
                let result = try state.beginMatchRound(paused: item.paused != 0,context: &context,observe: { event in
                    guard eventIndex < item.events.count else { throw error(item.label+" extra event") }
                    let e = item.events[eventIndex]; eventIndex += 1; events += 1
                    guard event == .init(e.kind,e.arguments) else { throw error("\(item.label) event\(eventIndex): \(event) vs \(e.kind)/\(e.arguments)") }
                    if event.kind == .method { guard e.response == item.methodResult else { throw error("COM input provenance") }; return }
                    guard e.response == nil else { throw error("Unexpected helper response") }
                    if event.kind == .teams { teams += 1; return }
                    if event.kind == .stageScan { stages += 1; return }
                    guard callIndex < item.calls.count else { throw error("Missing helper witness") }
                    let call = item.calls[callIndex]; callIndex += 1
                    let entry: UInt32, returns: [UInt32], arguments: [UInt32]
                    switch event.kind {
                    case .stopMusic: entry = 0x402100; returns = [0x41db7f,0x41dd38]; arguments = []
                    case .soundRequest:
                        entry = 0x401a30; returns = [0x41dd44]; arguments = [0]
                        guard call.this == 0x45561c else { throw error("Sound slot") }
                    case .reconstruct:
                        constructors += 1; entry = 0x4061d0; returns = [0x41df5f]; arguments = []
                        guard event.arguments.count == 1, actorMap[call.this] == event.arguments[0] else { throw error("Constructor this") }
                    case .inputReset:
                        entry = 0x431c70; returns = [0x41e128]; arguments = []
                        guard call.this == c.worldAddress else { throw error("Reset this") }
                    case .restorePlayback: entry = 0x43df00; returns = [0x41e15c]; arguments = []
                    default: throw error("Unexpected helper")
                    }
                    guard call.entry == entry, returns.contains(call.returnAddress), call.arguments == arguments,
                          call.entrySP == c.bodySP-UInt32((arguments.count+1)*4), call.returnSP == c.bodySP, call.saved.count == 4 else { throw error(item.label+" helper ABI") }
                })
                let pc: UInt32
                switch result.continuation { case .pausedRendering:pc=0x41d73b;case .gameplay:pc=0x41e339;case .menu:pc=0x4229cc;case .epilogue:pc=0x422a95 }
                guard result.continuation == item.continuation, result.stageDefeated == item.stageDefeated, pc == item.endPC,
                      eventIndex == item.events.count, callIndex == item.calls.count else { throw error(item.label+" continuation/local result") }
                continuations[result.continuation.rawValue,default: 0] += 1
                try snapshot(state,context,item.after,item.label+" final")
                if caseIndex == 0 { try onNatural?(state,context,result.continuation) }
            }
        })
        guard callbacks == 1 else { throw error("Missing native replay parent") }
        return .init(parent: parent,cases: c.cases.count,records: records,bytes: bytes,events: events,constructors: constructors,teams: teams,stages: stages,continuations: continuations)
    }
}
