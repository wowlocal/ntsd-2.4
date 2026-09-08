import Foundation
import NTSDCore

/// Repeated outer calls select their own phases. Captured phases are assertions
/// and platform inputs, never a program driving native control flow.
public enum FrontMenuLoopReference {
    public struct Result {
        public var cases = 0, phases = 0, returns = 0, boundaries = 0, loading = 0, bodies = 0, main = 0, tails = 0, worldOne = 0
        public var helpers = 0, events = 0, draws = 0, reads = 0, clips = 0, blits = 0, fills = 0, constructors = 0, frees = 0, tables = 0, random = 0
        public var settings = 0, settingsReturns = 0, settingsEvents = 0, prints = 0, fileWrites = 0, failedWrites = 0, records = 0, bytes = 0
        public var parent = FrontMenuCompletionReference.Result()
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, live: Bool?, storage: Storage }
    private struct Snapshot: Decodable { let globals: String, world: Storage, crtState: UInt32, pointers: [UInt8], records: [Record] }
    private struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32?, result: UInt32? }
    private struct PhaseState: Decodable {
        let stimulus: [InputControlReference.GlobalWrite], continuation: String, endPC: UInt32, endSP: UInt32
        let globals: String, world: Storage, records: [Record], helpers: [Helper]?, pending: [Helper]?
    }
    private struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    private struct Allocation: Decodable { let address: UInt32, backing: String? }
    private struct BitmapInput: Decodable { let resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32 }
    private struct Prefix: Decodable { let input: OriginalFrontScreenInput, fillBacking: String, allocation: Allocation?, bitmapInput: BitmapInput? }
    private struct Body: Decodable { let input: OriginalFrontScreenBodyInput, local: Storage }
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
    private struct Alternate: Decodable { let input: OriginalFrontScreenAlternateInput, fills: [Fill], settings: [Settings], local: Storage }
    private struct Random: Decodable { let before: UInt32, after: UInt32, result: UInt32 }
    private struct ABI: Decodable { let endPC: UInt32, endSP: UInt32, saved: [UInt32], seh: UInt32 }
    private struct CompletionInput: Decodable { let menu: OriginalMainMenuInput, presentation: OriginalMenuPresentationInput, drawResults: [Int32] }
    private struct Completion: Decodable {
        let entry: String, stimulus: [InputControlReference.GlobalWrite], input: CompletionInput, mainExit: OriginalMainMenuExit?, mainAfter: Snapshot?, mainEvents: Int?
        let helpers: [Helper], random: [Random], after: Snapshot, abi: ABI
    }
    private struct Events: Decodable { let events: [OriginalFrontScreenEvent] }
    private struct Update: Decodable { let events: [OriginalMenuPanelUpdateEvent], children: [Empty], panelRecords: [Empty] }
    private struct Initialize: Decodable { let allocations: [Empty], inputs: [Empty], calls: [Empty] }
    private struct Empty: Decodable {}
    private struct Phase: Decodable {
        let kind: String, backing: String?, state: PhaseState?, events: [OriginalFrontScreenEvent]
        var initialize: Initialize?, prefix: Prefix?, update: Update?, body: Body?, alternate: Alternate?, completion: Completion?
        enum Keys: String, CodingKey { case kind, backing, value }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self);kind = try c.decode(String.self,forKey: .kind);backing = try c.decodeIfPresent(String.self,forKey: .backing)
            state = kind == "completion" ? nil : try c.decode(PhaseState.self,forKey: .value)
            if kind == "update" {
                let u = try c.decode(Update.self,forKey: .value);update = u;events = u.events.map { .init($0.kind,$0.arguments) }
            } else { events = try c.decode(Events.self,forKey: .value).events }
            switch kind {
            case "initialize":initialize = try c.decode(Initialize.self,forKey: .value)
            case "prefix":prefix = try c.decode(Prefix.self,forKey: .value)
            case "update":break
            case "body":body = try c.decode(Body.self,forKey: .value)
            case "alternate":alternate = try c.decode(Alternate.self,forKey: .value)
            case "completion":completion = try c.decode(Completion.self,forKey: .value)
            default:throw FrontMenuLoopReference.error("Unknown phase")
            }
        }
    }
    private struct Case: Decodable {
        let label: String, stimulus: [InputControlReference.GlobalWrite], phases: [Phase], continuation: OriginalFrontMenuLoop.Continuation, endPC: UInt32, endSP: UInt32, after: Snapshot
    }
    private struct Corpus: Decodable { let exeSHA256: String, dllSHA256: String, initialGlobals: String, initialCRT: UInt32, sources: [Source], cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Front menu loop reference: "+text) }

    public static func compare(_ data: Data) throws -> Result {
        let raw = try MatchPreparationReference.unpack(data,maximumCount: 128_000_000),c = try JSONDecoder().decode(Corpus.self,from: raw)
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",!c.cases.isEmpty else { throw error("Source identity") }
        var result = Result(),blobs: [String:[UInt8]] = [:],cache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value };guard let b = c.blobs[key],b.sha256 == key else { throw error("Blob binding") }
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
            let key = ref.bytes+ref.defined;if let value = cache[key] { return value };let bytes = try blob(ref.bytes),mask = try blob(ref.defined)
            guard bytes.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Storage mask") }
            let value = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 });cache[key] = value;return value
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            };result.records += 1;result.bytes += actual.bytes.count
        }
        var sources: [String:Source] = [:]
        for s in c.sources {
            let bytes = try blob(s.dib),dib = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count))
            guard bytes.count >= 40,sources[s.path] == nil,try dib.integer(at: 4,as: Int32.self) == s.width,try dib.integer(at: 8,as: Int32.self) == s.height else { throw error("DIB identity") };sources[s.path] = s
        }
        guard Set(sources.keys) == ["MENU_BACK1","MENU_BACK13"] else { throw error("Declared background inventory") }
        guard let document = try JSONSerialization.jsonObject(with: raw) as? [String:Any],var parent = document["parent"] as? [String:Any] else { throw error("Parent document") }
        parent["blobs"] = document["blobs"]
        var ownWorld: OriginalStateRecord?,ownGlobals: OriginalStateRecord?,ownCRT: OriginalCRTRandom?,ownMemory: OriginalMenuPresentationMemory?,ownPrefix: OriginalFrontScreenPrelude?
        result.parent = try FrontMenuCompletionReference.compare(JSONSerialization.data(withJSONObject: parent)) { world,state,crt,bitmaps,surfaces,memory in
            try check(state,globals(c.initialGlobals),"Own native first return");guard crt.state == c.initialCRT else { throw error("Own parent CRT") }
            let address = try state.integer(at: 0x4511ac-OriginalMatchPreparation.globalBase,as: UInt32.self)
            guard let bitmap = bitmaps[address],let surface = surfaces[address] else { throw error("Own parent background") }
            ownPrefix = try .init(bitmaps: [address:bitmap],surfaces: [address:surface])
            ownWorld = world;ownGlobals = state;ownCRT = crt;ownMemory = memory
        }
        guard var world = ownWorld,var state = ownGlobals,var crt = ownCRT,var memory = ownMemory,var prefix = ownPrefix else { throw error("Missing native parent") }
        var resources = OriginalFrontMenuResources()
        func records(_ expected: [Record],_ label: String) throws {
            guard expected.count == memory.allocations.count,Set(expected.map(\.address)).count == expected.count else { throw error(label+" inventory") }
            for r in expected {
                guard let own = memory.allocations[r.address],own.live == (r.live ?? true) else { throw error(label+" ownership") }
                try check(own.storage,storage(r.storage),label+" bitmap")
            }
        }
        func snapshot(_ expected: Snapshot,_ world: OriginalStateRecord,_ state: OriginalStateRecord,_ label: String) throws {
            try check(world,storage(expected.world),label+" World");try check(state,globals(expected.globals),label+" globals");try records(expected.records,label)
            guard crt.state == expected.crtState,memory.replayPointers.bytes == expected.pointers else { throw error(label+" CRT/pointers") }
        }
        let helperReturns: [UInt32:Set<UInt32>] = [
            0x415160:[0x4270df,0x427884],0x4237e0:[0x4270c9,0x4276a9],0x43c450:[0x4270c9,0x4276a9],0x423840:[0x4270f1],0x43ee50:[0x4238e6],
            0x43ef70:[0x43f0d5,0x43f212],0x43f010:[0x427114,0x4274f7,0x42752b,0x427566,0x42759d,0x4275bc,0x427616,0x42762b,0x42766c,0x4276e8,0x42776d,0x4277b8,0x4277d6,0x4277ee,0x427817,0x4278d9,0x42471c,0x427937,0x4279f0,0x427a90,0x428778],
            0x401290:[0x427257,0x42727d,0x4272a4,0x4272f3,0x4273ac,0x42745d],0x401a30:[0x427318,0x4273d1,0x427482,0x427556,0x4276a4,0x427720,0x427798,0x4278f5,0x427a19],
            0x423230:[0x42768d,0x427709],0x4028a0:[0x424728,0x42877e],0x422ac0:[0x427a31,0x427a76],0x423910:[0x424708],0x423b00:[0x427a60,0x427c9f],0x43e940:[0x424733,0x428789],0x43ef50:[0x42391f]
        ]
        func helpers(_ values: [Helper]) throws {
            for h in values {
                let pop: UInt32 = h.entry == 0x43f010 ? 24 : h.entry == 0x43ee50 ? 12 : h.entry == 0x401a30 ? 4 : 0
                guard h.pop == pop,h.saved.count == 4,h.returnSP == h.entrySP+4+pop,h.result != nil,helperReturns[h.entry]?.contains(h.returnPC) == true else { throw error("Helper ABI "+String(h.entry,radix:16)) };result.helpers += 1
            }
        }
        func draw(_ args: [UInt32],_ results: [Int32],_ blits: inout Int,_ width: Int32,_ height: Int32,_ allocations: [UInt32:OriginalMenuPresentationMemory.Allocation],_ event: (OriginalFrontScreenEvent) throws -> Void) throws {
            guard args.count == 7,!results.isEmpty,let bitmap = allocations[args[0]],bitmap.live else { throw error("Unbound bitmap/device input") }
            let input = OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],mirrored: args[5],
                sourceSurface: try bitmap.storage.integer(at: 0,as: UInt32.self),targetSurface: args[6],viewportWidth: width,viewportHeight: height)
            var canonical = bitmap.storage;try canonical.write(UInt32(input.sourceSurface == 0 ? 0 : 1),at: 0)
            _ = try OriginalBitmapDrawing.draw(input,bitmap: canonical,observeRead: { r in var e = OriginalFrontScreenEvent("read");e.read = r;try event(e) },
                observeClip: { c in var e = OriginalFrontScreenEvent("clip");e.clip = c;try event(e) },perform: { b in
                    var e = OriginalFrontScreenEvent("blit");e.blit = b;try event(e);defer { blits += 1 };return results[blits%results.count]
                })
        }
        for (caseIndex,item) in c.cases.enumerated() {
            guard caseIndex != 0 || item.stimulus.isEmpty else { throw error("Natural next call") }
            for w in item.stimulus {
                let hex = Array(w.bytes);guard hex.count%2 == 0 else { throw error("Stimulus extent") }
                for i in stride(from: 0,to: hex.count,by: 2) {
                    guard let b = UInt8(String(hex[i...i+1]),radix: 16) else { throw error("Stimulus byte") };try state.write(b,at: Int(w.address)-OriginalMatchPreparation.globalBase+i/2)
                }
            }
            let beforeWorld = world,width = try state.integer(at: 0x44d78c-OriginalMatchPreparation.globalBase,as: Int32.self),height = try state.integer(at: 0x44d790-OriginalMatchPreparation.globalBase,as: Int32.self)
            var phaseIndex = 0,eventIndex = 0,active: Phase?,ownLocal: OriginalStateRecord?
            func take(_ kind: String) throws -> Phase {
                guard phaseIndex < item.phases.count,item.phases[phaseIndex].kind == kind else { throw error(item.label+" native phase "+kind+" at\(phaseIndex)") }
                let p = item.phases[phaseIndex];phaseIndex += 1;result.phases += 1;eventIndex = 0;active = p
                guard p.state?.stimulus.isEmpty ?? p.completion!.stimulus.isEmpty else { throw error("Nested stimulus would replace live state") };return p
            }
            func event(_ e: OriginalFrontScreenEvent) throws {
                guard let p = active,eventIndex < p.events.count,e == p.events[eventIndex] else { throw error("\(item.label) phase\(phaseIndex) event\(eventIndex): \(e); expected \(active.flatMap { $0.events.indices.contains(eventIndex) ? String(describing:$0.events[eventIndex]) : nil } ?? "end")") }
                eventIndex += 1;result.events += 1
                switch e.kind {
                case "draw":result.draws += 1
                case "read":result.reads += 1
                case "clip":result.clips += 1
                case "blit":result.blits += 1
                case "fill":result.fills += 1
                case "construct":result.constructors += 1
                case "free":result.frees += 1
                default:break
                }
            }
            func finish(_ p: Phase,_ state: OriginalStateRecord,_ continuation: String,_ pc: UInt32,_ sp: UInt32 = 0x1000f000) throws {
                guard let s = p.state,s.continuation == continuation,s.endPC == pc,s.endSP == sp,eventIndex == p.events.count else { throw error(item.label+" "+p.kind+" continuation/events") }
                if sp == 0x1000f000 { guard s.pending?.isEmpty ?? true else { throw error("Pending successful helper") } }
                try helpers(s.helpers ?? []);try check(state,globals(s.globals),item.label+" "+p.kind+" globals");try check(beforeWorld,storage(s.world),item.label+" World");try records(s.records,item.label)
            }
            let end = try OriginalFrontMenuLoop.run(world: &world,globals: &state,initialize: { world,state in
                let p = try take("initialize"),i = p.initialize!
                guard i.allocations.isEmpty,i.inputs.isEmpty,i.calls.isEmpty else { throw error("Unexpected early reinitialization inputs") }
                let end = try resources.load(world: world,globals: &state,allocate: { _ in throw error("Unprobed resource allocation") },source: { _,_ in throw error("Unprobed resource source") },deviceResult: { _ in throw error("Unprobed resource device") },observe: { try event(.init($0.kind.rawValue,$0.arguments,$0.strings)) })
                try finish(p,state,end.continuation.rawValue,0x42709b);return end
            },prefix: { state in
                let p = try take("prefix"),i = p.prefix!;var allocated = false,constructed = false
                guard i.input.drawTarget == 0x28002020 else { throw error("Outer prefix target") }
                let end = try prefix.advance(globals: &state,input: i.input,fillBacking: blob(i.fillBacking),allocate: {
                    guard !allocated,let a = i.allocation,a.address != 0,let backing = a.backing,memory.allocations[a.address] == nil else { throw error("New background allocation") };allocated = true;return try .init(address: a.address,backing: blob(backing))
                },source: { path in
                    guard !constructed,let b = i.bitmapInput,let s = sources[path],b.resource.path == path,b.resource.present,b.resource.width == s.width,b.resource.height == s.height,b.surface == 0x28006400 else { throw error("Background source input") };constructed = true;return (b.resource,b.surface,b.colorKeyResult)
                },observe: event)
                guard allocated == (i.allocation != nil),constructed == (i.bitmapInput != nil) else { throw error("Background calls") }
                for (address,bitmap) in prefix.bitmaps { var raw = bitmap.storage;try raw.write(prefix.surfaces[address]!,at: 0);memory.allocations[address] = .init(storage: raw) }
                try finish(p,state,end.rawValue,end == .critical ? 0x427127 : 0x4275cb);return end
            },update: { state in
                let p = try take("update");guard p.update!.children.isEmpty,p.update!.panelRecords.isEmpty else { throw error("Unexpected panel child input") }
                let end = try OriginalMenuPanelUpdate.run(globals: &state,content: { _ in throw error("Unprobed panel content") },bitmap: { _ in throw error("Unprobed panel bitmap") },write: { _,_ in throw error("Unprobed panel writer") },observe: { e,_ in try event(.init(e.kind,e.arguments)) })
                guard end == .ready else { throw error("Panel boundary") };try finish(p,state,"ready",0x42712c);return end
            },body: { state in
                let p = try take("body"),i = p.body!;guard let backing = p.backing else { throw error("Before-body scratch") }
                var local = try OriginalStateRecord(bytes: blob(backing),defined: [Bool](repeating: false,count: 0xc0)),blits = 0
                let end = try OriginalFrontScreenBody.advance(globals: &state,local: &local,input: i.input,draw: { try draw($0,i.input.drawResults,&blits,width,height,memory.allocations,event) },observe: event)
                try check(local,storage(i.local),item.label+" body scratch");ownLocal = local
                try finish(p,state,end.rawValue,0x4275cb);result.bodies += 1;return end
            },alternate: { state,selector in
                let p = try take("alternate"),i = p.alternate!
                guard selector == i.input.selector,i.input.drawTarget == 0x28002020 else { throw error("Native-derived selector/caller") }
                var blits = 0,fillIndex = 0,settingsIndex = 0
                let end = try OriginalFrontScreenAlternate.advance(globals: &state,input: i.input,draw: { try draw($0,i.input.drawResults,&blits,width,height,memory.allocations,event) },fill: { args in
                    guard fillIndex < i.fills.count else { throw error("Excess fill") };let f = i.fills[fillIndex];fillIndex += 1;guard f.address == 0x1000ef84 else { throw error("Fill stack") }
                    var e = OriginalFrontScreenEvent("fill");e.fill = try OriginalSurfaceFilling.request(target: args[0],x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),width: Int32(bitPattern: args[3]),height: Int32(bitPattern: args[4]),color: args[5],backing: blob(f.backing));try event(e)
                },writeSettings: { childState in
                    guard settingsIndex < i.settings.count else { throw error("Excess settings") };let s = i.settings[settingsIndex];settingsIndex += 1
                    guard [1,7,64,4096].contains(s.capacity),["full","error","zero","short"].contains(s.writeMode),s.entrySP == 0x1000effc,[0x42768d,0x427709].contains(s.returnPC),s.saved.count == 4 else { throw error("Settings input/ABI") }
                    var output = try OriginalBufferedTextOutput(backing: blob(s.backing)),index = 0,writeIndex = 0
                    guard output.buffer.bytes.count == s.capacity else { throw error("Settings buffer") }
                    let value = try OriginalSettingsWriting.run(globals: &childState,output: &output,available: s.available,write: { bytes in
                        defer { writeIndex += 1 };result.fileWrites += 1;if writeIndex != s.failAt { return Int32(bytes.count) };result.failedWrites += 1
                        switch s.writeMode { case "error":return -1;case "zero":return 0;case "short":return Int32(bytes.count)-1;default:throw error("Invalid failing write") }
                    },close: { s.closeResult },observe: { actual,state,stream in
                        guard index < s.events.count else { throw error("Excess writer event") };let e = s.events[index];index += 1
                        guard actual.kind == e.kind,actual.arguments == e.arguments,actual.strings == e.strings,actual.format == e.format,actual.result == e.result else { throw error(item.label+" writer event\(index-1)") }
                        if let key = e.globals { try check(state,globals(key),item.label+" child globals") }
                        if let key = e.file { try check(stream.fileStorage(),defined(key,32),item.label+" child FILE") }
                        if let ref = e.buffer { try check(stream.buffer,storage(ref),item.label+" child buffer") }
                        if actual.kind == "print" { guard [0x423266,0x42327d,0x423345,0x4233ea,0x4233f8,0x423405,0x423412,0x42341f].contains(e.returnPC) else { throw error("Print ABI") };result.prints += 1 }
                        if actual.kind == "close" { guard e.returnPC == 0x423426 else { throw error("Close ABI") } };result.settingsEvents += 1
                    })
                    guard index == s.events.count,value.value == s.result else { throw error("Settings result/events") }
                    switch value {
                    case .returned:guard s.completed,s.continuation == "returned",s.endPC == s.returnPC,s.endSP == s.entrySP+4 else { throw error("Settings return") };result.settingsReturns += 1
                    case .nullFile:guard !s.completed,s.continuation == "nullFile",s.endPC == 0x423260,s.endSP == 0x1000efdc else { throw error("Settings FILE boundary") }
                    default:throw error("Unprobed writer boundary")
                    }
                    try check(childState,globals(s.globals),item.label+" settings globals");try check(output.fileStorage(),defined(s.file,32),item.label+" settings FILE");try check(output.buffer,storage(s.buffer),item.label+" settings buffer")
                    result.settings += 1;return value
                },observe: event)
                guard settingsIndex == i.settings.count,fillIndex == i.fills.count else { throw error("Alternate child inventory") }
                if let local = ownLocal { try check(local,storage(i.local),item.label+" retained body scratch") }
                let pc: UInt32,sp: UInt32
                switch end {
                case .mainMenu:pc = 0x427915;sp = 0x1000f000
                case .presentation:pc = 0x42873e;sp = 0x1000f000
                case .otherSelector:pc = 0x427ca7;sp = 0x1000f000
                case .nullSettingsFile:pc = 0x423260;sp = 0x1000efdc;guard p.state?.pending?.last?.entry == 0x423230 else { throw error("Pending writer") }
                default:throw error("Unprobed alternate boundary")
                }
                try finish(p,state,end.rawValue,pc,sp);return end
            },completion: { entry,world,state in
                let p = try take("completion"),i = p.completion!
                guard entry.rawValue == i.entry,i.input.menu.targetSurface == 0x28002020,i.input.presentation.targetSurface == 0x28002020 else { throw error("Native completion entry/target") }
                let allocations = memory.allocations;var blits = 0,randomIndex = 0
                func drawing(_ args: [UInt32]) throws { try event(.init("draw",args));try draw(args,i.input.drawResults,&blits,width,height,allocations,event) }
                var presentation: OriginalMenuPresentationEntry = .tail
                if entry == .main {
                    let end = try OriginalMainMenu.run(world: &world,globals: &state,crt: &crt,input: i.input.menu) { e in
                        if e.kind == .bitmap { try drawing(e.arguments);return }
                        if e.kind == .randomTable {
                            guard e.arguments.count == 2 else { throw error("RNG event") };var rng = OriginalCRTRandom(state: e.arguments[0])
                            for _ in 0..<3000 {
                                guard randomIndex < i.random.count else { throw error("Excess RNG") };let r = i.random[randomIndex];randomIndex += 1
                                guard rng.state == r.before,rng.next() == r.result,rng.state == r.after else { throw error("Actual DLL RNG") };result.random += 1
                            }
                            guard rng.state == e.arguments[1] else { throw error("Final table state") };result.tables += 1
                        };try event(.init(e.kind.rawValue,e.arguments,e.strings))
                    }
                    guard end == i.mainExit,eventIndex == i.mainEvents,let after = i.mainAfter else { throw error("Main exit") };try snapshot(after,world,state,item.label+" main")
                    presentation = end == .present ? .tail : .epilogue;result.main += 1
                } else if entry == .worldOne { presentation = .worldOne;result.worldOne += 1 }
                if presentation == .tail { result.tails += 1 }
                try OriginalMenuPresentation.apply(presentation,input: i.input.presentation,world: &world,globals: &state,memory: &memory) { e in
                    if e.kind == .bitmap { try drawing(e.arguments) } else { try event(.init(e.kind.rawValue,e.arguments,e.strings)) }
                }
                guard eventIndex == p.events.count,randomIndex == i.random.count,i.abi.endPC == 0x30000000,i.abi.endSP == 0x1000f42c,i.abi.saved == [0x11223344,0x22334455,0x33445566,0x44556677],i.abi.seh == 0x12345678 else { throw error("Completion events/ABI") }
                try helpers(i.helpers);try snapshot(i.after,world,state,item.label+" completion")
            })
            guard end == item.continuation,phaseIndex == item.phases.count else { throw error(item.label+" whole-call continuation/phases") }
            switch end {
            case .returned:guard item.endPC == 0x30000000,item.endSP == 0x1000f42c else { throw error("Outer return") };result.returns += 1
            case .loading:guard item.endPC == 0x41bc90,item.endSP == 0x1000eff8 else { throw error("Loading call") };result.loading += 1
            case .otherSelector:guard item.endPC == 0x427ca7,item.endSP == 0x1000f000 else { throw error("Other selector") };result.boundaries += 1
            case .alternateBoundary:guard item.endPC == 0x423260,item.endSP == 0x1000efdc else { throw error("FILE boundary") };result.boundaries += 1
            default:throw error("Unprobed outer boundary")
            }
            try snapshot(item.after,world,state,item.label+" whole call");result.cases += 1
        }
        return result
    }
}
