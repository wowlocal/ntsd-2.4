import Foundation
import CryptoKit
import NTSDCore

/// A compact projection of full original Object captures. It compares all header,
/// tail and bitmap bytes/masks, all defined frame words/boxes after each occurrence
/// and at EOF, and the shared sound cache/checksum. Raw Frame padding and dead
/// malloc allocations remain in the research corpus, outside native comparison.
public enum ObjectReference {
    public struct Result { public let objects: Int, occurrences: Int, finalFrames: Int, bytes: Int, bitmaps: Int }
    private struct Corpus: Decodable {
        let exeSHA256: String, bitmapFill: UInt8, surfaceAddress: UInt32
        let translation: OriginalFileTranslation
        let cases: [Case], assetInputs: [OriginalBitmapInput]
    }
    private struct Record: Decodable { let initial: String, bytes: String, defined: String }
    private struct Bitmap: Decodable { let address: UInt32, path: String, optional: UInt32, storage: Record }
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
        let weaponSoundPaths: [Int: String], soundCount: Int, soundBytes: String
    }
    private static func hex(_ text: String) throws -> [UInt8] {
        let chars = Array(text.utf8)
        guard chars.count % 2 == 0 else { throw OriginalStateError.invalidStorage("Odd object hex length") }
        return try stride(from: 0, to: chars.count, by: 2).map { i in
            guard let byte = UInt8(String(decoding: chars[i..<(i + 2)], as: UTF8.self), radix: 16) else {
                throw OriginalStateError.invalidStorage("Invalid object hex")
            }
            return byte
        }
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
        struct Suite: Decodable { let corpora: [Corpus] }
        let suite = try JSONDecoder().decode(Suite.self, from: data)
        guard !suite.corpora.isEmpty else { throw OriginalStateError.invalidStorage("Empty Object suite") }
        let results = try suite.corpora.map { try compare($0) }
        return Result(objects: results.reduce(0) { $0 + $1.objects }, occurrences: results.reduce(0) { $0 + $1.occurrences },
                      finalFrames: results.reduce(0) { $0 + $1.finalFrames }, bytes: results.reduce(0) { $0 + $1.bytes }, bitmaps: results.reduce(0) { $0 + $1.bitmaps })
    }
    private static func compare(_ corpus: Corpus) throws -> Result {
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c", !corpus.cases.isEmpty else {
            throw OriginalStateError.invalidStorage("Unknown or empty Object corpus")
        }
        let assets = Dictionary(uniqueKeysWithValues: corpus.assetInputs.map { ($0.path, $0) })
        let bitmapAddresses = corpus.cases.flatMap(\.bitmaps).map(\.address)
        guard Set(bitmapAddresses).count == bitmapAddresses.count else { throw OriginalStateError.invalidStorage("Aliased bitmap wrappers") }
        var loader = OriginalObjectLoader(), bytes = 0, occurrences = 0
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw OriginalStateError.invalidStorage("\(label): size differs") }
            if let offset = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw OriginalStateError.invalidStorage("\(label)+\(String(offset, radix: 16)): byte or mask differs")
            }
            bytes += actual.bytes.count
        }
        for item in corpus.cases {
            guard loader.checksum == item.initialChecksum else { throw OriginalStateError.invalidStorage("Wrong shared checksum input") }
            var captured: [OriginalFrameRecord] = []
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
                                         bitmapSource: { path in
                guard let asset = assets[path] else { throw OriginalStateError.invalidStorage("Missing bitmap input \(path)") }
                return asset
            }, onFrame: { captured.append($0) })
            guard captured.count == item.frameOccurrences.count, result.frames.count == 400, item.frames.count == 400 else {
                throw OriginalStateError.invalidStorage("\(item.path): frame counts differ")
            }
            for (phase, actual, expected) in [("occurrence", captured, item.frameOccurrences), ("EOF", result.frames, item.frames)] {
                for i in actual.indices where actual[i] != expected[i] {
                    throw OriginalStateError.invalidStorage("\(item.path): \(phase) \(i), frame \(expected[i].number) differs")
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
            guard (1...9).contains(sheets) else { throw OriginalStateError.invalidStorage("Unverified sheet count") }
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
        return Result(objects: corpus.cases.count, occurrences: occurrences, finalFrames: corpus.cases.count*400, bytes: bytes, bitmaps: loader.bitmaps.count)
    }
}
