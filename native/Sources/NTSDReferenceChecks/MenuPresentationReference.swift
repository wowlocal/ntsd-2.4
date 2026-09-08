import Foundation
import NTSDCore

/// Extends the existing menu comparison at explicit stage hooks. Native World=2
/// is produced by the dispatcher branch, then feeds match/replay comparisons.
public enum MenuPresentationReference {
    public struct Result {
        public var menu = MainMenuReference.Result()
        public var steps = 0, bytes = 0, events = 0, formats = 0, transitions = 0, frees = 0, quits = 0
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String, initial: String }
    private struct Allocation: Decodable { let address: UInt32, storage: Record }
    private struct Memory: Decodable { let address: UInt32, live: Bool, storage: Record }
    private struct Snapshot: Decodable {
        let globals: String, world: Record, pointers: String, memory: [Memory], crtState: UInt32
    }
    private struct Write: Decodable { let address: UInt32, bytes: String }
    private struct Format: Decodable { let format: String, result: Int, bytes: String }
    private struct ABI: Decodable { let stackAfter: UInt32, savedRegisters: [UInt32], restoredSEH: UInt32 }
    private struct Step: Decodable {
        let label: String, entry: OriginalMenuPresentationEntry, input: OriginalMenuPresentationInput
        let stimulus: [Write], allocations: [Allocation], before: Snapshot, after: Snapshot
        let events: [OriginalMenuPresentationEvent], formats: [Format], abi: ABI
    }
    private struct Probe: Decodable { let presentation: [Step] }
    private struct Replay: Decodable { let address: UInt32 }
    private struct Case: Decodable { let presentationControls: [Step], mainMenu: [Probe], replay: Replay }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, worldAddress: UInt32, actorAddresses: [UInt32], catalogAddress: UInt32
        let cases: [Case], blobs: [String: Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu presentation reference: \(text)") }
    private static func hex(_ string: String) throws -> [UInt8] {
        let raw = Array(string.utf8)
        guard raw.count % 2 == 0 else { throw error("Hex width") }
        return try stride(from: 0, to: raw.count, by: 2).map { i in
            guard let value = UInt8(String(decoding: raw[i..<(i+2)], as: UTF8.self), radix: 16) else { throw error("Invalid hex") }
            return value
        }
    }
    public static func compare(loaded: Data, corpora: [Data]) throws -> Result {
        let inputs = try corpora.map { try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack($0)) }
        let empty = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 8), defined: [Bool](repeating: true, count: 8))
        var memories = [OriginalMenuPresentationMemory](repeating: .init(replayPointers: empty), count: corpora.count)
        var result = Result()
        // Cache one case at a time: full snapshots retain all globals/masks,
        // while keeping the development comparison's memory bounded.
        var cache: [String: [UInt8]] = [:]
        func run(_ steps: [Step], _ corpusIndex: Int, _ state: inout OriginalMatchPreparation, _ crt: OriginalCRTRandom) throws {
            let corpus = inputs[corpusIndex]
            guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
                  corpus.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d" else { throw error("Reference identity") }
            func blob(_ key: String) throws -> [UInt8] {
                if let raw = cache[key] { return raw }
                guard let item = corpus.blobs[key] else { throw error("Missing blob") }
                let raw = try MatchPreparationReference.inflate(item.deflate, count: item.count)
                guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob digest") }
                cache[key] = raw; return raw
            }
            func record(_ expected: Record) throws -> OriginalStateRecord {
                let raw = try blob(expected.bytes), mask = try blob(expected.defined), initial = try blob(expected.initial)
                guard raw.count == mask.count, initial.count == raw.count,
                      mask.allSatisfy({ $0 < 2 }), raw.indices.allSatisfy({ mask[$0] == 1 || raw[$0] == initial[$0] }) else { throw error("Record provenance") }
                return try .init(bytes: raw, defined: mask.map { $0 == 1 })
            }
            func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
                guard actual.bytes.count == expected.bytes.count else { throw error(label+" size") }
                if actual != expected {
                    let i = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                    throw error("\(label)+\(String(i, radix: 16)): \(actual.bytes[i]) vs \(expected.bytes[i])")
                }
                result.bytes += actual.bytes.count
            }
            func snapshot(_ s: Snapshot, _ label: String) throws {
                let bytes = try blob(s.globals)
                try check(state.globals, .init(bytes: bytes, defined: [Bool](repeating: true, count: bytes.count)), label+" globals")
                var world = try record(s.world)
                guard corpus.actorAddresses.count == 400, try world.integer(at: 0x7d4, as: UInt32.self) == corpus.catalogAddress else { throw error("World binding") }
                try world.write(UInt32(0), at: 0x7d4)
                for (index, address) in corpus.actorAddresses.enumerated() {
                    guard try world.integer(at: 0x194+index*4, as: UInt32.self) == address else { throw error("Actor binding") }
                    try world.write(UInt32(index), at: 0x194+index*4)
                }
                try check(state.world, world, label+" World")
                let pointers = try hex(s.pointers)
                try check(memories[corpusIndex].replayPointers, .init(bytes: pointers, defined: [Bool](repeating: true, count: 8)), label+" replay pointers")
                guard s.memory.count == memories[corpusIndex].allocations.count, crt.state == s.crtState else { throw error("Ownership/CRT state") }
                for allocation in s.memory {
                    guard let native = memories[corpusIndex].allocations[allocation.address], native.live == allocation.live else { throw error("Live/dead ownership") }
                    try check(native.storage, record(allocation.storage), label+" allocation")
                }
            }
            for step in steps {
                // Only declared platform/control input ranges, never a whole
                // expected post-state, are admitted to the native state.
                let words: Set<UInt32> = [0x44d000,0x44f190,0x450b70,0x450b6c,0x450bfc,0x4546f0,0x453cdc,
                    0x44d060,0x457580,0x458348,0x455608,0x455634,0x453e0c,0x451170,0x45118c,0x4511ac,
                    0x44eecc,0x44f040,0x44f044,0x44f048,0x44f04c,0x458438,0x45843c,0x4546f4]
                for write in step.stimulus {
                    let raw = try hex(write.bytes), address = write.address
                    if address == corpus.worldAddress {
                        guard raw == [1,0,0,0], step.entry == .worldOne else { throw error("World stimulus") }
                        try state.world.write(Int32(1), at: 0)
                    } else if address == 0x4588a8 {
                        guard raw.count == 8 else { throw error("Replay pointer stimulus") }
                        for (i, byte) in raw.enumerated() { try memories[corpusIndex].replayPointers.write(byte, at: i) }
                    } else {
                        let scalar = words.contains(address) || (address >= 0x45560c && address < 0x455620 && address%4 == 0)
                            || (address >= 0x452948 && address < 0x452948+400*4 && address%4 == 0)
                            || (address >= 0x451db0 && address < 0x451dbc && address%4 == 0)
                        guard (scalar && raw.count == 4) || (address == 0x4553f2 && raw.count == 2)
                                || (address == 0x453ccc && raw.count == 16)
                                || (address == 0x44fd98 && raw.count <= 256 && raw.last == 0) else { throw error("Undeclared stimulus") }
                        for (i, byte) in raw.enumerated() { try state.globals.write(byte, at: Int(address)-OriginalMatchPreparation.globalBase+i) }
                    }
                }
                for allocation in step.allocations {
                    let storage = try record(allocation.storage)
                    guard memories[corpusIndex].allocations[allocation.address] == nil,
                          [64,128,0x1f50].contains(storage.bytes.count),
                          storage.defined.enumerated().allSatisfy({ $0.element == (storage.bytes.count == 0x1f50 && $0.offset < 4) }) else { throw error("Supplied allocation extent/mask") }
                    memories[corpusIndex].allocations[allocation.address] = .init(storage: storage)
                }
                try snapshot(step.before, step.label+" before")
                var events: [OriginalMenuPresentationEvent] = []
                try OriginalMenuPresentation.apply(step.entry, input: step.input, world: &state.world, globals: &state.globals,
                                                   memory: &memories[corpusIndex]) { events.append($0) }
                guard events == step.events else {
                    let i = zip(events, step.events).enumerated().first { $0.element.0 != $0.element.1 }?.offset
                    throw error("\(step.label) events at \(i.map(String.init) ?? "count"), \(events.count) vs \(step.events.count); actual \(i.map { String(describing: events[$0]) } ?? "")")
                }
                let formats = events.filter { $0.kind == .format }
                guard formats.count == step.formats.count else { throw error("CRT format count") }
                for (event, format) in zip(formats, step.formats) {
                    guard event.strings.count == 2, event.strings[0] == Array(format.format.utf8),
                          event.arguments == [UInt32(format.result)], format.result == event.strings[1].count,
                          try hex(format.bytes) == event.strings[1]+[0] else { throw error("Actual CRT format witness") }
                }
                guard step.abi.stackAfter == 0x1000f42c, step.abi.restoredSEH == 0x12345678,
                      step.abi.savedRegisters == [0x11111111,0x22222222,0x33333333,0x44444444] else { throw error("Real prologue/ret4/SEH witness") }
                try snapshot(step.after, step.label+" after")
                result.steps += 1; result.events += events.count; result.formats += formats.count
                if step.entry == .worldOne { result.transitions += 1 }
                result.frees += events.filter { $0.kind == .free }.count
                result.quits += events.filter { $0.kind == .postMessage }.count
            }
        }
        result.menu = try MainMenuReference.compare(loaded: loaded, corpora: corpora, beforeMenus: { ci, index, state, crt in
            cache.removeAll(keepingCapacity: true)
            if index > 0 {
                // Bind the preceding recording's already verified allocator
                // identity. No new buffer/state is created from an expectation.
                // These later menu paths don't free it; parent begin owns that.
                try memories[ci].replayPointers.write(inputs[ci].cases[index-1].replay.address, at: 0)
            }
            try run(inputs[ci].cases[index].presentationControls, ci, &state, crt)
        }, afterProbe: { ci, index, probe, state, crt in
            try run(inputs[ci].cases[index].mainMenu[probe].presentation, ci, &state, crt)
        })
        return result
    }
}
