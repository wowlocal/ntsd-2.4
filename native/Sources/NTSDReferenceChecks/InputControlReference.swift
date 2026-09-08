import Foundation
import NTSDCore

public enum InputControlReference {
    public struct Result {
        public let local: LocalInputReference.Result
        public let cases: Int, records: Int, bytes: Int, events: Int, actions: Int, sends: Int, receives: Int, messages: Int, restores: Int, resets: Int
    }
    struct Blob: Decodable { let count: Int, deflate: String }
    struct Memory: Decodable, Equatable { let bytes: String, defined: String, live: Bool }
    struct Snapshot: Decodable, Equatable {
        let poolBytes: String, poolMask: String, globals: String, saved: String, pointers: String, memory: [Memory]
    }
    struct GlobalWrite: Decodable { let address: UInt32, bytes: String }
    struct ActorWrite: Decodable { let slot: Int, offset: Int, bytes: String }
    struct WorldWrite: Decodable { let offset: Int, bytes: String }
    struct BufferWrite: Decodable { let index: Int, offset: Int, bytes: String }
    struct Stimulus: Decodable {
        let globals: [GlobalWrite], actors: [ActorWrite], world: [WorldWrite], seats: [Int], buffers: [BufferWrite]
        let saved: [UInt8]?, pointers: [UInt32]?, live: [Bool]?, commands: [UInt8]?, playback: [UInt8]?
    }
    struct Platform: Decodable {
        let asyncResults: [Int32], ioctlResults: [Int32], ioctlBytes: [UInt8], sendResult: Int32
        let receives: [OriginalInputControlResponse], methodResult: Int32, messageResult: Int32, postResult: Int32
    }
    struct Event: Decodable {
        let kind: OriginalInputControlRequest.Kind, arguments: [UInt32], data: [[UInt8]], response: OriginalInputControlResponse?
    }
    struct Call: Decodable { let entry: UInt32, entrySP: UInt32, returnAddress: UInt32, arguments: [UInt32], saved: [UInt32], returnSP: UInt32 }
    struct Case: Decodable {
        let label: String, stimulus: Stimulus, platform: Platform, paused: Int32, inherited: Bool
        let stackBefore: [UInt8], stackAfter: [UInt8], scratchBefore: UInt32, scratchAfter: UInt32
        let events: [Event], helperCalls: [Call], receiveCalls: [Call], control: Snapshot, controlCommands: [UInt8], menuRegister: UInt32, after: Snapshot, endPC: UInt32
    }
    struct Parent: Decodable { let fixture: String, sha256: String }
    private struct Corpus: Decodable {
        let exeSHA256: String, control: Bool, parents: [String:Parent], worldAddress: UInt32, objectAddresses: [UInt32], actorAddresses: [UInt32]
        let bodySP: UInt32, bufferAddresses: [UInt32], initialContext: Snapshot, messages: [String:[UInt8]], cases: [Case], blobs: [String:Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Input-control reference: \(message)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let text = Array(text.utf8); guard text.count%2 == 0 else { throw error("Hex extent") }
        func digit(_ c: UInt8) throws -> UInt8 {
            switch c { case 48...57:return c-48;case 97...102:return c-87;default:throw error("Hex digit") }
        }
        return try stride(from: 0,to: text.count,by: 2).map { try digit(text[$0])*16+digit(text[$0+1]) }
    }

