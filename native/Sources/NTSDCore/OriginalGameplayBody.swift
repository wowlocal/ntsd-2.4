/// The unpaused gameplay continuation of an already entered loaded match.
/// Input/round dispatch and the alternative paused/menu continuations belong
/// to the enclosing loaded call. This operation never selects a continuation
/// from expected state and never executes reference EXE/DLL code.
public enum OriginalGameplayBody {
    public enum Stage: String, CaseIterable {
        case control, physics, links, contacts, hits
        case cpointActions, cpointPlacement, cpointCleanup, attachments
        case camera, drawing, impulses, lifecycle, commands, hud, notices
        case recording, layout, output
    }

    public enum Event {
        case control(slot: Int, OriginalActorControlEvent)
        case physics(OriginalWorldPhysicsEvent)
        case links(Stage, OriginalWorldLinksEvent)
        case contacts(OriginalWorldContactsEvent)
        case hits(OriginalHitEvent)
        case drawing(Stage, OriginalFrontScreenEvent)
        case impulses(OriginalMenuPresentationEvent)
        case lifecycle(OriginalPostDrawLifecycleEvent)
        case commands(OriginalPostDrawCommandEvent)
        case recording(OriginalResultRecording.Event)
    }

    /// Known root44c..5bf formatter backing, shared by the diagnostic, notice
    /// and result consumers. Nil does not invent original allocator/stack bytes.
    /// Other caller scratch is local to this operation. A previously unassigned
    /// word is required only at an actual dereference by a child API.
    public struct Caller: Equatable {
        public var formatter: OriginalStateRecord?
        public var indicatorTarget: UInt32?
        public init(formatter: OriginalStateRecord? = nil, indicatorTarget: UInt32? = nil) {
            self.formatter = formatter; self.indicatorTarget = indicatorTarget
        }
    }

