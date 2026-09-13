/// The next actual World2 suspension, retaining the previous loaded owners.
/// No common sound, catalog, Actor or interface constructor is re-executed.
public struct OriginalApplicationLoadedCycleSession {
    public typealias Session = OriginalApplicationMenuSession
    public typealias Input = OriginalApplicationInputSession
    public enum Boundary: Error, Equatable { case alreadyPrepared, requiresLoadedWorld }
    public let entry: Session.PendingLoading,owners: Session.LoadedOwners
    public let bindings: OriginalApplicationMatchBindings
    public private(set) var pendingContinuation: Input.PendingContinuation?
    init(pending: Session.PendingLoading,owners: Session.LoadedOwners) throws {
        try pending.state.validateAliases()
        guard try pending.state.full.integer(at:0xbb00,as:Int32.self) == 2,
              try pending.state.full.integer(at:0x5c,as:Int32.self) != 1 else { throw Boundary.requiresLoadedWorld }
        entry = pending;self.owners = owners;bindings = try .init(pending:owners.entry)
    }
    @discardableResult
    public mutating func advance<Environment>(environment: inout Environment,
        dispatch: (OriginalLocalInputDispatch,inout OriginalMatchPreparation,inout Environment) throws -> Void = { _,_,_ in
            throw OriginalStateError.invalidStorage("Application loaded cycle needs original AI/object child")
        },
        controlBoundary: (OriginalInputControlRequest,inout Environment) throws -> OriginalInputControlResponse,
        replayEvent: (OriginalReplayTickEvent,inout Environment) throws -> Void = { _,_ in },
        roundEvent: (OriginalMatchRoundEvent,inout Environment) throws -> Void = { _,_ in },
        prologue: (OriginalMatchPreparation,Session.State,Bool,[UInt8],[UInt8],inout Environment) throws -> Void = { _,_,_,_,_,_ in },
        checkpoint: (OriginalLoadedMatchEntry.Checkpoint,OriginalMatchPreparation,Session.State,[UInt8],inout Environment) throws -> Void = { _,_,_,_,_ in },
        beforeCommit: (Input.PendingContinuation,inout Environment) throws -> Void = { _,_ in }) throws -> Input.PendingContinuation {
        guard pendingContinuation == nil else { throw Boundary.alreadyPrepared }
        var candidate = environment,state = entry.state
        var model = try bindings.read(state,retaining:owners.match),context = try bindings.inputContext(state)
        var commands: [UInt8] = [],playback: [UInt8] = [],paused = false
        var operations = entry.stagedEffects.map(Input.Operation.menu)
        let base = state,binding = bindings
        let result = try OriginalLoadedMatchCycle.run(state:&model,context:&context,controlBoundary:{ q in
            let response = try controlBoundary(q,&candidate)
            switch q.kind {
            case .action,.soundRequest,.inputReset,.restorePlayback:break
            case .asyncSelect,.ioctl,.send,.receive,.message,.method,.free,.postMessage:operations.append(.control(q,response))
            }
            return response
        },dispatch:{ try dispatch($0,&$1,&candidate) },replayEvent:{ e in
            if e.kind == .message { operations.append(.replayMessage(e)) };try replayEvent(e,&candidate)
        },roundEvent:{ e in
            if e.kind == .method { operations.append(.roundMethod(e)) };try roundEvent(e,&candidate)
        },prologue:{ match,input,isPaused,buffer,replay in
            paused = isPaused;commands = buffer;playback = replay
            var snapshot = base;try binding.store(match,context:input,in:&snapshot)
            try prologue(match,snapshot,isPaused,buffer,replay,&candidate)
        },checkpoint:{ phase,match,input,buffer in
            commands = buffer
            var snapshot = base;try binding.store(match,context:input,in:&snapshot)
            try checkpoint(phase,match,snapshot,buffer,&candidate)
        })
        try bindings.store(model,context:context,in:&state);context.memory = state.memory
        let pending = Input.PendingContinuation(entry:owners.entry,state:state,match:model,inputContext:context,music:owners.music,
            commands:commands,playbackCommands:playback,paused:paused,round:result,operations:operations,graphics:entry.stagedGraphics,
            loading:entry,menuResources:owners.resources,menuBackgrounds:owners.backgrounds)
        try beforeCommit(pending,&candidate)
        pendingContinuation = pending;environment = candidate;return pending
    }
}
