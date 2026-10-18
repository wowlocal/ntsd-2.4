import Foundation

/// Repeated4246b0/World2 ->41bc90 with an already loaded catalog.
/// The original prologue owns phase/pause and clears both command buffers.
/// Menu, paused rendering and gameplay remain explicit round continuations.
public enum OriginalLoadedMatchCycle {
    public static func run(state: inout OriginalMatchPreparation,context: inout OriginalInputControlContext,
        controlBoundary: OriginalMatchPreparation.InputControlBoundary,
        dispatch: (OriginalLocalInputDispatch,inout OriginalMatchPreparation) throws -> Void = { _,_ in
            throw OriginalStateError.invalidStorage("Loaded cycle needs original AI/object child")
        },
        replayEvent: (OriginalReplayTickEvent) throws -> Void = { _ in },
        roundEvent: (OriginalMatchRoundEvent) throws -> Void = { _ in },
        prologue: (OriginalMatchPreparation,OriginalInputControlContext,Bool,[UInt8],[UInt8]) throws -> Void = { _,_,_,_,_ in },
        checkpoint: (OriginalLoadedMatchEntry.Checkpoint,OriginalMatchPreparation,OriginalInputControlContext,[UInt8]) throws -> Void = { _,_,_,_ in }) throws -> OriginalMatchRoundResult {
        var candidate = state,owned = context
        guard try candidate.world.integer(at: 0,as: Int32.self) == 2,
              try candidate.globals.integer(at: 0x44d05c-OriginalMatchPreparation.globalBase,as: Int32.self) != 1 else {
            throw OriginalStateError.invalidStorage("Loaded cycle requires World2 and completed loading")
        }
        let paused = try OriginalInitialLoading.begin(globals: &candidate.globals)
        var commands = [UInt8](repeating: 0,count: 10),playback = commands
        try candidate.prepareReplayCommands(paused: paused,commands: &commands,playbackCommands: &playback,context: owned,observe: replayEvent)
        try prologue(candidate,owned,paused,commands,playback)
        let result = try OriginalLoadedMatchEntry.run(state: &candidate,paused: paused,commands: &commands,playbackCommands: playback,context: &owned,
            dispatch: dispatch,controlBoundary: controlBoundary,replayEvent: replayEvent,roundEvent: roundEvent,checkpoint: checkpoint)
        state = candidate;context = owned
        return result
    }
}
