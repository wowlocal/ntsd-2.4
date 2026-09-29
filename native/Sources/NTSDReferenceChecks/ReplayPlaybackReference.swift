import Foundation
import NTSDCore

/// Compares OriginalReplayPlayback with real43dfa0 calls captured after the
/// verified first loading. Recordings are the app's own files, loaded through
/// OriginalReplayFileInput, with each case's declared edits. Layer/music calls,
/// Actor constructors, globals with their initialization masks, the recording's
/// written bytes, World and every Actor must agree. APPLICATION_PLAYBACK_PLAN.md P2.
public enum ReplayPlaybackReference {
    public struct Result {
        public let initial: InitialLoadingReference.Result
        public let cases: Int, records: Int, bytes: Int, calls: Int, constructors: Int, blocks: Int
        public let families: [String: Int]
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct GlobalWrite: Decodable { let address: UInt32, bytes: String }
    private struct WorldWrite: Decodable { let offset: Int, bytes: String }
    private struct ActorWrite: Decodable { let slot: Int, offset: Int, bytes: String }
    private struct Stimulus: Decodable { let recording: String, edits: [[Int32]], globals: [GlobalWrite] }
    private struct RecordingWrite: Decodable { let offset: Int, bytes: String }
    private struct Call: Decodable {
        let kind: String, caller: UInt32, arguments: [UInt32], this: UInt32?, path: String?
    }
    private struct Read: Decodable {
        let kind: String, address: UInt32, size: UInt32, pc: UInt32
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            kind = try c.decode(String.self);address = try c.decode(UInt32.self);size = try c.decode(UInt32.self);pc = try c.decode(UInt32.self)
        }
    }
    private struct Case: Decodable {
        let label: String, controlWord: UInt32, stimulus: Stimulus, calls: [Call], constructors: [Int]
        let undefinedReads: [Read], globalWrites: [GlobalWrite], recordingWrites: [RecordingWrite], savedWrites: [RecordingWrite]
        let world: Record, actors: [String: Record]
    }
    private struct Parent: Decodable { let fixture: String, sha256: String }
    private struct Corpus: Decodable {
        let exeSHA256: String, parents: [String: Parent], worldAddress: UInt32, catalogAddress: UInt32
        let objectAddresses: [UInt32], actorAddresses: [UInt32], controlWord: UInt32, blocks: [UInt32], cases: [Case], blobs: [String: Blob]
        let recordings: [String: String]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Replay-playback reference: \(message)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let utf8 = Array(text.utf8); guard utf8.count%2 == 0 else { throw error("Hex extent") }
        func value(_ c: UInt8) throws -> UInt8 {
            switch c { case 48...57:return c-48;case 97...102:return c-87;default:throw error("Hex digit") }
        }
        return try stride(from: 0,to: utf8.count,by: 2).map { try value(utf8[$0])*16+value(utf8[$0+1]) }
    }
    public static func compare(input: Data, loading: Data, catalog: Data, sounds: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(input))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.objectAddresses.count == 137, Set(c.objectAddresses).count == 137,
              c.actorAddresses.count == 400, Set(c.actorAddresses).count == 400, !c.cases.isEmpty,
              [0x27f,0x37f].contains(c.controlWord), c.cases.allSatisfy({ $0.controlWord == c.controlWord }) else { throw error("Source/parent identity") }
        for (key,data) in [("initial-loading",loading),("initial-loading-catalog",catalog),("initial-loading-sounds",sounds)] {
            guard let parent = c.parents[key], MatchPreparationReference.digest(data) == parent.sha256 else { throw error("Pinned initial loading \(key)") }
        }
        let precision: OriginalArithmeticPrecision = c.controlWord == 0x27f ? .bits53 : .bits64
        var blobs: [String:[UInt8]] = [:], stored: [String:OriginalStateRecord] = [:]
        var bytes = 0, records = 0, calls = 0, constructors = 0, families: [String:Int] = [:]
        let objects = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
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
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String, masks: Bool = true) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            let equal = masks ? actual == expected : actual.bytes == expected.bytes
            if !equal {
                let offset = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || (masks && actual.defined[$0] != expected.defined[$0]) }!
                throw error("\(label)+\(String(offset,radix:16)): \(actual.bytes[offset])/\(actual.defined[offset]) vs \(expected.bytes[offset])/\(expected.defined[offset])")
            }
            bytes += actual.bytes.count; records += 1
        }
        let initial = try InitialLoadingReference.compare(loading: loading,catalog: catalog,sounds: sounds,onLoaded: { loaded in
            var state = try OriginalMatchPreparation(loading: loaded,arithmeticPrecision: precision)
            for item in c.cases {
                families[String(item.label.split(separator: "-").first ?? ""),default: 0] += 1
                guard item.undefinedReads.isEmpty else {
                    throw error(item.label+" original read undefined bytes \(item.undefinedReads.prefix(3).map { "\($0.kind)@\(String($0.address,radix:16))" })")
                }
                for write in item.stimulus.globals {
                    for (i,b) in try hex(write.bytes).enumerated() { try state.globals.write(b,at: Int(write.address)-OriginalMatchPreparation.globalBase+i) }
                }
                guard let packed = c.recordings[item.stimulus.recording],let file = Data(base64Encoded: packed) else { throw error("Recording input") }
                var loaderGlobals = state.globals
                let loaded = try OriginalReplayFileInput.load(file: [UInt8](file),globals: &loaderGlobals)
                guard loaded.status == 1,var raw = loaded.recording else { throw error(item.label+" recording does not load") }
                for edit in item.stimulus.edits {
                    guard edit.count == 2 else { throw error("Edit") }
                    for (i,b) in withUnsafeBytes(of: edit[1].littleEndian,Array.init).enumerated() { raw[Int(edit[0])+i] = b }
                }
                var recording = try OriginalStateRecord(bytes: raw,defined: [Bool](repeating: true,count: raw.count))
                // The backup area 458588..4588a8 lies past the match globals.
                var saved = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x320),defined: [Bool](repeating: false,count: 0x320))
                let before = state,beforeRecording = recording,beforeSaved = saved
                var made: [[UInt32]] = [],seats: [Int] = []
                let catalogAddress = c.catalogAddress
                try OriginalReplayPlayback.prepare(state: &state,recording: &recording,saved: &saved,releaseLayers: { index,_ in
                    made.append([0x40c0e0,UInt32(index)])
                },loadLayers: { index,_ in
                    made.append([0x40c030,UInt32(bitPattern: Int32(index))])
                },playMusic: { scene in
                    let path = Array(scene.globals.bytes[(0x44eed0-OriginalMatchPreparation.globalBase)...].prefix { $0 != 0 })
                    made.append([0x4025b0]+path.map(UInt32.init))
                },observe: { e in if case .reconstruct(let seat) = e { seats.append(seat) } })
                guard seats == item.constructors else { throw error(item.label+" constructors \(seats) vs \(item.constructors)") }
                let expected: [[UInt32]] = try item.calls.map { call in
                    switch call.kind {
                    case "releaseLayers":
                        guard call.this == catalogAddress,call.arguments.count == 1 else { throw error(item.label+" release call") }
                        return [0x40c0e0,call.arguments[0]]
                    case "loadLayers":
                        guard call.this == catalogAddress,call.arguments.count == 1 else { throw error(item.label+" load call") }
                        return [0x40c030,call.arguments[0]]
                    case "playMusic": return [0x4025b0]+(try hex(call.path ?? "")).map(UInt32.init)
                    default: throw error(item.label+" call kind")
                    }
                }
                guard made == expected else { throw error(item.label+" calls \(made.map { $0.prefix(3) }) vs \(expected.map { $0.prefix(3) })") }
                calls += made.count;constructors += seats.count
                var expectedRecording = beforeRecording
                for write in item.recordingWrites {
                    for (i,b) in try hex(write.bytes).enumerated() { try expectedRecording.write(b,at: write.offset+i) }
                }
                try check(recording,expectedRecording,item.label+" recording")
                var globals = before.globals,expectedSaved = beforeSaved
                for write in item.globalWrites {
                    for (i,b) in try hex(write.bytes).enumerated() { try globals.write(b,at: Int(write.address)-OriginalMatchPreparation.globalBase+i) }
                }
                for write in item.savedWrites {
                    for (i,b) in try hex(write.bytes).enumerated() { try expectedSaved.write(b,at: write.offset+i) }
                }
                try check(saved,expectedSaved,item.label+" backup")
                try check(state.globals,globals,item.label+" globals")
                var world = try record(item.world)
                guard try world.integer(at: 0x7d4,as: UInt32.self) == c.catalogAddress else { throw error("World catalog binding") }
                try world.write(UInt32(0),at: 0x7d4)
                for (i,address) in c.actorAddresses.enumerated() {
                    guard try world.integer(at: 0x194+i*4,as: UInt32.self) == address else { throw error("World Actor table") }
                    try world.write(UInt32(i),at: 0x194+i*4)
                }
                try check(state.world,world,item.label+" World")
                for i in 0..<400 {
                    if let changed = item.actors[String(i)] {
                        var value = try record(changed)
                        guard let object = objects[try value.integer(at: 0x368,as: UInt32.self)] else { throw error("Known Actor Object pointer") }
                        try value.write(object,at: 0x368)
                        try check(state.actors[i],value,item.label+" Actor\(i)")
                    } else { try check(state.actors[i],before.actors[i],item.label+" unchanged Actor\(i)") }
                }
            }
        })
        return .init(initial: initial,cases: c.cases.count,records: records,bytes: bytes,calls: calls,
                     constructors: constructors,blocks: c.blocks.count,families: families)
    }
}
