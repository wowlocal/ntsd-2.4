import Foundation
import NTSDCore

/// tools/oracle_front_control_settings.py corpus: the completion parent is
/// replayed by FrontMenuCompletionReference, then every selector-6 case runs
/// `OriginalFrontControlSettings`, the presentation tail and the after-state
/// comparison on the same own state. APPLICATION_FRONT_MENU_ITEMS_PLAN.md F2.
public enum FrontControlSettingsReference {
    public struct Result {
        public var cases = 0, events = 0, draws = 0, texts = 0, sounds = 0, keyStates = 0, formats = 0
        public var writes = 0, reloads = 0, reloadEvents = 0, releases = 0, links = 0, records = 0, bytes = 0
        public var parent = FrontMenuCompletionReference.Result()
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, live: Bool, storage: Storage }
    private struct Snapshot: Decodable { let globals: String, world: Storage, crtState: UInt32, pointers: [UInt8], records: [Record] }
    private struct Input: Decodable { let presentation: OriginalMenuPresentationInput, drawResults: [Int32] }
    private struct Reload: Decodable { let data: String, chunk: Int, closeResult: Int32, file: UInt32, scratch: UInt32 }
    private struct WriterEvent: Decodable { let kind: String, arguments: [UInt32], strings: [[UInt8]], format: String?, result: UInt32? }
    private struct Settings: Decodable {
        let capacity: Int, available: Bool, writeMode: String, failAt: Int, closeResult: Int32, backing: String
        let returnPC: UInt32, completed: Bool, continuation: String, result: UInt32?, events: [WriterEvent], globals: String
    }
    /// Reload events carry the settings-loading fields beside the front event.
    private struct Fields: Decodable { let kind: String, format: String?, before: Int?, position: Int?, eof: Bool?, result: UInt32? }
    private struct Case: Decodable {
        let label: String, entry: String, stimulus: [InputControlReference.GlobalWrite], input: Input
        let mainExit: String, mainAfter: Snapshot, mainEvents: Int, events: [OriginalFrontScreenEvent], after: Snapshot
        let keyStates: [UInt32], reload: Reload?, settings: [Settings]
    }
    private struct Corpus: Decodable { let exeSHA256: String, dllSHA256: String, cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Front control settings reference: "+text) }

