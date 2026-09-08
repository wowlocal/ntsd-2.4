import Foundation
import NTSDCore

public enum FrontMenuResourcesReference {
    public struct Result {
        public var cases = 0, sources = 0, allocations = 0, constructors = 0, nullAllocations = 0
        public var events = 0, writes = 0, settings = 0, skipped = 0, nullBitmaps = 0, records = 0, bytes = 0
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, storage: Storage }
    private struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    private struct Allocation: Decodable { let address: UInt32, backing: String? }
    private struct Input: Decodable { let index: Int, resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32 }
    private struct Call: Decodable { let index: Int, address: UInt32, entrySP: UInt32, returnAddress: UInt32, saved: [UInt32], returnSP: UInt32 }
    private struct Case: Decodable {
        let label: String, stimulus: [InputControlReference.GlobalWrite], selector: Int32?
        let allocations: [Allocation], inputs: [Input], calls: [Call], events: [OriginalFrontMenuEvent]
        let continuation: OriginalFrontMenuResourceResult.Continuation, nullBitmapSlot: Int?, endPC: UInt32, endSP: UInt32
        let globals: String, world: Storage, records: [Record]
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, control: Bool, worldBacking: String, initialWorld: Storage, initialGlobals: String
        let sources: [Source], cases: [Case], blobs: [String:Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Front menu resources reference: "+text) }
    private static func hex(_ text: String) throws -> [UInt8] {
        let bytes = Array(text.utf8);guard bytes.count%2 == 0 else { throw error("Hex extent") }
        func digit(_ x: UInt8) throws -> UInt8 { switch x { case 48...57:return x-48;case 97...102:return x-87;default:throw error("Hex digit") } }
        return try stride(from: 0,to: bytes.count,by: 2).map { try digit(bytes[$0])*16+digit(bytes[$0+1]) }
    }
    public static func compare(_ data: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(data,maximumCount: 256_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c", !c.cases.isEmpty,
              Set(c.sources.map(\.path)) == Set(OriginalFrontMenuResources.paths), c.sources.count == 23 else { throw error("Source identity") }
        var result = Result(), blobs: [String:[UInt8]] = [:], normalized: [String:OriginalStateRecord] = [:], surfaces: [String:UInt32] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = blobs[key] { return bytes }
            guard let b = c.blobs[key], b.sha256 == key else { throw error("Blob identity") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") }
            blobs[key] = bytes;return bytes
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let bytes = try blob(ref.bytes), mask = try blob(ref.defined)
            guard bytes.count == mask.count, mask.allSatisfy({ $0 < 2 }) else { throw error("Record mask") }
            return try .init(bytes: bytes,defined: mask.map { $0 == 1 })
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            if let record = normalized[key] { return record }
            let bytes = try blob(key);guard bytes.count == OriginalMatchPreparation.globalSize else { throw error("Global extent") }
            let record = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count));normalized[key] = record;return record
        }
        func same<T>(_ a: [T], _ b: [T]) -> Bool {
            guard a.count == b.count else { return false }
            return a.withUnsafeBytes { x in b.withUnsafeBytes { y in x.isEmpty || memcmp(x.baseAddress!,y.baseAddress!,x.count) == 0 } }
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard same(actual.bytes,expected.bytes), same(actual.defined,expected.defined) || actual.defined == expected.defined else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error("\(label) storage+\(i.map { String($0,radix:16) } ?? "extent")")
            }
            result.records += 1;result.bytes += actual.bytes.count
        }
        var sourceByPath: [String:Source] = [:], inputByAddress: [UInt32:Input] = [:]
        for source in c.sources {
            let bytes = try blob(source.dib);guard bytes.count >= 40 else { throw error("DIB extent") }
            let record = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count))
            guard try record.integer(at: 0,as: UInt32.self) >= 40, try record.integer(at: 4,as: Int32.self) == source.width,
                  try record.integer(at: 8,as: Int32.self) == source.height else { throw error("DIB dimensions") }
            sourceByPath[source.path] = source;result.sources += 1
        }
        var world = try OriginalStateRecord.worldPrefix(over: blob(c.worldBacking)), state = try globals(c.initialGlobals), loader = OriginalFrontMenuResources()
        try check(world,storage(c.initialWorld),"World constructor")
        let returns: [UInt32] = [0x4247a5,0x42482c,0x42486b,0x4248aa,0x4248e9,0x424928,0x424967,0x4249a6,0x4249e5,0x424a24,0x424a63,
                                  0x426bc2,0x426c05,0x426c44,0x426c86,0x426cc1,0x426d00,0x426d3f,0x426d7e,0x426db9,0x426df8,0x426e37,0x426e76,0x426eb5]
        let nullPC: [Int:UInt32] = [0x45119c:0x424a72,0x451190:0x424b45,0x4511a0:0x424ca4,0x451168:0x4251fd,0x451178:0x4252e5,
            0x45116c:0x425e65,0x45117c:0x4263f2,0x4511a4:0x42669f,0x451188:0x426866,0x44faf4:0x426ec9,0x44f888:0x426ed2,
            0x44fcbc:0x426edb,0x44fb68:0x426ee4,0x44faf8:0x426eed,0x44fd80:0x426ef8]
        for (caseIndex,item) in c.cases.enumerated() {
            guard caseIndex != 0 || item.stimulus.isEmpty && item.selector == nil, item.endSP == 0x1000f000,
                  [0,11,24].contains(item.allocations.count) else { throw error("Caller provenance") }
            for w in item.stimulus { for (i,b) in try hex(w.bytes).enumerated() { try state.write(b,at: Int(w.address)-OriginalMatchPreparation.globalBase+i) } }
            if let selector = item.selector { try world.write(selector,at: 0) }
            let inputs = Dictionary(uniqueKeysWithValues: item.inputs.map { ($0.index,$0) })
            guard inputs.count == item.calls.count else { throw error("Constructor count") }
            var allocationIndex = 0, eventIndex = 0
            let end = try loader.load(world: world,globals: &state,allocate: { index in
                guard index == allocationIndex, index < item.allocations.count else { throw error("Allocation order") }
                let a = item.allocations[index];allocationIndex += 1;result.allocations += 1
                if a.address == 0 {
                    guard a.backing == nil, inputs[index] == nil else { throw error("Null allocation") }
                    result.nullAllocations += 1;return .init(address: 0,backing: [])
                }
                guard let backing = a.backing, let input = inputs[index], inputByAddress[a.address] == nil else { throw error("Allocation provenance") }
                inputByAddress[a.address] = input;return try .init(address: a.address,backing: blob(backing))
            },source: { index,path in
                guard let input = inputs[index], let source = sourceByPath[path], input.resource.path == path,
                      input.resource.present == (input.surface != 0), input.resource.width == (input.surface == 0 ? nil : source.width),
                      input.resource.height == (input.surface == 0 ? nil : source.height) else { throw error("DIB/device input") }
                return input.resource
            },deviceResult: { index in
                guard let input = inputs[index] else { throw error("Device response") };return (input.surface,input.colorKeyResult)
            },observe: { event in
                guard eventIndex < item.events.count, event == item.events[eventIndex] else { throw error("\(item.label) event\(eventIndex): \(event)") }
                eventIndex += 1;result.events += 1;if event.kind == .write { result.writes += 1 }
            })
            guard end.continuation == item.continuation, end.nullBitmapSlot == item.nullBitmapSlot,
                  allocationIndex == item.allocations.count, eventIndex == item.events.count, loader.bitmaps.count == item.records.count else { throw error(item.label+" continuation/lifetime") }
            switch end.continuation {
            case .settings:guard item.endPC == 0x427089 else { throw error("Settings boundary") };result.settings += 1
            case .ready:guard item.endPC == 0x42709b else { throw error("Skip boundary") };result.skipped += 1
            case .nullBitmap:guard let slot = end.nullBitmapSlot, nullPC[slot] == item.endPC else { throw error("Null bitmap boundary") };result.nullBitmaps += 1
            }
            for call in item.calls {
                guard (0..<24).contains(call.index), call.address == item.allocations[call.index].address, call.returnAddress == returns[call.index],
                      call.entrySP == 0x1000eff0, call.returnSP == 0x1000f000, call.saved.count == 4 else { throw error("Constructor ret12") }
                result.constructors += 1
            }
            try check(world,storage(item.world),item.label+" World")
            try check(state,globals(item.globals),item.label+" globals")
            for record in item.records {
                guard let actual = loader.bitmaps[record.address], let input = inputByAddress[record.address], actual.input == input.resource, !actual.optional else { throw error("Retained bitmap input") }
                let key = record.storage.bytes+record.storage.defined
                let expected: OriginalStateRecord
                if let cached = normalized[key] { expected = cached }
                else {
                    var value = try storage(record.storage);guard value.bytes.count == 0x1f50 else { throw error("Bitmap extent") }
                    let surface = try value.integer(at: 0,as: UInt32.self);surfaces[key] = surface
                    try value.write(UInt32(surface == 0 ? 0 : 1),at: 0);expected = value;normalized[key] = value
                }
                guard surfaces[key] == 0 || surfaces[key] == input.surface else { throw error("Surface normalization") }
                try check(actual.storage,expected,item.label+" bitmap")
            }
            result.cases += 1
        }
        return result
    }
}
