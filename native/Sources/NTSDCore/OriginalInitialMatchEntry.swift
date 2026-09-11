/// The first41c581 input/replay/round continuation of a completed native load.
/// Own UI/catalog/audio remain available with the resulting state. The returned
/// round continuation still requires its menu/render/gameplay caller and ret4.
public struct OriginalInitialMatchEntry {
    public var state: OriginalMatchPreparation
    public var inputContext: OriginalInputControlContext
    public let commands: [UInt8], playbackCommands: [UInt8], paused: Bool
    public let round: OriginalMatchRoundResult
    public let commonSounds: [OriginalWaveLoadResult]
    public let registeredSounds: OriginalRegisteredSoundLoading

    /// Caller precision and saved-playback/resource context need their own
    /// provenance. Buffer platform effects in the value-semantic environment;
    /// thrown callbacks retain it and do not publish a partially entered match.
    public static func run<Environment>(loading: OriginalInitialLoading,
        inputContext: OriginalInputControlContext, arithmeticPrecision: OriginalArithmeticPrecision,
        environment: inout Environment,
        dispatch: (OriginalLocalInputDispatch, inout OriginalMatchPreparation, inout Environment) throws -> Void = { _,_,_ in
            throw OriginalStateError.invalidStorage("Initial match entry needs the original AI/object child")
        },
        controlBoundary: (OriginalInputControlRequest, inout Environment) throws -> OriginalInputControlResponse,
        replayEvent: (OriginalReplayTickEvent, inout Environment) throws -> Void = { _,_ in },
        roundEvent: (OriginalMatchRoundEvent, inout Environment) throws -> Void = { _,_ in },
        checkpoint: (OriginalLoadedMatchEntry.Checkpoint, OriginalMatchPreparation, OriginalInputControlContext, [UInt8], inout Environment) throws -> Void = { _,_,_,_,_ in },
        beforeCommit: (Self, inout Environment) throws -> Void = { _,_ in }) throws -> Self {
        guard loading.commands.count == 20 else { throw OriginalStateError.invalidStorage("Initial command-buffer extent") }
        var state = try OriginalMatchPreparation(loading: loading, arithmeticPrecision: arithmeticPrecision)
        var owned = inputContext, candidate = environment
        var commands = Array(loading.commands.prefix(10))
        let playback = Array(loading.commands.suffix(10))
        let result = try OriginalLoadedMatchEntry.run(state: &state, paused: loading.paused,
            commands: &commands, playbackCommands: playback, context: &owned,
            dispatch: { try dispatch($0, &$1, &candidate) },
            controlBoundary: { try controlBoundary($0, &candidate) },
            replayEvent: { try replayEvent($0, &candidate) }, roundEvent: { try roundEvent($0, &candidate) },
            checkpoint: { try checkpoint($0, $1, $2, $3, &candidate) })
        let entry = Self(state: state, inputContext: owned, commands: commands, playbackCommands: playback,
            paused: loading.paused, round: result, commonSounds: loading.commonSounds,
            registeredSounds: loading.registeredSounds)
        try beforeCommit(entry, &candidate)
        environment = candidate
        return entry
    }
}

extension OriginalMatchPreparation {
    /// Transfer the complete loaded game state, including the ten interface
    /// resources. Choosing arithmetic precision is the enclosing caller's job.
    public init(loading: OriginalInitialLoading, arithmeticPrecision: OriginalArithmeticPrecision) throws {
        try self.init(catalog: loading.catalog, bootstrap: loading.bootstrap, globals: loading.globals,
            interface: loading.interface, arithmeticPrecision: arithmeticPrecision)
    }
}
