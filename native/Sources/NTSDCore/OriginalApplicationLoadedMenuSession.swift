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
    public enum AllocationKind: Equatable { case menu(Int), background }
    public enum Operation: Equatable {
        case preceding(Input.Operation), menu(Session.Effect)
        case music(OriginalMusicEvent,OriginalMusicResponse)
        case front(OriginalFrontScreenEvent,Int32,UInt32?)
        case clock(UInt32), loop(Session.Loop.Request,Session.Loop.Response)
    }
    public enum Observation {
        case music(OriginalMusicEvent,OriginalMusicResponse), bitmap(API.Request,API.Response)
        case resource(OriginalInterfaceEvent), front(OriginalFrontScreenEvent)
        case resourceCheckpoint(OriginalMenuResourceCheckpoint,OriginalStateRecord,[UInt32:OriginalLoadedBitmap])
        case characterCheckpoint(OriginalCharacterScreenCheckpoint,OriginalMatchPreparation)
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
        public let locals: [Int:Int32]
        public let graphics: [OriginalApplicationGraphics.Command]
        public var loading: Session.PendingLoading { entry.loading }
    }
    public enum Outcome {
        case returned(PendingReturn), matchPrelude(PendingMatchPrelude)
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
        let a = try Attempt(entry,inputs,environment,screenInput,outputInput,allocate,bitmap,music,milliseconds,observe,checkpoint)
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
        beforeCommit: (Outcome,inout Environment) throws -> Void = { _,_ in }) throws -> Outcome {
        guard pendingReturn == nil,pendingMatchPrelude == nil else { throw Boundary.alreadyPrepared }
        let a = try Attempt(entry,inputs,environment,screenInput,outputInput,allocate,bitmap,music,milliseconds,observe,checkpoint)
        let result = try a.run()
        try beforeCommit(result,&a.environment)
        switch result {
        case .returned(let value):pendingReturn = value
        case .matchPrelude(let value):pendingMatchPrelude = value
        }
        environment = a.environment;return result
    }
    private final class Attempt<E> {
        let entry: Input.PendingContinuation,bindings: OriginalApplicationMatchBindings
        let screenInput: OriginalFrontScreenBodyInput,outputInput: OriginalMenuPresentationInput
        let allocation: (AllocationKind,Int,inout E) throws -> OriginalInterfaceAllocation
        let bitmapReply: (API.Request,inout E) throws -> API.Response
        let musicReply: (OriginalMusicEvent,inout E) throws -> OriginalMusicResponse
        let clock: (inout E) throws -> UInt32
        let observe: (Observation,inout E) throws -> Void,checkpoint: (String,OriginalStateRecord,inout E) throws -> Void
        var environment: E,state: State,model: OriginalMatchPreparation
        var audio: OriginalMusicMemory,resources = OriginalMenuResourceLoading()
        var backgrounds: [UInt32:OriginalLoadedBitmap] = [:]
        var local: OriginalStateRecord,operations: [Operation],graphics: [OriginalApplicationGraphics.Command]
        var ranges: [(UInt64,UInt64)] = [],surfaces: [UInt32:UInt32] = [:],current: UInt32?,outputPhase = false
        var target: UInt32 { entry.loading.target }
        init(_ entry: Input.PendingContinuation,_ inputs: OriginalApplicationMenuInputs,_ env: E,
             _ screen: OriginalFrontScreenBodyInput,_ output: OriginalMenuPresentationInput,
             _ allocate: @escaping (AllocationKind,Int,inout E) throws -> OriginalInterfaceAllocation,
             _ bitmap: @escaping (API.Request,inout E) throws -> API.Response,
             _ music: @escaping (OriginalMusicEvent,inout E) throws -> OriginalMusicResponse,
             _ time: @escaping (inout E) throws -> UInt32,
             _ observe: @escaping (Observation,inout E) throws -> Void,
             _ checkpoint: @escaping (String,OriginalStateRecord,inout E) throws -> Void) throws {
            self.entry = entry;environment = env;state = entry.state;model = entry.match;audio = entry.music
            resources = entry.menuResources;backgrounds = entry.menuBackgrounds
            bindings = try .init(pending:entry.entry);screenInput = screen;outputInput = output
            allocation = allocate;bitmapReply = bitmap;musicReply = music;clock = time
            self.observe = observe;self.checkpoint = checkpoint
            operations = entry.operations.map(Operation.preceding);graphics = entry.graphics
            local = try .init(bytes:[UInt8](repeating:0,count:0x704),defined:[Bool](repeating:false,count:0x704))
            guard screen.drawResults.count == 1 else { throw Boundary.dependency("Single menu draw response") }
            guard output.targetSurface == entry.loading.target else { throw Boundary.dependency("Menu target") }
            guard var images = state.bitmapInputs else { throw Boundary.dependency("Bitmap inputs") }
            try images.addResources(inputs.bitmaps);state.bitmapInputs = images
            reserve(0x44d000,state.full.bytes.count)
            for (token,a) in state.memory.allocations where a.live { reserve(token,a.storage.bytes.count) }
            let catalog = entry.entry.entry
            for a in catalog.snapshot.allocations { reserve(a.token,a.count) }
            for f in catalog.files.streams.values { reserve(f.allocation.buffer,f.allocation.capacity) }
            for (a,p) in zip(catalog.startup.owner.loads,catalog.startup.platforms) { retain(a,p) }
            for (a,p) in zip(catalog.entry.common.sounds,catalog.entry.waveInputs) { retain(a,p) }
            for (i,p) in catalog.snapshot.waveInputs.enumerated() {
                guard let a = catalog.snapshot.sounds.buffers[i] else { throw Boundary.dependency("WAV owner") };retain(a,p)
            }
            for (token,record) in audio.allocations { reserve(token,record.bytes.count) }
        }
        func reserve(_ token: UInt32,_ count: Int) { if token != 0 && count > 0 { ranges.append((UInt64(token),UInt64(token)+UInt64(count))) } }
        func retain(_ a: OriginalWaveLoadResult,_ p: OriginalWavePlatform) {
            reserve(p.firstPointer,a.first.bytes.count);if let b = a.second { reserve(p.secondPointer,b.bytes.count) }
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
            case "write","read","clip","draw","text","stringLength","soundRequest","format","panel","keyName","timer","call","return","allocate","construct","candidates","random","musicConfiguration","stopMusic":break
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
                // The current match owns the bitmap bytes. The original pool
                // parent supplies only the stable ordinal/token/surface binding.
                let catalog = entry.entry.entry.snapshot
                guard model.bitmaps.indices.contains(index),catalog.bitmapTokens.indices.contains(index),
                      catalog.bitmapSurfaces.indices.contains(index) else { throw Boundary.dependency("Catalog bitmap binding") }
                let bitmap = model.bitmaps[index].storage,token = catalog.bitmapTokens[index]
                let surface = try bitmap.integer(at:0,as:UInt32.self) == 0 ? 0 : catalog.bitmapSurfaces[index]
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
                },milliseconds:milliseconds,draw:draw,observe:front)
            } else {
                var character = model
                character.globals = globals;character.world = world
                var selectionLocals: [Int:Int32] = [:]
                let result = try OriginalMatchSelection.advanceWithLibrary(state:&character,libraryText:&text,
                    selectionAtEntry:startup.resources.selectionAtEntry,target:target,input:screenInput,
                    fillBacking:{ [UInt8](repeating:0,count:100) },
                    draw:{ request,g in try self.characterDraw(request,g,owned) },observe:front,
                    checkpoint:{ point,current in
                        selectionLocals = point.locals
                        try self.observe(.characterCheckpoint(point,current),&self.environment)
                    })
                model = character;world = character.world;globals = character.globals
                if result == .matchPrelude {
                    state.memory = owned;state.libraryText = text
                    local = scratch;audio = musicOwner;resources = images
                    try checkpoint("matchPrelude",globals,&environment)
                    return .matchPrelude(.init(entry:entry,snapshot:try snapshot(globals,audio,resources),locals:selectionLocals,graphics:graphics))
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
            local = scratch;audio = musicOwner;resources = images
            let final = try snapshot(globals,audio,resources)
            if end == .returned { dispatcher = try OriginalApplicationDispatchEntry.finishWorldCall(globals:final.state.full) }
            return .returned(.init(entry:entry,snapshot:final,exit:end,dispatcherResult:dispatcher,graphics:graphics))
        }
    }
}
