import Foundation

/// The retained menu path through one whole message-loop iteration. The caller
/// supplies Native-produced parent state and declared platform replies. This
/// core neither consumes a host queue nor performs graphics/audio/file IO.
public struct OriginalApplicationMenuSession {
    public typealias Loop = OriginalApplicationMessageLoop
    private static let globalCount = 0xb440, outerStart = 0xb440
    private static let worldStart = 0xbb00, replayStart = 0xb8a8, counterOffset = 0xb580

    public enum Boundary: Error, Equatable {
        case dependency(String)
        case bitmapOwnership(UInt32)
    }

    /// Canonical storage includes the overlap between outer/local and World.
    /// Constructor snapshots are historical; memory owns current live records.
    public struct State {
        public fileprivate(set) var full: OriginalStateRecord
        public var memory: OriginalMenuPresentationMemory
        public var front: OriginalFrontMenuResources
        public var earlyScreen: OriginalFrontScreenPrelude
        // Declared process-attach VirtualAlloc pages, retained across all calls.
        // The accepted application loader supplies20000 known-zero bytes once.
        public var libraryHits = OriginalLibHitState()
        public var libraryTransforms = OriginalLibTransformBacking()
        public var libraryText: OriginalLibSurfaceText
        /// War setup bitmaps/Object bindings retained across438b40 calls.
        public var war = OriginalWarMenuMemory()
        public var random: OriginalCRTRandom
        public var screenBody: OriginalFrontScreenBody.StartupResult?
        public internal(set) var settings: OriginalSettingsLoading.StartupResult?
        public internal(set) var bitmapInputs: OriginalApplicationBitmapInputs?
        public internal(set) var graphics: OriginalApplicationGraphics?

        /// Adopt the already constructed menu parent exactly once. Surface
        /// tokens come from its own CreateSurface responses, never snapshots.
        public init(full: OriginalStateRecord, memory: OriginalMenuPresentationMemory,
                    front: OriginalFrontMenuResources, frontSurfaces: [UInt32:UInt32],
                    earlyScreen: OriginalFrontScreenPrelude, libraryText: OriginalLibSurfaceText,
                    random: OriginalCRTRandom, screenBody: OriginalFrontScreenBody.StartupResult?) throws {
            self.full = full; self.memory = memory; self.front = front
            self.earlyScreen = earlyScreen; self.libraryText = libraryText
            self.random = random; self.screenBody = screenBody
            try validateAliases()
            guard Set(frontSurfaces.keys) == Set(front.bitmaps.keys),
                  Set(front.bitmaps.keys).isDisjoint(with: earlyScreen.bitmaps.keys) else {
                throw OriginalStateError.invalidStorage("Menu duplicate constructed owner")
            }
            for (bitmaps, surfaces) in [(front.bitmaps,frontSurfaces),(earlyScreen.bitmaps,earlyScreen.surfaces)] {
                for (pointer, bitmap) in bitmaps {
                    guard pointer != 0, self.memory.allocations[pointer] == nil,
                          let surface = surfaces[pointer], bitmap.storage.bytes.count == 0x1f50,
                          try bitmap.storage.integer(at:0,as:UInt32.self) == (surface == 0 ? 0 : 1) else {
                        throw Boundary.bitmapOwnership(pointer)
                    }
                    var record = bitmap.storage
                    try record.write(surface,at:0)
                    self.memory.allocations[pointer] = .init(storage:record)
                }
            }
        }

        func validateAliases() throws {
            guard full.bytes.count == OriginalApplicationDispatchEntry.globalSize,
                  memory.replayPointers.bytes.count == 8,
                  try Self.slice(full,OriginalApplicationMenuSession.replayStart,8) == memory.replayPointers else {
                throw OriginalStateError.invalidStorage("Menu replay alias bytes or masks")
            }
        }
        static func slice(_ record: OriginalStateRecord,_ start: Int,_ count: Int) throws -> OriginalStateRecord {
            guard start >= 0, count >= 0, start <= record.bytes.count-count else {
                throw OriginalStateError.invalidStorage("Menu record extent")
            }
            return try .init(bytes:Array(record.bytes[start..<start+count]),defined:Array(record.defined[start..<start+count]))
        }
        mutating func replace(_ start: Int,_ record: OriginalStateRecord) throws {
            guard start >= 0, start <= full.bytes.count-record.bytes.count else {
                throw OriginalStateError.invalidStorage("Menu replacement extent")
            }
            full.overwrite(at:start,with:record)
        }
        fileprivate mutating func mergeAliases(counter: UInt32) throws {
            try replace(OriginalApplicationMenuSession.replayStart,memory.replayPointers)
            try full.write(counter,at:OriginalApplicationMenuSession.counterOffset)
        }
        /// The checks `mergeAliases` makes, in its order and with its errors,
        /// without writing (CORE_REALTIME A0).
        fileprivate func checkMergeAliases() throws {
            let start = OriginalApplicationMenuSession.replayStart
            guard start >= 0, start <= full.bytes.count-memory.replayPointers.bytes.count else {
                throw OriginalStateError.invalidStorage("Menu replacement extent")
            }
            let offset = OriginalApplicationMenuSession.counterOffset,total = full.byteCount
            guard offset >= 0, 4 <= total, offset <= total-4 else { throw OriginalStateError.outOfBounds(offset:offset,count:4) }
        }
    }

    public struct Responses {
        public let draw: Int32, presentation: Int32, sound: Int32, release: Int32, dcResult: Int32, dc: UInt32
        /// data\control.txt as 423480 reads it (text mode, CRLF → LF) and
        /// GetKeyState(VK_CAPITAL) for this iteration (CONTROL SETTINGS).
        public let controlFile: [UInt8]?, capsLock: Int32
        /// operator new(0x1f50) for a front background reloaded after the first
        /// iteration (a selector screen released it); unused offers stay free.
        public let background: OriginalInterfaceAllocation?
        public init(draw: Int32,presentation: Int32,sound: Int32,release: Int32,dcResult: Int32,dc: UInt32,
                    controlFile: [UInt8]? = nil,capsLock: Int32 = 0,background: OriginalInterfaceAllocation? = nil) {
            self.draw = draw; self.presentation = presentation; self.sound = sound
            self.release = release; self.dcResult = dcResult; self.dc = dc
            self.controlFile = controlFile; self.capsLock = capsLock; self.background = background
        }
    }

