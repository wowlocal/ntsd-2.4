import Foundation
import NTSDCore

public enum MenuContentReference {
    public struct Result { public var cases = 0, events = 0, formats = 0, gets = 0, scans = 0, writes = 0, success = 0, failure = 0, boundaries = 0, records = 0, bytes = 0 }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Event: Decodable {
        let kind: String, arguments: [UInt32]?, strings: [[UInt8]]?, format: String?, before: Int?, position: Int?, eof: Bool?, result: UInt32?
        let returnPC: UInt32?, globals: String?, scratch: Storage?
    }
    private struct Case: Decodable {
        let label: String, input: String?, index: Int32, chunk: Int, closeResult: Int32, backing: String, events: [Event]
        let continuation: String, endPC: UInt32, endSP: UInt32, result: UInt32, globals: String, scratch: Storage
    }
    private struct Source: Decodable { let path: String, bytes: String }
    private struct Corpus: Decodable { let exeSHA256: String, dllSHA256: String, initialGlobals: String, absentOriginalFiles: [String], adinfo: Source, cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu content reference: "+text) }
    public static func compare(_ data: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(data,maximumCount: 256_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.absentOriginalFiles == ["data/ad0.txt","data/ad1.txt","sprite/sys/ad0.bmp","sprite/sys/ad1.bmp"],
              c.adinfo.path == "data/adinfo.txt", c.cases.count >= 2 else { throw error("Source identity") }
        var result = Result(), blobs: [String:[UInt8]] = [:], globalRecords: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = blobs[key] { return bytes }
            guard let b = c.blobs[key], b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") };blobs[key] = bytes;return bytes
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            if let r = globalRecords[key] { return r }
            let bytes = try blob(key);guard bytes.count == OriginalMatchPreparation.globalSize else { throw error("Global extent") }
            let r = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count));globalRecords[key] = r;return r
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let bytes = try blob(ref.bytes), mask = try blob(ref.defined)
            guard bytes.count == 0x450, mask.count == bytes.count, mask.allSatisfy({ $0 < 2 }) else { throw error("Scratch extent/mask") }
            return try .init(bytes: bytes,defined: mask.map { $0 != 0 })
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            }
            result.records += 1;result.bytes += actual.bytes.count
        }
        guard try blob(c.adinfo.bytes) == Array("now 0 4 <end>\r\n".utf8) else { throw error("Original adinfo") }
        var state = try globals(c.initialGlobals)
        for (i,item) in c.cases.enumerated() {
            guard [1,7,4096].contains(item.chunk), i >= 2 || item.input == nil && item.index == Int32(i) else { throw error("File input") }
            try state.write(item.index,at: 0x44d784-OriginalMatchPreparation.globalBase)
            var scratch = try OriginalStateRecord(bytes: blob(item.backing),defined: [Bool](repeating: false,count: 0x450)), eventIndex = 0
            let input = try item.input.map(blob)
            let value = try OriginalMenuContent.load(globals: &state,local: &scratch,translatedBytes: input,closeResult: item.closeResult) { actual,state,local in
                guard eventIndex < item.events.count else { throw error(item.label+" excess event") }
                let expected = item.events[eventIndex];eventIndex += 1
                guard actual.kind == expected.kind, actual.arguments == (expected.arguments ?? []), actual.strings == (expected.strings ?? []),
                      actual.format == expected.format, actual.before == expected.before, actual.position == expected.position,
                      actual.eof == expected.eof, actual.result == expected.result else {
                    throw error("\(item.label) event\(eventIndex-1): \(actual) vs \(expected)")
                }
                if let key = expected.globals { try check(state,globals(key),item.label+" "+actual.kind+" globals") }
                if let ref = expected.scratch { try check(local,storage(ref),item.label+" "+actual.kind+" locals") }
                switch actual.kind {
                case "format":guard [0x43c7ae,0x43c7c1].contains(expected.returnPC) else { throw error("Format return") };result.formats += 1
                case "gets":guard [0x43c7fa,0x43c8a4,0x43c9b9,0x43ca8d,0x43cb2d,0x43cbe7].contains(expected.returnPC) else { throw error("Gets return") };result.gets += 1
                case "scan":guard [0x43c81d,0x43c8d1,0x43c9de,0x43cab6,0x43cb50,0x43cbfb].contains(expected.returnPC) else { throw error("Scan return") };result.scans += 1
                case "write":result.writes += 1
                default:break
                }
                result.events += 1
            }
            guard eventIndex == item.events.count else { throw error(item.label+" unconsumed events") }
            if let call = value.boundaryCall {
                guard item.continuation == "unterminatedInput", item.endPC == call, value.value == nil else { throw error("Unterminated input boundary") };result.boundaries += 1
            } else {
                guard item.continuation == "returned", value.value == item.result, item.result <= 1, item.endPC == 0x30000000, item.endSP == 0x1000f004 else { throw error(item.label+" return") }
                if item.result == 1 { result.success += 1 } else { result.failure += 1 }
            }
            try check(state,globals(item.globals),item.label+" final globals");try check(scratch,storage(item.scratch),item.label+" final locals")
            result.cases += 1
        }
        return result
    }
}
