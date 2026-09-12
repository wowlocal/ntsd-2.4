/// Production owner from declared WinMain entry to the live menu session.
/// Earlier PE/CRT initialization and host input/device/file adapters remain
/// explicit dependencies. No research corpus belongs to this runtime owner.
public struct OriginalApplicationBootstrap {
    public typealias Session = OriginalApplicationMenuSession
    public enum Boundary: Error, Equatable {
        case alreadyStarted
        case notStarted
        case sharedStartupAttempt
    }
    public struct Started {
        public let operations: [OriginalApplicationStartupOperation]
    }
    public enum Stage: String { case resources, settings, prefix, body, menu }
    public struct Settings {
        public let bytes: [UInt8],file: UInt32,scratchAddress: UInt32,closeResult: Int32
        public init(bytes: [UInt8],file: UInt32,scratchAddress: UInt32,closeResult: Int32) {
            self.bytes = bytes;self.file = file;self.scratchAddress = scratchAddress;self.closeResult = closeResult
        }
    }
    /// Immutable declared responses for a fresh menu resource lifetime. Array
    /// positions belong to the attempted Core call, never captured host cursors.
    /// A host adapter must prepare a transactional view before providing these
    /// inputs; no callback in this record can mutate an allocator or queue.
    public struct MenuInputs {
        public let settings: Settings
        public let prefix: OriginalFrontScreenInput
        public let body: OriginalFrontScreenBodyInput
        public let frontAllocations: [OriginalInterfaceAllocation]
        public let backgroundAllocation: OriginalInterfaceAllocation
        public let frontResponses: [OriginalBitmapSurfaceLoading.Response]
        public let backgroundResponses: [OriginalBitmapSurfaceLoading.Response]
        public init(settings: Settings,prefix: OriginalFrontScreenInput,body: OriginalFrontScreenBodyInput,
            frontAllocations: [OriginalInterfaceAllocation],backgroundAllocation: OriginalInterfaceAllocation,
            frontResponses: [OriginalBitmapSurfaceLoading.Response],backgroundResponses: [OriginalBitmapSurfaceLoading.Response]) {
            self.settings = settings;self.prefix = prefix;self.body = body
            self.frontAllocations = frontAllocations;self.backgroundAllocation = backgroundAllocation
            self.frontResponses = frontResponses;self.backgroundResponses = backgroundResponses
        }
    }
    public enum Observation {
        case queueResponse(Session.Loop.Request,Session.Loop.Response)
        case windowResponse(OriginalWindowInput.Request,Int32)
        case surfaceResponse(OriginalWindowInitialization.Request,OriginalWindowInitialization.Response)
        case lifecycleResponse(OriginalWindowInitialization.Request,OriginalWindowInitialization.Response)
        case bitmap(Stage,OriginalBitmapSurfaceLoading.Request,OriginalBitmapSurfaceLoading.Response)
        case allocateFront(Int,OriginalInterfaceAllocation)
        case allocateBackground(OriginalInterfaceAllocation)
        case loopRequest(Session.Loop.Request,OriginalStateRecord)
        case callback(Int32,OriginalStateRecord)
        case dispatchSurface(OriginalStateRecord)
        case resource(OriginalFrontMenuEvent)
        case resources(OriginalFrontMenuResourceResult,OriginalStateRecord,OriginalFrontMenuResources,[UInt32:UInt32])
        case settings(OriginalSettingsEvent,OriginalStateRecord,OriginalStateRecord)
        case settingsReturn(OriginalSettingsLoading.StartupResult,OriginalStateRecord)
        case front(Stage,OriginalFrontScreenEvent)
        case prefixReturn(OriginalFrontScreenPrelude.Continuation,OriginalStateRecord,OriginalFrontScreenPrelude)
        case panelReturn(OriginalStateRecord)
        case bodyReturn(OriginalFrontScreenBody.StartupResult,OriginalStateRecord,OriginalLibSurfaceText)
    }
    public private(set) var startup: OriginalWinMainStartup?
    public private(set) var session: Session?
    public init() {}

