import Foundation

/// 41c581 through input, replay bookkeeping and the original round dispatcher.
/// Accepts the state and command buffers produced by loading/the caller.
/// Rendering, the next gameplay passes and the menu are returned continuations.
public enum OriginalLoadedMatchEntry {
    public enum Checkpoint: String, Codable, Sendable {
        case localBeforeDispatch, local, control, received, replay, round
    }
    public static func run(state: inout OriginalMatchPreparation, paused: Bool,
                           commands: inout [UInt8], playbackCommands: [UInt8],
                           context: inout OriginalInputControlContext,
                           dispatch: (OriginalLocalInputDispatch, inout OriginalMatchPreparation) throws -> Void = { _,_ in
                               throw OriginalStateError.invalidStorage("Loaded entry needs the original AI/object child")
                           },
                           controlBoundary: OriginalMatchPreparation.InputControlBoundary,
                           replayEvent: (OriginalReplayTickEvent) throws -> Void = { _ in },
                           roundEvent: (OriginalMatchRoundEvent) throws -> Void = { _ in },
                           checkpoint: (Checkpoint, OriginalMatchPreparation, OriginalInputControlContext, [UInt8]) throws -> Void = { _,_,_,_ in }) throws -> OriginalMatchRoundResult {
        var candidate = state, output = commands, owned = context
        try candidate.beginLocalInput(paused: paused,commands: &output,beforeDispatch: { value,buffer in
            try checkpoint(.localBeforeDispatch,value,owned,buffer)
        },dispatch: dispatch)
        try checkpoint(.local,candidate,owned,output)
        // The later sub-steps run in place on this entry's own candidate, which
        // is dropped when anything throws (CORE_REALTIME B2): no second copy
        // of the globals, actors or context per sub-step.
        _ = try candidate.controlInputInPlace(commands: &output,playbackCommands: playbackCommands,context: &owned,boundary: controlBoundary)
        try checkpoint(.control,candidate,owned,output)
        let next = try candidate.receiveInputInPlace(paused: paused,commands: &output,playbackCommands: playbackCommands)
        try checkpoint(.received,candidate,owned,output)
        try candidate.finishReplayInputInPlace(entry: next == .recording ? .recording : .playbackChecksum,paused: paused,
            commands: output,playbackCommands: playbackCommands,context: &owned,observe: replayEvent)
        try checkpoint(.replay,candidate,owned,output)
        let result = try candidate.beginMatchRoundInPlace(paused: paused,context: &owned,observe: roundEvent)
        try checkpoint(.round,candidate,owned,output)
        state = candidate;commands = output;context = owned
        return result
    }
}
