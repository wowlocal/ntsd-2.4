import Foundation
import NTSDCore

public enum MenuCycleReference {
    public struct Result {
        public let parent: MenuReturnReference.Result
        public let cases: Int,records: Int,bytes: Int,events: Int,checkpoints: Int,returns: Int
    }
    typealias Snapshot = InputControlReference.Snapshot
    typealias Storage = MenuStartupReference.Storage
    typealias Retained = MenuStartupReference.Retained
    typealias Position = MenuStartupReference.Position
    struct Prefix: Decodable {
        let after: Snapshot,paused: Int32,phase: UInt32,commands: [UInt8],playback: [UInt8],end: Position
    }
    struct Case: Decodable {
        let label: String,stimulus: [InputControlReference.GlobalWrite],before: Snapshot,earlyBefore: Retained
        let prefix: Prefix,local: MenuStartupReference.Local,inputControl: InputControlReference.Case
        let replay: MenuStartupReference.Replay,round: MenuStartupReference.Round,music: MenuStartupReference.Music?,resources: MenuStartupReference.Resources?
        let mode: ModeScreenReference.Case?,returned: MenuReturnReference.Case?,after: Snapshot,earlyAfter: Retained,end: Position
    }
    private struct Corpus: Decodable {
        let exeSHA256: String,dllSHA256: String,parent: InputControlReference.Parent,worldAddress: UInt32
        let actorAddresses: [UInt32],objectAddresses: [UInt32],cases: [Case],blobs: [String:InputControlReference.Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu cycle reference: "+text) }
    public static func compare(cycle: Data,returning: Data,screen: Data,startup: Data,menu: Data,loading: Data,catalog: Data,sounds: Data, arithmeticPrecision: OriginalArithmeticPrecision = .bits64,
        onLast: ((OriginalMatchPreparation,OriginalInputControlContext,OriginalCRTRandom,OriginalMusicMemory,OriginalMenuResourceLoading) throws -> Void)? = nil) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(cycle,maximumCount: 128_000_000))
        let initial = try JSONDecoder().decode(MenuStartupReference.Corpus.self,from: MatchPreparationReference.unpack(startup,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.parent.sha256 == MatchPreparationReference.digest(returning),c.worldAddress == 0x22000020,
              c.actorAddresses == initial.actorAddresses,c.objectAddresses == initial.objectAddresses,
              c.actorAddresses.count == 400,c.objectAddresses.count == 137,c.cases.count == 4 else { throw error("Source/parent identity") }
        var portion: Portion?,callbacks = 0
        let parent = try MenuReturnReference.compare(returning: returning,screen: screen,startup: startup,menu: menu,loading: loading,catalog: catalog,sounds: sounds,arithmeticPrecision: arithmeticPrecision) { own,context,crt,music,resources in
            callbacks += 1
            let result = try compareCases(actorAddresses: c.actorAddresses,objectAddresses: c.objectAddresses,worldAddress: c.worldAddress,initial: initial,cases: c.cases,blobs: c.blobs,
                state: own,context: context,crt: crt,music: music,resources: resources,parentSequence: true)
            portion = result
            try onLast?(result.state,result.context,crt,result.music,result.resources)
        }
        guard callbacks == 1,let p = portion,p.returns == 3 else { throw error("Own parent/return completion") }
        return .init(parent: parent,cases: p.cases,records: p.records,bytes: p.bytes,events: p.events,checkpoints: p.checkpoints,returns: p.returns)
    }
    struct Portion {
        let state: OriginalMatchPreparation,context: OriginalInputControlContext,music: OriginalMusicMemory,resources: OriginalMenuResourceLoading
        /// Own round outputs survive the intervening gameplay stages. The
        /// result recorder must consume these, never source stack snapshots.
        let roundResults: [OriginalMatchRoundResult]
        let cases: Int,records: Int,bytes: Int,events: Int,checkpoints: Int,returns: Int
    }
    /// Same whole-call comparisons on retained state; new callers supply their
    /// acquired keyboard bytes before entry, never expected Actor/menu records.
    static func compareCases(actorAddresses: [UInt32],objectAddresses: [UInt32],worldAddress: UInt32,initial: MenuStartupReference.Corpus,
        cases items: [Case],blobs sourceBlobs: [String:InputControlReference.Blob],state own: OriginalMatchPreparation,context initialContext: OriginalInputControlContext,
        crt: OriginalCRTRandom,music initialMusic: OriginalMusicMemory,resources initialResources: OriginalMenuResourceLoading,parentSequence: Bool = false,
        replayAddresses: [UInt32] = [],gameplay: Bool = false) throws -> Portion {
        let c = (actorAddresses: actorAddresses,objectAddresses: objectAddresses,worldAddress: worldAddress,cases: items,blobs: sourceBlobs)
        var state = own,context = initialContext,musicMemory = initialMusic,loader = initialResources
        var roundResults: [OriginalMatchRoundResult] = []
        let actors = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objects = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let surfaces = Dictionary(uniqueKeysWithValues: initial.resources.allocations.enumerated().map { ($0.element.address,initial.resources.inputs[$0.offset].surface) })
        var cache: [String:[UInt8]] = [:],records = 0,bytes = 0,events = 0,checkpoints = 0,cases = 0,returns = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            guard let b = c.blobs[key] else { throw error("Missing blob") }
            let raw = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 8_000_000)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob SHA") };cache[key] = raw;return raw
        }
        func storage(_ s: Storage) throws -> OriginalStateRecord {
            let raw = try blob(s.bytes),mask = try blob(s.defined)
            guard raw.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Mask extent") }
            return try .init(bytes: raw,defined: mask.map { $0 != 0 })
        }
        func defined(_ key: String) throws -> OriginalStateRecord {
            let raw = try blob(key);return try .init(bytes: raw,defined: [Bool](repeating: true,count: raw.count))
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
                guard let a = actors[try raw.integer(at: 0x194+i*4,as: UInt32.self)] else { throw error("World Actor") }
                try result.write(a,at: 0x194+i*4)
            };return result
        }
        func actor(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var result = raw
            guard raw.bytes.count == 0x420,let o = objects[try raw.integer(at: 0x368,as: UInt32.self)] else { throw error("Actor Object") }
            try result.write(o,at: 0x368);return result
        }
        func snapshot(_ state: OriginalMatchPreparation,_ context: OriginalInputControlContext,_ expected: Snapshot,_ label: String) throws {
            let raw = try blob(expected.poolBytes),mask = try blob(expected.poolMask)
            guard raw.count == 0x7d8+400*0x420,raw.count == mask.count,mask.allSatisfy({ $0 < 2 }),expected.memory.count == replayAddresses.count else { throw error("Pool/replay extent") }
            func part(_ at: Int,_ count: Int) throws -> OriginalStateRecord { try .init(bytes: Array(raw[at..<at+count]),defined: mask[at..<at+count].map { $0 != 0 }) }
            try check(state.world,world(part(0,0x7d8)),label+" World")
            for i in 0..<400 { try check(state.actors[i],actor(part(0x7d8+i*0x420,0x420)),label+" Actor\(i)") }
            try check(state.globals,defined(expected.globals),label+" globals")
            try check(context.savedPlayback,defined(expected.saved),label+" saved playback")
            try check(context.memory.replayPointers,defined(expected.pointers),label+" replay pointers")
            for (address,m) in zip(replayAddresses,expected.memory) {
                guard let own = context.memory.allocations[address],own.live == m.live else { throw error("Replay ownership") }
                try check(own.storage,.init(bytes: blob(m.bytes),defined: blob(m.defined).map { $0 != 0 }),label+" replay storage")
            }
        }
        func pool(_ state: OriginalMatchPreparation,_ expected: MenuStartupReference.Pool,_ label: String) throws {
            guard expected.actors.count == 400 else { throw error("Local pool extent") }
            try check(state.world,world(storage(expected.world)),label+" World");try check(state.globals,defined(expected.globals),label+" globals")
            for i in 0..<400 { try check(state.actors[i],actor(storage(expected.actors[i])),label+" Actor\(i)") }
        }
        func retained(_ state: OriginalMatchPreparation,_ context: OriginalInputControlContext,_ crt: OriginalCRTRandom,_ expected: Retained,_ label: String) throws {
            try check(state.world,world(storage(expected.world)),label+" early World");try check(state.globals,defined(expected.globals),label+" early globals")
            guard crt.state == expected.crtState,context.memory.allocations.count == expected.records.count+replayAddresses.count,context.memory.replayPointers.bytes == expected.pointers else { throw error("Early ownership/CRT") }
            for r in expected.records {
                guard let a = context.memory.allocations[r.address],a.live == r.live else { throw error("Early bitmap ownership") }
                try check(a.storage,storage(r.storage),label+" early bitmap")
            }
        }
        for (i,item) in c.cases.enumerated() {
            try snapshot(state,context,item.before,item.label+" before");try retained(state,context,crt,item.earlyBefore,item.label+" before")
            guard item.stimulus.count == (parentSequence && (i == 1 || i == 3) ? 1 : 0) else { throw error("Acquired input sequence") }
            if let w = item.stimulus.first {
                let status = try state.globals.integer(at: 0x450b4c-0x44d000,as: Int32.self)
                guard (1...4).contains(status) else { throw error("Own player config") }
                let config = 0x44fb20+Int(status)*80
                guard try state.globals.integer(at: config-0x44d000,as: Int32.self) == 0 else { throw error("Keyboard device") }
                let key = try state.globals.integer(at: config+20-0x44d000,as: UInt32.self)
                guard key < 300,w.address == 0x455378+key,w.bytes == (i == 1 ? "64" : "75") else { throw error("Own attack key") }
                try state.globals.write(UInt8(i == 1 ? 100 : 117),at: Int(w.address)-0x44d000)
            }
            let local = item.local,control = item.inputControl,replay = item.replay,round = item.round
            guard local.parent,local.natural,local.paused == 0,local.dispatch.isEmpty,control.inherited,control.paused == 0,
                  control.stimulus.globals.isEmpty,control.stimulus.actors.isEmpty,control.stimulus.world.isEmpty,control.stimulus.seats.isEmpty,
                  control.stimulus.buffers.isEmpty,control.stimulus.saved == nil,control.stimulus.pointers == nil,control.stimulus.live == nil,control.stimulus.commands == nil,control.stimulus.playback == nil,
                  replay.inherited,replay.paused == 0,replay.kind == "finish",replay.entry == .recording,replay.calls.count == (gameplay ? 1 : 0),
                  round.inherited,round.paused == 0,round.calls.isEmpty,round.continuation == (gameplay ? .gameplay : .menu) else { throw error("Own stage continuity") }
            var phaseIndex = 0,controlIndex = 0,replayIndex = 0,roundIndex = 0,asyncIndex = 0,ioctlIndex = 0,prologues = 0
            let order: [OriginalLoadedMatchEntry.Checkpoint] = [.localBeforeDispatch,.local,.control,.received,.replay,.round]
            let outcome = try OriginalLoadedMatchCycle.run(state: &state,context: &context,controlBoundary: { request in
                guard controlIndex < control.events.count else { throw error("Unexpected control request") }
                let e = control.events[controlIndex];controlIndex += 1;events += 1
                guard request == .init(e.kind,e.arguments,e.data) else { throw error("Control request order") }
                let response: OriginalInputControlResponse
                switch request.kind {
                case .asyncSelect:
                    guard asyncIndex < control.platform.asyncResults.count else { throw error("Async boundary") }
                    response = .init(result: control.platform.asyncResults[asyncIndex]);asyncIndex += 1
                case .ioctl:
                    guard ioctlIndex < control.platform.ioctlResults.count else { throw error("Ioctl boundary") }
                    response = .init(result: control.platform.ioctlResults[ioctlIndex],bytes: ioctlIndex == 1 ? control.platform.ioctlBytes : []);ioctlIndex += 1
                default:throw error("Unexpected control child in own menu cycle")
                }
                guard e.response == response else { throw error("Supplied control response") };return response
            },replayEvent: { event in
                guard replayIndex < replay.events.count,event == replay.events[replayIndex] else { throw error("Replay event") };replayIndex += 1;events += 1
            },roundEvent: { event in
                guard roundIndex < round.events.count,event == round.events[roundIndex] else { throw error("Round event") };roundIndex += 1;events += 1
            },prologue: { value,owned,paused,commands,playback in
                prologues += 1;checkpoints += 1
                guard !paused,item.prefix.paused == 0,(!parentSequence || item.prefix.phase == (i%2 == 0 ? 0 : 1)),
                      try value.globals.integer(at: 0x450b90-0x44d000,as: UInt32.self) == item.prefix.phase,
                      commands == item.prefix.commands,playback == item.prefix.playback,commands == local.commandsBefore,
                      item.prefix.end.pc == 0x41c581,item.prefix.end.sp == 0x1000e9bc else { throw error("Own prologue") }
                try snapshot(value,owned,item.prefix.after,item.label+" prologue")
            },checkpoint: { phase,value,owned,commands in
                guard phaseIndex < order.count,phase == order[phaseIndex],commands == local.commandsAfter else { throw error("Entry order/commands") }
                phaseIndex += 1;checkpoints += 1
                switch phase {
                case .localBeforeDispatch:try pool(value,local.beforeDispatch,"Before AI")
                case .local:try pool(value,local.after,"Local")
                case .control:
                    try snapshot(value,owned,control.control,"Control")
                    guard commands == control.controlCommands,try value.globals.integer(at: 0x44d020-0x44d000,as: UInt32.self) == control.menuRegister else { throw error("Control cached menu") }
                case .received:try snapshot(value,owned,control.after,"Received")
                case .replay:try snapshot(value,owned,replay.after,"Replay")
                case .round:try snapshot(value,owned,round.after,"Round")
                }
            })
            guard prologues == 1,phaseIndex == order.count,controlIndex == control.events.count,replayIndex == replay.events.count,roundIndex == round.events.count,
                  outcome.continuation == round.continuation,outcome.stageDefeated == round.stageDefeated,
                  control.events.count == (item.prefix.phase == 0 ? 4 : 0),control.helperCalls.isEmpty,control.receiveCalls.count == 1 else { throw error("Cycle stage completion") }
            roundResults.append(outcome)
            let sp: UInt32 = 0x1000e9bc,received = control.receiveCalls[0]
            guard local.call.entrySP == sp-16,local.call.returnAddress == 0x41c5e5,local.call.saved.count == 4,local.stackAfter == sp,local.endPC == 0x41c5e5,
                  local.call.arguments == [item.prefix.phase,try state.globals.integer(at: 0x451160-0x44d000,as: UInt32.self),sp+0x434],
                  received.entry == 0x4198f0,received.entrySP == sp-16,received.returnAddress == 0x41d495,received.returnSP == sp,received.saved.count == 4,
                  received.arguments == [0x44f198,item.prefix.phase,sp+0x434],control.endPC == 0x41d5db,replay.endPC == 0x41d714,round.endPC == (gameplay ? 0x41e339 : 0x4229cc),
                  control.stackBefore == control.stackAfter,control.stackAfter == replay.stackBefore,replay.stackBefore == replay.stackAfter,
                  replay.stackAfter == round.stackBefore,round.stackBefore == round.stackAfter else { throw error("Repeated caller ABI/stack") }
            if gameplay {
                let call = replay.calls[0]
                guard call.entry == 0x43db40,call.entrySP == sp-8,call.returnSP == sp-4,call.returnAddress == 0x41d613,
                      call.argument == sp+0x434,call.saved.count == 4 else { throw error("Own recording ret4") }
                guard item.music == nil,item.resources == nil,item.mode == nil,item.returned == nil,item.end.pc == 0x41e339,item.end.sp == sp else { throw error("Own gameplay continuation") }
                try snapshot(state,context,item.after,item.label+" after");try retained(state,context,crt,item.earlyAfter,item.label+" after");cases += 1
                continue
            }
            guard let music = item.music,let resources = item.resources else { throw error("Menu continuation resources") }
            guard music.kind == "menu",music.inherited,music.stimulus.isEmpty,music.events.isEmpty,music.calls.isEmpty,music.formats.isEmpty,
                  music.endPC == 0x4297ae,music.endSP == 0x1000df08 else { throw error("Retained music entry") }
            try OriginalMusicPlayback.enterMenu(globals: &state.globals,memory: &musicMemory,request: { _ in throw error("Unexpected music request") })
            try check(state.globals,defined(music.afterGlobals),"Music globals");checkpoints += 1
            guard musicMemory.allocations.count == music.allocations.count else { throw error("Music inventory") }
            for a in music.allocations {
                guard let own = musicMemory.allocations[a.address] else { throw error("Music ownership") };try check(own,storage(a.storage),"Music bytes")
            }
            guard resources.inherited,resources.stimulus.isEmpty,resources.allocations.isEmpty,resources.inputs.isEmpty,resources.calls.isEmpty,resources.events.isEmpty,
                  resources.endPC == 0x429e5a,resources.endSP == 0x1000df08 else { throw error("Retained resource entry") }
            var pointIndex = 0
            let result = try loader.load(globals: &state.globals,allocate: { _ in throw error("Unexpected menu allocation") },source: { _,_ in throw error("Unexpected bitmap load") },
                deviceResult: { _ in throw error("Unexpected bitmap device request") },checkpoint: { point,globals,_ in
                    guard pointIndex < resources.checkpoints.count else { throw error("Resource checkpoint count") }
                    let p = resources.checkpoints[pointIndex];pointIndex += 1;checkpoints += 1
                    guard point == .init(p.kind,index: p.index),p.records.isEmpty else { throw error("Resource checkpoint") }
                    try check(globals,defined(p.globals),"Retained resource globals")
                },observe: { _ in throw error("Unexpected resource event") })
            guard result.continuation == .ready,result.continuation == resources.continuation,result.selectionAtEntry == resources.selectionAtEntry,
                  pointIndex == resources.checkpoints.count,loader.bitmaps.count == resources.records.count else { throw error("Resource completion") }
            try check(state.globals,defined(resources.globals),"Menu dispatch globals")
            for r in resources.records {
                guard let own = loader.bitmaps[r.address],let surface = surfaces[r.address] else { throw error("Menu bitmap ownership") }
                var raw = try storage(r.storage)
                guard try raw.integer(at: 0,as: UInt32.self) == surface else { throw error("Original bitmap surface") }
                try raw.write(UInt32(surface == 0 ? 0 : 1),at: 0);try check(own.storage,raw,"Retained menu bitmap")
            }
            if try state.globals.integer(at: 0x44d020-0x44d000,as: Int32.self) == 10 {
                guard let mode = item.mode,let returning = item.returned,mode.inherited,mode.stimulus.isEmpty,mode.backgrounds.isEmpty,returning.inherited,returning.stimulus.isEmpty else { throw error("Whole mode caller") }
                let m = try ModeScreenReference.compareCases(objectAddresses: c.objectAddresses,actorAddresses: c.actorAddresses,worldAddress: c.worldAddress,sources: [],cases: [mode],blobs: c.blobs,state: state,context: context,crt: crt)
                state = m.state;context = m.context;records += m.records;bytes += m.bytes;events += m.events
                let r = try MenuReturnReference.compareCases(actorAddresses: c.actorAddresses,objectAddresses: c.objectAddresses,cases: [returning],blobs: c.blobs,state: state,context: context,crt: crt)
                state = r.state;context = r.context;records += r.records;bytes += r.bytes;events += r.events;checkpoints += r.checkpoints;returns += 1
                guard item.end.pc == 0x30000000,item.end.sp == 0x1000f42c else { throw error("Whole outer return") }
            } else {
                guard (!parentSequence || i == 3),item.mode == nil,item.returned == nil,item.end.pc == 0x429e5a,item.end.sp == 0x1000df08,
                      try (parentSequence ? [3] : [1,3]).contains(state.globals.integer(at: 0x44d020-0x44d000,as: Int32.self)) else { throw error("Own next selection entry") }
            }
            try snapshot(state,context,item.after,item.label+" after");try retained(state,context,crt,item.earlyAfter,item.label+" after");cases += 1
        }
        return .init(state: state,context: context,music: musicMemory,resources: loader,roundResults: roundResults,cases: cases,records: records,bytes: bytes,events: events,checkpoints: checkpoints,returns: returns)
    }
}