    /// Only terminal platform operations belong here. Helper entries (draw,
    /// text, soundRequest), reads and stores remain observations, avoiding a
    /// second draw/sound when a backend consumes a completed batch.
    public enum Effect: Equatable {
        case blit(OriginalBitmapBlit, result: Int32)
        case fill(OriginalSurfaceFillRequest, result: Int32)
        case surface(OriginalWindowInitialization.Request, OriginalWindowInitialization.Response)
        case soundMethod(OriginalFrontScreenEvent, ignoredResult: Int32)
        case release(OriginalFrontScreenEvent, ignoredResult: Int32)
        case present(OriginalFrontScreenEvent, result: Int32)
        case getDC(OriginalFrontScreenEvent, result: Int32, output: UInt32)
        case graphics(OriginalFrontScreenEvent,result: Int32)
        case frontAPI(OriginalFrontScreenEvent,OriginalLibSurfaceText.Response)
        case free(UInt32)
        case translate(Loop.Request)
        case sleep(UInt32)
        case bitmap(OriginalBitmapSurfaceLoading.Request,OriginalBitmapSurfaceLoading.Response)
        case allocate(UInt32,[UInt8])
        case settings(OriginalSettingsEvent)
        case lifecycle(OriginalWindowInitialization.Request,OriginalWindowInitialization.Response)
        case startupFront(OriginalFrontScreenEvent)
        case startupGraphics(OriginalFrontScreenEvent,result: Int32)
        /// 423230's complete data\control.txt (as written, LF line ends).
        case settingsFile([UInt8])
        /// A window-channel call whose result the original ignores and after which
        /// its screen makes no further platform call (the menus' MessageBoxA and
        /// ShellExecuteA): performed at commit, in effect order after the
        /// iteration's sound methods, as the original's own call order has it.
        case deferredWindow(OriginalWindowInput.Request)
    }
    public enum Checkpoint: String {
        case dispatch, world, prefix, panel, body, alternate, main, tail, worldReturn, dispatchReturn
    }
    public struct Committed {
        public let result: Loop.Result
        public let effects: [Effect]
        public let graphics: [OriginalApplicationGraphics.Command]
    }
    /// An idle message-loop iteration (no message, the timer not due) as
    /// `step` would commit it: the loop after it and its effects (CORE_REALTIME A1).
    struct IdleIteration { let loop: Loop, effects: [Effect] }
    private struct NotIdle: Error {}
    private struct ProviderFailure: Error { let error: Error }
    /// `step`'s message-loop iteration when it is idle: the same loop code and
    /// requests through `queue`, on a copy. nil when the iteration is anything
    /// else (a message, the timer due, a failed check); the caller then runs
    /// `step`, which replays the served requests and raises any error itself.
    /// Errors of `queue` itself propagate unchanged (CORE_REALTIME A1).
    func idleIteration(queue: (Loop.Request) throws -> Loop.Response) throws -> IdleIteration? {
        guard (try? state.validateAliases()) != nil,revision < UInt64.max else { return nil }
        var loop = self.loop,staged = state,effects: [Effect] = []
        do {
            let result = try loop.step(context:&staged,
                speed:{ try $0.full.integer(at:0x2c,as:Int32.self) },
                target:{ _ in throw NotIdle() },
                perform:{ request,_ in
                    switch request.kind {
                    case .peek,.time,.sleep:break
                    default:throw NotIdle()
                    }
                    let response: Loop.Response
                    do { response = try queue(request) } catch { throw ProviderFailure(error:error) }
                    if request.kind == .sleep { effects.append(.sleep(request.arguments[0])) }
                    return response
                })
            guard result == .continued else { return nil }
            try staged.checkMergeAliases()
        } catch let failure as ProviderFailure { throw failure.error }
        catch { return nil }
        return .init(loop:loop,effects:effects)
    }
    /// Install an idle iteration as `step` commits it (CORE_REALTIME A1).
    mutating func commitIdle(_ idle: IdleIteration) {
        loop = idle.loop
        // idleIteration ran the merge's checks on this same state.
        try! state.mergeAliases(counter:loop.counter)
        revision += 1
    }
    /// Child-entry evidence only. The tentative timer work in the caller has
    /// not returned. These operations must not be dispatched as committed IO.
    public struct PendingLoading {
        fileprivate let ownerID: UUID,revision: UInt64
        // Transfer identity only. Distinguishes separate attempts made from
        // copies of one committed Session; never enters original game state.
        private let attemptID = UUID()
        func isSameAttempt(as other: Self) -> Bool {
            ownerID == other.ownerID && revision == other.revision && attemptID == other.attemptID
        }
        public let state: State, target: UInt32
        public let loopContinuation: Loop.PendingDispatch
        public let stagedEffects: [Effect]
        public let stagedGraphics: [OriginalApplicationGraphics.Command]
        fileprivate init(ownerID: UUID,revision: UInt64,state: State,target: UInt32,
            loopContinuation: Loop.PendingDispatch,stagedEffects: [Effect],
            stagedGraphics: [OriginalApplicationGraphics.Command]) {
            self.ownerID = ownerID;self.revision = revision;self.state = state;self.target = target
            self.loopContinuation = loopContinuation;self.stagedEffects = stagedEffects;self.stagedGraphics = stagedGraphics
        }
        public func makeLoadingSession() throws -> OriginalApplicationLoadingSession {
            try .init(pending:self)
        }
    }
    public enum Outcome { case committed(Committed), loading(PendingLoading) }
    private struct Loading: Error { let pending: PendingLoading }

    private let ownerID = UUID()
    private var revision: UInt64 = 0
    public struct LoadedOwners {
        public let entry: OriginalApplicationPoolSession.PendingInput
        public let match: OriginalMatchPreparation,music: OriginalMusicMemory
        public let resources: OriginalMenuResourceLoading,backgrounds: [UInt32:OriginalLoadedBitmap]
    }
    public private(set) var loadedOwners: LoadedOwners?
    public private(set) var state: State
    public private(set) var loop: Loop
    public init(state: State,loop: Loop) throws {
        try state.validateAliases()
        guard try state.full.integer(at:Self.counterOffset,as:UInt32.self) == loop.counter else {
            throw OriginalStateError.invalidStorage("Menu counter alias")
        }
        self.state = state; self.loop = loop
    }

