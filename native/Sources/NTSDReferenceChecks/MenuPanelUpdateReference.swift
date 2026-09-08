import Foundation
import NTSDCore

public enum MenuPanelUpdateReference {
    public struct Result {
        public var cases = 0, events = 0, childEvents = 0, content = 0, bitmaps = 0, defaults = 0, caches = 0
        public var constructors = 0, destructors = 0, returns = 0, boundaries = 0, records = 0, bytes = 0
        public var parent = FrontScreenPreludeReference.Result()
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, storage: Storage }
    private struct PanelRecord: Decodable { let address: UInt32, live: Bool, storage: Storage }
    private struct Allocation: Decodable { let address: UInt32, backing: String? }
    private struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    private struct Event: Decodable {
        let kind: String, arguments: [UInt32]?, strings: [[UInt8]]?, format: String?, result: UInt32?, before: Int?, position: Int?, eof: Bool?, returnPC: UInt32?
        let globals: String?, scratch: Storage?, file: String?, buffer: Storage?
    }
    private struct Helper: Decodable { let entry: UInt32, address: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32, result: UInt32 }
    private struct Child: Decodable {
        let kind: String, entry: UInt32, entrySP: UInt32, returnPC: UInt32, saved: [UInt32], completed: Bool, endPC: UInt32, endSP: UInt32, result: UInt32?
        let events: [Event], globals: String, input: String?, localAddress: UInt32?, backing: String?, index: Int32?, chunk: Int?, closeResult: Int32?
        let source: String?, surface: UInt32?, colorKeyResult: Int32?, releaseResult: UInt32?, allocation: Allocation?, resource: OriginalBitmapInput?, calls: [Helper]?, records: [PanelRecord]?
        let capacity: Int?, available: Bool?, writeMode: String?, failAt: Int?, scratch: Storage?, file: String?, buffer: Storage?
    }
    private struct Case: Decodable {
        let label: String, stimulus: [InputControlReference.GlobalWrite], events: [OriginalMenuPanelUpdateEvent], children: [Child]
        let continuation: String, endPC: UInt32, endSP: UInt32, globals: String, world: Storage, records: [Record], panelRecords: [PanelRecord]
    }
    private struct Corpus: Decodable { let exeSHA256: String, dllSHA256: String, initialGlobals: String, absentOriginalFiles: [String], sources: [Source], cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Panel update reference: "+text) }
    public static func compare(_ data: Data) throws -> Result {
        let raw = try MatchPreparationReference.unpack(data,maximumCount: 128_000_000),c = try JSONDecoder().decode(Corpus.self,from: raw)
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d", !c.cases.isEmpty,
              c.absentOriginalFiles == ["data/ad0.txt","data/ad1.txt","sprite/sys/ad0.bmp","sprite/sys/ad1.bmp"] else { throw error("Source identity") }
        var result = Result(),blobs: [String:[UInt8]] = [:],stateCache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value }
            guard let b = c.blobs[key],b.sha256 == key else { throw error("Blob binding") }
            let value = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw error("Blob SHA") };blobs[key] = value;return value
        }
        func defined(_ key: String,_ size: Int) throws -> OriginalStateRecord {
            if let value = stateCache[key] { guard value.bytes.count == size else { throw error("Cached extent") };return value }
            let bytes = try blob(key);guard bytes.count == size else { throw error("Record extent") }
            let value = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: size));stateCache[key] = value;return value
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let key = ref.bytes+ref.defined;if let value = stateCache[key] { return value }
            let bytes = try blob(ref.bytes),mask = try blob(ref.defined)
            guard bytes.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Storage mask") }
            let value = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 });stateCache[key] = value;return value
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            }
            result.records += 1;result.bytes += actual.bytes.count
        }
        func globals(_ key: String) throws -> OriginalStateRecord { try defined(key,OriginalMatchPreparation.globalSize) }
        var sources: [String:Source] = [:]
        for source in c.sources {
            let bytes = try blob(source.dib);guard bytes.count >= 40 else { throw error("DIB extent") }
            let r = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count))
            guard try r.integer(at: 4,as: Int32.self) == source.width,try r.integer(at: 8,as: Int32.self) == source.height else { throw error("DIB dimensions") }
            sources[source.path] = source
        }
        guard sources.count == 1,sources["MENU_BACK1"] != nil else { throw error("Declared bitmap control source") }
        guard let document = try JSONSerialization.jsonObject(with: raw) as? [String:Any],var parent = document["parent"] as? [String:Any] else { throw error("Parent document") }
        parent["blobs"] = document["blobs"]
        var ownWorld: OriginalStateRecord?,ownGlobals: OriginalStateRecord?,early: [UInt32:OriginalLoadedBitmap] = [:]
        result.parent = try FrontScreenPreludeReference.compare(JSONSerialization.data(withJSONObject: parent)) { world,state,resources,prefix in
            try check(state,globals(c.initialGlobals),"Own native screen parent")
            ownWorld = world;ownGlobals = state;early = resources.bitmaps
            for (address,bitmap) in prefix.bitmaps {
                guard early[address] == nil else { throw error("Duplicate parent allocation") };early[address] = bitmap
            }
        }
        guard let world = ownWorld,var state = ownGlobals else { throw error("Missing native parent") }
        var panel = OriginalMenuPanelBitmap(),panelInputs: [OriginalBitmapInput] = []
        func panelRecords(_ expected: [PanelRecord],_ label: String) throws {
            guard expected.count == panel.records.count,panelInputs.count == expected.count else { throw error(label+" panel generations") }
            for (i,record) in expected.enumerated() {
                let actual = panel.records[i];var value = try storage(record.storage)
                let surface = try value.integer(at: 0,as: UInt32.self)
                guard actual.address == record.address,actual.live == record.live,actual.surface == surface,actual.bitmap.input == panelInputs[i],!actual.bitmap.optional else { throw error(label+" generation binding") }
                try value.write(UInt32(surface == 0 ? 0 : 1),at: 0);try check(actual.bitmap.storage,value,label+" bitmap")
            }
        }
        let crtReturns: Set<UInt32> = [0x43c7ae,0x43c7c1,0x43c7fa,0x43c8a4,0x43c9b9,0x43ca8d,0x43cb2d,0x43cbe7,0x43c81d,0x43c8d1,0x43c9de,0x43cab6,0x43cb50,0x43cbfb,
            0x43c6f2,0x43c704,0x43c729,0x43c73c,0x43c6b6,0x43c773,0x43c6bd,0x43c77a]
        func event(_ kind: String,_ args: [UInt32],_ strings: [[UInt8]],format: String? = nil,value: UInt32? = nil,before: Int? = nil,position: Int? = nil,eof: Bool? = nil,
            child: Child,index: inout Int,state: OriginalStateRecord?,scratch: OriginalStateRecord? = nil,output: OriginalBufferedTextOutput? = nil) throws {
            guard index < child.events.count else { throw error(child.kind+" excess event") };let e = child.events[index];index += 1
            guard kind == e.kind,args == (e.arguments ?? []),strings == (e.strings ?? []),format == e.format,value == e.result,before == e.before,position == e.position,eof == e.eof else {
                throw error("\(child.kind) event\(index-1): \(kind) \(args) \(strings) result\(String(describing: value)) vs \(e)")
            }
            if let pc = e.returnPC { guard crtReturns.contains(pc) else { throw error("CRT return site") } }
            if let key = e.globals { guard let state else { throw error("Missing event globals") };try check(state,globals(key),child.kind+" "+kind+" globals") }
            if let ref = e.scratch { guard let scratch else { throw error("Missing local state") };try check(scratch,storage(ref),child.kind+" locals") }
            if let key = e.file { guard let output else { throw error("Missing FILE state") };try check(output.fileStorage(),defined(key,32),child.kind+" FILE") }
            if let ref = e.buffer { guard let output else { throw error("Missing buffer state") };try check(output.buffer,storage(ref),child.kind+" buffer") }
            result.childEvents += 1
        }
        func finish(_ child: Child,_ count: Int,_ value: UInt32?,_ state: OriginalStateRecord,scratch: OriginalStateRecord? = nil,output: OriginalBufferedTextOutput? = nil) throws {
            guard count == child.events.count,child.result == value else { throw error(child.kind+" child result/events") }
            if child.completed {
                guard child.endPC == child.returnPC,child.endSP == child.entrySP+4,value != nil else { throw error("Child outer ABI") };result.returns += 1
            } else { guard child.kind == "content",value == nil else { throw error("Pending child") } }
            try check(state,globals(child.globals),child.kind+" final globals")
            if let ref = child.scratch { guard let scratch else { throw error("Final scratch") };try check(scratch,storage(ref),"Final local state") }
            if let key = child.file { guard let output else { throw error("Final FILE") };try check(output.fileStorage(),defined(key,32),"Final FILE") }
            if let ref = child.buffer { guard let output else { throw error("Final buffer") };try check(output.buffer,storage(ref),"Final buffer") }
        }
        for (i,item) in c.cases.enumerated() {
            guard i != 0 || item.stimulus.isEmpty && item.children.isEmpty else { throw error("Natural first caller") }
            for write in item.stimulus {
                let text = Array(write.bytes);guard text.count%2 == 0 else { throw error("Stimulus extent") }
                for j in stride(from: 0,to: text.count,by: 2) {
                    guard let byte = UInt8(String(text[j...j+1]),radix: 16) else { throw error("Stimulus byte") }
                    try state.write(byte,at: Int(write.address)-OriginalMatchPreparation.globalBase+j/2)
                }
            }
            var childIndex = 0,parentIndex = 0
            func next(_ kind: String) throws -> Child {
                guard childIndex < item.children.count else { throw error(item.label+" excess child") }
                let child = item.children[childIndex];childIndex += 1
                let returns: [String:Set<UInt32>] = ["content":[0x423726,0x42374d,0x42379a],"bitmap":[0x423775,0x423756],"defaults":[0x42375f],"cache":[0x423764,0x4237c8]]
                guard child.kind == kind,child.entrySP == 0x1000eff8,child.saved.count == 4,returns[kind]?.contains(child.returnPC) == true else { throw error(item.label+" Child caller") }
                return child
            }
            let end = try OriginalMenuPanelUpdate.run(globals: &state,content: { state in
                let child = try next("content");result.content += 1
                guard child.entry == 0x43c780,let backing = child.backing,child.localAddress == child.entrySP-0x454,
                      [1,7,4096].contains(child.chunk),child.index == (try state.integer(at: 0x44d784-OriginalMatchPreparation.globalBase,as: Int32.self)),let close = child.closeResult else { throw error("Content input") }
                var local = try OriginalStateRecord(bytes: blob(backing),defined: [Bool](repeating: false,count: 0x450)),n = 0
                let value = try OriginalMenuContent.load(globals: &state,local: &local,translatedBytes: child.input.map(blob),closeResult: close) { e,s,l in
                    try event(e.kind,e.arguments,e.strings,format: e.format,value: e.result,before: e.before,position: e.position,eof: e.eof,child: child,index: &n,state: s,scratch: l)
                }
                if let call = value.boundaryCall { guard !child.completed,child.endPC == call else { throw error("Content boundary") } }
                try finish(child,n,value.value,state,scratch: local);return value
            },bitmap: { state in
                let child = try next("bitmap");result.bitmaps += 1
                guard child.entry == 0x43cc60,let a = child.allocation,let surface = child.surface,let key = child.colorKeyResult,let sourceName = child.source,let source = sources[sourceName],let calls = child.calls,let records = child.records else { throw error("Bitmap input") }
                var n = 0,allocations = 0,loads = 0
                let value = try panel.load(globals: &state,allocate: {
                    allocations += 1;guard early[a.address] == nil else { throw error("Reused early resource") }
                    if a.address == 0 { guard a.backing == nil,child.resource == nil else { throw error("Null bitmap") };return .init(address: 0,backing: []) }
                    guard let backing = a.backing else { throw error("Bitmap backing") };return try .init(address: a.address,backing: blob(backing))
                },source: { path in
                    loads += 1;guard let input = child.resource,input.path == path,input.present == (surface != 0),input.width == (surface == 0 ? nil : source.width),input.height == (surface == 0 ? nil : source.height) else { throw error("Declared DIB/path control") }
                    panelInputs.append(input);return input
                },deviceResult: { (surface,key) },observe: { e in
                    // Bitmap child emits no per-event snapshots; its entire
                    // live/dead state is compared at return below.
                    try event(e.kind,e.arguments,e.strings,child: child,index: &n,state: nil)
                })
                guard allocations == 1,loads == (a.address == 0 ? 0 : 1) else { throw error("Bitmap callback count") }
                for call in calls {
                    guard call.returnSP == call.entrySP+4+call.pop,call.returnSP == child.entrySP-40,call.saved.count == 4 else { throw error("Bitmap child ABI") }
                    if call.entry == 0x43ee50 { guard call.returnPC == 0x43ccd9,call.pop == 12,call.result == a.address else { throw error("Constructor return") };result.constructors += 1 }
                    else { guard call.entry == 0x43ef50,call.returnPC == 0x43cc9c,call.pop == 0 else { throw error("Destructor return") };result.destructors += 1 }
                }
                try finish(child,n,value ? 1 : 0,state);try panelRecords(records,item.label);return value
            },write: { mode,state in
                let child = try next(mode.rawValue)
                if mode == .defaults { result.defaults += 1 } else { result.caches += 1 }
                guard child.entry == (mode == .defaults ? 0x43c690 : 0x43c710),let backing = child.backing,let capacity = child.capacity,let available = child.available,
                      let action = child.writeMode,let failAt = child.failAt,let close = child.closeResult,[1,7,64,4096].contains(capacity),["full","error","zero","short"].contains(action) else { throw error("Writer input") }
                var output = try OriginalBufferedTextOutput(backing: blob(backing)),n = 0,writeIndex = 0
                guard output.buffer.bytes.count == capacity else { throw error("Output extent") }
                let value = try OriginalMenuInfoWriting.run(mode,globals: &state,output: &output,available: available,write: { bytes in
                    defer { writeIndex += 1 };let count = Int32(bytes.count)
                    if writeIndex != failAt { return count }
                    switch action { case "error":return -1;case "zero":return 0;case "short":return count-1;default:throw error("Invalid IO error response") }
                },close: { close },observe: { e,s,o in
                    try event(e.kind,e.arguments,e.strings,format: e.format,value: e.result,child: child,index: &n,state: s,output: o)
                })
                try finish(child,n,value,state,output: output);return value
            },observe: { e,_ in
                guard parentIndex < item.events.count,e == item.events[parentIndex] else { throw error("\(item.label) parent event\(parentIndex): \(e)") }
                parentIndex += 1;result.events += 1
            })
            guard parentIndex == item.events.count,childIndex == item.children.count else { throw error("Unconsumed parent/children") }
            switch end {
            case .ready:guard item.continuation == "ready",item.endPC == 0x42712c,item.endSP == 0x1000f000 else { throw error("Root return") }
            case .contentBoundary(let call):guard item.continuation == "contentBoundary",item.endPC == call else { throw error("Root boundary") };result.boundaries += 1
            }
            try check(state,globals(item.globals),item.label+" final globals");try check(world,storage(item.world),item.label+" World")
            guard item.records.count == early.count else { throw error("Parent resource inventory") }
            for record in item.records {
                guard let actual = early[record.address] else { throw error("Parent resource binding") };var expected = try storage(record.storage)
                let surface = try expected.integer(at: 0,as: UInt32.self);try expected.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                try check(actual.storage,expected,item.label+" early bitmap")
            }
            try panelRecords(item.panelRecords,item.label);result.cases += 1
        }
        return result
    }
}
