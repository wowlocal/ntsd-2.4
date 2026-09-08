import Foundation
import NTSDCore

public enum ReplayTickReference {
    public struct Result {
        public let parent: InputControlReference.Result
        public let cases: Int, records: Int, bytes: Int, events: Int, reads: Int, writes: Int, checks: Int, messages: Int, chains: Int
    }
    private typealias Blob = InputControlReference.Blob
    private typealias Snapshot = InputControlReference.Snapshot
    private typealias Memory = InputControlReference.Memory
    private typealias Stimulus = InputControlReference.Stimulus
    private typealias Parent = InputControlReference.Parent
    private struct Prefix: Decodable { let state: Snapshot, stack: [UInt8] }
    private struct Event: Decodable {
        let kind: OriginalReplayTickEvent.Kind, arguments: [UInt32], data: [[UInt8]], response: Int32?
    }
    private struct Call: Decodable { let entry: UInt32, entrySP: UInt32, returnAddress: UInt32, argument: UInt32, saved: [UInt32], returnSP: UInt32 }
    private struct LocalCall: Decodable { let entrySP: UInt32, returnAddress: UInt32, arguments: [UInt32], saved: [UInt32] }
    private struct Case: Decodable {
        let label: String, kind: String, entry: OriginalReplayTickEntry, paused: Int32, inherited: Bool, stimulus: Stimulus
        let stackBefore: [UInt8], stackAfter: [UInt8], scratchBefore: UInt32, scratchAfter: UInt32
        let prefix: Prefix?, control: InputControlReference.Case?, events: [Event], calls: [Call], localCall: LocalCall?
        let messageResult: Int32, menuRegister: UInt32, after: Snapshot, endPC: UInt32
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, control: Bool, parents: [String:Parent], worldAddress: UInt32, objectAddresses: [UInt32], actorAddresses: [UInt32]
        let bodySP: UInt32, bufferAddresses: [UInt32], initialContext: Snapshot, cases: [Case], messages: [String:[UInt8]], blobs: [String:Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Replay tick reference: \(message)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let text = Array(text.utf8); guard text.count%2 == 0 else { throw error("Hex extent") }
        func digit(_ c: UInt8) throws -> UInt8 { switch c { case 48...57:return c-48;case 97...102:return c-87;default:throw error("Hex digit") } }
        return try stride(from: 0,to: text.count,by: 2).map { try digit(text[$0])*16+digit(text[$0+1]) }
    }

