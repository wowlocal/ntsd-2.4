/// Continue the owned loading/input menu child through fresh resources, the
/// installed-library mode/human character screens and the loading/early return. Effects
/// remain tentative until the retained enclosing session completes its loop.
public struct OriginalApplicationLoadedMenuSession {
    public typealias Input = OriginalApplicationInputSession
    public typealias Session = OriginalApplicationMenuSession
    public typealias State = Session.State
    public typealias API = OriginalBitmapSurfaceLoading
    public enum Boundary: Error, Equatable {
        case alreadyPrepared, dependency(String), overlap(UInt32), owner(UInt32)
    }
    public enum AllocationKind: Equatable { case menu(Int), background, arena(Int), war(Int) }
    public enum Operation: Equatable {
        case preceding(Input.Operation), menu(Session.Effect)
        case music(OriginalMusicEvent,OriginalMusicResponse)
        case front(OriginalFrontScreenEvent,Int32,UInt32?)
        case clock(UInt32), loop(Session.Loop.Request,Session.Loop.Response)
        case localTime(OriginalLocalTime), recordingAllocation(UInt32,Int)
        case gameplayRecording(OriginalResultRecording.Event)
        case gameplayAllocate(UInt32,Int), gameplayProcessor(UInt32)
        case gameplayOpen(OriginalReplayFileOutput.OpenRequest,Bool)
        case gameplayWrite([UInt8],Int32), gameplayClose(Int32)
        case gameplayResume(UInt32,Int32)
    }
    public enum Observation {
        case music(OriginalMusicEvent,OriginalMusicResponse), bitmap(API.Request,API.Response)
        case resource(OriginalInterfaceEvent), front(OriginalFrontScreenEvent)
        case resourceCheckpoint(OriginalMenuResourceCheckpoint,OriginalStateRecord,[UInt32:OriginalLoadedBitmap])
        case characterCheckpoint(OriginalCharacterScreenCheckpoint,OriginalMatchPreparation)
        case prelude(OriginalMatchPreludeEvent), preparation(OriginalMatchPreparationEvent)
        case launchCheckpoint(String,Snapshot)
        case gameplay(OriginalGameplayBody.Event)
        case gameplayCheckpoint(OriginalGameplayBody.Stage,Snapshot)
    }
    public struct Snapshot {
        public let state: State, match: OriginalMatchPreparation
        public let music: OriginalMusicMemory,resources: OriginalMenuResourceLoading
        public let backgrounds: [UInt32:OriginalLoadedBitmap]
        public let local: OriginalStateRecord,operations: [Operation]
    }
    public struct PendingReturn {
        public let entry: Input.PendingContinuation, snapshot: Snapshot
        public let exit: OriginalModeScreenExit,dispatcherResult: Int32?
        public let graphics: [OriginalApplicationGraphics.Command]
        public var loading: Session.PendingLoading { entry.loading }
    }
    /// Start has been selected, but preparation and the enclosing return have
    /// not run. Retain current owners and the original suspended loop ticket.
    public struct PendingMatchPrelude {
        public let entry: Input.PendingContinuation, snapshot: Snapshot
        public let confirmation: Int32
        public let locals: [Int:Int32]
        public let graphics: [OriginalApplicationGraphics.Command]
        public var loading: Session.PendingLoading { entry.loading }
    }
    public enum Outcome {
        case returned(PendingReturn), matchPrelude(PendingMatchPrelude)
    }
    /// Playback Recording (43249c) platform services: GetOpenFileNameA (nil:
    /// cancelled), the file behind 43e620's ifstream (nil: does not open),
    /// MessageBoxA(0, text, 0, 0) and ShellExecuteA(open) for a `.txt` choice.
    public struct PlaybackServices<Environment> {
        public let choose: (inout Environment) throws -> String?
        public let read: (String,inout Environment) throws -> [UInt8]?
        public let alert: ([UInt8],inout Environment) throws -> Void
        public let open: (String,inout Environment) throws -> Void
        public init(choose: @escaping (inout Environment) throws -> String?,read: @escaping (String,inout Environment) throws -> [UInt8]?,
                    alert: @escaping ([UInt8],inout Environment) throws -> Void,open: @escaping (String,inout Environment) throws -> Void) {
            self.choose = choose;self.read = read;self.alert = alert;self.open = open
        }
    }
    public let entry: Input.PendingContinuation
    public private(set) var pendingReturn: PendingReturn?
    public private(set) var pendingMatchPrelude: PendingMatchPrelude?
    public init(pending: Input.PendingContinuation) throws {
        try pending.state.validateAliases()
        guard pending.round.continuation == .menu else { throw Boundary.dependency("Selected input continuation") }
        guard pending.state.bitmapInputs != nil,pending.state.graphics != nil else { throw Boundary.dependency("Graphics owners") }
        entry = pending
    }
    /// Providers buffer platform work in their value-owned Environment. Numeric
    /// responses are explicit; bitmap structures come from bundled DIB inputs.
    @discardableResult
    public mutating func advance<Environment>(inputs: OriginalApplicationMenuInputs,environment: inout Environment,
        screenInput: OriginalFrontScreenBodyInput,outputInput: OriginalMenuPresentationInput,
        allocate: @escaping (AllocationKind,Int,inout Environment) throws -> OriginalInterfaceAllocation,
        bitmap: @escaping (API.Request,inout Environment) throws -> API.Response,
        music: @escaping (OriginalMusicEvent,inout Environment) throws -> OriginalMusicResponse,
        milliseconds: @escaping (inout Environment) throws -> UInt32,
        observe: @escaping (Observation,inout Environment) throws -> Void = { _,_ in },
        checkpoint: @escaping (String,OriginalStateRecord,inout Environment) throws -> Void = { _,_,_ in },
        beforeCommit: (PendingReturn,inout Environment) throws -> Void = { _,_ in }) throws -> PendingReturn {
        guard pendingReturn == nil,pendingMatchPrelude == nil else { throw Boundary.alreadyPrepared }
        let a = try Attempt(entry,inputs,environment,screenInput,outputInput,allocate,bitmap,music,milliseconds,observe,checkpoint,nil,nil)
        guard case .returned(let result) = try a.run() else { throw Boundary.dependency("Match prelude requires retained continuation") }
        try beforeCommit(result,&a.environment)
        pendingReturn = result;environment = a.environment;return result
    }
    /// Produce either a completed menu child or the still-pending Start child.
    /// Neither outcome publishes effects to a host or completes the Bootstrap.
    @discardableResult
    public mutating func advanceUntilBoundary<Environment>(inputs: OriginalApplicationMenuInputs,environment: inout Environment,
        screenInput: OriginalFrontScreenBodyInput,outputInput: OriginalMenuPresentationInput,
        allocate: @escaping (AllocationKind,Int,inout Environment) throws -> OriginalInterfaceAllocation,
        bitmap: @escaping (API.Request,inout Environment) throws -> API.Response,
        music: @escaping (OriginalMusicEvent,inout Environment) throws -> OriginalMusicResponse,
        milliseconds: @escaping (inout Environment) throws -> UInt32,
        observe: @escaping (Observation,inout Environment) throws -> Void = { _,_ in },
        checkpoint: @escaping (String,OriginalStateRecord,inout Environment) throws -> Void = { _,_,_ in },
        localTime: ((inout Environment) throws -> OriginalLocalTime)? = nil,
        allocateReplay: ((Int,inout Environment) throws -> UInt32)? = nil,
        demoMusicTrack: Int32? = nil,
        playback: PlaybackServices<Environment>? = nil,
        beforeCommit: (Outcome,inout Environment) throws -> Void = { _,_ in }) throws -> Outcome {
        guard pendingReturn == nil,pendingMatchPrelude == nil else { throw Boundary.alreadyPrepared }
        let a = try Attempt(entry,inputs,environment,screenInput,outputInput,allocate,bitmap,music,milliseconds,observe,checkpoint,localTime,allocateReplay)
        a.demoMusicTrack = demoMusicTrack;a.playback = playback
        let result = try a.run()
        try beforeCommit(result,&a.environment)
        switch result {
        case .returned(let value):pendingReturn = value
        case .matchPrelude(let value):pendingMatchPrelude = value
        }
        environment = a.environment;return result
    }
    final class Attempt<E> {
        let entry: Input.PendingContinuation,bindings: OriginalApplicationMatchBindings
        let screenInput: OriginalFrontScreenBodyInput,outputInput: OriginalMenuPresentationInput
        let allocation: (AllocationKind,Int,inout E) throws -> OriginalInterfaceAllocation
        let bitmapReply: (API.Request,inout E) throws -> API.Response
        let musicReply: (OriginalMusicEvent,inout E) throws -> OriginalMusicResponse
        let clock: (inout E) throws -> UInt32
        /// War start (43a21f) providers: GetLocalTime and the recording calloc.
        let localTimeReply: ((inout E) throws -> OriginalLocalTime)?,replayReply: ((Int,inout E) throws -> UInt32)?
        /// 4025d0's ECX at the Demo start (declared by the platform; nil: boundary).
        var demoMusicTrack: Int32?
        var playback: PlaybackServices<E>?
        /// 458588..4588a8 after a playback start in this call (stored by the snapshot).
        var savedPlayback: OriginalStateRecord?
        let observe: (Observation,inout E) throws -> Void,checkpoint: (String,OriginalStateRecord,inout E) throws -> Void
        var environment: E,state: State,model: OriginalMatchPreparation
        var audio: OriginalMusicMemory,resources = OriginalMenuResourceLoading()
        var backgrounds: [UInt32:OriginalLoadedBitmap] = [:]
        var local: OriginalStateRecord,operations: [Operation],graphics: [OriginalApplicationGraphics.Command]
        var surfaces: [UInt32:UInt32] = [:],current: UInt32?,outputPhase = false
        /// The address ranges reserved at the attempt's start, then claims. Only
        /// claim/reserve use them (allocation events), so the starting ranges
        /// are collected on first use from values captured in init
        /// (CORE_REALTIME R2).
        var ranges: [(UInt64,UInt64)] { collectStartingRanges(); return collectedRanges! }
        private var collectedRanges: [(UInt64,UInt64)]?, collectRanges: (() -> [(UInt64,UInt64)])?
        private func collectStartingRanges() {
            if collectedRanges == nil { collectedRanges = collectRanges!(); collectRanges = nil }
        }
        var target: UInt32 { entry.loading.target }
        init(_ entry: Input.PendingContinuation,_ inputs: OriginalApplicationMenuInputs,_ env: E,
             _ screen: OriginalFrontScreenBodyInput,_ output: OriginalMenuPresentationInput,
             _ allocate: @escaping (AllocationKind,Int,inout E) throws -> OriginalInterfaceAllocation,
             _ bitmap: @escaping (API.Request,inout E) throws -> API.Response,
             _ music: @escaping (OriginalMusicEvent,inout E) throws -> OriginalMusicResponse,
             _ time: @escaping (inout E) throws -> UInt32,
             _ observe: @escaping (Observation,inout E) throws -> Void,
             _ checkpoint: @escaping (String,OriginalStateRecord,inout E) throws -> Void,
             _ localTime: ((inout E) throws -> OriginalLocalTime)? = nil,
             _ replay: ((Int,inout E) throws -> UInt32)? = nil,
             resuming: PendingMatchPrelude? = nil) throws {
            localTimeReply = localTime;replayReply = replay
            self.entry = entry;environment = env;state = resuming?.snapshot.state ?? entry.state
            model = resuming?.snapshot.match ?? entry.match;audio = resuming?.snapshot.music ?? entry.music
            resources = resuming?.snapshot.resources ?? entry.menuResources
            backgrounds = resuming?.snapshot.backgrounds ?? entry.menuBackgrounds
            bindings = try .init(pending:entry.entry);screenInput = screen;outputInput = output
            allocation = allocate;bitmapReply = bitmap;musicReply = music;clock = time
            self.observe = observe;self.checkpoint = checkpoint
            operations = resuming?.snapshot.operations ?? entry.operations.map(Operation.preceding)
            graphics = resuming?.graphics ?? entry.graphics
            local = try resuming?.snapshot.local ?? .init(bytes:[UInt8](repeating:0,count:0x704),defined:[Bool](repeating:false,count:0x704))
            guard screen.drawResults.count == 1 else { throw Boundary.dependency("Single menu draw response") }
            guard output.targetSurface == entry.loading.target else { throw Boundary.dependency("Menu target") }
            guard var images = state.bitmapInputs else { throw Boundary.dependency("Bitmap inputs") }
            try images.addResources(inputs.bitmaps);state.bitmapInputs = images
            // The starting ranges, in the order they were always reserved: the
            // globals, live allocations, the session's static ranges (built once
            // per session; a wave-owner failure throws here as before), audio.
            let fullCount = state.full.bytes.count,allocations = state.memory.allocations
            let staticRanges = try entry.entry.staticRanges(),audioAllocations = audio.allocations
            collectRanges = {
                var spans: [(UInt64,UInt64)] = []
                func add(_ token: UInt32,_ count: Int) { if token != 0 && count > 0 { spans.append((UInt64(token),UInt64(token)+UInt64(count))) } }
                add(0x44d000,fullCount)
                for (token,a) in allocations where a.live { add(token,a.storage.byteCount) }
                spans += staticRanges
                for (token,record) in audioAllocations { add(token,record.bytes.count) }
                return spans
            }
        }
        func reserve(_ token: UInt32,_ count: Int) {
            guard token != 0 && count > 0 else { return }
            collectStartingRanges(); collectedRanges!.append((UInt64(token),UInt64(token)+UInt64(count)))
        }
        func claim(_ token: UInt32,_ count: Int) throws {
            let lo = UInt64(token),hi = lo+UInt64(count)
            guard token != 0,count > 0,hi <= UInt64(UInt32.max)+1,
                  !ranges.contains(where:{ lo < $0.1 && $0.0 < hi }) else { throw Boundary.overlap(token) }
            reserve(token,count)
        }
        func emit(_ effect: Session.Effect) throws {
            guard var owner = state.graphics else { throw Boundary.dependency("Graphics") }
            if let command = try owner.consume(effect,inputs:state.bitmapInputs) { graphics.append(command) }
            state.graphics = owner;operations.append(.menu(effect))
        }
        func allocate(_ kind: AllocationKind) throws -> OriginalInterfaceAllocation {
            let a = try allocation(kind,0x1f50,&environment)
            if a.address != 0 {
                guard a.backing.count == 0x1f50 else { throw Boundary.dependency("Bitmap backing extent") }
                try claim(a.address,a.backing.count);surfaces[a.address] = 0
            } else if !a.backing.isEmpty { throw Boundary.dependency("NULL bitmap backing") }
            current = a.address;try emit(.allocate(a.address,a.backing));return a
        }
        func bitmap(_ q: API.Request) throws -> API.Response {
            let control = try bitmapReply(q,&environment)
            guard var inputs = state.bitmapInputs else { throw Boundary.dependency("Bitmap inputs") }
            let reply = try inputs.response(q,control:control);state.bitmapInputs = inputs
            if q.kind == "createSurface",let surface = reply.output {
                guard let current,current != 0 else { throw Boundary.dependency("Surface allocation owner") }
                surfaces[current] = surface
            }
            try emit(.bitmap(q,reply));try observe(.bitmap(q,reply),&environment);return reply
        }
        func music(_ e: OriginalMusicEvent) throws -> OriginalMusicResponse {
            let response = try musicReply(e,&environment)
            if e.kind == .allocate,let token = response.pointer,token != 0 {
                guard let count = e.arguments.first else { throw Boundary.dependency("Music allocation extent") }
                try claim(token,Int(count))
            }
            if e.kind != .helper && e.kind != .format { operations.append(.music(e,response)) }
            try observe(.music(e,response),&environment);return response
        }
        func milliseconds() throws -> UInt32 {
            let value = try clock(&environment);operations.append(.clock(value));return value
        }
        func adopted(_ bitmaps: [UInt32:OriginalLoadedBitmap],in memory: inout OriginalMenuPresentationMemory) throws {
            for (token,bitmap) in bitmaps {
                guard let surface = surfaces[token],entry.state.memory.allocations[token] == nil else { throw Boundary.owner(token) }
                var record = bitmap.storage
                let liveSurface = try record.integer(at:0,as:UInt32.self) != 0
                guard !liveSurface || surface != 0 else { throw Boundary.owner(token) }
                try record.write(liveSurface ? surface : 0,at:0)
                memory.allocations[token] = .init(storage:record)
            }
        }
        func snapshot(_ globals: OriginalStateRecord,_ music: OriginalMusicMemory,
                      _ images: OriginalMenuResourceLoading,_ memory: OriginalMenuPresentationMemory? = nil,
                      _ world: OriginalStateRecord? = nil) throws -> Snapshot {
            var own = state,match = model,context = entry.inputContext
            match.globals = globals;if let world { match.world = world }
            context.memory = memory ?? state.memory
            if let savedPlayback { context.savedPlayback = savedPlayback }
            try bindings.store(match,context:context,in:&own)
            return .init(state:own,match:match,music:music,resources:images,backgrounds:backgrounds,local:local,operations:operations)
        }
        func point(_ name: String) throws { try checkpoint(name,model.globals,&environment) }
        func front(_ e: OriginalFrontScreenEvent) throws {
            let response = outputPhase ? outputInput.methodResult : screenInput.methodResult
            switch e.kind {
            case "blit":guard let b = e.blit else { throw Boundary.dependency("Blt") };try emit(.blit(b,result:outputPhase ? outputInput.methodResult : screenInput.drawResults.first ?? response))
            case "fill":guard let f = e.fill else { throw Boundary.dependency("Fill") };try emit(.fill(f,result:response))
            case "getDC":try emit(.getDC(e,result:outputPhase ? outputInput.dcResult : screenInput.dcResult,output:outputPhase ? outputInput.dc : screenInput.dc))
            case "setBackgroundMode","setTextColor","textOut","releaseDC":try emit(.graphics(e,result:response))
            case "method":
                guard e.arguments.count >= 2 else { throw Boundary.dependency("Method") }
                if let owner = state.graphics?.currentResources[e.arguments[0]],["primary","backbuffer","bitmapSurface"].contains(owner.kind) {
                    if e.arguments[1] == 8 {
                        if var inputs = state.bitmapInputs,inputs.surfaces[e.arguments[0]] != nil {
                            _ = try inputs.response(.init("release",[e.arguments[0]]),control:.init(result:response));state.bitmapInputs = inputs
                        }
                        try emit(.release(e,ignoredResult:response))
                    } else { try emit(.present(e,result:response)) }
                } else {
                    let result = outputPhase && e.arguments[1] == 0x1c ? outputInput.audioSetResult : response
                    operations.append(.front(e,result,nil))
                }
            case "soundMethod":try emit(.soundMethod(e,ignoredResult:response))
            case "musicMethod":operations.append(.front(e,response,nil))
            case "free":guard e.arguments.count == 1 else { throw Boundary.dependency("Free") };try emit(.free(e.arguments[0]))
            case "queryInterface":operations.append(.front(e,outputInput.queryResult,outputInput.queriedAudio))
            case "audioVolumeRead":operations.append(.front(e,outputInput.audioGetResult,UInt32(bitPattern:outputInput.audioVolume)))
            case "sleep":operations.append(.front(e,0,nil))
            case "shell":operations.append(.front(e,Int32(bitPattern:screenInput.shellResult),nil))
            case "postMessage":operations.append(.front(e,outputInput.postResult,nil))
            case "enter","leave":operations.append(.front(e,0,nil))
            case "postQuit":
                // PostQuitMessage(code) is void; the platform posts WM_QUIT only
                // after this batch commits.
                guard e.arguments.count == 1,e.strings.isEmpty else { throw Boundary.dependency("PostQuitMessage") }
                operations.append(.front(e,0,nil))
            case "width","rectangle","labelWrite","fontPass","stringWrite","localWrite","formatWrite","infoWrite","infoText","stage","queueWrite","play","dispatcherWrite","write","read","clip","draw","text","stringLength","soundRequest","format","panel","keyName","timer","call","return","allocate","construct","candidates","random","musicConfiguration","stopMusic","warFrame":break
            default:throw Boundary.dependency("Front operation "+e.kind)
            }
            try observe(.front(e),&environment)
        }
        func draw(_ args: [UInt32],_ globals: OriginalStateRecord,_ memory: OriginalMenuPresentationMemory) throws {
            guard args.count == 7,let a = memory.allocations[args[0]],a.live,a.storage.bytes.count == 0x1f50 else { throw Boundary.dependency("Draw bitmap owner") }
            let surface = try a.storage.integer(at:0,as:UInt32.self)
            var record = a.storage;try record.write(UInt32(surface == 0 ? 0 : 1),at:0)
            let q = try OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:surface,targetSurface:args[6],viewportWidth:globals.integer(at:0x78c,as:Int32.self),viewportHeight:globals.integer(at:0x790,as:Int32.self))
            _ = try OriginalBitmapDrawing.draw(q,bitmap:record,observeRead:{ r in var e = OriginalFrontScreenEvent("read");e.read = r;try self.front(e) },observeClip:{ c in var e = OriginalFrontScreenEvent("clip");e.clip = c;try self.front(e) },perform:{ b in var e = OriginalFrontScreenEvent("blit");e.blit = b;try self.front(e);return self.outputPhase ? self.outputInput.methodResult : self.screenInput.drawResults.first ?? self.screenInput.methodResult })
        }
        func characterDraw(_ request: OriginalCharacterScreenDraw,_ globals: OriginalStateRecord,
                           _ memory: OriginalMenuPresentationMemory) throws {
            switch request.bitmap {
            case .menu(let token):
                let args = [token,UInt32(bitPattern:request.x),UInt32(bitPattern:request.y),
                            UInt32(bitPattern:request.frame),request.colorKey,0,request.target]
                try front(.init("draw",args));try draw(args,globals,memory)
            case .catalog(let index):
                // Bytes and identities belong to the retained current match.
                guard model.bitmaps.indices.contains(index),!model.releasedBitmaps.contains(index),
                      let token = model.bitmapOwners[index],let liveSurface = model.bitmapSurfaceOwners[index] else {
                    throw Boundary.dependency("Catalog bitmap binding")
                }
                let bitmap = model.bitmaps[index].storage
                let surface = try bitmap.integer(at:0,as:UInt32.self) == 0 ? 0 : liveSurface
                guard surface == 0 || state.graphics?.currentResources[surface]?.kind == "bitmapSurface" else {
                    throw Boundary.owner(surface)
                }
                let args = [token,UInt32(bitPattern:request.x),UInt32(bitPattern:request.y),
                            UInt32(bitPattern:request.frame),request.colorKey,0,request.target]
                try front(.init("draw",args))
                let input = try OriginalBitmapDrawInput(x:request.x,y:request.y,frame:request.frame,colorKey:request.colorKey,
                    mirrored:0,sourceSurface:surface,targetSurface:request.target,
                    viewportWidth:globals.integer(at:0x78c,as:Int32.self),viewportHeight:globals.integer(at:0x790,as:Int32.self))
                _ = try OriginalBitmapDrawing.draw(input,bitmap:bitmap,
                    observeRead:{ r in var e = OriginalFrontScreenEvent("read");e.read = r;try self.front(e) },
                    observeClip:{ c in var e = OriginalFrontScreenEvent("clip");e.clip = c;try self.front(e) },
                    perform:{ b in var e = OriginalFrontScreenEvent("blit");e.blit = b;try self.front(e);return self.screenInput.drawResults[0] })
            }
        }
        /// The retained surface of a War bitmap: this call's CreateSurface, or the
        /// adopted owner from an earlier call.
        func warSurface(_ token: UInt32,_ owned: OriginalMenuPresentationMemory) throws -> UInt32 {
            if let surface = surfaces[token] { return surface }
            guard let a = owned.allocations[token],a.live else { throw Boundary.owner(token) }
            return try a.storage.integer(at:0,as:UInt32.self)
        }
        /// Menu200..219 (438b40): War bitmaps come from the War memory, whose
        /// BATTLEMODE geometry the setup rewrites; other draws use the menu path.
        func warDraw(_ request: OriginalCharacterScreenDraw,_ globals: OriginalStateRecord,
                     _ owned: OriginalMenuPresentationMemory,_ war: OriginalWarMenuMemory) throws {
            guard case .menu(let token) = request.bitmap,let bitmap = war.bitmaps[token] else {
                return try characterDraw(request,globals,owned)
            }
            let args = [token,UInt32(bitPattern:request.x),UInt32(bitPattern:request.y),
                        UInt32(bitPattern:request.frame),request.colorKey,0,request.target]
            try front(.init("draw",args))
            let surface = try bitmap.storage.integer(at:0,as:UInt32.self) == 0 ? 0 : warSurface(token,owned)
            let input = try OriginalBitmapDrawInput(x:request.x,y:request.y,frame:request.frame,colorKey:request.colorKey,
                mirrored:0,sourceSurface:surface,targetSurface:request.target,
                viewportWidth:globals.integer(at:0x78c,as:Int32.self),viewportHeight:globals.integer(at:0x790,as:Int32.self))
            _ = try OriginalBitmapDrawing.draw(input,bitmap:bitmap.storage,
                observeRead:{ r in var e = OriginalFrontScreenEvent("read");e.read = r;try self.front(e) },
                observeClip:{ c in var e = OriginalFrontScreenEvent("clip");e.clip = c;try self.front(e) },
                perform:{ b in var e = OriginalFrontScreenEvent("blit");e.blit = b;try self.front(e);return self.screenInput.drawResults[0] })
        }
        /// Mode4 menus200..219 and, on Start, the War preparation43a21f..43a769
        /// with this session's arena, music and recording owners.
        func war(_ scene: inout OriginalMatchPreparation,_ library: inout OriginalLibSurfaceText?,
                 _ owned: inout OriginalMenuPresentationMemory,_ musicOwner: inout OriginalMusicMemory) throws -> OriginalCharacterScreenExit {
            var memory = state.war,context: Void = ()
            let exit = try OriginalWarSetup.advanceWithSurfaceLoading(state:&scene,memory:&memory,libraryText:&library,environment:&context,
                target:target,input:screenInput,fillBacking:[UInt8](repeating:0,count:100),
                allocate:{ i,_ in try self.allocate(.war(i)) },perform:{ q,_ in try self.bitmap(q) },
                bitmapStorage:{ token,_ in
                    guard let a = owned.allocations[token],a.live else { throw Boundary.owner(token) }
                    return a.storage
                },draw:{ request,globals,war,_ in try self.warDraw(request,globals,owned,war) },
                observe:{ e,_ in try self.front(e) },resourceEvent:{ e,_ in try self.observe(.resource(e),&self.environment) },
                prepare:{ value,_,_ in try self.warStart(&value,&owned,&musicOwner);return true })
            // New War wrappers become owned allocations with their live surfaces.
            let fresh = memory.bitmaps.filter { owned.allocations[$0.key] == nil }
            try adopted(fresh,in:&owned)
            state.war = memory;return exit
        }
        /// Arena layers for a preparation that owns the memory during its call:
        /// wrappers come from `.arena(n)` allocations and releases are checked
        /// against their owners; adoption and release apply after `body`.
        func stagedArena(_ scene: inout OriginalMatchPreparation,_ owned: inout OriginalMenuPresentationMemory,
                         _ body: (inout OriginalMatchPreparation,inout OriginalMenuPresentationMemory,
                                  (String,Bool) throws -> OriginalLoadedBitmap?,(Int,OriginalLoadedBitmap) throws -> Void) throws -> Void) throws {
            var owners = scene.bitmapOwners,surfaceOwners = scene.bitmapSurfaceOwners
            var nextOrdinal = scene.bitmaps.count,layer = 0
            let device = try scene.globals.integer(at:0x457578-0x44d000,as:UInt32.self)
            let current = owned
            var arena: [UInt32:OriginalLoadedBitmap] = [:],released: [UInt32] = []
            try body(&scene,&owned,{ path,optional in
                let allocation = try self.allocate(.arena(layer));layer += 1
                guard allocation.address != 0 else { return nil }
                var context: Void = ()
                let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:optional,
                    backing:allocation.backing,device:device,flags:0x40,context:&context,perform:{ q,_ in try self.bitmap(q) })
                arena[allocation.address] = bitmap
                owners[nextOrdinal] = allocation.address;surfaceOwners[nextOrdinal] = self.surfaces[allocation.address];nextOrdinal += 1
                return bitmap
            },{ ordinal,bitmap in
                guard let wrapper = owners[ordinal],let allocation = current.allocations[wrapper],allocation.live,!released.contains(wrapper) else {
                    throw Boundary.dependency("Arena release wrapper owner")
                }
                let surface = try allocation.storage.integer(at:0,as:UInt32.self)
                var normalized = allocation.storage;try normalized.write(UInt32(surface == 0 ? 0 : 1),at:0)
                guard normalized == bitmap.storage else { throw Boundary.owner(wrapper) }
                var context: Void = ()
                try OriginalBitmapRelease.release(bitmap,wrapper:wrapper,surface:surface,context:&context,perform:{ q,_ in
                    if q.kind == "free" { try self.emit(.free(wrapper));return .init() }
                    return try self.bitmap(q)
                })
                released.append(wrapper)
            })
            for wrapper in released { owned.allocations[wrapper]?.live = false }
            try adopted(arena,in:&owned)
            scene.bitmapOwners = owners;scene.bitmapSurfaceOwners = surfaceOwners
        }
        func localTime() throws -> OriginalLocalTime {
            guard let localTimeReply else { throw Boundary.dependency("Local time provider") }
            let time = try localTimeReply(&environment);operations.append(.localTime(time));return time
        }
        func allocateRecording(_ count: Int) throws -> UInt32 {
            guard let replayReply else { throw Boundary.dependency("Recording allocation provider") }
            let address = try replayReply(count,&environment)
            try claim(address,count);operations.append(.recordingAllocation(address,count))
            return address
        }
        /// A preparation's recording free and sounds (the Tournament's computer
        /// join, 0x45560c) go to the front; its other events are internal.
        /// Unknown kinds stay boundaries.
        func preparationEvent(_ e: OriginalFrontScreenEvent,_ name: String) throws {
            switch e.kind {
            case "free":
                guard e.arguments.count == 1 else { throw Boundary.dependency("Recording free") }
                try front(.init("free",[e.arguments[0]]))
            case "soundRequest","soundMethod":try front(e)
            case "localTime","format","releaseLayers","loadLayers","reconstruct","resetInput","replayEntry","calloc","random","candidates":break
            default:throw Boundary.dependency(name+" event "+e.kind)
            }
        }
        func warStart(_ scene: inout OriginalMatchPreparation,_ owned: inout OriginalMenuPresentationMemory,
                      _ musicOwner: inout OriginalMusicMemory) throws {
            guard localTimeReply != nil,replayReply != nil else { throw Boundary.dependency("War start providers") }
            try stagedArena(&scene,&owned) { scene,owned,construct,release in
                try OriginalWarPreparation.prepare(state:&scene,memory:&owned,localTime:localTime,
                    constructBitmap:{ path,optional,_ in try construct(path,optional) },releaseBitmap:release,
                    resumeMusic:{ globals in
                        try OriginalMusicPlayback.resumeMatch(globals:&globals,memory:&musicOwner,request:self.music)
                    },allocateReplay:allocateRecording,observe:{ try preparationEvent($0,"War start") })
            }
        }
        /// Tournament 434349..4347c5 or Team Tournament 436747..436afd, called by
        /// the bracket (menus 26..29 / 126..129) with the same owners as War.
        /// Their contract has no null arena allocation: that is a boundary.
        func bracketStart(_ scene: inout OriginalMatchPreparation,_ owned: inout OriginalMenuPresentationMemory,team: Bool) throws {
            guard localTimeReply != nil,replayReply != nil else { throw Boundary.dependency("Tournament start providers") }
            try stagedArena(&scene,&owned) { scene,owned,construct,release in
                let constructBitmap: (String,Bool,[UInt8]) throws -> OriginalLoadedBitmap = { path,optional,_ in
                    guard let bitmap = try construct(path,optional) else { throw Boundary.dependency("Tournament arena allocation") }
                    return bitmap
                }
                if team {
                    try OriginalTeamTournamentPreparation.prepare(state:&scene,memory:&owned,localTime:localTime,constructBitmap:constructBitmap,
                        releaseBitmap:release,allocateReplay:allocateRecording,observe:{ try preparationEvent($0,"Team Tournament start") })
                } else {
                    try OriginalTournamentPreparation.prepare(state:&scene,memory:&owned,localTime:localTime,constructBitmap:constructBitmap,
                        releaseBitmap:release,allocateReplay:allocateRecording,observe:{ try preparationEvent($0,"Tournament start") })
                }
            }
        }
        /// 43249c..4328cc: input reset, Sleep(300), GetOpenFileNameA, the previous
        /// playback buffer freed (43d280), `.txt` through ShellExecuteA, the loader
        /// 43e620, the playback start 43dfa0 with this session's arena/music owners,
        /// and its checks. Messages go to MessageBoxA. The mode screen then
        /// continues its own tail.
        func playbackBranch(_ globals: inout OriginalStateRecord,_ owned: inout OriginalMenuPresentationMemory,
                            _ musicOwner: inout OriginalMusicMemory,_ services: PlaybackServices<E>) throws {
            var scene = model;scene.globals = globals
            func done() { globals = scene.globals;model = scene }
            try scene.resetOriginalInput()
            try front(.init("sleep",[300]))
            guard let path = try services.choose(&environment) else { return done() }
            // 43d280(4588ac): free a previous playback buffer.
            let old = try owned.replayPointers.integer(at: 4,as: UInt32.self)
            if old != 0 {
                guard var allocation = owned.allocations[old],allocation.live else { throw Boundary.owner(old) }
                try front(.init("free",[old]));allocation.live = false;owned.allocations[old] = allocation
                try owned.replayPointers.write(UInt32(0),at: 4)
            }
            let name = Array(path.utf8)
            if name.count > 4 && name[name.count-4] == 0x2e && [0x74,0x54].contains(name[name.count-3])
                && [0x78,0x58].contains(name[name.count-2]) && [0x74,0x54].contains(name[name.count-1]) {
                try services.open(path,&environment);return done()
            }
            let file = try services.read(path,&environment)
            let loaded = try OriginalReplayFileInput.load(file: file,globals: &scene.globals)
            guard loaded.status == 1,let bytes = loaded.recording else {
                if let message = OriginalReplayPlayback.loaderMessage(loaded.status) { try services.alert(message,&environment) }
                return done()
            }
            guard let replayReply else { throw Boundary.dependency("Playback buffer allocation") }
            let address = try replayReply(bytes.count,&environment)
            try claim(address,bytes.count);operations.append(.recordingAllocation(address,bytes.count))
            try owned.replayPointers.write(address,at: 4)
            var recording = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count))
            var saved = savedPlayback ?? entry.inputContext.savedPlayback
            let device = try scene.globals.integer(at: 0x457578-0x44d000,as: UInt32.self)
            var owners = scene.bitmapOwners,surfaceOwners = scene.bitmapSurfaceOwners
            var nextOrdinal = scene.bitmaps.count,layer = 0
            scene.releasedBitmapOrder = []
            try OriginalReplayPlayback.prepare(state: &scene,recording: &recording,saved: &saved,releaseLayers: { index,s in
                s.releasedBitmapOrder += try s.backgroundLoader.releaseLayersWithSurface(in: &s.backgrounds[index]) { ordinal,bitmap in
                    guard let wrapper = owners[ordinal],var allocation = owned.allocations[wrapper],allocation.live else {
                        throw Boundary.dependency("Arena release wrapper owner")
                    }
                    let surface = try allocation.storage.integer(at: 0,as: UInt32.self)
                    var normalized = allocation.storage;try normalized.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                    guard normalized == bitmap.storage else { throw Boundary.owner(wrapper) }
                    var context: Void = ()
                    try OriginalBitmapRelease.release(bitmap,wrapper: wrapper,surface: surface,context: &context,perform: { q,_ in
                        if q.kind == "free" { try self.emit(.free(wrapper));return .init() }
                        return try self.bitmap(q)
                    })
                    allocation.live = false;owned.allocations[wrapper] = allocation
                }
            },loadLayers: { index,s in
                try s.backgroundLoader.loadLayersWithSurface(in: &s.backgrounds[index]) { path,optional,_ in
                    let allocation = try self.allocate(.arena(layer));layer += 1
                    guard allocation.address != 0 else { return nil }
                    var context: Void = ()
                    let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path: path,optional: optional,
                        backing: allocation.backing,device: device,flags: 0x40,context: &context,perform: { q,_ in try self.bitmap(q) })
                    try self.adopted([allocation.address:bitmap],in: &owned)
                    owners[nextOrdinal] = allocation.address;surfaceOwners[nextOrdinal] = self.surfaces[allocation.address];nextOrdinal += 1
                    return bitmap
                }
            },playMusic: { s in
                try OriginalMusicPlayback.resumeMatch(globals: &s.globals,memory: &musicOwner,request: self.music)
            })
            scene.bitmapOwners = owners;scene.bitmapSurfaceOwners = surfaceOwners
            owned.allocations[address] = .init(storage: recording)
            savedPlayback = saved
            if case .rejected(let message) = try OriginalReplayPlayback.start(recording: recording,globals: &scene.globals) {
                try services.alert(message,&environment)
            }
            done()
        }
        func run() throws -> Outcome {
            var dummy: Void = ()
            var globals = model.globals,world = model.world,owned = state.memory,text = state.libraryText,scratch = local
            var musicOwner = audio,images = resources
            let startup = try OriginalCharacterMenuStartup.runWithSurfaceLoading(globals:&globals,music:&musicOwner,resources:&images,environment:&dummy,
                musicRequest:{ e,_ in try self.music(e) },allocate:{ i,_ in try self.allocate(.menu(i)) },perform:{ q,_ in try self.bitmap(q) },
                afterMusic:{ _,g,_,_ in try self.checkpoint("music",g,&self.environment) },
                checkpoint:{ p,g,b,_ in
                    try self.observe(.resourceCheckpoint(p,g,b),&self.environment)
                    try self.checkpoint("resource.\(p.kind.rawValue).\(p.index)",g,&self.environment)
                },observe:{ e,_ in try self.observe(.resource(e),&self.environment) })
            // Cached constructors are historical; current memory retains their live fields.
            try adopted(images.bitmaps.filter { surfaces[$0.key] != nil },in:&owned)
            try checkpoint("startup",globals,&environment)
            let end: OriginalModeScreenExit
            if try OriginalModeScreen.selectsModeScreen(globals:&globals) {
                end = try OriginalModeScreen.advanceWithLibraryPanel(world:world,actors:model.actors,globals:&globals,memory:&owned,
                local:&scratch,libraryText:&text,worldAddress:0x458b00,target:target,input:screenInput,fillBacking:[UInt8](repeating:0,count:100),
                background:{ g,m in
                    let result = try OriginalMenuBackground.load(globals:&g,milliseconds:self.milliseconds(),allocate:{ try self.allocate(.background) },source:{ _ in throw Boundary.dependency("Background source") },constructBitmap:{ a,device,path in
                        var context: Void = ()
                        let b = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:false,backing:a.backing,device:device,flags:0x40,context:&context,perform:{ q,_ in try self.bitmap(q) })
                        let surface = try b.storage.integer(at:0,as:UInt32.self) == 0 ? 0 : self.surfaces[a.address] ?? 0
                        return (b,surface)
                    },observe:self.front)
                    if let b = result.bitmap { self.backgrounds[result.address] = b;try self.adopted([result.address:b],in:&m) }
                },update:{ g in
                    _ = try OriginalMenuPanelUpdate.run(globals:&g,content:{ _ in throw Boundary.dependency("Panel content IO") },bitmap:{ _ in throw Boundary.dependency("Panel bitmap IO") },write:{ _,_ in throw Boundary.dependency("Panel write IO") },observe:{ e,_ in try self.front(.init(e.kind,e.arguments)) })
                },milliseconds:milliseconds,draw:draw,playback:playback.map { services in { g,m in
                    try self.playbackBranch(&g,&m,&musicOwner,services)
                } },observe:front)
                // A playback start rebuilt the World and Actors in the model.
                world = model.world
            } else {
                var character = model
                character.globals = globals;character.world = world
                var selectionLocals: [Int:Int32] = [:]
                var confirmation: Int32?
                // Demo start (42d789): arena layers with this session's owners,
                // the configured track through 4025b0 and 4025d0's declared ECX.
                var demoOwners = character.bitmapOwners,demoSurfaceOwners = character.bitmapSurfaceOwners
                var demoNext = character.bitmaps.count,demoLayer = 0,demoUsed = false
                let device = try globals.integer(at:0x457578-0x44d000,as:UInt32.self)
                let demo = demoMusicTrack.map { track in OriginalDemoStartProviders(musicTrack:track,playMusic:{ g in
                    try OriginalMusicPlayback.resumeMatch(globals:&g,memory:&musicOwner,request:self.music)
                },constructBitmap:{ path,optional,_ in
                    demoUsed = true
                    let allocation = try self.allocate(.arena(demoLayer));demoLayer += 1
                    guard allocation.address != 0 else { return nil }
                    var context: Void = ()
                    let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:optional,
                        backing:allocation.backing,device:device,flags:0x40,context:&context,perform:{ q,_ in try self.bitmap(q) })
                    try self.adopted([allocation.address:bitmap],in:&owned)
                    demoOwners[demoNext] = allocation.address;demoSurfaceOwners[demoNext] = self.surfaces[allocation.address];demoNext += 1
                    return bitmap
                },releaseBitmap:{ ordinal,bitmap in
                    demoUsed = true
                    guard let wrapper = demoOwners[ordinal],var allocation = owned.allocations[wrapper],allocation.live else {
                        throw Boundary.dependency("Arena release wrapper owner")
                    }
                    let surface = try allocation.storage.integer(at:0,as:UInt32.self)
                    var normalized = allocation.storage;try normalized.write(UInt32(surface == 0 ? 0 : 1),at:0)
                    guard normalized == bitmap.storage else { throw Boundary.owner(wrapper) }
                    var context: Void = ()
                    try OriginalBitmapRelease.release(bitmap,wrapper:wrapper,surface:surface,context:&context,perform:{ q,_ in
                        if q.kind == "free" { try self.emit(.free(wrapper));return .init() }
                        return try self.bitmap(q)
                    })
                    allocation.live = false;owned.allocations[wrapper] = allocation
                }) }
                let result = try OriginalMatchSelection.advanceWithLibrary(state:&character,libraryText:&text,
                    selectionAtEntry:startup.resources.selectionAtEntry,target:target,input:screenInput,
                    fillBacking:{ [UInt8](repeating:0,count:100) },
                    draw:{ request,g in try self.characterDraw(request,g,owned) },observe:front,
                    checkpoint:{ point,current in
                        selectionLocals = point.locals
                        try self.observe(.characterCheckpoint(point,current),&self.environment)
                    },tournamentStage:{ scene,locals,library,initialize in
                        try OriginalTournamentBracket.advance(state:&scene,locals:&locals,libraryText:&library,initialize:initialize,
                            target:self.target,fillBacking:[UInt8](repeating:0,count:100),
                            resumeMusic:{ g in try OriginalMusicPlayback.resumeMatch(globals:&g,memory:&musicOwner,request:self.music) },
                            prepare:{ value in try self.bracketStart(&value,&owned,team:false);return true },
                            draw:{ request,g in try self.characterDraw(request,g,owned) },observe:front,
                            checkpoint:{ point,current in
                                selectionLocals = point.locals
                                try self.observe(.characterCheckpoint(point,current),&self.environment)
                            })
                    },teamTournamentStage:{ scene,locals,library,initialize in
                        try OriginalTeamTournamentBracket.advance(state:&scene,locals:&locals,libraryText:&library,initialize:initialize,
                            target:self.target,fillBacking:[UInt8](repeating:0,count:100),
                            resumeMusic:{ g in try OriginalMusicPlayback.resumeMatch(globals:&g,memory:&musicOwner,request:self.music) },
                            prepare:{ value in try self.bracketStart(&value,&owned,team:true);return true },
                            draw:{ request,g in try self.characterDraw(request,g,owned) },observe:front,
                            checkpoint:{ point,current in
                                selectionLocals = point.locals
                                try self.observe(.characterCheckpoint(point,current),&self.environment)
                            })
                    },warStage:{ scene,library in
                        try self.war(&scene,&library,&owned,&musicOwner)
                    },demo:demo,matchPrelude:{ confirmation = $0 })
                if demoUsed { character.bitmapOwners = demoOwners;character.bitmapSurfaceOwners = demoSurfaceOwners }
                model = character;world = character.world;globals = character.globals
                if result == .matchPrelude {
                    guard let confirmation else { throw Boundary.dependency("Selection confirmation owner") }
                    state.memory = owned;state.libraryText = text
                    local = scratch;audio = musicOwner;resources = images
                    try checkpoint("matchPrelude",globals,&environment)
                    return .matchPrelude(.init(entry:entry,snapshot:try snapshot(globals,audio,resources),confirmation:confirmation,locals:selectionLocals,graphics:graphics))
                }
                guard result == .returned else { throw Boundary.dependency("Character continuation "+result.rawValue) }
                end = .returned
            }
            try checkpoint("screen",globals,&environment)
            var dispatcher: Int32?
            if end == .returned {
                outputPhase = true
                try OriginalMenuReturn.advanceWithLibrary(world:&world,globals:&globals,memory:&owned,libraryText:&text,
                    input:outputInput,milliseconds:0,fillBacking:[UInt8](repeating:0,count:100),wholeEarlyReturn:true,readMilliseconds:milliseconds,
                    draw:draw,observe:front,checkpoint:{ name,w,g in
                        try self.checkpoint(name,g,&self.environment)
                    })

            }
            model.world = world;model.globals = globals;state.memory = owned;state.libraryText = text
            // War start (43a21f) replaces the recording pointer 4588a8.
            try state.replace(0xb8a8,owned.replayPointers)
            local = scratch;audio = musicOwner;resources = images
            let final = try snapshot(globals,audio,resources)
            if end == .returned { dispatcher = try OriginalApplicationDispatchEntry.finishWorldCall(globals:final.state.full) }
            return .returned(.init(entry:entry,snapshot:final,exit:end,dispatcherResult:dispatcher,graphics:graphics))
        }
    }
}
