/// Complete the actual retained41e339 child with the installed library and
/// current application owners. The original Bootstrap ticket remains pending
/// until finishLoadedMenu commits the whole enclosing iteration.
public struct OriginalApplicationGameplaySession {
    public typealias Menu = OriginalApplicationLoadedMenuSession
    public let entry: OriginalApplicationInputSession.PendingContinuation
    public private(set) var pendingReturn: Menu.PendingReturn?

    public init(pending: OriginalApplicationInputSession.PendingContinuation) throws {
        try pending.state.validateAliases()
        guard pending.round.continuation == .gameplay, pending.match.libraryCommands != nil else {
            throw Menu.Boundary.dependency("Installed gameplay continuation")
        }
        entry = pending
    }

    /// Environment value-owns buffered effects. No callback submits IO before
    /// the enclosing Bootstrap commits. Unconnected result-file operations
    /// throw at their actual call, preserving the preceding committed game.
    @discardableResult
    public mutating func advance<Environment>(environment: inout Environment,
        outputInput: OriginalMenuPresentationInput,
        caller: OriginalGameplayBody.Caller = .init(),
        fillBacking: @escaping () throws -> [UInt8] = {
            throw Menu.Boundary.dependency("Gameplay fill backing")
        },
        allocate: @escaping (inout Environment) throws -> UInt32 = { _ in
            throw Menu.Boundary.dependency("Gameplay replay codec allocation")
        },
        processorSignature: @escaping (inout Environment) throws -> UInt32 = { _ in
            throw Menu.Boundary.dependency("Gameplay replay processor input")
        },
        open: @escaping (OriginalReplayFileOutput.OpenRequest,inout Environment) throws -> Bool = { _,_ in
            throw Menu.Boundary.dependency("Gameplay replay file open")
        },
        write: @escaping ([UInt8],inout Environment) throws -> Int32 = { _,_ in
            throw Menu.Boundary.dependency("Gameplay replay file write")
        },
        close: @escaping (inout Environment) throws -> Int32 = { _ in
            throw Menu.Boundary.dependency("Gameplay replay file close")
        },
        resumeMusic: @escaping (UInt32,inout Environment) throws -> Int32 = { _,_ in
            throw Menu.Boundary.dependency("Gameplay command music resume")
        },
        observe: @escaping (Menu.Observation,inout Environment) throws -> Void = { _,_ in },
        beforeCommit: (Menu.PendingReturn,inout Environment) throws -> Void = { _,_ in }) throws -> Menu.PendingReturn {
        guard pendingReturn == nil else { throw Menu.Boundary.alreadyPrepared }
        let a = try Menu.Attempt(entry,.init(bitmaps:[:]),environment,
            .init(dcResult:outputInput.dcResult,dc:outputInput.dc,methodResult:outputInput.methodResult,
                  drawResults:[outputInput.methodResult],shellResult:33),outputInput,
            { _,_,_ in throw Menu.Boundary.dependency("Unexpected gameplay bitmap allocation") },
            { _,_ in throw Menu.Boundary.dependency("Unexpected gameplay bitmap construction") },
            { _,_ in throw Menu.Boundary.dependency("Unexpected gameplay music selection") },
            { _ in throw Menu.Boundary.dependency("Unexpected gameplay menu clock") },observe,{ _,_,_ in })
        a.outputPhase = true
        let catalog = entry.entry.entry
        let soundBuffers = Set((catalog.startup.owner.loads + catalog.entry.common.sounds +
            Array(catalog.snapshot.sounds.buffers.values)).map(\.output).filter { $0 != 0 })
        var drainingSound = false
        var model = entry.match,context = entry.inputContext,random = entry.state.random,local = caller
        let library = OriginalGameplayBody.Library(text:entry.state.libraryText,hits:entry.state.libraryHits,
                                                   transforms:entry.state.libraryTransforms)
        func resource(_ token: UInt32) throws -> (OriginalStateRecord,UInt32) {
            var record: OriginalStateRecord
            let surface: UInt32
            if let allocation = a.state.memory.allocations[token] {
                guard allocation.live,allocation.storage.bytes.count == 0x1f50 else { throw Menu.Boundary.owner(token) }
                record = allocation.storage;surface = try record.integer(at:0,as:UInt32.self)
            } else {
                guard let ordinal = a.model.bitmapOwners.first(where:{ $0.value == token })?.key,
                      a.model.bitmaps.indices.contains(ordinal),!a.model.releasedBitmaps.contains(ordinal),
                      let currentSurface = a.model.bitmapSurfaceOwners[ordinal] else { throw Menu.Boundary.owner(token) }
                record = a.model.bitmaps[ordinal].storage;surface = currentSurface
                guard try record.integer(at:0,as:UInt32.self) == (surface == 0 ? 0 : 1) else { throw Menu.Boundary.owner(token) }
            }
            guard surface == 0 || a.state.graphics?.currentResources[surface]?.kind == "bitmapSurface" else {
                throw Menu.Boundary.owner(surface)
            }
            try record.write(UInt32(surface == 0 ? 0 : 1),at:0)
            return (record,surface)
        }
        let installed = try OriginalGameplayBody.apply(state:&model,context:&context,crt:&random,
            round:entry.round,caller:&local,target:entry.loading.target,presentation:outputInput,library:library,
            surface:{ ordinal in
                guard !a.model.releasedBitmaps.contains(ordinal),let token = a.model.bitmapOwners[ordinal],
                      a.model.bitmaps.indices.contains(ordinal) else { throw Menu.Boundary.dependency("Gameplay bitmap ordinal") }
                let (record,surface) = try resource(token)
                guard record == a.model.bitmaps[ordinal].storage else { throw Menu.Boundary.owner(token) }
                return surface
            },resourceBitmap:resource,fillBacking:fillBacking,
            performFill:{ _ in outputInput.methodResult },performBlit:{ _ in outputInput.methodResult },
            allocate:{
                let token = try allocate(&a.environment)
                if token != 0 { try a.claim(token,OriginalReplayWriter.capacity) }
                a.operations.append(.gameplayAllocate(token,OriginalReplayWriter.capacity));return token
            },processorSignature:{
                let value = try processorSignature(&a.environment);a.operations.append(.gameplayProcessor(value));return value
            },open:{ q in
                let value = try open(q,&a.environment);a.operations.append(.gameplayOpen(q,value));return value
            },write:{ bytes in
                let value = try write(bytes,&a.environment);a.operations.append(.gameplayWrite(bytes,value));return value
            },close:{
                let value = try close(&a.environment);a.operations.append(.gameplayClose(value));return value
            },
            soundRequest:{ request in
                if request.kind == .method {
                    guard let token = request.arguments.first,soundBuffers.contains(token) else {
                        throw Menu.Boundary.dependency("Gameplay current WAV buffer owner")
                    }
                    try a.emit(.soundMethod(.init("soundMethod",request.arguments),ignoredResult:outputInput.methodResult))
                }
                return outputInput.methodResult
            },observe:{ event in
                switch event {
                case .drawing(let stage,let e):
                    if stage == .output,e.kind == "stage",e.arguments == [0x419e60] { drainingSound = true }
                    if drainingSound,e.kind == "method" {
                        // The sound callback below stages this terminal method
                        // exactly once after validating the loaded WAV owner.
                        try observe(.front(e),&a.environment)
                    } else { try a.front(e) }
                case .impulses(let e):try a.front(.init(e.kind.rawValue,e.arguments,e.strings))
                case .recording(let e):a.operations.append(.gameplayRecording(e))
                case .commands(.resumeMusic(_,let control)):
                    let value = try resumeMusic(control,&a.environment)
                    a.operations.append(.gameplayResume(control,value))
                default:break
                }
                try observe(.gameplay(event),&a.environment)
            },ownedCheckpoint:{ stage,match,input,crt,library in
                var snapshot = a.state
                try a.bindings.store(match,context:input,in:&snapshot);snapshot.random = crt
                guard let library else { throw Menu.Boundary.dependency("Missing checkpoint library owners") }
                snapshot.libraryText = library.text;snapshot.libraryHits = library.hits
                snapshot.libraryTransforms = library.transforms
                let value = Menu.Snapshot(state:snapshot,match:match,music:a.audio,resources:a.resources,
                    backgrounds:a.backgrounds,local:a.local,operations:a.operations)
                try observe(.gameplayCheckpoint(stage,value),&a.environment)
            })
        guard let installed else { throw Menu.Boundary.dependency("Lost gameplay library owners") }
        var state = a.state
        try a.bindings.store(model,context:context,in:&state)
        state.random = random;state.libraryText = installed.text
        state.libraryHits = installed.hits;state.libraryTransforms = installed.transforms
        let snapshot = Menu.Snapshot(state:state,match:model,music:a.audio,resources:a.resources,
            backgrounds:a.backgrounds,local:a.local,operations:a.operations)
        let result = try OriginalApplicationDispatchEntry.finishWorldCall(globals:state.full)
        let pending = Menu.PendingReturn(entry:entry,snapshot:snapshot,exit:.returned,dispatcherResult:result,graphics:a.graphics)
        try beforeCommit(pending,&a.environment)
        pendingReturn = pending;environment = a.environment;return pending
    }
}
