import Foundation
import CryptoKit
import Compression
import NTSDCore

/// A compact projection of full original Object captures. It compares all header,
/// tail and bitmap bytes/masks, frame projections after each occurrence and at EOF,
/// and the shared sound cache/checksum. The raw suite additionally compares every
/// Frame byte/mask and all live/dead Frame allocations with supplied addresses.
public enum ObjectReference {
    public struct Result { public let objects: Int, occurrences: Int, finalFrames: Int, bytes: Int, bitmaps: Int, rawFrames: Int, allocations: Int }
    private struct Corpus: Decodable {
        let exeSHA256: String, bitmapFill: UInt8, surfaceAddress: UInt32
        let crtSHA256: String?
        let translation: OriginalFileTranslation
        let cases: [Case], assetInputs: [OriginalBitmapInput]
    }
    private struct Record: Decodable { let initial: String, bytes: String, defined: String }
    private struct Bitmap: Decodable { let address: UInt32, path: String, optional: UInt32, storage: Record }
    private struct RawFrame: Decodable { let number: Int, bytes: String, defined: String }
    private struct Allocation: Decodable { let address: UInt32, kind: OriginalFrameAllocationKind, storage: Record }
    private struct Event: Decodable {
        let kind: String
        let bitmap: Int?, normalAddress: UInt32?
        let destination: [Int32]?, source: [Int32]?, effects: String?
    }
    private struct Case: Decodable {
        let path: String, id: Int32, type: Int32, decoded: String
        let source: String, sourceSHA256: String
        let initialChecksum: UInt32, checksum: UInt32
        let header: Record, tail: Record, bitmaps: [Bitmap], events: [Event]
        let frames: [OriginalFrameRecord], frameOccurrences: [OriginalFrameRecord]
        let frameStorage: Record?, frameStorageOccurrences: [RawFrame]?, frameAllocations: [Allocation]?
        let weaponSoundPaths: [Int: String], soundCount: Int, soundBytes: String
    }
    private static func hex(_ text: String) throws -> [UInt8] {
        let chars = Array(text.utf8)
        guard chars.count % 2 == 0 else { throw OriginalStateError.invalidStorage("Odd object hex length") }
        func nibble(_ byte: UInt8) throws -> UInt8 {
            switch byte {
            case 48...57: return byte - 48
            case 65...70: return byte - 55
            case 97...102: return byte - 87
            default: throw OriginalStateError.invalidStorage("Invalid object hex")
            }
        }
        return try stride(from: 0, to: chars.count, by: 2).map { try nibble(chars[$0])*16 + nibble(chars[$0+1]) }
    }
    private static func record(_ item: Record) throws -> OriginalStateRecord {
        let mask = try hex(item.defined)
        guard mask.allSatisfy({ $0 <= 1 }) else { throw OriginalStateError.invalidStorage("Invalid object initialization mask") }
        return try OriginalStateRecord(bytes: hex(item.bytes), defined: mask.map { $0 == 1 })
    }
    public static func compare(_ data: Data) throws -> Result {
        try compare(JSONDecoder().decode(Corpus.self, from: data))
    }
    public static func compareSuite(_ data: Data) throws -> Result {
        struct Packed: Decodable { let deflate: String?, count: Int?, sha256: String? }
        let packed = try JSONDecoder().decode(Packed.self, from: data)
        var decoded = data
        if let encoded = packed.deflate {
            guard let count = packed.count, (1...600_000_000).contains(count), let source = Data(base64Encoded: encoded) else {
                throw OriginalStateError.invalidStorage("Invalid compressed Object fixture")
            }
            var output = [UInt8](repeating: 0, count: count+1)
            let result = output.withUnsafeMutableBufferPointer { dst in
                source.withUnsafeBytes { src in
                    compression_decode_buffer(dst.baseAddress!, dst.count, src.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard result == count else { throw OriginalStateError.invalidStorage("Object DEFLATE length mismatch") }
            output.removeLast(); decoded = Data(output)
            guard SHA256.hash(data: decoded).map({ String(format: "%02x", $0) }).joined() == packed.sha256 else {
                throw OriginalStateError.invalidStorage("Object DEFLATE checksum mismatch")
            }
        }
        struct Suite: Decodable { let corpora: [Corpus] }
        let suite = try JSONDecoder().decode(Suite.self, from: decoded)
        guard !suite.corpora.isEmpty else { throw OriginalStateError.invalidStorage("Empty Object suite") }
        let results = try suite.corpora.map { try compare($0) }
        return Result(objects: results.reduce(0) { $0 + $1.objects }, occurrences: results.reduce(0) { $0 + $1.occurrences },
                      finalFrames: results.reduce(0) { $0 + $1.finalFrames }, bytes: results.reduce(0) { $0 + $1.bytes }, bitmaps: results.reduce(0) { $0 + $1.bitmaps },
                      rawFrames: results.reduce(0) { $0 + $1.rawFrames }, allocations: results.reduce(0) { $0 + $1.allocations })
    }
    private static func compare(_ corpus: Corpus) throws -> Result {
        if let crt = corpus.crtSHA256, crt != "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d" {
            throw OriginalStateError.invalidStorage("Unknown Microsoft CRT capture")
        }
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c", !corpus.cases.isEmpty else {
            throw OriginalStateError.invalidStorage("Unknown or empty Object corpus")
        }
        let assets = Dictionary(uniqueKeysWithValues: corpus.assetInputs.map { ($0.path, $0) })
        let bitmapAddresses = corpus.cases.flatMap(\.bitmaps).map(\.address)
        guard Set(bitmapAddresses).count == bitmapAddresses.count else { throw OriginalStateError.invalidStorage("Aliased bitmap wrappers") }
        var loader = OriginalObjectLoader(), bytes = 0, occurrences = 0, rawFrames = 0, allocations = 0
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw OriginalStateError.invalidStorage("\(label): size differs") }
            if let offset = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw OriginalStateError.invalidStorage("\(label)+\(String(offset, radix: 16)): byte or mask differs")
            }
            bytes += actual.bytes.count
        }
        for item in corpus.cases {
            guard loader.checksum == item.initialChecksum else { throw OriginalStateError.invalidStorage("Wrong shared checksum input") }
            let beforeLoad = loader
            var captured: [OriginalFrameRecord] = []
            var mirrors: [OriginalBitmapMirrorRequest] = []
            var rawCaptured: [(Int, OriginalStateRecord)] = []
            var allocationIndex = 0
            let allocationStart = loader.frameAllocations.count
            let rawBacking = try item.frameStorage.map { try hex($0.initial) }
            let bitmapStart = loader.bitmaps.count
            let original = try hex(item.source)
            guard SHA256.hash(data: Data(original)).map({ String(format: "%02x", $0) }).joined() == item.sourceSHA256 else {
                throw OriginalStateError.invalidStorage("Original DAT source hash differs")
            }
            let source = try OriginalDATDecoder.decode(original, fileName: item.path, translation: corpus.translation)
            guard source.unicodeScalars.map({ UInt8($0.value) }) == (try hex(item.decoded)) else {
                throw OriginalStateError.invalidStorage("\(item.path): complete decoder output differs at the declared stdio boundary")
            }
            let result = try loader.load(decoded: source, id: item.id, type: item.type,
                                         headerBacking: hex(item.header.initial), tailBacking: hex(item.tail.initial), bitmapFill: corpus.bitmapFill,
                                         frameBacking: rawBacking, frameAllocation: { kind, size in
                guard let expected = item.frameAllocations else { return nil }
                guard allocationIndex < expected.count, expected[allocationIndex].kind == kind,
                      expected[allocationIndex].storage.initial.count == size*2 else {
                    throw OriginalStateError.invalidStorage("\(item.path): Frame allocation order/size \(allocationIndex)")
                }
                defer { allocationIndex += 1 }
                return expected[allocationIndex].address
            },
                                         bitmapSource: { path in
                guard let asset = assets[path] else { throw OriginalStateError.invalidStorage("Missing bitmap input \(path)") }
                return asset
            }, onMirror: { mirrors.append($0) }, onFrame: { captured.append($0) }, onFrameStorage: { rawCaptured.append(($0, $1)) })
            let expectedMirrors = item.events.filter { $0.kind == "mirror-blit" }
            guard mirrors.count == expectedMirrors.count else { throw OriginalStateError.invalidStorage("Mirror request count differs") }
            for (actual, expected) in zip(mirrors, expectedMirrors) {
                guard let normal = expected.normalAddress.flatMap({ bitmapAddresses.firstIndex(of: $0) }),
                      actual.normalBitmap == normal, actual.mirrorBitmap == expected.bitmap,
                      actual.destination == expected.destination, actual.source == expected.source,
                      actual.flags == 0x1000800, let effects = expected.effects,
                      actual.effects.bytes == (try hex(effects)), actual.effects.defined == Array(repeating: true, count: 100) else {
                    throw OriginalStateError.invalidStorage("Complete mirror Blt caller fields differ")
                }
            }
            if !mirrors.isEmpty {
                enum Stop: Error { case mirror }
                var trial = beforeLoad, reached = false
                do {
                    _ = try trial.load(decoded: source, id: item.id, type: item.type,
                        headerBacking: hex(item.header.initial), tailBacking: hex(item.tail.initial), bitmapFill: corpus.bitmapFill,
                        frameBacking: rawBacking, bitmapSource: { path in
                            guard let asset = assets[path] else { throw OriginalStateError.invalidStorage("Missing mirror rollback asset") }
                            return asset
                        }, onMirror: { _ in reached = true; throw Stop.mirror })
                    throw OriginalStateError.invalidStorage("Mirror observer failure did not propagate")
                } catch Stop.mirror {}
                guard reached, trial.checksum == beforeLoad.checksum, trial.soundBytes == beforeLoad.soundBytes,
                      trial.soundCount == beforeLoad.soundCount, trial.bitmaps == beforeLoad.bitmaps,
                      trial.frameAllocations == beforeLoad.frameAllocations else {
                    throw OriginalStateError.invalidStorage("Mirror observer failure did not roll back Object resources")
                }
            }
            guard captured.count == item.frameOccurrences.count, result.frames.count == 400, item.frames.count == 400 else {
                throw OriginalStateError.invalidStorage("\(item.path): frame counts differ")
            }
            for (phase, actual, expected) in [("occurrence", captured, item.frameOccurrences), ("EOF", result.frames, item.frames)] {
                for i in actual.indices where actual[i] != expected[i] {
                    throw OriginalStateError.invalidStorage("\(item.path): \(phase) \(i), frame \(expected[i].number) differs")
                }
            }
            if let raw = item.frameStorage {
                guard let checkpoints = item.frameStorageOccurrences, checkpoints.count == rawCaptured.count,
                      let expectedAllocations = item.frameAllocations, allocationIndex == expectedAllocations.count,
                      loader.frameAllocations.count - allocationStart == expectedAllocations.count else {
                    throw OriginalStateError.invalidStorage("\(item.path): missing raw Frame/heap evidence")
                }
                let expected = try record(raw)
                guard expected.bytes.count == 400*0x178, result.frameStorage.count == 400 else { throw OriginalStateError.invalidStorage("Raw Frame table size") }
                for index in 0..<400 {
                    let range = index*0x178..<(index+1)*0x178
                    try check(result.frameStorage[index], .init(bytes: Array(expected.bytes[range]), defined: Array(expected.defined[range])), "\(item.path) Frame \(index)")
                    rawFrames += 1
                }
                for (i, frame) in checkpoints.enumerated() {
                    guard rawCaptured[i].0 == frame.number else { throw OriginalStateError.invalidStorage("Raw Frame checkpoint order") }
                    try check(rawCaptured[i].1, record(.init(initial: "", bytes: frame.bytes, defined: frame.defined)), "\(item.path) occurrence \(i)")
                    rawFrames += 1
                }
                for (i, allocation) in expectedAllocations.enumerated() {
                    let actual = loader.frameAllocations[allocationStart+i]
                    guard actual.address == allocation.address, actual.kind == allocation.kind else { throw OriginalStateError.invalidStorage("Frame allocation identity") }
                    try check(actual.storage, record(allocation.storage), "\(item.path) allocation \(i)")
                    allocations += 1
                }
            }
            guard loader.checksum == item.checksum, loader.soundCount == item.soundCount,
                  loader.soundBytes == (try hex(item.soundBytes)), result.weaponSoundPaths == item.weaponSoundPaths else {
                throw OriginalStateError.invalidStorage("\(item.path): shared sound cache/checksum or weapon paths differ")
            }
            var header = try record(item.header)
            func bindBitmap(at offset: Int) throws {
                guard header.defined[offset..<(offset + 4)].allSatisfy({ $0 }) else { return }
                let pointer = try header.integer(at: offset, as: UInt32.self)
                guard let index = bitmapAddresses.firstIndex(of: pointer), pointer != 0 else {
                    throw OriginalStateError.invalidStorage("Unknown bitmap pointer in Object header")
                }
                try header.write(UInt32(index + 1), at: offset)
            }
            for offset in [0x6fc, 0x728] { try bindBitmap(at: offset) }
            let sheets = Int(try header.integer(at: 0x498, as: Int32.self))
            guard (1...10).contains(sheets) else { throw OriginalStateError.invalidStorage("Unverified sheet count") }
            for slot in 1...sheets {
                try bindBitmap(at: 0x750 + slot*4); try bindBitmap(at: 0x778 + slot*4)
            }
            for ordinal in 0..<3 {
                let pointer = try header.integer(at: 0x98 + ordinal*4, as: UInt32.self)
                guard (pointer != 0) == (item.weaponSoundPaths[ordinal] != nil) else { throw OriginalStateError.invalidStorage("Weapon sound nullability") }
                if pointer != 0 { try header.write(UInt32(ordinal + 1), at: 0x98 + ordinal*4) }
            }
            try check(result.header, header, item.path + " header")
            try check(result.nameTail, record(item.tail), item.path + " name tail")
            guard loader.bitmaps.count - bitmapStart == item.bitmaps.count else { throw OriginalStateError.invalidStorage("Bitmap allocation count differs") }
            for (i, bitmap) in item.bitmaps.enumerated() {
                let index = bitmapStart + i, actual = loader.bitmaps[index]
                guard actual.input.path == bitmap.path, UInt32(actual.optional ? 1 : 0) == bitmap.optional else {
                    throw OriginalStateError.invalidStorage("Bitmap request order differs")
                }
                var expected = try record(bitmap.storage)
                let surface = try expected.integer(at: 0, as: UInt32.self)
                guard surface == (actual.input.present ? corpus.surfaceAddress : 0), corpus.surfaceAddress != 0 else {
                    throw OriginalStateError.invalidStorage("Bitmap platform surface boundary differs")
                }
                try expected.write(UInt32(actual.input.present ? 1 : 0), at: 0)
                try check(actual.storage, expected, item.path + " bitmap \(i)")
                let blits = item.events.filter { $0.kind == "mirror-blit" && $0.bitmap == index }
                guard blits.count <= 1 else { throw OriginalStateError.invalidStorage("Repeated mirror blit") }
                let expectedSource = blits.first?.normalAddress.flatMap { bitmapAddresses.firstIndex(of: $0) }
                guard actual.mirroredFrom == expectedSource, blits.isEmpty || expectedSource != nil else {
                    throw OriginalStateError.invalidStorage("Mirror fallback request differs")
                }
            }
            occurrences += captured.count
        }
        return Result(objects: corpus.cases.count, occurrences: occurrences, finalFrames: corpus.cases.count*400, bytes: bytes, bitmaps: loader.bitmaps.count,
                      rawFrames: rawFrames, allocations: allocations)
    }
}
