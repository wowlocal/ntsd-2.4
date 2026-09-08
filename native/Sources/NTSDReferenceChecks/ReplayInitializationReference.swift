import Foundation
import NTSDCore

public enum ReplayInitializationReference {
    public struct Result {
        public var preparation = MatchPreparationReference.Result()
        public var buffers = 0, bytes = 0, allocations = 0, releases = 0
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Replay: Decodable { let address: UInt32, storage: Record }
    private struct Write: Decodable { let address: UInt32, bytes: String }
    private struct Event: Decodable {
        let kind: String, address: UInt32?, count: Int?, size: Int?, caller: String
        let mode: UInt32?, activity: UInt32?, actors: UInt32?
    }
    private struct Case: Decodable {
        let label: String, mode: Int32, replayStimulus: [Write], replay: Replay
        let replayBeforePointers: String, replayAfterPointers: String, replayEvents: [Event]
    }
    private struct Cleanup: Decodable { let events: [Event], pointers: String, globals: String }
    private struct Corpus: Decodable {
        let replayPointersAddress: UInt32, replayPointersInitial: String
        let worldAddress: UInt32, actorAddresses: [UInt32], globalAddress: UInt32
        let cases: [Case], cleanup: Cleanup, blobs: [String: Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Replay initialization reference: \(message)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let characters = Array(text.utf8)
        guard characters.count % 2 == 0 else { throw error("Odd hex length") }
        return try stride(from: 0, to: characters.count, by: 2).map { index in
            guard let byte = UInt8(String(decoding: characters[index..<(index+2)], as: UTF8.self), radix: 16) else { throw error("Invalid hex") }
            return byte
        }
    }
    private static func pointers(_ text: String) throws -> [UInt32] {
        let bytes = try hex(text)
        guard bytes.count == 8 else { throw error("Pointer storage") }
        return [0, 4].map { start in (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[start+$1]) << ($1*8) } }
    }

