import Foundation
import NTSDCore

/// Own pause, single-step and resume on independently rebuilt native state.
/// Manifest records are comparison outputs; only declared platform responses
/// are supplied to the operation. No expected state or caller storage is seeded.
enum PausedGameplayReference {
    typealias Refs = [String:String]
    typealias Stage = OriginalGameplayBody.Stage
    typealias PauseStage = OriginalPausedGameplay.Stage
    struct EventGroups: Decodable {
        let camera: [OriginalFrontScreenEvent]?, drawing: [OriginalFrontScreenEvent]?
        let impulses: [OriginalMenuPresentationEvent]?
        let lifecycle: [GameplayLifecycleReference.Input.Event]?
        let commands: [GameplayCommandsReference.Input.Event]?
    }
    struct Section: Decodable {
        let label: String, before: Refs, after: Refs
        let helpers: [MatchLaunchReference.Control.Helper]
        let events: EventGroups
        let end: MenuStartupReference.Position
    }
    struct Output: Decodable {
        let label: String, before: Refs, after: Refs
        let helpers: [MatchLaunchReference.Control.Helper], events: [OriginalFrontScreenEvent]
        let end: MenuStartupReference.Position
    }
    struct Case: Decodable {
        let index: Int, before: Refs, after: Refs
        let cycle: Cycle, stages: [Section], output: Output
        let acquisition: Acquisition, paused: Bool, rendering: Rendering?
        let keyboardAfter: [UInt8], fpuStart: Int, fpuEnd: Int
        let end: MenuStartupReference.Position
    }
    struct Cycle: Decodable {
        struct Local: Decodable {
            let parent: Bool, natural: Bool, paused: Int32
            let commandsAfter: [UInt8], call: MenuStartupReference.Local.Call?
            let beforeDispatch: MenuStartupReference.Pool?, after: MenuStartupReference.Pool
            let dispatch: [OriginalLocalInputDispatch]
        }
        let stimulus: [InputControlReference.GlobalWrite], prefix: MenuCycleReference.Prefix
        let local: Local, inputControl: InputControlReference.Case
        let replay: MenuStartupReference.Replay, round: MenuStartupReference.Round
    }
    struct Acquisition: Decodable {
        struct Plan: Decodable { let index: Int, keys: [UInt32] }
        struct Change: Decodable, Equatable { let address: UInt32, bytes: String }
        let plan: Plan, before: [UInt8], after: [UInt8], changes: [Change]
    }
    struct Rendering: Decodable {
        struct Point: Decodable {
            let stage: String, pc: UInt32, state: Refs, events: [OriginalFrontScreenEvent]
        }
        let before: Refs, after: Refs, checkpoints: [Point], events: [OriginalFrontScreenEvent]
        let helpers: [MatchLaunchReference.Control.Helper], fillInputs: [String], target: UInt32
        let drawResults: [Int32], fillResult: Int32, end: MenuStartupReference.Position
    }
    struct Platform: Decodable {
        let input: OriginalMenuPresentationInput, drawResults: [Int32]
        let loadedSoundBuffers: [UInt32], resourceSurfaces: [String:UInt32]
    }
    struct Corpus: Decodable {
        let format: String, exeSHA256: String, dllSHA256: String, control: Bool
        let parent: InputControlReference.Parent, worldAddress: UInt32
        let actorAddresses: [UInt32], objectAddresses: [UInt32], initial: Refs
        let platform: Platform, cases: [Case], blobs: [String:InputControlReference.Blob]
    }
    final class Document {
        let corpus: Corpus
        private let components: [String:Any]
        private var cache: [String:MatchLaunchReference.State] = [:]
        init(_ data: Data) throws {
            let raw = try MatchPreparationReference.unpack(data, maximumCount: 256_000_000)
            corpus = try JSONDecoder().decode(Corpus.self, from: raw)
            guard let root = try JSONSerialization.jsonObject(with: raw) as? [String:Any],
                  let values = root["components"] as? [String:Any],
                  corpus.format == "paused-gameplay-components-v1", corpus.cases.count == 14 else { throw error("Manifest format") }
            for (key,value) in values {
                let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys,.fragmentsAllowed,.withoutEscapingSlashes])
                guard MatchPreparationReference.digest(bytes) == key else { throw error("Component hash") }
            }
            components = values
        }
        func snapshot(_ refs: Refs) throws -> MatchLaunchReference.State {
            let key = refs.keys.sorted().map { $0+":"+refs[$0]! }.joined(separator: ",")
            if let value = cache[key] { return value }
            var fields: [String:Any] = [:]
            for (name,reference) in refs {
                guard let value = components[reference] else { throw error("Missing component") }; fields[name] = value
            }
            let value = try JSONDecoder().decode(MatchLaunchReference.State.self, from: JSONSerialization.data(withJSONObject: fields))
            cache[key] = value; return value
        }
    }
    struct Result { let calls: Int, pausedCalls: Int, events: Int, helpers: Int }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Paused gameplay reference: "+text) }

    static func compare(_ document: Document, state: inout OriginalMatchPreparation,
        context: inout OriginalInputControlContext, crt: inout OriginalCRTRandom,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord,UInt32),
        replayAddresses: [UInt32],
        blob: (String) throws -> [UInt8],
        snapshot: (OriginalMatchPreparation,OriginalInputControlContext,OriginalCRTRandom,MatchLaunchReference.State,String) throws -> Void) throws -> Result {
        let c = document.corpus, p = c.platform.input
        let initial = try document.snapshot(c.initial)
        guard state.arithmeticPrecision == .bits53, c.platform.drawResults == [0,1],
              p.targetSurface == (try state.globals.integer(at: 0x455608-0x44d000, as: UInt32.self)),
              p.dcResult == 0, p.methodResult == 0, p.queryResult == 0, p.audioGetResult == 0,
              p.audioSetResult == 0, p.postResult == 0 else { throw error("Own platform context") }
        try snapshot(state,context,crt,initial,"continuous initial")
        let order: [Stage] = [.control,.physics,.links,.contacts,.hits,.cpointActions,.cpointPlacement,.cpointCleanup,
            .attachments,.camera,.drawing,.impulses,.lifecycle,.commands,.hud,.notices,.recording,.layout,.output]
        let labels = ["control","physics","depth-attachments","contacts","hits-items","cpoint-actions","cpoint-placement",
            "cpoint-cleanup","cpoint-attachments","camera-background","world-drawing","post-draw-impulses","post-draw-lifecycle",
            "post-draw-commands","world-hud","post-hud-notices","result-recording","result-layout"]
        let catalogIndices = initial.bitmaps.indices.filter { state.interface.bitmaps[initial.bitmaps[$0].address] == nil }
        guard catalogIndices.count == state.bitmaps.count else { throw error("Catalog inventory") }
        let nativeIndices = Dictionary(uniqueKeysWithValues: catalogIndices.enumerated().map { (initial.bitmaps[$0.element].address,$0.offset) })
        let sourceIndices = Dictionary(uniqueKeysWithValues: initial.bitmaps.enumerated().map { ($0.element.address,$0.offset) })
        let actors = Dictionary(uniqueKeysWithValues:c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objects = Dictionary(uniqueKeysWithValues:c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        func record(_ bytes: String,_ mask: String) throws -> OriginalStateRecord {
            let raw = try blob(bytes),defined = try blob(mask)
            guard raw.count == defined.count,defined.allSatisfy({ $0 < 2 }) else { throw error("Input mask") }
            return try .init(bytes:raw,defined:defined.map { $0 != 0 })
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else { throw error("Input "+label) }
        }
        func world(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var value = raw
            guard try value.integer(at:0x7d4,as:UInt32.self) == 0x60000020 else { throw error("Input catalog identity") }
            try value.write(UInt32(0),at:0x7d4)
            for n in 0..<400 {
                guard let index = actors[try value.integer(at:0x194+n*4,as:UInt32.self)] else { throw error("Input actor identity") }
                try value.write(index,at:0x194+n*4)
            }
            return value
        }
        func actor(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var value = raw
            guard let index = objects[try value.integer(at:0x368,as:UInt32.self)] else { throw error("Input object identity") }
            try value.write(index,at:0x368);return value
        }
        func localPool(_ value: OriginalMatchPreparation,_ expected: MenuStartupReference.Pool) throws {
            guard expected.actors.count == value.actors.count else { throw error("Input local pool count") }
            try check(value.world,world(record(expected.world.bytes,expected.world.defined)),"local World")
            guard value.globals.bytes == (try blob(expected.globals)),value.globals.defined.allSatisfy({ $0 }) else { throw error("Input local globals") }
            for n in value.actors.indices { let r = expected.actors[n];try check(value.actors[n],actor(record(r.bytes,r.defined)),"local actor") }
        }
        func inputSnapshot(_ value: OriginalMatchPreparation,_ owned: OriginalInputControlContext,_ expected: InputControlReference.Snapshot) throws {
            let raw = try blob(expected.poolBytes),mask = try blob(expected.poolMask)
            guard raw.count == 0x7d8+400*0x420,mask.count == raw.count,mask.allSatisfy({ $0 < 2 }),
                  expected.memory.count == replayAddresses.count else { throw error("Input pool/recording extent") }
            func part(_ offset: Int,_ count: Int) throws -> OriginalStateRecord {
                try .init(bytes:Array(raw[offset..<offset+count]),defined:mask[offset..<offset+count].map { $0 != 0 })
            }
            try check(value.world,world(part(0,0x7d8)),"World")
            for n in 0..<400 { try check(value.actors[n],actor(part(0x7d8+n*0x420,0x420)),"actor") }
            guard value.globals.bytes == (try blob(expected.globals)),value.globals.defined.allSatisfy({ $0 }),
                  owned.savedPlayback.bytes == (try blob(expected.saved)),owned.savedPlayback.defined.allSatisfy({ $0 }),
                  owned.memory.replayPointers.bytes == (try blob(expected.pointers)),owned.memory.replayPointers.defined.allSatisfy({ $0 }) else { throw error("Input globals/saved/pointers") }
            for (address,r) in zip(replayAddresses,expected.memory) {
                guard let allocation = owned.memory.allocations[address],allocation.live == r.live else { throw error("Input recording ownership") }
                try check(allocation.storage,record(r.bytes,r.defined),"recording")
            }
        }
        let pauseOrder: [PauseStage] = [.background,.drawing,.hud,.pauseBitmap,.indicators,.output]
        let pauseStops: [UInt32] = [0x41d74d,0x41d762,0x41d76a,0x41d78b,0x422994]
        var events = 0, helpers = 0, previous = c.initial, previousFPU = 15102, pausedCalls = 0
        for (index,item) in c.cases.enumerated() {
            guard item.index == index+1, item.before == previous, item.fpuStart == previousFPU,
                  item.fpuEnd > item.fpuStart, item.stages.map(\.label) == (item.paused ? [] : labels),
                  item.keyboardAfter.count == 300,
                  item.cycle.stimulus.isEmpty, item.cycle.local.dispatch.isEmpty,
                  item.cycle.local.parent, item.cycle.local.natural,
                  item.cycle.local.paused == item.cycle.prefix.paused,
                  item.paused == (item.cycle.local.call == nil),
                  item.paused == (item.cycle.local.beforeDispatch == nil),
                  item.cycle.prefix.phase == UInt32(index%2), item.end.pc == 0x30000000, item.end.sp == 0x1000f42c else { throw error("Successive caller identity") }
            let before = try document.snapshot(item.before), after = try document.snapshot(item.after)
            try snapshot(state,context,crt,before,"call\(item.index) before")
            let acquisition = item.acquisition
            let planned: [UInt32] = index == 0 || index == 10 ? [0x4553e8] : index == 4 ? [0x4553e9] : []
            let keyOffset = 0x455378-0x44d000
            guard acquisition.plan.index == index+1, acquisition.plan.keys == planned,
                  Array(state.globals.bytes[keyOffset..<keyOffset+300]) == acquisition.before else { throw error("Own acquired keys before") }
            var changes: [Acquisition.Change] = []
            for address in [UInt32(0x4553e8),0x4553e9] {
                let value: UInt8 = planned.contains(address) ? 100 : 117
                if try state.globals.integer(at:Int(address)-0x44d000,as:UInt8.self) != value {
                    try state.globals.write(value,at:Int(address)-0x44d000)
                    changes.append(.init(address:address,bytes:value == 100 ? "64" : "75"))
                }
            }
            guard changes == acquisition.changes, Array(state.globals.bytes[keyOffset..<keyOffset+300]) == acquisition.after else { throw error("Own acquired key changes") }
            let acquiredState = state
            let sections = Dictionary(uniqueKeysWithValues: zip(Array(order.dropLast()),item.stages))
            let output = item.output, cycle = item.cycle, control = cycle.inputControl
            guard item.paused == (cycle.round.continuation == .pausedRendering), item.paused == (item.rendering != nil),
                  output.before == (item.rendering?.after ?? item.stages.last!.after),
                  output.after == item.after.filter({ $0.key != "frameHeap" }) else { throw error("Body/output continuity") }
            var pauseSections: [PauseStage:Rendering.Point] = [:]
            if let rendering = item.rendering {
                guard rendering.checkpoints.map(\.stage) == pauseOrder.dropLast().map(\.rawValue),
                      rendering.checkpoints.map(\.pc) == pauseStops, rendering.target == p.targetSurface,
                      rendering.drawResults == [0,1], rendering.fillResult == 0, rendering.fillInputs.isEmpty,
                      rendering.checkpoints.flatMap(\.events) == rendering.events,
                      rendering.checkpoints.last?.state == rendering.after else { throw error("Paused source stages") }
                pauseSections = Dictionary(uniqueKeysWithValues: zip(Array(pauseOrder.dropLast()),rendering.checkpoints))
            }
            let ownAtEntry = state
            func surface(_ n: Int) throws -> UInt32 {
                guard ownAtEntry.bitmaps.indices.contains(n), !ownAtEntry.releasedBitmaps.contains(n) else { throw error("Surface ownership") }
                return ownAtEntry.bitmaps[n].input.present ? 0x24000000 : 0
            }
            func resource(_ token: UInt32) throws -> (OriginalStateRecord,UInt32) {
                if let b = ownAtEntry.interface.bitmaps[token] { return (b.storage,b.input.present ? 0x24000000 : 0) }
                if let n = nativeIndices[token] { return try (ownAtEntry.bitmaps[n].storage,surface(n)) }
                return try resourceBitmap(token)
            }
            var expectedDraws: [Stage:[OriginalFrontScreenEvent]] = [.output:output.events,.layout:[]]
            for stage in [Stage.camera,.drawing,.hud,.notices] where !item.paused {
                expectedDraws[stage] = stage == .camera ? sections[stage]!.events.camera ?? [] : sections[stage]!.events.drawing ?? []
            }
            let expectedRandom = (sections[.hits]?.helpers ?? []).filter { $0.entry == 0x417170 }.map {
                OriginalHitEvent.random(stream: Int32(bitPattern:$0.arguments[0]),range:Int32(bitPattern:$0.arguments[1]),result:Int32(bitPattern:$0.result))
            }
            // The first trial reaches the final output observer after the
            // preceding input phase, replay write and complete simulation.
            // Its rollback is checked against the whole call's original state.
            for trial in (index == 0 || (item.paused && pausedCalls == 0) ? [true,false] : [false]) {
                var next = state, owned = context, generator = crt, caller = OriginalGameplayBody.Caller()
                var stageIndex = 0, controlIndex = 0, replayIndex = 0, roundIndex = 0, asyncIndex = 0, ioctlIndex = 0
                var inputIndex = 0, prologues = 0, entries = 0, seenEvents = 0, rejected = false
                var drawingCounts: [Stage:Int] = [:], blitCounts: [Stage:Int] = [:], activeDrawing: Stage?
                var pauseIndex = 0, pauseDrawingCounts: [PauseStage:Int] = [:], pauseBlits = 0, pauseOutputBlits = 0
                var activePause: PauseStage?
                var hitEvents: [OriginalHitEvent] = [], impulses: [OriginalMenuPresentationEvent] = []
                var lifecycle: [GameplayLifecycleReference.Input.Event] = [], commands: [GameplayCommandsReference.Input.Event] = []
                let inputOrder: [OriginalLoadedMatchEntry.Checkpoint] = (item.paused ? [] : [.localBeforeDispatch])+[.local,.control,.received,.replay,.round]
                func observe(_ event: OriginalGameplayBody.Event) throws {
                    guard !item.paused else { throw error("Unpaused body executed during pause") }
                    guard stageIndex < order.count else { throw error("Event after body") }
                    let current = order[stageIndex]; seenEvents += 1
                    switch event {
                    case let .drawing(stage,original):
                        guard stage == current else { throw error("Drawing stage") }; activeDrawing = stage
                        var value = original
                        if [.camera,.drawing,.hud].contains(stage), ["draw","width","rectangle"].contains(value.kind) {
                            guard let token = value.arguments.first,token > 0 else { throw error("Bitmap identity") }
                            if catalogIndices.indices.contains(Int(token)-1) { value.arguments[0] = UInt32(catalogIndices[Int(token)-1]+1) }
                            else if let n = sourceIndices[token] { value.arguments[0] = UInt32(n+1) }
                        }
                        let n = drawingCounts[stage,default:0]
                        guard let expected = expectedDraws[stage],n < expected.count,value == expected[n] else { throw error("call\(item.index) \(stage) event\(n): \(value)") }
                        drawingCounts[stage] = n+1
                        if trial,stage == .output,value.kind == "dispatcherWrite" { throw error("Late whole-call observer") }
                    case let .hits(value):guard current == .hits else { throw error("Hit stage") };hitEvents.append(value)
                    case let .impulses(value):guard current == .impulses else { throw error("Impulse stage") };impulses.append(value)
                    case let .lifecycle(value):
                        guard current == .lifecycle else { throw error("Lifecycle stage") }
                        let e: GameplayLifecycleReference.Input.Event
                        switch value {
                        case let .reconstruct(slot,created):e = .init(kind:"reconstruct",slot:slot,arguments:[UInt32(created)])
                        case let .random(slot,stream,range,result):e = .init(kind:"random",slot:slot,arguments:[stream,range,result].map(UInt32.init(bitPattern:)))
                        case let .catalogSound(slot,x,n):e = .init(kind:"catalogSound",slot:slot,arguments:[x,n].map(UInt32.init(bitPattern:)))
                        case let .builtinSound(slot,x,n):e = .init(kind:"builtinSound",slot:slot,arguments:[x,n].map(UInt32.init(bitPattern:)))
                        };lifecycle.append(e)
                    case let .commands(value):
                        guard current == .commands else { throw error("Command stage") }
                        switch value {
                        case let .random(stream,range,result):commands.append(.init(kind:"random",arguments:[stream,range,result].map(UInt32.init(bitPattern:))))
                        case let .reconstruct(slot):commands.append(.init(kind:"reconstruct",arguments:[UInt32(slot)]))
                        case .resumeMusic:throw error("New source music observer required")
                        }
                    default:throw error("Unmatched actual body event \(event)")
                    }
                }
                func pausedObserve(_ stage: PauseStage,_ original: OriginalFrontScreenEvent) throws {
                    guard item.paused,pauseIndex < pauseOrder.count,stage == pauseOrder[pauseIndex] else { throw error("Paused event stage") }
                    activePause = stage;seenEvents += 1
                    var value = original
                    if stage != .output, ["draw","width","rectangle"].contains(value.kind) {
                        guard let token = value.arguments.first,token > 0 else { throw error("Paused bitmap identity") }
                        if catalogIndices.indices.contains(Int(token)-1) { value.arguments[0] = UInt32(catalogIndices[Int(token)-1]+1) }
                        else if let n = sourceIndices[token] { value.arguments[0] = UInt32(n+1) }
                    }
                    let expected = stage == .output ? output.events : pauseSections[stage]!.events
                    let n = pauseDrawingCounts[stage,default:0]
                    guard n < expected.count,value == expected[n] else { throw error("call\(item.index) paused \(stage) event\(n): \(value)") }
                    pauseDrawingCounts[stage] = n+1
                    if trial,stage == .output,value.kind == "dispatcherWrite" { throw error("Late whole-call observer") }
                }
                do {
                    _ = try OriginalLoadedGameplayCall.run(state:&next,context:&owned,crt:&generator,caller:&caller,
                        controlBoundary:{ request in
                            guard controlIndex < control.events.count else { throw error("Extra control request") }
                            let e = control.events[controlIndex];controlIndex += 1;seenEvents += 1
                            guard request == .init(e.kind,e.arguments,e.data) else { throw error("Control request order") }
                            let response: OriginalInputControlResponse
                            switch request.kind {
                            case .action:
                                guard e.response == nil,request.arguments.count == 1,
                                      [UInt32(0x416dd0),0x416df0].contains(request.arguments[0]) else { throw error("Pause hotkey observer") }
                                return .init(result:0)
                            case .asyncSelect:
                                guard asyncIndex < control.platform.asyncResults.count else { throw error("Async response") }
                                response = .init(result:control.platform.asyncResults[asyncIndex]);asyncIndex += 1
                            case .ioctl:
                                guard ioctlIndex < control.platform.ioctlResults.count else { throw error("Ioctl response") }
                                response = .init(result:control.platform.ioctlResults[ioctlIndex],bytes:ioctlIndex == 1 ? control.platform.ioctlBytes : []);ioctlIndex += 1
                            default:throw error("Unrecovered platform request")
                            }
                            guard e.response == response else { throw error("Control response") };return response
                        },target:p.targetSurface,presentation:p,surface:surface,resourceBitmap:resource,
                        fillBacking:{ throw error("New fill backing required") },performFill:{ _ in throw error("Unexpected fill") },
                        performBlit:{ _ in
                            if item.paused {
                                guard let stage = activePause else { throw error("Paused Blt without draw") }
                                if stage == .output { defer { pauseOutputBlits += 1 };return Int32(pauseOutputBlits%2) }
                                defer { pauseBlits += 1 };return Int32(pauseBlits%2)
                            }
                            guard let stage = activeDrawing else { throw error("Blt without draw") }
                            let n = blitCounts[stage,default:0];blitCounts[stage] = n+1;return Int32(n%2)
                        },allocate:{ throw error("New codec allocation required") },processorSignature:{ throw error("New processor request") },
                        open:{ _ in throw error("New replay file open") },write:{ _ in throw error("New replay file write") },close:{ throw error("New replay close") },
                        soundRequest:{ _ in 0 },replayEvent:{ event in
                            guard replayIndex < cycle.replay.events.count,event == cycle.replay.events[replayIndex] else { throw error("Replay event") }
                            replayIndex += 1;seenEvents += 1
                        },roundEvent:{ event in
                            guard roundIndex < cycle.round.events.count,event == cycle.round.events[roundIndex] else { throw error("Round event") }
                            roundIndex += 1;seenEvents += 1
                        },prologue:{ value,memory,paused,keys,playback in
                            prologues += 1
                            guard paused == (cycle.prefix.paused == 1),keys == cycle.prefix.commands,playback == cycle.prefix.playback,
                                  value.globals.bytes == (try blob(cycle.prefix.after.globals)) else { throw error("Prologue state") }
                            try inputSnapshot(value,memory,cycle.prefix.after)
                        },inputCheckpoint:{ phase,value,memory,keys in
                            guard inputIndex < inputOrder.count,phase == inputOrder[inputIndex],keys == cycle.local.commandsAfter else { throw error("Input stages") }
                            inputIndex += 1
                            switch phase {
                            case .localBeforeDispatch:
                                guard let beforeDispatch = cycle.local.beforeDispatch else { throw error("Paused local helper must remain skipped") }
                                try localPool(value,beforeDispatch)
                            case .local:try localPool(value,cycle.local.after)
                            case .control:try inputSnapshot(value,memory,control.control)
                            case .received:try inputSnapshot(value,memory,control.after)
                            case .replay:try inputSnapshot(value,memory,cycle.replay.after)
                            case .round:try inputSnapshot(value,memory,cycle.round.after)
                            }
                        },bodyEntry:{ value,memory,random,round in
                            entries += 1
                            guard round.continuation == cycle.round.continuation,round.stageDefeated == cycle.round.stageDefeated else { throw error("Own round continuation") }
                            try snapshot(value,memory,random,document.snapshot(item.rendering?.before ?? item.stages[0].before),"call\(item.index) body entry")
                        },observe:observe,checkpoint:{ stage,value,memory,random in
                            guard stageIndex < order.count,stage == order[stageIndex] else { throw error("Body order") };stageIndex += 1
                            if !trial {
                                let refs = stage == .output ? item.after : sections[stage]!.after
                                try snapshot(value,memory,random,document.snapshot(refs),"call\(item.index) "+stage.rawValue)
                            }
                        },pausedObserve:pausedObserve,pausedCheckpoint:{ stage,value,memory in
                            guard item.paused,pauseIndex < pauseOrder.count,stage == pauseOrder[pauseIndex] else { throw error("Paused checkpoint order") }
                            pauseIndex += 1
                            if !trial {
                                let refs = stage == .output ? item.after : pauseSections[stage]!.state
                                try snapshot(value,memory,crt,document.snapshot(refs),"call\(item.index) paused "+stage.rawValue)
                            }
                        })
                } catch OriginalStateError.invalidStorage(let message) where trial && message == "Paused gameplay reference: Late whole-call observer" { rejected = true }
                guard prologues == 1,entries == 1,inputIndex == inputOrder.count,controlIndex == control.events.count,
                      replayIndex == cycle.replay.events.count,roundIndex == cycle.round.events.count,
                      hitEvents == expectedRandom,impulses == (sections[.impulses]?.events.impulses ?? []),
                      lifecycle == (sections[.lifecycle]?.events.lifecycle ?? []),commands == (sections[.commands]?.events.commands ?? []),
                      caller == OriginalGameplayBody.Caller() else { throw error("Incomplete call events or unknown storage") }
                for (stage,expected) in expectedDraws where !item.paused {
                    guard drawingCounts[stage,default:0] == expected.count,
                          blitCounts[stage,default:0] == expected.filter({ $0.kind == "blit" }).count else { throw error("Incomplete output") }
                }
                if item.paused {
                    guard generator == crt else { throw error("Paused call changed CRT random state") }
                    for stage in pauseOrder {
                        let expected = stage == .output ? output.events : pauseSections[stage]!.events
                        guard pauseDrawingCounts[stage,default:0] == expected.count else { throw error("Incomplete paused output") }
                    }
                    guard pauseBlits == item.rendering!.events.filter({ $0.kind == "blit" }).count,
                          pauseOutputBlits == output.events.filter({ $0.kind == "blit" }).count,stageIndex == 0 else { throw error("Paused drawing count") }
                }
                if trial {
                    guard rejected,(item.paused ? pauseIndex == pauseOrder.count-1 : stageIndex == order.count-1),generator == crt,
                          next.globals == acquiredState.globals else { throw error("Whole-call rollback") }
                    // The input acquisition preceded the transaction. Check all
                    // globals against the own acquired state, then undo only
                    // those two declared keyboard bytes to compare the complete
                    // pre-acquisition snapshot, including every other owner.
                    var originalKeys = next
                    for address in [UInt32(0x4553e8),0x4553e9] {
                        try originalKeys.globals.write(acquisition.before[Int(address)-0x455378],at:Int(address)-0x44d000)
                    }
                    try snapshot(originalKeys,owned,generator,before,"whole-call rollback")
                } else {
                    guard !rejected,(item.paused ? pauseIndex == pauseOrder.count : stageIndex == order.count),
                          Array(next.globals.bytes[keyOffset..<keyOffset+300]) == item.keyboardAfter else { throw error("Incomplete production call") }
                    try snapshot(next,owned,generator,after,"call\(item.index) full return")
                    state = next;context = owned;crt = generator;events += seenEvents
                }
            }
            helpers += item.stages.reduce(0) { $0+$1.helpers.count }+output.helpers.count+(item.rendering?.helpers.count ?? 0)
            if item.paused { pausedCalls += 1 }
            previous = item.after;previousFPU = item.fpuEnd
        }
        return .init(calls:c.cases.count,pausedCalls:pausedCalls,events:events,helpers:helpers)
    }
}
