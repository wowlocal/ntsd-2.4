import Foundation
import Compression
import CryptoKit
import NTSDCore

/// Rebuilds and verifies the full native catalog once, then continues through
/// bootstrap and chained match preparations. Expected post-state never supplies
/// native gameplay inputs; only recorded allocator/menu/global stimuli do.
public enum MatchPreparationReference {
    public struct Result {
        public var cases = 0, records = 0, bytes = 0, constructors = 0, randomCalls = 0, bitmaps = 0, releases = 0
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Packed: Decodable { let count: Int, deflate: String, sha256: String }
    private struct Record: Decodable { let initial: String, bytes: String, defined: String }
    private struct RandomState: Decodable, Equatable { let index: Int, counter: Int }
    private struct Snapshot: Decodable {
        let world: Record, actors: [Record], backgrounds: [Record], globals: String
        let random: RandomState, bitmapCount: Int, released: [UInt32]
    }
    private struct Write: Decodable { let address: UInt32, bytes: String }
    private struct Call: Decodable, Equatable {
        let kind: String
        var index: Int? = nil, stream: Int32? = nil, range: Int32? = nil, result: Int32? = nil
        var before: RandomState? = nil, after: RandomState? = nil
    }
    private struct Bitmap: Decodable { let address: UInt32, path: String, optional: UInt32, storage: Record }
    private struct Event: Decodable { let kind: String, address: UInt32? }
    private struct Case: Decodable {
        let label: String, mode: Int32, stimulus: [Write], before: Snapshot, after: Snapshot
        let constructors: [Int], calls: [Call], bitmaps: [Bitmap], events: [Event]
        let continued: Snapshot?
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, loadedFixtureSHA256: String, loadedCatalogSHA256: String
        let catalogAddress: UInt32, worldAddress: UInt32, actorAddresses: [UInt32], objectAddresses: [UInt32]
        let bitmapAddresses: [UInt32], surfaceAddress: UInt32, globalAddress: UInt32, globalInitial: String
        let pattern: String, selector: Int32, staged: Snapshot, cases: [Case], assets: [OriginalBitmapInput]
        let blobs: [String: Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Match preparation reference: \(message)") }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func inflate(_ text: String, count: Int) throws -> [UInt8] {
        guard (0...20_000_000).contains(count), let source = Data(base64Encoded: text) else { throw error("Invalid compressed block") }
        var bytes = [UInt8](repeating: 0, count: count+1)
        let actual = bytes.withUnsafeMutableBufferPointer { output in
            source.withUnsafeBytes { input in
                compression_decode_buffer(output.baseAddress!, output.count, input.bindMemory(to: UInt8.self).baseAddress!, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard actual == count else { throw error("Compressed length mismatch") }
        bytes.removeLast(); return bytes
    }

    static func unpack(_ input: Data) throws -> Data {
        guard let packed = try? JSONDecoder().decode(Packed.self, from: input) else { return input }
        let data = Data(try inflate(packed.deflate, count: packed.count))
        guard digest(data) == packed.sha256 else { throw error("Envelope digest") }
        return data
    }

    public static func compare(loaded: Data, corpora: [Data],
                               afterPreparation: (Int, Int, OriginalLoadedCatalog, inout OriginalMatchPreparation) throws -> Void = { _, _, _, _ in }) throws -> Result {
        guard !corpora.isEmpty else { throw error("Missing preparation corpus") }
        var result = Result()
        _ = try LoadedCatalogReference.compare(loaded) { catalog in
            for (index, data) in corpora.enumerated() {
                try compare(data, loadedSHA256: digest(loaded), catalog: catalog, result: &result) { caseIndex, state in
                    try afterPreparation(index, caseIndex, catalog, &state)
                }
            }
        }
        return result
    }

    private static func compare(_ input: Data, loadedSHA256: String, catalog: OriginalLoadedCatalog, result: inout Result,
                                 afterPreparation: (Int, inout OriginalMatchPreparation) throws -> Void) throws {
        let data = try unpack(input)
        let corpus = try JSONDecoder().decode(Corpus.self, from: data)
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              corpus.loadedFixtureSHA256 == loadedSHA256,
              corpus.globalAddress == OriginalMatchPreparation.globalBase,
              corpus.actorAddresses.count == 400, Set(corpus.actorAddresses).count == 400,
              corpus.objectAddresses.count == catalog.objects.count, Set(corpus.objectAddresses).count == catalog.objects.count,
              corpus.bitmapAddresses.count == catalog.bitmaps.count, corpus.staged.actors.count == 400 else { throw error("Unknown/broken source bindings") }
        var cache: [String: [UInt8]] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            guard let item = corpus.blobs[key] else { throw error("Missing blob") }
            let raw = try inflate(item.deflate, count: item.count)
            guard digest(Data(raw)) == key else { throw error("Blob digest") }
            cache[key] = raw; return raw
        }
        func record(_ item: Record) throws -> OriginalStateRecord {
            let mask = try blob(item.defined)
            guard mask.allSatisfy({ $0 < 2 }) else { throw error("Invalid mask") }
            return try .init(bytes: blob(item.bytes), defined: mask.map { $0 == 1 })
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error("\(label): size") }
            if let offset = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw error("\(label)+\(String(offset, radix: 16)): \(actual.bytes[offset])/\(actual.defined[offset]) vs \(expected.bytes[offset])/\(expected.defined[offset])")
            }
            result.records += 1; result.bytes += actual.bytes.count
        }
        let objectMap = Dictionary(uniqueKeysWithValues: corpus.objectAddresses.enumerated().map { ($0.element, $0.offset) })
        let actorMap = Dictionary(uniqueKeysWithValues: corpus.actorAddresses.enumerated().map { ($0.element, $0.offset) })
        var bitmapMap = Dictionary(uniqueKeysWithValues: corpus.bitmapAddresses.enumerated().map { ($0.element, $0.offset) })
        func actor(_ item: Record) throws -> OriginalStateRecord {
            var value = try record(item)
            guard let ordinal = objectMap[try value.integer(at: 0x368, as: UInt32.self)] else { throw error("Unknown Object pointer") }
            try value.write(UInt32(ordinal), at: 0x368)
            return value
        }
        func background(_ item: Record) throws -> OriginalStateRecord {
            var value = try record(item)
            for offset in [0x98c] + Array(stride(from: 0x914, through: 0x988, by: 4)) {
                if !value.defined[offset..<(offset+4)].allSatisfy({ $0 }) { continue }
                let pointer = try value.integer(at: offset, as: UInt32.self)
                if pointer == 0 { continue }
                guard let index = bitmapMap[pointer] else { throw error("Unknown BG bitmap pointer") }
                try value.write(UInt32(index+1), at: offset)
            }
            return value
        }
        var bootstrap = try OriginalWorldBootstrap(worldBacking: blob(corpus.staged.world.initial),
                                                   actorBacking: corpus.staged.actors.map { try blob($0.initial) }, selector: corpus.selector)
        try bootstrap.activateStagingActors(firstObjectWord90: catalog.objects[0].header.integer(at: 0x90, as: Int32.self))
        let globals = try blob(corpus.globalInitial)
        var state = try OriginalMatchPreparation(catalog: catalog, bootstrap: bootstrap,
                                                globals: .init(bytes: globals, defined: [Bool](repeating: true, count: globals.count)))
        func snapshot(_ item: Snapshot, _ label: String) throws {
            guard item.actors.count == 400, item.backgrounds.count == 101, item.bitmapCount == state.bitmaps.count,
                  Set(try item.released.map { address -> Int in
                      guard let i = bitmapMap[address] else { throw error("Unknown released bitmap") }; return i
                  }) == state.releasedBitmaps else { throw error("\(label): pool/resource inventory") }
            var world = try record(item.world)
            guard try world.integer(at: 0x7d4, as: UInt32.self) == corpus.catalogAddress else { throw error("Catalog pointer") }
            try world.write(UInt32(0), at: 0x7d4)
            for (slot, address) in corpus.actorAddresses.enumerated() {
                guard try world.integer(at: 0x194+slot*4, as: UInt32.self) == address else { throw error("World Actor pointer") }
                try world.write(UInt32(slot), at: 0x194+slot*4)
                try check(state.actors[slot], actor(item.actors[slot]), "\(label) Actor \(slot)")
            }
            try check(state.world, world, "\(label) World")
            for i in 0..<101 { try check(state.backgrounds[i], background(item.backgrounds[i]), "\(label) BG \(i)") }
            let bytes = try blob(item.globals)
            try check(state.globals, .init(bytes: bytes, defined: [Bool](repeating: true, count: bytes.count)), "\(label) globals")
            guard try state.globals.integer(at: 0x450bcc-OriginalMatchPreparation.globalBase, as: Int32.self) == item.random.index,
                  try state.globals.integer(at: 0x450c34-OriginalMatchPreparation.globalBase, as: Int32.self) == item.random.counter else { throw error("RNG snapshot") }
        }
        try snapshot(corpus.staged, "bootstrap")
        let assets = Dictionary(uniqueKeysWithValues: corpus.assets.map { ($0.path, $0) })
        for (caseIndex, item) in corpus.cases.enumerated() {
            for write in item.stimulus {
                let characters = Array(write.bytes.utf8)
                guard characters.count % 2 == 0 else { throw error("Stimulus hex") }
                var bytes: [UInt8] = []
                for i in stride(from: 0, to: characters.count, by: 2) {
                    guard let b = UInt8(String(decoding: characters[i..<(i+2)], as: UTF8.self), radix: 16) else { throw error("Stimulus hex") }
                    bytes.append(b)
                }
                if write.address >= corpus.worldAddress, write.address < corpus.worldAddress+UInt32(OriginalStateRecord.worldPrefixSize) {
                    let offset = Int(write.address-corpus.worldAddress)
                    guard offset >= 4, offset+bytes.count <= 404 else { throw error("Unrecovered World stimulus") }
                    for (i, byte) in bytes.enumerated() { try state.world.write(byte, at: offset+i) }
                } else if write.address >= corpus.globalAddress, write.address < corpus.globalAddress+UInt32(OriginalMatchPreparation.globalSize) {
                    for (i, byte) in bytes.enumerated() { try state.globals.write(byte, at: Int(write.address-corpus.globalAddress)+i) }
                } else {
                    guard let (address, slot) = actorMap.first(where: { $0.key <= write.address && write.address < $0.key+UInt32(OriginalStateRecord.actorSize) }) else { throw error("Unknown stimulus allocation") }
                    let offset = Int(write.address-address)
                    if offset == 0x368 {
                        guard bytes.count == 4 else { throw error("Partial Object binding stimulus") }
                        let pointer = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
                        guard let ordinal = objectMap[pointer] else { throw error("Stimulus Object pointer") }
                        try state.actors[slot].write(UInt32(ordinal), at: offset)
                    } else {
                        guard offset == 0x364 && bytes.count == 4 || offset == 0xcd && bytes.count == 7 else { throw error("Unrecovered Actor stimulus") }
                        for (i, byte) in bytes.enumerated() { try state.actors[slot].write(byte, at: offset+i) }
                    }
                }
            }
            try snapshot(item.before, item.label+" before")
            var calls: [Call] = [], constructors: [Int] = [], requests: [String] = []
            try state.prepare(mode: item.mode, bitmapSource: { path in
                guard let input = assets[path] else { throw error("Missing layer asset \(path)") }
                requests.append(path); return input
            }, observe: { event in
                switch event {
                case .reconstruct(let slot): constructors.append(slot)
                case .random(let stream, let range, let value, let bi, let bc, let i, let c):
                    calls.append(.init(kind: "rng", stream: stream, range: range, result: value,
                                       before: .init(index: bi, counter: bc), after: .init(index: i, counter: c)))
                case .releaseLayers(let index): calls.append(.init(kind: "release-layers", index: index))
                case .loadLayers(let index): calls.append(.init(kind: "load-layers", index: index))
                case .resetInput: calls.append(.init(kind: "reset-input"))
                case .resumeMusic: calls.append(.init(kind: "resume-music"))
                case .musicPath: calls.append(.init(kind: "music-path"))
                }
            })
            guard calls == item.calls, constructors == item.constructors, requests == item.bitmaps.map(\.path) else { throw error("\(item.label): call/constructor/layer request order") }
            for bitmap in item.bitmaps {
                let index = bitmapMap.count
                guard bitmapMap[bitmap.address] == nil, state.bitmaps.indices.contains(index) else { throw error("Bitmap allocation identity") }
                bitmapMap[bitmap.address] = index
                let actual = state.bitmaps[index]
                var expected = try record(bitmap.storage)
                guard actual.input.path == bitmap.path, actual.optional == (bitmap.optional != 0), actual.mirroredFrom == nil,
                      try expected.integer(at: 0, as: UInt32.self) == (actual.input.present ? corpus.surfaceAddress : 0) else { throw error("Bitmap device boundary") }
                try expected.write(UInt32(actual.input.present ? 1 : 0), at: 0)
                try check(actual.storage, expected, "\(item.label) bitmap \(index)")
            }
            let released = try item.events.filter { $0.kind == "free" }.map { event -> Int in
                guard let address = event.address, let index = bitmapMap[address] else { throw error("Release event identity") }; return index
            }
            guard released == state.releasedBitmapOrder else { throw error("Layer release order") }
            try snapshot(item.after, item.label+" after")
            try afterPreparation(caseIndex, &state)
            if let continued = item.continued { try snapshot(continued, item.label+" continued") }
            result.cases += 1; result.constructors += constructors.count; result.bitmaps += item.bitmaps.count
            result.releases += released.count; result.randomCalls += calls.filter { $0.kind == "rng" }.count
        }
    }
}