    /// Reply providers inspect a staged platform/queue view. Observers may
    /// throw, but must not execute IO. Only a returned Committed batch is ready
    /// for delivery; any error or PendingLoading leaves this session unchanged.
    public mutating func step(responses: Responses,
        queue: (Loop.Request) throws -> Loop.Response,
        windowDefault: (OriginalWindowInput.Request) throws -> Int32,
        surface: (OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response,
        observe: @escaping (OriginalFrontScreenEvent) throws -> Void = { _ in },
        graphicsObserve: @escaping (OriginalApplicationGraphics.Command) throws -> Void = { _ in },
        checkpoint: (Checkpoint,OriginalStateRecord,Int32?) throws -> Void = { _,_,_ in },
        bodyProduced: (OriginalFrontScreenBody.StartupResult) throws -> Void = { _ in },
        beforeCommit: (Loop,State) throws -> Void = { _,_ in },
        /// false: the caller's `beforeCommit` ignores the state, so the merged
        /// copy of `full` made for it is skipped (CORE_REALTIME A0); the merge's
        /// checks still run in the same place.
        observesCommit: Bool = true,
        initialization: OriginalApplicationBootstrap.MenuInputs? = nil,
        initializationBitmap: ((OriginalApplicationBootstrap.Stage,OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response)? = nil,
        frontProvider: ((OriginalApplicationBootstrap.Stage,OriginalFrontScreenEvent) throws -> OriginalLibSurfaceText.Response)? = nil,
        networkProvider: OriginalMenuNetworkProvider? = nil,
        socketProvider: ((OriginalNetworkNotification.Request) throws -> OriginalNetworkNotification.Response)? = nil,
        clientProvider: ((OriginalNetworkClient.Request) throws -> OriginalNetworkClient.Response)? = nil,
        networkExitProvider: ((OriginalNetworkExit.Request) throws -> Int32)? = nil,
        bootstrapObserve: @escaping (OriginalApplicationBootstrap.Observation) throws -> Void = { _ in },
        lifecycle: (OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response = { _ in throw Boundary.dependency("Menu lifecycle") },
        graph: (OriginalGraphEvents.Request) throws -> OriginalGraphEvents.Response = { _ in throw Boundary.dependency("Menu graph events") }) throws -> Outcome {
        try state.validateAliases()
        if initializationBitmap != nil,let input = initialization {
            guard input.frontResponses.isEmpty,input.backgroundResponses.isEmpty else {
                throw Boundary.dependency("Observed bitmap requests cannot mix prepared response arrays")
            }
        }
        guard revision < UInt64.max else { throw Boundary.dependency("Session revision extent") }
        var next = self, effects: [Effect] = []
        var loopContinuation: Loop.PendingDispatch?
        var bitmapInputs = state.bitmapInputs ?? initialization?.bitmapResources.map { OriginalApplicationBitmapInputs(resources:$0) }
        var graphics = state.graphics, graphicsCommands: [OriginalApplicationGraphics.Command] = []
        func emit(_ effect: Effect) throws {
            if graphics != nil {
                // In place: consume is all-or-nothing (CORE_REALTIME phase 4b).
                let command = try graphics!.consume(effect,inputs:bitmapInputs)
                if let command { graphicsCommands.append(command);try graphicsObserve(command) }
            }
            effects.append(effect)
        }
        let oldCounter = loop.counter
        var stage: OriginalApplicationBootstrap.Stage = .menu
        var lastBltResult: Int32 = 0, lastPresentationResult: Int32?
        var drawResult: Int32 {
            if let initialization {
                if stage == .prefix { return initialization.prefix.drawResults.first ?? responses.draw }
                if stage == .body { return initialization.body.drawResults.first ?? responses.draw }
            }
            return responses.draw
        }
        func event(_ e: OriginalFrontScreenEvent) throws {
            switch e.kind {
            case "blit":
                guard let b = e.blit else { throw Boundary.dependency("Missing bitmap Blt request") }
                if let reply = try frontProvider?(stage,e) {
                    lastBltResult = reply.result;try emit(.frontAPI(e,reply))
                } else { lastBltResult = drawResult;try emit(.blit(b,result:drawResult)) }
            case "fill":
                guard let f = e.fill else { throw Boundary.dependency("Missing fill request") }
                if let reply = try frontProvider?(stage,e) { try emit(.frontAPI(e,reply)) }
                else { try emit(.fill(f,result:stage == .prefix ? initialization?.prefix.fillResult ?? responses.draw : responses.draw)) }
            case "soundMethod": try emit(.soundMethod(e,ignoredResult:responses.sound))
            case "method":
                guard e.arguments.count >= 2 else { throw Boundary.dependency("Menu COM request") }
                if e.arguments[1] == 8 {
                    let reply = try frontProvider?(stage,e),value = reply?.result ?? responses.release
                    if var bindings = bitmapInputs {
                        _ = try bindings.response(.init("release",[e.arguments[0]]),control:.init(result:value))
                        bitmapInputs = bindings
                    }
                    if let reply { try emit(.frontAPI(e,reply)) }
                    else { try emit(.release(e,ignoredResult:value)) }
                }
                else if e.arguments[1] == 0x14 || e.arguments[1] == 0x2c {
                    if let reply = try frontProvider?(stage,e) {
                        lastPresentationResult = reply.result;try emit(.frontAPI(e,reply))
                    } else { lastPresentationResult = responses.presentation;try emit(.present(e,result:responses.presentation)) }
                }
                else { throw Boundary.dependency("Menu COM continuation") }
            case "getDC":
                // The installed body response callback already emitted its
                // terminal effect. Keep this original event as observation.
                if frontProvider == nil || stage != .body {
                    let result = stage == .body ? initialization?.body.dcResult ?? responses.dcResult : responses.dcResult
                    let output = stage == .body ? initialization?.body.dc ?? responses.dc : responses.dc
                    // The EXE's own 401290 decided on the prepared reply. With a
                    // provider the device performs that GetDC in order; any other
                    // device answer is a boundary (APPLICATION_GDI_TEXT_PLAN.md).
                    if let reply = try frontProvider?(stage,e) {
                        guard reply.result == result,result < 0 || reply.output == output else { throw Boundary.dependency("Declared GetDC reply") }
                        try emit(.frontAPI(e,reply))
                    } else { try emit(.getDC(e,result:result,output:output)) }
                }
            case "setBackgroundMode","setBackgroundColor","setTextColor","textOut","releaseDC":
                if frontProvider == nil || stage != .body {
                    // Their results are ignored by both text routines.
                    if let reply = try frontProvider?(stage,e) { try emit(.frontAPI(e,reply)) }
                    else if let input = initialization,stage == .body { try emit(.startupGraphics(e,result:input.body.methodResult)) }
                    else { try emit(.graphics(e,result:responses.draw)) }
                }
            case "free":
                guard e.arguments.count == 1 else { throw Boundary.dependency("Menu free request") }
                try emit(.free(e.arguments[0]))
            case "timer" where initialization == nil && stage == .prefix: break // the queue's timeGetTime
            case "timer","createThread","lastError":
                guard initialization != nil && stage == .prefix else { throw Boundary.dependency("Menu operation "+e.kind) }
                try emit(.startupFront(e))
            case "format","allocate","construct":
                guard stage == .prefix else { throw Boundary.dependency("Menu format") }
            case "enter","leave":if initialization != nil { try emit(.startupFront(e)) }
            case "write","writeLocal","read","clip","draw","text","stringLength","soundRequest","randomTable","panel": break
            // Main menu (APPLICATION_FRONT_MENU_ITEMS_PLAN.md F1): WSAStartup is
            // answered by the declared network input (wVersion 0); MessageBoxA,
            // Sleep and ShellExecuteA are performed when the main menu returns.
            case "startup","message","shell","sleep": break
            // With a live network provider (NETWORK_PLAY_PLAN.md N2) 402b60's
            // requests are answered as they are made and recorded here.
            case "hostname","hostLookup","htons","addressText","formatAddress","socket","asyncSelect","bind","listen","closeSocket":
                guard networkProvider != nil else { throw Boundary.dependency("Menu operation "+e.kind) }
            default: throw Boundary.dependency("Menu operation "+e.kind)
            }
            if initialization != nil && stage != .menu { try bootstrapObserve(.front(stage,e)) }
            else { try observe(e) }
        }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
            if [8,16].contains(bytes.count) {
                // API rectangle writes are retained whole in lifecycle replies.
                // Project their words into the existing scalar observation format.
                for i in stride(from:0,to:bytes.count,by:4) { try store(address+i,Array(bytes[i..<i+4])) }
                return
            }
            guard [1,2,4].contains(bytes.count) else { throw Boundary.dependency("Menu store extent") }
            let value = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
            try event(.init("write",[UInt32(address),UInt32(bytes.count),value]))
        }
        func worldStore(_ offset: Int,_ value: UInt32) throws {
            try event(.init("write",[0x458b00+UInt32(offset),4,value]))
        }
        func point(_ name: Checkpoint,_ full: OriginalStateRecord,_ result: Int32? = nil) throws {
            try checkpoint(name,full,result)
        }
        do {
            let result = try next.loop.step(context:&next.state,
                speed:{ try $0.full.integer(at:0x2c,as:Int32.self) },
                target:{ try $0.full.integer(at:0x4dac,as:UInt32.self) },
                beforeGameDispatch:{ pending,_ in loopContinuation = pending },
                perform:{ request, owned in
                    if request.kind != .gameDispatch {
                        guard request.kind != .recoverSurface else { throw Boundary.dependency("Application surface recovery") }
                        if initialization != nil { try bootstrapObserve(.loopRequest(request,owned.full)) }
                        let response = try queue(request)
                        if request.kind == .translate { try emit(.translate(request)) }
                        if request.kind == .sleep { try emit(.sleep(request.arguments[0])) }
                        guard request.kind == .dispatchMessage else { return response }
                        guard response.writes.isEmpty else {
                            throw OriginalStateError.invalidStorage("Only message retrieval owns MSG output writes")
                        }
                        guard let bytes = request.message, let mask = request.defined else {
                            throw OriginalStateError.invalidStorage("Menu delivered MSG")
                        }
                        let msg = try OriginalStateRecord(bytes:bytes,defined:mask)
                        let input = try OriginalWindowInput.Message(window:msg.integer(at:0,as:UInt32.self),message:msg.integer(at:4,as:UInt32.self),wParam:msg.integer(at:8,as:UInt32.self),lParam:msg.integer(at:12,as:UInt32.self))
                        var g = try State.slice(owned.full,0,Self.globalCount)
                        var local = try State.slice(owned.full,Self.outerStart,0x140)
                        let result: Int32
                        if input.message == 3 || input.message == 5 || input.message == 0x105 {
                            // WM_SYSKEYUP is 43b83f (Alt+Enter recreation). Its 43bdd0
                            // stack frames are fresh, undefined backing.
                            result = try OriginalWindowLifecycle.receive(input,globals:&g,memory:&owned.memory,
                                backing:{ _,count in [UInt8](repeating:0,count:count) },perform:{ q in
                                    let r = try lifecycle(q);try emit(.lifecycle(q,r));return r
                                },store:store,deliver:{ message,globals,memory in
                                    try OriginalWindowInput.receive(message,globals:&globals,local:&local,memory:&memory,
                                        request:{ q in try windowDefault(q) },store:store)
                                })
                        } else if input.message == 0x400 {
                            // 401e90's own stack frame: fresh undefined backing each call,
                            // no global writes; only DefWindowProc joins the window provider.
                            var frame = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:64),defined:[Bool](repeating:false,count:64))
                            result = try OriginalGraphEvents.receive(input,globals:g,local:&frame,request:{ q in
                                guard q.kind == .windowDefault else { return try graph(q) }
                                return .init(result:try windowDefault(.init(.windowDefault,q.arguments)))
                            })
                        } else if input.message == 0x401 {
                            // 402ec0 owns fresh local storage. Only its writes make bytes
                            // known; the saved caller frame is not its backing.
                            var frame = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:160),defined:[Bool](repeating:false,count:160))
                            result = try OriginalNetworkNotification.receive(input,globals:&g,local:&frame,request:{ q in
                                switch q.kind {
                                case .windowDefault:
                                    return .init(result:try windowDefault(.init(.windowDefault,q.arguments)))
                                case .message:
                                    let parts = q.bytes.split(separator:0,omittingEmptySubsequences:false)
                                    guard parts.count == 3,parts[2].isEmpty else { throw Boundary.dependency("Notification MessageBoxA text") }
                                    return .init(result:try windowDefault(.init(.message,q.arguments,[Array(parts[0]),Array(parts[1])])))
                                default:
                                    guard let socketProvider else { throw Boundary.dependency("Menu socket notification") }
                                    return try socketProvider(q)
                                }
                            },store:{ region,offset,bytes in
                                if region == .globals { try store(OriginalMatchPreparation.globalBase+offset,bytes) }
                            })
                        } else {
                            // Every WndProc platform call — DefWindowProcA, and the quit
                            // path's MessageBoxA, Release, free, PostMessageA and
                            // PostQuitMessage — is answered on the window channel.
                            result = try OriginalWindowInput.receive(input,globals:&g,local:&local,memory:&owned.memory,
                                request:{ q in try windowDefault(q) },store:store)
                        }
                        owned.graphics = graphics
                        try owned.replace(0,g); try owned.replace(Self.outerStart,local)
                        try owned.mergeAliases(counter:oldCounter)
                        if initialization != nil { try bootstrapObserve(.callback(result,owned.full)) }
                        return .init(result:result)
                    }
                    stage = .resources
                    try owned.mergeAliases(counter:oldCounter)
                    try point(.dispatch,owned.full)
                    let game = try OriginalApplicationDispatchEntry.advance(incomingTarget:request.arguments[0],globals:&owned.full,perform:{ q,full in
                        guard q.kind == "blt" || (initialization != nil && ["pixelFormat","debug"].contains(q.kind)) else { throw Boundary.dependency("Menu dispatcher "+q.kind) }
                        if initialization != nil { try bootstrapObserve(.dispatchSurface(full)) }
                        let response = try surface(q); try emit(.surface(q,response)); return response
                    },store:store)
                    try point(.world,owned.full)
                    var world = try State.slice(owned.full,Self.worldStart,0x7d8)
                    var g = try State.slice(owned.full,0,Self.globalCount)
                    var resources = owned.front, screen = owned.earlyScreen, library = owned.libraryText
                    var random = owned.random, memory = owned.memory, body = owned.screenBody
                    var settings = owned.settings,networkHost: OriginalStateRecord?,bodyLocal: OriginalStateRecord?
                    var frontSurfaces: [UInt32:UInt32] = [:]
                    var frontAPIIndex = 0,backgroundAPIIndex = 0
                    // Drawing callbacks run while presentation borrows memory.
                    // Track its ordered frees separately to avoid an overlapping
                    // Swift access while preserving current ownership checks.
                    var drawing = memory.allocations
                    func adopt(_ bitmaps: [UInt32:OriginalLoadedBitmap],_ surfaces: [UInt32:UInt32]) throws {
                        guard Set(bitmaps.keys) == Set(surfaces.keys) else { throw Boundary.dependency("Bootstrap surface registry") }
                        for (pointer,bitmap) in bitmaps {
                            guard pointer != 0,memory.allocations[pointer] == nil,let surface = surfaces[pointer],
                                  try bitmap.storage.integer(at:0,as:UInt32.self) == (surface == 0 ? 0 : 1) else { throw Boundary.bitmapOwnership(pointer) }
                            var record = bitmap.storage;try record.write(surface,at:0)
                            let allocation = OriginalMenuPresentationMemory.Allocation(storage:record)
                            memory.allocations[pointer] = allocation;drawing[pointer] = allocation
                        }
                    }
                    func construct(_ allocation: OriginalInterfaceAllocation,_ device: UInt32,_ path: String,
                                   _ at: OriginalApplicationBootstrap.Stage) throws -> (OriginalLoadedBitmap,UInt32) {
                        guard initializationBitmap != nil || initialization != nil else { throw Boundary.dependency("Initial bitmap inputs") }
                        var created: UInt32?
                        let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:false,
                            backing:allocation.backing,device:device,flags:0x40,context:&created,perform:{ q,cursor in
                                let response: OriginalBitmapSurfaceLoading.Response
                                if let provider = initializationBitmap {
                                    let actual = try provider(at,q)
                                    guard var bindings = bitmapInputs else { throw Boundary.dependency("Observed bitmap input provenance") }
                                    response = try bindings.observed(q,response:actual);bitmapInputs = bindings
                                } else {
                                    guard let input = initialization else { throw Boundary.dependency("Initial bitmap inputs") }
                                    let replies = at == .resources ? input.frontResponses : input.backgroundResponses
                                    let index = at == .resources ? frontAPIIndex : backgroundAPIIndex
                                    guard index < replies.count else { throw Boundary.dependency("Initial bitmap response") }
                                    let control = replies[index]
                                    if var bindings = bitmapInputs {
                                        response = try bindings.response(q,control:control);bitmapInputs = bindings
                                    } else { response = control }
                                    if at == .resources { frontAPIIndex += 1 } else { backgroundAPIIndex += 1 }
                                }
                                try emit(.bitmap(q,response))
                                try bootstrapObserve(.bitmap(at,q,response))
                                if q.kind == "createSurface" && response.result == 0 { cursor = response.output }
                                return response
                            })
                        let present = try bitmap.storage.integer(at:0,as:UInt32.self) != 0
                        guard !present || created != nil else { throw Boundary.bitmapOwnership(allocation.address) }
                        return (bitmap,present ? created! : 0)
                    }
                    func combined(_ globals: OriginalStateRecord,_ w: OriginalStateRecord? = nil) throws -> OriginalStateRecord {
                        var snapshot = owned
                        try snapshot.replace(0,globals)
                        if let w { try snapshot.replace(Self.worldStart,w) }
                        return snapshot.full
                    }
                    let width = try g.integer(at:0x78c,as:Int32.self), height = try g.integer(at:0x790,as:Int32.self)
                    func liveBitmap(_ pointer: UInt32) throws -> OriginalMenuPresentationMemory.Allocation {
                        guard let bitmap = drawing[pointer], bitmap.live else { throw Boundary.bitmapOwnership(pointer) }
                        return bitmap
                    }
                    func draw(_ args: [UInt32]) throws {
                        guard args.count == 7 else { throw Boundary.dependency("Menu bitmap arguments") }
                        let bitmap = try liveBitmap(args[0]), surface = try bitmap.storage.integer(at:0,as:UInt32.self)
                        var canonical = bitmap.storage; try canonical.write(UInt32(surface == 0 ? 0 : 1),at:0)
                        let input = OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:surface,targetSurface:args[6],viewportWidth:width,viewportHeight:height)
                        _ = try OriginalBitmapDrawing.draw(input,bitmap:canonical,observeRead:{ r in var e = OriginalFrontScreenEvent("read");e.read = r;try event(e) },observeClip:{ c in var e = OriginalFrontScreenEvent("clip");e.clip = c;try event(e) },perform:{ b in var e = OriginalFrontScreenEvent("blit");e.blit = b;try event(e);return lastBltResult })
                    }
                    func present(_ presentation: OriginalMenuPresentationEntry,_ w: inout OriginalStateRecord,_ state: inout OriginalStateRecord) throws {
                        if presentation == .tail { try point(.tail,combined(state,w)) }
                        let input = OriginalMenuPresentationInput(targetSurface:game.target,methodResult:responses.presentation,queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0,postResult:0)
                        try OriginalMenuPresentation.applyWithLibrary(presentation,input:input,world:&w,globals:&state,memory:&memory,libraryText:&library,store:store,worldStored:worldStore,observe:{ e in
                            if e.kind == .bitmap { try event(.init("draw",e.arguments));try draw(e.arguments) }
                            else {
                                guard e.kind == .method || e.kind == .free else { throw Boundary.dependency("Menu presentation "+e.kind.rawValue) }
                                try event(.init(e.kind.rawValue,e.arguments,e.strings))
                                if e.kind == .free { drawing[e.arguments[0]]?.live = false }
                            }
                        })
                    }
                    var continuation = try OriginalFrontMenuLoop.run(world:&world,globals:&g,initialize:{ w,state in
                        let result = try resources.load(world:w,globals:&state,allocate:{ index in
                            guard let input = initialization else { throw Boundary.dependency("Menu resource allocation") }
                            guard index < input.frontAllocations.count,settings == nil else { throw Boundary.dependency("Initial front allocation lifetime") }
                            let allocation = input.frontAllocations[index]
                            try bootstrapObserve(.allocateFront(index,allocation))
                            try emit(.allocate(allocation.address,allocation.backing));return allocation
                        },source:{ _,_ in throw Boundary.dependency("Menu resource source") },deviceResult:{ _ in throw Boundary.dependency("Menu resource device") },constructBitmap:{ _,allocation,device,path in
                            let (bitmap,surface) = try construct(allocation,device,path,.resources)
                            frontSurfaces[allocation.address] = surface;return bitmap
                        },observe:{ e in
                            if initialization != nil { try bootstrapObserve(.resource(e)) }
                            else {
                                guard e.kind == .write else { throw Boundary.dependency("Menu resource "+e.kind.rawValue) }
                                try event(.init("write",[e.arguments[1],e.arguments[2],e.arguments[3]]))
                            }
                        })
                        if let input = initialization,result.continuation != .ready {
                            try bootstrapObserve(.resources(result,combined(state),resources,frontSurfaces))
                            try adopt(resources.bitmaps,frontSurfaces)
                            guard result.continuation == .settings else { return result }
                            stage = .settings
                            let file = input.settings
                            let output = try OriginalSettingsLoading.loadOwnStartup(globals:&state,translatedBytes:file.bytes,
                                file:file.file,scratchAddress:file.scratchAddress,target:game.target,closeResult:file.closeResult,observe:{ e,g,s in
                                    if e.kind == .open || e.kind == .close { try emit(.settings(e)) }
                                    try bootstrapObserve(.settings(e,g,s))
                                })
                            settings = output
                            try bootstrapObserve(.settingsReturn(output,combined(state)))
                            guard output.continuation == .ready else { throw Boundary.dependency("Initial settings NULL FILE") }
                            return .init(continuation:.ready,nullBitmapSlot:nil)
                        }
                        return result
                    },prefix:{ state in
                        stage = .prefix
                        try point(.prefix,combined(state))
                        // Validate the live registry before the retained helper
                        // reads its historical constructor view of this bitmap.
                        let pointer = try state.integer(at:0x41ac,as:UInt32.self)
                        if pointer != 0 {
                            let current = try liveBitmap(pointer)
                            guard let historical = screen.bitmaps[pointer], let surface = screen.surfaces[pointer] else { throw Boundary.bitmapOwnership(pointer) }
                            var record = historical.storage; try record.write(surface,at:0)
                            guard record == current.storage else { throw Boundary.bitmapOwnership(pointer) }
                        }
                        // The zero fields below have no reply semantics: any
                        // timer/worker/allocation operation throws before use.
                        let input: OriginalFrontScreenInput
                        if let first = initialization?.prefix {
                            input = .init(drawTarget:game.target,milliseconds:first.milliseconds,threadHandle:first.threadHandle,
                                threadID:first.threadID,lastError:first.lastError,fillResult:first.fillResult,drawResults:first.drawResults)
                        } else {
                            // 4237e0 reads timeGetTime only to choose a reloaded MENU_BACK.
                            let reload = try state.integer(at:0x41ac,as:UInt32.self) == 0
                            let milliseconds = reload ? UInt32(bitPattern:try queue(.init(.time)).result) : 0
                            input = .init(drawTarget:game.target,milliseconds:milliseconds,threadHandle:0,threadID:0,lastError:0,fillResult:responses.draw,drawResults:[responses.draw])
                        }
                        let oldKeys = Set(screen.bitmaps.keys)
                        let end = try screen.advance(globals:&state,input:input,fillBacking:[UInt8](repeating:0,count:100),allocate:{
                            guard let allocation = initialization?.backgroundAllocation ?? responses.background else { throw Boundary.dependency("Menu background allocation") }
                            try bootstrapObserve(.allocateBackground(allocation))
                            guard allocation.address == 0 || memory.allocations[allocation.address] == nil else { throw Boundary.bitmapOwnership(allocation.address) }
                            try emit(.allocate(allocation.address,allocation.backing));return allocation
                        },source:{ _ in throw Boundary.dependency("Menu background source") },constructBitmap:{ allocation,device,path in
                            try construct(allocation,device,path,.prefix)
                        },observe:event)
                        // First load or a later reload: the new background joins the owned registry.
                        let fresh = screen.bitmaps.filter { !oldKeys.contains($0.key) }
                        try adopt(fresh,screen.surfaces.filter { fresh[$0.key] != nil })
                        if initialization != nil { try bootstrapObserve(.prefixReturn(end,combined(state),screen)) }
                        return end
                    },update:{ state in
                        stage = .body
                        try point(.panel,combined(state))
                        let result = try OriginalMenuPanelUpdate.run(globals:&state,content:{ _ in throw Boundary.dependency("Menu panel content") },bitmap:{ _ in throw Boundary.dependency("Menu panel bitmap") },write:{ _,_ in throw Boundary.dependency("Menu panel write") },observe:{ e,_ in try event(.init(e.kind,e.arguments)) })
                        if initialization != nil { try bootstrapObserve(.panelReturn(combined(state))) }
                        return result
                    },body:{ state in
                        try point(.body,combined(state))
                        let output = try OriginalFrontScreenBody.advanceOwnStartup(globals:&state,target:game.target,libraryText:&library,input:initialization?.body ?? .init(dcResult:responses.dcResult,dc:responses.dc,methodResult:responses.draw,drawResults:[responses.draw],shellResult:0),draw:draw,
                            textPerform:frontProvider.map { provider in { q in
                                try provider(stage,.init(q.kind.rawValue,q.arguments,q.strings))
                            } },textDidRespond:{ q,r in
                                try emit(.frontAPI(.init(q.kind.rawValue,q.arguments,q.strings),r))
                            },observe:event)
                        try bodyProduced(output); body = output; bodyLocal = output.local
                        if initialization != nil { try bootstrapObserve(.bodyReturn(output,combined(state),library)) }
                        return output.continuation
                    },alternate:{ state,selector in
                        stage = .menu
                        try point(.alternate,combined(state))
                        if (6...8).contains(selector) {
                            // CONTROL SETTINGS (6) and RECORDING INFO (7, 8;
                            // APPLICATION_FRONT_MENU_ITEMS.md F2, F3): GetKeyState, the 423480
                            // reload and the 423230 writer use this iteration's inputs; the
                            // written file is an effect; Sleep and ShellExecuteA run when the
                            // screen returns.
                            var calls: [OriginalFrontScreenEvent] = []
                            let screen = OriginalFrontControlSettings.Input(target:game.target,dcResult:responses.dcResult,dc:responses.dc)
                            func reload(_ s: inout OriginalStateRecord) throws {
                                guard let bytes = responses.controlFile else { throw Boundary.dependency("Control settings file") }
                                var scratch = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x1f4),defined:[Bool](repeating:false,count:0x1f4))
                                // Declared tokens: the FILE and the helper's own scratch are never dereferenced.
                                guard try OriginalSettingsLoading.loadAndContinueStartup(globals:&s,scratch:&scratch,translatedBytes:bytes,
                                    file:1,scratchAddress:0x10000000,flagClearValue:nil) == .ready else { throw Boundary.dependency("Control settings reload") }
                            }
                            func write(_ s: inout OriginalStateRecord) throws -> OriginalSettingsWriting.Result {
                                var output = try OriginalBufferedTextOutput(backing:[UInt8](repeating:0,count:4096)),written: [UInt8] = []
                                let result = try OriginalSettingsWriting.run(globals:&s,output:&output,available:true,
                                    write:{ bytes in written += bytes;return Int32(bytes.count) },close:{ 0 })
                                try emit(.settingsFile(written));return result
                            }
                            func screenEvent(_ e: OriginalFrontScreenEvent) throws {
                                switch e.kind {
                                case "keyState","format","call","return","fontPass","stringWrite":if initialization == nil { try observe(e) }
                                case "sleep","shell":calls.append(e);if initialization == nil { try observe(e) }
                                default:try event(e)
                                }
                            }
                            if selector == 6 {
                                try OriginalFrontControlSettings.advance(globals:&state,memory:&memory,input:screen,draw:draw,
                                    keyState:{ _ in responses.capsLock },reload:reload,write:write,observe:screenEvent)
                            } else {
                                // The font's Blt answers are the ones its blit events just emitted.
                                try OriginalFrontRecordingInfo.advance(selector:selector,globals:&state,memory:&memory,input:screen,draw:draw,
                                    blit:{ _ in lastBltResult },keyState:{ _ in responses.capsLock },reload:reload,write:write,observe:screenEvent)
                            }
                            for c in calls {
                                if c.kind == "sleep" { _ = try queue(.init(.sleep,c.arguments));try emit(.sleep(c.arguments[0])) }
                                else { try emit(.deferredWindow(.init(.shell,c.arguments,c.strings))) }
                            }
                            return .presentation
                        }
                        return try OriginalFrontScreenAlternate.advance(globals:&state,input:.init(selector:selector,drawTarget:game.target,timers:[],methodResult:0,drawResults:[responses.draw],fillResult:0,threadHandle:0,threadID:0,lastError:0),draw:draw,fill:{ _ in throw Boundary.dependency("Alternate fill") },writeSettings:{ _ in throw Boundary.dependency("Alternate settings write") },observe:event)
                    },completion:{ entry,w,state in
                        let presentation: OriginalMenuPresentationEntry
                        if entry == .main {
                            try point(.main,combined(state,w))
                            // Without a network provider WSAStartup answers wVersion 0
                            // (the declared no-network stand-in); with one, 402b60's
                            // requests are answered live (NETWORK_PLAY_PLAN.md N2).
                            let input = OriginalMainMenuInput(targetSurface:game.target,panelWord:nil,network:.init(startupResult:0,version:0,hostnameResult:0,hostname:[],hostEntryAddress:0,addresses:[],socketResult:0,asyncResult:0,bindResult:0,listenResult:0))
                            var calls: [OriginalMainMenuEvent] = []
                            let end = try OriginalMainMenu.run(world:&w,globals:&state,crt:&random,input:input,network:networkProvider,store:store,worldStored:worldStore,observe:{ e in
                                if e.kind == .bitmap { try event(.init("draw",e.arguments));try draw(e.arguments) }
                                else {
                                    try event(.init(e.kind.rawValue,e.arguments,e.strings))
                                    if [.message,.sleep,.shell].contains(e.kind) { calls.append(e) }
                                }
                            })
                            // Their results are unused and no platform call follows them
                            // inside the main menu: Sleep is served on the queue now, and
                            // MessageBoxA/ShellExecuteA become commit effects after the
                            // iteration's sounds (`deferredWindow`), in the original order.
                            for c in calls {
                                switch c.kind {
                                case .message: try emit(.deferredWindow(.init(.message,c.arguments,c.strings)))
                                case .shell: try emit(.deferredWindow(.init(.shell,c.arguments,c.strings)))
                                default:
                                    guard c.arguments.count == 1 else { throw Boundary.dependency("Menu Sleep") }
                                    _ = try queue(.init(.sleep,c.arguments)); try emit(.sleep(c.arguments[0]))
                                }
                            }
                            // 402b60's failures return before the frame is presented.
                            if end == .returnWithoutPresentation { return }
                            guard end == .present else { throw Boundary.dependency("Main menu return") }
                            presentation = .tail
                        } else { presentation = entry == .worldOne ? .worldOne : .tail }
                        try present(presentation,&w,&state)
                    })
                    if continuation == .otherSelector {
                        // The network menu (APPLICATION_FRONT_MENU_ITEMS_PLAN.md F1b): the
                        // actual 427ca7 continuation, its body, then the real tail or
                        // epilogue. Supplied live providers use iteration receipts;
                        // absent providers keep the declared no-network stand-in.
                        let selector = try g.integer(at:0x44d064-OriginalMatchPreparation.globalBase,as:Int32.self)
                        guard (1...4).contains(selector) else { throw Boundary.dependency("Menu selector \(selector)") }
                        stage = .menu
                        // The 51 hostname bytes at World+7d8 (NETWORK_MENU.md) follow the World
                        // prefix in the canonical record (4592d8): read and write them there.
                        var host = try State.slice(owned.full,Self.worldStart+0x7d8,51)
                        // Caller-local bytes from callerSP+14; only this call's body writes are known.
                        var local = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x400),defined:[Bool](repeating:false,count:0x400))
                        if let bodyLocal { for i in 0x14..<bodyLocal.bytes.count where bodyLocal.defined[i] { try local.write(bodyLocal.bytes[i],at:i-0x14) } }
                        enum Call { case window(OriginalWindowInput.Request),sleep([UInt32]) }
                        var calls: [Call] = []
                        func box(_ bytes: [UInt8]) throws {
                            let parts = bytes.split(separator:0,omittingEmptySubsequences:false)
                            guard parts.count == 3,parts[2].isEmpty else { throw Boundary.dependency("Network MessageBoxA text") }
                            calls.append(.window(.init(.message,[0,0],[Array(parts[0]),Array(parts[1])])))
                        }
                        func refused(_ kind: String) throws -> Int32 {
                            switch kind {
                            case "socket","closeSocket","cleanup","sendTo","connect","send","receive":return -1
                            default:throw Boundary.dependency("Winsock "+kind)
                            }
                        }
                        let end = try OriginalNetworkMenu.run(world:&world,hostname:&host,globals:&g,local:&local,libraryText:&library,memory:&memory,
                            input:.init(selector:selector,worldAddress:0x458b00,drawTarget:game.target,dcResult:responses.dcResult,dc:responses.dc),
                            background:{ _,_ in throw Boundary.dependency("Network menu background") },
                            draw:{ args,_ in try draw(args) },fill:{ a in
                                guard a.count == 6 else { throw Boundary.dependency("Network menu fill") }
                                var e = OriginalFrontScreenEvent("fill")
                                e.fill = try OriginalSurfaceFilling.request(target:a[0],x:Int32(bitPattern:a[1]),y:Int32(bitPattern:a[2]),width:Int32(bitPattern:a[3]),height:Int32(bitPattern:a[4]),color:a[5],backing:[UInt8](repeating:0,count:100))
                                try event(e)
                            },timer:{ UInt32(bitPattern:try queue(.init(.time)).result) },keyState:{ _ in responses.capsLock },
                            client:{ s,l,w in try OriginalNetworkClient.attempt(globals:&s,local:&l,world:w,request:{ r in
                                if let clientProvider {
                                    if r.kind == .message {
                                        let parts = r.bytes.split(separator:0,omittingEmptySubsequences:false)
                                        guard parts.count == 3,parts[2].isEmpty else { throw Boundary.dependency("Client MessageBoxA text") }
                                        return .init(result:try windowDefault(.init(.message,r.arguments,[Array(parts[0]),Array(parts[1])])))
                                    }
                                    return try clientProvider(r)
                                }
                                switch r.kind {
                                case .message:try box(r.bytes);return .init(result:1)
                                case .sleep:calls.append(.sleep(r.arguments));return .init()
                                default:return .init(result:try refused(r.kind.rawValue))
                                }
                            }) },exit:{ s in
                                var frame = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:256),defined:[Bool](repeating:false,count:256))
                                _ = try OriginalNetworkExit.run(globals:&s,local:&frame,request:{ r in
                                    if let networkExitProvider {
                                        if r.kind == .message {
                                            let parts = r.bytes.split(separator:0,omittingEmptySubsequences:false)
                                            guard parts.count == 3,parts[2].isEmpty else { throw Boundary.dependency("Exit MessageBoxA text") }
                                            return try windowDefault(.init(.message,r.arguments,[Array(parts[0]),Array(parts[1])]))
                                        }
                                        return try networkExitProvider(r)
                                    }
                                    if r.kind == .message { try box(r.bytes);return 1 }
                                    return try refused(r.kind.rawValue)
                                })
                            },observe:{ e in
                                switch e.kind {
                                case "format","keyState","timer","fillRequest":try observe(e)
                                case "sleep":calls.append(.sleep(e.arguments));try observe(e)
                                case "shell":calls.append(.window(.init(.shell,e.arguments,e.strings)));try observe(e)
                                default:try event(e)
                                }
                            })
                        networkHost = host
                        for c in calls {
                            switch c {
                            case .sleep(let arguments):
                                guard arguments.count == 1 else { throw Boundary.dependency("Network menu Sleep") }
                                _ = try queue(.init(.sleep,arguments));try emit(.sleep(arguments[0]))
                            case .window(let q):try emit(.deferredWindow(q))
                            }
                        }
                        try present(end == .presentation ? .tail : .epilogue,&world,&g)
                        continuation = .returned
                    }
                    let resultRecord = try combined(g,world)
                    owned.full = resultRecord; owned.front = resources; owned.earlyScreen = screen
                    owned.libraryText = library; owned.random = random; owned.memory = memory; owned.screenBody = body; owned.settings = settings;owned.bitmapInputs = bitmapInputs;owned.graphics = graphics
                    if let networkHost { try owned.replace(Self.worldStart+0x7d8,networkHost) }
                    try owned.replace(Self.replayStart,memory.replayPointers)
                    if continuation == .loading {
                        guard let loopContinuation else { throw Boundary.dependency("Missing loading loop continuation") }
                        throw Loading(pending:.init(ownerID:ownerID,revision:revision,state:owned,target:game.target,loopContinuation:loopContinuation,stagedEffects:effects,stagedGraphics:graphicsCommands))
                    }
                    guard continuation == .returned else { throw Boundary.dependency("Menu continuation "+continuation.rawValue) }
                    try point(.worldReturn,owned.full,initialization == nil ? nil : lastPresentationResult ?? responses.presentation)
                    let result = try OriginalApplicationDispatchEntry.finishWorldCall(globals:owned.full)
                    try point(.dispatchReturn,owned.full,result)
                    return .init(result:result)
                },counterWritten:{ try event(.init("write",[0x458580,4,$0])) },beforeCommit:{ timer,staged,_ in
                    if observesCommit {
                        var coherent = staged; try coherent.mergeAliases(counter:timer.counter)
                        try beforeCommit(timer,coherent)
                    } else { try staged.checkMergeAliases(); try beforeCommit(timer,staged) }
                })
            try next.state.mergeAliases(counter:next.loop.counter)
            next.revision += 1;self = next
            return .committed(.init(result:result,effects:effects,graphics:graphicsCommands))
        } catch let loading as Loading {
            return .loading(loading.pending)
        }
    }
}


