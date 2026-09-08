import Foundation
import NTSDCore

public enum SettingsWritingReference {
    public struct Result {
        public var cases = 0, returns = 0, nullFiles = 0, stringBoundaries = 0, events = 0, prints = 0, closes = 0
        public var fileWrites = 0, failedWrites = 0, parentWrites = 0, records = 0, bytes = 0
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Event: Decodable {
        let kind: String, arguments: [UInt32], strings: [[UInt8]], format: String?, result: UInt32?, returnPC: UInt32?
        let globals: String?, file: String?, buffer: Storage?
    }
    private struct Case: Decodable {
        let label: String, stimulus: [InputControlReference.GlobalWrite], capacity: Int, available: Bool, writeMode: String, failAt: Int, closeResult: Int32
        let backing: String, events: [Event], continuation: String, result: UInt32?, endPC: UInt32, endSP: UInt32, globals: String, file: String, buffer: Storage
    }
    private struct Source: Decodable { let path: String, raw: String, logical: String }
    private struct Literal: Decodable { let address: UInt32, bytes: [UInt8] }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, initialGlobals: String, source: Source, defaults: [Literal], cases: [Case], blobs: [String:Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Settings writing reference: "+text) }
    public static func compare(_ data: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(data,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d", c.source.path == "data/control.txt",
              c.source.raw == "cc7f84872d9b95fe64c1c95cc7895b3e2c0a52a3ae0f7f7970f0b3c56b7037c0",!c.cases.isEmpty else { throw error("Source identity") }
        guard c.defaults.count == OriginalSettingsWriting.defaults.count else { throw error("Default inventory") }
        for (actual,expected) in zip(OriginalSettingsWriting.defaults,c.defaults) {
            guard actual.address == expected.address,actual.bytes == expected.bytes else { throw error("Original default literal") }
        }
        var result = Result(),blobs: [String:[UInt8]] = [:],records: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = blobs[key] { return bytes }
            guard let b = c.blobs[key],b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") };blobs[key] = bytes;return bytes
        }
        func defined(_ key: String,_ size: Int) throws -> OriginalStateRecord {
            if let value = records[key] { guard value.bytes.count == size else { throw error("Cached extent") };return value }
            let bytes = try blob(key);guard bytes.count == size else { throw error("Record extent") }
            let value = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: size));records[key] = value;return value
        }
        func globals(_ key: String) throws -> OriginalStateRecord { try defined(key,OriginalMatchPreparation.globalSize) }
        func storage(_ ref: Storage,_ size: Int) throws -> OriginalStateRecord {
            let key = ref.bytes+ref.defined
            if let value = records[key] { guard value.bytes.count == size else { throw error("Cached buffer extent") };return value }
            let bytes = try blob(ref.bytes),mask = try blob(ref.defined)
            guard bytes.count == size,mask.count == size,mask.allSatisfy({ $0 < 2 }) else { throw error("Buffer extent/mask") }
            let value = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 });records[key] = value;return value
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            }
            result.records += 1;result.bytes += actual.bytes.count
        }
        let raw = try blob(c.source.raw),logical = try blob(c.source.logical)
        var translated: [UInt8] = [],i = 0
        while i < raw.count { if raw[i] == 13,i+1 < raw.count,raw[i+1] == 10 { i += 1 };translated.append(raw[i]);i += 1 }
        guard translated == logical else { throw error("Original control translation") }
        var state = try globals(c.initialGlobals)
        for (caseIndex,item) in c.cases.enumerated() {
            guard [1,7,64,4096].contains(item.capacity),["full","error","zero","short"].contains(item.writeMode) else { throw error("Output domain") }
            for write in item.stimulus {
                let text = Array(write.bytes);guard text.count%2 == 0 else { throw error("Stimulus extent") }
                for j in stride(from: 0,to: text.count,by: 2) {
                    guard let byte = UInt8(String(text[j...j+1]),radix: 16) else { throw error("Stimulus byte") }
                    try state.write(byte,at: Int(write.address)-OriginalMatchPreparation.globalBase+j/2)
                }
            }
            var stream = try OriginalBufferedTextOutput(backing: blob(item.backing)),eventIndex = 0,writeIndex = 0,written: [UInt8] = []
            guard stream.buffer.bytes.count == item.capacity else { throw error("Buffer input") }
            let value = try OriginalSettingsWriting.run(globals: &state,output: &stream,available: item.available,write: { bytes in
                defer { writeIndex += 1 };result.fileWrites += 1;written += bytes
                let count = Int32(bytes.count)
                if writeIndex != item.failAt { return count }
                result.failedWrites += 1
                switch item.writeMode { case "error":return -1;case "zero":return 0;case "short":return count-1;default:throw error("Invalid failing write") }
            },close: { item.closeResult },observe: { actual,state,output in
                guard eventIndex < item.events.count else { throw error(item.label+" excess event") };let e = item.events[eventIndex];eventIndex += 1
                guard actual.kind == e.kind,actual.arguments == e.arguments,actual.strings == e.strings,actual.format == e.format,actual.result == e.result else {
                    throw error("\(item.label) event\(eventIndex-1): \(actual) vs \(e)")
                }
                if let key = e.globals { try check(state,globals(key),item.label+" "+actual.kind+" globals") }
                if let key = e.file { try check(output.fileStorage(),defined(key,32),item.label+" "+actual.kind+" FILE") }
                if let ref = e.buffer { try check(output.buffer,storage(ref,item.capacity),item.label+" "+actual.kind+" buffer") }
                switch actual.kind {
                case "print":guard [0x423266,0x42327d,0x423345,0x4233ea,0x4233f8,0x423405,0x423412,0x42341f].contains(e.returnPC) else { throw error("Print return") };result.prints += 1
                case "close":guard e.returnPC == 0x423426 else { throw error("Close return") };result.closes += 1
                case "write":result.parentWrites += 1
                default:break
                }
                result.events += 1
            })
            guard eventIndex == item.events.count,value.value == item.result else { throw error(item.label+" final events/value") }
            switch value {
            case .returned:guard item.continuation == "returned",item.endPC == 0x30000000,item.endSP == 0x1000f004 else { throw error("Outer return") };result.returns += 1
            case .nullFile:guard item.continuation == "nullFile",item.endPC == 0x423260,item.endSP == 0x1000efe0 else { throw error("Null FILE boundary") };result.nullFiles += 1
            case .unterminatedName(let pc):guard item.continuation == "unterminatedName",item.endPC == pc else { throw error("String boundary") };result.stringBoundaries += 1
            }
            try check(state,globals(item.globals),item.label+" final globals");try check(stream.fileStorage(),defined(item.file,32),item.label+" final FILE")
            try check(stream.buffer,storage(item.buffer,item.capacity),item.label+" final buffer")
            if caseIndex == 0 { guard written == logical else { throw error("Original control byte roundtrip") } }
            result.cases += 1
        }
        return result
    }
}
