import Foundation

/// In-process owner of recovered application transactions. Platform preparation
/// must use only staged, independently owned mutable state and immutable inputs.
/// It cannot perform host IO or supply an expected Core after-state. Committed
/// batches still need a backend with its own actual device/failure contract.
public final class OriginalApplicationHostSession<Platform: OriginalApplicationStartupPlatform> {
    public typealias Application = OriginalApplicationBootstrap
    public typealias Session = OriginalApplicationMenuSession
    public typealias LoadedMenu = OriginalApplicationLoadedMenuSession
    public typealias GameplayInput = OriginalApplicationInputSession.PendingContinuation
    public enum Boundary: Error, Equatable {
        case reentrantAttempt, sharedPlatform, pendingLoading, publicationExtent, staleSequence
        case noPendingLoading, alreadyPreparedLoading, noPreparedLoading, differentLoadingAttempt, unreturnedLoading
        case noPreparedMatchPrelude, noPreparedGameplayInput
    }
    public struct Inputs {
        public let initialization: Application.MenuInputs?
        public let responses: Session.Responses
        public let queue: [Session.Loop.Response], windowDefault: [Int32]
        public let surface: [OriginalWindowInitialization.Response]
        public let lifecycle: [OriginalWindowInitialization.Response]
        public init(initialization: Application.MenuInputs? = nil, responses: Session.Responses,
            queue: [Session.Loop.Response], windowDefault: [Int32] = [],
            surface: [OriginalWindowInitialization.Response] = [],
            lifecycle: [OriginalWindowInitialization.Response] = []) {
            self.initialization = initialization; self.responses = responses
            self.queue = queue; self.windowDefault = windowDefault
            self.surface = surface; self.lifecycle = lifecycle
        }
    }
    /// Native owners for exactly one committed handoff. The value survives
    /// later Host commits and the Host itself; it never consults latest state.
    /// This retains computed data, not an actual device lease or IO acknowledgement.
    public struct DeliveryContext {
        public let application: Application
        private let retainedPlatform: Platform
        fileprivate init(application: Application, platform: Platform) throws {
            self.application = application
            retainedPlatform = try OriginalApplicationHostSession<Platform>.copy(platform)
        }
        /// With the platform copy already made (CORE_REALTIME A1).
        fileprivate init(application: Application, retainedPlatform: Platform) {
            self.application = application; self.retainedPlatform = retainedPlatform
        }
        /// A caller may mutate this independent inspection copy without changing
        /// the batch or Host. stagedCopy retains its existing value-state contract.
        public func platformSnapshot() throws -> Platform {
            try OriginalApplicationHostSession<Platform>.copy(retainedPlatform)
        }
    }

