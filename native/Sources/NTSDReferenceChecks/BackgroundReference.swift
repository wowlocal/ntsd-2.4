import Foundation
import CryptoKit
import NTSDCore

/// Independent comparison with full original 0x990 BG records and 0x1f50
/// wrappers. Fixture compression is lossless: original untouched bitmap tails
/// are validated by the Python capture and reconstructed here, then compared.
public enum BackgroundReference {
    public struct Result { public let calls: Int, parses: Int, bitmaps: Int, releases: Int, bytes: Int }
    private struct Corpus: Decodable {
        let exeSHA256: String, bitmapFill: UInt8, surfaceAddress: UInt32, initialChecksum: UInt32
        let translation: OriginalFileTranslation
        let cases: [Case], bitmaps: [Bitmap], released: [UInt32], assetInputs: [OriginalBitmapInput]
    }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct BitmapRecord: Decodable { let prefix: String, definedPrefix: String }
    private struct Bitmap: Decodable { let address: UInt32, path: String, optional: UInt32, storage: BitmapRecord }
    private struct Request: Decodable { let address: UInt32, path: String, optional: UInt32 }
    private struct Event: Decodable { let kind: String, address: UInt32? }
    private struct Case: Decodable {
        let kind: String, index: Int, id: Int32, path: String?
        let initialChecksum: UInt32, checksum: UInt32, before: Record, after: Record
        let source: String?, sourceSHA256: String?, decoded: String?, outerTokens: [String]
        let bitmaps: [Request], events: [Event]
    }
    private static func error(_ value: String) -> OriginalStateError { .invalidStorage("Background reference: \(value)") }
    private static func hex(_ value: String) throws -> [UInt8] {
        let bytes = Array(value.utf8)
        guard bytes.count % 2 == 0 else { throw error("Odd hex length") }
        return try stride(from: 0, to: bytes.count, by: 2).map { i in
            guard let result = UInt8(String(decoding: bytes[i..<(i + 2)], as: UTF8.self), radix: 16) else { throw error("Invalid hex") }
            return result
        }
    }
    private static func record(_ value: Record) throws -> OriginalStateRecord {
        let bytes = try hex(value.bytes), defined = try hex(value.defined)
        guard defined.allSatisfy({ $0 <= 1 }) else { throw error("Invalid mask") }
        return try OriginalStateRecord(bytes: bytes, defined: defined.map { $0 == 1 })
    }
    public static func compare(_ data: Data) throws -> Result { try compare(JSONDecoder().decode(Corpus.self, from: data)) }
    public static func compareSuite(_ data: Data) throws -> Result {
        struct Suite: Decodable { let corpora: [Corpus] }
        let suite = try JSONDecoder().decode(Suite.self, from: data)
        guard !suite.corpora.isEmpty else { throw error("Empty suite") }
        let results = try suite.corpora.map { try compare($0) }
        return Result(calls: results.reduce(0) { $0 + $1.calls }, parses: results.reduce(0) { $0 + $1.parses },
                      bitmaps: results.reduce(0) { $0 + $1.bitmaps }, releases: results.reduce(0) { $0 + $1.releases }, bytes: results.reduce(0) { $0 + $1.bytes })
    }
    private static func compare(_ corpus: Corpus) throws -> Result {
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c", !corpus.cases.isEmpty else { throw error("Unknown or empty corpus") }
        let assets = Dictionary(uniqueKeysWithValues: corpus.assetInputs.map { ($0.path, $0) })
        let addresses = corpus.bitmaps.map(\.address)
        guard Set(addresses).count == addresses.count, !addresses.contains(0) else { throw error("Aliased/null bitmap address") }
        let addressIndices = Dictionary(uniqueKeysWithValues: addresses.enumerated().map { ($0.element, $0.offset) })
        func normalize(_ raw: Record) throws -> OriginalStateRecord {
            var result = try record(raw)
            guard result.bytes.count == 0x990 else { throw error("BG record size") }
            for offset in Array(stride(from: 0x914, to: 0x98c, by: 4)) + [0x98c] {
                if result.defined[offset..<(offset + 4)].allSatisfy({ $0 }) {
                    let pointer = try result.integer(at: offset, as: UInt32.self)
                    if pointer != 0 {
                        guard let index = addressIndices[pointer] else { throw error("Unknown bitmap pointer at \(offset)") }
                        try result.write(UInt32(index + 1), at: offset)
                    }
                }
            }
            return result
        }
        var loader = OriginalBackgroundLoader(initialChecksum: corpus.initialChecksum)
        var records: [Int: OriginalStateRecord] = [:], byteCount = 0, parses = 0, released: [UInt32] = []
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String, count: Bool = true) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error("\(label) size differs") }
            if let offset = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw error("\(label)+\(String(offset, radix: 16)): \(actual.bytes[offset])/\(actual.defined[offset]) vs \(expected.bytes[offset])/\(expected.defined[offset])")
            }
            if count { byteCount += actual.bytes.count }
        }
        func bitmapSource(_ path: String) throws -> OriginalBitmapInput {
            guard let asset = assets[path] else { throw error("No captured bitmap input: \(path)") }
            return asset
        }
        for (step, item) in corpus.cases.enumerated() {
            let before = try normalize(item.before)
            var storage = records[item.index] ?? before
            try check(storage, before, "Step \(step) input", count: false)
            guard loader.checksum == item.initialChecksum else { throw error("Shared checksum input") }
            let bitmapStart = loader.bitmaps.count
            var releaseIndices: [Int] = []
            switch item.kind {
            case "parse":
                guard let raw = item.source, let hash = item.sourceSHA256, let decoded = item.decoded, let path = item.path else { throw error("Missing parse input") }
                let source = try hex(raw)
                guard SHA256.hash(data: Data(source)).map({ String(format: "%02x", $0) }).joined() == hash else { throw error("Source hash") }
                let logical = try OriginalDATDecoder.decode(source, fileName: path, translation: corpus.translation)
                guard logical.unicodeScalars.map({ UInt8($0.value) }) == (try hex(decoded)) else { throw error("Declared stdio decoder output") }
                storage = try loader.parse(decoded: logical, backing: storage, bitmapFill: corpus.bitmapFill, bitmapSource: bitmapSource)
                let expectedTokens = try item.outerTokens.map { try hex($0) }
                guard loader.outerTokens.map({ $0.unicodeScalars.map { UInt8($0.value) } }) == expectedTokens else { throw error("Outer token sequence differs") }
                parses += 1
            case "load":
                try loader.loadLayers(in: &storage, bitmapFill: corpus.bitmapFill, bitmapSource: bitmapSource)
            case "release":
                releaseIndices = try loader.releaseLayers(in: &storage)
            default: throw error("Unknown call kind")
            }
            guard loader.checksum == item.checksum else { throw error("Step \(step) checksum differs") }
            try check(storage, normalize(item.after), "Step \(step) \(item.kind) BG \(item.index)")
            records[item.index] = storage
            guard loader.bitmaps.count - bitmapStart == item.bitmaps.count else { throw error("Bitmap allocation count") }
            for (offset, request) in item.bitmaps.enumerated() {
                let index = bitmapStart + offset, actual = loader.bitmaps[index]
                guard addresses[index] == request.address, actual.input.path == request.path, request.optional == 0, !actual.optional else { throw error("Ordered bitmap request") }
            }
            let events = item.events.filter { $0.kind == "surface-release" || $0.kind == "free" }
            guard events.count == releaseIndices.count*2 else { throw error("Release request count") }
            for (i, index) in releaseIndices.enumerated() {
                guard events[i*2].kind == "surface-release", events[i*2 + 1].kind == "free",
                      events[i*2].address == addresses[index], events[i*2 + 1].address == addresses[index] else { throw error("Release/free order") }
                released.append(addresses[index])
            }
        }
        guard loader.bitmaps.count == corpus.bitmaps.count, released == corpus.released,
              loader.releasedBitmaps == Set(released.compactMap { addressIndices[$0] }) else { throw error("Final allocation/release inventory") }
        for (index, bitmap) in corpus.bitmaps.enumerated() {
            let prefix = try hex(bitmap.storage.prefix), mask = try hex(bitmap.storage.definedPrefix)
            guard prefix.count == 12, mask.count == 12, mask.allSatisfy({ $0 <= 1 }) else { throw error("Bitmap lossless codec") }
            var expected = try OriginalStateRecord(bytes: prefix + Array(repeating: corpus.bitmapFill, count: 0x1f50 - 12),
                                                   defined: mask.map { $0 == 1 } + Array(repeating: false, count: 0x1f50 - 12))
            let surface = try expected.integer(at: 0, as: UInt32.self)
            guard corpus.surfaceAddress != 0, surface == corpus.surfaceAddress, loader.bitmaps[index].input.present else { throw error("Opaque device surface boundary") }
            try expected.write(UInt32(1), at: 0)
            try check(loader.bitmaps[index].storage, expected, "Bitmap \(index)")
        }
        return Result(calls: corpus.cases.count, parses: parses, bitmaps: loader.bitmaps.count, releases: released.count, bytes: byteCount)
    }
}
