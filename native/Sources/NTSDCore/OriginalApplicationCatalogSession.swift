/// Production composition of the original catalog and its existing children.
/// Immutable platform controls are consumed inside one tentative attempt. There
/// is no prefix length or captured state in the runtime contract; an observer
/// cancellation publishes neither a catalog nor the enclosing menu iteration.
public struct OriginalApplicationCatalogSession {
    public typealias Session = OriginalApplicationMenuSession
    public typealias Loading = OriginalApplicationLoadingSession
    public typealias API = OriginalBitmapSurfaceLoading
    public enum Boundary: Error, Equatable {
        case alreadyPrepared, missingOwners, dependency(String), input(String), exhausted(String), overlap(UInt32)
    }
    /// Actual startup results, kept separately from the subsequent common and
    /// registered WAV owners. Platforms give logical PCM identities, not bytes.
    public struct StartupSounds {
        public let owner: OriginalMenuSoundStartup.Result, platforms: [OriginalWavePlatform]
        public init(owner: OriginalMenuSoundStartup.Result, platforms: [OriginalWavePlatform]) throws {
            guard owner.loads.count == platforms.count else { throw Boundary.input("Startup WAV owners") }
            self.owner = owner; self.platforms = platforms
        }
    }
    public struct MessageInput {
        public let name: String, response: OriginalLibLoadingProgress.MessageResponse
        public init(name: String, response: OriginalLibLoadingProgress.MessageResponse) {
            self.name = name; self.response = response
        }
    }
    public struct Inputs {
        public let files: [String:[UInt8]], bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
        /// Replies contain no expected sizes or captured structure writes.
        public let allocationTokens: [UInt32], bitmapReplies: [API.Response]
        public let fileAllocations: [OriginalLoadingFileAllocation], waves: [OriginalWavePlatform], times: [UInt32]
        public let volumeReplies: [Int32]
        public let messages: [MessageInput], presentation: OriginalMenuPresentationInput
        public let drawResult: Int32, graphicsResult: Int32, allocationFill: UInt8
        public init(files: [String:[UInt8]], bitmaps: [String:OriginalApplicationStartupInputs.Bitmap],
            allocationTokens: [UInt32], bitmapReplies: [API.Response], fileAllocations: [OriginalLoadingFileAllocation],
            waves: [OriginalWavePlatform], volumeReplies: [Int32], times: [UInt32], messages: [MessageInput],
            presentation: OriginalMenuPresentationInput, drawResult: Int32, graphicsResult: Int32, allocationFill: UInt8) throws {
            guard bitmapReplies.allSatisfy({ $0.writes.isEmpty }), files[OriginalLoadingFiles.temporaryPath] == nil else {
                throw Boundary.input("Captured bitmap writes or external temporary file")
            }
            self.files = files; self.bitmaps = bitmaps; self.allocationTokens = allocationTokens
            self.bitmapReplies = bitmapReplies; self.fileAllocations = fileAllocations; self.waves = waves
            self.volumeReplies = volumeReplies
            self.times = times; self.messages = messages; self.presentation = presentation
            self.drawResult = drawResult; self.graphicsResult = graphicsResult; self.allocationFill = allocationFill
        }
    }
    public struct Allocation: Equatable {
        public enum Kind: Equatable { case catalog, object, bitmap, frame(OriginalFrameAllocationKind), weapon(Int) }
        public let kind: Kind, token: UInt32, count: Int
    }
    public struct GlobalStore: Equatable {
        public let address: Int, bytes: [UInt8]
    }
    public enum Observation {
        case allocation(Allocation), catalogEntry(UInt32,String,UInt32), request(OriginalCatalogLoadRequest)
        case parentStore(OriginalCatalogRegistry.Store), globalStore(GlobalStore)
        case api(API.Request,API.Response), front(OriginalFrontScreenEvent), file(OriginalLoadingFileEvent)
        case wave(Int,OriginalWaveEvent), volume([UInt32],ignoredResult:Int32)
    }
    public enum Operation: Equatable {
        case preceding(Loading.Operation), menu(Session.Effect), allocation(Allocation)
        case file(OriginalLoadingFileEvent), wave(Int,OriginalWaveEvent), volume([UInt32],ignoredResult:Int32), clock(UInt32)
        case message(String,Int32,[UInt8])
    }
    public struct Snapshot {
        public let state: Session.State, parent: [Int:OriginalStateRecord], allocations: [Allocation]
        public let objectTokens: [UInt32], bitmapTokens: [UInt32], bitmapSurfaces: [UInt32]
        public let sounds: OriginalRegisteredSoundLoading, waveInputs: [OriginalWavePlatform]
        /// Actual semantic writes; this mask is not Native knowledge and does
        /// not claim original instruction widths, PC order or store counts.
        public let globalStores: [GlobalStore], observedGlobalWrites: [Bool]
        public let operations: [Operation], graphics: [OriginalApplicationGraphics.Command]
    }
    /// Full native catalog return only. Caller pool/UI/outer-loop work remains
    /// tentative and requires its own continuation before delivery to a backend.
    public struct PendingPool {
        public let entry: Loading.PendingCatalog, startup: StartupSounds, snapshot: Snapshot
        public let catalog: OriginalLoadedCatalog, files: OriginalLoadingFiles
    }
    public let entry: Loading.PendingCatalog, startup: StartupSounds
    public private(set) var pendingPool: PendingPool?
    public init(pending: Loading.PendingCatalog, startup: StartupSounds) throws {
        try pending.state.validateAliases()
        guard pending.state.bitmapInputs != nil, pending.state.graphics != nil,
              pending.common.sounds.count == pending.waveInputs.count else { throw Boundary.missingOwners }
        // The shared registry initializes its own ordinal count to zero. A
        // retained nonempty cache needs a separately recovered continuation.
        guard try pending.state.full.integer(at:0x458438-0x44d000,as:UInt32.self) == 0 else {
            throw Boundary.dependency("Nonempty initial registered-sound cache")
        }
        entry = pending; self.startup = startup
    }
    @discardableResult
    public mutating func load(inputs: Inputs,
        observe: @escaping (Observation,Session.State) throws -> Void = { _,_ in },
        afterChild: @escaping (OriginalCatalogChildObservation,Snapshot) throws -> Void = { _,_ in },
        beforeCommit: (PendingPool) throws -> Void = { _ in }) throws -> PendingPool {
        let resources = try Resources(files:inputs.files,bitmaps:inputs.bitmaps,presentation:inputs.presentation,
            drawResult:inputs.drawResult,graphicsResult:inputs.graphicsResult,allocationFill:inputs.allocationFill)
        return try load(resources:resources,makeControls:{ Self.fixedControls(inputs) },
                        observe:observe,afterChild:afterChild,beforeCommit:beforeCommit)
    }
    /// The factory creates fresh logical reply/cursor ownership for each attempt.
    /// No provider, catalog or enclosing timer iteration is published on error.
    @discardableResult
    public mutating func load(resources: Resources,makeControls: () throws -> Controls,
        observe: @escaping (Observation,Session.State) throws -> Void = { _,_ in },
        afterChild: @escaping (OriginalCatalogChildObservation,Snapshot) throws -> Void = { _,_ in },
        beforeCommit: (PendingPool) throws -> Void = { _ in }) throws -> PendingPool {
        guard pendingPool == nil else { throw Boundary.alreadyPrepared }
        let attempt = try Attempt(entry:entry,startup:startup,inputs:resources,controls:makeControls(),observe:observe,afterChild:afterChild)
        let loaded = try attempt.run()
        let result = PendingPool(entry:entry,startup:startup,snapshot:attempt.snapshot(),catalog:loaded.catalog,files:loaded.files)
        try beforeCommit(result)
        pendingPool = result
        return result
    }