    /// These are overlapping views of the same ordered work, not two lists to
    /// execute. The consumer must retain original cross-domain operation order.
    public struct Batch {
        public enum Contents {
            case startup(Application.Started)
            case iteration(Session.Committed)
            case loaded(Session.LoadedCommit)
        }
        /// Host handoff ordinal only; never a game timer/counter or resource ID.
        public let sequence: UInt64, contents: Contents
        public let context: DeliveryContext
    }
    public enum Outcome {
        case committed(sequence: UInt64, result: Session.Loop.Result)
        case loading
    }
    private struct Pending {
        let loading: Session.PendingLoading, inputs: Inputs, platform: Platform
    }
    /// These are the actual retained owners, not a reconstructed application.
    /// A fresh child uses entry/startup; a later child uses the current cycle.
    public struct LoadingContext {
        public let entry: Session.PendingLoading, startup: OriginalWinMainStartup
        public let cycle: OriginalApplicationLoadedCycleSession?
    }
    /// A single acquisition selects the next consumer. Gameplay includes the
    /// existing paused-rendering continuation; it is not an outer return.
    public enum LoadedOutcome {
        case returned(LoadedMenu.PendingReturn)
        case matchPrelude(LoadedMenu.PendingMatchPrelude)
        case gameplayInput(GameplayInput)
        public init(menu: LoadedMenu.Outcome) {
            switch menu {
            case .returned(let child):self = .returned(child)
            case .matchPrelude(let child):self = .matchPrelude(child)
            }
        }
    }
    private enum Prepared {
        case returned(LoadedMenu.PendingReturn, Platform)
        case matchPrelude(LoadedMenu.PendingMatchPrelude, Platform)
        case gameplayInput(GameplayInput, Platform)
        var platform: Platform {
            switch self { case .returned(_,let p),.matchPrelude(_,let p),.gameplayInput(_,let p):return p }
        }
        var returned: LoadedMenu.PendingReturn? {
            if case .returned(let child,_) = self { return child };return nil
        }
        var gameplayInput: GameplayInput? {
            if case .gameplayInput(let child,_) = self { return child };return nil
        }
        var matchPrelude: LoadedMenu.PendingMatchPrelude? {
            if case .matchPrelude(let child,_) = self { return child };return nil
        }
    }
    private let lock = NSRecursiveLock()
    private var inFlight = false
    private var application = Application()
    private var platform: Platform
    private var pending: Pending?
    private var prepared: Prepared?
    private var batches: [Batch] = []
    private var sequence: UInt64 = 0

