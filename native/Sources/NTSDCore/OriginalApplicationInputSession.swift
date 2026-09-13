/// Continue the actual owned pool/UI at41c581 through local/control/received
/// input, replay and round dispatch. The returned child still awaits its menu,
/// gameplay or rendering continuation and the retained outer-loop transaction.
public struct OriginalApplicationInputSession {
    public typealias Pool = OriginalApplicationPoolSession
    public typealias State = OriginalApplicationMenuSession.State
    public enum Boundary: Error, Equatable { case alreadyPrepared, commandExtent }
    public enum Operation: Equatable {
        case preceding(Pool.Operation)
        case control(OriginalInputControlRequest,OriginalInputControlResponse)
        case replayMessage(OriginalReplayTickEvent)
        case roundMethod(OriginalMatchRoundEvent)
    }
    public struct PendingContinuation {
        public let entry: Pool.PendingInput, state: State, match: OriginalMatchPreparation
        public let inputContext: OriginalInputControlContext, music: OriginalMusicMemory
        public let commands: [UInt8], playbackCommands: [UInt8], paused: Bool
        public let round: OriginalMatchRoundResult, operations: [Operation]
        public let graphics: [OriginalApplicationGraphics.Command]
    }
    public let entry: Pool.PendingInput, bindings: OriginalApplicationMatchBindings
    public let arithmeticPrecision: OriginalArithmeticPrecision
    public private(set) var pendingContinuation: PendingContinuation?

    /// Precision is an explicit caller context, never a default inferred from
    /// old test fixtures. WinMain alone does not prove earlier CRT initialization.
    public init(pending: Pool.PendingInput, arithmeticPrecision: OriginalArithmeticPrecision) throws {
        try pending.state.validateAliases()
        guard pending.loaded.commands.count == 20 else { throw Boundary.commandExtent }
        entry = pending;bindings = try .init(pending:pending);self.arithmeticPrecision = arithmeticPrecision
    }

    /// Environment must value-own its tentative platform replies/effects.
    /// Observations are not backend operations. Any throw keeps this session,
    /// its input parent and the caller environment unchanged.
    @discardableResult
    public mutating func advance<Environment>(environment: inout Environment,
        dispatch: (OriginalLocalInputDispatch,inout OriginalMatchPreparation,inout Environment) throws -> Void = { _,_,_ in
            throw OriginalStateError.invalidStorage("Application input needs the original AI/object child")
        },
        controlBoundary: (OriginalInputControlRequest,inout Environment) throws -> OriginalInputControlResponse,
        replayEvent: (OriginalReplayTickEvent,inout Environment) throws -> Void = { _,_ in },
        roundEvent: (OriginalMatchRoundEvent,inout Environment) throws -> Void = { _,_ in },
        checkpoint: (OriginalLoadedMatchEntry.Checkpoint,OriginalMatchPreparation,State,[UInt8],inout Environment) throws -> Void = { _,_,_,_,_ in },
        beforeCommit: (PendingContinuation,inout Environment) throws -> Void = { _,_ in }) throws -> PendingContinuation {
        guard pendingContinuation == nil else { throw Boundary.alreadyPrepared }
        var state = entry.state,candidate = environment
        var match = try bindings.read(state,catalog:entry.loaded.catalog,interface:entry.loaded.interface,
                                      arithmeticPrecision:arithmeticPrecision)
        var context = try bindings.inputContext(state),commands = Array(entry.loaded.commands.prefix(10))
        let playback = Array(entry.loaded.commands.suffix(10)),original = state,binding = bindings
        var operations = entry.operations.map(Operation.preceding)
        let result = try OriginalLoadedMatchEntry.run(state:&match,paused:entry.loaded.paused,
            commands:&commands,playbackCommands:playback,context:&context,
            dispatch:{ try dispatch($0,&$1,&candidate) },controlBoundary:{ q in
                let response = try controlBoundary(q,&candidate)
                switch q.kind {
                case .action,.soundRequest,.inputReset,.restorePlayback:break
                case .asyncSelect,.ioctl,.send,.receive,.message,.method,.free,.postMessage:
                    operations.append(.control(q,response))
                }
                return response
            },replayEvent:{ event in
                if event.kind == .message { operations.append(.replayMessage(event)) }
                try replayEvent(event,&candidate)
            },roundEvent:{ event in
                if event.kind == .method { operations.append(.roundMethod(event)) }
                try roundEvent(event,&candidate)
            },checkpoint:{ phase,model,input,buffer in
                var snapshot = original
                try binding.store(model,context:input,in:&snapshot)
                try checkpoint(phase,model,snapshot,buffer,&candidate)
            })
        try bindings.store(match,context:context,in:&state)
        // The application memory now contains the current Actor records too;
        // retain this same joined owner in the returned input context.
        context.memory = state.memory
        let pending = PendingContinuation(entry:entry,state:state,match:match,inputContext:context,
            music:entry.entry.startup.music,commands:commands,playbackCommands:playback,paused:entry.loaded.paused,
            round:result,operations:operations,graphics:entry.graphics)
        try beforeCommit(pending,&candidate)
        pendingContinuation = pending;environment = candidate;return pending
    }
}