extension OriginalApplicationMenuSession {
    public struct LoadedCommit {
        public let result: Loop.Result
        public let menu: OriginalApplicationLoadedMenuSession.PendingReturn
        public let operations: [OriginalApplicationLoadedMenuSession.Operation]
        public let graphics: [OriginalApplicationGraphics.Command]
    }
    /// Complete the exact suspended iteration once. A different session or any
    /// intervening committed iteration invalidates this child before platform
    /// work. The immutable parent remains available for diagnosis and retry.
    @discardableResult
    public mutating func finishLoadedMenu<Environment>(_ pending: OriginalApplicationLoadedMenuSession.PendingReturn,
        environment: inout Environment,
        perform: (Loop.Request,inout Environment) throws -> Loop.Response,
        beforeCommit: (Loop,State,inout Environment) throws -> Void = { _,_,_ in },
        /// false: the caller's `beforeCommit` ignores the state, so the merged
        /// copy of `full` made for it is skipped (CORE_REALTIME A0); the merge's
        /// checks still run in the same place.
        observesCommit: Bool = true) throws -> LoadedCommit {
        let origin = pending.loading
        guard ownerID == origin.ownerID,revision == origin.revision,revision < UInt64.max else {
            throw Boundary.dependency("Stale or foreign loaded continuation")
        }
        guard pending.exit == .returned,let result = pending.dispatcherResult else { throw Boundary.dependency("Unreturned loaded menu") }
        try pending.snapshot.state.validateAliases()
        var candidate = environment,staged = pending.snapshot.state,operations = pending.snapshot.operations
        let complete = try origin.loopContinuation.resume(dispatchResult:result,context:&staged,perform:{ request,_ in
            guard request.kind == .time || request.kind == .sleep else { throw Boundary.dependency("Loaded outer surface recovery") }
            let response = try perform(request,&candidate)
            operations.append(.loop(request,response));return response
        },beforeCommit:{ timer,context,_ in
            if observesCommit {
                var coherent = context;try coherent.mergeAliases(counter:timer.counter)
                try beforeCommit(timer,coherent,&candidate)
            } else { try context.checkMergeAliases(); try beforeCommit(timer,context,&candidate) }
        })
        try staged.mergeAliases(counter:complete.loop.counter)
        state = staged;loop = complete.loop;revision += 1;environment = candidate
        loadedOwners = .init(entry:pending.entry.entry,match:pending.snapshot.match,music:pending.snapshot.music,
                             resources:pending.snapshot.resources,backgrounds:pending.snapshot.backgrounds)
        return .init(result:complete.result,menu:pending,operations:operations,graphics:pending.graphics)
    }
}

extension OriginalApplicationMenuSession {
    /// Continue the fresh World2 suspension using the owners committed by this
    /// Session. The first catalog/pool parent supplies identities only.
    public func makeLoadedCycle(pending: PendingLoading) throws -> OriginalApplicationLoadedCycleSession {
        guard ownerID == pending.ownerID,revision == pending.revision,let owners = loadedOwners else {
            throw Boundary.dependency("Missing, stale or foreign loaded cycle")
        }
        return try .init(pending:pending,owners:owners)
    }
}
