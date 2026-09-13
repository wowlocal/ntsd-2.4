/// Continue the exact Start child retained by the owned application. Prelude,
/// bundled-library preparation, music, arena surfaces and recording share its
/// current owners. The enclosing Bootstrap still owns final platform publication.
public struct OriginalApplicationMatchLaunchSession {
    public typealias Menu = OriginalApplicationLoadedMenuSession
    public typealias API = OriginalBitmapSurfaceLoading
    public let entry: Menu.PendingMatchPrelude
    public private(set) var pendingReturn: Menu.PendingReturn?

    public init(pending: Menu.PendingMatchPrelude) throws {
        try pending.snapshot.state.validateAliases()
        guard pending.snapshot.match.libraryCommands != nil else {
            throw Menu.Boundary.dependency("Installed preparation library owner")
        }
        entry = pending
    }

    /// Environment must value-own buffered effects and responses. A throw at
    /// any child or final checkpoint keeps both this session and it unchanged.
    @discardableResult
    public mutating func advance<Environment>(environment: inout Environment,
        bitmaps: [String:OriginalApplicationStartupInputs.Bitmap] = [:],
        outputInput: OriginalMenuPresentationInput,methodResult: Int32 = 0,
        allocateBitmap: @escaping (Int,Int,inout Environment) throws -> OriginalInterfaceAllocation,
        bitmap: @escaping (API.Request,inout Environment) throws -> API.Response,
        localTime: @escaping (inout Environment) throws -> OriginalLocalTime,
        music: @escaping (OriginalMusicEvent,inout Environment) throws -> OriginalMusicResponse,
        allocateReplay: @escaping (Int,inout Environment) throws -> UInt32,
        milliseconds: @escaping (inout Environment) throws -> UInt32,
        observe: @escaping (Menu.Observation,inout Environment) throws -> Void = { _,_ in },
        beforeCommit: (Menu.PendingReturn,inout Environment) throws -> Void = { _,_ in }) throws -> Menu.PendingReturn {
        guard pendingReturn == nil else { throw Menu.Boundary.alreadyPrepared }
        let attempt = try Menu.Attempt(entry.entry,.init(bitmaps:bitmaps),environment,
            .init(dcResult:outputInput.dcResult,dc:outputInput.dc,methodResult:methodResult,drawResults:[methodResult],shellResult:33),
            outputInput,{ kind,count,env in
                guard case .arena(let index) = kind else { throw Menu.Boundary.dependency("Launch bitmap allocation kind") }
                return try allocateBitmap(index,count,&env)
            },bitmap,music,milliseconds,observe,{ _,_,_ in },resuming:entry)
        let result = try attempt.launch(entry,localTime:localTime,allocateReplay:allocateReplay)
        try beforeCommit(result,&attempt.environment)
        pendingReturn = result;environment = attempt.environment;return result
    }
}

extension OriginalApplicationLoadedMenuSession.Attempt {
    private func launchPoint(_ name: String) throws {
        try observe(.launchCheckpoint(name,snapshot(model.globals,audio,resources)),&environment)
    }

    private func prelude(_ event: OriginalMatchPreludeEvent) throws {
        switch event {
        case .localTime:break
        case .soundRequest(let loop):try front(.init("soundRequest",[loop ? 1 : 0]))
        case .soundMethod(let resource,let offset,let arguments):
            try front(.init("soundMethod",[resource,UInt32(offset)]+arguments))
        case .fillRectangle(let resource,let x,let y,let width,let height,let color):
            var e = OriginalFrontScreenEvent("fill")
            e.fill = try OriginalSurfaceFilling.request(target:resource,x:x,y:y,width:width,height:height,color:color,
                backing:[UInt8](repeating:0,count:100))
            try front(e)
        }
        try observe(.prelude(event),&environment)
    }

