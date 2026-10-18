/// Own native resources at the catalog return, before41c052 pool construction.
/// Globals are the caller's current state, including intervening catalog writes.
/// Constructing this value does not copy an earlier sound cache over that state.
public struct OriginalInitialLoadingContinuation {
    public let prefix: OriginalInitialLoadingCommon
    public let resources: OriginalInitialCatalogResources
    public let world: OriginalStateRecord, globals: OriginalStateRecord

    public init(prefix: OriginalInitialLoadingCommon, resources: OriginalInitialCatalogResources,
                world: OriginalStateRecord, globals: OriginalStateRecord) throws {
        guard !resources.catalog.objects.isEmpty,
              resources.catalog.soundCount == resources.sounds.buffers.count,
              prefix.commands.count == 2, prefix.commands.allSatisfy({ $0.count == 10 }) else {
            throw OriginalStateError.invalidStorage("Initial loading continuation ownership")
        }
        self.prefix = prefix; self.resources = resources
        self.world = world; self.globals = globals
    }

    /// Execute pool/UI rules and stage caller bookkeeping through the final
    /// observer. External effects must remain buffered in the supplied context.
    public func complete<Context>(context: inout Context,
        allocateActor: (Int, Int, inout Context) throws -> [UInt8],
        allocateInterface: (Int, inout Context) throws -> OriginalInterfaceAllocation,
        perform: @escaping (OriginalBitmapSurfaceLoading.Request, inout Context) throws -> OriginalBitmapSurfaceLoading.Response,
        afterActorConstructor: (Int, Bool, OriginalStateRecord, inout Context) throws -> Void = { _,_,_,_ in },
        afterPool: (OriginalWorldBootstrap, Bool, inout Context) throws -> Void = { _,_,_ in },
        afterBitmap: (Int, OriginalStateRecord, inout Context) throws -> Void = { _,_,_ in },
        observeInterface: (OriginalInterfaceEvent, inout Context) throws -> Void = { _,_ in },
        beforeCommit: (OriginalInitialLoading, inout Context) throws -> Void = { _,_ in }) throws -> OriginalInitialLoading {
        var environment = context
        let pool = try OriginalInitialPoolAndInterface.load(world: world, globals: globals,
            firstObjectWord90: { try resources.catalog.objects[0].header.integer(at: 0x90, as: Int32.self) },
            context: &environment, allocateActor: allocateActor, allocateInterface: allocateInterface,
            perform: perform, afterActorConstructor: afterActorConstructor, afterPool: afterPool,
            afterBitmap: afterBitmap, observeInterface: observeInterface)
        let result = loaded(pool)
        try beforeCommit(result, &environment)
        context = environment
        return result
    }

    /// Historical full-loading captures supply43ed10's device result. They use
    /// the same pool composition without claiming execution inside that helper.
    func completeWithProvidedInterface(actorBacking: [[UInt8]],
        allocateInterface: (Int) throws -> OriginalInterfaceAllocation,
        interfaceSource: (Int, String) throws -> OriginalBitmapInput,
        interfaceDevice: (Int) throws -> (surface: UInt32, colorKeyResult: Int32),
        afterPool: (OriginalWorldBootstrap, Bool) throws -> Void,
        afterBitmap: (Int, OriginalStateRecord) throws -> Void,
        observeInterface: (OriginalInterfaceEvent) throws -> Void) throws -> OriginalInitialLoading {
        guard actorBacking.count == 400 else { throw OriginalStateError.invalidStorage("Initial Actor pool count") }
        var context = ()
        let pool = try OriginalInitialPoolAndInterface.load(world: world, globals: globals,
            firstObjectWord90: { try resources.catalog.objects[0].header.integer(at: 0x90, as: Int32.self) },
            context: &context, allocateActor: { slot,_,_ in actorBacking[slot] },
            afterActorConstructor: { _,_,_,_ in }, afterPool: { value,staging,_ in try afterPool(value,staging) },
            loadInterface: { state,_ in
                var interface = OriginalInitialInterfaceLoading()
                try interface.load(globals: &state, allocate: allocateInterface, source: interfaceSource,
                    deviceResult: interfaceDevice, afterBitmap: afterBitmap, observe: observeInterface)
                return interface
            })
        return loaded(pool)
    }

    private func loaded(_ pool: OriginalInitialPoolAndInterface) -> OriginalInitialLoading {
        .init(globals: pool.globals, bootstrap: pool.bootstrap, catalog: resources.catalog,
            registeredSounds: resources.sounds, commonSounds: prefix.sounds, interface: pool.interface,
            paused: prefix.paused, commands: prefix.commands.flatMap { $0 })
    }
}