    public static func compare(_ data: Data) throws -> Result {
        let raw = try MatchPreparationReference.unpack(data,maximumCount: 256_000_000),c = try JSONDecoder().decode(Corpus.self,from: raw)
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",!c.cases.isEmpty else { throw error("Source identity") }
        guard let document = try JSONSerialization.jsonObject(with: raw) as? [String:Any],var parent = document["parent"] as? [String:Any],
              let rawCases = document["cases"] as? [[String:Any]] else { throw error("Parent document") }
        parent["blobs"] = document["blobs"]
        var result = Result(),blobs: [String:[UInt8]] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = blobs[key] { return bytes };guard let b = c.blobs[key],b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") };blobs[key] = bytes;return bytes
        }
        func record(_ key: String) throws -> OriginalStateRecord { let b = try blob(key);return try .init(bytes: b,defined: [Bool](repeating: true,count: b.count)) }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let bytes = try blob(ref.bytes),mask = try blob(ref.defined)
            guard bytes.count == mask.count else { throw error("Storage mask") }
            return try .init(bytes: bytes,defined: mask.map { $0 != 0 })
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            };result.records += 1;result.bytes += actual.bytes.count
        }
        var own: (world: OriginalStateRecord,state: OriginalStateRecord,crt: OriginalCRTRandom,memory: OriginalMenuPresentationMemory)?
        result.parent = try FrontMenuCompletionReference.compare(JSONSerialization.data(withJSONObject: parent)) { world,state,crt,_,_,memory in
            own = (world,state,crt,memory)
        }
        guard var (world,state,crt,memory) = own else { throw error("Missing native parent") }
        func snapshot(_ s: Snapshot,_ label: String) throws {
            try check(state,record(s.globals),label+" globals");try check(world,storage(s.world),label+" World")
            guard crt.state == s.crtState,memory.replayPointers.bytes == s.pointers,s.records.count == memory.allocations.count else { throw error(label+" CRT/pointers/ownership") }
            for r in s.records {
                guard let allocation = memory.allocations[r.address],allocation.live == r.live else { throw error(label+" live allocation") }
                try check(allocation.storage,storage(r.storage),label+" bitmap")
            }
        }
        for (caseIndex,item) in c.cases.enumerated() {
            guard item.entry == "controls",item.mainExit == "present" else { throw error("Entry/exit") }
            let fields = try JSONDecoder().decode([Fields].self,from: JSONSerialization.data(withJSONObject: rawCases[caseIndex]["events"] ?? []))
            for write in item.stimulus {
                let bytes = Array(write.bytes);guard bytes.count%2 == 0 else { throw error("Stimulus extent") }
                for i in stride(from: 0,to: bytes.count,by: 2) {
                    guard let byte = UInt8(String(bytes[i...i+1]),radix: 16) else { throw error("Stimulus byte") }
                    try state.write(byte,at: Int(write.address)-OriginalMatchPreparation.globalBase+i/2)
                }
            }
            var index = 0,blits = 0,keyIndex = 0,settingsIndex = 0
            let width = try state.integer(at: 0x44d78c-OriginalMatchPreparation.globalBase,as: Int32.self)
            let height = try state.integer(at: 0x44d790-OriginalMatchPreparation.globalBase,as: Int32.self)
            let target = item.input.presentation.targetSurface
            func event(_ e: OriginalFrontScreenEvent) throws {
                guard index < item.events.count,e == item.events[index] else {
                    throw error("\(item.label) event\(index): \(e); expected \(index < item.events.count ? String(describing: item.events[index]) : "end")")
                }
                index += 1;result.events += 1
                switch e.kind {
                case "draw":result.draws += 1
                case "textOut":result.texts += 1
                case "soundRequest":result.sounds += 1
                case "keyState":result.keyStates += 1
                case "format":result.formats += 1
                case "free":result.releases += 1
                case "shell":result.links += 1
                default:break
                }
            }
            let drawMemory = memory.allocations
            func draw(_ args: [UInt32]) throws {
                guard let bitmap = drawMemory[args[0]],bitmap.live else { throw error("Unbound/dead bitmap draw") }
                let input = OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],
                    mirrored: args[5],sourceSurface: try bitmap.storage.integer(at: 0,as: UInt32.self),targetSurface: args[6],viewportWidth: width,viewportHeight: height)
                var drawing = bitmap.storage;try drawing.write(UInt32(input.sourceSurface == 0 ? 0 : 1),at: 0)
                _ = try OriginalBitmapDrawing.draw(input,bitmap: drawing,observeRead: { r in
                    var e = OriginalFrontScreenEvent("read");e.read = r;try event(e)
                },observeClip: { c in
                    var e = OriginalFrontScreenEvent("clip");e.clip = c;try event(e)
                },perform: { b in
                    var e = OriginalFrontScreenEvent("blit");e.blit = b;try event(e)
                    defer { blits += 1 };return item.input.drawResults[blits%item.input.drawResults.count]
                })
            }
            try OriginalFrontControlSettings.advance(globals: &state,memory: &memory,
                input: .init(target: target,dcResult: item.input.presentation.dcResult,dc: item.input.presentation.dc),
                draw: draw,keyState: { k in
                    guard k == 20,keyIndex < item.keyStates.count else { throw error("Excess GetKeyState") }
                    defer { keyIndex += 1 };return Int32(bitPattern: item.keyStates[keyIndex])
                },reload: { s in
                    guard let r = item.reload else { throw error("Undeclared reload") }
                    var scratch = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x1f4),defined: [Bool](repeating: false,count: 0x1f4))
                    let continuation = try OriginalSettingsLoading.loadAndContinueStartup(globals: &s,scratch: &scratch,translatedBytes: blob(r.data),
                        file: r.file,scratchAddress: r.scratch,closeResult: r.closeResult,flagClearValue: nil) { actual,_,_ in
                        switch actual.kind {
                        case .write,.settingsReturn:return
                        default:break
                        }
                        guard index < item.events.count,actual.kind.rawValue == fields[index].kind,actual.arguments == item.events[index].arguments else {
                            throw error("\(item.label) reload event\(index): \(actual)")
                        }
                        let f = fields[index]
                        if actual.kind == .open { guard item.events[index].strings == [Array("data\\control.txt".utf8),Array("r".utf8)] else { throw error("Reload open") } }
                        if actual.kind == .close { guard actual.arguments == [r.file,UInt32(bitPattern: r.closeResult)] else { throw error("Reload close") } }
                        if [.scan,.gets,.eof].contains(actual.kind) {
                            guard actual.format == f.format,actual.before == f.before,actual.position == f.position,actual.eof == f.eof,actual.result == f.result else {
                                throw error("\(item.label) reload fields\(index): \(actual) vs \(f)")
                            }
                        }
                        index += 1;result.events += 1;result.reloadEvents += 1
                    }
                    guard continuation == .ready else { throw error("Reload continuation") };result.reloads += 1
                },write: { s in
                    guard settingsIndex < item.settings.count else { throw error("Excess settings writer") };let w = item.settings[settingsIndex];settingsIndex += 1
                    guard w.returnPC == 0x4290a7,w.available,w.completed,w.continuation == "returned" else { throw error("Writer inputs") }
                    var output = try OriginalBufferedTextOutput(backing: blob(w.backing)),writerIndex = 0,writeIndex = 0
                    let value = try OriginalSettingsWriting.run(globals: &s,output: &output,available: w.available,write: { bytes in
                        defer { writeIndex += 1 }
                        if writeIndex != w.failAt { return Int32(bytes.count) }
                        guard w.writeMode == "error" else { throw error("Writer mode") };return -1
                    },close: { w.closeResult },observe: { actual,_,_ in
                        guard writerIndex < w.events.count else { throw error("Excess writer event") };let e = w.events[writerIndex];writerIndex += 1
                        guard actual.kind == e.kind,actual.arguments == e.arguments,actual.strings == e.strings,actual.format == e.format,actual.result == e.result else {
                            throw error("\(item.label) writer event\(writerIndex-1): \(actual) vs \(e)")
                        }
                    })
                    guard writerIndex == w.events.count,value.value == w.result else { throw error("Writer events/result") }
                    try check(s,record(w.globals),item.label+" writer globals");result.writes += 1;return value
                },observe: event)
            guard index == item.mainEvents,keyIndex == item.keyStates.count,settingsIndex == item.settings.count else { throw error(item.label+" events at presentation") }
            try snapshot(item.mainAfter,item.label+" presentation")
            try OriginalMenuPresentation.apply(.tail,input: item.input.presentation,world: &world,globals: &state,memory: &memory) { e in
                if e.kind == .bitmap { try event(.init("draw",e.arguments));try draw(e.arguments) }
                else { try event(.init(e.kind.rawValue,e.arguments,e.strings)) }
            }
            guard index == item.events.count else { throw error(item.label+" final events") }
            try snapshot(item.after,item.label+" return");result.cases += 1
        }
        return result
    }
}
