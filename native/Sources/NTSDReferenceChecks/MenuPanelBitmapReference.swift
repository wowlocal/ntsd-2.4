import Foundation
import NTSDCore

public enum MenuPanelBitmapReference {
    public struct Result {
        public var cases = 0, sources = 0, helpers = 0, constructors = 0, destructors = 0, allocations = 0, nullAllocations = 0
        public var events = 0, writes = 0, releases = 0, frees = 0, reused = 0, success = 0, failure = 0, records = 0, bytes = 0
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, live: Bool, storage: Storage }
    private struct Allocation: Decodable { let address: UInt32, backing: String? }
    private struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    private struct Call: Decodable { let entry: UInt32, address: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32, result: UInt32 }
    private struct Case: Decodable {
        let label: String, path: String, allocation: Allocation, resource: OriginalBitmapInput?, surface: UInt32, colorKeyResult: Int32, releaseResult: UInt32
        let calls: [Call], events: [OriginalMenuPanelBitmapEvent], result: UInt32, endPC: UInt32, endSP: UInt32, globals: String, records: [Record]
    }
    private struct Corpus: Decodable { let exeSHA256: String, initialGlobals: String, absentOriginalFiles: [String], sources: [Source], cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu panel bitmap reference: "+text) }
    public static func compare(_ data: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(data,maximumCount: 64_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.absentOriginalFiles == ["sprite/sys/ad0.bmp","sprite/sys/ad1.bmp"], c.cases.count >= 2,
              Set(c.sources.map(\.path)) == ["MENU_CLIP","MENU_BACK1","SPARK"], c.sources.count == 3 else { throw error("Source identity") }
        var result = Result(), blobs: [String:[UInt8]] = [:], normalized: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = blobs[key] { return bytes }
            guard let b = c.blobs[key], b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") };blobs[key] = bytes;return bytes
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            if let r = normalized[key] { return r }
            let bytes = try blob(key);guard bytes.count == OriginalMatchPreparation.globalSize else { throw error("Global extent") }
            let r = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count));normalized[key] = r;return r
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let key = ref.bytes+ref.defined
            if let r = normalized[key] { return r }
            let bytes = try blob(ref.bytes), mask = try blob(ref.defined)
            guard bytes.count == 0x1f50, mask.count == bytes.count, mask.allSatisfy({ $0 < 2 }) else { throw error("Bitmap extent/mask") }
            var r = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 })
            let surface = try r.integer(at: 0,as: UInt32.self)
            try r.write(UInt32(surface == 0 ? 0 : 1),at: 0);normalized[key] = r;return r
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            }
            result.records += 1;result.bytes += actual.bytes.count
        }
        var sources: [String:Source] = [:]
        for source in c.sources {
            let bytes = try blob(source.dib);guard bytes.count >= 40 else { throw error("DIB header") }
            let r = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count))
            guard try r.integer(at: 0,as: UInt32.self) >= 40, try r.integer(at: 4,as: Int32.self) == source.width,
                  try r.integer(at: 8,as: Int32.self) == source.height else { throw error("DIB dimensions") }
            sources[source.path] = source;result.sources += 1
        }
        var state = try globals(c.initialGlobals), loader = OriginalMenuPanelBitmap(), inputs: [OriginalBitmapInput] = [], seen = Set<UInt32>()
        for (i,item) in c.cases.enumerated() {
            guard i >= 2 || item.path == c.absentOriginalFiles[i].replacingOccurrences(of: "/",with: "\\") && item.resource?.present == false else { throw error("Original missing files") }
            for (j,b) in (Array(item.path.utf8)+[0]).enumerated() { try state.write(b,at: 0x453d40-OriginalMatchPreparation.globalBase+j) }
            var eventIndex = 0, allocationCount = 0, inputCount = 0, deviceCount = 0
            let value = try loader.load(globals: &state,allocate: {
                allocationCount += 1;result.allocations += 1
                let a = item.allocation
                if a.address == 0 {
                    guard a.backing == nil, item.resource == nil else { throw error("Null allocation") }
                    result.nullAllocations += 1;return .init(address: 0,backing: [])
                }
                guard let backing = a.backing else { throw error("Missing malloc backing") }
                if !seen.insert(a.address).inserted { result.reused += 1 }
                return try .init(address: a.address,backing: blob(backing))
            },source: { path in
                inputCount += 1
                guard let input = item.resource, input.path == path, input.present == (item.surface != 0) else { throw error("Resource binding") }
                if input.present {
                    guard let source = sources[path], input.width == source.width, input.height == source.height else { throw error("Original DIB binding") }
                } else { guard input.width == nil, input.height == nil else { throw error("Missing DIB dimensions") } }
                inputs.append(input);return input
            },deviceResult: {
                deviceCount += 1;return (item.surface,item.colorKeyResult)
            },observe: { event in
                guard eventIndex < item.events.count, event == item.events[eventIndex] else { throw error("\(item.label) event\(eventIndex): \(event)") }
                eventIndex += 1;result.events += 1
                switch event.kind { case "write":result.writes += 1;case "release":result.releases += 1;case "free":result.frees += 1;default:break }
            })
            guard allocationCount == 1, inputCount == (item.allocation.address == 0 ? 0 : 1), deviceCount == inputCount,
                  eventIndex == item.events.count, item.result == (value ? 1 : 0), item.endPC == 0x30000000, item.endSP == 0x1000f004,
                  loader.records.count == item.records.count, inputs.count == item.records.count else { throw error(item.label+" return/lifetime") }
            var constructors = 0, destructors = 0
            for call in item.calls {
                guard call.saved.count == 4, call.returnSP == call.entrySP+4+call.pop, call.returnSP == 0x1000efd8 else { throw error("Child ABI") }
                if call.entry == 0x43ee50 {
                    guard call.returnPC == 0x43ccd9, call.pop == 12, call.address == item.allocation.address, call.result == call.address else { throw error("Constructor return") };constructors += 1
                } else {
                    guard call.entry == 0x43ef50, call.returnPC == 0x43cc9c, call.pop == 0, item.events.contains(.init("destroy",[call.address])) else { throw error("Destructor return") };destructors += 1
                }
                result.helpers += 1
            }
            guard constructors == inputCount, destructors == item.events.filter({ $0.kind == "destroy" }).count else { throw error("Helper coverage") }
            result.constructors += constructors;result.destructors += destructors
            try check(state,globals(item.globals),item.label+" globals")
            for (j,expected) in item.records.enumerated() {
                let actual = loader.records[j], raw = try blob(expected.storage.bytes)
                let surface = UInt32(raw[0]) | UInt32(raw[1])<<8 | UInt32(raw[2])<<16 | UInt32(raw[3])<<24
                guard actual.address == expected.address, actual.live == expected.live, actual.surface == surface,
                      actual.bitmap.input == inputs[j], !actual.bitmap.optional else { throw error(item.label+" allocation generation\(j)") }
                try check(actual.bitmap.storage,storage(expected.storage),item.label+" bitmap generation\(j)")
            }
            if value { result.success += 1 } else { result.failure += 1 };result.cases += 1
        }
        return result
    }
}
