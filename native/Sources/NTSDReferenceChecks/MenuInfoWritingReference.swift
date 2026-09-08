import Foundation
import NTSDCore

public enum MenuInfoWritingReference {
    public struct Result { public var cases = 0, defaults = 0, caches = 0, events = 0, formats = 0, prints = 0, closes = 0, fileWrites = 0, failedWrites = 0, parentWrites = 0, records = 0, bytes = 0 }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Event: Decodable {
        let kind: String, arguments: [UInt32], strings: [[UInt8]], format: String?, result: UInt32?, returnPC: UInt32?
        let globals: String?, file: String?, buffer: Storage?
    }
    private struct Case: Decodable {
        let label: String, mode: OriginalMenuInfoWriting.Mode, date: [UInt8], index: Int32, period: Int32, capacity: Int, available: Bool, writeMode: String, failAt: Int, closeResult: Int32
        let backing: String, events: [Event], result: UInt32, endPC: UInt32, endSP: UInt32, globals: String, file: String, buffer: Storage
    }
    private struct Source: Decodable { let path: String, bytes: String }
    private struct Corpus: Decodable { let exeSHA256: String, dllSHA256: String, initialGlobals: String, adinfo: Source, cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu info writing reference: "+text) }
    public static func compare(_ data: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(data,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d", c.adinfo.path == "data/adinfo.txt" else { throw error("Source identity") }
        var result = Result(), blobs: [String:[UInt8]] = [:], globalsCache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = blobs[key] { return bytes }
            guard let b = c.blobs[key], b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") };blobs[key] = bytes;return bytes
        }
        func defined(_ key: String,_ size: Int) throws -> OriginalStateRecord {
            let bytes = try blob(key);guard bytes.count == size else { throw error("Record extent") }
            return try .init(bytes: bytes,defined: [Bool](repeating: true,count: size))
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            if let r = globalsCache[key] { return r }
            let r = try defined(key,OriginalMatchPreparation.globalSize);globalsCache[key] = r;return r
        }
        func storage(_ ref: Storage,_ size: Int) throws -> OriginalStateRecord {
            let bytes = try blob(ref.bytes), mask = try blob(ref.defined)
            guard bytes.count == size, mask.count == size, mask.allSatisfy({ $0 < 2 }) else { throw error("Buffer extent/mask") }
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
        for item in c.cases {
            guard [1,7,64,4096].contains(item.capacity), ["full","error","zero","short"].contains(item.writeMode) else { throw error("Output domain") }
            try state.write(item.index,at: 0x44d784-OriginalMatchPreparation.globalBase);try state.write(item.period,at: 0x44d788-OriginalMatchPreparation.globalBase)
            for (i,b) in (item.date+[0]).enumerated() { try state.write(b,at: 0x4527b0-OriginalMatchPreparation.globalBase+i) }
            var stream = try OriginalBufferedTextOutput(backing: blob(item.backing)), eventIndex = 0, writeIndex = 0
            guard stream.buffer.bytes.count == item.capacity else { throw error("Buffer input") }
            let value = try OriginalMenuInfoWriting.run(item.mode,globals: &state,output: &stream,available: item.available,write: { bytes in
                defer { writeIndex += 1 };result.fileWrites += 1
                let count = Int32(bytes.count)
                if writeIndex != item.failAt { return count }
                result.failedWrites += 1
                switch item.writeMode { case "error":return -1;case "zero":return 0;case "short":return count-1;default:throw error("Invalid failing-write input") }
            },close: { item.closeResult },observe: { actual,state,output in
                guard eventIndex < item.events.count else { throw error(item.label+" excess event") }
                let e = item.events[eventIndex];eventIndex += 1
                guard actual.kind == e.kind, actual.arguments == e.arguments, actual.strings == e.strings, actual.format == e.format, actual.result == e.result else {
                    throw error("\(item.label) event\(eventIndex-1): \(actual) vs \(e)")
                }
                if let key = e.globals { try check(state,globals(key),item.label+" "+actual.kind+" globals") }
                if let key = e.file { try check(output.fileStorage(),defined(key,32),item.label+" "+actual.kind+" FILE") }
                if let ref = e.buffer { try check(output.buffer,storage(ref,item.capacity),item.label+" "+actual.kind+" buffer") }
                switch actual.kind {
                case "format":guard [0x43c6f2,0x43c704,0x43c729,0x43c73c].contains(e.returnPC) else { throw error("Format return") };result.formats += 1
                case "print":guard [0x43c6b6,0x43c773].contains(e.returnPC) else { throw error("Print return") };result.prints += 1
                case "close":guard [0x43c6bd,0x43c77a].contains(e.returnPC) else { throw error("Close return") };result.closes += 1
                case "write":result.parentWrites += 1
                default:break
                }
                result.events += 1
            })
            guard eventIndex == item.events.count, value == item.result, item.endPC == 0x30000000, item.endSP == 0x1000f004 else { throw error(item.label+" outer return") }
            try check(state,globals(item.globals),item.label+" final globals")
            try check(stream.fileStorage(),defined(item.file,32),item.label+" final FILE")
            try check(stream.buffer,storage(item.buffer,item.capacity),item.label+" final buffer")
            if item.mode == .defaults { result.defaults += 1 } else { result.caches += 1 };result.cases += 1
        }
        return result
    }
}
