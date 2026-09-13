/// Own application continuation from the completed catalog through400 Actors,
/// eight staging reconstructions and ten UI constructors, before41c581. Shared
/// recovered loaders execute the rules. A failed attempt publishes no effects.
public struct OriginalApplicationPoolSession {
    public typealias Catalog = OriginalApplicationCatalogSession
    public typealias Session = OriginalApplicationMenuSession
    public typealias API = OriginalBitmapSurfaceLoading
    public enum Boundary: Error, Equatable {
        case alreadyPrepared, missingOwners, input(String), overlap(UInt32), nullActor
    }
    public struct Allocation: Equatable {
        public enum Kind: Equatable { case actor(Int), interface(Int) }
        public let kind: Kind,token: UInt32,count: Int
    }
    /// Fresh logical allocator/reply ownership per attempt. These callbacks must
    /// buffer effects; the returned operation journal is still awaiting the
    /// enclosing input/outer-loop continuation before backend publication.
    public struct Controls {
        public let allocate: (Allocation.Kind,Int) throws -> OriginalInterfaceAllocation
        public let bitmap: (API.Request) throws -> API.Response
        public let finish: () throws -> Void
        public init(allocate: @escaping (Allocation.Kind,Int) throws -> OriginalInterfaceAllocation,
                    bitmap: @escaping (API.Request) throws -> API.Response,finish: @escaping () throws -> Void = {}) {
            self.allocate = allocate;self.bitmap = bitmap;self.finish = finish
        }
    }
    /// Semantic boundaries only: no private per-instruction or partially updated
    /// enclosing Memory snapshot is exposed during the nested shared transaction.
    public enum Observation {
        case allocation(Allocation), constructor(Int,Bool,OriginalStateRecord)
        case pool(OriginalWorldBootstrap,Bool), interface(OriginalInterfaceEvent)
        case api(API.Request,API.Response), bitmapStored(Int,OriginalStateRecord)
    }
    public enum Operation: Equatable {
        case preceding(Catalog.Operation), allocation(Allocation), menu(Session.Effect)
    }
    public struct PendingInput {
        public let entry: Catalog.PendingPool,loaded: OriginalInitialLoading,state: Session.State
        public let allocations: [Allocation],actorTokens: [UInt32],interfaceTokens: [UInt32],interfaceSurfaces: [UInt32]
        public let operations: [Operation],graphics: [OriginalApplicationGraphics.Command]
    }
    public let entry: Catalog.PendingPool
    public private(set) var pendingInput: PendingInput?
    public init(pending: Catalog.PendingPool) throws {
        try pending.snapshot.state.validateAliases()
        guard pending.snapshot.state.bitmapInputs != nil,pending.snapshot.state.graphics != nil,
              !pending.catalog.objects.isEmpty,
              pending.snapshot.objectTokens.count == pending.catalog.objects.count,
              pending.snapshot.allocations.filter({ $0.kind == .catalog }).count == 1 else { throw Boundary.missingOwners }
        entry = pending
    }
    @discardableResult
    public mutating func prepare(inputs: OriginalApplicationInterfaceInputs,makeControls: () throws -> Controls,
        observe: @escaping (Observation) throws -> Void = { _ in },
        beforeCommit: (PendingInput) throws -> Void = { _ in }) throws -> PendingInput {
        guard pendingInput == nil else { throw Boundary.alreadyPrepared }
        let attempt = try Attempt(entry,inputs,makeControls(),observe)
        let loaded = try attempt.run()
        let result = PendingInput(entry:entry,loaded:loaded,state:attempt.state,allocations:attempt.allocations,
            actorTokens:attempt.actorTokens,interfaceTokens:attempt.interfaceTokens,interfaceSurfaces:attempt.surfaces,
            operations:attempt.operations,graphics:attempt.graphics)
        try beforeCommit(result)
        pendingInput = result;return result
    }
    private final class Attempt {
        let entry: Catalog.PendingPool,controls: Controls,observe: (Observation) throws -> Void
        var state: Session.State,allocations: [Allocation] = [],actorTokens: [UInt32] = [],interfaceTokens: [UInt32] = []
        var surfaces: [UInt32] = [],ranges: [(UInt64,UInt64)] = []
        var operations: [Operation],graphics: [OriginalApplicationGraphics.Command]
        init(_ entry: Catalog.PendingPool,_ inputs: OriginalApplicationInterfaceInputs,_ controls: Controls,
             _ observe: @escaping (Observation) throws -> Void) throws {
            self.entry = entry;self.controls = controls;self.observe = observe;state = entry.snapshot.state
            operations = entry.snapshot.operations.map(Operation.preceding);graphics = entry.snapshot.graphics
            guard var images = state.bitmapInputs else { throw Boundary.missingOwners }
            try images.addResources(inputs.bitmaps);state.bitmapInputs = images
            // The canonical globals/outer/World record is also live owned
            // storage; a logical heap identity cannot overlap that interval.
            reserve(0x44d000,state.full.bytes.count)
            for (token,a) in state.memory.allocations where a.live { reserve(token,a.storage.bytes.count) }
            for a in entry.snapshot.allocations { reserve(a.token,a.count) }
            for stream in entry.files.streams.values { reserve(stream.allocation.buffer,stream.allocation.capacity) }
            for (owner,p) in zip(entry.startup.owner.loads,entry.startup.platforms) { retain(owner,p) }
            for (owner,p) in zip(entry.entry.common.sounds,entry.entry.waveInputs) { retain(owner,p) }
            for (i,p) in entry.snapshot.waveInputs.enumerated() {
                guard let owner = entry.snapshot.sounds.buffers[i] else { throw Boundary.missingOwners };retain(owner,p)
            }
        }
        func reserve(_ token: UInt32,_ count: Int) {
            if token != 0,count > 0 { ranges.append((UInt64(token),UInt64(token)+UInt64(count))) }
        }
        func retain(_ owner: OriginalWaveLoadResult,_ p: OriginalWavePlatform) {
            reserve(p.firstPointer,owner.first.bytes.count)
            if let second = owner.second { reserve(p.secondPointer,second.bytes.count) }
        }
        func allocate(_ kind: Allocation.Kind,_ count: Int) throws -> OriginalInterfaceAllocation {
            let value = try controls.allocate(kind,count),a = Allocation(kind:kind,token:value.address,count:count)
            allocations.append(a);operations.append(.allocation(a));try observe(.allocation(a))
            if value.address == 0 {
                if case .actor = kind { throw Boundary.nullActor }
                guard value.backing.isEmpty else { throw Boundary.input("NULL UI backing") };return value
            }
            guard value.backing.count == count else { throw Boundary.input("Allocation backing extent") }
            let lo = UInt64(value.address),hi = lo+UInt64(count)
            guard hi <= UInt64(UInt32.max)+1 else { throw Boundary.input("Logical allocation extent") }
            guard !ranges.contains(where:{ lo < $0.1 && $0.0 < hi }) else { throw Boundary.overlap(value.address) }
            reserve(value.address,count);return value
        }
        func perform(_ q: API.Request) throws -> API.Response {
            let control = try controls.bitmap(q)
            guard control.writes.isEmpty else { throw Boundary.input("Captured bitmap writes") }
            guard var images = state.bitmapInputs,var owner = state.graphics else { throw Boundary.missingOwners }
            let response = try images.response(q,control:control);state.bitmapInputs = images
            if q.kind == "createSurface",let surface = response.output {
                guard !surfaces.isEmpty else { throw Boundary.input("UI surface without allocation") }
                surfaces[surfaces.count-1] = surface
            }
            let effect = Session.Effect.bitmap(q,response)
            if let command = try owner.consume(effect,inputs:images) { graphics.append(command) }
            state.graphics = owner;operations.append(.menu(effect));try observe(.api(q,response));return response
        }
        func join(_ pool: OriginalWorldBootstrap) throws {
            guard actorTokens.count == 400,pool.actors.count == 400,
                  let catalog = entry.snapshot.allocations.first(where:{ $0.kind == .catalog }),
                  let object = entry.snapshot.objectTokens.first else { throw Boundary.missingOwners }
            var world = pool.world
            try world.write(catalog.token,at:0x7d4)
            for i in 0..<400 {
                try world.write(actorTokens[i],at:0x194+4*i)
                var actor = pool.actors[i];try actor.write(object,at:0x368)
                state.memory.allocations[actorTokens[i]] = .init(storage:actor)
            }
            try state.replace(0xbb00,world)
        }
        func run() throws -> OriginalInitialLoading {
            let continuation = try OriginalInitialLoadingContinuation(prefix:entry.entry.common,
                resources:.init(catalog:entry.catalog,sounds:entry.snapshot.sounds),
                world:Session.State.slice(state.full,0xbb00,0x7d8),
                globals:Session.State.slice(state.full,0,OriginalMatchPreparation.globalSize))
            var context: Void = ()
            let loaded = try continuation.complete(context:&context,allocateActor:{ slot,count,_ in
                guard slot == self.actorTokens.count else { throw Boundary.input("Actor allocation order") }
                let a = try self.allocate(.actor(slot),count);self.actorTokens.append(a.address);return a.backing
            },allocateInterface:{ index,_ in
                guard index == self.interfaceTokens.count else { throw Boundary.input("UI allocation order") }
                let a = try self.allocate(.interface(index),0x1f50)
                self.interfaceTokens.append(a.address);self.surfaces.append(0);return a
            },perform:{ q,_ in try self.perform(q) },afterActorConstructor:{ slot,staging,record,_ in
                try self.observe(.constructor(slot,staging,record))
            },afterPool:{ pool,staging,_ in
                try self.join(pool);try self.observe(.pool(pool,staging))
            },afterBitmap:{ index,globals,_ in
                try self.state.replace(0,globals);try self.observe(.bitmapStored(index,globals))
            },observeInterface:{ event,_ in try self.observe(.interface(event)) })
            try state.replace(0,loaded.globals)
            for (i,token) in interfaceTokens.enumerated() where token != 0 {
                guard let bitmap = loaded.interface.bitmaps[token] else { throw Boundary.missingOwners }
                var record = bitmap.storage
                if try record.integer(at:0,as:UInt32.self) == 0 { surfaces[i] = 0 }
                try record.write(surfaces[i],at:0);state.memory.allocations[token] = .init(storage:record)
            }
            try controls.finish();try state.validateAliases();return loaded
        }
    }
}
