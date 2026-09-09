import NTSDCore

/// Run the production body once from the independently rebuilt round result.
/// Source sections are assertions and platform bindings, never state seeds.
enum GameplayBodyReference {
    typealias Stage = OriginalGameplayBody.Stage
    typealias Section = MatchLaunchReference.Control.Section
    struct Result { let checkpoints: Int, events: Int }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Gameplay body reference: "+text) }

    static func compare(sections: [Stage:Section], state: OriginalMatchPreparation,
        context: OriginalInputControlContext, crt: OriginalCRTRandom, round: OriginalMatchRoundResult,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        snapshot: (OriginalMatchPreparation, OriginalInputControlContext, OriginalCRTRandom,
                   MatchLaunchReference.State, String) throws -> Void) throws -> Result {
        // This order and the actual stops come from the pinned caller sections,
        // independently of the production enum's declaration order.
        let stops: [(Stage, UInt32)] = [
            (.control,0x41e634),(.physics,0x41eed1),(.links,0x41eed8),(.contacts,0x41eefb),(.hits,0x41f2ac),
            (.cpointActions,0x41f2b3),(.cpointPlacement,0x41f2b8),(.cpointCleanup,0x41f47d),(.attachments,0x41f484),
            (.camera,0x41f496),(.drawing,0x41f4ac),(.impulses,0x41f550),(.lifecycle,0x4214d5),
            (.commands,0x421a15),(.hud,0x421a2d),(.notices,0x421cdc),(.recording,0x422944),
            (.layout,0x422994),(.output,0x30000000)]
        let order = stops.map(\.0)
        guard stops.allSatisfy({ sections[$0.0]?.end.pc == $0.1 }) else { throw error("Original stage stops") }
        guard Set(sections.keys) == Set(Stage.allCases), let camera = sections[.camera]?.drawing,
              let output = sections[.output]?.gameplayReturn, let lifecycle = sections[.lifecycle]?.lifecycle,
              let impulses = sections[.impulses]?.impulses,
              round.continuation == .gameplay, state.arithmeticPrecision == .bits53,
              camera.fillInputs.isEmpty, sections[.notices]?.notices?.fillInputs.isEmpty == true,
              camera.target == (try state.globals.integer(at: 0x455608-0x44d000, as: UInt32.self)),
              output.input.targetSurface == camera.target,
              impulses.dc == output.input.dc, impulses.dcResult == output.input.dcResult else { throw error("Own body inputs") }
        let before = sections[.control]!.before
        let catalogIndices = before.bitmaps.indices.filter { state.interface.bitmaps[before.bitmaps[$0].address] == nil }
        guard catalogIndices.count == state.bitmaps.count, camera.surfaces.count == before.bitmaps.count else { throw error("Catalog surface inventory") }
        let nativeIndices = Dictionary(uniqueKeysWithValues: catalogIndices.enumerated().map { (before.bitmaps[$0.element].address, $0.offset) })
        let sourceIndices = Dictionary(uniqueKeysWithValues: before.bitmaps.enumerated().map { ($0.element.address, $0.offset) })
        func surface(_ n: Int) throws -> UInt32 {
            guard state.bitmaps.indices.contains(n), !state.releasedBitmaps.contains(n) else { throw error("Catalog surface ownership") }
            let value: UInt32 = state.bitmaps[n].input.present ? 0x24000000 : 0
            guard camera.surfaces[catalogIndices[n]] == value else { throw error("Declared catalog surface") }; return value
        }
        func resource(_ token: UInt32) throws -> (OriginalStateRecord, UInt32) {
            if let bitmap = state.interface.bitmaps[token] {
                return (bitmap.storage, bitmap.input.present ? 0x24000000 : 0)
            }
            if let index = nativeIndices[token] { return try (state.bitmaps[index].storage, surface(index)) }
            return try resourceBitmap(token)
        }
        var expectedDraws: [Stage:[OriginalFrontScreenEvent]] = [:]
        for stage in [Stage.camera, .drawing, .hud] {
            guard let drawing = sections[stage]?.drawing, drawing.drawResults == [0,1] else { throw error("Drawing response sequence") }
            expectedDraws[stage] = drawing.events
        }
        expectedDraws[.notices] = sections[.notices]?.notices?.events
        expectedDraws[.layout] = []
        expectedDraws[.output] = output.events
        guard output.drawResults == [0,1] else { throw error("Output response sequence") }
        let randomCalls = sections[.hits]!.helpers.filter { $0.entry == 0x417170 }
        guard randomCalls.allSatisfy({ $0.arguments.count == 2 }), randomCalls.count == 1 else { throw error("Own item RNG") }
        let expectedRandom = randomCalls.map { OriginalHitEvent.random(stream: Int32(bitPattern: $0.arguments[0]),
            range: Int32(bitPattern: $0.arguments[1]), result: Int32(bitPattern: $0.result)) }

        // Execute the complete body twice: a late output observer rejects the
        // first trial, after simulation, frame scheduling, rendering and sound.
        // Its events remain buffered and its native state must remain unchanged.
        var acceptedEvents = 0, acceptedCheckpoints = 0
        for trial in [true, false] {
            var next = state, owned = context, random = crt, caller = OriginalGameplayBody.Caller()
            var drawingCounts: [Stage:Int] = [:], blitCounts: [Stage:Int] = [:]
            var activeDrawing: Stage?, seenStages: [Stage] = []
            var hitEvents: [OriginalHitEvent] = [], impulseEvents: [OriginalMenuPresentationEvent] = []
            var lifecycleEvents: [GameplayLifecycleReference.Input.Event] = []
            var events = 0, rejected = false
            func observe(_ event: OriginalGameplayBody.Event) throws {
                guard seenStages.count < order.count else { throw error("Event after completed source caller") }
                let current = order[seenStages.count]
                events += 1
                switch event {
                case let .hits(value):
                    guard current == .hits else { throw error("Hit event outside source hit caller") }; hitEvents.append(value)
                case let .impulses(value):
                    guard current == .impulses else { throw error("Impulse event outside source caller") }; impulseEvents.append(value)
                case let .lifecycle(value):
                    guard current == .lifecycle else { throw error("Lifecycle event outside source loop") }
                    let item: GameplayLifecycleReference.Input.Event
                    switch value {
                    case let .reconstruct(slot, created): item = .init(kind: "reconstruct", slot: slot, arguments: [UInt32(created)])
                    case let .random(slot, stream, range, result): item = .init(kind: "random", slot: slot, arguments: [stream,range,result].map(UInt32.init(bitPattern:)))
                    case let .catalogSound(slot, x, index): item = .init(kind: "catalogSound", slot: slot, arguments: [x,index].map(UInt32.init(bitPattern:)))
                    case let .builtinSound(slot, x, index): item = .init(kind: "builtinSound", slot: slot, arguments: [x,index].map(UInt32.init(bitPattern:)))
                    }
                    lifecycleEvents.append(item)
                case let .drawing(stage, original):
                    guard stage == current else { throw error("Output event outside source stage") }
                    activeDrawing = stage
                    var value = original
                    if [.camera,.drawing,.hud].contains(stage), ["draw","width","rectangle"].contains(value.kind) {
                        guard let token = value.arguments.first, token > 0 else { throw error("Bitmap event identity") }
                        if catalogIndices.indices.contains(Int(token)-1) { value.arguments[0] = UInt32(catalogIndices[Int(token)-1]+1) }
                        else if let index = sourceIndices[token] { value.arguments[0] = UInt32(index+1) }
                    }
                    let count = drawingCounts[stage, default: 0]
                    guard let expected = expectedDraws[stage], count < expected.count, value == expected[count] else {
                        throw error("\(stage) event\(count): \(value)")
                    }
                    drawingCounts[stage] = count+1
                    if trial, stage == .output, value.kind == "dispatcherWrite" { throw error("Late whole-body observer") }
                default: throw error("Unexpected own body event \(event)")
                }
            }
            do {
                try OriginalGameplayBody.apply(state: &next, context: &owned, crt: &random,
                    round: round, caller: &caller, target: camera.target, presentation: output.input,
                    surface: surface, resourceBitmap: resource,
                    fillBacking: { throw error("Unexpected fill backing") }, performFill: { _ in throw error("Unexpected fill") },
                    performBlit: { _ in
                        guard let stage = activeDrawing else { throw error("Blt without observed draw") }
                        let count = blitCounts[stage, default: 0]; blitCounts[stage] = count+1; return Int32(count%2)
                    }, allocate: { throw error("Unexpected codec allocation") }, processorSignature: { throw error("Unexpected processor read") },
                    open: { _ in throw error("Unexpected replay open") }, write: { _ in throw error("Unexpected replay write") },
                    close: { throw error("Unexpected replay close") }, soundRequest: { _ in 0 }, observe: observe,
                    checkpoint: { stage, value, memory, generator in
                        guard seenStages.count < order.count, stage == order[seenStages.count] else { throw error("Body stage order") }
                        seenStages.append(stage)
                        if !trial { try snapshot(value, memory, generator, sections[stage]!.after, "body "+stage.rawValue) }
                    })
            } catch OriginalStateError.invalidStorage(let message) where trial && message == "Gameplay body reference: Late whole-body observer" { rejected = true }
            guard hitEvents == expectedRandom, impulseEvents == impulses.events, lifecycleEvents == lifecycle.events,
                  caller == OriginalGameplayBody.Caller() else { throw error("Body events or unknown caller storage") }
            for (stage, expected) in expectedDraws {
                guard drawingCounts[stage, default: 0] == expected.count,
                      blitCounts[stage, default: 0] == expected.filter({ $0.kind == "blit" }).count else { throw error("Incomplete \(stage) output") }
            }
            if trial {
                guard rejected, seenStages == Array(order.dropLast()), random == crt,
                      owned.savedPlayback == context.savedPlayback,
                      owned.memory.replayPointers == context.memory.replayPointers,
                      owned.memory.allocations == context.memory.allocations else { throw error("Whole body rollback") }
                try snapshot(next, owned, random, before, "whole body rollback")
            } else {
                guard !rejected, seenStages == order else { throw error("Incomplete whole body") }
                acceptedEvents = events; acceptedCheckpoints = seenStages.count
            }
        }
        print("GAMEPLAY BODY", acceptedCheckpoints, "stage checkpoints", acceptedEvents, "ordered events; late whole-body rollback passed")
        return .init(checkpoints: acceptedCheckpoints, events: acceptedEvents)
    }
}
