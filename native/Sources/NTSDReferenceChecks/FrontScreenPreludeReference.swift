import Foundation
import NTSDCore

public enum FrontScreenPreludeReference {
    public struct Result {
        public var cases = 0, sources = 0, helpers = 0, events = 0, records = 0, bytes = 0
        public var fills = 0, constructors = 0, draws = 0, reads = 0, undefinedReads = 0, clips = 0, blits = 0, formats = 0, threads = 0, boundaries = 0
        public var parent = SettingsLoadingReference.Result()
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, storage: Storage }
    private struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    private struct Allocation: Decodable { let address: UInt32, backing: String? }
    private struct BitmapInput: Decodable { let resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32 }
    private struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32?, result: UInt32? }
    private struct Case: Decodable {
        let label: String, stimulus: [InputControlReference.GlobalWrite], input: OriginalFrontScreenInput, fillBacking: String
        let allocation: Allocation?, bitmapInput: BitmapInput?, events: [OriginalFrontScreenEvent], helpers: [Helper], pending: [Helper]
        let continuation: OriginalFrontScreenPrelude.Continuation, endPC: UInt32, endSP: UInt32, globals: String, world: Storage, records: [Record]
    }
    private struct Corpus: Decodable { let exeSHA256: String, dllSHA256: String, initialGlobals: String, sources: [Source], cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Front screen reference: "+text) }
    public static func compare(_ data: Data,
        onNatural: ((OriginalStateRecord,OriginalStateRecord,OriginalFrontMenuResources,OriginalFrontScreenPrelude) throws -> Void)? = nil) throws -> Result {
        let raw = try MatchPreparationReference.unpack(data,maximumCount: 128_000_000), c = try JSONDecoder().decode(Corpus.self,from: raw)
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d", !c.cases.isEmpty else { throw error("Source identity") }
        var result = Result(), blobs: [String:[UInt8]] = [:], globalsCache: [String:OriginalStateRecord] = [:], recordCache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let data = blobs[key] { return data }
            guard let b = c.blobs[key], b.sha256 == key else { throw error("Blob binding") }
            let data = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(data)) == key else { throw error("Blob SHA") };blobs[key] = data;return data
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            if let r = globalsCache[key] { return r }
            let bytes = try blob(key);guard bytes.count == OriginalMatchPreparation.globalSize else { throw error("Global extent") }
            let r = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count));globalsCache[key] = r;return r
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let key = ref.bytes+ref.defined
            if let r = recordCache[key] { return r }
            let bytes = try blob(ref.bytes), mask = try blob(ref.defined)
            guard mask.count == bytes.count, mask.allSatisfy({ $0 < 2 }) else { throw error("Storage mask") }
            let r = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 });recordCache[key] = r;return r
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
            let bytes = try blob(source.dib);guard bytes.count >= 40, sources[source.path] == nil else { throw error("DIB identity") }
            let r = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count))
            guard try r.integer(at: 4,as: Int32.self) == source.width, try r.integer(at: 8,as: Int32.self) == source.height else { throw error("DIB dimensions") }
            sources[source.path] = source
        }
        guard Set(sources.keys) == Set((1...13).map { "MENU_BACK\($0)" }) else { throw error("Background inventory") };result.sources = sources.count
        guard let document = try JSONSerialization.jsonObject(with: raw) as? [String:Any], var parent = document["parent"] as? [String:Any] else { throw error("Parent document") }
        parent["blobs"] = document["blobs"]
        var ownWorld: OriginalStateRecord?, ownGlobals: OriginalStateRecord?, ownResources: OriginalFrontMenuResources?
        result.parent = try SettingsLoadingReference.compare(JSONSerialization.data(withJSONObject: parent)) { world,state,resources in
            try check(state,globals(c.initialGlobals),"Native settings parent")
            ownWorld = world;ownGlobals = state;ownResources = resources
        }
        guard let world = ownWorld, var state = ownGlobals, let resources = ownResources else { throw error("Missing native parent") }
        var prefix = OriginalFrontScreenPrelude()
        let helperPops: [UInt32:UInt32] = [0x4237e0:0,0x43c450:0,0x415160:0,0x423840:0,0x43ee50:12,0x43f010:24,0x43ef70:0]
        for (index,item) in c.cases.enumerated() {
            guard index != 0 || item.stimulus.isEmpty && item.input.drawTarget == 0x28002020 else { throw error("First caller binding") }
            for write in item.stimulus {
                let hex = Array(write.bytes);guard hex.count%2 == 0 else { throw error("Stimulus extent") }
                for i in stride(from: 0,to: hex.count,by: 2) {
                    guard let byte = UInt8(String(hex[i...i+1]),radix: 16) else { throw error("Stimulus byte") }
                    try state.write(byte,at: Int(write.address)-OriginalMatchPreparation.globalBase+i/2)
                }
            }
            var eventIndex = 0, allocated = false, constructed = false
            let end = try prefix.advance(globals: &state,input: item.input,fillBacking: blob(item.fillBacking),allocate: {
                guard !allocated, let a = item.allocation else { throw error("Allocation order") };allocated = true
                guard resources.bitmaps[a.address] == nil else { throw error("Reused early resource") }
                if a.address == 0 { guard a.backing == nil else { throw error("Null backing") };return .init(address: 0,backing: []) }
                guard let backing = a.backing else { throw error("Missing backing") };return try .init(address: a.address,backing: blob(backing))
            },source: { path in
                guard !constructed, let input = item.bitmapInput, let source = sources[path], input.resource.path == path,
                      input.surface == (input.resource.present ? 0x28006400 : 0), input.resource.width == (input.resource.present ? source.width : nil),
                      input.resource.height == (input.resource.present ? source.height : nil) else { throw error("Constructor input") }
                constructed = true;return (input.resource,input.surface,input.colorKeyResult)
            },observe: { event in
                guard eventIndex < item.events.count, event == item.events[eventIndex] else { throw error("\(item.label) event\(eventIndex): \(event) vs \(item.events.indices.contains(eventIndex) ? String(describing:item.events[eventIndex]) : "none")") }
                eventIndex += 1;result.events += 1
                switch event.kind {
                case "fill":result.fills += 1
                case "construct":result.constructors += 1
                case "draw":result.draws += 1
                case "read":result.reads += 1;if event.read?.defined == false { result.undefinedReads += 1 }
                case "clip":result.clips += 1
                case "blit":result.blits += 1
                case "format":result.formats += 1
                case "createThread":result.threads += 1
                default:break
                }
            })
            guard end == item.continuation, eventIndex == item.events.count, allocated == (item.allocation != nil), constructed == (item.bitmapInput != nil),
                  item.records.count == resources.bitmaps.count+prefix.bitmaps.count else { throw error(item.label+" continuation/lifetime") }
            switch end {
            case .critical,.alternate:
                guard item.pending.isEmpty, item.endPC == (end == .critical ? 0x427127 : 0x4275cb), item.endSP == 0x1000f000 else { throw error("Caller continuation") }
            case .nullFillTarget:guard item.endPC == 0x4151b6, item.endSP == 0x1000ef64 else { throw error("Fill boundary") };result.boundaries += 1
            case .nullBitmap:guard item.endPC == 0x43f04b, item.endSP == 0x1000ef1c else { throw error("Bitmap boundary") };result.boundaries += 1
            case .nullDrawTarget:guard [0x43f12b,0x43f2e6].contains(item.endPC) else { throw error("Draw target boundary") };result.boundaries += 1
            }
            for call in item.helpers {
                guard helperPops[call.entry] == call.pop, call.returnSP == call.entrySP+4+call.pop, call.saved.count == 4, call.result != nil else { throw error("Actual helper return") }
                result.helpers += 1
            }
            try check(world,storage(item.world),item.label+" World");try check(state,globals(item.globals),item.label+" globals")
            for record in item.records {
                guard let actual = prefix.bitmaps[record.address] ?? resources.bitmaps[record.address] else { throw error("Retained bitmap") }
                var expected = try storage(record.storage)
                let surface = try expected.integer(at: 0,as: UInt32.self)
                if let binding = prefix.surfaces[record.address] { guard surface == binding else { throw error("Background surface binding") } }
                try expected.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                try check(actual.storage,expected,item.label+" bitmap")
            }
            if index == 0 { try onNatural?(world,state,resources,prefix) }
            result.cases += 1
        }
        return result
    }
}
