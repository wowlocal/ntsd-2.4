import Foundation
import NTSDCore

public enum ReceivedInputReference {
    public struct Result {
        public let local: LocalInputReference.Result
        public let cases: Int, bytes: Int, records: Int, remoteCalls: Int, playbackCalls: Int, continuous: Int
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Snapshot: Decodable { let world: Record, actors: [Record], globals: String }
    private struct GlobalWrite: Decodable { let address: UInt32, bytes: String }
    private struct WorldWrite: Decodable { let offset: Int, bytes: String }
    private struct ActorWrite: Decodable { let slot: Int, offset: Int, bytes: String }
    private struct Stimulus: Decodable { let globals: [GlobalWrite], actors: [ActorWrite], world: [WorldWrite], seats: [Int] }
    private struct Call: Decodable {
        let kind: String, entrySP: UInt32, returnAddress: UInt32, arguments: [UInt32], saved: [UInt32], returnSP: UInt32
        let after: Snapshot, commands: [UInt8]
    }
    private struct Case: Decodable {
        let label: String, kind: String, stimulus: Stimulus, phase: UInt32, paused: Int32, inherited: Bool, continuous: Bool
        let stackBefore: [UInt8], stackAfter: [UInt8], calls: [Call], after: Snapshot, entryPC: UInt32, endPC: UInt32, stackPointerAfter: UInt32
    }
    private struct Parent: Decodable { let fixture: String, sha256: String }
    private struct Corpus: Decodable {
        let exeSHA256: String, control: Bool, parents: [String: Parent], worldAddress: UInt32, objectAddresses: [UInt32], actorAddresses: [UInt32]
        let bodySP: UInt32, cases: [Case], blobs: [String: Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Received-input reference: \(message)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let utf8 = Array(text.utf8); guard utf8.count%2 == 0 else { throw error("Hex extent") }
        func value(_ c: UInt8) throws -> UInt8 {
            switch c { case 48...57:return c-48;case 97...102:return c-87;default:throw error("Hex digit") }
        }
        return try stride(from: 0,to: utf8.count,by: 2).map { try value(utf8[$0])*16+value(utf8[$0+1]) }
    }
    public static func compare(received: Data, local: Data, loading: Data, catalog: Data, sounds: Data) throws -> Result {
        // Two complete states per call plus caller intermediates exceed the
        // earlier64 MB transport bound; individual state blobs remain2 MB.
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(received,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.objectAddresses.count == 137, Set(c.objectAddresses).count == 137,
              c.actorAddresses.count == 400, Set(c.actorAddresses).count == 400,
              c.worldAddress == 0x68000020, c.bodySP == 0x1000e9fc, !c.cases.isEmpty else { throw error("Source/parent identity") }
        for (key,data) in [("local-input",local),("initial-loading",loading),("initial-loading-catalog",catalog),("initial-loading-sounds",sounds)] {
            guard let parent = c.parents[key], MatchPreparationReference.digest(data) == parent.sha256 else { throw error("Pinned parent \(key)") }
        }
        var blobs: [String:[UInt8]] = [:], stored: [String:OriginalStateRecord] = [:], actorCache: [String:OriginalStateRecord] = [:]
        var bytes = 0, records = 0, remoteCalls = 0, playbackCalls = 0, continuous = 0, parentCallbacks = 0
        let objects = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let actors = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        func blob(_ key: String) throws -> [UInt8] {
            if let raw = blobs[key] { return raw }
            guard let b = c.blobs[key], (0...2_000_000).contains(b.count) else { throw error("Blob extent") }
            let raw = try MatchPreparationReference.inflate(b.deflate,count: b.count)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob hash") }
            blobs[key] = raw; return raw
        }
        func record(_ item: Record) throws -> OriginalStateRecord {
            let key = item.bytes+item.defined
            if let value = stored[key] { return value }
            let raw = try blob(item.bytes), mask = try blob(item.defined)
            guard raw.count == mask.count, mask.allSatisfy({ $0<2 }) else { throw error("Mask") }
            let value = try OriginalStateRecord(bytes: raw,defined: mask.map { $0==1 }); stored[key] = value; return value
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if actual != expected {
                let offset = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                throw error("\(label)+\(String(offset,radix:16)): \(actual.bytes[offset])/\(actual.defined[offset]) vs \(expected.bytes[offset])/\(expected.defined[offset])")
            }
            bytes += actual.bytes.count; records += 1
        }
        func snapshot(_ state: OriginalMatchPreparation, _ expected: Snapshot, _ label: String) throws {
            guard expected.actors.count == 400 else { throw error("Pool extent") }
            let global = try blob(expected.globals)
            try check(state.globals,.init(bytes: global,defined: [Bool](repeating: true,count: global.count)),label+" globals")
            var world = try record(expected.world)
            guard try world.integer(at: 0x7d4,as: UInt32.self) == 0x60000020 else { throw error("World catalog binding") }
            try world.write(UInt32(0),at: 0x7d4)
            for i in 0..<400 {
                guard let ordinal = actors[try world.integer(at: 0x194+i*4,as: UInt32.self)] else { throw error("World Actor table") }
                try world.write(ordinal,at: 0x194+i*4)
            }
            try check(state.world,world,label+" World")
            for (i,item) in expected.actors.enumerated() {
                let key = item.bytes+item.defined
                var value: OriginalStateRecord
                if let cached = actorCache[key] { value = cached }
                else {
                    value = try record(item)
                    guard let object = objects[try value.integer(at: 0x368,as: UInt32.self)] else { throw error("Known Actor Object pointer") }
                    try value.write(object,at: 0x368); actorCache[key] = value
                }
                try check(state.actors[i],value,label+" Actor\(i)")
            }
        }
        let parent = try LocalInputReference.compare(input: local,loading: loading,catalog: catalog,sounds: sounds,onNatural: { initial,initialCommands,initialPaused in
            parentCallbacks += 1
            guard parentCallbacks == 1, initialPaused == c.control else { throw error("Natural input parent") }
            var state = initial, commands = initialCommands
            for (index,item) in c.cases.enumerated() {
                guard item.inherited == (index == 0), item.continuous == (index == 0 && !c.control),
                      item.stackBefore.count == 28, item.stackAfter.count == 28 else { throw error("Case order/stack extent") }
                for write in item.stimulus.globals {
                    for (i,b) in try hex(write.bytes).enumerated() { try state.globals.write(b,at: Int(write.address)-OriginalMatchPreparation.globalBase+i) }
                }
                for write in item.stimulus.world {
                    for (i,b) in try hex(write.bytes).enumerated() { try state.world.write(b,at: write.offset+i) }
                }
                for write in item.stimulus.actors {
                    guard (0..<400).contains(write.slot) else { throw error("Actor stimulus") }
                    for (i,b) in try hex(write.bytes).enumerated() { try state.actors[write.slot].write(b,at: write.offset+i) }
                }
                guard item.stimulus.seats.isEmpty || item.stimulus.seats.count == 8 else { throw error("Seat extent") }
                for (seat,ordinal) in item.stimulus.seats.enumerated() {
                    guard (0..<400).contains(ordinal) else { throw error("Seat ordinal") }
                    try state.world.write(UInt32(ordinal),at: 0x194+seat*4)
                }
                let playback = Array(item.stackBefore[16..<26])
                if item.inherited {
                    guard commands == Array(item.stackBefore[4..<14]), playback == [UInt8](repeating: 0,count: 10),
                          item.stimulus.globals.isEmpty, item.stimulus.world.isEmpty, item.stimulus.actors.isEmpty,
                          item.stimulus.seats.isEmpty, item.paused == (initialPaused ? 1 : 0), item.kind == "caller" else { throw error("Inherited continuity") }
                } else { commands = Array(item.stackBefore[4..<14]) }
                let phase = try item.kind == "caller" ? state.globals.integer(at: 0x450b90-OriginalMatchPreparation.globalBase,as: UInt32.self) : item.phase
                var callCount = 0
                func call(_ kind: String, _ current: OriginalMatchPreparation, _ output: [UInt8]) throws {
                    guard callCount < item.calls.count else { throw error("Extra native call") }
                    let expected = item.calls[callCount], caller = item.kind == "caller"
                    let args: [UInt32] = kind == "remote" ? [0x44f198,phase,c.bodySP+0x434] : [c.bodySP+0x440,phase]
                    let entrySP = caller ? c.bodySP-UInt32((args.count+1)*4) : 0x1000d000
                    guard expected.kind == kind, expected.arguments == args, expected.saved.count == 4,
                          expected.entrySP == entrySP, expected.returnSP == entrySP+UInt32((args.count+1)*4),
                          expected.returnAddress == (caller ? (kind == "remote" ? 0x41d495 : 0x41d4b7) : 0x30000000),
                          expected.commands == output else { throw error(item.label+" actual call/ret ABI or commands") }
                    try snapshot(current,expected.after,item.label+" "+kind)
                    if kind == "remote" { remoteCalls += 1 } else { playbackCalls += 1 }
                    callCount += 1
                }
                let expectedEnd: UInt32
                switch item.kind {
                case "remote":
                    guard item.entryPC == 0x4198f0 else { throw error("Remote entry") }
                    let packet = try (0..<10).map { try state.globals.integer(at: 0x44f198-OriginalMatchPreparation.globalBase+$0,as: UInt8.self) }
                    try state.remoteInput(packet: packet,phase: Int32(bitPattern: phase),commands: &commands)
                    try call("remote",state,commands); expectedEnd = 0x30000000
                case "playback":
                    guard item.entryPC == 0x4197a0 else { throw error("Playback entry") }
                    try state.playbackInput(packet: playback,phase: Int32(bitPattern: phase))
                    try call("playback",state,commands); expectedEnd = 0x30000000
                case "caller":
                    guard item.entryPC == (item.continuous ? 0x41c5e5 : 0x41d469), !item.continuous || phase != 0 else { throw error("Caller entry/phase1 jump") }
                    let next = try state.receiveInput(paused: item.paused != 0,commands: &commands,playbackCommands: playback,
                                                     afterRemote: { try call("remote",$0,$1) })
                    if next == .playbackChecksum { try call("playback",state,commands) }
                    expectedEnd = next == .playbackChecksum ? 0x41d4b7 : 0x41d5db
                    if item.continuous { continuous += 1 }
                default: throw error("Case kind")
                }
                var stack = item.stackBefore; stack.replaceSubrange(4..<14,with: commands)
                guard stack == item.stackAfter, callCount == item.calls.count, item.endPC == expectedEnd,
                      item.stackPointerAfter == (item.kind == "caller" ? c.bodySP : item.calls.last?.returnSP) else { throw error(item.label+" caller result/stack") }
                try snapshot(state,item.after,item.label+" final")
            }
        })
        guard parentCallbacks == 1 else { throw error("Missing parent callback") }
        return .init(local: parent,cases: c.cases.count,bytes: bytes,records: records,remoteCalls: remoteCalls,playbackCalls: playbackCalls,continuous: continuous)
    }
}