    private final class Attempt {
        let entry: Loading.PendingCatalog, inputs: Resources
        let controls: Controls
        let observe: (Observation,Session.State) throws -> Void
        let afterChild: (OriginalCatalogChildObservation,Snapshot) throws -> Void
        var state: Session.State, parent: [Int:OriginalStateRecord] = [:], allocations: [Allocation] = []
        var objectTokens: [UInt32] = [], bitmapTokens: [UInt32] = [], bitmapSurfaces: [UInt32] = []
        var sounds = OriginalRegisteredSoundLoading(), waveInputs: [OriginalWavePlatform] = []
        var globalStores: [GlobalStore] = [], observedGlobalWrites: [Bool]
        var operations: [Operation], graphics: [OriginalApplicationGraphics.Command]
        var ranges: [(UInt64,UInt64)] = []
        var pendingSound: OriginalSoundRegistration?
        init(entry: Loading.PendingCatalog,startup: StartupSounds,inputs: Resources,controls: Controls,
            observe: @escaping (Observation,Session.State) throws -> Void,
            afterChild: @escaping (OriginalCatalogChildObservation,Snapshot) throws -> Void) throws {
            self.entry = entry; self.inputs = inputs; self.controls = controls; self.observe = observe; self.afterChild = afterChild
            state = entry.state; observedGlobalWrites = [Bool](repeating:false,count:state.full.bytes.count)
            operations = entry.stagedOperations.map(Operation.preceding); graphics = entry.stagedGraphics
            guard inputs.presentation.targetSurface == entry.target else { throw Boundary.input("Catalog presentation target") }
            guard var images = state.bitmapInputs else { throw Boundary.missingOwners }
            try images.addResources(inputs.bitmaps); state.bitmapInputs = images
            for (token,a) in state.memory.allocations where a.live {
                ranges.append((UInt64(token),UInt64(token)+UInt64(a.storage.bytes.count)))
            }
            let device = try word(0x44eecc)
            guard startup.owner.deviceReady,device != 0,
                  startup.owner.loads.count == OriginalMenuSoundStartup.paths.count else {
                throw Boundary.dependency("Startup sound ownership for catalog entry")
            }
            for (i,pair) in zip(startup.owner.loads,startup.platforms).enumerated() {
                let (owner,p) = pair
                guard p.destination == UInt32(0x45560c+4*i),p.device == device,
                      try word(Int(p.destination)) == owner.output else { throw Boundary.input("Startup WAV binding") }
                try retainWave(owner,p)
            }
            for (i,pair) in zip(entry.common.sounds,entry.waveInputs).enumerated() {
                let (owner,p) = pair
                guard p.destination == UInt32(0x451db0+4*i),p.device == device,
                      try word(Int(p.destination)) == owner.output else { throw Boundary.input("Common WAV binding") }
                try retainWave(owner,p)
            }
            for (region,count) in OriginalCatalogRegistry.regionSizes { parent[region] = try backing(count) }
        }
        func snapshot() -> Snapshot {
            .init(state:state,parent:parent,allocations:allocations,objectTokens:objectTokens,bitmapTokens:bitmapTokens,
                bitmapSurfaces:bitmapSurfaces,sounds:sounds,waveInputs:waveInputs,globalStores:globalStores,
                observedGlobalWrites:observedGlobalWrites,operations:operations,graphics:graphics)
        }
        func backing(_ count: Int) throws -> OriginalStateRecord {
            try .init(bytes:[UInt8](repeating:inputs.allocationFill,count:count),defined:[Bool](repeating:false,count:count))
        }
        func emit(_ event: Observation) throws { try observe(event,state) }
        func effect(_ effect: Session.Effect) throws {
            guard var owner = state.graphics else { throw Boundary.missingOwners }
            let command = try owner.consume(effect,inputs:state.bitmapInputs); state.graphics = owner
            if let command { graphics.append(command) }; operations.append(.menu(effect))
        }
        func word(_ address: Int) throws -> UInt32 { try state.full.integer(at:address-0x44d000,as:UInt32.self) }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
            let offset = address-0x44d000
            guard offset >= 0,offset <= state.full.bytes.count-bytes.count else { throw Boundary.input("Catalog global extent") }
            try state.replace(offset,.init(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count)))
            observedGlobalWrites.replaceSubrange(offset..<offset+bytes.count,with:repeatElement(true,count:bytes.count))
            let write = GlobalStore(address:address,bytes:bytes); globalStores.append(write); try emit(.globalStore(write))
        }
        func put(_ address: Int,_ value: UInt32) throws {
            try store(address,(0..<4).map { UInt8(truncatingIfNeeded:value >> ($0*8)) })
        }
        func range(_ token: UInt32,_ count: Int,checkingOverlap: Bool = true) throws {
            guard count >= 0 else { throw Boundary.input("Negative allocation size") }
            if count == 0 { return }
            let lo = UInt64(token), hi = lo+UInt64(count)
            guard token != 0, hi <= UInt64(UInt32.max)+1 else { throw Boundary.input("Logical allocation extent") }
            if checkingOverlap && ranges.contains(where:{ lo < $0.1 && $0.0 < hi }) { throw Boundary.overlap(token) }
            ranges.append((lo,hi))
        }
        func retainWave(_ owner: OriginalWaveLoadResult,_ p: OriginalWavePlatform) throws {
            guard owner.exit == .returned,owner.returned == 1,!owner.temporaryLive,
                  p.device != 0,p.buffer != 0,owner.output == p.buffer,owner.temporary != nil else {
                throw Boundary.dependency("WAV without established completed PCM ownership")
            }
            guard p.firstCount == owner.first.bytes.count, p.secondCount == (owner.second?.bytes.count ?? 0) else {
                throw Boundary.input("WAV PCM allocation provenance")
            }
            // Temporary WAV bytes have no declared address in WavePlatform.
            // They stay owned values, outside this logical address journal;
            // unresolved live temporaries above cannot authorize allocation.
            try range(p.firstPointer,owner.first.bytes.count)
            if let second = owner.second { try range(p.secondPointer,second.bytes.count) }
        }
        func allocate(_ kind: Allocation.Kind,_ count: Int) throws -> UInt32 {
            let token = try controls.allocate(kind,count)
            let a = Allocation(kind:kind,token:token,count:count)
            operations.append(.allocation(a)); allocations.append(a); try emit(.allocation(a))
            guard token != 0 else { throw Boundary.dependency("NULL catalog child allocation") }
            try range(token,count); return token
        }
        func parentStore(_ write: OriginalCatalogRegistry.Store) throws {
            var bytes = write.bytes
            switch write.binding {
            case .raw: break
            case .objectOrdinal(let index):
                guard objectTokens.indices.contains(index),bytes.count == 4 else { throw Boundary.input("Object pointer ordinal") }
                bytes = (0..<4).map { UInt8(truncatingIfNeeded:objectTokens[index] >> ($0*8)) }
            case .bitmapOrdinal(let index):
                guard bitmapTokens.indices.contains(index),bytes.count == 4 else { throw Boundary.input("Bitmap pointer ordinal") }
                bytes = (0..<4).map { UInt8(truncatingIfNeeded:bitmapTokens[index] >> ($0*8)) }
            }
            guard var region = parent[write.region] else { throw Boundary.input("Parent region") }
            for (i,byte) in bytes.enumerated() { try region.write(byte,at:write.offset+i) }
            parent[write.region] = region; try emit(.parentStore(write))
        }
        func file(_ path: String) throws -> [UInt8] {
            guard let bytes = inputs.files[path] else { throw Boundary.input("Missing original file: "+path) }; return bytes
        }
        func construct(_ path: String,_ optional: Bool,_ bytes: [UInt8]) throws -> OriginalLoadedBitmap {
            let token = try allocate(.bitmap,0x1f50); bitmapTokens.append(token)
            var context: Void = (), surface: UInt32 = 0
            let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:optional,backing:bytes,
                device:word(0x457578),flags:0x40,context:&context) { q,_ in
                let control = try self.controls.bitmap(q)
                guard control.writes.isEmpty else { throw Boundary.input("Captured bitmap writes") }
                guard var owner = self.state.bitmapInputs else { throw Boundary.missingOwners }
                let r = try owner.response(q,control:control); self.state.bitmapInputs = owner
                if q.kind == "createSurface",let output = r.output { surface = output }
                try self.effect(.bitmap(q,r)); try self.emit(.api(q,r)); return r
            }
            bitmapSurfaces.append(try bitmap.storage.integer(at:0,as:UInt32.self) == 0 ? 0 : surface)
            return bitmap
        }
        func time() throws -> UInt32 { try controls.time() }
        func message(_ name: String,_ bytes: [UInt8]) throws -> OriginalLibLoadingProgress.MessageResponse {
            let value = try controls.message(name,bytes)
            guard value.name == name else { throw Boundary.input("Message response order") }
            guard name == "PeekMessageA",value.response.result == 0,value.response.bytes.isEmpty else {
                throw Boundary.dependency("Nonempty loading message dispatch")
            }
            operations.append(.message(name,value.response.result,bytes)); return value.response
        }
        func front(_ event: OriginalFrontScreenEvent) throws {
            switch event.kind {
            case "stage": return
            case "timeGetTime":
                guard event.arguments.count == 1 else { throw Boundary.input("Clock event") }
                operations.append(.clock(event.arguments[0]))
            case "sleep":
                guard event.arguments.count == 1 else { throw Boundary.input("Sleep event") }
                try effect(.sleep(event.arguments[0]))
            case "blit":
                guard let b = event.blit else { throw Boundary.input("Blt request") }; try effect(.blit(b,result:inputs.drawResult))
            case "method": try effect(.present(event,result:inputs.presentation.methodResult))
            case "soundMethod": try effect(.soundMethod(event,ignoredResult:inputs.presentation.methodResult))
            case "getDC": try effect(.getDC(event,result:inputs.presentation.dcResult,output:inputs.presentation.dc))
            case "setBackgroundMode":
                // The shared library helper has accepted GetDC and emitted its
                // own new DC. Keep the observer view current during its local
                // inout transaction; the whole returned text owner joins below.
                guard let dc = event.arguments.first else { throw Boundary.input("Library DC event") }
                state.libraryText = .init(retainedDC:dc)
                try effect(.graphics(event,result:inputs.graphicsResult))
            case "setTextColor","textOut","releaseDC": try effect(.graphics(event,result:inputs.graphicsResult))
            case "read","clip","draw","panelRead","text","stringLength","soundRequest","PeekMessageA": break
            default: throw Boundary.dependency("Loading front operation: "+event.kind)
            }
            try emit(.front(event))
        }
        func draw(_ args: [UInt32]) throws {
            guard args.count == 7,let a = state.memory.allocations[args[0]],a.live,a.storage.bytes.count == 0x1f50 else {
                throw Boundary.input("Loading retained bitmap owner")
            }
            let surface = try a.storage.integer(at:0,as:UInt32.self)
            var record = a.storage; try record.write(UInt32(surface == 0 ? 0 : 1),at:0)
            let q = try OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),
                colorKey:args[4],mirrored:args[5],sourceSurface:surface,targetSurface:args[6],
                viewportWidth:Int32(bitPattern:word(0x44d78c)),viewportHeight:Int32(bitPattern:word(0x44d790)))
            _ = try OriginalBitmapDrawing.draw(q,bitmap:record,observeRead:{ r in
                var e = OriginalFrontScreenEvent("read"); e.read = r; try self.front(e)
            },observeClip:{ r in
                var e = OriginalFrontScreenEvent("clip"); e.clip = r; try self.front(e)
            },perform:{ r in
                var e = OriginalFrontScreenEvent("blit"); e.blit = r; try self.front(e); return self.inputs.drawResult
            })
        }
        func progress(_ request: OriginalLoadingProgress.Request) throws {
            switch request {
            case .catalogOpen: try front(.init("timeGetTime",[time()]))
            case .update:
                var globals = try Session.State.slice(state.full,0,OriginalMatchPreparation.globalSize), text = state.libraryText
                try OriginalLibLoadingProgress.update(globals:&globals,libraryText:&text,input:inputs.presentation,
                    time:time,panelFirstWord:{ p in
                        guard let a = self.state.memory.allocations[p],a.live else { throw Boundary.input("Loading panel owner") }
                        return try a.storage.integer(at:0,as:UInt32.self)
                    },draw:draw,fillBacking:{ throw Boundary.dependency("Loading fill backing") },
                    performFill:{ _ in throw Boundary.dependency("Loading fill") },message:message,store:store,
                    checkpoint:{ try self.state.replace(0,$0) },observe:front)
                try state.replace(0,globals); state.libraryText = text
            }
        }
        func sound(_ request: OriginalSoundRegistration) throws {
            guard pendingSound == nil,UInt32(request.index) == (try word(0x458438)),
                  request.cacheBefore == Array(state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)]) else {
                throw Boundary.input("Registered sound cache provenance")
            }
            pendingSound = request
            let device = try word(0x44eecc)
            guard device != 0 else { return }
            let p = try controls.wave(request,device),index = request.index
            let address = 0x452948+index*4,outputBefore = try word(address)
            try emit(.wave(index,.init(.load,[p.destination],[request.path.unicodeScalars.map { UInt8($0.value) }])))
            var candidate = sounds
            try candidate.load(request,device:device,outputBefore:outputBefore,platform:p,fileSource:file,
                outputStored:{ try self.put(address,$0) },onWave:{ e in
                    if e.kind != .load { self.operations.append(.wave(index,e)) }; try self.emit(.wave(index,e))
                },onVolume:{ args in
                    let result = try self.controls.volume(args)
                    self.operations.append(.volume(args,ignoredResult:result)); try self.emit(.volume(args,ignoredResult:result))
                })
            guard let owner = candidate.buffers[index] else { throw Boundary.missingOwners }
            try retainWave(owner,p); sounds = candidate; waveInputs.append(p)
        }
        func soundCache(_ bytes: [UInt8],_ count: Int) throws {
            guard let request = pendingSound,request.index+1 == count else { throw Boundary.input("Sound commit order") }
            let incoming = request.path.unicodeScalars.map { UInt8($0.value) }+[0]
            try store(0x455638+request.index*20,incoming); try put(0x458438,UInt32(count))
            guard bytes == Array(state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)]) else {
                throw Boundary.input("Whole sound cache differs from its own stores")
            }
            pendingSound = nil
        }
        func run() throws -> (catalog:OriginalLoadedCatalog,files:OriginalLoadingFiles) {
            let token = try allocate(.catalog,Int(entry.allocationBytes)),name = "data\\data.txt"
            try emit(.catalogEntry(token,name,entry.target))
            let bg = try backing(OriginalBackgroundLoader.recordSize),stage = try backing(OriginalStageLoader.stageSize)
            let result = try OriginalLoadedCatalog.loadWithFiles(files:.init(translation:.text),fileName:name,
                initialChecksum:word(0x44f620),initialSoundBytes:Array(state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)]),
                fill:inputs.allocationFill,parentBacking:parent,backgroundBacking:Array(repeating:bg,count:101),stageBacking:Array(repeating:stage,count:60),
                fileSource:file,fileAllocation:{ path,mode in
                    let a = try self.controls.file(path,mode)
                    try self.range(a.buffer,a.capacity); return a
                },
                onFile:{ e in self.operations.append(.file(e)); try self.emit(.file(e)) },
                bitmapSource:{ _ in throw Boundary.dependency("Missing owned bitmap constructor") },constructBitmap:construct,
                frameAllocation:{ try self.allocate(.frame($0),$1) },weaponSoundAllocation:{ try self.allocate(.weapon($0),$1) },
                onNewSound:{ _,q in try self.sound(q) },onMirror:{ _ in throw Boundary.dependency("Catalog mirrored bitmap continuation") },
                onProgress:progress,onChecksum:{ _,value in try self.put(0x44f620,value) },onSoundCache:soundCache,
                onMessage:{ _,checksum in
                    guard try self.word(0x44f620) == checksum else { throw Boundary.input("Message checksum") }
                    try OriginalLibLoadingProgress.processMessage(message:self.message,observe:self.front)
                },onRequest:{ q in
                    try self.emit(.request(q))
                    if q.kind == .object {
                        guard q.index == self.objectTokens.count else { throw Boundary.input("Object request order") }
                        self.objectTokens.append(try self.allocate(.object,0x25360))
                    }
                },onStore:parentStore,onChild:{ try self.afterChild($0,self.snapshot()) })
            guard pendingSound == nil else { throw Boundary.input("Unfinished catalog sound") }
            try controls.finish()
            try state.validateAliases(); return result
        }
    }
}
