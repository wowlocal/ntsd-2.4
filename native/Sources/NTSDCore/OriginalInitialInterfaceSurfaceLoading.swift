extension OriginalInitialInterfaceLoading {
    /// Whole initial UI caller with the recovered image/surface/copy helpers.
    /// Use a value-semantic context for staged allocator/device bookkeeping;
    /// callbacks must buffer external effects until this operation commits.
    /// A numeric resource failure follows the original return/cleanup rules.
    /// A thrown dependency or observer error retains loader, globals and context.
    public mutating func loadWithSurfaceLoading<Context>(globals: inout OriginalStateRecord,
        context: inout Context,
        allocate: (Int, inout Context) throws -> OriginalInterfaceAllocation,
        perform: @escaping (OriginalBitmapSurfaceLoading.Request, inout Context) throws -> OriginalBitmapSurfaceLoading.Response,
        afterBitmap: (Int, OriginalStateRecord, inout Context) throws -> Void = { _,_,_ in },
        observe: (OriginalInterfaceEvent, inout Context) throws -> Void = { _,_ in }) throws {
        var candidate = self, state = globals, environment = context
        try candidate.load(globals: &state, allocate: { try allocate($0, &environment) },
            source: { _,_ in throw OriginalStateError.invalidStorage("Unexpected initial-interface image-result provider") },
            deviceResult: { _ in throw OriginalStateError.invalidStorage("Unexpected initial-interface device-result provider") },
            constructBitmap: { _,allocation,device,path in
                try OriginalBitmapConstructor.constructWithSurfaceLoading(path: path, optional: false,
                    backing: allocation.backing, device: device, flags: 0x40, context: &environment, perform: perform)
            }, afterBitmap: { index,globals in try afterBitmap(index, globals, &environment) },
            observe: { try observe($0, &environment) })
        self = candidate; globals = state; context = environment
    }
}
