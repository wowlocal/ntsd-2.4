/// An already loaded match call from its own input/round entry through
/// the gameplay body and the enclosing dispatcher's return effect. The caller
/// supplies platform responses and owned resource resolvers, never expected
/// state. Menu and early-epilogue continuations remain explicit
/// unsupported boundaries of this entry, with the complete call rolled back.
public enum OriginalLoadedGameplayCall {
    public static func run(state: inout OriginalMatchPreparation,
        context: inout OriginalInputControlContext, crt: inout OriginalCRTRandom,
        caller: inout OriginalGameplayBody.Caller,
        controlBoundary: OriginalMatchPreparation.InputControlBoundary,
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
        dispatch: (OriginalLocalInputDispatch, inout OriginalMatchPreparation) throws -> Void = { _,_ in
            throw OriginalStateError.invalidStorage("Loaded gameplay call needs original AI/object child")
        },
        replayEvent: (OriginalReplayTickEvent) throws -> Void = { _ in },
        roundEvent: (OriginalMatchRoundEvent) throws -> Void = { _ in },
        prologue: (OriginalMatchPreparation, OriginalInputControlContext, Bool, [UInt8], [UInt8]) throws -> Void = { _,_,_,_,_ in },
        inputCheckpoint: (OriginalLoadedMatchEntry.Checkpoint, OriginalMatchPreparation, OriginalInputControlContext, [UInt8]) throws -> Void = { _,_,_,_ in },
        bodyEntry: (OriginalMatchPreparation, OriginalInputControlContext, OriginalCRTRandom, OriginalMatchRoundResult) throws -> Void = { _,_,_,_ in },
        observe: (OriginalGameplayBody.Event) throws -> Void = { _ in },
        checkpoint: (OriginalGameplayBody.Stage, OriginalMatchPreparation, OriginalInputControlContext, OriginalCRTRandom) throws -> Void = { _,_,_,_ in },
        pausedObserve: (OriginalPausedGameplay.Stage, OriginalFrontScreenEvent) throws -> Void = { _,_ in },
        pausedCheckpoint: (OriginalPausedGameplay.Stage, OriginalMatchPreparation, OriginalInputControlContext) throws -> Void = { _,_,_ in }) throws -> OriginalMatchRoundResult {
        var next = state, owned = context, random = crt, local = caller
        let round = try OriginalLoadedMatchCycle.run(state: &next, context: &owned,
            controlBoundary: controlBoundary, dispatch: dispatch, replayEvent: replayEvent,
            roundEvent: roundEvent, prologue: prologue, checkpoint: inputCheckpoint)
        guard round.continuation == .gameplay || round.continuation == .pausedRendering else {
            throw OriginalStateError.invalidStorage("Loaded gameplay call has unsupported continuation: "+round.continuation.rawValue)
        }
        try bodyEntry(next, owned, random, round)
        if round.continuation == .pausedRendering {
            try OriginalPausedGameplay.apply(state: &next, context: &owned, round: round, caller: &local,
                target: target, presentation: presentation, surface: surface, resourceBitmap: resourceBitmap,
                fillBacking: fillBacking, performFill: performFill, performBlit: performBlit,
                soundRequest: soundRequest, observe: pausedObserve, checkpoint: pausedCheckpoint)
        } else {
            try OriginalGameplayBody.apply(state: &next, context: &owned, crt: &random,
            round: round, caller: &local, target: target, presentation: presentation, sse2: sse2,
            surface: surface, resourceBitmap: resourceBitmap, fillBacking: fillBacking,
            performFill: performFill, performBlit: performBlit, allocate: allocate,
            processorSignature: processorSignature, open: open, write: write, close: close,
            soundRequest: soundRequest, observe: observe, checkpoint: checkpoint)
        }
        // Input, replay-command writes, round changes, simulation and output
        // commit together. Observers buffer external effects until this returns.
        // Caller storage is justified for this invocation; callers must not
        // carry it into a later original frame without recovered provenance.
        state = next; context = owned; crt = random; caller = local
        return round
    }
}
