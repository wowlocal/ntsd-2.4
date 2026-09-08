import Foundation
import NTSDCore

public enum SettingsLoadingReference {
    public struct Result {
        public var cases = 0, scans = 0, gets = 0, eof = 0, writes = 0, returns = 0, nullFiles = 0, events = 0, records = 0, bytes = 0
        public var front = FrontMenuResourcesReference.Result()
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Source: Decodable { let path: String, raw: String, logical: String }
    private struct Event: Decodable {
        let kind: String, arguments: [UInt32]?, strings: [String]?, format: String?, before: Int?, position: Int?, eof: Bool?, result: UInt32?
        let returnPC: UInt32?, globals: String?, scratch: Storage?
    }
    private struct Case: Decodable {
        let label: String, input: String, chunk: Int, present: Bool, closeResult: Int32
        let stimulus: [InputControlReference.GlobalWrite], events: [Event], continuation: OriginalSettingsLoading.Continuation
        let callerEBX: UInt32, endPC: UInt32, endSP: UInt32, globals: String, scratch: Storage
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, settingsInitialGlobals: String, settingsWorld: Storage
        let scratchAddress: UInt32, scratchBacking: String, source: Source, cases: [Case], blobs: [String:Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Settings loading reference: "+text) }
    public static func compare(_ data: Data) throws -> Result {
        let raw = try MatchPreparationReference.unpack(data,maximumCount: 128_000_000)
        let c = try JSONDecoder().decode(Corpus.self,from: raw)
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.scratchAddress == 0x1000ee04, !c.cases.isEmpty else { throw error("Identity/stack") }
        var result = Result(), blobs: [String:[UInt8]] = [:], globalRecords: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = blobs[key] { return bytes }
            guard let b = c.blobs[key], b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") }
            blobs[key] = bytes;return bytes
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            if let record = globalRecords[key] { return record }
            let bytes = try blob(key);guard bytes.count == OriginalMatchPreparation.globalSize else { throw error("Global extent") }
            let record = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count))
            globalRecords[key] = record;return record
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let bytes = try blob(ref.bytes), mask = try blob(ref.defined)
            guard mask.count == bytes.count, mask.allSatisfy({ $0 < 2 }) else { throw error("Mask") }
            return try .init(bytes: bytes,defined: mask.map { $0 != 0 })
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual == expected else {
                let mismatch = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(mismatch.map { String($0,radix:16) } ?? "extent"))
            }
            result.records += 1;result.bytes += actual.bytes.count
        }
        guard c.source.path == "data/control.txt",
              c.source.raw == "cc7f84872d9b95fe64c1c95cc7895b3e2c0a52a3ae0f7f7970f0b3c56b7037c0",
              c.cases[0].input == c.source.logical else { throw error("Original control file binding") }
        let source = try blob(c.source.raw)
        var translated: [UInt8] = [], index = 0
        while index < source.count {
            if source[index] == 13, index+1 < source.count, source[index+1] == 10 { index += 1 }
            translated.append(source[index]);index += 1
        }
        guard try translated == blob(c.source.logical) else { throw error("Declared original CRLF input") }
        // Reuse the existing independent native World/resource loader against
        // this capture's fresh original parent. No expected after-state is input.
        guard let document = try JSONSerialization.jsonObject(with: raw) as? [String:Any], let frontCase = document["front"] else { throw error("Parent corpus") }
        var frontDocument: [String:Any] = [:]
        for key in ["exeSHA256","control","worldBacking","initialWorld","sources","blobs"] { frontDocument[key] = document[key] }
        frontDocument["initialGlobals"] = document["frontInitialGlobals"];frontDocument["cases"] = [frontCase]
        var current: OriginalStateRecord?
        result.front = try FrontMenuResourcesReference.compare(JSONSerialization.data(withJSONObject: frontDocument)) { world,state,_ in
            try check(world,storage(c.settingsWorld),"Parent World")
            try check(state,globals(c.settingsInitialGlobals),"Parent globals")
            current = state
        }
        guard var state = current else { throw error("Missing native parent") }
        var scratch = try OriginalStateRecord(bytes: blob(c.scratchBacking),defined: [Bool](repeating: false,count: 0x1f4))
        for (caseIndex,item) in c.cases.enumerated() {
            guard [1,7,4096].contains(item.chunk), caseIndex != 0 || item.stimulus.isEmpty && item.present && item.callerEBX == 0 else { throw error("Caller input") }
            for write in item.stimulus {
                guard write.bytes.count%2 == 0 else { throw error("Stimulus hex") }
                let text = Array(write.bytes)
                for i in stride(from: 0,to: text.count,by: 2) {
                    guard let byte = UInt8(String(text[i...i+1]),radix: 16) else { throw error("Stimulus byte") }
                    try state.write(byte,at: Int(write.address)-OriginalMatchPreparation.globalBase+i/2)
                }
            }
            var eventIndex = 0
            let end = try OriginalSettingsLoading.loadAndContinueStartup(globals: &state,scratch: &scratch,translatedBytes: blob(item.input),
                file: item.present ? 0x20001000 : 0,scratchAddress: c.scratchAddress,closeResult: item.closeResult,flagClearValue: item.callerEBX) { actual,state,temporary in
                guard eventIndex < item.events.count else { throw error(item.label+" excess event") }
                let expected = item.events[eventIndex];eventIndex += 1
                var arguments = expected.arguments ?? [], expectedResult = expected.result
                if expected.kind == "settingsReturn" {
                    guard arguments.count == 2, arguments[0] == 0x1000f000 else { throw error("Settings ret/stack") }
                    expectedResult = arguments[1];arguments = []
                }
                guard actual.kind.rawValue == expected.kind, actual.arguments == arguments, actual.strings == (expected.strings ?? []),
                      actual.format == expected.format, actual.before == expected.before, actual.position == expected.position,
                      actual.eof == expected.eof, actual.result == expectedResult else {
                    throw error("\(item.label) event\(eventIndex-1) \(actual) vs \(expected)")
                }
                if let key = expected.globals { try check(state,globals(key),item.label+" "+expected.kind+" globals") }
                if let ref = expected.scratch { try check(temporary,storage(ref),item.label+" "+expected.kind+" scratch") }
                switch actual.kind {
                case .scan:
                    guard [0x4234dd,0x423513,0x42356d,0x42357a].contains(expected.returnPC) else { throw error("Scanf return") };result.scans += 1
                case .gets:
                    guard [0x42358a,0x423594,0x423688].contains(expected.returnPC) else { throw error("Fgets return") };result.gets += 1
                case .eof:
                    guard [0x423646,0x4236c1].contains(expected.returnPC) else { throw error("Feof return") };result.eof += 1
                case .settingsReturn:result.returns += 1
                case .write:result.writes += 1
                default:break
                }
                result.events += 1
            }
            guard end == item.continuation, eventIndex == item.events.count else { throw error(item.label+" continuation") }
            if end == .ready {
                guard item.endPC == 0x42709b, item.endSP == 0x1000f000 else { throw error("Caller end") }
            } else {
                guard item.endPC == 0x4234db, item.endSP == 0x1000ede0 else { throw error("Null FILE boundary") };result.nullFiles += 1
            }
            try check(state,globals(item.globals),item.label+" final globals")
            try check(scratch,storage(item.scratch),item.label+" final scratch")
            result.cases += 1
        }
        return result
    }
}