    func launch(_ pending: OriginalApplicationLoadedMenuSession.PendingMatchPrelude,
        localTime: @escaping (inout E) throws -> OriginalLocalTime,
        allocateReplay: @escaping (Int,inout E) throws -> UInt32) throws -> OriginalApplicationLoadedMenuSession.PendingReturn {
        typealias Boundary = OriginalApplicationLoadedMenuSession.Boundary
        try launchPoint("entry")
        var globals = model.globals
        _ = try OriginalMatchPrelude.apply(globals:&globals,readLocalTime:{
            let time = try localTime(&self.environment);self.operations.append(.localTime(time));return time
        },observe:prelude)
        model.globals = globals;try launchPoint("prelude")

        var prepared = model,library = model.libraryCommands!
        var owners = model.bitmapOwners,nextOrdinal = model.bitmaps.count,layer = 0
        let mode = try model.globals.integer(at:0x451160-0x44d000,as:Int32.self)
        try prepared.prepareUsingBundledLibrary(mode:mode,library:&library,
            constructBitmap:{ path,optional,_ in
                let allocation = try self.allocate(.arena(layer));layer += 1
                guard allocation.address != 0 else { return nil }
                var context: Void = ()
                let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:optional,
                    backing:allocation.backing,device:self.model.globals.integer(at:0x457578-0x44d000,as:UInt32.self),
                    flags:0x40,context:&context,perform:{ q,_ in try self.bitmap(q) })
                try self.adopted([allocation.address:bitmap],in:&self.state.memory)
                owners[nextOrdinal] = allocation.address;nextOrdinal += 1
                return bitmap
            },releaseBitmap:{ ordinal,bitmap in
                guard let wrapper = owners[ordinal],var allocation = self.state.memory.allocations[wrapper],allocation.live else {
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
                allocation.live = false;self.state.memory.allocations[wrapper] = allocation
            },music:{ scene in
                scene.bitmapOwners = owners;self.model = scene
                try self.launchPoint("preparation")
                var musicGlobals = scene.globals,memory = self.audio
                try OriginalMusicPlayback.resumeMatch(globals:&musicGlobals,memory:&memory,request:self.music)
                scene.globals = musicGlobals;self.model = scene;self.audio = memory
                try self.launchPoint("music")
            },observe:{ event in try self.observe(.preparation(event),&self.environment) })
        prepared.libraryCommands = library;prepared.bitmapOwners = owners;model = prepared
        try launchPoint("tail")

        // Recording replaces only4588a8. Playback and every other allocation
        // remain owned by the same memory. Free precedes the new calloc request.
        let old = try state.memory.replayPointers.integer(at:0,as:UInt32.self)
        if old != 0 {
            guard var allocation = state.memory.allocations[old],allocation.live else { throw Boundary.owner(old) }
            try front(.init("free",[old]));allocation.live = false;state.memory.allocations[old] = allocation
            try state.memory.replayPointers.write(UInt32(0),at:0)
            try state.replace(0xb8a8,state.memory.replayPointers)
        }
        var writer = OriginalReplayRecording(),recorded = model,address: UInt32 = 0
        try writer.begin(mode:mode,state:&recorded) { event in
            guard case .allocate(_,let bytes) = event else { throw Boundary.dependency("Recording allocation") }
            address = try allocateReplay(bytes,&self.environment);try self.claim(address,bytes)
            self.operations.append(.recordingAllocation(address,bytes))
            try self.state.memory.replayPointers.write(address,at:0)
            try self.state.replace(0xb8a8,self.state.memory.replayPointers)
        }
        guard let buffer = writer.buffer else { throw Boundary.dependency("Recording buffer") }
        state.memory.allocations[address] = .init(storage:buffer);model = recorded
        try launchPoint("recording")
        try model.continueMenu(confirmation:pending.confirmation,
            bitmapSource:{ _ in throw Boundary.dependency("Remaining menu surface continuation") },observe:{ event in
                switch event {
                case .device(let value):try self.prelude(value)
                case .state(let value):try self.observe(.preparation(value),&self.environment)
                case .musicSelection,.candidates:throw Boundary.dependency("Remaining menu selection continuation")
                }
            })
        try launchPoint("menu")
        outputPhase = true
        var world = model.world,returnGlobals = model.globals,memory = state.memory,text = state.libraryText
        try OriginalMenuReturn.advanceWithLibrary(world:&world,globals:&returnGlobals,memory:&memory,libraryText:&text,
            input:outputInput,milliseconds:0,fillBacking:[UInt8](repeating:0,count:100),wholeEarlyReturn:true,
            readMilliseconds:milliseconds,draw:draw,observe:front,ownedCheckpoint:{ name,w,g,m,t in
                var current = self.model;current.world = w;current.globals = g
                self.model = current;self.state.memory = m;self.state.libraryText = t
                try self.launchPoint(name)
            })
        model.world = world;model.globals = returnGlobals;state.memory = memory;state.libraryText = text
        let final = try snapshot(model.globals,audio,resources)
        let result = try OriginalApplicationDispatchEntry.finishWorldCall(globals:final.state.full)
        return .init(entry:entry,snapshot:final,exit:.returned,dispatcherResult:result,graphics:graphics)
    }
}
