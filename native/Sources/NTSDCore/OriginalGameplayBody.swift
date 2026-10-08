/// The unpaused gameplay continuation of an already entered loaded match.
/// Input/round dispatch and the alternative paused/menu continuations belong
/// to the enclosing loaded call. This operation never selects a continuation
/// from expected state and never executes reference EXE/DLL code.
public enum OriginalGameplayBody {
    /// Persistent installed-library owners, distinct from call-local scratch.
    /// Hit storage must come from declared installation/allocation provenance;
    /// empty transform destinations keep unrecovered extended writes explicit.
    public struct Library: Equatable {
        public var text: OriginalLibSurfaceText
        public var hits: OriginalLibHitState
        public var transforms: OriginalLibTransformBacking
        public init(text: OriginalLibSurfaceText, hits: OriginalLibHitState,
                    transforms: OriginalLibTransformBacking = .init()) {
            self.text = text;self.hits = hits;self.transforms = transforms
        }
    }
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
    @discardableResult
    public static func apply(state: inout OriginalMatchPreparation,
        context: inout OriginalInputControlContext, crt: inout OriginalCRTRandom,
        round: OriginalMatchRoundResult, caller: inout Caller,
        target: UInt32, presentation: OriginalMenuPresentationInput, sse2: Bool = false,
        library: Library? = nil,
        surface: (Int) throws -> UInt32,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        fillBacking: () throws -> [UInt8],
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        allocate: () throws -> UInt32, processorSignature: () throws -> UInt32,
        open: (OriginalReplayFileOutput.OpenRequest) throws -> Bool,
        write: ([UInt8]) throws -> Int32, close: () throws -> Int32,
        soundRequest: OriginalQueuedSound.Request,
        music: OriginalMusicPlayback.Request = { _ in throw OriginalStateError.invalidStorage("Gameplay music request provider") },
        /// false: nobody observes the drawing's read, clip, draw and rectangle
        /// events, so they are not built (CORE_REALTIME 4d). Every other event,
        /// value and error is the same.
        detail: Bool = true,
        observe: (Event) throws -> Void = { _ in },
        checkpoint: (Stage, OriginalMatchPreparation, OriginalInputControlContext, OriginalCRTRandom) throws -> Void = { _,_,_,_ in },
        ownedCheckpoint: (Stage, OriginalMatchPreparation, OriginalInputControlContext, OriginalCRTRandom, Library?) throws -> Void = { _,_,_,_,_ in }) throws -> Library? {
        guard round.continuation == .gameplay else {
            throw OriginalStateError.invalidStorage("Gameplay body requires the own gameplay continuation")
        }
        guard caller.formatter == nil || caller.formatter?.bytes.count == OriginalResultLayout.localSize else {
            throw OriginalStateError.invalidStorage("Gameplay body caller formatter extent")
        }
        guard (library != nil) == (state.libraryCommands != nil) else {
            throw OriginalStateError.invalidStorage("Installed gameplay requires retained library owners")
        }
        var next = state, owned = context, random = crt, retained = caller, installed = library
        let textRenderer: OriginalSurfaceText.Renderer? = library == nil ? nil : { bytes,target,background,color,x,y,result,dc,observer in
            try installed!.text.draw(bytes,target:target,background:background,color:color,
                                     x:x,y:y,dcResult:result,dc:dc,observe:observer)
        }
        func emitCheckpoint(_ stage: Stage,_ match: OriginalMatchPreparation,_ input: OriginalInputControlContext,_ crt: OriginalCRTRandom) throws {
            try checkpoint(stage,match,input,crt)
            try ownedCheckpoint(stage,match,input,crt,installed)
        }
        // Control, physics, links, contacts, hits, cpoints, camera, drawing,
        // the post-draw impulses and lifecycle and the result recording run in
        // place on this body's own copy, which it drops when anything throws
        // (CORE_REALTIME B2 P4).
        try OriginalWorldControl.applyInPlace(state: &next, bundledLibrary: library != nil, observe: { try observe(.control(slot: $0, $1)) })
        try emitCheckpoint(.control, next, owned, random)
        // The hit pass's item word [esp+4c]: only a reserve respawn writes it
        // earlier in this call (APPLICATION_HIT_ITEM_SLOT_PLAN.md).
        var itemSlot: OriginalRequestSlotWord?
        try OriginalWorldPhysics.applyInPlace(state: &next, observe: { try observe(.physics($0)) },
            respawned: { itemSlot = .respawn() })
        try emitCheckpoint(.physics, next, owned, random)
        try OriginalWorldLinks.applyInPlace(state: &next, sse2Conversion: sse2, observe: { try observe(.links(.links, $0)) })
        try emitCheckpoint(.links, next, owned, random)
        try OriginalWorldContacts.apply(state: &next, bundledLibrary: library != nil, observe: { try observe(.contacts($0)) }, inPlace: true)
        try emitCheckpoint(.contacts, next, owned, random)
        // The full-pool item's root4c has one producer in this call, a reserve
        // respawn (above); otherwise it and the incoming cpoint partner have no
        // whole-body native producer, and children retain nil until used.
        if installed != nil {
            try OriginalLibWorldHits.applyInPlace(state:&next,crt:&random,library:&installed!.hits,itemSlot:itemSlot,sse2:sse2,
                                          observe:{ try observe(.hits($0)) })
        } else {
            try OriginalWorldHits.applyInPlace(state: &next, crt: &random, itemSlot: itemSlot, sse2: sse2, observe: { try observe(.hits($0)) })
        }
        try emitCheckpoint(.hits, next, owned, random)
        try OriginalWorldCPoints.applyInPlace(state: &next, sse2Conversion: sse2,
            observe: { try observe(.links(.attachments, $0)) }, afterStage: { stage, value in
                let point: Stage
                switch stage {
                case .actions: point = .cpointActions
                case .placement: point = .cpointPlacement
                case .cleanup: point = .cpointCleanup
                case .attachments: point = .attachments
                }
                try emitCheckpoint(point, value, owned, random)
            })
        let mode = try next.globals.integer(at: 0x451160-0x44d000, as: Int32.self)
        try OriginalWorldCamera.applyInPlace(state: &next, mode: mode, target: target,
            sse2Conversion: sse2, surface: surface, fillBacking: fillBacking,
            performFill: performFill, performBlit: performBlit, detail: detail, observe: { try observe(.drawing(.camera, $0)) })
        try emitCheckpoint(.camera, next, owned, random)
        let phase = try next.globals.integer(at: 0x450bd8-0x44d000, as: Int32.self)
        try OriginalWorldDrawing.applyInPlace(state: &next, target: target, phase: phase,
            surface: surface, resourceBitmap: resourceBitmap, performBlit: performBlit,
            detail: detail, observe: { try observe(.drawing(.drawing, $0)) })
        try emitCheckpoint(.drawing, next, owned, random)
        // Mission stage logic (mode1): its callee calls become the gameplay
        // body's own draws, fills, text, sounds and music requests.
        func mission(_ state: inout OriginalMatchPreparation) throws -> Bool {
            let globals = state.globals
            func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000, as: Int32.self) }
            try OriginalMissionStage.apply(state: &state, target: target, sse2: sse2, observe: { event in
                guard case .call(let c) = event else { return }
                let a = c.arguments.map { Int32(bitPattern: $0) }
                switch c.kind {
                case .bitmapDraw:
                    guard let holder = c.this, a.count == 6 else { throw OriginalStateError.invalidStorage("Mission bitmap call") }
                    let (record, source) = try resourceBitmap(holder)
                    let width = try g(0x44d78c), height = try g(0x44d790)
                    let input = OriginalBitmapDrawInput(x: a[0], y: a[1], frame: a[2], colorKey: c.arguments[3], mirrored: c.arguments[4],
                        sourceSurface: source, targetSurface: c.arguments[5], viewportWidth: width, viewportHeight: height)
                    try OriginalBitmapDrawing.draw(input, bitmap: record, detail: detail, observeRead: { r in
                        var e = OriginalFrontScreenEvent("read"); e.read = r; try observe(.drawing(.impulses, e))
                    }, observeClip: { clip in
                        var e = OriginalFrontScreenEvent("clip"); e.clip = clip; try observe(.drawing(.impulses, e))
                    }, perform: { b in
                        var e = OriginalFrontScreenEvent("blit"); e.blit = b; try observe(.drawing(.impulses, e)); return try performBlit(b)
                    })
                case .fill:
                    let request = try OriginalSurfaceFilling.request(target: UInt32(bitPattern: g(0x455608)), x: a[0], y: a[1],
                        width: a[2], height: a[3], color: c.arguments[4], backing: fillBacking())
                    var e = OriginalFrontScreenEvent("fill"); e.fill = request; try observe(.drawing(.impulses, e)); _ = try performFill(request)
                case .text:
                    _ = try OriginalSurfaceText.draw(c.text ?? [], target: c.arguments[0], background: c.arguments[2], color: c.arguments[3],
                        x: a[4], y: a[5], dcResult: presentation.dcResult, dc: presentation.dc, renderer: textRenderer,
                        observe: { try observe(.impulses($0)) })
                case .format:break
                case .sound:
                    guard let buffer = c.this else { throw OriginalStateError.invalidStorage("Mission sound call") }
                    try OriginalQueuedSound.play(bufferWordAddress: buffer, loop: c.arguments[0], globals: globals, request: soundRequest)
                case .musicStop:try OriginalMusicPlayback.stop(globals: globals, request: music)
                case .music:throw OriginalStateError.invalidStorage("Mission phase music (stage.dat has no music: entries) is not connected")
                }
            })
            return true
        }
        // War battle logic (mode4): status lines through the surface-text
        // renderer, preset labels through the bitmap font from their bytes.
        func war(_ state: inout OriginalMatchPreparation) throws -> Bool {
            // Font resources, target and viewport are not written by 43a860.
            let globals = state.globals
            try OriginalWarBattle.apply(state: &state, observe: { event in
                guard case .call(let c) = event else { return }
                let a = c.arguments.map { Int32(bitPattern: $0) }
                switch c.kind {
                case .text:
                    guard a.count == 5 else { throw OriginalStateError.invalidStorage("War text call") }
                    _ = try OriginalSurfaceText.draw(c.text, target: c.arguments[0], background: c.arguments[1], color: c.arguments[2],
                        x: a[3], y: a[4], dcResult: presentation.dcResult, dc: presentation.dc, renderer: textRenderer,
                        observe: { try observe(.impulses($0)) })
                case .format:break
                case .bitmapFont:
                    guard a.count == 6 else { throw OriginalStateError.invalidStorage("War label call") }
                    var label = try OriginalStateRecord(bytes: c.text+[0], defined: [Bool](repeating: true, count: c.text.count+1))
                    try OriginalBitmapFont.draw(.fourPass, text: &label, x: a[0], y: a[1], columns: a[2], lines: a[3], style: a[4],
                        cursor: c.arguments[5], globals: globals, resourceBitmap: resourceBitmap, performBlit: performBlit,
                        detail: detail, observe: { try observe(.drawing(.impulses, $0)) })
                }
            })
            return true
        }
        try OriginalPostDrawImpulses.applyInPlace(state: &next, dcResult: presentation.dcResult, dc: presentation.dc, textRenderer: textRenderer, mission: { try mission(&$0) }, war: { try war(&$0) }, observe: { event in
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
        try emitCheckpoint(.impulses, next, owned, random)
        // Keep each live slot's known producers inside the same original loop.
        // Earlier caller words whose complete lifetimes are unrecovered remain
        // nil; these are not seeded or carried between separate match calls.
        // SP+34 is known: 41f2c7 stores −4 − World on every call.
        var scratch = OriginalPostDrawScratch(requestSlot: .initial())
        let transforms = try OriginalPostDrawLifecycle.applyInPlace(state: &next, scratch: &scratch, sse2: sse2, library: installed?.transforms,
            observe: { try observe(.lifecycle($0)) })
        if let transforms { installed!.transforms = transforms }
        try emitCheckpoint(.lifecycle, next, owned, random)
        // SP+34 as the loop left it: 41f2c7's −4 − World or the loop's last writer.
        var spawn = scratch.requestSlot
        try OriginalPostDrawCommands.apply(state: &next, requestSlot: &spawn, sse2: sse2,
            observe: { try observe(.commands($0)) })
        try emitCheckpoint(.commands, next, owned, random)
        try OriginalWorldHUD.apply(state: &next, surface: surface, resourceBitmap: resourceBitmap,
            performBlit: performBlit, detail: detail, observe: { try observe(.drawing(.hud, $0)) })
        try emitCheckpoint(.hud, next, owned, random)
        var notice: OriginalStateRecord?
        if let storage = retained.formatter {
            notice = try .init(bytes: Array(storage.bytes[0x20...]), defined: Array(storage.defined[0x20...]))
        }
        try OriginalPostHUDNotices.apply(state: next, local: &notice,
            dcResult: presentation.dcResult, dc: presentation.dc, fillBacking: fillBacking,
            resourceBitmap: resourceBitmap, performFill: performFill, performBlit: performBlit, textRenderer: textRenderer,
            observe: { try observe(.drawing(.notices, $0)) })
        if let notice, let original = retained.formatter {
            retained.formatter = try .init(bytes: Array(original.bytes[..<0x20])+notice.bytes,
                defined: Array(original.defined[..<0x20])+notice.defined)
        }
        try emitCheckpoint(.notices, next, owned, random)
        let result = try OriginalResultRecording.applyInPlace(state: &next, context: &owned,
            stageDefeated: round.stageDefeated, allocate: allocate, processorSignature: processorSignature,
            open: open, write: write, close: close, observe: { try observe(.recording($0)) })
        try emitCheckpoint(.recording, next, owned, random)
        try OriginalResultLayout.apply(state: &next, context: owned, continuation: result.continuation,
            stageDefeated: round.stageDefeated, indicatorTarget: retained.indicatorTarget, local: &retained.formatter,
            dcResult: presentation.dcResult, dc: presentation.dc, surface: surface, resourceBitmap: resourceBitmap,
            performBlit: performBlit, textRenderer: textRenderer, detail: detail, observe: { try observe(.drawing(.layout, $0)) })
        try emitCheckpoint(.layout, next, owned, random)
        try OriginalGameplayOutput.returnFromDispatcher(world: &next.world, globals: &next.globals,
            memory: &owned.memory, input: presentation, resourceBitmap: resourceBitmap,
            performBlit: performBlit, soundRequest: soundRequest, textRenderer: textRenderer, detail: detail, observe: { try observe(.drawing(.output, $0)) })
        try emitCheckpoint(.output, next, owned, random)
        state = next; context = owned; crt = random; caller = retained
        return installed
    }
}
