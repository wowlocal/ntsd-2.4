import Foundation
import NTSDCore

/// Natural continuation of the own early-menu/loading state to character-menu
/// resources. All snapshots are comparisons; only declared platform replies,
/// allocator backing and the original pre-menu saved-playback region are inputs.
public enum MenuStartupReference {
    public struct Result {
        public let parent: MenuLoadingReference.Result
        public let checkpoints: Int, records: Int, bytes: Int, events: Int
        public let localCalls: Int, receivedCalls: Int, musicCalls: Int, constructors: Int
    }
    typealias Snapshot = InputControlReference.Snapshot
    typealias Blob = InputControlReference.Blob
    struct Storage: Decodable { let bytes: String, defined: String }
    struct Position: Decodable { let pc: UInt32, sp: UInt32 }
    struct Pool: Decodable { let world: Storage, actors: [Storage], globals: String }
    struct Retained: Decodable {
        struct Record: Decodable { let address: UInt32, live: Bool, storage: Storage }
        let globals: String, world: Storage, crtState: UInt32, pointers: [UInt8], records: [Record]
    }
    struct NoStimulus: Decodable {
        struct Key: CodingKey { let stringValue: String;var intValue: Int? { nil };init?(stringValue: String) { self.stringValue=stringValue };init?(intValue: Int) { return nil } }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            for key in c.allKeys where try !c.decodeNil(forKey: key) {
                let list = try c.nestedUnkeyedContainer(forKey: key)
                guard list.isAtEnd else { throw error("Post-loading game-state stimulus") }
            }
        }
    }
    struct Local: Decodable {
        struct Call: Decodable { let entrySP: UInt32, returnAddress: UInt32, arguments: [UInt32], saved: [UInt32] }
        let stimulus: NoStimulus, parent: Bool, natural: Bool, paused: Int32
        let commandsBefore: [UInt8], commandsAfter: [UInt8], call: Call, beforeDispatch: Pool, after: Pool
        let dispatch: [OriginalLocalInputDispatch], stackAfter: UInt32, endPC: UInt32
    }
    struct Control: Decodable {
        struct Call: Decodable { let entry: UInt32, entrySP: UInt32, returnAddress: UInt32, arguments: [UInt32], saved: [UInt32], returnSP: UInt32 }
        let stimulus: NoStimulus, inherited: Bool, paused: Int32, stackBefore: [UInt8], stackAfter: [UInt8]
        let events: [OriginalInputControlRequest], helperCalls: [Call], receiveCalls: [Call]
        let control: Snapshot, after: Snapshot, controlCommands: [UInt8], menuRegister: UInt32, endPC: UInt32
    }
    struct Replay: Decodable {
        struct Call: Decodable { let entry: UInt32,entrySP: UInt32,returnAddress: UInt32,argument: UInt32,saved: [UInt32],returnSP: UInt32 }
        let stimulus: NoStimulus, inherited: Bool, paused: Int32, kind: String, entry: OriginalReplayTickEntry
        let stackBefore: [UInt8], stackAfter: [UInt8], events: [OriginalReplayTickEvent], calls: [Call]
        let menuRegister: UInt32, after: Snapshot, endPC: UInt32
    }
    struct Round: Decodable {
        let stimulus: NoStimulus, inherited: Bool, paused: Int32, stackBefore: [UInt8], stackAfter: [UInt8]
        let events: [OriginalMatchRoundEvent], calls: [Control.Call], stageDefeated: UInt32?
        let continuation: OriginalMatchRoundContinuation, endPC: UInt32, after: Snapshot
    }
    struct Allocation: Decodable { let address: UInt32, storage: Storage }
    struct Music: Decodable {
        struct Event: Decodable { let kind: OriginalMusicEvent.Kind, arguments: [UInt32], strings: [[UInt8]], response: OriginalMusicResponse }
        struct Call: Decodable { let entry: UInt32, entrySP: UInt32, returnAddress: UInt32, saved: [UInt32], returnSP: UInt32 }
        struct Format: Decodable { let result: Int32, bytes: String }
        let kind: String, inherited: Bool, stimulus: [InputControlReference.GlobalWrite]
        let events: [Event], calls: [Call], formats: [Format], allocations: [Allocation], afterGlobals: String, endPC: UInt32, endSP: UInt32
    }
    struct Resources: Decodable {
        struct Input: Decodable { let index: Int, resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32 }
        struct Allocate: Decodable { let address: UInt32, backing: String }
        struct Call: Decodable { let index: Int, address: UInt32, entrySP: UInt32, returnAddress: UInt32, saved: [UInt32], returnSP: UInt32 }
        struct Checkpoint: Decodable { let kind: OriginalMenuResourceCheckpoint.Kind, index: Int, globals: String, records: [Allocation] }
        let inherited: Bool, stimulus: [InputControlReference.GlobalWrite], allocations: [Allocate], inputs: [Input], calls: [Call]
        let events: [OriginalInterfaceEvent], checkpoints: [Checkpoint], records: [Allocation]
        let continuation: OriginalMenuResourceResult.Continuation, selectionAtEntry: UInt32, endPC: UInt32, endSP: UInt32, globals: String
    }
    struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, parents: [String:InputControlReference.Parent], entry: Position, end: Position
        let worldAddress: UInt32, objectAddresses: [UInt32], actorAddresses: [UInt32], savedAtFirstMenu: [UInt8]
        let initialContext: Snapshot, local: Local, inputControl: Control, replay: Replay, round: Round, music: Music, resources: Resources
        let sources: [Source], after: Snapshot, retainedBefore: Retained, retainedAfter: Retained, blobs: [String:Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu startup reference: "+text) }
    public static func compare(startup: Data, menu: Data, loading: Data, catalog: Data, sounds: Data, arithmeticPrecision: OriginalArithmeticPrecision = .bits64,
        onEntry: (OriginalInitialLoading, OriginalInputControlContext, OriginalInitialMatchEntry) throws -> Void = { _,_,_ in },
        onReady: ((OriginalMatchPreparation,OriginalInputControlContext,OriginalCRTRandom,OriginalMusicMemory,OriginalMenuResourceLoading) throws -> Void)? = nil) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(startup,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.worldAddress == 0x22000020,c.entry.pc == 0x41c581,c.entry.sp == 0x1000e9bc,
              c.end.pc == 0x429e5a,c.end.sp == c.entry.sp-0xab4,c.savedAtFirstMenu.count == 0x320,
              c.objectAddresses.count == 137,Set(c.objectAddresses).count == 137,
              c.actorAddresses.count == 400,Set(c.actorAddresses).count == 400 else { throw error("Source/continuous caller identity") }
        for (key,data) in [("menu-loading",menu),("menu-loading-state",loading),("menu-loading-catalog",catalog),("menu-loading-sounds",sounds)] {
            guard c.parents[key]?.sha256 == MatchPreparationReference.digest(data) else { throw error("Pinned own loading "+key) }
        }
        let objects = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let actors = Dictionary(uniqueKeysWithValues: c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        var blobs: [String:[UInt8]] = [:],records = 0,bytes = 0,checkpoints = 0,events = 0,callbacks = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value }
            guard let b = c.blobs[key] else { throw error("Missing blob") }
            let value = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 8_000_000)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw error("Blob SHA") };blobs[key] = value;return value
        }
        func storage(_ s: Storage) throws -> OriginalStateRecord {
            let raw = try blob(s.bytes),mask = try blob(s.defined)
            guard raw.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Storage mask") }
            return try .init(bytes: raw,defined: mask.map { $0 != 0 })
        }
        func defined(_ key: String) throws -> OriginalStateRecord {
            let raw = try blob(key);return try .init(bytes: raw,defined: [Bool](repeating: true,count: raw.count))
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if let i = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw error(label+"+"+String(i,radix:16))
            };records += 1;bytes += actual.bytes.count
        }
        func world(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var value = raw
            guard value.bytes.count == 0x7d8,try value.integer(at: 0x7d4,as: UInt32.self) == 0x60000020 else { throw error("World/catalog") }
            try value.write(UInt32(0),at: 0x7d4)
            for i in 0..<400 {
                guard let a = actors[try value.integer(at: 0x194+i*4,as: UInt32.self)] else { throw error("World/Actor") }
                try value.write(a,at: 0x194+i*4)
            };return value
        }
        func actor(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var value = raw
            guard value.bytes.count == 0x420,let o = objects[try value.integer(at: 0x368,as: UInt32.self)] else { throw error("Actor/Object") }
            try value.write(o,at: 0x368);return value
        }
        func pool(_ state: OriginalMatchPreparation,_ expected: Pool,_ label: String) throws {
            guard expected.actors.count == 400 else { throw error("Local Actor count") }
            try check(state.world,world(storage(expected.world)),label+" World")
            try check(state.globals,defined(expected.globals),label+" globals")
            for (i,r) in expected.actors.enumerated() { try check(state.actors[i],actor(storage(r)),label+" Actor\(i)") }
        }
        func snapshot(_ state: OriginalMatchPreparation,_ context: OriginalInputControlContext,_ expected: Snapshot,_ label: String) throws {
            let raw = try blob(expected.poolBytes),mask = try blob(expected.poolMask)
            guard raw.count == 0x7d8+400*0x420,raw.count == mask.count,mask.allSatisfy({ $0 < 2 }),expected.memory.isEmpty else { throw error("Natural pool/replay inventory") }
            func part(_ offset: Int,_ count: Int) throws -> OriginalStateRecord {
                try .init(bytes: Array(raw[offset..<offset+count]),defined: mask[offset..<offset+count].map { $0 != 0 })
            }
            try check(state.world,world(part(0,0x7d8)),label+" World")
            for i in 0..<400 { try check(state.actors[i],actor(part(0x7d8+i*0x420,0x420)),label+" Actor\(i)") }
            try check(state.globals,defined(expected.globals),label+" globals")
            try check(context.savedPlayback,defined(expected.saved),label+" saved playback")
            try check(context.memory.replayPointers,defined(expected.pointers),label+" replay pointers")
        }
        func retained(_ state: OriginalMatchPreparation,_ memory: OriginalMenuPresentationMemory,_ crt: OriginalCRTRandom,_ expected: Retained) throws {
            try check(state.globals,defined(expected.globals),"Retained globals")
            try check(state.world,world(storage(expected.world)),"Retained World")
            guard memory.allocations.count == expected.records.count,Set(expected.records.map(\.address)).count == expected.records.count,
                  crt.state == expected.crtState,memory.replayPointers.bytes == expected.pointers else { throw error("Retained CRT/ownership") }
            for r in expected.records {
                guard let owned = memory.allocations[r.address],owned.live == r.live else { throw error("Early bitmap liveness") }
                try check(owned.storage,storage(r.storage),"Retained early bitmap")
            }
        }
        let parent = try MenuLoadingReference.compare(menu: menu,loading: loading,catalog: catalog,sounds: sounds,onLoaded: { loaded,crt,earlyMemory in
            callbacks += 1;guard callbacks == 1,!loaded.paused,loaded.commands.count == 20 else { throw error("Own loaded continuation") }
            var state = try OriginalMatchPreparation(loading: loaded,arithmeticPrecision: arithmeticPrecision)
            var context = OriginalInputControlContext(savedPlayback: try .init(bytes: c.savedAtFirstMenu,defined: [Bool](repeating: true,count: 0x320)),memory: earlyMemory)
            var commands = Array(loaded.commands.prefix(10));let playback = Array(loaded.commands.suffix(10))
            try retained(state,context.memory,crt,c.retainedBefore)
            let local = c.local,control = c.inputControl,replay = c.replay,round = c.round
            guard local.parent,local.natural,local.paused == 0,local.commandsBefore == commands,local.dispatch.isEmpty,
                  local.call.arguments == [try state.globals.integer(at: 0x450b90-0x44d000,as: UInt32.self),try state.globals.integer(at: 0x451160-0x44d000,as: UInt32.self),c.entry.sp+0x434],
                  local.call.entrySP == c.entry.sp-16,local.call.returnAddress == 0x41c5e5,local.call.saved.count == 4,local.stackAfter == c.entry.sp,local.endPC == 0x41c5e5,
                  control.inherited,control.paused == 0,control.events.isEmpty,control.helperCalls.isEmpty,control.endPC == 0x41d5db,
                  replay.inherited,replay.paused == 0,replay.kind == "finish",replay.entry == .recording,replay.calls.isEmpty,replay.endPC == 0x41d714,
                  round.inherited,round.paused == 0,round.calls.isEmpty,round.continuation == .menu,round.endPC == 0x4229cc,
                  control.stackBefore == control.stackAfter,control.stackAfter == replay.stackBefore,replay.stackBefore == replay.stackAfter,
                  replay.stackAfter == round.stackBefore,round.stackBefore == round.stackAfter,
                  control.stackBefore.count == 28,Array(control.stackBefore[4..<14]) == commands,Array(control.stackBefore[16..<26]) == playback else { throw error("Natural call/stack provenance") }
            var phaseIndex = 0,replayIndex = 0,roundIndex = 0
            let order: [OriginalLoadedMatchEntry.Checkpoint] = [.localBeforeDispatch,.local,.control,.received,.replay,.round]
            var environment: [OriginalLoadedMatchEntry.Checkpoint] = []
            let entry = try OriginalInitialMatchEntry.run(loading: loaded,inputContext: context,arithmeticPrecision: arithmeticPrecision,environment: &environment,
                controlBoundary: { _,_ in throw error("Unexpected natural control platform request") },
                replayEvent: { event,_ in
                    guard replayIndex < replay.events.count,event == replay.events[replayIndex] else { throw error("Replay event") };replayIndex += 1;events += 1
                },roundEvent: { event,_ in
                    guard roundIndex < round.events.count,event == round.events[roundIndex] else { throw error("Round event") };roundIndex += 1;events += 1
                },checkpoint: { phase,value,owned,buffer,steps in
                    guard phaseIndex < order.count,phase == order[phaseIndex],buffer == local.commandsAfter else { throw error("Original continuation order/commands") }
                    steps.append(phase)
                    phaseIndex += 1;checkpoints += 1
                    switch phase {
                    case .localBeforeDispatch:try pool(value,local.beforeDispatch,"Before AI")
                    case .local:try pool(value,local.after,"Local");try snapshot(value,owned,c.initialContext,"Own control entry")
                    case .control:
                        try snapshot(value,owned,control.control,"Control")
                        guard buffer == control.controlCommands,try value.globals.integer(at: 0x44d020-0x44d000,as: UInt32.self) == control.menuRegister else { throw error("Control menu/commands") }
                    case .received:try snapshot(value,owned,control.after,"Received")
                    case .replay:
                        try snapshot(value,owned,replay.after,"Replay")
                        guard try value.globals.integer(at: 0x44d020-0x44d000,as: UInt32.self) == replay.menuRegister else { throw error("Replay menu") }
                    case .round:try snapshot(value,owned,round.after,"Round")
                    }
                })
            try onEntry(loaded,context,entry)
            state = entry.state; context = entry.inputContext; commands = entry.commands
            let outcome = entry.round
            guard phaseIndex == order.count,environment == order,replayIndex == replay.events.count,roundIndex == round.events.count,
                  outcome.continuation == round.continuation,outcome.stageDefeated == round.stageDefeated,
                  control.receiveCalls.count == 1 else { throw error("Input/round result") }
            let received = control.receiveCalls[0]
            guard received.entry == 0x4198f0,received.entrySP == c.entry.sp-16,received.returnAddress == 0x41d495,
                  received.returnSP == c.entry.sp,received.saved.count == 4,received.arguments == [0x44f198,1,c.entry.sp+0x434] else { throw error("Received ret12 ABI") }

            var musicMemory = OriginalMusicMemory(),musicIndex = 0,formatIndex = 0
            let music = c.music
            guard music.kind == "menu",music.inherited,music.stimulus.isEmpty,music.endPC == 0x4297ae,music.endSP == c.end.sp else { throw error("Actual menu/music entry") }
            let resources = c.resources
            guard resources.inherited,resources.stimulus.isEmpty,resources.endPC == c.end.pc,resources.endSP == c.end.sp,
                  resources.allocations.count == 11,resources.inputs.count == 11,resources.calls.count == 11,c.sources.count == 11 else { throw error("Character-menu resource provenance") }
            let inputs = Dictionary(uniqueKeysWithValues: resources.inputs.map { ($0.index,$0) })
            let sources = Dictionary(uniqueKeysWithValues: c.sources.map { ($0.path,$0) })
            for source in c.sources {
                let dib = try defined(source.dib)
                guard dib.bytes.count >= 40,try dib.integer(at: 4,as: Int32.self) == source.width,try dib.integer(at: 8,as: Int32.self) == source.height else { throw error("Original DIB dimensions") }
            }
            var loader = OriginalMenuResourceLoading(),allocationIndex = 0,eventIndex = 0,pointIndex = 0
            func bitmaps(_ expected: [Allocation],_ actual: [UInt32:OriginalLoadedBitmap]) throws {
                guard actual.count == expected.count else { throw error("New bitmap inventory") }
                for r in expected {
                    guard let a = actual[r.address],let i = resources.allocations.firstIndex(where: { $0.address == r.address }),let input = inputs[i],a.input == input.resource else { throw error("New bitmap binding") }
                    var value = try storage(r.storage)
                    guard try value.integer(at: 0,as: UInt32.self) == input.surface else { throw error("Raw bitmap surface") }
                    try value.write(UInt32(input.surface == 0 ? 0 : 1),at: 0)
                    try check(a.storage,value,"Character-menu bitmap")
                }
            }
            var menuEnvironment: [String] = []
            let startup = try OriginalCharacterMenuStartup.run(globals: &state.globals,music: &musicMemory,resources: &loader,environment: &menuEnvironment,
                musicRequest: { event,_ in
                guard musicIndex < music.events.count else { throw error("Excess music event") }
                let e = music.events[musicIndex];musicIndex += 1;events += 1
                guard event == .init(e.kind,e.arguments,e.strings) else { throw error("Music event\(musicIndex)") }
                if event.kind == .format {
                    guard formatIndex < music.formats.count,event.strings.count == 2 else { throw error("CRT format witness") }
                    let f = music.formats[formatIndex];formatIndex += 1
                    guard event.arguments == [UInt32(bitPattern: f.result)],f.bytes == (event.strings[1]+[0]).map({ String(format: "%02x",$0) }).joined() else { throw error("Actual CRT format") }
                }
                return e.response
            },allocate: { index,_ in
                guard index == allocationIndex,index < resources.allocations.count else { throw error("Menu allocation order") };allocationIndex += 1
                let a = resources.allocations[index];return try .init(address: a.address,backing: blob(a.backing))
            },source: { index,path,_ in
                guard let input = inputs[index],let source = sources[path],input.resource.path == path,input.surface != 0,
                      input.resource.present,input.resource.width == source.width,input.resource.height == source.height else { throw error("Original resource/device input") }
                return input.resource
            },deviceResult: { index,_ in
                guard let input = inputs[index] else { throw error("Device input") };return (input.surface,input.colorKeyResult)
            },afterMusic: { entered,musicGlobals,loadedMusic,steps in
                guard entered else { throw error("Missing own music entry") }
                steps.append("music")
                let helpers = music.events.filter { $0.kind == .helper }.map { $0.arguments[0] }
                guard musicIndex == music.events.count,formatIndex == music.formats.count,helpers.sorted() == music.calls.map(\.entry).sorted(),
                      loadedMusic.allocations.count == music.allocations.count else { throw error("Music completion/inventory") }
                let helperReturns: [UInt32:UInt32] = [0x402020:0x4297ab,0x401d30:0x402085,0x401c90:0x40208a,0x401da0:0x4020a2,0x401f30:0x4020c9]
                for h in music.calls { guard helperReturns[h.entry] == h.returnAddress,h.returnSP == h.entrySP+4,h.saved.count == 4 else { throw error("Music helper ABI") } }
                try check(musicGlobals,defined(music.afterGlobals),"Music globals");checkpoints += 1
                for a in music.allocations {
                    guard let owned = loadedMusic.allocations[a.address] else { throw error("Music allocation") }
                    try check(owned,storage(a.storage),"Music UTF16")
                }

            },checkpoint: { point,globals,owned,steps in
                steps.append(point.kind.rawValue)
                guard pointIndex < resources.checkpoints.count else { throw error("Excess resource checkpoint") }
                let p = resources.checkpoints[pointIndex];pointIndex += 1;checkpoints += 1
                guard point == .init(p.kind,index: p.index) else { throw error("Resource checkpoint order") }
                try check(globals,defined(p.globals),"Character-menu globals");try bitmaps(p.records,owned)
            },observe: { event,_ in
                guard eventIndex < resources.events.count,event == resources.events[eventIndex] else { throw error("Resource event\(eventIndex)") };eventIndex += 1;events += 1
            })
            let result = startup.resources
            guard menuEnvironment == ["music"]+resources.checkpoints.map({ $0.kind.rawValue }) else { throw error("Music/resource transaction order") }
            guard allocationIndex == 11,eventIndex == resources.events.count,pointIndex == resources.checkpoints.count,
                  result.continuation == .ready,result.continuation == resources.continuation,result.selectionAtEntry == resources.selectionAtEntry else { throw error("Resource completion") }
            let returns: [UInt32] = [0x429812,0x429851,0x429890,0x4298cf,0x42990e,0x42994d,0x42998c,0x4299cb,0x429a0a,0x429a49,0x429a88]
            for h in resources.calls {
                guard (0..<11).contains(h.index),h.address == resources.allocations[h.index].address,h.returnAddress == returns[h.index],
                      h.entrySP == c.end.sp-16,h.returnSP == c.end.sp,h.saved.count == 4 else { throw error("Resource ret12 ABI") }
            }
            try bitmaps(resources.records,loader.bitmaps);try check(state.globals,defined(resources.globals),"Final menu globals")
            try snapshot(state,context,c.after,"Final own match state");try retained(state,context.memory,crt,c.retainedAfter)
            try onReady?(state,context,crt,musicMemory,loader)
        })
        guard callbacks == 1 else { throw error("Missing own parent") }
        return .init(parent: parent,checkpoints: checkpoints,records: records,bytes: bytes,events: events,
            localCalls: 1,receivedCalls: c.inputControl.receiveCalls.count,musicCalls: c.music.calls.count,constructors: c.resources.calls.count)
    }
}
