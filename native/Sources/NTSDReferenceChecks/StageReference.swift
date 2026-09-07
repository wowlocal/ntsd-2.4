import Foundation
import Compression
import CryptoKit
import NTSDCore

/// Development-only lossless storage comparison. Compression is solely the
/// fixture transport; the shipping Stage loader uses original record bytes/masks.
public enum StageReference {
    public struct Result { public let loads: Int, initializations: Int, phases: Int, checkpoints: Int, records: Int, bytes: Int }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable, Hashable { let bytes: String, defined: String }
    private struct Checkpoint: Decodable { let kind: String, stage: Int, phase: Int?, record: Record }
    private struct Case: Decodable {
        let name: String, source: String, sourceSHA256: String, decoded: String
        let initialChecksum: UInt32, checksum: UInt32, stageIDs: [Int], phaseIDs: [[Int]]
        let checkpoints: [Checkpoint], records: [Record]
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, translation: OriginalFileTranslation
        let initialRecords: [Record], cases: [Case], blobs: [String: Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Stage reference: \(text)") }
    private static func digest(_ bytes: [UInt8]) -> String {
        SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
    }
    private static func hex(_ text: String) throws -> [UInt8] {
        let bytes = Array(text.utf8)
        guard bytes.count % 2 == 0 else { throw error("Odd hex length") }
        return try stride(from: 0, to: bytes.count, by: 2).map { i in
            guard let value = UInt8(String(decoding: bytes[i..<(i + 2)], as: UTF8.self), radix: 16) else { throw error("Invalid hex") }
            return value
        }
    }
    public static func compare(_ data: Data) throws -> Result { try compare(JSONDecoder().decode(Corpus.self, from: data)) }
    public static func compareSuite(_ data: Data) throws -> Result {
        struct Suite: Decodable { let corpora: [Corpus] }
        let suite = try JSONDecoder().decode(Suite.self, from: data)
        guard !suite.corpora.isEmpty else { throw error("Empty suite") }
        let results = try suite.corpora.map { try compare($0) }
        return Result(loads: results.reduce(0) { $0 + $1.loads }, initializations: results.reduce(0) { $0 + $1.initializations },
                      phases: results.reduce(0) { $0 + $1.phases }, checkpoints: results.reduce(0) { $0 + $1.checkpoints },
                      records: results.reduce(0) { $0 + $1.records }, bytes: results.reduce(0) { $0 + $1.bytes })
    }
    private static func compare(_ corpus: Corpus) throws -> Result {
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c", !corpus.cases.isEmpty else { throw error("Unknown or empty corpus") }
        func blob(_ hash: String) throws -> [UInt8] {
            guard let item = corpus.blobs[hash], item.count == OriginalStageLoader.stageSize,
                  let packed = Data(base64Encoded: item.deflate), !packed.isEmpty else { throw error("Missing/malformed blob") }
            // One spare byte distinguishes exact length from buffer truncation.
            var output = [UInt8](repeating: 0, count: item.count + 1)
            let count = output.withUnsafeMutableBufferPointer { dst in
                packed.withUnsafeBytes { src in
                    compression_decode_buffer(dst.baseAddress!, dst.count, src.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard count == item.count else { throw error("DEFLATE length mismatch") }
            output.removeLast()
            guard digest(output) == hash else { throw error("Decoded blob SHA-256 mismatch") }
            return output
        }
        func record(_ item: Record) throws -> OriginalStateRecord {
            let bytes = try blob(item.bytes), mask = try blob(item.defined)
            guard mask.allSatisfy({ $0 <= 1 }) else { throw error("Invalid initialization mask") }
            return try OriginalStateRecord(bytes: bytes, defined: mask.map { $0 == 1 })
        }
        // Identical initial records share immutable backing until the original's
        // sparse writes require a copy. Checkpoints are decoded one at a time.
        var initialCache: [Record: OriginalStateRecord] = [:]
        var backing: [OriginalStateRecord] = []
        for item in corpus.initialRecords {
            if initialCache[item] == nil { initialCache[item] = try record(item) }
            backing.append(initialCache[item]!)
        }
        var loader = try OriginalStageLoader(backing: backing)
        initialCache.removeAll(); backing.removeAll()
        var recordCount = 0, stageCount = 0, phaseCount = 0, checkpointCount = 0
        func check(_ actual: OriginalStateRecord, _ raw: Record, _ label: String) throws {
            let expected = try record(raw)
            guard actual.bytes == expected.bytes, actual.defined == expected.defined else {
                let offset = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                throw error("\(label)+\(String(offset, radix: 16)): byte/mask differ")
            }
            recordCount += 1
        }
        for item in corpus.cases {
            let source = try hex(item.source)
            guard digest(source) == item.sourceSHA256 else { throw error("Source SHA-256 mismatch") }
            // Unlike Object/BG, 40c910 unconditionally invokes decoder 414a30.
            // Its fixed source path ends in .dat, matching this shared native decoder.
            let decoded = try OriginalDATDecoder.decode(source, fileName: "data\\stage.dat", translation: corpus.translation)
            guard decoded.unicodeScalars.map({ UInt8($0.value) }) == (try hex(item.decoded)) else { throw error("Full decoder output differs") }
            var index = 0, ids: [Int] = [], phases: [[Int]] = []
            try loader.load(decoded: decoded) { kind, stage, phase, storage in
                guard index < item.checkpoints.count else { throw error("Extra checkpoint") }
                let expected = item.checkpoints[index]
                guard kind == expected.kind, stage == expected.stage, phase == expected.phase else { throw error("Checkpoint order differs") }
                try check(storage, expected.record, "\(item.name) \(kind) stage \(stage) phase \(phase ?? -1)")
                if kind == "initialized" { ids.append(stage) }
                else if kind == "phase", let phase { phases.append([stage, phase]) }
                else { throw error("Unknown checkpoint kind") }
                index += 1
            }
            guard index == item.checkpoints.count, ids == item.stageIDs, phases == item.phaseIDs,
                  item.records.count == 60, item.initialChecksum == item.checksum else { throw error("Stage/phase/checksum inventory") }
            for stage in 0..<60 { try check(loader.records[stage], item.records[stage], "\(item.name) EOF stage \(stage)") }
            stageCount += ids.count; phaseCount += phases.count; checkpointCount += index
        }
        return Result(loads: corpus.cases.count, initializations: stageCount, phases: phaseCount, checkpoints: checkpointCount,
                      records: recordCount, bytes: recordCount*OriginalStageLoader.stageSize)
    }
}
