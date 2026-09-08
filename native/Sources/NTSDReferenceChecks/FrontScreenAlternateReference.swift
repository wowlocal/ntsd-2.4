import Foundation
import NTSDCore

public enum FrontScreenAlternateReference {
    public struct Result {
        public var cases = 0, helpers = 0, events = 0, draws = 0, reads = 0, clips = 0, blits = 0, fills = 0, sounds = 0, timers = 0, workers = 0
        public var settings = 0, settingsReturns = 0, settingsEvents = 0, prints = 0, fileWrites = 0, failedWrites = 0, boundaries = 0, records = 0, bytes = 0
        public var parent = FrontScreenBodyReference.Result()
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, storage: Storage }
    private struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32?, result: UInt32? }
    private struct Fill: Decodable { let backing: String, address: UInt32 }
    private struct WriterEvent: Decodable {
        let kind: String, arguments: [UInt32], strings: [[UInt8]], format: String?, result: UInt32?, returnPC: UInt32?
        let globals: String?, file: String?, buffer: Storage?
    }
    private struct Settings: Decodable {
        let capacity: Int, available: Bool, writeMode: String, failAt: Int, closeResult: Int32, backing: String
        let entrySP: UInt32, returnPC: UInt32, saved: [UInt32], completed: Bool, continuation: String, endPC: UInt32, endSP: UInt32, result: UInt32?
        let events: [WriterEvent], globals: String, file: String, buffer: Storage
    }
    private struct Case: Decodable {
        let label: String, stimulus: [InputControlReference.GlobalWrite], input: OriginalFrontScreenAlternateInput, events: [OriginalFrontScreenEvent], helpers: [Helper], pending: [Helper]
        let settings: [Settings], fills: [Fill], continuation: OriginalFrontScreenAlternate.Continuation, endPC: UInt32, endSP: UInt32, globals: String, local: Storage, world: Storage, records: [Record]
    }
    private struct Corpus: Decodable { let exeSHA256: String, dllSHA256: String, initialGlobals: String, initialLocal: Storage, cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Front screen alternate reference: "+text) }
    public static func compare(_ data: Data) throws -> Result {
        let raw = try MatchPreparationReference.unpack(data,maximumCount: 128_000_000),c = try JSONDecoder().decode(Corpus.self,from: raw)
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",!c.cases.isEmpty else { throw error("Source identity") }
        var result = Result(),blobs: [String:[UInt8]] = [:],cache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value }
            guard let b = c.blobs[key],b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") };blobs[key] = bytes;return bytes
        }
        func defined(_ key: String,_ size: Int) throws -> OriginalStateRecord {
            if let value = cache[key] { guard value.bytes.count == size else { throw error("Cached extent") };return value }
            let bytes = try blob(key);guard bytes.count == size else { throw error("Defined extent") }
            let value = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: size));cache[key] = value;return value
        }
        func globals(_ key: String) throws -> OriginalStateRecord { try defined(key,OriginalMatchPreparation.globalSize) }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let key = ref.bytes+ref.defined;if let value = cache[key] { return value }
            let bytes = try blob(ref.bytes),mask = try blob(ref.defined)
            guard bytes.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Storage extent/mask") }
            let value = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 });cache[key] = value;return value
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
        var ownWorld: OriginalStateRecord?,ownGlobals: OriginalStateRecord?,ownLocal: OriginalStateRecord?,bitmaps: [UInt32:OriginalLoadedBitmap] = [:],surfaces: [UInt32:UInt32] = [:]
        result.parent = try FrontScreenBodyReference.compare(JSONSerialization.data(withJSONObject: parent)) { world,state,local,resources,tokens in
            try check(state,globals(c.initialGlobals),"Own native body globals");try check(local,storage(c.initialLocal),"Own native body stack")
            ownWorld = world;ownGlobals = state;ownLocal = local;bitmaps = resources;surfaces = tokens
        }
        guard let world = ownWorld,var state = ownGlobals,let local = ownLocal else { throw error("Missing native parent") }
        // The caller supplied this stack word before the body observation began.
        // Its raw token is an input; reading it must not invent a defined mask.
        let drawTarget = local.bytes[0x20..<0x24].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
        let returns: [UInt32:Set<UInt32>] = [0x401a30:[0x4276a4,0x427720,0x427798,0x4278f5],0x415160:[0x427884],0x423230:[0x42768d,0x427709],
            0x4237e0:[0x4276a9],0x43c450:[0x4276a9],0x43ef70:[0x43f212],0x43f010:[0x427616,0x42762b,0x42766c,0x4276e8,0x42776d,0x4277b8,0x4277d6,0x4277ee,0x427817,0x4278d9]]
        for (caseIndex,item) in c.cases.enumerated() {
            if caseIndex == 0 {
                guard item.stimulus.isEmpty,item.input.selector == (try state.integer(at: 0x44d064-OriginalMatchPreparation.globalBase,as: Int32.self)),item.input.selector == 0 else { throw error("Natural first dispatch") }
            }
            guard item.input.drawTarget == drawTarget,!item.input.drawResults.isEmpty else { throw error("Caller/device inputs") }
            for write in item.stimulus {
                let text = Array(write.bytes);guard text.count%2 == 0 else { throw error("Stimulus extent") }
                for j in stride(from: 0,to: text.count,by: 2) {
                    guard let byte = UInt8(String(text[j...j+1]),radix: 16) else { throw error("Stimulus byte") }
                    try state.write(byte,at: Int(write.address)-OriginalMatchPreparation.globalBase+j/2)
                }
            }
            var eventIndex = 0,blits = 0,fillIndex = 0,settingsIndex = 0
            func event(_ e: OriginalFrontScreenEvent) throws {
                guard eventIndex < item.events.count,e == item.events[eventIndex] else { throw error("\(item.label) event\(eventIndex): \(e); expected \(eventIndex < item.events.count ? String(describing:item.events[eventIndex]) : "end")") }
                eventIndex += 1;result.events += 1
                switch e.kind {
                case "draw":result.draws += 1
                case "read":result.reads += 1
                case "clip":result.clips += 1
                case "blit":result.blits += 1
                case "fill":result.fills += 1
                case "soundRequest":result.sounds += 1
                case "timer":result.timers += 1
                case "createThread":result.workers += 1
                default:break
                }
            }
            let width = try state.integer(at: 0x44d78c-OriginalMatchPreparation.globalBase,as: Int32.self),height = try state.integer(at: 0x44d790-OriginalMatchPreparation.globalBase,as: Int32.self)
            let end = try OriginalFrontScreenAlternate.advance(globals: &state,input: item.input,draw: { args in
                guard let bitmap = bitmaps[args[0]],let surface = surfaces[args[0]] else { throw error("Unbound native bitmap") }
                let draw = OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],mirrored: args[5],
                    sourceSurface: surface,targetSurface: args[6],viewportWidth: width,viewportHeight: height)
                _ = try OriginalBitmapDrawing.draw(draw,bitmap: bitmap.storage,observeRead: { r in
                    var e = OriginalFrontScreenEvent("read");e.read = r;try event(e)
                },observeClip: { c in
                    var e = OriginalFrontScreenEvent("clip");e.clip = c;try event(e)
                },perform: { b in
                    var e = OriginalFrontScreenEvent("blit");e.blit = b;try event(e)
                    defer { blits += 1 };return item.input.drawResults[blits%item.input.drawResults.count]
                })
            },fill: { args in
                guard fillIndex < item.fills.count else { throw error("Excess fill") };let f = item.fills[fillIndex];fillIndex += 1
                guard f.address == 0x1000ef84 else { throw error("Actual fill stack") }
                var e = OriginalFrontScreenEvent("fill")
                e.fill = try OriginalSurfaceFilling.request(target: args[0],x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),width: Int32(bitPattern: args[3]),height: Int32(bitPattern: args[4]),color: args[5],backing: blob(f.backing));try event(e)
            },writeSettings: { childState in
                guard settingsIndex < item.settings.count else { throw error("Excess settings child") };let s = item.settings[settingsIndex];settingsIndex += 1
                guard [1,7,64,4096].contains(s.capacity),["full","error","zero","short"].contains(s.writeMode),s.entrySP == 0x1000effc,[0x42768d,0x427709].contains(s.returnPC),s.saved.count == 4 else { throw error("Settings child inputs") }
                var output = try OriginalBufferedTextOutput(backing: blob(s.backing)),index = 0,writeIndex = 0
                guard output.buffer.bytes.count == s.capacity else { throw error("Settings buffer input") }
                let value = try OriginalSettingsWriting.run(globals: &childState,output: &output,available: s.available,write: { bytes in
                    defer { writeIndex += 1 };result.fileWrites += 1
                    if writeIndex != s.failAt { return Int32(bytes.count) };result.failedWrites += 1
                    switch s.writeMode { case "error":return -1;case "zero":return 0;case "short":return Int32(bytes.count)-1;default:throw error("Invalid failing write") }
                },close: { s.closeResult },observe: { actual,state,stream in
                    guard index < s.events.count else { throw error("Excess writer event") };let e = s.events[index];index += 1
                    guard actual.kind == e.kind,actual.arguments == e.arguments,actual.strings == e.strings,actual.format == e.format,actual.result == e.result else { throw error("\(item.label) writer event\(index-1): \(actual) vs \(e)") }
                    if let key = e.globals { try check(state,globals(key),item.label+" child globals") }
                    if let key = e.file { try check(stream.fileStorage(),defined(key,32),item.label+" child FILE") }
                    if let ref = e.buffer { try check(stream.buffer,storage(ref),item.label+" child buffer") }
                    if actual.kind == "print" {
                        guard [0x423266,0x42327d,0x423345,0x4233ea,0x4233f8,0x423405,0x423412,0x42341f].contains(e.returnPC) else { throw error("Print return") };result.prints += 1
                    }
                    if actual.kind == "close" { guard e.returnPC == 0x423426 else { throw error("Close return") } }
                    result.settingsEvents += 1
                })
                guard index == s.events.count,value.value == s.result else { throw error("Settings events/result") }
                switch value {
                case .returned:guard s.completed,s.continuation == "returned",s.endPC == s.returnPC,s.endSP == s.entrySP+4 else { throw error("Settings return") };result.settingsReturns += 1
                case .nullFile:guard !s.completed,s.continuation == "nullFile",s.endPC == 0x423260,s.endSP == 0x1000efdc else { throw error("Settings FILE boundary") }
                case .unterminatedName(let pc):guard !s.completed,s.continuation == "unterminatedName",s.endPC == pc else { throw error("Settings string boundary") }
                }
                try check(childState,globals(s.globals),item.label+" settings globals");try check(output.fileStorage(),defined(s.file,32),item.label+" settings FILE");try check(output.buffer,storage(s.buffer),item.label+" settings buffer")
                result.settings += 1;return value
            },observe: event)
            guard end == item.continuation,eventIndex == item.events.count,settingsIndex == item.settings.count,fillIndex+(end == .nullFillTarget ? 1 : 0) == item.fills.count else { throw error(item.label+" final continuation/events") }
            switch end {
            case .presentation,.mainMenu,.otherSelector:
                let pc: UInt32 = end == .presentation ? 0x42873e : end == .mainMenu ? 0x427915 : 0x427ca7
                guard item.endPC == pc,item.endSP == 0x1000f000,item.pending.isEmpty else { throw error("Caller continuation") }
            case .nullBitmap:guard item.endPC == 0x43f04b,item.endSP == 0x1000ef1c,item.pending.last?.entry == 0x43f010 else { throw error("Null bitmap") };result.boundaries += 1
            case .nullFillTarget:guard item.endPC == 0x4151b6,item.endSP == 0x1000ef64,item.pending.last?.entry == 0x415160 else { throw error("Null fill") };result.boundaries += 1
            case .nullSettingsFile:guard item.endPC == 0x423260,item.endSP == 0x1000efdc,item.pending.last?.entry == 0x423230 else { throw error("Null settings FILE") };result.boundaries += 1
            default:throw error("Unprobed continuation")
            }
            for helper in item.helpers {
                let pop: UInt32 = helper.entry == 0x43f010 ? 24 : helper.entry == 0x401a30 ? 4 : 0
                guard helper.saved.count == 4,helper.pop == pop,helper.returnSP == helper.entrySP+4+pop,helper.result != nil,returns[helper.entry]?.contains(helper.returnPC) == true else { throw error("Helper ABI") }
                if helper.entry == 0x415160 { guard helper.result == UInt32(bitPattern: item.input.fillResult) else { throw error("Fill HRESULT") } }
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
