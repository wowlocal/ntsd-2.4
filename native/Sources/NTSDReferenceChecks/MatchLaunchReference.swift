import Foundation
import NTSDCore

/// Continue the entire verified selection parent, keeping its own state and
/// resources. Expected snapshots are comparison outputs, never engine inputs.
public enum MatchLaunchReference {
    public struct Result {
        public let parent: MatchSelectionReference.Result
        public let cases: Int,records: Int,bytes: Int,events: Int,helpers: Int,checkpoints: Int,controlSlots: Int,physicsSlots: Int,depthSlots: Int
    }
    typealias Storage = MenuStartupReference.Storage
    typealias Allocation = MenuStartupReference.Allocation
    struct State: Decodable {
        let state: InputControlReference.Snapshot,early: MenuStartupReference.Retained
        let backgrounds: [Storage],bitmaps: [Allocation],music: [Allocation],released: [UInt32]
    }
    struct Event: Decodable {
        let kind: String
        let slot: Int?,loop: UInt32?,values: [UInt16]?,index: Int?,counter: Int?,beforeIndex: Int?,beforeCounter: Int?
        let stream: Int32?,range: Int32?,result: UInt32?,format: [UInt8]?,bytes: [UInt8]?
        let address: UInt32?,count: Int?,size: Int?,mode: Int32?,activity: UInt32?,actors: UInt32?
    }
    struct BitmapEvent: Decodable { let kind: String,path: String?,present: Bool?,width: Int32?,height: Int32?,sha256: String?,bitmap: Int? }
    struct Bitmap: Decodable { let address: UInt32,path: String,optional: UInt32 }
    struct Case: Decodable {
        let label: String,before: State?,after: State,events: [Event]?,helpers: [MenuReturnReference.Helper]?
        let bitmapEvents: [BitmapEvent]?,newBitmaps: [Bitmap]?,end: MenuStartupReference.Position?
        let readsBeforeWrites: [CharacterScreenReference.UndefinedRead]?
        let music: MenuStartupReference.Music?,returned: MenuReturnReference.Case?,cycle: MenuCycleReference.Case?
    }
    struct Corpus: Decodable {
        let exeSHA256: String,dllSHA256: String,parent: InputControlReference.Parent,worldAddress: UInt32
        let actorAddresses: [UInt32],objectAddresses: [UInt32],localTime: [UInt16],cases: [Case],blobs: [String:InputControlReference.Blob]
    }
    struct Control: Decodable {
        struct Checkpoint: Decodable { let label: String,pc: UInt32,slot: Int,actor: Storage }
        struct Helper: Decodable { let entry: UInt32,entrySP: UInt32,returnSP: UInt32,pop: UInt32,saved: [UInt32],this: UInt32,arguments: [UInt32] }
        struct Section: Decodable {
            let label: String,before: State,after: State,helpers: [Helper],checkpoints: [Checkpoint]
            let readsBeforeWrites: [CharacterScreenReference.UndefinedRead],end: MenuStartupReference.Position
        }
        let exeSHA256: String,dllSHA256: String,parent: InputControlReference.Parent,worldAddress: UInt32
        let actorAddresses: [UInt32],objectAddresses: [UInt32],cases: [Section],blobs: [String:InputControlReference.Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Match launch reference: "+message) }
    public static func compare(launch: Data,selection: Data,character: Data,cycle: Data,returning: Data,screen: Data,startup: Data,menu: Data,loading: Data,catalog: Data,sounds: Data,requireComplete: Bool = true,
                               gameplayControl: Data? = nil,gameplayPhysics: Bool = false,gameplayLinks: Data? = nil) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(launch,maximumCount: 128_000_000))
        let control = try gameplayControl.map { try JSONDecoder().decode(Control.self,from: MatchPreparationReference.unpack($0,maximumCount: 128_000_000)) }
        let links = try gameplayLinks.map { try JSONDecoder().decode(Control.self,from: MatchPreparationReference.unpack($0,maximumCount: 128_000_000)) }
        guard !gameplayPhysics || control != nil else { throw error("Physics needs own control continuation") }
        if let control {
            guard requireComplete,control.exeSHA256 == c.exeSHA256,control.dllSHA256 == c.dllSHA256,
                  control.parent.sha256 == MatchPreparationReference.digest(launch),control.worldAddress == c.worldAddress,
                  control.actorAddresses == c.actorAddresses,control.objectAddresses == c.objectAddresses,
                  control.cases.map(\.label) == ["control","physics"] else { throw error("Gameplay control parent identity") }
        }
        if let links {
            guard gameplayPhysics,let gameplayControl,links.exeSHA256 == c.exeSHA256,links.dllSHA256 == c.dllSHA256,
                  links.parent.sha256 == MatchPreparationReference.digest(gameplayControl),links.worldAddress == c.worldAddress,
                  links.actorAddresses == c.actorAddresses,links.objectAddresses == c.objectAddresses,
                  links.cases.map(\.label) == ["depth-attachments"] else { throw error("Gameplay links parent identity") }
        }
        let blobs = c.blobs.merging(control?.blobs ?? [:]) { _,new in new }.merging(links?.blobs ?? [:]) { _,new in new }
        let initial = try JSONDecoder().decode(MenuStartupReference.Corpus.self,from: MatchPreparationReference.unpack(startup,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.parent.sha256 == MatchPreparationReference.digest(selection),c.worldAddress == 0x22000020,
              c.actorAddresses == initial.actorAddresses,c.objectAddresses == initial.objectAddresses,c.localTime.count == 8,
              (requireComplete ? c.cases.count == 8 : [4,8].contains(c.cases.count)),
              c.cases.map(\.label) == Array(["prelude","preparation","music","preparation-tail","recording","menu-continuation","returned","gameplay-entry"].prefix(c.cases.count)) else { throw error("Source/parent identity") }
        var records = 0,bytes = 0,events = 0,helpers = 0,checkpoints = 0,callbacks = 0,controlSlots = 0,physicsSlots = 0,depthSlots = 0
        var cache: [String:[UInt8]] = [:],recordCache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            guard let b = blobs[key] else { throw error("Missing blob") }
            let raw = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 8_000_000)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob SHA") };cache[key] = raw;return raw
        }
        func storage(_ s: Storage) throws -> OriginalStateRecord {
            let key = s.bytes+s.defined;if let value = recordCache[key] { return value }
            let raw = try blob(s.bytes),mask = try blob(s.defined)
            guard raw.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Storage mask") }
            let value = try OriginalStateRecord(bytes: raw,defined: mask.map { $0 != 0 });recordCache[key] = value;return value
        }
        func defined(_ key: String) throws -> OriginalStateRecord {
            if let value = recordCache[key] { return value }
            let raw = try blob(key),value = try OriginalStateRecord(bytes: raw,defined: [Bool](repeating: true,count: raw.count));recordCache[key] = value;return value
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if let i = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw error(label+"+"+String(i,radix:16)+" actual \(actual.bytes[i])/\(actual.defined[i]) expected \(expected.bytes[i])/\(expected.defined[i])")
            };records += 1;bytes += actual.bytes.count
        }
        let actors = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objects = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        func world(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var value = raw
            guard try value.integer(at: 0x7d4,as: UInt32.self) == 0x60000020 else { throw error("World catalog") };try value.write(UInt32(0),at: 0x7d4)
            for i in 0..<400 {
                guard let a = actors[try value.integer(at: 0x194+i*4,as: UInt32.self)] else { throw error("World Actor") };try value.write(a,at: 0x194+i*4)
            };return value
        }
        let parent = try MatchSelectionReference.compare(selection: selection,character: character,cycle: cycle,returning: returning,screen: screen,startup: startup,menu: menu,loading: loading,catalog: catalog,sounds: sounds) { own,initialContext,crt,initialMusic,resources in
            callbacks += 1
            var state = own,context = initialContext,music = initialMusic,replayAddresses: [UInt32] = []
            func snapshot(_ value: OriginalMatchPreparation,_ expected: State,_ label: String) throws {
                let s = expected.state,raw = try blob(s.poolBytes),mask = try blob(s.poolMask)
                guard raw.count == 0x7d8+400*0x420,mask.count == raw.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Pool extent") }
                func part(_ at: Int,_ n: Int) throws -> OriginalStateRecord { try .init(bytes: Array(raw[at..<at+n]),defined: mask[at..<at+n].map { $0 != 0 }) }
                try check(value.world,world(part(0,0x7d8)),label+" World")
                for i in 0..<400 {
                    var r = try part(0x7d8+i*0x420,0x420)
                    guard let o = objects[try r.integer(at: 0x368,as: UInt32.self)] else { throw error("Actor Object") };try r.write(o,at: 0x368)
                    try check(value.actors[i],r,label+" Actor\(i)")
                }
                try check(value.globals,defined(s.globals),label+" globals")
                try check(context.savedPlayback,defined(s.saved),label+" saved settings");try check(context.memory.replayPointers,defined(s.pointers),label+" replay pointers")
                guard s.memory.count == replayAddresses.count else { throw error("Replay inventory") }
                for (address,m) in zip(replayAddresses,s.memory) {
                    guard let a = context.memory.allocations[address],a.live == m.live else { throw error("Recording ownership") }
                    try check(a.storage,.init(bytes: blob(m.bytes),defined: blob(m.defined).map { $0 != 0 }),label+" recording")
                }
                let retained = expected.early
                try check(value.world,world(storage(retained.world)),label+" early World");try check(value.globals,defined(retained.globals),label+" early globals")
                guard crt.state == retained.crtState,context.memory.replayPointers.bytes == retained.pointers,
                      context.memory.allocations.count == retained.records.count+replayAddresses.count else { throw error("Early ownership/CRT") }
                for r in retained.records {
                    guard let a = context.memory.allocations[r.address],a.live == r.live else { throw error("Retained bitmap ownership") };try check(a.storage,storage(r.storage),label+" retained bitmap")
                }
                let catalogBitmaps = expected.bitmaps.filter { value.interface.bitmaps[$0.address] == nil }
                guard expected.backgrounds.count == 101,catalogBitmaps.count == value.bitmaps.count,
                      expected.bitmaps.count == value.bitmaps.count+value.interface.bitmaps.count else { throw error("BG/bitmap inventory") }
                let bitmapMap = Dictionary(uniqueKeysWithValues: catalogBitmaps.enumerated().map { ($0.element.address,$0.offset) })
                for (i,b) in expected.backgrounds.enumerated() {
                    var record = try storage(b)
                    for offset in [0x98c]+Array(stride(from: 0x914,through: 0x988,by: 4)) where record.defined[offset..<offset+4].allSatisfy({ $0 }) {
                        let p = try record.integer(at: offset,as: UInt32.self)
                        if p != 0 { guard let index = bitmapMap[p] else { throw error("BG bitmap binding") };try record.write(UInt32(index+1),at: offset) }
                    };try check(value.backgrounds[i],record,label+" BG\(i)")
                }
                for b in expected.bitmaps {
                    let actual: OriginalLoadedBitmap
                    if let a = value.interface.bitmaps[b.address] { actual = a }
                    else { guard let i = bitmapMap[b.address] else { throw error("Catalog bitmap") };actual = value.bitmaps[i] }
                    var record = try storage(b.storage)
                    guard try record.integer(at: 0,as: UInt32.self) == (actual.input.present ? 0x24000000 : 0) else { throw error("Bitmap surface") }
                    try record.write(UInt32(actual.input.present ? 1 : 0),at: 0);try check(actual.storage,record,label+" bitmap")
                }
                let released = try Set(expected.released.map { p -> Int in guard let i = bitmapMap[p] else { throw error("Released bitmap identity") };return i })
                guard value.releasedBitmaps == released,music.allocations.count == expected.music.count else { throw error("Resource lifetime") }
                for r in expected.music { guard let a = music.allocations[r.address] else { throw error("Music allocation") };try check(a,storage(r.storage),label+" music") }
                checkpoints += 1
            }
            func section(_ index: Int,_ stop: UInt32) throws -> Case {
                let item = c.cases[index]
                guard let before = item.before,item.end?.pc == stop,item.end?.sp == 0x1000df08,item.readsBeforeWrites?.isEmpty == true else { throw error("Owned section boundary/read provenance") }
                try snapshot(state,before,item.label+" before")
                for h in item.helpers ?? [] {
                    let pops: [UInt32:UInt32] = [0x4061d0:0,0x417170:0,0x40c030:4,0x40c0e0:4,0x431c70:0,0x43d280:0,0x43d2c0:0,0x401a30:4,0x43ee50:12]
                    guard pops[h.entry] == h.pop,h.returnSP == h.entrySP+4+h.pop,h.saved.count == 4 else { throw error("Launch helper ABI") };helpers += 1
                };return item
            }
            let prelude = try section(0,0x42d1ff),t = c.localTime
            var preludeEvents: [OriginalMatchPreludeEvent] = []
            let fileName = try OriginalMatchPrelude.apply(globals: &state.globals,localTime: .init(year:t[0],month:t[1],dayOfWeek:t[2],day:t[3],hour:t[4],minute:t[5],second:t[6],milliseconds:t[7])) { preludeEvents.append($0) }
            guard let pe = prelude.events,pe.map(\.kind) == ["localTime","format","format","soundRequest"],pe[0].values == t,
                  pe[1].format == Array("%4d%02d%02d_%02d%02d%02d".utf8),pe[2].format == Array("%s.lfr".utf8),
                  pe[1].result == pe[1].bytes.map({ UInt32($0.count) }),pe[2].result == UInt32(fileName.utf8.count),
                  pe[2].bytes == Array(fileName.utf8),pe[1].bytes == Array(fileName.dropLast(7).utf8),pe[3].slot == 0x455610,pe[3].loop == 0,
                  preludeEvents == [.localTime,.soundRequest(loop:false)] else { throw error("Prelude time/format/sound order") }
            events += pe.count;try snapshot(state,prelude.after,"prelude after")
            let preparation = try section(1,0x42d6b6),musicCase = c.cases[2],tail = c.cases[3]
            guard let expectedMusic = musicCase.music,let beforeTail = tail.before,let tailEvents = tail.events,
                  expectedMusic.kind == "match",expectedMusic.inherited,expectedMusic.stimulus.isEmpty,expectedMusic.endPC == 0x42d6bb,expectedMusic.endSP == 0x1000df08 else { throw error("Own enabled music caller") }
            var preparationEvents: [OriginalMatchPreparationEvent] = [],requests: [String] = [],musicCallbacks = 0
            let inputs = (preparation.bitmapEvents ?? []).filter { $0.kind == "bitmap-load" }
            try state.prepare(mode: 0,bitmapSource: { path in
                let i = requests.count;guard i < inputs.count,inputs[i].path == path,let present = inputs[i].present else { throw error("Own layer source") }
                let a = inputs[i];requests.append(path);return .init(path:path,present:present,width:a.width,height:a.height)
            },music: { value in
                musicCallbacks += 1;try snapshot(value,preparation.after,"prepared before music")
                var index = 0,formats = 0
                try OriginalMusicPlayback.resumeMatch(globals: &value.globals,memory: &music) { event in
                    guard index < expectedMusic.events.count else { throw error("Excess music event") };let e = expectedMusic.events[index];index += 1;events += 1
                    guard event == .init(e.kind,e.arguments,e.strings) else { throw error("Music event\(index)") }
                    if event.kind == .format {
                        guard formats < expectedMusic.formats.count,event.strings.count == 2 else { throw error("Music CRT format") }
                        let f = expectedMusic.formats[formats];formats += 1
                        guard event.arguments == [UInt32(bitPattern:f.result)],f.bytes == (event.strings[1]+[0]).map({ String(format:"%02x",$0) }).joined() else { throw error("Music CRT witness") }
                    };return e.response
                }
                guard index == expectedMusic.events.count,formats == expectedMusic.formats.count else { throw error("Music completion") }
                try check(value.globals,defined(expectedMusic.afterGlobals),"Music globals")
                let returns: [UInt32:UInt32] = [0x402020:0x4025c3,0x401d30:0x402085,0x401c90:0x40208a,0x401da0:0x4020a2,0x401f30:0x4020c9]
                for h in expectedMusic.calls { guard returns[h.entry] == h.returnAddress,h.returnSP == h.entrySP+4,h.saved.count == 4 else { throw error("Music helper ABI") };helpers += 1 }
                guard expectedMusic.events.filter({ $0.kind == .helper }).map({ $0.arguments[0] }).sorted() == expectedMusic.calls.map(\.entry).sorted() else { throw error("Music helper inventory") }
                try snapshot(value,musicCase.after,"music after");try snapshot(value,beforeTail,"tail before")
            },observe: { preparationEvents.append($0) })
            guard musicCallbacks == 1,requests == preparation.newBitmaps?.map(\.path),requests.count == inputs.count,
                  tail.end?.pc == 0x42d6ed,tail.end?.sp == 0x1000df08,tail.readsBeforeWrites?.isEmpty == true else { throw error("Preparation continuation") }
            let expectedEvents = (preparation.events ?? [])+tailEvents
            var eventIndex = 0
            for event in preparationEvents {
                if case .resumeMusic = event { continue };if case .musicPath = event { continue }
                guard eventIndex < expectedEvents.count else { throw error("Excess preparation event") };let e = expectedEvents[eventIndex];eventIndex += 1;events += 1
                let same: Bool
                switch event {
                case .reconstruct(let i):same = e.kind == "reconstruct" && e.slot == i
                case .random(let s,let r,let v,let bi,let bc,let i,let counter):same = e.kind == "random" && e.stream == s && e.range == r && e.result == UInt32(bitPattern:v) && e.beforeIndex == bi && e.beforeCounter == bc && e.index == i && e.counter == counter
                case .releaseLayers(let i):same = e.kind == "releaseLayers" && e.index == i
                case .loadLayers(let i):same = e.kind == "loadLayers" && e.index == i
                case .resetInput:same = e.kind == "resetInput"
                case .resumeMusic,.musicPath:same = false
                };guard same else { throw error("Preparation event\(eventIndex)") }
            }
            guard eventIndex == expectedEvents.count else { throw error("Missing preparation event") }
            for h in tail.helpers ?? [] { guard [UInt32(0x4061d0),0x431c70].contains(h.entry),h.pop == 0,h.returnSP == h.entrySP+4,h.saved.count == 4 else { throw error("Tail helper ABI") };helpers += 1 }
            try snapshot(state,tail.after,"prepared after reset")
            if !requireComplete && c.cases.count == 4 { return }
            let recording = try section(4,0x42d704)
            guard let re = recording.events,re.count == 2,re[0].kind == "replayEntry",re[0].mode == 0,re[0].activity == c.worldAddress+4,re[0].actors == c.worldAddress+0x194,
                  re[1].kind == "calloc",re[1].count == 1,re[1].size == OriginalReplayRecording.byteCount,let address = re[1].address,address != 0,
                  try context.memory.replayPointers.integer(at: 0,as: UInt32.self) == 0,context.memory.allocations[address] == nil else { throw error("Own first recording allocation") }
            var writer = OriginalReplayRecording(),allocations: [OriginalReplayAllocationEvent] = []
            try writer.begin(mode:0,state:&state) { allocations.append($0) }
            guard allocations == [.allocate(generation:1,bytes:OriginalReplayRecording.byteCount)],let buffer = writer.buffer else { throw error("Recording initialization") }
            context.memory.allocations[address] = .init(storage:buffer);try context.memory.replayPointers.write(address,at:0);replayAddresses.append(address);events += re.count
            try snapshot(state,recording.after,"recording after")
            let continuation = try section(5,0x42e0d2)
            try state.continueMenu(confirmation:1,bitmapSource: { _ in throw error("Unexpected Start bitmap") },observe: { _ in throw error("Unexpected Start continuation event") })
            guard continuation.events?.isEmpty == true else { throw error("Start continuation events") };try snapshot(state,continuation.after,"menu continued")
            guard let returned = c.cases[6].returned,returned.inherited,returned.stimulus.isEmpty else { throw error("Own whole return") }
            let r = try MenuReturnReference.compareCases(actorAddresses:c.actorAddresses,objectAddresses:c.objectAddresses,cases:[returned],blobs:c.blobs,state:state,context:context,crt:crt,replayAddresses:replayAddresses)
            state = r.state;context = r.context;records += r.records;bytes += r.bytes;events += r.events;helpers += r.helpers;checkpoints += r.checkpoints
            try snapshot(state,c.cases[6].after,"whole return after")
            guard let cycle = c.cases[7].cycle else { throw error("Next whole entry") }
            let entry = try MenuCycleReference.compareCases(actorAddresses:c.actorAddresses,objectAddresses:c.objectAddresses,worldAddress:c.worldAddress,initial:initial,cases:[cycle],blobs:c.blobs,
                state:state,context:context,crt:crt,music:music,resources:resources,replayAddresses:replayAddresses,gameplay:true)
            state = entry.state;context = entry.context;records += entry.records;bytes += entry.bytes;events += entry.events;checkpoints += entry.checkpoints
            try snapshot(state,c.cases[7].after,"first gameplay boundary")
            if let control {
                // Continue our own first gameplay entry. The source also contains
                // a later physics section, compared only when gameplayPhysics is enabled.
                let section = control.cases[0]
                guard section.end.pc == 0x41e634,section.end.sp == 0x1000e9bc,section.readsBeforeWrites.isEmpty else { throw error("Control boundary/provenance") }
                try snapshot(state,section.before,"own control before")
                let phase = try state.globals.integer(at: 0x450b90-0x44d000,as: UInt32.self)
                let mode = try state.globals.integer(at: 0x451160-0x44d000,as: UInt32.self)
                let pops: [UInt32:UInt32] = [0x413080:8,0x412800:0,0x4128f0:0,0x4129e0:0,0x412ac0:0,0x412ba0:0,0x412c90:0,0x412d80:0,0x412e60:0,0x412f40:4,
                    0x40e170:8,0x40e2d0:4,0x40e450:4,0x417170:0,0x403270:8,0x4034e0:0]
                for h in section.helpers {
                    guard pops[h.entry] == h.pop,h.returnSP == h.entrySP+4+h.pop,h.saved.count == 4 else { throw error("Control helper ABI") }
                    if h.entry == 0x413080 { guard h.arguments == [phase,mode],actors[h.this] != nil else { throw error("Own control caller arguments") } }
                    helpers += 1
                }
                let expected = section.checkpoints.filter { $0.pc == 0x41e364 }
                let actorCalls = section.helpers.filter { $0.entry == 0x413080 }
                guard expected.count == actorCalls.count else { throw error("Control checkpoint count") }
                var seen = 0
                let controlWorld = state.world
                try OriginalWorldControl.apply(state: &state,observe: { _,_ in throw error("Unexpected first control event") },afterActorControl: { slot,actor in
                    guard seen < expected.count,expected[seen].label == "control-return",expected[seen].slot == slot else { throw error("Control slot order") }
                    let ownIndex = try controlWorld.integer(at: 0x194+slot*4,as: UInt32.self)
                    guard actors[actorCalls[seen].this] == ownIndex else { throw error("Control Actor binding") }
                    var r = try storage(expected[seen].actor)
                    guard let o = objects[try r.integer(at: 0x368,as: UInt32.self)] else { throw error("Control Object binding") };try r.write(o,at: 0x368)
                    try check(actor,r,"own control Actor\(slot)");seen += 1
                })
                guard seen == expected.count else { throw error("Missing Actor control") };controlSlots = seen
                try snapshot(state,section.after,"own control after")
                if gameplayPhysics {
                    let section = control.cases[1]
                    guard section.end.pc == 0x41eed1,section.end.sp == 0x1000e9bc,section.readsBeforeWrites.isEmpty else { throw error("Physics boundary/provenance") }
                    try snapshot(state,section.before,"own physics before")
                    let returns = section.checkpoints.filter { $0.pc == 0x41e657 }
                    guard section.helpers.count == 2,returns.count == 2 else { throw error("Own first physics helper count") }
                    for h in section.helpers {
                        guard h.entry == 0x40e490,h.pop == 0,h.returnSP == h.entrySP+4,h.saved.count == 4,h.arguments.isEmpty else { throw error("Physics helper ABI") };helpers += 1
                    }
                    let physicsWorld = state.world
                    var seen = 0
                    try OriginalWorldPhysics.apply(state: &state,observe: { _ in throw error("Unexpected first physics event") },afterActorPhysics: { slot,actor in
                        guard seen < returns.count,returns[seen].slot == slot,returns[seen].label == "physics-return",
                              actors[section.helpers[seen].this] == (try physicsWorld.integer(at: 0x194+slot*4,as: UInt32.self)) else { throw error("Physics slot order/binding") }
                        var r = try storage(returns[seen].actor)
                        guard let o = objects[try r.integer(at: 0x368,as: UInt32.self)] else { throw error("Physics Object binding") };try r.write(o,at: 0x368)
                        try check(actor,r,"own physics Actor\(slot)");seen += 1
                    })
                    guard seen == returns.count else { throw error("Missing Actor physics") };physicsSlots = seen
                    try snapshot(state,section.after,"own physics after")
                    if let links {
                        let section = links.cases[0]
                        guard section.end.pc == 0x41eed8,section.end.sp == 0x1000e9bc,section.readsBeforeWrites.isEmpty,
                              section.helpers.map(\.entry) == [0x4450d0,0x4450d0,0x417f80],section.helpers.last?.this == c.worldAddress else { throw error("Depth/links boundary and helpers") }
                        for h in section.helpers {
                            guard h.pop == 0,h.returnSP == h.entrySP+4,h.arguments.isEmpty,h.saved.count == 4 else { throw error("Depth/links helper ABI") };helpers += 1
                        }
                        try snapshot(state,section.before,"own depth/links before")
                        let checkpoints = section.checkpoints
                        guard checkpoints.count == 2 else { throw error("Own depth checkpoint count") }
                        var seen = 0
                        try OriginalWorldLinks.apply(state: &state,observe: { _ in throw error("Unexpected own first attachment event") },afterDepth: { slot,actor in
                            guard seen < checkpoints.count,checkpoints[seen].pc == 0x41800e,checkpoints[seen].label == "depth-return",checkpoints[seen].slot == slot else { throw error("Depth slot order") }
                            var r = try storage(checkpoints[seen].actor)
                            guard let o = objects[try r.integer(at: 0x368,as: UInt32.self)] else { throw error("Depth Object binding") };try r.write(o,at: 0x368)
                            try check(actor,r,"own depth Actor\(slot)");seen += 1
                        })
                        guard seen == checkpoints.count else { throw error("Missing depth Actor") };depthSlots = seen
                        try snapshot(state,section.after,"own depth/links after")
                    }
                }
            }
        }
        guard callbacks == 1 else { throw error("Own selection callback") }
        return .init(parent:parent,cases:c.cases.count,records:records,bytes:bytes,events:events,helpers:helpers,checkpoints:checkpoints,controlSlots:controlSlots,physicsSlots:physicsSlots,depthSlots:depthSlots)
    }
}