    public init(platform: Platform) throws { self.platform = try Self.copy(platform) }
    private static func copy(_ platform: Platform) throws -> Platform {
        let staged = try platform.stagedCopy()
        guard staged !== platform else { throw Boundary.sharedPlatform }
        return staged
    }
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try body()
    }
    private func attempt<T>(_ body: () throws -> T) throws -> T {
        try locked {
            guard !inFlight else { throw Boundary.reentrantAttempt }
            inFlight = true; defer { inFlight = false }
            return try body()
        }
    }
    private func requirePublication() throws {
        guard pending == nil else { throw Boundary.pendingLoading }
        guard sequence < UInt64.max else { throw Boundary.publicationExtent }
    }
    private func publish(_ contents: Batch.Contents, context: DeliveryContext) -> UInt64 {
        sequence += 1; batches.append(.init(sequence: sequence, contents: contents, context: context))
        return sequence
    }

    private var idleCommits: UInt64 = 0
    /// Iterations committed by `stepIdle` (a diagnostic for tests and probes).
    public var idleCommitCount: UInt64 { locked { idleCommits } }
    /// `step` for an idle message-loop iteration (no message, the timer not
    /// due) without the whole step: the same checks in `step`'s order, the
    /// session's `idleIteration` (the step's own loop code and requests), then
    /// the same publication, committing in place once nothing can fail. nil
    /// when the iteration is anything else; the caller then runs `step`, which
    /// raises any error itself (CORE_REALTIME A1).
    func stepIdle(prepare: (Platform, Session.State) throws -> Inputs,
        queue: (Session.Loop.Request, Platform) throws -> Session.Loop.Response,
        beforePublication: (Platform) throws -> Void = { _ in },
        expectedSequence: UInt64? = nil) throws -> Outcome? {
        try attempt {
            try requirePublication()
            guard expectedSequence == nil || expectedSequence == sequence else { throw Boundary.staleSequence }
            guard application.session != nil else { throw Application.Boundary.notStarted }
            let candidate = try Self.copy(platform)
            let inputs = try prepare(candidate, application.session!.state)
            guard application.startup != nil, inputs.initialization == nil, inputs.queue.isEmpty, inputs.windowDefault.isEmpty,
                  inputs.surface.isEmpty, inputs.lifecycle.isEmpty,
                  let idle = try application.session!.idleIteration(queue: { q in try queue(q, candidate) }) else { return nil }
            // The delivery context's platform copy, then the final hook, as `step`.
            let retained = try Self.copy(candidate)
            try beforePublication(candidate)
            application.commitIdle(idle); idleCommits += 1
            let value = Session.Committed(result: .continued, effects: idle.effects, graphics: [])
            platform = candidate
            return .committed(sequence: publish(.iteration(value), context: .init(application: application, retainedPlatform: retained)),
                              result: .continued)
        }
    }

    /// A value snapshot of the last committed Core owner. Observers during an
    /// attempt see this same committed state, never the tentative child state.
    public var snapshot: Application { locked { application } }
    public var committedSequence: UInt64 { locked { sequence } }
    public var pendingLoading: Session.PendingLoading? { locked { pending?.loading } }
    public var preparedLoadedMenu: LoadedMenu.PendingReturn? { locked { prepared?.returned } }
    public var preparedMatchPrelude: LoadedMenu.PendingMatchPrelude? { locked { prepared?.matchPrelude } }
    public var preparedGameplayInput: GameplayInput? { locked { prepared?.gameplayInput } }
    public var pendingBatchCount: Int { locked { batches.count } }
    /// Inspection returns another independent copy, never our mutable platform.
    public func platformSnapshot() throws -> Platform { try attempt { try Self.copy(platform) } }
    public func pendingPlatformSnapshot() throws -> Platform? {
        try attempt { try pending.map { try Self.copy($0.platform) } }
    }
    public func preparedPlatformSnapshot() throws -> Platform? {
        try attempt { try prepared.map { try Self.copy($0.platform) } }
    }
    /// One destructive in-process handoff. This neither executes IO nor promises
    /// physical exactly-once delivery/recovery after a backend failure or crash.
    public func takeCommitted() throws -> Batch? {
        try attempt { batches.isEmpty ? nil : batches.removeFirst() }
    }

    @discardableResult
    public func start(instance: UInt32, show: Int32, initial: OriginalStateRecord,
        prepare: (Platform) throws -> Void = { _ in },
        store: (Platform, Int, [UInt8]) throws -> Void = { _,_,_ in },
        beforeCommit: (OriginalWinMainStartup, Session, Platform) throws -> Void = { _,_,_ in },
        beforePublication: (Platform) throws -> Void = { _ in },
        failedAttempt: (Platform, Error) -> Void = { _,_ in }) throws -> UInt64 {
        try attempt {
            try requirePublication()
            var next = application, candidate = platform
            let value = try next.start(instance: instance, show: show, initial: initial,
                platform: &candidate, prepare: prepare, store: store, beforeCommit: beforeCommit, failedAttempt: failedAttempt)
            // Bootstrap reports its own failures. Context preparation and final
            // validation failures are reported here exactly once. The final hook
            // validates ownership only: no IO or mutation of the candidate.
            let context: DeliveryContext
            do {
                context = try .init(application: next, platform: candidate)
                try beforePublication(candidate)
            }
            catch { failedAttempt(candidate, error); throw error }
            application = next; platform = candidate
            return publish(.startup(value), context: context)
        }
    }

    /// Preparation may reserve queue positions/resource identities only on its
    /// supplied staged platform. It must not mutate captured/shared host state.
    /// All callbacks are observations, not effect consumers. Existing Core owns
    /// queue/timer decisions, masks and aliases. A failed attempt commits nothing.
    public func step(prepare: (Platform, Session.State) throws -> Inputs,
        observe: @escaping (Application.Observation) throws -> Void = { _ in },
        menuObserve: @escaping (OriginalFrontScreenEvent) throws -> Void = { _ in },
        graphicsObserve: @escaping (OriginalApplicationGraphics.Command) throws -> Void = { _ in },
        checkpoint: (Session.Checkpoint, OriginalStateRecord, Int32?) throws -> Void = { _,_,_ in },
        bodyProduced: (OriginalFrontScreenBody.StartupResult) throws -> Void = { _ in },
        beforeCommit: (Session.Loop, Session.State) throws -> Void = { _,_ in },
        /// false: `beforeCommit` ignores the state (it gets the step's staged
        /// state without the alias merge); see OriginalApplicationMenuSession.step.
        observesCommit: Bool = true,
        bitmap: ((Application.Stage, OriginalBitmapSurfaceLoading.Request, Platform) throws -> OriginalBitmapSurfaceLoading.Response)? = nil,
        lifecycle: ((OriginalWindowInitialization.Request, Platform) throws -> OriginalWindowInitialization.Response)? = nil,
        surface: ((OriginalWindowInitialization.Request, Platform) throws -> OriginalWindowInitialization.Response)? = nil,
        front: ((Application.Stage, OriginalFrontScreenEvent, Platform) throws -> OriginalLibSurfaceText.Response)? = nil,
        queue: ((Session.Loop.Request, Platform) throws -> Session.Loop.Response)? = nil,
        windowDefault: ((OriginalWindowInput.Request, Platform) throws -> Int32)? = nil,
        graph: ((OriginalGraphEvents.Request, Platform) throws -> OriginalGraphEvents.Response)? = nil,
        network: ((OriginalMainMenuEvent, Platform) throws -> OriginalMenuNetworkReply)? = nil,
        socket: ((OriginalNetworkNotification.Request, Platform) throws -> OriginalNetworkNotification.Response)? = nil,
        client: ((OriginalNetworkClient.Request, Platform) throws -> OriginalNetworkClient.Response)? = nil,
        networkExit: ((OriginalNetworkExit.Request, Platform) throws -> Int32)? = nil,
        beforePublication: (Platform) throws -> Void = { _ in },
        expectedSequence: UInt64? = nil) throws -> Outcome {
        try attempt {
            try requirePublication()
            guard expectedSequence == nil || expectedSequence == sequence else { throw Boundary.staleSequence }
            guard let session = application.session else { throw Application.Boundary.notStarted }
            let candidate = try Self.copy(platform)
            let inputs = try prepare(candidate, session.state)
            var next = application
            let result = try next.step(inputs: inputs.initialization, responses: inputs.responses,
                queue: inputs.queue, windowDefault: inputs.windowDefault, surface: inputs.surface,
                lifecycle: inputs.lifecycle, observe: observe, menuObserve: menuObserve,
                graphicsObserve: graphicsObserve, checkpoint: checkpoint, bodyProduced: bodyProduced,
                beforeCommit: beforeCommit, observesCommit: observesCommit,
                bitmap: bitmap.map { callback in { stage,q in try callback(stage,q,candidate) } },
                lifecycleProvider: lifecycle.map { callback in { q in try callback(q,candidate) } },
                surfaceProvider: surface.map { callback in { q in try callback(q,candidate) } },
                frontProvider: front.map { callback in { stage,q in try callback(stage,q,candidate) } },
                queueProvider: queue.map { callback in { q in try callback(q,candidate) } },
                windowDefaultProvider: windowDefault.map { callback in { q in try callback(q,candidate) } },
                graphProvider: graph.map { callback in { q in try callback(q,candidate) } },
                networkProvider: network.map { callback in { e in try callback(e,candidate) } },
                socketProvider: socket.map { callback in { q in try callback(q,candidate) } },
                clientProvider: client.map { callback in { q in try callback(q,candidate) } },
                networkExitProvider: networkExit.map { callback in { q in try callback(q,candidate) } })
            switch result {
            case .committed(let value):
                let context = try DeliveryContext(application: next, platform: candidate)
                // Final validation only: no IO or mutation of candidate in this hook.
                try beforePublication(candidate)
                application = next; platform = candidate
                return .committed(sequence: publish(.iteration(value), context: context), result: value.result)
            case .loading(let loading):
                try beforePublication(candidate)
                pending = .init(loading: loading, inputs: inputs, platform: candidate)
                return .loading
            }
        }
    }

    /// Run existing loading/menu children against the exact suspended entry.
    /// Providers may mutate only the supplied independent platform or local
    /// value owners. This stores a prepared child without publishing its IO.
    @discardableResult
    public func prepareLoadedMenu(
        prepare: (LoadingContext, Platform) throws -> OriginalApplicationLoadedMenuSession.PendingReturn,
        beforePrepared: (OriginalApplicationLoadedMenuSession.PendingReturn, Platform) throws -> Void = { _,_ in }
    ) throws -> OriginalApplicationLoadedMenuSession.PendingReturn {
        try attempt {
            let result = try prepareBoundary(prepare:{ .returned(try prepare($0,$1)) },beforePrepared:{ outcome,p in
                if case .returned(let child) = outcome { try beforePrepared(child,p) }
            })
            guard case .returned(let child) = result else { throw Boundary.unreturnedLoading }
            return child
        }
    }

    /// Start is a retained child, not an outer return. Its effects/platform stay
    /// private until launch and the enclosing loop both finish successfully.
    @discardableResult
    public func prepareLoadedMenuUntilBoundary(
        prepare: (LoadingContext, Platform) throws -> LoadedMenu.Outcome,
        beforePrepared: (LoadedMenu.Outcome, Platform) throws -> Void = { _,_ in }
    ) throws -> LoadedMenu.Outcome {
        try attempt {
            func menu(_ outcome: LoadedOutcome) throws -> LoadedMenu.Outcome {
                switch outcome {
                case .returned(let child):return .returned(child)
                case .matchPrelude(let child):return .matchPrelude(child)
                case .gameplayInput:throw Boundary.unreturnedLoading
                }
            }
            return try menu(prepareBoundary(prepare:{ .init(menu:try prepare($0,$1)) },
                beforePrepared:{ try beforePrepared(menu($0),$1) }))
        }
    }

    /// Retain one outcome selected from actual input, without requiring the
    /// caller to guess menu versus gameplay or repeat acquisition to choose an API.
    @discardableResult
    public func prepareLoadedUntilBoundary(
        prepare: (LoadingContext, Platform) throws -> LoadedOutcome,
        beforePrepared: (LoadedOutcome, Platform) throws -> Void = { _,_ in }
    ) throws -> LoadedOutcome {
        try attempt { try prepareBoundary(prepare:prepare,beforePrepared:beforePrepared) }
    }

    private func validate(_ child: LoadedMenu.PendingReturn,for loading: Session.PendingLoading) throws {
        guard child.loading.isSameAttempt(as:loading) else { throw Boundary.differentLoadingAttempt }
        guard child.exit == .returned,child.dispatcherResult != nil else { throw Boundary.unreturnedLoading }
        try child.snapshot.state.validateAliases()
    }
    private func prepareBoundary(
        prepare: (LoadingContext, Platform) throws -> LoadedOutcome,
        beforePrepared: (LoadedOutcome, Platform) throws -> Void
    ) throws -> LoadedOutcome {
        guard let pending else { throw Boundary.noPendingLoading }
        guard prepared == nil else { throw Boundary.alreadyPreparedLoading }
        guard let startup = application.startup, let session = application.session else { throw Application.Boundary.notStarted }
        let candidate = try Self.copy(pending.platform)
        let cycle = try session.loadedOwners.map { _ in try application.makeLoadedCycle(pending:pending.loading) }
        let outcome = try prepare(.init(entry:pending.loading,startup:startup,cycle:cycle),candidate)
        let next: Prepared
        switch outcome {
        case .returned(let child):
            try validate(child,for:pending.loading);next = .returned(child,candidate)
        case .matchPrelude(let child):
            guard child.loading.isSameAttempt(as:pending.loading) else { throw Boundary.differentLoadingAttempt }
            try child.snapshot.state.validateAliases();next = .matchPrelude(child,candidate)
        case .gameplayInput(let child):
            guard child.loading.isSameAttempt(as:pending.loading) else { throw Boundary.differentLoadingAttempt }
            // Reuse the existing branch, alias and installed-library contract.
            _ = try OriginalApplicationGameplaySession(pending:child)
            next = .gameplayInput(child,candidate)
        }
        try beforePrepared(outcome,candidate)
        prepared = next;return outcome
    }

    /// Resume only our retained Start. Failure keeps this child/platform; once
    /// successful, only the final outer tail remains retryable. The provider
    /// runs the existing MatchLaunchSession using the supplied actual child.
    @discardableResult
    public func resumeMatchLaunch(
        prepare: (LoadedMenu.PendingMatchPrelude, Platform) throws -> LoadedMenu.PendingReturn,
        beforePrepared: (LoadedMenu.PendingReturn, Platform) throws -> Void = { _,_ in }
    ) throws -> LoadedMenu.PendingReturn {
        try attempt {
            guard let pending else { throw Boundary.noPendingLoading }
            guard let prepared,case .matchPrelude(let child,let platform) = prepared else { throw Boundary.noPreparedMatchPrelude }
            guard child.loading.isSameAttempt(as:pending.loading) else { throw Boundary.differentLoadingAttempt }
            let candidate = try Self.copy(platform)
            let returned = try prepare(child,candidate)
            try validate(returned,for:pending.loading)
            try beforePrepared(returned,candidate)
            self.prepared = .returned(returned,candidate);return returned
        }
    }

    /// Resume only our acquired input. Body failure leaves Ready/platform intact;
    /// success retains the returned body for the separately retryable outer tail.
    @discardableResult
    public func resumeGameplay(
        prepare: (GameplayInput, Platform) throws -> LoadedMenu.PendingReturn,
        beforePrepared: (LoadedMenu.PendingReturn, Platform) throws -> Void = { _,_ in }
    ) throws -> LoadedMenu.PendingReturn {
        try attempt {
            guard let pending else { throw Boundary.noPendingLoading }
            guard let prepared,case .gameplayInput(let child,let preparedPlatform) = prepared else { throw Boundary.noPreparedGameplayInput }
            guard child.loading.isSameAttempt(as:pending.loading) else { throw Boundary.differentLoadingAttempt }
            let candidate = try Self.copy(preparedPlatform)
            let returned = try prepare(child,candidate)
            try validate(returned,for:pending.loading)
            try beforePrepared(returned,candidate)
            self.prepared = .returned(returned,candidate);return returned
        }
    }

    /// Retry only the final outer tail after a failure. No caller-supplied child
    /// can replace the prepared result. Core, host platform and the single full
    /// journal become visible together after the final observer succeeds.
    @discardableResult
    public func finishLoadedMenu(
        perform: (Session.Loop.Request, Platform) throws -> Session.Loop.Response,
        beforeCommit: (Session.Loop, Session.State, Platform) throws -> Void = { _,_,_ in },
        /// false: `beforeCommit` ignores the state (it gets the step's staged
        /// state without the alias merge); see OriginalApplicationMenuSession.step.
        observesCommit: Bool = true
    ) throws -> Outcome {
        try attempt {
            guard let pending else { throw Boundary.noPendingLoading }
            guard let prepared,case .returned(let child,let preparedPlatform) = prepared else { throw Boundary.noPreparedLoading }
            guard child.loading.isSameAttempt(as:pending.loading) else { throw Boundary.differentLoadingAttempt }
            guard sequence < UInt64.max else { throw Boundary.publicationExtent }
            var candidate = try Self.copy(preparedPlatform), next = application
            let result = try next.finishLoadedMenu(child,environment:&candidate,
                perform:{ request,platform in try perform(request,platform) },
                beforeCommit:{ loop,state,platform in try beforeCommit(loop,state,platform) },observesCommit:observesCommit)
            let context = try DeliveryContext(application: next, platform: candidate)
            application = next;self.platform = candidate;self.prepared = nil;self.pending = nil
            return .committed(sequence:publish(.loaded(result),context:context),result:result.result)
        }
    }
}
