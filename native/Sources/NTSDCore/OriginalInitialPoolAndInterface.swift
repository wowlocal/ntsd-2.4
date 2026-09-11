/// The loading continuation41c052..41c581 after the catalog returns.
/// The caller supplies its already constructed World and first loaded Object+90.
/// This does not select players or complete the surrounding41bc90 invocation.
public struct OriginalInitialPoolAndInterface {
    public let bootstrap: OriginalWorldBootstrap
    public let interface: OriginalInitialInterfaceLoading
    public let globals: OriginalStateRecord

    /// Stage allocator/device bookkeeping in a value-semantic context until all
    /// Actor and bitmap work succeeds. Buffer external effects in that context.
    /// Numeric bitmap failures follow the original continuation; thrown failures
    /// retain the caller's context and produce no new pool/interface result.
    public static func load<Context>(world: OriginalStateRecord, globals: OriginalStateRecord,
        firstObjectWord90: Int32, context: inout Context,
        allocateActor: (Int, Int, inout Context) throws -> [UInt8],
        allocateInterface: (Int, inout Context) throws -> OriginalInterfaceAllocation,
        perform: @escaping (OriginalBitmapSurfaceLoading.Request, inout Context) throws -> OriginalBitmapSurfaceLoading.Response,
        afterActorConstructor: (Int, Bool, OriginalStateRecord, inout Context) throws -> Void = { _,_,_,_ in },
        afterPool: (OriginalWorldBootstrap, Bool, inout Context) throws -> Void = { _,_,_ in },
        afterBitmap: (Int, OriginalStateRecord, inout Context) throws -> Void = { _,_,_ in },
        observeInterface: (OriginalInterfaceEvent, inout Context) throws -> Void = { _,_ in }) throws -> Self {
        var environment = context, state = globals
        var bootstrap = try OriginalWorldBootstrap(world: world,
            allocateActor: { try allocateActor($0, $1, &environment) },
            afterConstructor: { try afterActorConstructor($0, false, $1, &environment) })
        try afterPool(bootstrap, false, &environment)
        try bootstrap.activateStagingActors(firstObjectWord90: firstObjectWord90,
            afterConstructor: { try afterActorConstructor($0, true, $1, &environment) })
        try afterPool(bootstrap, true, &environment)
        var interface = OriginalInitialInterfaceLoading()
        try interface.loadWithSurfaceLoading(globals: &state, context: &environment,
            allocate: allocateInterface, perform: perform, afterBitmap: afterBitmap, observe: observeInterface)
        context = environment
        return .init(bootstrap: bootstrap, interface: interface, globals: state)
    }
}