    public static func compare(control: Data, local: Data, loading: Data, catalog: Data, sounds: Data,
                               onNatural: ((OriginalMatchPreparation, OriginalInputControlContext, [UInt8], [UInt8], Bool, OriginalReplayTickEntry) throws -> Void)? = nil) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(control,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.worldAddress == 0x68000020, c.bodySP == 0x1000e9fc, c.objectAddresses.count == 137, Set(c.objectAddresses).count == 137,
              c.actorAddresses.count == 400, Set(c.actorAddresses).count == 400, c.bufferAddresses == [0x2a000020,0x2b000020], !c.cases.isEmpty else { throw error("Source identity") }
        for (key,data) in [("local-input",local),("initial-loading",loading),("initial-loading-catalog",catalog),("initial-loading-sounds",sounds)] {
            guard let p = c.parents[key], MatchPreparationReference.digest(data) == p.sha256 else { throw error("Parent SHA \(key)") }
        }
        let actorMap = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objectMap = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        var blobs: [String:[UInt8]] = [:], memoryRecords: [String:OriginalStateRecord] = [:], pools: [String:OriginalStateRecord] = [:]
        var records = 0, bytes = 0, events = 0, actions = 0, sends = 0, receives = 0, messages = 0, restores = 0, resets = 0, callbacks = 0
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
            let raw = try blob(item.bytes), mask = try blob(item.defined)
            guard raw.count == OriginalReplayRecording.byteCount, mask.count == raw.count, mask.allSatisfy({ $0 == 1 }) else { throw error("Supplied buffer/mask extent") }
            let value = try OriginalStateRecord(bytes: raw,defined: mask.map { $0 != 0 }); memoryRecords[key] = value; return value
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
        let parent = try LocalInputReference.compare(input: local,loading: loading,catalog: catalog,sounds: sounds,onNatural: { initial,initialCommands,paused in
            callbacks += 1; guard callbacks == 1, paused == c.control else { throw error("Natural parent") }
            var state = initial, commands = initialCommands
            var owned = OriginalMenuPresentationMemory(replayPointers: try defined(c.initialContext.pointers,8))
            guard owned.replayPointers.bytes == [UInt8](repeating: 0,count: 8), c.initialContext.memory.count == 2 else { throw error("Initial inactive replay ownership") }
            for (index,address) in c.bufferAddresses.enumerated() {
                owned.allocations[address] = .init(storage: try memory(c.initialContext.memory[index]),live: c.initialContext.memory[index].live)
            }
            var context = OriginalInputControlContext(savedPlayback: try defined(c.initialContext.saved,0x320),memory: owned)
            try snapshot(state,context,c.initialContext,"Initial input-control state")
            for (index,item) in c.cases.enumerated() {
                guard item.inherited == (index == 0), item.stackBefore.count == 28, item.stackAfter.count == 28 else { throw error("Case sequence/stack") }
                for w in item.stimulus.globals {
                    for (i,b) in try hex(w.bytes).enumerated() { try state.globals.write(b,at: Int(w.address)-OriginalMatchPreparation.globalBase+i) }
                }
                for w in item.stimulus.actors {
                    guard state.actors.indices.contains(w.slot) else { throw error("Actor input") }
                    for (i,b) in try hex(w.bytes).enumerated() { try state.actors[w.slot].write(b,at: w.offset+i) }
                }
                for w in item.stimulus.world { for (i,b) in try hex(w.bytes).enumerated() { try state.world.write(b,at: w.offset+i) } }
                guard item.stimulus.seats.isEmpty || item.stimulus.seats.count == 8 else { throw error("Seat inputs") }
                for (seat,actor) in item.stimulus.seats.enumerated() {
                    guard (0..<400).contains(actor) else { throw error("Actor ordinal") }; try state.world.write(UInt32(actor),at: 0x194+seat*4)
                }
                if let saved = item.stimulus.saved {
                    guard saved.count == 0x320 else { throw error("Saved input extent") }; context.savedPlayback = try .init(bytes: saved,defined: [Bool](repeating: true,count: saved.count))
                }
                if let pointers = item.stimulus.pointers {
                    guard pointers.count == 2 else { throw error("Pointer inputs") }
                    for (i,p) in pointers.enumerated() { try context.memory.replayPointers.write(p,at: i*4) }
                }
                if let live = item.stimulus.live {
                    guard live.count == 2 else { throw error("Live inputs") }
                    for (i,address) in c.bufferAddresses.enumerated() { context.memory.allocations[address]!.live = live[i] }
                }
                for w in item.stimulus.buffers {
                    guard (0..<2).contains(w.index) else { throw error("Buffer input") }
                    let address = c.bufferAddresses[w.index]
                    for (i,b) in try hex(w.bytes).enumerated() { try context.memory.allocations[address]!.storage.write(b,at: w.offset+i) }
                }
                let playback: [UInt8]
                if item.inherited {
                    guard item.stimulus.commands == nil, item.stimulus.playback == nil, item.paused == (paused ? 1 : 0) else { throw error("Inherited command inputs") }
                    playback = [UInt8](repeating: 0,count: 10)
                } else {
                    guard let input = item.stimulus.commands, let replay = item.stimulus.playback else { throw error("Declared commands") }
                    commands = input; playback = replay
                }
                guard commands == Array(item.stackBefore[4..<14]), playback == Array(item.stackBefore[16..<26]) else { throw error("Command provenance") }
                var eventIndex = 0, asyncIndex = 0, ioctlIndex = 0, receiveIndex = 0, actionIndex = 0, scratch = item.scratchBefore
                let menu = try state.controlInput(commands: &commands,playbackCommands: playback,context: &context,boundary: { request in
                    guard eventIndex < item.events.count else { throw error(item.label+" extra event") }
                    let e = item.events[eventIndex]; eventIndex += 1; events += 1
                    guard request == .init(e.kind,e.arguments,e.data) else { throw error("\(item.label) event\(eventIndex): \(request) vs \(e.kind)/\(e.arguments)/\(e.data)") }
                    let response: OriginalInputControlResponse?
                    switch request.kind {
                    case .asyncSelect:
                        guard asyncIndex < item.platform.asyncResults.count else { throw error("Async response") }
                        response = .init(result: item.platform.asyncResults[asyncIndex]); asyncIndex += 1
                    case .ioctl:
                        guard ioctlIndex < item.platform.ioctlResults.count else { throw error("IO response") }
                        let output = ioctlIndex == 1 ? item.platform.ioctlBytes : []
                        if ioctlIndex == 1 {
                            guard output.isEmpty || output.count == 4 else { throw error("IO output") }
                            scratch = output.isEmpty ? 0 : output.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
                        }
                        response = .init(result: item.platform.ioctlResults[ioctlIndex],bytes: output); ioctlIndex += 1
                    case .send: sends += 1; response = .init(result: item.platform.sendResult)
                    case .receive:
                        guard receiveIndex < item.platform.receives.count else { throw error("Receive response") }
                        response = item.platform.receives[receiveIndex]; receiveIndex += 1; receives += 1
                    case .message:
                        guard request.arguments.count == 4, c.messages[String(request.arguments[1])] != nil else { throw error("Original message identity") }
                        messages += 1; response = .init(result: item.platform.messageResult)
                    case .postMessage: response = .init(result: item.platform.postResult)
                    case .method: response = .init(result: item.platform.methodResult)
                    case .free: response = .init()
                    case .action:
                        guard actionIndex < item.helperCalls.count, request.arguments.count == 1 else { throw error("Helper witness") }
                        let call = item.helperCalls[actionIndex], entry = request.arguments[0], output = c.bodySP+0x434
                        let args: [UInt32]
                        switch entry {
                        case 0x416c70,0x416ca0: args = [output]
                        case 0x416dd0,0x416df0: args = [0x44d020]
                        case 0x416cd0: args = [0x44d020,0x451160]
                        case 0x416e10,0x416e30: args = [output,0x44d020]
                        case 0x416e60,0x416eb0,0x416f10,0x416f60: args = [output,0x44d020,0x451160]
                        default: throw error("Helper entry")
                        }
                        guard call.entry == entry, call.arguments == args, call.entrySP == c.bodySP-UInt32((args.count+1)*4), call.returnSP == call.entrySP+4,
                              call.saved.count == 4, (0x41c5e5..<0x41d469).contains(call.returnAddress) else { throw error("Real helper ABI") }
                        actionIndex += 1; actions += 1; response = nil
                    case .restorePlayback: restores += 1; response = nil
                    case .inputReset: resets += 1; response = nil
                    case .soundRequest: response = nil
                    }
                    guard response == e.response else { throw error("OS response provenance") }
                    return response ?? .init() // Observation events do not replace helper bodies.
                })
                guard eventIndex == item.events.count, receiveIndex == item.platform.receives.count, actionIndex == item.helperCalls.count,
                      UInt32(bitPattern: menu) == item.menuRegister, scratch == item.scratchAfter, commands == item.controlCommands else { throw error(item.label+" control result") }
                try snapshot(state,context,item.control,item.label+" control")
                let phase = try state.globals.integer(at: 0x450b90-OriginalMatchPreparation.globalBase,as: UInt32.self)
                let next = try state.receiveInput(paused: item.paused != 0,commands: &commands,playbackCommands: playback)
                let entries: [UInt32] = item.paused != 0 ? [] : next == .playbackChecksum ? [0x4198f0,0x4197a0] : [0x4198f0]
                guard item.receiveCalls.count == entries.count else { throw error("Received-input call count") }
                for (i,entry) in entries.enumerated() {
                    let call = item.receiveCalls[i], remote = entry == 0x4198f0
                    let args: [UInt32] = remote ? [0x44f198,phase,c.bodySP+0x434] : [c.bodySP+0x440,phase]
                    guard call.entry == entry, call.arguments == args, call.entrySP == c.bodySP-UInt32((args.count+1)*4), call.returnSP == c.bodySP,
                          call.saved.count == 4, call.returnAddress == (remote ? 0x41d495 : 0x41d4b7) else { throw error("Real received-input ABI") }
                }
                var stack = item.stackBefore; stack.replaceSubrange(4..<14,with: commands)
                guard stack == item.stackAfter, item.endPC == (next == .playbackChecksum ? 0x41d4b7 : 0x41d5db) else { throw error(item.label+" received result") }
                try snapshot(state,context,item.after,item.label+" received")
                if index == 0 {
                    try onNatural?(state,context,commands,playback,item.paused != 0,next == .playbackChecksum ? .playbackChecksum : .recording)
                }
            }
        })
        guard callbacks == 1 else { throw error("Missing native parent") }
        return .init(local: parent,cases: c.cases.count,records: records,bytes: bytes,events: events,actions: actions,sends: sends,receives: receives,messages: messages,restores: restores,resets: resets)
    }
}