    public static func compare(loaded: Data, corpora: [Data],
                               onFinished: (Int, OriginalLoadedCatalog, inout OriginalMatchPreparation) throws -> Void = { _, _, _ in },
                               beforePreparation: (Int, Int, inout OriginalMatchPreparation) throws -> Void = { _, _, _ in }) throws -> Result {
        let inputs = try corpora.map { try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack($0)) }
        guard inputs.allSatisfy({ $0.replayPointersAddress == 0x4588a8 && $0.globalAddress == OriginalMatchPreparation.globalBase && $0.cases.count == 25 }) else { throw error("Corpus domain") }
        var recorders = [OriginalReplayRecording](repeating: .init(), count: inputs.count)
        var result = Result()
        result.preparation = try MatchPreparationReference.compare(loaded: loaded, corpora: corpora, onFinished: onFinished, beforePreparation: beforePreparation) { corpusIndex, caseIndex, catalog, state in
            let corpus = inputs[corpusIndex], item = corpus.cases[caseIndex]
            func blob(_ key: String) throws -> [UInt8] {
                guard let value = corpus.blobs[key] else { throw error("Missing blob") }
                let bytes = try MatchPreparationReference.inflate(value.deflate, count: value.count)
                guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob digest") }
                return bytes
            }
            guard try pointers(corpus.replayPointersInitial) == [0, 0] else { throw error("Initial recording/playback ownership") }
            let previous = caseIndex == 0 ? UInt32(0) : corpus.cases[caseIndex-1].replay.address
            guard try pointers(item.replayBeforePointers) == [previous, 0],
                  (recorders[corpusIndex].buffer != nil) == (caseIndex > 0),
                  recorders[corpusIndex].generation == caseIndex else { throw error("Recording ownership before begin") }
            for write in item.replayStimulus {
                let bytes = try hex(write.bytes)
                if write.address >= corpus.globalAddress, write.address < corpus.globalAddress+UInt32(OriginalMatchPreparation.globalSize) {
                    for (i, byte) in bytes.enumerated() { try state.globals.write(byte, at: Int(write.address-corpus.globalAddress)+i) }
                } else if write.address >= corpus.worldAddress+4, write.address < corpus.worldAddress+22 {
                    guard bytes.count == 1 else { throw error("Activity stimulus width") }
                    try state.world.write(bytes[0], at: Int(write.address-corpus.worldAddress))
                } else {
                    guard let slot = corpus.actorAddresses.firstIndex(where: { $0 <= write.address && write.address < $0+0x420 }),
                          slot < 18, bytes.count == 4 else { throw error("Actor stimulus storage") }
                    let offset = Int(write.address-corpus.actorAddresses[slot])
                    guard [0x364, 8, 0x10, 0x14, 0x18, 0x308, 0x354, 0x304, 0x33c, 0x344, 0x340].contains(offset) else { throw error("Unrecovered Actor stimulus") }
                    for (i, byte) in bytes.enumerated() { try state.actors[slot].write(byte, at: offset+i) }
                }
            }
            var observed: [OriginalReplayAllocationEvent] = []
            try recorders[corpusIndex].begin(mode: item.mode, world: state.world, actors: state.actors, catalog: catalog,
                                             globals: &state.globals, observe: { observed.append($0) })
            guard let entry = item.replayEvents.first, entry.kind == "entry", entry.caller == "0x42d701",
                  entry.mode == UInt32(bitPattern: item.mode), entry.activity == corpus.worldAddress+4,
                  entry.actors == corpus.worldAddress+0x194 else { throw error("Actual menu caller/arguments") }
            let generation = UInt32(caseIndex+1)
            let expected = try item.replayEvents.dropFirst().map { event -> OriginalReplayAllocationEvent in
                if event.kind == "calloc" {
                    guard event.address == item.replay.address, event.count == 1, event.size == OriginalReplayRecording.byteCount,
                          event.caller == "0x43d2de" else { throw error("calloc boundary") }
                    return .allocate(generation: generation, bytes: OriginalReplayRecording.byteCount)
                }
                guard event.kind == "free", event.address == previous, previous != 0, event.caller == "0x43d292" else { throw error("free boundary") }
                return .release(generation: generation-1)
            }
            guard observed == expected, recorders[corpusIndex].generation == generation,
                  try pointers(item.replayAfterPointers) == [item.replay.address, 0],
                  let actual = recorders[corpusIndex].buffer else { throw error("Recording allocation order/ownership") }
            let mask = try blob(item.replay.storage.defined)
            guard mask.count == OriginalReplayRecording.byteCount, mask.allSatisfy({ $0 == 1 }) else { throw error("calloc provenance") }
            let reference = try OriginalStateRecord(bytes: blob(item.replay.storage.bytes), defined: mask.map { $0 == 1 })
            if actual != reference {
                let offset = actual.bytes.indices.first { actual.bytes[$0] != reference.bytes[$0] || actual.defined[$0] != reference.defined[$0] }!
                throw error("\(item.label)+\(String(offset, radix: 16)): byte/mask mismatch")
            }
            result.buffers += 1; result.bytes += actual.bytes.count; result.allocations += 1
            result.releases += expected.filter { if case .release = $0 { return true }; return false }.count
            if caseIndex == corpus.cases.count-1 {
                var cleared: [OriginalReplayAllocationEvent] = []
                try recorders[corpusIndex].clear { cleared.append($0) }
                try recorders[corpusIndex].clear { cleared.append($0) }
                guard cleared == [.release(generation: generation)], recorders[corpusIndex].buffer == nil,
                      corpus.cleanup.events.count == 1, corpus.cleanup.events[0].kind == "free",
                      corpus.cleanup.events[0].address == item.replay.address, corpus.cleanup.events[0].caller == "0x43d292",
                      try pointers(corpus.cleanup.pointers) == [0, 0],
                      state.globals.bytes == (try blob(corpus.cleanup.globals)) else { throw error("Repeated clear / preserved global state") }
                result.releases += 1
            }
        }
        return result
    }
}