    /// Complete the gameplay body and its ordinary dispatcher-return effect.
    /// All native state commits together. The caller buffers device/file events
    /// until this operation AND its enclosing loaded call have committed.
    /// Unsupported mode1/4 children and unresolved caller reads remain explicit
    /// errors; no game branch is skipped to obtain a successful return.
    public static func apply(state: inout OriginalMatchPreparation,
        context: inout OriginalInputControlContext, crt: inout OriginalCRTRandom,
        round: OriginalMatchRoundResult, caller: inout Caller,
        target: UInt32, presentation: OriginalMenuPresentationInput, sse2: Bool = false,
        surface: (Int) throws -> UInt32,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        fillBacking: () throws -> [UInt8],
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        allocate: () throws -> UInt32, processorSignature: () throws -> UInt32,
        open: (OriginalReplayFileOutput.OpenRequest) throws -> Bool,
        write: ([UInt8]) throws -> Int32, close: () throws -> Int32,
        soundRequest: OriginalQueuedSound.Request,
        observe: (Event) throws -> Void = { _ in },
        checkpoint: (Stage, OriginalMatchPreparation, OriginalInputControlContext, OriginalCRTRandom) throws -> Void = { _,_,_,_ in }) throws {
        guard round.continuation == .gameplay else {
            throw OriginalStateError.invalidStorage("Gameplay body requires the own gameplay continuation")
        }
        guard caller.formatter == nil || caller.formatter?.bytes.count == OriginalResultLayout.localSize else {
            throw OriginalStateError.invalidStorage("Gameplay body caller formatter extent")
        }
        var next = state, owned = context, random = crt, retained = caller
        try OriginalWorldControl.apply(state: &next, observe: { try observe(.control(slot: $0, $1)) })
        try checkpoint(.control, next, owned, random)
        try OriginalWorldPhysics.apply(state: &next, observe: { try observe(.physics($0)) })
        try checkpoint(.physics, next, owned, random)
        try OriginalWorldLinks.apply(state: &next, sse2Conversion: sse2, observe: { try observe(.links(.links, $0)) })
        try checkpoint(.links, next, owned, random)
        try OriginalWorldContacts.apply(state: &next, observe: { try observe(.contacts($0)) })
        try checkpoint(.contacts, next, owned, random)
        // The full-pool item's root4c and incoming cpoint partner currently
        // have no whole-body native producer. Children retain nil until used.
        try OriginalWorldHits.apply(state: &next, crt: &random, sse2: sse2, observe: { try observe(.hits($0)) })
        try checkpoint(.hits, next, owned, random)
        try OriginalWorldCPoints.apply(state: &next, sse2Conversion: sse2,
            observe: { try observe(.links(.attachments, $0)) }, afterStage: { stage, value in
                let point: Stage
                switch stage {
                case .actions: point = .cpointActions
                case .placement: point = .cpointPlacement
                case .cleanup: point = .cpointCleanup
                case .attachments: point = .attachments
                }
                try checkpoint(point, value, owned, random)
            })
        let mode = try next.globals.integer(at: 0x451160-0x44d000, as: Int32.self)
        try OriginalWorldCamera.apply(state: &next, mode: mode, target: target,
            sse2Conversion: sse2, surface: surface, fillBacking: fillBacking,
            performFill: performFill, performBlit: performBlit, observe: { try observe(.drawing(.camera, $0)) })
        try checkpoint(.camera, next, owned, random)
        let phase = try next.globals.integer(at: 0x450bd8-0x44d000, as: Int32.self)
        try OriginalWorldDrawing.apply(state: &next, target: target, phase: phase,
            surface: surface, resourceBitmap: resourceBitmap, performBlit: performBlit,
            observe: { try observe(.drawing(.drawing, $0)) })
        try checkpoint(.drawing, next, owned, random)
        try OriginalPostDrawImpulses.apply(state: &next, dcResult: presentation.dcResult, dc: presentation.dc, observe: { event in
            // This original diagnostic sprintf writes root48c. If full backing
            // is known, retain its own output for the later overlapping users.
            // A nil backing remains unavailable, never filled from a fixture.
            if event.kind == .format, var storage = retained.formatter {
                guard event.strings.count == 2, event.strings[1].count+1 <= storage.bytes.count-0x40 else {
                    throw OriginalStateError.invalidStorage("Gameplay diagnostic formatter extent")
                }
                for (offset, byte) in (event.strings[1]+[0]).enumerated() { try storage.write(byte, at: 0x40+offset) }
                retained.formatter = storage
            }
            try observe(.impulses(event))
        })
        try checkpoint(.impulses, next, owned, random)
        // Keep each live slot's known producers inside the same original loop.
        // Earlier caller words whose complete lifetimes are unrecovered remain
        // nil; these are not seeded or carried between separate match calls.
        var scratch = OriginalPostDrawScratch()
        try OriginalPostDrawLifecycle.apply(state: &next, scratch: &scratch, sse2: sse2,
            observe: { try observe(.lifecycle($0)) })
        try checkpoint(.lifecycle, next, owned, random)
        var spawn: Int32?
        try OriginalPostDrawCommands.apply(state: &next, retainedSpawnSlot: &spawn, sse2: sse2,
            observe: { try observe(.commands($0)) })
        try checkpoint(.commands, next, owned, random)
        try OriginalWorldHUD.apply(state: &next, surface: surface, resourceBitmap: resourceBitmap,
            performBlit: performBlit, observe: { try observe(.drawing(.hud, $0)) })
        try checkpoint(.hud, next, owned, random)
        var notice: OriginalStateRecord?
        if let storage = retained.formatter {
            notice = try .init(bytes: Array(storage.bytes[0x20...]), defined: Array(storage.defined[0x20...]))
        }
        try OriginalPostHUDNotices.apply(state: next, local: &notice,
            dcResult: presentation.dcResult, dc: presentation.dc, fillBacking: fillBacking,
            resourceBitmap: resourceBitmap, performFill: performFill, performBlit: performBlit,
            observe: { try observe(.drawing(.notices, $0)) })
        if let notice, let original = retained.formatter {
            retained.formatter = try .init(bytes: Array(original.bytes[..<0x20])+notice.bytes,
                defined: Array(original.defined[..<0x20])+notice.defined)
        }
        try checkpoint(.notices, next, owned, random)
        let result = try OriginalResultRecording.apply(state: &next, context: &owned,
            stageDefeated: round.stageDefeated, allocate: allocate, processorSignature: processorSignature,
            open: open, write: write, close: close, observe: { try observe(.recording($0)) })
        try checkpoint(.recording, next, owned, random)
        try OriginalResultLayout.apply(state: &next, context: owned, continuation: result.continuation,
            stageDefeated: round.stageDefeated, indicatorTarget: retained.indicatorTarget, local: &retained.formatter,
            dcResult: presentation.dcResult, dc: presentation.dc, surface: surface, resourceBitmap: resourceBitmap,
            performBlit: performBlit, observe: { try observe(.drawing(.layout, $0)) })
        try checkpoint(.layout, next, owned, random)
        try OriginalGameplayOutput.returnFromDispatcher(world: &next.world, globals: &next.globals,
            memory: &owned.memory, input: presentation, resourceBitmap: resourceBitmap,
            performBlit: performBlit, soundRequest: soundRequest, observe: { try observe(.drawing(.output, $0)) })
        try checkpoint(.output, next, owned, random)
        state = next; context = owned; crt = random; caller = retained
    }
}
