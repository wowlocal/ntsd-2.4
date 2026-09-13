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
        public var libraryText: OriginalLibSurfaceText
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
            var bytes = full.bytes, mask = full.defined
            bytes.replaceSubrange(start..<start+record.bytes.count,with:record.bytes)
            mask.replaceSubrange(start..<start+record.bytes.count,with:record.defined)
            full = try .init(bytes:bytes,defined:mask)
        }
        fileprivate mutating func mergeAliases(counter: UInt32) throws {
            try replace(OriginalApplicationMenuSession.replayStart,memory.replayPointers)
            try full.write(counter,at:OriginalApplicationMenuSession.counterOffset)
        }
    }

    public struct Responses {
        public let draw: Int32, presentation: Int32, sound: Int32, release: Int32, dcResult: Int32, dc: UInt32
        public init(draw: Int32,presentation: Int32,sound: Int32,release: Int32,dcResult: Int32,dc: UInt32) {
            self.draw = draw; self.presentation = presentation; self.sound = sound
            self.release = release; self.dcResult = dcResult; self.dc = dc
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
        case free(UInt32)
        case translate(Loop.Request)
        case sleep(UInt32)
        case bitmap(OriginalBitmapSurfaceLoading.Request,OriginalBitmapSurfaceLoading.Response)
        case allocate(UInt32,[UInt8])
        case settings(OriginalSettingsEvent)
        case lifecycle(OriginalWindowInitialization.Request,OriginalWindowInitialization.Response)
        case startupFront(OriginalFrontScreenEvent)
        case startupGraphics(OriginalFrontScreenEvent,result: Int32)
    }
    public enum Checkpoint: String {
        case dispatch, world, prefix, panel, body, alternate, main, tail, worldReturn, dispatchReturn
    }
    public struct Committed {
        public let result: Loop.Result
        public let effects: [Effect]
        public let graphics: [OriginalApplicationGraphics.Command]
    }
    /// Child-entry evidence only. The tentative timer work in the caller has
    /// not returned. These operations must not be dispatched as committed IO.
    public struct PendingLoading {
        public let state: State, target: UInt32
        public let loopContinuation: Loop.PendingDispatch
        public let stagedEffects: [Effect]
        public let stagedGraphics: [OriginalApplicationGraphics.Command]
        public func makeLoadingSession() throws -> OriginalApplicationLoadingSession {
            try .init(pending:self)
        }
    }
    public enum Outcome { case committed(Committed), loading(PendingLoading) }
    private struct Loading: Error { let pending: PendingLoading }

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
        initialization: OriginalApplicationBootstrap.MenuInputs? = nil,
        bootstrapObserve: @escaping (OriginalApplicationBootstrap.Observation) throws -> Void = { _ in },
        lifecycle: (OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response = { _ in throw Boundary.dependency("Menu lifecycle") }) throws -> Outcome {
        try state.validateAliases()
        var next = self, effects: [Effect] = []
        var loopContinuation: Loop.PendingDispatch?
        var bitmapInputs = state.bitmapInputs ?? initialization?.bitmapResources.map { OriginalApplicationBitmapInputs(resources:$0) }
        var graphics = state.graphics, graphicsCommands: [OriginalApplicationGraphics.Command] = []
        func emit(_ effect: Effect) throws {
            if var owner = graphics {
                let command = try owner.consume(effect,inputs:bitmapInputs);graphics = owner
                if let command { graphicsCommands.append(command);try graphicsObserve(command) }
            }
            effects.append(effect)
        }
        let oldCounter = loop.counter
        var stage: OriginalApplicationBootstrap.Stage = .menu
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
                try emit(.blit(b,result:drawResult))
            case "fill":
                guard let f = e.fill else { throw Boundary.dependency("Missing fill request") }
                try emit(.fill(f,result:stage == .prefix ? initialization?.prefix.fillResult ?? responses.draw : responses.draw))
            case "soundMethod": try emit(.soundMethod(e,ignoredResult:responses.sound))
            case "method":
                guard e.arguments.count >= 2 else { throw Boundary.dependency("Menu COM request") }
                if e.arguments[1] == 8 {
                    if var bindings = bitmapInputs {
                        _ = try bindings.response(.init("release",[e.arguments[0]]),control:.init(result:responses.release))
                        bitmapInputs = bindings
                    }
                    try emit(.release(e,ignoredResult:responses.release))
                }
                else if e.arguments[1] == 0x14 || e.arguments[1] == 0x2c { try emit(.present(e,result:responses.presentation)) }
                else { throw Boundary.dependency("Menu COM continuation") }
            case "getDC": try emit(.getDC(e,result:stage == .body ? initialization?.body.dcResult ?? responses.dcResult : responses.dcResult,output:stage == .body ? initialization?.body.dc ?? responses.dc : responses.dc))
            case "setBackgroundMode","setTextColor","textOut","releaseDC":
                if let input = initialization,stage == .body { try emit(.startupGraphics(e,result:input.body.methodResult)) }
                else { try emit(.graphics(e,result:responses.draw)) }
            case "free":
                guard e.arguments.count == 1 else { throw Boundary.dependency("Menu free request") }
                try emit(.free(e.arguments[0]))
            case "timer","createThread","lastError":
                guard initialization != nil && stage == .prefix else { throw Boundary.dependency("Menu operation "+e.kind) }
                try emit(.startupFront(e))
            case "format","allocate","construct":
                guard initialization != nil && stage == .prefix else { throw Boundary.dependency("Menu format") }
            case "enter","leave":if initialization != nil { try emit(.startupFront(e)) }
            case "write","writeLocal","read","clip","draw","text","stringLength","soundRequest","randomTable","panel": break
            default: throw Boundary.dependency("Menu operation "+e.kind)
            }
            if initialization != nil && stage != .menu { try bootstrapObserve(.front(stage,e)) }
            else { try observe(e) }
        }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
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
                        if input.message == 5 {
                            result = try OriginalWindowLifecycle.receive(input,globals:&g,memory:&owned.memory,
                                backing:{ _,_ in throw Boundary.dependency("Initial resize backing") },perform:{ q in
                                    let r = try lifecycle(q);try emit(.lifecycle(q,r));return r
                                },store:store)
                        } else { result = try OriginalWindowInput.receive(input,globals:&g,local:&local,memory:&owned.memory,request:{ q in
                            guard q.kind == .windowDefault else { throw Boundary.dependency("Menu window "+q.kind.rawValue) }
                            return try windowDefault(q)
                        },store:store) }
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
                    var settings = owned.settings
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
                        guard let input = initialization else { throw Boundary.dependency("Initial bitmap inputs") }
                        var created: UInt32?
                        let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:false,
                            backing:allocation.backing,device:device,flags:0x40,context:&created,perform:{ q,cursor in
                                let replies = at == .resources ? input.frontResponses : input.backgroundResponses
                                let index = at == .resources ? frontAPIIndex : backgroundAPIIndex
                                guard index < replies.count else { throw Boundary.dependency("Initial bitmap response") }
                                let control = replies[index]
                                let response: OriginalBitmapSurfaceLoading.Response
                                if var bindings = bitmapInputs {
                                    response = try bindings.response(q,control:control);bitmapInputs = bindings
                                } else { response = control }
                                if at == .resources { frontAPIIndex += 1 } else { backgroundAPIIndex += 1 }
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
                        _ = try OriginalBitmapDrawing.draw(input,bitmap:canonical,observeRead:{ r in var e = OriginalFrontScreenEvent("read");e.read = r;try event(e) },observeClip:{ c in var e = OriginalFrontScreenEvent("clip");e.clip = c;try event(e) },perform:{ b in var e = OriginalFrontScreenEvent("blit");e.blit = b;try event(e);return drawResult })
                    }
                    let continuation = try OriginalFrontMenuLoop.run(world:&world,globals:&g,initialize:{ w,state in
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
                            input = .init(drawTarget:game.target,milliseconds:0,threadHandle:0,threadID:0,lastError:0,fillResult:responses.draw,drawResults:[responses.draw])
                        }
                        let oldKeys = Set(screen.bitmaps.keys)
                        let end = try screen.advance(globals:&state,input:input,fillBacking:[UInt8](repeating:0,count:100),allocate:{
                            guard let first = initialization else { throw Boundary.dependency("Menu background allocation") }
                            let allocation = first.backgroundAllocation
                            try bootstrapObserve(.allocateBackground(allocation))
                            guard allocation.address == 0 || memory.allocations[allocation.address] == nil else { throw Boundary.bitmapOwnership(allocation.address) }
                            try emit(.allocate(allocation.address,allocation.backing));return allocation
                        },source:{ _ in throw Boundary.dependency("Menu background source") },constructBitmap:{ allocation,device,path in
                            try construct(allocation,device,path,.prefix)
                        },observe:event)
                        if initialization != nil {
                            let fresh = screen.bitmaps.filter { !oldKeys.contains($0.key) }
                            try adopt(fresh,screen.surfaces.filter { fresh[$0.key] != nil })
                            try bootstrapObserve(.prefixReturn(end,combined(state),screen))
                        }
                        return end
                    },update:{ state in
                        stage = .body
                        try point(.panel,combined(state))
                        let result = try OriginalMenuPanelUpdate.run(globals:&state,content:{ _ in throw Boundary.dependency("Menu panel content") },bitmap:{ _ in throw Boundary.dependency("Menu panel bitmap") },write:{ _,_ in throw Boundary.dependency("Menu panel write") },observe:{ e,_ in try event(.init(e.kind,e.arguments)) })
                        if initialization != nil { try bootstrapObserve(.panelReturn(combined(state))) }
                        return result
                    },body:{ state in
                        try point(.body,combined(state))
                        let output = try OriginalFrontScreenBody.advanceOwnStartup(globals:&state,target:game.target,libraryText:&library,input:initialization?.body ?? .init(dcResult:responses.dcResult,dc:responses.dc,methodResult:responses.draw,drawResults:[responses.draw],shellResult:0),draw:draw,observe:event)
                        try bodyProduced(output); body = output
                        if initialization != nil { try bootstrapObserve(.bodyReturn(output,combined(state),library)) }
                        return output.continuation
                    },alternate:{ state,selector in
                        stage = .menu
                        try point(.alternate,combined(state))
                        return try OriginalFrontScreenAlternate.advance(globals:&state,input:.init(selector:selector,drawTarget:game.target,timers:[],methodResult:0,drawResults:[responses.draw],fillResult:0,threadHandle:0,threadID:0,lastError:0),draw:draw,fill:{ _ in throw Boundary.dependency("Alternate fill") },writeSettings:{ _ in throw Boundary.dependency("Alternate settings write") },observe:event)
                    },completion:{ entry,w,state in
                        let presentation: OriginalMenuPresentationEntry
                        if entry == .main {
                            try point(.main,combined(state,w))
                            // Network replies are unavailable to this session.
                            // Its first network request is rejected by event().
                            let input = OriginalMainMenuInput(targetSurface:game.target,panelWord:nil,network:.init(startupResult:0,version:0,hostnameResult:0,hostname:[],hostEntryAddress:0,addresses:[],socketResult:0,asyncResult:0,bindResult:0,listenResult:0))
                            let end = try OriginalMainMenu.run(world:&w,globals:&state,crt:&random,input:input,store:store,worldStored:worldStore,observe:{ e in
                                if e.kind == .bitmap { try event(.init("draw",e.arguments));try draw(e.arguments) }
                                else { try event(.init(e.kind.rawValue,e.arguments,e.strings)) }
                            })
                            guard end == .present else { throw Boundary.dependency("Main menu return") }
                            presentation = .tail
                        } else { presentation = entry == .worldOne ? .worldOne : .tail }
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
                    })
                    let resultRecord = try combined(g,world)
                    owned.full = resultRecord; owned.front = resources; owned.earlyScreen = screen
                    owned.libraryText = library; owned.random = random; owned.memory = memory; owned.screenBody = body; owned.settings = settings;owned.bitmapInputs = bitmapInputs;owned.graphics = graphics
                    try owned.replace(Self.replayStart,memory.replayPointers)
                    if continuation == .loading {
                        guard let loopContinuation else { throw Boundary.dependency("Missing loading loop continuation") }
                        throw Loading(pending:.init(state:owned,target:game.target,loopContinuation:loopContinuation,stagedEffects:effects,stagedGraphics:graphicsCommands))
                    }
                    guard continuation == .returned else { throw Boundary.dependency("Menu continuation "+continuation.rawValue) }
                    try point(.worldReturn,owned.full,initialization == nil ? nil : responses.presentation)
                    let result = try OriginalApplicationDispatchEntry.finishWorldCall(globals:owned.full)
                    try point(.dispatchReturn,owned.full,result)
                    return .init(result:result)
                },counterWritten:{ try event(.init("write",[0x458580,4,$0])) },beforeCommit:{ timer,staged,_ in
                    var coherent = staged; try coherent.mergeAliases(counter:timer.counter)
                    try beforeCommit(timer,coherent)
                })
            try next.state.mergeAliases(counter:next.loop.counter)
            self = next
            return .committed(.init(result:result,effects:effects,graphics:graphicsCommands))
        } catch let loading as Loading {
            return .loading(loading.pending)
        }
    }
}
