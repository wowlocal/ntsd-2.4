import Foundation
import NTSDCore

public enum CharacterScreenReference {
    public struct Result {
        public let parent: MenuCycleReference.Result
        public let cases: Int,events: Int,helpers: Int,records: Int,bytes: Int,draws: Int,checkpoints: Int,returns: Int
    }
    typealias Snapshot = InputControlReference.Snapshot
    typealias Storage = ModeScreenReference.Storage
    typealias Retained = ModeScreenReference.Retained
    struct Point: Decodable {
        let pc: UInt32,sp: UInt32,seat: UInt32,state: Snapshot,locals: [String:Int32]
        private enum CodingKeys: String,CodingKey { case pc,sp,seat,state,locals }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            pc = try c.decode(UInt32.self,forKey: .pc);sp = try c.decode(UInt32.self,forKey: .sp)
            seat = try c.decode(UInt32.self,forKey: .seat);state = try c.decode(Snapshot.self,forKey: .state)
            locals = try c.decode([String:UInt32].self,forKey: .locals).mapValues(Int32.init(bitPattern:))
        }
    }
    struct UndefinedRead: Decodable {
        let kind: String,offset: Int,size: Int,pc: UInt32
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            kind = try c.decode(String.self);offset = try c.decode(Int.self);size = try c.decode(Int.self);pc = try c.decode(UInt32.self)
            guard c.isAtEnd else { throw error("Undefined-read tuple") }
        }
    }
    struct Screen: Decodable {
        let label: String,before: Snapshot,earlyBefore: Retained,input: ModeScreenReference.Input
        let events: [OriginalFrontScreenEvent],helpers: [ModeScreenReference.Helper],checkpoints: [Point],fills: [String]
        let after: Snapshot,earlyAfter: Retained,continuation: OriginalCharacterScreenExit,end: MenuStartupReference.Position
        let readsBeforeWrites: [UndefinedRead]?
    }
    struct Acquired: Decodable { let seat: Int,button: Int,pressed: Bool,address: UInt32,bytes: String }
    struct Case: Decodable { let label: String,before: Snapshot,acquired: [Acquired],cycle: MenuCycleReference.Case?,screen: Screen,returned: MenuReturnReference.Case? }
    struct Corpus: Decodable {
        let exeSHA256: String,dllSHA256: String,parent: InputControlReference.Parent,worldAddress: UInt32
        let actorAddresses: [UInt32],objectAddresses: [UInt32],cases: [Case],blobs: [String:InputControlReference.Blob]
    }
    struct Catalog: Decodable {
        struct Bitmap: Decodable { let address: UInt32 }
        let surfaceAddress: UInt32,bitmaps: [Bitmap]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Character screen reference: "+text) }
    public static func compare(character: Data,cycle: Data,returning: Data,screen: Data,startup: Data,menu: Data,loading: Data,catalog: Data,sounds: Data,requireComplete: Bool = true, arithmeticPrecision: OriginalArithmeticPrecision = .bits64,
        onLast: ((OriginalMatchPreparation,OriginalInputControlContext,OriginalCRTRandom,OriginalMusicMemory,OriginalMenuResourceLoading) throws -> Void)? = nil) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(character,maximumCount: 128_000_000))
        let initial = try JSONDecoder().decode(MenuStartupReference.Corpus.self,from: MatchPreparationReference.unpack(startup,maximumCount: 128_000_000))
        let catalogSource = try JSONDecoder().decode(Catalog.self,from: MatchPreparationReference.unpack(catalog,maximumCount: 192_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.parent.sha256 == MatchPreparationReference.digest(cycle),c.worldAddress == 0x22000020,
              c.actorAddresses == initial.actorAddresses,c.objectAddresses == initial.objectAddresses,
              requireComplete ? c.cases.count == 34 : (1...34).contains(c.cases.count) else { throw error("Source/parent identity") }
        var portion: Portion?,callbacks = 0
        let parent = try MenuCycleReference.compare(cycle: cycle,returning: returning,screen: screen,startup: startup,menu: menu,loading: loading,catalog: catalog,sounds: sounds,arithmeticPrecision: arithmeticPrecision) { own,context,crt,music,resources in
            callbacks += 1
            let result = try compareCases(actorAddresses: c.actorAddresses,objectAddresses: c.objectAddresses,worldAddress: c.worldAddress,initial: initial,catalogSource: catalogSource,
                cases: c.cases,blobs: c.blobs,state: own,context: context,crt: crt,music: music,resources: resources,requireComplete: requireComplete)
            portion = result
            try onLast?(result.state,result.context,crt,result.music,result.resources)
        }
        guard callbacks == 1,let p = portion else { throw error("Own parent completion") }
        return .init(parent: parent,cases: p.cases,events: p.events,helpers: p.helpers,records: p.records,bytes: p.bytes,draws: p.draws,checkpoints: p.checkpoints,returns: p.returns)
    }
    struct Portion {
        let state: OriginalMatchPreparation,context: OriginalInputControlContext,music: OriginalMusicMemory,resources: OriginalMenuResourceLoading
        let cases: Int,events: Int,helpers: Int,records: Int,bytes: Int,draws: Int,checkpoints: Int,returns: Int
    }
    /// Continue the same shared comparison on owned state. Only acquired keyboard
    /// inputs enter the continuation; expected snapshots never seed the engine.
    static func compareCases(actorAddresses: [UInt32],objectAddresses: [UInt32],worldAddress: UInt32,initial: MenuStartupReference.Corpus,catalogSource: Catalog,
        cases items: [Case],blobs sourceBlobs: [String:InputControlReference.Blob],state own: OriginalMatchPreparation,context initialContext: OriginalInputControlContext,
        crt: OriginalCRTRandom,music initialMusic: OriginalMusicMemory,resources initialResources: OriginalMenuResourceLoading,requireComplete: Bool = true,matchSelection: Bool = false) throws -> Portion {
        let c = (actorAddresses: actorAddresses,objectAddresses: objectAddresses,worldAddress: worldAddress,cases: items,blobs: sourceBlobs)
        var state = own,context = initialContext,music = initialMusic,resources = initialResources
        let actors = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objects = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let surfaces = Dictionary(uniqueKeysWithValues: initial.resources.allocations.enumerated().map { ($0.element.address,initial.resources.inputs[$0.offset].surface) })
        let catalogAddresses = Set(catalogSource.bitmaps.map(\.address))
        var blobs: [String:[UInt8]] = [:], cached: [String:OriginalStateRecord] = [:]
        var cases = 0,events = 0,helpers = 0,records = 0,bytes = 0,draws = 0,checkpoints = 0,returns = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value }
            guard let b = c.blobs[key] else { throw error("Missing blob") }
            let value = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 8_000_000)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw error("Blob SHA") };blobs[key] = value;return value
        }
        func storage(_ s: Storage) throws -> OriginalStateRecord {
            let key = s.bytes+s.defined;if let value = cached[key] { return value }
            let raw = try blob(s.bytes),mask = try blob(s.defined)
            guard raw.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Mask extent") }
            let value = try OriginalStateRecord(bytes: raw,defined: mask.map { $0 != 0 });cached[key] = value;return value
        }
        func defined(_ key: String) throws -> OriginalStateRecord {
            if let value = cached[key] { return value }
            let raw = try blob(key),value = try OriginalStateRecord(bytes: raw,defined: [Bool](repeating: true,count: raw.count));cached[key] = value;return value
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if let i = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw error(label+"+"+String(i,radix:16)+" actual \(actual.bytes[i])/\(actual.defined[i]) expected \(expected.bytes[i])/\(expected.defined[i])")
            };records += 1;bytes += actual.bytes.count
        }
        func world(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var result = raw
            guard raw.bytes.count == 0x7d8,try raw.integer(at: 0x7d4,as: UInt32.self) == 0x60000020 else { throw error("World catalog") }
            try result.write(UInt32(0),at: 0x7d4)
            for i in 0..<400 {
                guard let ref = actors[try raw.integer(at: 0x194+i*4,as: UInt32.self)] else { throw error("World Actor") }
                try result.write(ref,at: 0x194+i*4)
            };return result
        }
        func snapshot(_ state: OriginalMatchPreparation,_ context: OriginalInputControlContext,_ value: Snapshot,_ label: String) throws {
            let raw = try blob(value.poolBytes),mask = try blob(value.poolMask)
            guard raw.count == 0x7d8+400*0x420,mask.count == raw.count,value.memory.isEmpty else { throw error("Pool/replay extent") }
            func part(_ at: Int,_ count: Int) throws -> OriginalStateRecord {
                try .init(bytes: Array(raw[at..<at+count]),defined: mask[at..<at+count].map { $0 != 0 })
            }
            try check(state.world,world(part(0,0x7d8)),label+" World")
            for i in 0..<400 {
                var record = try part(0x7d8+i*0x420,0x420)
                guard let ref = objects[try record.integer(at: 0x368,as: UInt32.self)] else { throw error("Actor Object") }
                try record.write(ref,at: 0x368);try check(state.actors[i],record,label+" Actor\(i)")
            }
            try check(state.globals,defined(value.globals),label+" globals")
            try check(context.savedPlayback,defined(value.saved),label+" saved playback")
            try check(context.memory.replayPointers,defined(value.pointers),label+" replay pointers")
        }
        func retained(_ state: OriginalMatchPreparation,_ context: OriginalInputControlContext,_ crt: OriginalCRTRandom,_ expected: Retained,_ label: String) throws {
            try check(state.world,world(storage(expected.world)),label+" early World")
            try check(state.globals,defined(expected.globals),label+" early globals")
            guard context.memory.allocations.count == expected.records.count,crt.state == expected.crtState,
                  context.memory.replayPointers.bytes == expected.pointers else { throw error("Early ownership/CRT") }
            for r in expected.records {
                guard let actual = context.memory.allocations[r.address],actual.live == r.live else { throw error(label+" liveness") }
                try check(actual.storage,storage(r.storage),label+" retained bitmap")
            }
        }
        let catalogBitmaps = state.bitmaps
        guard catalogBitmaps.count == catalogSource.bitmaps.count else { throw error("Owned catalog bitmaps") }
        for (i,item) in c.cases.enumerated() {
            try snapshot(state,context,item.before,item.label+" before input")
            for w in item.acquired {
                guard (0..<8).contains(w.seat),(0..<7).contains(w.button) else { throw error("Acquired seat/button") }
                let status = try state.globals.integer(at: 0x450b4c+w.seat*4-0x44d000,as: Int32.self)
                guard (1...4).contains(status) else { throw error("Own player configuration") }
                let config = 0x44fb20+Int(status)*80
                guard try state.globals.integer(at: config-0x44d000,as: Int32.self) == 0 else { throw error("Keyboard device") }
                let key = try state.globals.integer(at: config+4+w.button*4-0x44d000,as: UInt32.self)
                guard key < 300,w.address == 0x455378+key,w.bytes == (w.pressed ? "64" : "75") else { throw error("Own key binding") }
                try state.globals.write(UInt8(w.pressed ? 100 : 117),at: Int(w.address)-0x44d000)
            }
            if let cycle = item.cycle {
                guard (matchSelection || i > 0),cycle.stimulus.isEmpty,cycle.mode == nil,cycle.returned == nil else { throw error("Whole next caller") }
                let r = try MenuCycleReference.compareCases(actorAddresses: c.actorAddresses,objectAddresses: c.objectAddresses,worldAddress: c.worldAddress,initial: initial,
                    cases: [cycle],blobs: c.blobs,state: state,context: context,crt: crt,music: music,resources: resources)
                state = r.state;context = r.context;music = r.music;resources = r.resources
                records += r.records;bytes += r.bytes;events += r.events;checkpoints += r.checkpoints
            } else { guard !matchSelection,i == 0,item.acquired.isEmpty else { throw error("Own first429e5a") } }
            let item = item.screen
            if let reads = item.readsBeforeWrites {
                // The inherited loader tracker covers catalog allocations.
                // All menu AND catalog reads are compared by draw() below.
                var inCatalog = false,undefinedOffsets: Set<Int> = []
                for e in item.events {
                    if e.kind == "draw" { inCatalog = e.arguments.first.map { catalogAddresses.contains($0) } ?? false }
                    if inCatalog,let r = e.read,!r.defined { undefinedOffsets.insert(r.offset) }
                }
                guard reads.allSatisfy({ $0.kind == "bitmap" && $0.offset == 12 && $0.size == 4 && [0x43f04b,0x43f183].contains($0.pc) }),
                      Set(reads.map(\.offset)) == undefinedOffsets else { throw error("Bitmap read provenance") }
            } else if requireComplete { throw error("Missing renderer read provenance") }
            try snapshot(state,context,item.before,item.label+" screen before");try retained(state,context,crt,item.earlyBefore,item.label+" screen before")
            guard (matchSelection ? !item.fills.isEmpty : item.fills.count == 1),!item.input.drawResults.isEmpty else { throw error("Screen drawing input") }
            var eventIndex = 0,pointIndex = 0,blits = 0,fillIndex = 0
            func fillBacking() throws -> [UInt8] {
                guard fillIndex < item.fills.count else { throw error("Unexpected fill") }
                defer { fillIndex += 1 };return try blob(item.fills[fillIndex])
            }
            func event(_ value: OriginalFrontScreenEvent) throws {
                guard eventIndex < item.events.count,value == item.events[eventIndex] else { throw error(item.label+" event\(eventIndex) actual \(value) expected \(eventIndex < item.events.count ? String(describing:item.events[eventIndex]) : "end")") }
                eventIndex += 1;events += 1
            }
            let selectionAtEntry = try state.globals.integer(at: 0x4512c8-0x44d000,as: UInt32.self)
            func draw(_ request: OriginalCharacterScreenDraw,_ globals: OriginalStateRecord) throws {
                var bitmap: OriginalStateRecord
                let address: UInt32,surface: UInt32
                switch request.bitmap {
                case .menu(let token):
                    address = token
                    if let owned = resources.bitmaps[token],let output = surfaces[token] { bitmap = owned.storage;surface = output }
                    else if let owned = context.memory.allocations[token],owned.live {
                        bitmap = owned.storage;surface = try bitmap.integer(at: 0,as: UInt32.self);try bitmap.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                    } else { throw error("Menu bitmap ownership") }
                case .catalog(let index):
                    guard catalogBitmaps.indices.contains(index) else { throw error("Catalog bitmap ownership") }
                    bitmap = catalogBitmaps[index].storage;address = catalogSource.bitmaps[index].address
                    surface = try bitmap.integer(at: 0,as: UInt32.self) == 0 ? 0 : catalogSource.surfaceAddress
                }
                try event(.init("draw",[address,UInt32(bitPattern: request.x),UInt32(bitPattern: request.y),UInt32(bitPattern: request.frame),request.colorKey,0,request.target]));draws += 1
                let input = try OriginalBitmapDrawInput(x: request.x,y: request.y,frame: request.frame,colorKey: request.colorKey,mirrored: 0,sourceSurface: surface,targetSurface: request.target,
                    viewportWidth: globals.integer(at: 0x44d78c-0x44d000,as: Int32.self),viewportHeight: globals.integer(at: 0x44d790-0x44d000,as: Int32.self))
                _ = try OriginalBitmapDrawing.draw(input,bitmap: bitmap,observeRead: { read in
                    var e = OriginalFrontScreenEvent("read");e.read = read;try event(e)
                },observeClip: { clip in
                    var e = OriginalFrontScreenEvent("clip");e.clip = clip;try event(e)
                },perform: { blit in
                    var e = OriginalFrontScreenEvent("blit");e.blit = blit;try event(e)
                    defer { blits += 1 };return item.input.drawResults[blits%item.input.drawResults.count]
                })
            }
            func checkpoint(_ point: OriginalCharacterScreenCheckpoint,_ value: OriginalMatchPreparation) throws {
                guard pointIndex < item.checkpoints.count else { throw error("Unexpected checkpoint") }
                let p = item.checkpoints[pointIndex];pointIndex += 1;checkpoints += 1
                guard point.pc == p.pc,p.sp == 0x1000df08,p.locals == Dictionary(uniqueKeysWithValues: point.locals.map { (String($0.key),$0.value) }),
                      point.pc != 0x42a25a || point.seat == Int(p.seat) else { throw error(item.label+" checkpoint metadata "+String(point.pc,radix:16)+" actual \(point.locals), expected \(p.locals)") }
                try snapshot(value,context,p.state,item.label+" checkpoint "+String(point.pc,radix:16))
            }
            let end: OriginalCharacterScreenExit
            if matchSelection {
                end = try OriginalMatchSelection.advance(state: &state,selectionAtEntry: selectionAtEntry,target: 0x28002020,input: item.input.body,
                    fillBacking: fillBacking,draw: draw,observe: event,checkpoint: checkpoint)
            } else {
                end = try OriginalCharacterScreen.advance(state: &state,selectionAtEntry: selectionAtEntry,target: 0x28002020,input: item.input.body,
                    fillBacking: fillBacking(),draw: draw,observe: event,checkpoint: checkpoint)
            }
            guard (matchSelection ? [.returned,.matchPrelude].contains(end) : end == .returned),end == item.continuation,
                  item.end.pc == (end == .matchPrelude ? 0x42cf8a : 0x42e0d2),item.end.sp == 0x1000df08,
                  eventIndex == item.events.count,pointIndex == item.checkpoints.count,(matchSelection || pointIndex == 12),fillIndex == item.fills.count else { throw error("Character completion") }
            for h in item.helpers {
                let pop: UInt32 = h.entry == 0x401a30 ? 4 : h.entry == 0x43f010 ? 24 : 0
                let allowed = [0x415160,0x401290,0x401a30,0x43f010,0x43ef70,0x431c70]+(matchSelection ? [0x402130,0x417170] : [])
                guard allowed.contains(Int(h.entry)),h.saved.count == 4,h.pop == pop,h.returnSP == h.entrySP+4+pop,
                      (matchSelection ? (0x42a1d0...0x42e0d2) : (0x42a1d0...0x42b218)).contains(h.returnPC)
                        || [0x43f0d5,0x43f212].contains(h.returnPC) || (matchSelection && [0x40232d,0x402588,0x4025a1].contains(h.returnPC)) else { throw error("Character helper ABI") }
            }
            helpers += item.helpers.count
            try snapshot(state,context,item.after,item.label+" screen after");try retained(state,context,crt,item.earlyAfter,item.label+" screen after")
            if let returning = c.cases[i].returned {
                guard end == .returned,returning.inherited,returning.stimulus.isEmpty else { throw error("Own character return") }
                let r = try MenuReturnReference.compareCases(actorAddresses: c.actorAddresses,objectAddresses: c.objectAddresses,cases: [returning],blobs: c.blobs,state: state,context: context,crt: crt)
                state = r.state;context = r.context;records += r.records;bytes += r.bytes;events += r.events;checkpoints += r.checkpoints;helpers += r.helpers
                returns += 1
            } else { guard matchSelection,end == .matchPrelude,i == c.cases.count-1 else { throw error("Own match-prelude boundary") } }
            cases += 1
        }
        if requireComplete { guard try state.globals.integer(at: 0x451248-0x44d000,as: Int32.self) == 17,
              try state.globals.integer(at: 0x45124c-0x44d000,as: Int32.self) == 21,
              try state.globals.integer(at: 0x451288-0x44d000,as: Int32.self) == 3,
              try state.globals.integer(at: 0x45128c-0x44d000,as: Int32.self) == 3 else { throw error("Selected ready Naruto/Sasuke") } }

        return .init(state: state,context: context,music: music,resources: resources,cases: cases,events: events,helpers: helpers,records: records,bytes: bytes,draws: draws,checkpoints: checkpoints,returns: returns)
    }
}
