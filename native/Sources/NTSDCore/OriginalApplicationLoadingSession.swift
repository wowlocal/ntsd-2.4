/// Production continuation of an actual menu loading entry. All work remains
/// tentative until the still-open catalog/loading/outer-loop continuation.
/// File bytes and platform replies are immutable inputs; observers do no IO.
public struct OriginalApplicationLoadingSession {
    public typealias Session = OriginalApplicationMenuSession
    public enum Boundary: Error, Equatable {
        case alreadyPrepared, missingOwners, waveReply(Int), unusedReplies, operation(String)
    }
    public enum Observation { case front(OriginalFrontScreenEvent), wave(OriginalWaveEvent) }
    /// A graphics command resolves the corresponding menu operation; it must
    /// not be delivered as a second draw. Wave load helper entries are excluded.
    public enum Operation: Equatable {
        case menu(Session.Effect)
        case wave(Int,OriginalWaveEvent)
    }
    public struct PendingCatalog {
        public let state: Session.State,target: UInt32,common: OriginalInitialLoadingCommon
        public let waveInputs: [OriginalWavePlatform]
        public let stagedOperations: [Operation],stagedGraphics: [OriginalApplicationGraphics.Command]
        /// The next original allocation boundary; allocation has not executed.
        public let allocationBytes: UInt32 = 81_273_768
    }
    public let entry: Session.PendingLoading
    public private(set) var pendingCatalog: PendingCatalog?
    public init(pending: Session.PendingLoading) throws {
        try pending.state.validateAliases()
        guard pending.state.bitmapInputs != nil,pending.state.graphics != nil else { throw Boundary.missingOwners }
        entry = pending
    }

    @discardableResult
    public mutating func prepareCommon(inputs: OriginalApplicationLoadingInputs,waves: [OriginalWavePlatform],
        drawResult: Int32,presentationResult: Int32,
        store: (Int,[UInt8]) throws -> Void = { _,_ in },
        observe: (Observation) throws -> Void = { _ in },
        graphicsObserve: (OriginalApplicationGraphics.Command) throws -> Void = { _ in },
        beforeWave: (Int,String,UInt32,OriginalStateRecord) throws -> Void = { _,_,_,_ in },
        afterPrologue: (OriginalStateRecord,Bool) throws -> Void = { _,_ in },
        attemptedWave: (Int,OriginalWaveLoadResult,OriginalStateRecord) throws -> Void = { _,_,_ in },
        afterWave: (Int,OriginalWaveLoadResult,OriginalStateRecord) throws -> Void = { _,_,_ in },
        beforeCatalog: (PendingCatalog) throws -> Void = { _ in }) throws -> PendingCatalog {
        guard pendingCatalog == nil else { throw Boundary.alreadyPrepared }
        var state = entry.state,operations = entry.stagedEffects.map(Operation.menu),graphics = entry.stagedGraphics
        let initial = try Session.State.slice(state.full,0,OriginalMatchPreparation.globalSize)
        var waveIndex = -1,consumed = 0
        func emit(_ effect: Session.Effect) throws {
            guard var owner = state.graphics else { throw Boundary.missingOwners }
            let command = try owner.consume(effect,inputs:state.bitmapInputs);state.graphics = owner
            if let command { graphics.append(command);try graphicsObserve(command) }
            operations.append(.menu(effect))
        }
        func ownedStore(_ address: Int,_ bytes: [UInt8]) throws {
            let offset = address-OriginalMatchPreparation.globalBase
            guard offset >= 0,offset <= OriginalMatchPreparation.globalSize-bytes.count else { throw Boundary.operation("Global store extent") }
            try state.replace(offset,.init(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count)))
            try store(address,bytes)
        }
        func draw(_ arguments: [UInt32]) throws {
            guard arguments.count == 7,let bitmap = state.memory.allocations[arguments[0]],bitmap.live,
                  bitmap.storage.bytes.count == 0x1f50 else { throw Boundary.operation("Loading bitmap owner") }
            let surface = try bitmap.storage.integer(at:0,as:UInt32.self)
            var canonical = bitmap.storage;try canonical.write(UInt32(surface == 0 ? 0 : 1),at:0)
            let request = try OriginalBitmapDrawInput(x:Int32(bitPattern:arguments[1]),y:Int32(bitPattern:arguments[2]),
                frame:Int32(bitPattern:arguments[3]),colorKey:arguments[4],mirrored:arguments[5],sourceSurface:surface,
                targetSurface:arguments[6],viewportWidth:initial.integer(at:0x78c,as:Int32.self),viewportHeight:initial.integer(at:0x790,as:Int32.self))
            _ = try OriginalBitmapDrawing.draw(request,bitmap:canonical,observeRead:{ q in
                var event = OriginalFrontScreenEvent("read");event.read = q;try observe(.front(event))
            },observeClip:{ q in
                var event = OriginalFrontScreenEvent("clip");event.clip = q;try observe(.front(event))
            },perform:{ q in
                var event = OriginalFrontScreenEvent("blit");event.blit = q
                try emit(.blit(q,result:drawResult));try observe(.front(event));return drawResult
            })
        }
        let common = try OriginalInitialLoadingCommon.load(globals:initial,targetSurface:entry.target,fileSource:inputs.file,
            platform:{ index,path,destination in
                guard index < waves.count else { throw Boundary.waveReply(index) }
                waveIndex = index;consumed += 1
                try beforeWave(index,path,destination,Session.State.slice(state.full,0,OriginalMatchPreparation.globalSize))
                return waves[index]
            },afterPrologue:afterPrologue,afterWave:afterWave,attemptedWave:attemptedWave,store:ownedStore,observe:{ event in
                if let wave = event.wave {
                    if wave.kind != .load { operations.append(.wave(waveIndex,wave)) }
                    try observe(.wave(wave))
                }
                if let presentation = event.presentation {
                    if presentation.kind == .bitmap {
                        try observe(.front(.init("draw",presentation.arguments)));try draw(presentation.arguments)
                    } else {
                        guard presentation.kind == .method else { throw Boundary.operation(presentation.kind.rawValue) }
                        let event = OriginalFrontScreenEvent(presentation.kind.rawValue,presentation.arguments,presentation.strings)
                        try emit(.present(event,result:presentationResult));try observe(.front(event))
                    }
                }
            })
        guard consumed == waves.count else { throw Boundary.unusedReplies }
        try state.replace(0,common.globals);try state.validateAliases()
        let prepared = PendingCatalog(state:state,target:entry.target,common:common,waveInputs:waves,
            stagedOperations:operations,stagedGraphics:graphics)
        try beforeCatalog(prepared)
        pendingCatalog = prepared
        return prepared
    }
}
