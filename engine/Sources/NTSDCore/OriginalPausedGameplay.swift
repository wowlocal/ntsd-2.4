/// Paused rendering from the own round continuation through ordinary output
/// and dispatcher return. This caller draws the background directly and keeps
/// command flags. It does not run simulation or the unpaused camera pass.
public enum OriginalPausedGameplay {
    public enum Stage: String, CaseIterable {
        case background, drawing, hud, pauseBitmap, indicators, output
    }

    /// Stages all mutable game/resource/caller storage until output completes.
    /// The caller must buffer external device events until the loaded call commits.
    @discardableResult
    public static func apply(state: inout OriginalMatchPreparation,
        context: inout OriginalInputControlContext, round: OriginalMatchRoundResult,
        caller: inout OriginalGameplayBody.Caller, target: UInt32,
        presentation: OriginalMenuPresentationInput,
        library: OriginalGameplayBody.Library? = nil,
        surface: (Int) throws -> UInt32,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        fillBacking: () throws -> [UInt8],
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        soundRequest: OriginalQueuedSound.Request,
        observe: (Stage, OriginalFrontScreenEvent) throws -> Void = { _,_ in },
        checkpoint: (Stage, OriginalMatchPreparation, OriginalInputControlContext) throws -> Void = { _,_,_ in },
        ownedCheckpoint: (Stage, OriginalMatchPreparation, OriginalInputControlContext, OriginalGameplayBody.Library?) throws -> Void = { _,_,_,_ in }) throws -> OriginalGameplayBody.Library? {
        guard round.continuation == .pausedRendering else {
            throw OriginalStateError.invalidStorage("Paused gameplay requires the own paused continuation")
        }
        guard (library != nil) == (state.libraryCommands != nil) else {
            throw OriginalStateError.invalidStorage("Installed paused gameplay requires retained library owners")
        }
        var next = state, owned = context, retained = caller, installed = library
        let textRenderer: OriginalSurfaceText.Renderer? = library == nil ? nil : { bytes,target,background,color,x,y,result,dc,observer in
            try installed!.text.draw(bytes,target:target,background:background,color:color,
                                     x:x,y:y,dcResult:result,dc:dc,observe:observer)
        }
        func emitCheckpoint(_ stage: Stage,_ match: OriginalMatchPreparation,_ input: OriginalInputControlContext) throws {
            try checkpoint(stage,match,input)
            try ownedCheckpoint(stage,match,input,installed)
        }
        try next.globals.write(Int32(1), at: 0x44d02c-0x44d000)
        let bitmaps = next.bitmaps, released = next.releasedBitmaps
        try OriginalBackgroundDrawing.draw(backgrounds: &next.backgrounds,
            globals: next.globals, target: target, bitmap: { token in
                guard token != 0, Int(token)-1 < bitmaps.count, !released.contains(Int(token)-1) else {
                    throw OriginalStateError.invalidStorage("Paused background bitmap ownership")
                }
                return try (bitmaps[Int(token)-1].storage, surface(Int(token)-1))
            }, fillBacking: fillBacking, performFill: performFill, performBlit: performBlit,
            observe: { try observe(.background, $0) })
        try emitCheckpoint(.background, next, owned)
        let phase = try next.globals.integer(at: 0x450bd8-0x44d000, as: Int32.self)
        try OriginalWorldDrawing.apply(state: &next, target: target, phase: phase,
            surface: surface, resourceBitmap: resourceBitmap, performBlit: performBlit,
            observe: { try observe(.drawing, $0) })
        try emitCheckpoint(.drawing, next, owned)
        try OriginalWorldHUD.drawPreservingCommands(state: &next, surface: surface,
            resourceBitmap: resourceBitmap, performBlit: performBlit,
            observe: { try observe(.hud, $0) })
        try emitCheckpoint(.hud, next, owned)
        let token = try next.globals.integer(at: 0x44ff8c-0x44d000, as: UInt32.self)
        let destination = try next.globals.integer(at: 0x455608-0x44d000, as: UInt32.self)
        try observe(.pauseBitmap, .init("draw", [token, 360, 288, UInt32.max, 1, 0, destination]))
        guard token != 0 else { throw OriginalStateError.invalidStorage("Paused bitmap is null") }
        let (bitmap, sourceSurface) = try resourceBitmap(token)
        let input = try OriginalBitmapDrawInput(x: 360, y: 288, frame: -1, colorKey: 1, mirrored: 0,
            sourceSurface: sourceSurface, targetSurface: destination,
            viewportWidth: next.globals.integer(at: 0x44d78c-0x44d000, as: Int32.self),
            viewportHeight: next.globals.integer(at: 0x44d790-0x44d000, as: Int32.self))
        try OriginalBitmapDrawing.draw(input, bitmap: bitmap, observeRead: { value in
            var event = OriginalFrontScreenEvent("read"); event.read = value; try observe(.pauseBitmap, event)
        }, observeClip: { value in
            var event = OriginalFrontScreenEvent("clip"); event.clip = value; try observe(.pauseBitmap, event)
        }, perform: { value in
            var event = OriginalFrontScreenEvent("blit"); event.blit = value; try observe(.pauseBitmap, event)
            return try performBlit(value)
        })
        try emitCheckpoint(.pauseBitmap, next, owned)
        // The paused caller already holds its target in ESI and pushes it
        // before joining the indicator. No unknown retained stage result is read.
        try OriginalResultLayout.apply(state: &next, context: owned, continuation: .indicators,
            stageDefeated: nil, indicatorTarget: target, local: &retained.formatter,
            dcResult: presentation.dcResult, dc: presentation.dc, surface: surface,
            resourceBitmap: resourceBitmap, performBlit: performBlit, textRenderer: textRenderer,
            observe: { try observe(.indicators, $0) })
        try emitCheckpoint(.indicators, next, owned)
        try OriginalGameplayOutput.returnFromDispatcher(world: &next.world, globals: &next.globals,
            memory: &owned.memory, input: presentation, resourceBitmap: resourceBitmap,
            performBlit: performBlit, soundRequest: soundRequest, textRenderer: textRenderer,
            observe: { try observe(.output, $0) })
        try emitCheckpoint(.output, next, owned)
        state = next; context = owned; caller = retained
        return installed
    }
}
