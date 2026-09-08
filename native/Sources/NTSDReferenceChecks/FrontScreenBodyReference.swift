import Foundation
import NTSDCore

public enum FrontScreenBodyReference {
    public struct Result {
        public var cases = 0, events = 0, helpers = 0, texts = 0, draws = 0, reads = 0, clips = 0, blits = 0, sounds = 0, shells = 0
        public var records = 0, bytes = 0, boundaries = 0
        public var parent = MenuPanelUpdateReference.Result()
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, storage: Storage }
    private struct Literal: Decodable { let address: UInt32, bytes: [UInt8] }
    private struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32?, result: UInt32? }
    private struct Case: Decodable {
        let label: String, stimulus: [InputControlReference.GlobalWrite], input: OriginalFrontScreenBodyInput, events: [OriginalFrontScreenEvent], helpers: [Helper], pending: [Helper]
        let continuation: OriginalFrontScreenBody.Continuation, endPC: UInt32, endSP: UInt32, globals: String, local: Storage, world: Storage, records: [Record]
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, initialGlobals: String, localAddress: UInt32, localBacking: String
        let literals: [Literal], links: [Literal], cases: [Case], blobs: [String:Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Front screen body reference: "+text) }
    public static func compare(_ data: Data) throws -> Result {
        let raw = try MatchPreparationReference.unpack(data,maximumCount: 128_000_000), c = try JSONDecoder().decode(Corpus.self,from: raw)
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",c.localAddress == 0x1000f000,!c.cases.isEmpty else { throw error("Source identity") }
        guard c.literals.count == OriginalFrontScreenBody.literals.count,c.links.count == OriginalFrontScreenBody.links.count else { throw error("Literal inventory") }
        for (actual,expected) in zip(OriginalFrontScreenBody.literals+OriginalFrontScreenBody.links,c.literals+c.links) {
            guard actual.address == expected.address,actual.bytes == expected.bytes else { throw error("Original literal "+String(expected.address,radix:16)) }
        }
        var result = Result(),blobs: [String:[UInt8]] = [:],recordCache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value }
            guard let b = c.blobs[key],b.sha256 == key else { throw error("Blob binding") }
            let value = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw error("Blob SHA") };blobs[key] = value;return value
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            if let value = recordCache[key] { return value }
            let bytes = try blob(key);guard bytes.count == OriginalMatchPreparation.globalSize else { throw error("Global extent") }
            let value = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count));recordCache[key] = value;return value
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let key = ref.bytes+ref.defined;if let value = recordCache[key] { return value }
            let bytes = try blob(ref.bytes),mask = try blob(ref.defined)
            guard bytes.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Storage mask") }
            let value = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 });recordCache[key] = value;return value
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            }
            result.records += 1;result.bytes += actual.bytes.count
        }
        guard let document = try JSONSerialization.jsonObject(with: raw) as? [String:Any],var parent = document["parent"] as? [String:Any] else { throw error("Parent document") }
        parent["blobs"] = document["blobs"]
        var ownWorld: OriginalStateRecord?,ownGlobals: OriginalStateRecord?,bitmaps: [UInt32:OriginalLoadedBitmap] = [:],surfaces: [UInt32:UInt32] = [:]
        result.parent = try MenuPanelUpdateReference.compare(JSONSerialization.data(withJSONObject: parent)) { world,state,resources in
            try check(state,globals(c.initialGlobals),"Own native panel parent");ownWorld = world;ownGlobals = state;bitmaps = resources
        }
        guard let world = ownWorld,var state = ownGlobals else { throw error("Missing native parent") }
        // Native constructors canonicalize only surface+0. Bind original raw
        // surface tokens from the declared parent constructor/device inputs.
        guard let prefix = parent["parent"] as? [String:Any],let settings = prefix["parent"] as? [String:Any],let front = settings["front"] as? [String:Any],
              let frontInputs = front["inputs"] as? [[String:Any]],let frontAllocations = front["allocations"] as? [[String:Any]],
              let prefixCases = prefix["cases"] as? [[String:Any]] else { throw error("Parent device inventory") }
        for input in frontInputs {
            guard let i = input["index"] as? Int,frontAllocations.indices.contains(i),let address = frontAllocations[i]["address"] as? UInt32,let surface = input["surface"] as? UInt32,
                  let key = input["colorKeyResult"] as? Int32 else { throw error("Parent device input") }
            surfaces[address] = key < 0 ? 0 : surface
        }
        for item in prefixCases {
            if let a = item["allocation"] as? [String:Any],let address = a["address"] as? UInt32,address != 0,
               let input = item["bitmapInput"] as? [String:Any],let surface = input["surface"] as? UInt32,let key = input["colorKeyResult"] as? Int32 { surfaces[address] = key < 0 ? 0 : surface }
        }
        guard surfaces.count == bitmaps.count else { throw error("All native resource surfaces") }
        var local = try OriginalStateRecord(bytes: blob(c.localBacking),defined: [Bool](repeating: false,count: 0xc0))
        let returns: [UInt32:Set<UInt32>] = [
            0x401290:[0x427257,0x42727d,0x4272a4,0x4272f3,0x4273ac,0x42745d],
            0x401a30:[0x427318,0x4273d1,0x427482,0x427556],
            0x43f010:[0x4274f7,0x42752b,0x427566,0x42759d,0x4275bc],
            0x43ef70:[0x43f212]
        ]
        for (i,item) in c.cases.enumerated() {
            guard i != 0 || item.stimulus.isEmpty else { throw error("Natural first entry") }
            for write in item.stimulus {
                let text = Array(write.bytes);guard text.count%2 == 0 else { throw error("Stimulus extent") }
                for j in stride(from: 0,to: text.count,by: 2) {
                    guard let byte = UInt8(String(text[j...j+1]),radix: 16) else { throw error("Stimulus byte") }
                    try state.write(byte,at: Int(write.address)-OriginalMatchPreparation.globalBase+j/2)
                }
            }
            var index = 0,blits = 0
            func event(_ e: OriginalFrontScreenEvent) throws {
                guard index < item.events.count,e == item.events[index] else { throw error("\(item.label) event\(index): \(e); expected \(index < item.events.count ? String(describing:item.events[index]) : "end")") }
                index += 1;result.events += 1
                switch e.kind {
                case "text":result.texts += 1
                case "draw":result.draws += 1
                case "read":result.reads += 1
                case "clip":result.clips += 1
                case "blit":result.blits += 1
                case "soundRequest":result.sounds += 1
                case "shell":result.shells += 1
                default:break
                }
            }
            let width = try state.integer(at: 0x44d78c-OriginalMatchPreparation.globalBase,as: Int32.self),height = try state.integer(at: 0x44d790-OriginalMatchPreparation.globalBase,as: Int32.self)
            guard !item.input.drawResults.isEmpty else { throw error("Draw responses") }
            let end = try OriginalFrontScreenBody.advance(globals: &state,local: &local,input: item.input,draw: { args in
                guard let bitmap = bitmaps[args[0]],let surface = surfaces[args[0]] else { throw error("Unbound native bitmap") }
                let input = OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],mirrored: args[5],
                    sourceSurface: surface,targetSurface: args[6],viewportWidth: width,viewportHeight: height)
                _ = try OriginalBitmapDrawing.draw(input,bitmap: bitmap.storage,observeRead: { r in
                    var e = OriginalFrontScreenEvent("read");e.read = r;try event(e)
                },observeClip: { c in
                    var e = OriginalFrontScreenEvent("clip");e.clip = c;try event(e)
                },perform: { b in
                    var e = OriginalFrontScreenEvent("blit");e.blit = b;try event(e)
                    defer { blits += 1 };return item.input.drawResults[blits%item.input.drawResults.count]
                })
            },observe: event)
            guard index == item.events.count,end == item.continuation else { throw error("Final continuation/events") }
            if end == .alternateDispatch { guard item.endPC == 0x4275cb,item.endSP == 0x1000f000,item.pending.isEmpty else { throw error("Final caller") } }
            else { guard end == .nullTextTarget,item.endPC == 0x401295,item.pending.last?.entry == 0x401290 else { throw error("Declared boundary") };result.boundaries += 1 }
            for helper in item.helpers {
                let pop: [UInt32:UInt32] = [0x401290:0,0x401a30:4,0x43f010:24,0x43ef70:0]
                guard helper.saved.count == 4,helper.pop == pop[helper.entry],helper.returnSP == helper.entrySP+4+helper.pop,helper.result != nil,returns[helper.entry]?.contains(helper.returnPC) == true else { throw error("Helper ABI "+String(helper.entry,radix:16)+" return "+String(helper.returnPC,radix:16)) }
                if helper.entry == 0x401290 { guard helper.result == UInt32(bitPattern: item.input.dcResult) else { throw error("Text GetDC return") } }
                result.helpers += 1
            }
            try check(state,globals(item.globals),item.label+" globals");try check(local,storage(item.local),item.label+" stack");try check(world,storage(item.world),item.label+" World")
            guard item.records.count == bitmaps.count else { throw error("Resource inventory") }
            for record in item.records {
                guard let actual = bitmaps[record.address],let surface = surfaces[record.address] else { throw error("Resource binding") }
                var expected = try storage(record.storage);guard try expected.integer(at: 0,as: UInt32.self) == surface else { throw error("Retained surface") }
                try expected.write(UInt32(surface == 0 ? 0 : 1),at: 0);try check(actual.storage,expected,item.label+" bitmap")
            }
            result.cases += 1
        }
        return result
    }
}
