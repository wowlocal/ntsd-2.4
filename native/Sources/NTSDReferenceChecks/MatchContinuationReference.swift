import Foundation
import NTSDCore

public enum MatchContinuationReference {
    public struct Result {
        public var parent = MatchPreludeReference.Result()
        public var cases = 0, records = 0, bytes = 0, randomCalls = 0, constructors = 0, bitmaps = 0
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let initial: String, bytes: String, defined: String }
    private struct RandomState: Decodable, Equatable { let index: Int, counter: Int }
    private struct Snapshot: Decodable {
        let world: Record, actors: [Record], backgrounds: [Record], globals: String
        let random: RandomState, bitmapCount: Int, released: [UInt32]
    }
    private struct Write: Decodable { let address: Int, bytes: String }
    private struct Call: Decodable, Equatable {
        let kind: String
        var index: Int? = nil, stream: Int32? = nil, range: Int32? = nil, result: Int32? = nil
        var before: RandomState? = nil, after: RandomState? = nil
        var seat: Int? = nil, ordinals: [Int]? = nil, loop: Bool? = nil, resource: UInt32? = nil
        var vtableOffset: Int? = nil, arguments: [UInt32]? = nil
        var x: Int32? = nil, y: Int32? = nil, width: Int32? = nil, height: Int32? = nil, color: UInt32? = nil
    }
    private struct Bitmap: Decodable { let address: UInt32, path: String, optional: UInt32, storage: Record }
    private struct Event: Decodable { let kind: String, address: UInt32? }
    private struct ABI: Decodable { let returnAddress: UInt32, stackAfter: UInt32, savedRegisters: [UInt32], restoredSEH: UInt32 }
    private struct Case: Decodable {
        let label: String, confirmation: Int32, stimulus: [Write], before: Snapshot, after: Snapshot
        let deviceResult: UInt32
        let calls: [Call], bitmaps: [Bitmap], events: [Event], abi: ABI
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, parentFixtureSHA256: String
        let worldAddress: UInt32, catalogAddress: UInt32, objectAddresses: [UInt32], actorAddresses: [UInt32]
        let bitmapAddresses: [UInt32], surfaceAddress: UInt32, initial: Snapshot, cases: [Case]
        let assets: [OriginalBitmapInput], blobs: [String: Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Match continuation reference: \(text)") }
    public static func compare(loaded: Data, parents: [Data], corpora: [Data]) throws -> Result {
        guard parents.count == corpora.count, !parents.isEmpty else { throw error("Missing paired parent") }
        let inputs = try corpora.map { try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack($0)) }
        var result = Result()
        result.parent = try MatchPreludeReference.compare(loaded: loaded, corpora: parents) { index, catalog, state in
            let corpus = inputs[index]
            guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
                  corpus.parentFixtureSHA256 == MatchPreparationReference.digest(parents[index]),
                  corpus.objectAddresses.count == catalog.objects.count, corpus.actorAddresses.count == 400,
                  corpus.bitmapAddresses.count == state.bitmaps.count else { throw error("Source bindings") }
            var cache: [String: [UInt8]] = [:]
            func blob(_ key: String) throws -> [UInt8] {
                if let raw = cache[key] { return raw }
                guard let item = corpus.blobs[key] else { throw error("Missing blob") }
                let raw = try MatchPreparationReference.inflate(item.deflate, count: item.count)
                guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob digest") }
                cache[key] = raw; return raw
            }
            func record(_ item: Record) throws -> OriginalStateRecord {
                let bytes = try blob(item.bytes), mask = try blob(item.defined), initial = try blob(item.initial)
                guard bytes.count == mask.count, bytes.count == initial.count,
                      mask.allSatisfy({ $0 < 2 }), bytes.indices.allSatisfy({ mask[$0] == 1 || bytes[$0] == initial[$0] }) else { throw error("Record provenance") }
                return try .init(bytes: bytes, defined: mask.map { $0 == 1 })
            }
            func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
                guard actual.bytes.count == expected.bytes.count else { throw error("\(label): size") }
                if actual != expected {
                    let offset = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                    throw error("\(label)+\(String(offset, radix: 16)): \(actual.bytes[offset])/\(actual.defined[offset]) vs \(expected.bytes[offset])/\(expected.defined[offset])")
                }
                result.records += 1; result.bytes += actual.bytes.count
            }
            let objects = Dictionary(uniqueKeysWithValues: corpus.objectAddresses.enumerated().map { ($0.element, $0.offset) })
            var bitmaps = Dictionary(uniqueKeysWithValues: corpus.bitmapAddresses.enumerated().map { ($0.element, $0.offset) })
            func snapshot(_ item: Snapshot, _ label: String) throws {
                guard item.actors.count == 400, item.backgrounds.count == 101, item.bitmapCount == state.bitmaps.count,
                      Set(try item.released.map { address -> Int in
                          guard let index = bitmaps[address] else { throw error("Unknown released resource") }; return index
                      }) == state.releasedBitmaps else { throw error("\(label): inventory") }
                var world = try record(item.world)
                guard try world.integer(at: 0x7d4, as: UInt32.self) == corpus.catalogAddress else { throw error("Catalog reference") }
                try world.write(UInt32(0), at: 0x7d4)
                for slot in 0..<400 {
                    guard try world.integer(at: 0x194+slot*4, as: UInt32.self) == corpus.actorAddresses[slot] else { throw error("Actor reference") }
                    try world.write(UInt32(slot), at: 0x194+slot*4)
                    var actor = try record(item.actors[slot])
                    guard let ordinal = objects[try actor.integer(at: 0x368, as: UInt32.self)] else { throw error("Object reference") }
                    try actor.write(UInt32(ordinal), at: 0x368)
                    try check(state.actors[slot], actor, "\(label) Actor \(slot)")
                }
                try check(state.world, world, label+" World")
                for index in 0..<101 {
                    var bg = try record(item.backgrounds[index])
                    for offset in [0x98c]+Array(stride(from: 0x914, through: 0x988, by: 4)) {
                        if !bg.defined[offset..<(offset+4)].allSatisfy({ $0 }) { continue }
                        let pointer = try bg.integer(at: offset, as: UInt32.self)
                        if pointer == 0 { continue }
                        guard let bitmap = bitmaps[pointer] else { throw error("BG resource reference") }
                        try bg.write(UInt32(bitmap+1), at: offset)
                    }
                    try check(state.backgrounds[index], bg, "\(label) BG \(index)")
                }
                let globals = try blob(item.globals)
                try check(state.globals, .init(bytes: globals, defined: [Bool](repeating: true, count: globals.count)), label+" globals")
                guard try state.globals.integer(at: 0x450bcc-OriginalMatchPreparation.globalBase, as: Int32.self) == item.random.index,
                      try state.globals.integer(at: 0x450c34-OriginalMatchPreparation.globalBase, as: Int32.self) == item.random.counter else { throw error("RNG state") }
            }
            try snapshot(corpus.initial, "after pinned parent")
            let assets = Dictionary(uniqueKeysWithValues: corpus.assets.map { ($0.path, $0) })
            for item in corpus.cases {
                guard [0, 0x80004005].contains(item.deviceResult), item.abi.returnAddress == 0x30000000, item.abi.stackAfter == 0x1000fab4,
                      item.abi.savedRegisters == [0x11111111,0x22222222,0x33333333,0x44444444], item.abi.restoredSEH == 0 else { throw error("Actual ret12/SEH/cookie witness") }
                for write in item.stimulus {
                    let hex = Array(write.bytes.utf8)
                    guard hex.count % 2 == 0, write.address >= OriginalMatchPreparation.globalBase,
                          write.address+hex.count/2 <= OriginalMatchPreparation.globalBase+OriginalMatchPreparation.globalSize else { throw error("Unrecovered stimulus") }
                    for i in stride(from: 0, to: hex.count, by: 2) {
                        guard let byte = UInt8(String(decoding: hex[i..<(i+2)], as: UTF8.self), radix: 16) else { throw error("Invalid hex") }
                        try state.globals.write(byte, at: write.address-OriginalMatchPreparation.globalBase+i/2)
                    }
                }
                try snapshot(item.before, item.label+" before")
                var calls: [Call] = [], requested: [String] = []
                try state.continueMenu(confirmation: item.confirmation, bitmapSource: { path in
                    guard let input = assets[path] else { throw error("Missing asset") }; requested.append(path); return input
                }, observe: { event in
                    switch event {
                    case .musicSelection: calls.append(.init(kind: "music-selection"))
                    case .candidates(let seat, let ordinals): calls.append(.init(kind: "candidates", seat: seat, ordinals: ordinals))
                    case .state(let event):
                        switch event {
                        case .reconstruct(let index): calls.append(.init(kind: "reconstruct", index: index))
                        case .random(let stream, let range, let value, let bi, let bc, let i, let c):
                            calls.append(.init(kind: "rng", stream: stream, range: range, result: value, before: .init(index: bi, counter: bc), after: .init(index: i, counter: c)))
                        case .releaseLayers(let index): calls.append(.init(kind: "release-layers", index: index))
                        case .loadLayers(let index): calls.append(.init(kind: "load-layers", index: index))
                        case .resetInput: calls.append(.init(kind: "reset-input"))
                        case .resumeMusic, .musicPath: throw error("Unexpected continuation music path")
                        }
                    case .device(let event):
                        switch event {
                        case .localTime: throw error("Unexpected continuation time query")
                        case .soundRequest(let loop): calls.append(.init(kind: "sound-request", loop: loop))
                        case .soundMethod(let resource, let offset, let args): calls.append(.init(kind: "sound-method", resource: resource, vtableOffset: offset, arguments: args))
                        case .fillRectangle(let resource, let x, let y, let width, let height, let color):
                            calls.append(.init(kind: "fill-rectangle", resource: resource, x: x, y: y, width: width, height: height, color: color))
                        }
                    }
                })
                guard calls == item.calls, requested == item.bitmaps.map(\.path) else { throw error("\(item.label): call/candidate/resource order") }
                for bitmap in item.bitmaps {
                    let index = bitmaps.count
                    guard bitmaps[bitmap.address] == nil, state.bitmaps.indices.contains(index) else { throw error("Allocation identity") }
                    bitmaps[bitmap.address] = index
                    let actual = state.bitmaps[index]
                    var expected = try record(bitmap.storage)
                    guard actual.input.path == bitmap.path, actual.optional == (bitmap.optional != 0), actual.mirroredFrom == nil,
                          try expected.integer(at: 0, as: UInt32.self) == (actual.input.present ? corpus.surfaceAddress : 0) else { throw error("Device allocation") }
                    try expected.write(UInt32(actual.input.present ? 1 : 0), at: 0)
                    try check(actual.storage, expected, item.label+" bitmap")
                }
                let released = try item.events.filter { $0.kind == "free" }.map { event -> Int in
                    guard let address = event.address, let index = bitmaps[address] else { throw error("Release identity") }; return index
                }
                guard released == state.releasedBitmapOrder else { throw error("Release order") }
                try snapshot(item.after, item.label+" after")
                result.cases += 1; result.bitmaps += item.bitmaps.count
                result.randomCalls += calls.filter { $0.kind == "rng" }.count
                result.constructors += calls.filter { $0.kind == "reconstruct" }.count
            }
        }
        return result
    }
}