    public static func compare(replay: Data, control: Data, local: Data, loading: Data, catalog: Data, sounds: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(replay,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.worldAddress == 0x68000020, c.bodySP == 0x1000e9fc, c.objectAddresses.count == 137, Set(c.objectAddresses).count == 137,
              c.actorAddresses.count == 400, Set(c.actorAddresses).count == 400, c.bufferAddresses == [0x2a000020,0x2b000020], !c.cases.isEmpty else { throw error("Source identity") }
        for (key,data) in [("input-control",control),("local-input",local),("initial-loading",loading),("initial-loading-catalog",catalog),("initial-loading-sounds",sounds)] {
            guard let p = c.parents[key], MatchPreparationReference.digest(data) == p.sha256 else { throw error("Parent SHA \(key)") }
        }
        let actorMap = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objectMap = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        var blobs: [String:[UInt8]] = [:], memoryRecords: [String:OriginalStateRecord] = [:], pools: [String:OriginalStateRecord] = [:]
        var memoryMasks: [String:[Bool]] = [:]
        var records = 0, bytes = 0, events = 0, reads = 0, writes = 0, checks = 0, messages = 0, chains = 0, callbacks = 0
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
        let parent = try InputControlReference.compare(control: control,local: local,loading: loading,catalog: catalog,sounds: sounds,onNatural: { initial,initialContext,initialCommands,initialPlayback,initialPaused,initialEntry in
            callbacks += 1; guard callbacks == 1, initialPaused == c.control else { throw error("Natural control parent") }
            var state = initial, context = initialContext, commands = initialCommands, playback = initialPlayback
            try snapshot(state,context,c.initialContext,"Initial replay tick state")
            for (caseIndex,item) in c.cases.enumerated() {
                guard item.inherited == (caseIndex == 0), ["prefix","finish","chain"].contains(item.kind), item.stackBefore.count == 28, item.stackAfter.count == 28 else { throw error("Case shape") }
                let s = item.stimulus
                for w in s.globals { for (i,b) in try hex(w.bytes).enumerated() { try state.globals.write(b,at: Int(w.address)-OriginalMatchPreparation.globalBase+i) } }
                for w in s.actors {
                    guard state.actors.indices.contains(w.slot) else { throw error("Actor input") }
                    for (i,b) in try hex(w.bytes).enumerated() { try state.actors[w.slot].write(b,at: w.offset+i) }
                }
                for w in s.world { for (i,b) in try hex(w.bytes).enumerated() { try state.world.write(b,at: w.offset+i) } }
                guard s.seats.isEmpty || s.seats.count == 20 else { throw error("Seat input extent") }
                for (seat,actor) in s.seats.enumerated() {
                    guard (0..<400).contains(actor) else { throw error("Actor input ordinal") }; try state.world.write(UInt32(actor),at: 0x194+seat*4)
                }
                if let saved = s.saved { guard saved.count == 0x320 else { throw error("Saved input extent") }; context.savedPlayback = try .init(bytes: saved,defined: [Bool](repeating: true,count: saved.count)) }
                if let pointers = s.pointers {
                    guard pointers.count == 2 else { throw error("Pointer inputs") }
                    for (i,p) in pointers.enumerated() { try context.memory.replayPointers.write(p,at: i*4) }
                }
                if let live = s.live {
                    guard live.count == 2 else { throw error("Lifetime inputs") }
                    for (i,a) in c.bufferAddresses.enumerated() { context.memory.allocations[a]!.live = live[i] }
                }
                for w in s.buffers {
                    guard (0..<2).contains(w.index) else { throw error("Buffer inputs") }
                    for (i,b) in try hex(w.bytes).enumerated() { try context.memory.allocations[c.bufferAddresses[w.index]]!.storage.write(b,at: w.offset+i) }
                }
                if item.inherited {
                    guard item.kind == "finish", item.paused == (initialPaused ? 1 : 0), item.entry == initialEntry, s.commands == nil, s.playback == nil else { throw error("Inherited inputs") }
                } else {
                    guard let a = s.commands, let b = s.playback else { throw error("Declared commands") }; commands = a; playback = b
                }
                guard commands == Array(item.stackBefore[4..<14]), playback == Array(item.stackBefore[16..<26]) else { throw error("Command provenance") }
                var eventIndex = 0, callIndex = 0, scratch = item.scratchBefore
                let observe: (OriginalReplayTickEvent) throws -> Void = { event in
                    guard eventIndex < item.events.count else { throw error(item.label+" extra event") }
                    let e = item.events[eventIndex]; eventIndex += 1; events += 1
                    guard event == .init(e.kind,e.arguments,e.data) else { throw error("\(item.label) event\(eventIndex): \(event) vs \(e.kind)/\(e.arguments)/\(e.data)") }
                    if event.kind == .message {
                        messages += 1
                        guard e.response == item.messageResult, event.arguments.count == 4, c.messages[String(event.arguments[1])] != nil else { throw error("Message boundary") }
                    } else { guard e.response == nil else { throw error("Unexpected observation response") } }
                    if event.kind == .readPacket || event.kind == .writePacket {
                        let read = event.kind == .readPacket
                        if read { reads += 1 } else { writes += 1 }
                        guard callIndex < item.calls.count else { throw error("Packet call witness") }
                        let call = item.calls[callIndex]; callIndex += 1
                        guard call.entry == (read ? 0x43dc50 : 0x43db40), call.entrySP == c.bodySP-8, call.returnSP == c.bodySP-4,
                              call.returnAddress == (read ? 0x41be88 : 0x41d613), call.saved.count == 4,
                              read ? call.argument == c.bodySP+0x440 : [c.bodySP+0x434,c.bodySP+0x440].contains(call.argument) else { throw error("Original packet ABI") }
                    }
                    if event.kind == .readChecksum || event.kind == .writeChecksum { checks += 1 }
                }
                func stack() -> [UInt8] { var v = item.stackBefore; v.replaceSubrange(4..<14,with: commands); v.replaceSubrange(16..<26,with: playback); return v }
                if item.kind == "prefix" || item.kind == "chain" {
                    try state.prepareReplayCommands(paused: item.paused != 0,commands: &commands,playbackCommands: &playback,context: context,observe: observe)
                    guard let prefix = item.prefix, prefix.stack == stack() else { throw error(item.label+" prefix stack") }
                    try snapshot(state,context,prefix.state,item.label+" prefix")
                } else { guard item.prefix == nil else { throw error("Unexpected prefix") } }
                var entry = item.entry
                if item.kind == "chain" {
                    chains += 1
                    guard let old = item.control else { throw error("Control continuation") }
                    let phase = try state.globals.integer(at: 0x450b90-OriginalMatchPreparation.globalBase,as: UInt32.self)
                    let mode = try state.globals.integer(at: 0x451160-OriginalMatchPreparation.globalBase,as: UInt32.self)
                    try state.beginLocalInput(paused: item.paused != 0,commands: &commands) // No supplied AI/no-effect handler.
                    if item.paused == 0 {
                        guard let local = item.localCall, local.entrySP == c.bodySP-16, local.returnAddress == 0x41c5e5,
                              local.arguments == [phase,mode,c.bodySP+0x434], local.saved.count == 4 else { throw error("Local caller ABI") }
                    } else { guard item.localCall == nil else { throw error("Paused local call") } }
                    guard old.stackBefore == stack() else { throw error("Local/control command continuation") }
                    var position = 0, asyncIndex = 0, ioctlIndex = 0, receiveIndex = 0, actionIndex = 0
                    let menu = try state.controlInput(commands: &commands,playbackCommands: playback,context: &context,boundary: { request in
                        guard position < old.events.count else { throw error("Extra control event") }
                        let e = old.events[position]; position += 1
                        guard request == .init(e.kind,e.arguments,e.data) else { throw error(item.label+" control event \(position)") }
                        let response: OriginalInputControlResponse?
                        switch request.kind {
                        case .asyncSelect: response = .init(result: old.platform.asyncResults[asyncIndex]); asyncIndex += 1
                        case .ioctl:
                            let output = ioctlIndex == 1 ? old.platform.ioctlBytes : []
                            if ioctlIndex == 1 { scratch = output.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) } }
                            response = .init(result: old.platform.ioctlResults[ioctlIndex],bytes: output); ioctlIndex += 1
                        case .send: response = .init(result: old.platform.sendResult)
                        case .receive: response = old.platform.receives[receiveIndex]; receiveIndex += 1
                        case .message: response = .init(result: old.platform.messageResult)
                        case .postMessage: response = .init(result: old.platform.postResult)
                        case .method: response = .init(result: old.platform.methodResult)
                        case .free: response = .init()
                        case .action:
                            guard actionIndex < old.helperCalls.count, request.arguments.count == 1 else { throw error("Control helper witness") }
                            let call = old.helperCalls[actionIndex]; actionIndex += 1
                            let output = c.bodySP+0x434, args: [UInt32]
                            switch request.arguments[0] {
                            case 0x416c70,0x416ca0: args = [output]
                            case 0x416dd0,0x416df0: args = [0x44d020]
                            case 0x416cd0: args = [0x44d020,0x451160]
                            case 0x416e10,0x416e30: args = [output,0x44d020]
                            case 0x416e60,0x416eb0,0x416f10,0x416f60: args = [output,0x44d020,0x451160]
                            default: throw error("Control helper")
                            }
                            guard call.entry == request.arguments[0], call.arguments == args, call.entrySP == c.bodySP-UInt32((args.count+1)*4),
                                  call.returnSP == call.entrySP+4, call.saved.count == 4, (0x41c5e5..<0x41d469).contains(call.returnAddress) else { throw error("Control helper ABI") }
                            response = nil
                        case .soundRequest,.inputReset,.restorePlayback: response = nil
                        }
                        guard response == e.response else { throw error("Control response provenance") }; return response ?? .init()
                    })
                    guard position == old.events.count, actionIndex == old.helperCalls.count, receiveIndex == old.platform.receives.count,
                          UInt32(bitPattern: menu) == old.menuRegister, commands == old.controlCommands, scratch == old.scratchAfter else { throw error("Control result") }
                    try snapshot(state,context,old.control,item.label+" control")
                    let next = try state.receiveInput(paused: item.paused != 0,commands: &commands,playbackCommands: playback)
                    entry = next == .playbackChecksum ? .playbackChecksum : .recording
                    guard entry == item.entry, old.stackAfter == stack(), old.endPC == (entry == .playbackChecksum ? 0x41d4b7 : 0x41d5db) else { throw error("Received continuation") }
                    let entries: [UInt32] = item.paused != 0 ? [] : entry == .playbackChecksum ? [0x4198f0,0x4197a0] : [0x4198f0]
                    guard old.receiveCalls.count == entries.count else { throw error("Received call count") }
                    for (i,pc) in entries.enumerated() {
                        let call = old.receiveCalls[i], remote = pc == 0x4198f0
                        let args: [UInt32] = remote ? [0x44f198,phase,c.bodySP+0x434] : [c.bodySP+0x440,phase]
                        guard call.entry == pc, call.arguments == args, call.entrySP == c.bodySP-UInt32((args.count+1)*4), call.returnSP == c.bodySP,
                              call.saved.count == 4, call.returnAddress == (remote ? 0x41d495 : 0x41d4b7) else { throw error("Received ABI") }
                    }
                    try snapshot(state,context,old.after,item.label+" received")
                } else { guard item.control == nil, item.localCall == nil else { throw error("Unexpected control") } }
                if item.kind != "prefix" {
                    if entry == .playbackChecksum { scratch = UInt32(bitPattern: try state.globals.integer(at: 0x450b8c-OriginalMatchPreparation.globalBase,as: Int32.self)/150) }
                    try state.finishReplayInput(entry: entry,paused: item.paused != 0,commands: commands,playbackCommands: playback,context: &context,observe: observe)
                }
                guard eventIndex == item.events.count, callIndex == item.calls.count, scratch == item.scratchAfter, stack() == item.stackAfter,
                      item.endPC == (item.kind == "prefix" ? 0x41be8b : 0x41d714), item.menuRegister == (try state.globals.integer(at: 0x44d020-OriginalMatchPreparation.globalBase,as: UInt32.self)) else { throw error(item.label+" final witness") }
                try snapshot(state,context,item.after,item.label+" final")
            }
        })
        guard callbacks == 1 else { throw error("Missing native control parent") }
        return .init(parent: parent,cases: c.cases.count,records: records,bytes: bytes,events: events,reads: reads,writes: writes,checks: checks,messages: messages,chains: chains)
    }
}
