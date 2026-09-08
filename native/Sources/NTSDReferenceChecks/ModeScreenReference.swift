import Foundation
import NTSDCore

public enum ModeScreenReference {
    public struct Result {
        public let parent: MenuStartupReference.Result
        public var cases = 0, events = 0, helpers = 0, records = 0, bytes = 0, draws = 0, keys = 0, backgrounds = 0, playback = 0
    }
    typealias Blob = InputControlReference.Blob
    typealias Snapshot = InputControlReference.Snapshot
    struct Storage: Decodable { let bytes: String, defined: String }
    struct Retained: Decodable {
        struct Record: Decodable { let address: UInt32, live: Bool, storage: Storage }
        let globals: String, world: Storage, crtState: UInt32, pointers: [UInt8], records: [Record]
    }
    struct Background: Decodable {
        struct Allocation: Decodable { let address: UInt32, backing: String? }
        struct Input: Decodable { let resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32 }
        let allocation: Allocation, input: Input?
    }
    struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32, result: UInt32 }
    struct Input: Decodable {
        let dcResult: Int32, dc: UInt32, methodResult: Int32, drawResults: [Int32], shellResult: UInt32, milliseconds: UInt32
        var body: OriginalFrontScreenBodyInput { .init(dcResult: dcResult,dc: dc,methodResult: methodResult,drawResults: drawResults,shellResult: shellResult) }
    }
    struct Case: Decodable {
        let label: String, inherited: Bool, stimulus: [InputControlReference.GlobalWrite], input: Input
        let backing: String, local: Storage, fills: [String], backgrounds: [Background], events: [OriginalFrontScreenEvent], helpers: [Helper]
        let continuation: OriginalModeScreenExit, endPC: UInt32, endSP: UInt32, saved: [UInt32], before: Snapshot, after: Snapshot, earlyBefore: Retained, earlyAfter: Retained
    }
    struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, parent: InputControlReference.Parent, worldAddress: UInt32, actorAddresses: [UInt32], localAddress: UInt32
        let cases: [Case], sources: [Source], blobs: [String:Blob]
    }
    struct Startup: Decodable { let objectAddresses: [UInt32], actorAddresses: [UInt32] }
    private static func error(_ s: String) -> OriginalStateError { .invalidStorage("Mode screen reference: "+s) }
    public static func compare(screen: Data,startup: Data,menu: Data,loading: Data,catalog: Data,sounds: Data,
        onFirst: ((OriginalMatchPreparation,OriginalInputControlContext,OriginalCRTRandom,OriginalMusicMemory,OriginalMenuResourceLoading) throws -> Void)? = nil) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(screen,maximumCount: 128_000_000))
        let metadata = try JSONDecoder().decode(Startup.self,from: MatchPreparationReference.unpack(startup,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.parent.sha256 == MatchPreparationReference.digest(startup),c.worldAddress == 0x22000020,c.localAddress == 0x1000d7ec,
              c.actorAddresses == metadata.actorAddresses,c.actorAddresses.count == 400,!c.cases.isEmpty else { throw error("Source/parent identity") }
        var result: Portion?,callbacks = 0
        let parent = try MenuStartupReference.compare(startup: startup,menu: menu,loading: loading,catalog: catalog,sounds: sounds) { own,context,crt,music,resources in
            callbacks += 1
            result = try compareCases(objectAddresses: metadata.objectAddresses,actorAddresses: c.actorAddresses,worldAddress: c.worldAddress,sources: c.sources,cases: c.cases,blobs: c.blobs,state: own,context: context,crt: crt) { state,context in
                try onFirst?(state,context,crt,music,resources)
            }
        }
        guard callbacks == 1,let portion = result else { throw error("Missing own parent") }
        return .init(parent: parent,cases: portion.cases,events: portion.events,helpers: portion.helpers,records: portion.records,bytes: portion.bytes,draws: portion.draws,keys: portion.keys,backgrounds: portion.backgrounds,playback: portion.playback)
    }

    struct Portion {
        let state: OriginalMatchPreparation,context: OriginalInputControlContext
        var cases = 0, events = 0, helpers = 0, records = 0, bytes = 0, draws = 0, keys = 0, backgrounds = 0, playback = 0
    }
    /// Reuses the same checks on a caller's own state; snapshots remain comparisons.
    static func compareCases(objectAddresses: [UInt32],actorAddresses: [UInt32],worldAddress: UInt32,sources: [Source],cases items: [Case],blobs sourceBlobs: [String:Blob],
        state initial: OriginalMatchPreparation,context initialContext: OriginalInputControlContext,crt: OriginalCRTRandom,
        onFirst: ((OriginalMatchPreparation,OriginalInputControlContext) throws -> Void)? = nil) throws -> Portion {
        let c = (actorAddresses: actorAddresses,worldAddress: worldAddress,sources: sources,cases: items,blobs: sourceBlobs)
        var state = initial,context = initialContext
        let objects = Dictionary(uniqueKeysWithValues: objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let actors = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let helperReturns: [UInt32:Set<UInt32>] = [
            0x415160:[0x431d77],0x423840:[0x431d88],0x43ee50:[0x4238e6],0x4236d0:[0x431d90],
            0x401290:[0x431ee3,0x431f06,0x431f2d,0x431f86,0x43203e,0x4320ed,0x432982],
            0x43f010:[0x431daa,0x431dcb,0x43215f,0x43218a,0x4321ae,0x4321d2,0x4321f6,0x43221a,0x43223e,0x432265,0x432286,0x4322ad,0x432931,0x4329ea],
            0x43ef70:[0x43f0d5,0x43f212],0x401a30:[0x431fb1,0x432069,0x432118,0x432349],0x431b70:[0x4322b6],
            0x423910:[0x43238d,0x4323c7,0x4323f7,0x432427,0x432461,0x43248f],0x43ef50:[0x42391f],
            0x4019b0:[0x4328e9],0x423b00:[0x432907],0x422b00:[0x432959]
        ]
        var blobs: [String:[UInt8]] = [:], cached: [String:OriginalStateRecord] = [:]
        var cases = 0,events = 0,helpers = 0,records = 0,bytes = 0,draws = 0,keys = 0,backgrounds = 0,playback = 0
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
        for (i,item) in c.cases.enumerated() {
            guard i != 0 || (item.inherited && item.stimulus.isEmpty) else { throw error("Own first screen entry") }
            for w in item.stimulus {
                let chars = Array(w.bytes)
                guard chars.count%2 == 0 else { throw error("Stimulus extent") }
                var raw: [UInt8] = []
                for j in stride(from: 0,to: chars.count,by: 2) {
                    guard let b = UInt8(String(chars[j...j+1]),radix:16) else { throw error("Stimulus hex") };raw.append(b)
                }
                if w.address >= 0x44d000 && UInt64(w.address)+UInt64(raw.count) <= 0x458440 {
                    for (j,b) in raw.enumerated() { try state.globals.write(b,at: Int(w.address)-0x44d000+j) }
                } else {
                    guard let index = c.actorAddresses.firstIndex(where: { $0 <= w.address && UInt64(w.address)+UInt64(raw.count) <= UInt64($0)+0x420 }) else { throw error("Actor stimulus ownership") }
                    for (j,b) in raw.enumerated() { try state.actors[index].write(b,at: Int(w.address-c.actorAddresses[index])+j) }
                }
            }
            try snapshot(state,context,item.before,item.label+" before");try retained(state,context,crt,item.earlyBefore,item.label+" before")
            guard try OriginalModeScreen.selectsModeScreen(globals: &state.globals),item.fills.count == 1,!item.input.drawResults.isEmpty else { throw error("Mode caller") }
            var local = try OriginalStateRecord(bytes: blob(item.backing),defined: [Bool](repeating: false,count: 0x704))
            var eventIndex = 0,backgroundIndex = 0,blits = 0
            func event(_ e: OriginalFrontScreenEvent) throws {
                guard eventIndex < item.events.count,e == item.events[eventIndex] else { throw error(item.label+" event\(eventIndex) actual \(e), expected \(eventIndex < item.events.count ? String(describing:item.events[eventIndex]) : "end")") }
                eventIndex += 1;events += 1
                if e.kind == "draw" { draws += 1 };if e.kind == "keyName" { keys += 1 }
            }
            let end = try OriginalModeScreen.advance(state: &state,memory: &context.memory,local: &local,worldAddress: c.worldAddress,target: 0x28002020,
                input: item.input.body,fillBacking: blob(item.fills[0]),background: { globals,memory in
                    guard backgroundIndex < item.backgrounds.count else { throw error("Unexpected background") }
                    let b = item.backgrounds[backgroundIndex];backgroundIndex += 1;backgrounds += 1
                    guard let input = b.input,let source = c.sources.first(where: { $0.path == input.resource.path }) else { throw error("Background source") }
                    let dib = try defined(source.dib)
                    guard dib.bytes.count >= 40,try dib.integer(at: 4,as: Int32.self) == source.width,try dib.integer(at: 8,as: Int32.self) == source.height,
                          input.resource.width == source.width,input.resource.height == source.height else { throw error("Source DIB") }
                    let result = try OriginalMenuBackground.load(globals: &globals,milliseconds: item.input.milliseconds,allocate: {
                        guard let backing = b.allocation.backing,memory.allocations[b.allocation.address] == nil else { throw error("New background allocation") }
                        return try .init(address: b.allocation.address,backing: blob(backing))
                    },source: { path in
                        guard path == input.resource.path else { throw error("Background name") };return (input.resource,input.surface,input.colorKeyResult)
                    },observe: event)
                    guard let bitmap = result.bitmap else { throw error("Background constructor") }
                    var raw = bitmap.storage;try raw.write(result.surface,at: 0)
                    memory.allocations[result.address] = .init(storage: raw)
                },update: { globals in
                    let result = try OriginalMenuPanelUpdate.run(globals: &globals,content: { _ in throw error("Worker content boundary") },
                        bitmap: { _ in throw error("Worker bitmap boundary") },write: { _,_ in throw error("Worker writer boundary") }) { e,_ in
                            try event(.init(e.kind,e.arguments))
                        }
                    guard result == .ready else { throw error("Panel update completion") }
                },panel: { globals in
                    guard try globals.integer(at: 0x458420-0x44d000,as: UInt32.self) == 0 else { throw error("Enabled optional panel boundary") }
                },draw: { args,globals,memory in
                    guard let allocation = memory.allocations[args[0]],allocation.live else { throw error("Bitmap ownership") }
                    var bitmap = allocation.storage;let surface = try bitmap.integer(at: 0,as: UInt32.self)
                    try bitmap.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                    let request = try OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],mirrored: args[5],
                        sourceSurface: surface,targetSurface: args[6],viewportWidth: globals.integer(at: 0x44d78c-0x44d000,as: Int32.self),viewportHeight: globals.integer(at: 0x44d790-0x44d000,as: Int32.self))
                    _ = try OriginalBitmapDrawing.draw(request,bitmap: bitmap,observeRead: { r in
                        var e = OriginalFrontScreenEvent("read");e.read = r;try event(e)
                    },observeClip: { clip in
                        var e = OriginalFrontScreenEvent("clip");e.clip = clip;try event(e)
                    },perform: { blit in
                        var e = OriginalFrontScreenEvent("blit");e.blit = blit;try event(e)
                        defer { blits += 1 };return item.input.drawResults[blits%item.input.drawResults.count]
                    })
                },observe: event)
            guard end == item.continuation,eventIndex == item.events.count,backgroundIndex == item.backgrounds.count,item.saved.count == 4 else { throw error("Screen completion") }
            if end == .returned { guard item.endPC == 0x429eb7,item.endSP == 0x1000df08 else { throw error("Real ret16") } }
            else { guard item.endPC == 0x43249c,item.endSP == 0x1000d7dc else { throw error("Playback entry") };playback += 1 }
            for h in item.helpers {
                let pop: UInt32 = h.entry == 0x401a30 ? 4 : h.entry == 0x43ee50 ? 12 : h.entry == 0x43f010 ? 24 : 0
                guard h.saved.count == 4,h.pop == pop,h.returnSP == h.entrySP+4+pop,
                      helperReturns[h.entry]?.contains(h.returnPC) == true else { throw error("Child return ABI "+String(h.entry,radix:16)+" to "+String(h.returnPC,radix:16)) }
            }
            helpers += item.helpers.count
            try check(local,storage(item.local),item.label+" locals")
            try snapshot(state,context,item.after,item.label+" after");try retained(state,context,crt,item.earlyAfter,item.label+" after")
            if i == 0 { try onFirst?(state,context) }
            cases += 1
        }
        return .init(state: state,context: context,cases: cases,events: events,helpers: helpers,records: records,bytes: bytes,draws: draws,keys: keys,backgrounds: backgrounds,playback: playback)
    }
}