    /// Every message/timer iteration commits independently. Failed first-menu
    /// work leaves startup and all previously delivered callbacks intact.
    public mutating func step(inputs: MenuInputs,responses: Session.Responses,
        queue: [Session.Loop.Response],windowDefault: [Int32],
        surface: [OriginalWindowInitialization.Response],lifecycle: [OriginalWindowInitialization.Response],
        observe: @escaping (Observation) throws -> Void = { _ in },
        menuObserve: @escaping (OriginalFrontScreenEvent) throws -> Void = { _ in },
        checkpoint: (Session.Checkpoint,OriginalStateRecord,Int32?) throws -> Void = { _,_,_ in },
        beforeCommit: (Session.Loop,Session.State) throws -> Void = { _,_ in }) throws -> Session.Outcome {
        guard var next = session,startup != nil else { throw Boundary.notStarted }
        var qi = 0,wi = 0,si = 0,li = 0
        func take<T>(_ values: [T],_ index: inout Int,_ name: String) throws -> T {
            guard index < values.count else { throw Session.Boundary.dependency("Bootstrap "+name+" response") }
            defer { index += 1 };return values[index]
        }
        let result = try next.step(responses:responses,queue:{ q in
            let r = try take(queue,&qi,"queue");try observe(.queueResponse(q,r));return r
        },windowDefault:{ q in
            let r = try take(windowDefault,&wi,"window");try observe(.windowResponse(q,r));return r
        },surface:{ q in
            let r = try take(surface,&si,"surface");try observe(.surfaceResponse(q,r));return r
        },observe:menuObserve,checkpoint:checkpoint,beforeCommit:{ loop,state in
            guard qi == queue.count,wi == windowDefault.count,si == surface.count,li == lifecycle.count else {
                throw Session.Boundary.dependency("Unused bootstrap iteration responses")
            }
            try beforeCommit(loop,state)
        },initialization:inputs,bootstrapObserve:observe,lifecycle:{ q in
            let r = try take(lifecycle,&li,"lifecycle");try observe(.lifecycleResponse(q,r));return r
        })
        if case .committed = result { session = next }
        return result
    }

    /// A failed fresh startup commits neither adapter cursor, resource owners,
    /// globals nor operations. A later menu failure cannot undo this commit.
    public mutating func start<P: OriginalApplicationStartupPlatform>(
        instance: UInt32,show: Int32,initial: OriginalStateRecord,platform: inout P,
        store: (P,Int,[UInt8]) throws -> Void = { _,_,_ in },
        beforeCommit: (OriginalWinMainStartup,Session,P) throws -> Void = { _,_,_ in },
        failedAttempt: (P,Error) -> Void = { _,_ in }) throws -> Started {
        guard startup == nil,session == nil else { throw Boundary.alreadyStarted }
        guard initial.bytes.count == OriginalApplicationDispatchEntry.globalSize else {
            throw OriginalStateError.invalidStorage("Bootstrap full initial extent")
        }
        let staged = try platform.stagedCopy()
        guard staged !== platform else { throw Boundary.sharedStartupAttempt }
        let bridge = OriginalApplicationStartupBridge(staged)
        do {
            var owner = OriginalWinMainStartup()
            var globals = try Session.State.slice(initial,0,OriginalMatchPreparation.globalSize)
            try owner.run(instance:instance,show:show,globals:&globals,platform:bridge,
                          store:{ try store(staged,$0,$1) })
            var bytes = initial.bytes,mask = initial.defined
            bytes.replaceSubrange(0..<globals.bytes.count,with:globals.bytes)
            mask.replaceSubrange(0..<globals.bytes.count,with:globals.defined)
            let full = try OriginalStateRecord(bytes:bytes,defined:mask)
            let memory = OriginalMenuPresentationMemory(replayPointers:try Session.State.slice(full,0xb8a8,8))
            let state = try Session.State(full:full,memory:memory,front:.init(),frontSurfaces:[:],
                earlyScreen:.init(),libraryText:.init(),random:owner.random,screenBody:nil)
            let loop = try Session.Loop(baseline:owner.random.state,counter:full.integer(at:0xb580,as:UInt32.self))
            let menu = try Session(state:state,loop:loop)
            try beforeCommit(owner,menu,staged)
            startup = owner;session = menu;platform = staged
            return .init(operations:bridge.operations)
        } catch {
            failedAttempt(staged,error)
            throw error
        }
    }
}
