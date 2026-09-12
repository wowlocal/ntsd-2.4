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

        fileprivate func validateAliases() throws {
            guard full.bytes.count == OriginalApplicationDispatchEntry.globalSize,
                  memory.replayPointers.bytes.count == 8,
                  try Self.slice(full,OriginalApplicationMenuSession.replayStart,8) == memory.replayPointers else {
                throw OriginalStateError.invalidStorage("Menu replay alias bytes or masks")
            }
        }
        fileprivate static func slice(_ record: OriginalStateRecord,_ start: Int,_ count: Int) throws -> OriginalStateRecord {
            guard start >= 0, count >= 0, start <= record.bytes.count-count else {
                throw OriginalStateError.invalidStorage("Menu record extent")
            }
            return try .init(bytes:Array(record.bytes[start..<start+count]),defined:Array(record.defined[start..<start+count]))
        }
        fileprivate mutating func replace(_ start: Int,_ record: OriginalStateRecord) throws {
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
        case graphics(OriginalFrontScreenEvent)
        case free(UInt32)
        case translate(Loop.Request)
        case sleep(UInt32)
    }
    public enum Checkpoint: String {
        case dispatch, world, prefix, panel, body, alternate, main, tail, worldReturn, dispatchReturn
    }
    public struct Committed {
        public let result: Loop.Result
        public let effects: [Effect]
    }
    /// Child-entry evidence only. The tentative timer work in the caller has
    /// not returned. These operations must not be dispatched as committed IO.
    public struct PendingLoading {
        public let state: State, target: UInt32
        public let stagedEffects: [Effect]
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
        checkpoint: (Checkpoint,OriginalStateRecord,Int32?) throws -> Void = { _,_,_ in },
        bodyProduced: (OriginalFrontScreenBody.StartupResult) throws -> Void = { _ in },
        beforeCommit: (Loop,State) throws -> Void = { _,_ in }) throws -> Outcome {
        try state.validateAliases()
        var next = self, effects: [Effect] = []
        let oldCounter = loop.counter
        func event(_ e: OriginalFrontScreenEvent) throws {
            switch e.kind {
            case "blit":
                guard let b = e.blit else { throw Boundary.dependency("Missing bitmap Blt request") }
                effects.append(.blit(b,result:responses.draw))
            case "fill":
                guard let f = e.fill else { throw Boundary.dependency("Missing fill request") }
                effects.append(.fill(f,result:responses.draw))
            case "soundMethod": effects.append(.soundMethod(e,ignoredResult:responses.sound))
            case "method":
                guard e.arguments.count >= 2 else { throw Boundary.dependency("Menu COM request") }
                if e.arguments[1] == 8 { effects.append(.release(e,ignoredResult:responses.release)) }
                else if e.arguments[1] == 0x14 { effects.append(.present(e,result:responses.presentation)) }
                else { throw Boundary.dependency("Menu COM continuation") }
            case "getDC": effects.append(.getDC(e,result:responses.dcResult,output:responses.dc))
            case "setBackgroundMode","setTextColor","textOut","releaseDC": effects.append(.graphics(e))
            case "free":
                guard e.arguments.count == 1 else { throw Boundary.dependency("Menu free request") }
                effects.append(.free(e.arguments[0]))
            case "write","writeLocal","read","clip","draw","text","stringLength","soundRequest","randomTable","panel","enter","leave": break
            default: throw Boundary.dependency("Menu operation "+e.kind)
            }
            try observe(e)
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
                perform:{ request, owned in
                    if request.kind != .gameDispatch {
                        guard request.kind != .recoverSurface else { throw Boundary.dependency("Application surface recovery") }
                        let response = try queue(request)
                        if request.kind == .translate { effects.append(.translate(request)) }
                        if request.kind == .sleep { effects.append(.sleep(request.arguments[0])) }
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
                        let result = try OriginalWindowInput.receive(input,globals:&g,local:&local,memory:&owned.memory,request:{ q in
                            guard q.kind == .windowDefault else { throw Boundary.dependency("Menu window "+q.kind.rawValue) }
                            return try windowDefault(q)
                        },store:store)
                        try owned.replace(0,g); try owned.replace(Self.outerStart,local)
                        try owned.mergeAliases(counter:oldCounter)
                        return .init(result:result)
                    }
                    try owned.mergeAliases(counter:oldCounter)
                    try point(.dispatch,owned.full)
                    let game = try OriginalApplicationDispatchEntry.advance(incomingTarget:request.arguments[0],globals:&owned.full,perform:{ q,_ in
                        guard q.kind == "blt" else { throw Boundary.dependency("Menu dispatcher "+q.kind) }
                        let response = try surface(q); effects.append(.surface(q,response)); return response
                    },store:store)
                    try point(.world,owned.full)
                    var world = try State.slice(owned.full,Self.worldStart,0x7d8)
                    var g = try State.slice(owned.full,0,Self.globalCount)
                    var resources = owned.front, screen = owned.earlyScreen, library = owned.libraryText
                    var random = owned.random, memory = owned.memory, body = owned.screenBody
                    // Drawing callbacks run while presentation borrows memory.
                    // Track its ordered frees separately to avoid an overlapping
                    // Swift access while preserving current ownership checks.
                    var drawing = memory.allocations
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
                        _ = try OriginalBitmapDrawing.draw(input,bitmap:canonical,observeRead:{ r in var e = OriginalFrontScreenEvent("read");e.read = r;try event(e) },observeClip:{ c in var e = OriginalFrontScreenEvent("clip");e.clip = c;try event(e) },perform:{ b in var e = OriginalFrontScreenEvent("blit");e.blit = b;try event(e);return responses.draw })
                    }
                    let continuation = try OriginalFrontMenuLoop.run(world:&world,globals:&g,initialize:{ w,state in
                        try resources.load(world:w,globals:&state,allocate:{ _ in throw Boundary.dependency("Menu resource allocation") },source:{ _,_ in throw Boundary.dependency("Menu resource source") },deviceResult:{ _ in throw Boundary.dependency("Menu resource device") },observe:{ e in
                            guard e.kind == .write else { throw Boundary.dependency("Menu resource "+e.kind.rawValue) }
                            try event(.init("write",[e.arguments[1],e.arguments[2],e.arguments[3]]))
                        })
                    },prefix:{ state in
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
                        return try screen.advance(globals:&state,input:.init(drawTarget:game.target,milliseconds:0,threadHandle:0,threadID:0,lastError:0,fillResult:responses.draw,drawResults:[responses.draw]),fillBacking:[UInt8](repeating:0,count:100),allocate:{ throw Boundary.dependency("Menu background allocation") },source:{ _ in throw Boundary.dependency("Menu background source") },observe:event)
                    },update:{ state in
                        try point(.panel,combined(state))
                        return try OriginalMenuPanelUpdate.run(globals:&state,content:{ _ in throw Boundary.dependency("Menu panel content") },bitmap:{ _ in throw Boundary.dependency("Menu panel bitmap") },write:{ _,_ in throw Boundary.dependency("Menu panel write") },observe:{ e,_ in try event(.init(e.kind,e.arguments)) })
                    },body:{ state in
                        try point(.body,combined(state))
                        let output = try OriginalFrontScreenBody.advanceOwnStartup(globals:&state,target:game.target,libraryText:&library,input:.init(dcResult:responses.dcResult,dc:responses.dc,methodResult:responses.draw,drawResults:[responses.draw],shellResult:0),draw:draw,observe:event)
                        try bodyProduced(output); body = output; return output.continuation
                    },alternate:{ state,selector in
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
                    owned.libraryText = library; owned.random = random; owned.memory = memory; owned.screenBody = body
                    try owned.replace(Self.replayStart,memory.replayPointers)
                    if continuation == .loading {
                        throw Loading(pending:.init(state:owned,target:game.target,stagedEffects:effects))
                    }
                    guard continuation == .returned else { throw Boundary.dependency("Menu continuation "+continuation.rawValue) }
                    try point(.worldReturn,owned.full)
                    let result = try OriginalApplicationDispatchEntry.finishWorldCall(globals:owned.full)
                    try point(.dispatchReturn,owned.full,result)
                    return .init(result:result)
                },counterWritten:{ try event(.init("write",[0x458580,4,$0])) },beforeCommit:{ timer,staged,_ in
                    var coherent = staged; try coherent.mergeAliases(counter:timer.counter)
                    try beforeCommit(timer,coherent)
                })
            try next.state.mergeAliases(counter:next.loop.counter)
            self = next
            return .committed(.init(result:result,effects:effects))
        } catch let loading as Loading {
            return .loading(loading.pending)
        }
    }
}
