/// Continue the actual owned pool/UI at41c581 through local/control/received
/// input, replay and round dispatch. The returned child still awaits its menu,
/// gameplay or rendering continuation and the retained outer-loop transaction.
public struct OriginalApplicationInputSession {
    public typealias Pool = OriginalApplicationPoolSession
    public typealias State = OriginalApplicationMenuSession.State
    public enum Boundary: Error, Equatable { case alreadyPrepared, commandExtent }
    public enum Operation: Equatable {
        case preceding(Pool.Operation)
        case menu(OriginalApplicationMenuSession.Effect)
        case control(OriginalInputControlRequest,OriginalInputControlResponse)
        case replayMessage(OriginalReplayTickEvent)
        case roundMethod(OriginalMatchRoundEvent)
    }
    public struct PendingContinuation {
        /// The values, fixed at creation, in one shared object: the loaded
        /// cycle's continuation is copied with every Host stage, pending return
        /// and batch of a tick (~380 references per copy before;
        /// CORE_REALTIME phase 4m, as 4a and 4l). Reads borrow through `_read`.
        private final class Storage {
            let entry: Pool.PendingInput, state: State, match: OriginalMatchPreparation
            let inputContext: OriginalInputControlContext, music: OriginalMusicMemory
            let commands: [UInt8], playbackCommands: [UInt8], paused: Bool
            let round: OriginalMatchRoundResult, operations: [Operation]
            let graphics: [OriginalApplicationGraphics.Command]
            let loading: OriginalApplicationMenuSession.PendingLoading
            let menuResources: OriginalMenuResourceLoading
            let menuBackgrounds: [UInt32:OriginalLoadedBitmap]
            init(entry: Pool.PendingInput,state: State,match: OriginalMatchPreparation,inputContext: OriginalInputControlContext,
                 music: OriginalMusicMemory,commands: [UInt8],playbackCommands: [UInt8],paused: Bool,round: OriginalMatchRoundResult,
                 operations: [Operation],graphics: [OriginalApplicationGraphics.Command],loading: OriginalApplicationMenuSession.PendingLoading,
                 menuResources: OriginalMenuResourceLoading,menuBackgrounds: [UInt32:OriginalLoadedBitmap]) {
                self.entry = entry;self.state = state;self.match = match;self.inputContext = inputContext;self.music = music
                self.commands = commands;self.playbackCommands = playbackCommands;self.paused = paused;self.round = round
                self.operations = operations;self.graphics = graphics;self.loading = loading
                self.menuResources = menuResources;self.menuBackgrounds = menuBackgrounds
            }
        }
        private let storage: Storage
        public var entry: Pool.PendingInput { _read { yield storage.entry } }
        public var state: State { _read { yield storage.state } }
        public var match: OriginalMatchPreparation { _read { yield storage.match } }
        public var inputContext: OriginalInputControlContext { _read { yield storage.inputContext } }
        public var music: OriginalMusicMemory { _read { yield storage.music } }
        public var commands: [UInt8] { _read { yield storage.commands } }
        public var playbackCommands: [UInt8] { _read { yield storage.playbackCommands } }
        public var paused: Bool { storage.paused }
        public var round: OriginalMatchRoundResult { _read { yield storage.round } }
        public var operations: [Operation] { _read { yield storage.operations } }
        public var graphics: [OriginalApplicationGraphics.Command] { _read { yield storage.graphics } }
        public var loading: OriginalApplicationMenuSession.PendingLoading { _read { yield storage.loading } }
        public var menuResources: OriginalMenuResourceLoading { _read { yield storage.menuResources } }
        public var menuBackgrounds: [UInt32:OriginalLoadedBitmap] { _read { yield storage.menuBackgrounds } }
        init(entry: Pool.PendingInput,state: State,match: OriginalMatchPreparation,
             inputContext: OriginalInputControlContext,music: OriginalMusicMemory,
             commands: [UInt8],playbackCommands: [UInt8],paused: Bool,
             round: OriginalMatchRoundResult,operations: [Operation],graphics: [OriginalApplicationGraphics.Command],
             loading: OriginalApplicationMenuSession.PendingLoading? = nil,
             menuResources: OriginalMenuResourceLoading = .init(),menuBackgrounds: [UInt32:OriginalLoadedBitmap] = [:]) {
            storage = Storage(entry:entry,state:state,match:match,inputContext:inputContext,music:music,commands:commands,
                              playbackCommands:playbackCommands,paused:paused,round:round,operations:operations,graphics:graphics,
                              loading:loading ?? entry.entry.entry.entry,menuResources:menuResources,menuBackgrounds:menuBackgrounds)
        }
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
        // This application uses the bundled-library handlers. Its requested
        // Object word has no established startup backing and is not known zero.
        match.libraryCommands = .init()
        match.bitmapOwners = Dictionary(uniqueKeysWithValues:entry.entry.snapshot.bitmapTokens.enumerated().map { ($0.offset,$0.element) })
        match.bitmapSurfaceOwners = Dictionary(uniqueKeysWithValues:entry.entry.snapshot.bitmapSurfaces.enumerated().map { ($0.offset,$0.element) })
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
