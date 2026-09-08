import Foundation
import NTSDCore

public enum ModeSelectionReference {
    public struct Result {
        public var cases = 0, input = 0, selections = 0, playback = 0, helpers = 0, events = 0, records = 0, bytes = 0
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, storage: Storage, live: Bool? }
    private struct Helper: Decodable {
        let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32, result: UInt32
    }
    private struct Case: Decodable {
        let label: String, kind: String, stimulus: [InputControlReference.GlobalWrite], revive: [UInt32]
        let events: [OriginalModeSelectionEvent], helpers: [Helper], continuation: String, endPC: UInt32, endSP: UInt32, after: [Record]
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, worldAddress: UInt32, actorAddresses: [UInt32], globalAddress: UInt32, replayAddress: UInt32
        let initial: [Record], cases: [Case], blobs: [String:Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Mode selection reference: "+message) }
    public static func compare(_ data: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(data,maximumCount: 40_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.globalAddress == OriginalMatchPreparation.globalBase, c.worldAddress == 0x22000020,
              c.replayAddress == 0x4588a8, c.actorAddresses.count == 9,
              Set(c.actorAddresses).count == c.actorAddresses.count, !c.cases.isEmpty else { throw error("Identity/inventory") }
        var result = Result(), blobs: [String:[UInt8]] = [:], cache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value }
            guard let b = c.blobs[key], b.sha256 == key else { throw error("Blob identity") }
            let value = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 100_000)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw error("Blob hash") }
            blobs[key] = value; return value
        }
        func storage(_ s: Storage) throws -> OriginalStateRecord {
            let key = s.bytes+s.defined
            if let value = cache[key] { return value }
            let bytes = try blob(s.bytes), mask = try blob(s.defined)
            guard bytes.count == mask.count, mask.allSatisfy({ $0 < 2 }) else { throw error("Mask extent") }
            let value = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 }); cache[key] = value; return value
        }
        func normalizeWorld(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            guard raw.bytes.count == OriginalStateRecord.worldPrefixSize else { throw error("World extent") }
            var bytes = raw.bytes
            for seat in 0..<8 {
                let offset = 0x194+seat*4, pointer = try raw.integer(at: offset,as: UInt32.self)
                guard let index = c.actorAddresses.firstIndex(of: pointer) else { throw error("Actor binding") }
                for i in 0..<4 { bytes[offset+i] = UInt8(truncatingIfNeeded: UInt32(index) >> (i*8)) }
            }
            return try OriginalStateRecord(bytes: bytes,defined: raw.defined)
        }
        var regions: [UInt32:OriginalStateRecord] = [:], live: [UInt32:Bool] = [:]
        for r in c.initial {
            guard regions[r.address] == nil else { throw error("Duplicate initial region") }
            regions[r.address] = try storage(r.storage)
            if let alive = r.live { live[r.address] = alive }
        }
        func required(_ p: UInt32) throws -> OriginalStateRecord {
            guard let value = regions[p] else { throw error("Missing region") }; return value
        }
        var rawWorld = try required(c.worldAddress), state = try required(c.globalAddress)
        var actors = try c.actorAddresses.map(required)
        var memory = OriginalMenuPresentationMemory(replayPointers: try required(c.replayAddress))
        for (p,alive) in live { memory.allocations[p] = .init(storage: try required(p),live: alive) }
        guard state.bytes.count == OriginalMatchPreparation.globalSize, memory.replayPointers.bytes.count == 8,
              actors.allSatisfy({ $0.bytes.count == OriginalStateRecord.actorSize }), regions.count == 15, memory.allocations.count == 3 else { throw error("Storage inventory") }
        let helperReturns: [UInt32:Set<UInt32>] = [0x431b70:[0x30000000,0x4322b6],0x401a30:[0x432349],
            0x423910:[0x43238d,0x4323c7,0x4323f7,0x432427,0x432461,0x43248f],0x43ef50:[0x42391f],0x4019b0:[0x4328e9]]
        for item in c.cases {
            for w in item.stimulus {
                let chars = Array(w.bytes)
                guard chars.count%2 == 0 else { throw error("Stimulus extent") }
                let count = chars.count/2
                guard let address = regions.keys.first(where: { $0 <= w.address && UInt64(w.address)+UInt64(count) <= UInt64($0)+UInt64(regions[$0]!.bytes.count) }) else { throw error("Stimulus ownership") }
                var record: OriginalStateRecord
                if address == c.globalAddress { record = state }
                else if address == c.worldAddress { record = rawWorld }
                else if address == c.replayAddress { record = memory.replayPointers }
                else if let index = c.actorAddresses.firstIndex(of: address) { record = actors[index] }
                else if let value = memory.allocations[address] { record = value.storage }
                else { throw error("Unbound stimulus") }
                for i in 0..<count {
                    guard let byte = UInt8(String(chars[2*i...2*i+1]),radix: 16) else { throw error("Stimulus hex") }
                    try record.write(byte,at: Int(w.address-address)+i)
                }
                if address == c.globalAddress { state = record }
                else if address == c.worldAddress { rawWorld = record }
                else if address == c.replayAddress { memory.replayPointers = record }
                else if let index = c.actorAddresses.firstIndex(of: address) { actors[index] = record }
                else { memory.allocations[address]!.storage = record }
            }
            for address in item.revive {
                guard memory.allocations[address] != nil else { throw error("Revive ownership") }
                memory.allocations[address]!.live = true
            }
            let world = try normalizeWorld(rawWorld)
            var events: [OriginalModeSelectionEvent] = []
            let continuation: String
            if item.kind == "input" {
                try OriginalMenuInput.advance(world: world,actors: actors,globals: &state)
                continuation = "returned"; result.input += 1
            } else {
                guard item.kind == "selection" else { throw error("Entry kind") }
                continuation = try OriginalModeSelection.advance(world: world,actors: actors,globals: &state,memory: &memory) { events.append($0) }.rawValue
                result.selections += 1
            }
            guard events == item.events else {
                throw error(item.label+" events: \(events); expected \(item.events)")
            }
            guard continuation == item.continuation, item.endSP == 0x1000d000,
                  item.endPC == ["returned":UInt32(0x30000000),"panel":0x4328f8,"playback":0x43249c][continuation] else { throw error(item.label+" continuation") }
            if continuation == "playback" { result.playback += 1 }
            for h in item.helpers {
                guard h.pop == (h.entry == 0x401a30 ? 4 : 0), h.returnSP == h.entrySP+4+h.pop,
                      h.saved.count == 4, helperReturns[h.entry]?.contains(h.returnPC) == true else { throw error(item.label+" child ABI") }
                if h.entry == 0x431b70 { guard h.result == 0x451340 else { throw error("Input return EAX") } }
            }
            guard item.after.count == regions.count, Set(item.after.map(\.address)) == Set(regions.keys) else { throw error("Final inventory") }
            for r in item.after {
                var expected = try storage(r.storage)
                let actual: OriginalStateRecord
                if r.address == c.globalAddress { actual = state }
                else if r.address == c.worldAddress { actual = world; expected = try normalizeWorld(expected) }
                else if r.address == c.replayAddress { actual = memory.replayPointers }
                else if let index = c.actorAddresses.firstIndex(of: r.address) { actual = actors[index] }
                else if let allocation = memory.allocations[r.address] {
                    guard allocation.live == r.live else { throw error(item.label+" liveness") }; actual = allocation.storage
                } else { throw error("Final ownership") }
                guard actual == expected else {
                    let i = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                    throw error(item.label+" region"+String(r.address,radix:16)+" offset"+(i.map { String($0,radix:16) } ?? "extent"))
                }
                result.records += 1; result.bytes += actual.bytes.count
            }
            result.cases += 1; result.events += events.count; result.helpers += item.helpers.count
        }
        return result
    }
}
