import Foundation
import NTSDCore

/// Compares OriginalObjectInput with real406ba0 calls captured after the
/// verified first loading. Unlisted Actors must be unchanged; globals may
/// change only in the two game-RNG words.
public enum ObjectInputReference {
    public struct Result {
        public let initial: InitialLoadingReference.Result
        public let cases: Int, records: Int, bytes: Int, random: Int, constructors: Int, blocks: Int
        public let hitFa: [Int32: Int]
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct GlobalWrite: Decodable { let address: UInt32, bytes: String }
    private struct WorldWrite: Decodable { let offset: Int, bytes: String }
    private struct ActorWrite: Decodable { let slot: Int, offset: Int, bytes: String }
    private struct Binding: Decodable { let slot: Int, object: UInt32, frame: UInt32 }
    private struct Stimulus: Decodable { let globals: [GlobalWrite], actors: [ActorWrite], world: [WorldWrite], bindings: [Binding] }
    private struct Random: Decodable { let stream: UInt32, range: UInt32, caller: UInt32, before: [UInt32], result: UInt32 }
    private struct Case: Decodable {
        let label: String, slot: Int, controlWord: UInt32, stimulus: Stimulus, random: [Random], constructors: [Int]
        let rng: [UInt32], world: Record, actors: [String: Record]
    }
    private struct Parent: Decodable { let fixture: String, sha256: String }
    private struct Corpus: Decodable {
        let exeSHA256: String, parents: [String: Parent], worldAddress: UInt32, objectAddresses: [UInt32], actorAddresses: [UInt32]
        let controlWord: UInt32, blocks: [UInt32], cases: [Case], blobs: [String: Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Object-input reference: \(message)") }
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
        var bytes = 0, records = 0, random = 0, constructors = 0, hitFa: [Int32:Int] = [:]
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
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if actual != expected {
                let offset = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                throw error("\(label)+\(String(offset,radix:16)): \(actual.bytes[offset])/\(actual.defined[offset]) vs \(expected.bytes[offset])/\(expected.defined[offset])")
            }
            bytes += actual.bytes.count; records += 1
        }
        let initial = try InitialLoadingReference.compare(loading: loading,catalog: catalog,sounds: sounds,onLoaded: { loaded in
            var state = try OriginalMatchPreparation(loading: loaded,arithmeticPrecision: precision)
            for item in c.cases {
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
                for binding in item.stimulus.bindings {
                    guard (0..<400).contains(binding.slot), binding.object < loaded.catalog.objects.count, binding.frame < 400 else { throw error("Source binding stimulus") }
                    try state.actors[binding.slot].write(binding.object,at: 0x368)
                    try state.actors[binding.slot].write(binding.frame,at: 0x70)
                }
                guard (10..<400).contains(item.slot) else { throw error("Called slot") }
                let object = Int(try state.actors[item.slot].integer(at: 0x368,as: UInt32.self))
                let frame = Int(try state.actors[item.slot].integer(at: 0x70,as: UInt32.self))
                let hit = try state.loadedObjects[object].frameStorage[frame].integer(at: 0x30,as: Int32.self)
                hitFa[hit,default: 0] += 1
                let before = state
                var events: [OriginalObjectInputEvent] = []
                try OriginalObjectInput.apply(slot: item.slot,state: &state,observe: { events.append($0) })
                let draws = events.compactMap { e -> [UInt32]? in
                    if case let .random(stream,range,result) = e { return [UInt32(bitPattern: stream),UInt32(bitPattern: range),UInt32(bitPattern: result)] }
                    return nil
                }
                let built = events.compactMap { e -> Int? in if case let .reconstruct(slot) = e { return slot }; return nil }
                guard draws == item.random.map({ [$0.stream,$0.range,$0.result] }), item.random.allSatisfy({ (0x406ba0..<0x408cae).contains($0.caller) }) else {
                    throw error(item.label+" RNG calls \(draws) vs \(item.random.map { [$0.stream,$0.range,$0.result] })")
                }
                guard built == item.constructors else { throw error(item.label+" constructors \(built) vs \(item.constructors)") }
                random += draws.count; constructors += built.count
                guard item.rng.count == 2 else { throw error("RNG words") }
                var globals = before.globals
                try globals.write(item.rng[0],at: 0x450bcc-OriginalMatchPreparation.globalBase)
                try globals.write(item.rng[1],at: 0x450c34-OriginalMatchPreparation.globalBase)
                try check(state.globals,globals,item.label+" globals")
                var world = try record(item.world)
                guard try world.integer(at: 0x7d4,as: UInt32.self) == 0x60000020 else { throw error("World catalog binding") }
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
        return .init(initial: initial,cases: c.cases.count,records: records,bytes: bytes,random: random,constructors: constructors,
                     blocks: c.blocks.count,hitFa: hitFa)
    }
}
