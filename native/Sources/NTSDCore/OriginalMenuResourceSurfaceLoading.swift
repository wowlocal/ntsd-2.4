extension OriginalMenuResourceLoading {
    /// Whole resource caller with recovered image/surface/copy helpers.
    /// Context must have value semantics and buffer external effects until commit.
    /// Numeric API errors retain the original cleanup and continuation rules;
    /// thrown dependencies/observers leave loader, globals and context unchanged.
    /// NULL-SPARK preserves the standalone partial boundary, never dispatches.
    @discardableResult
    public mutating func loadWithSurfaceLoading<Context>(globals: inout OriginalStateRecord,
        context: inout Context,
        allocate: (Int, inout Context) throws -> OriginalInterfaceAllocation,
        perform: @escaping (OriginalBitmapSurfaceLoading.Request, inout Context) throws -> OriginalBitmapSurfaceLoading.Response,
        checkpoint: (OriginalMenuResourceCheckpoint, OriginalStateRecord, [UInt32:OriginalLoadedBitmap], inout Context) throws -> Void = { _,_,_,_ in },
        observe: (OriginalInterfaceEvent, inout Context) throws -> Void = { _,_ in }) throws -> OriginalMenuResourceResult {
        var candidate = self, state = globals, environment = context
        var scratch = try OriginalBitmapSurfaceLoading.CopyScratch()
        let result = try candidate.load(globals: &state, allocate: { try allocate($0, &environment) },
            source: { _,_ in throw OriginalStateError.invalidStorage("Unexpected menu image-result provider") },
            deviceResult: { _ in throw OriginalStateError.invalidStorage("Unexpected menu device-result provider") },
            constructBitmap: { _,allocation,device,path in
                try OriginalBitmapConstructor.constructWithSurfaceLoading(path: path, optional: false,
                    backing: allocation.backing, device: device, flags: 0x40, context: &environment, copyScratch: &scratch, perform: perform)
            }, checkpoint: { cp,globals,bitmaps in try checkpoint(cp, globals, bitmaps, &environment) },
            observe: { try observe($0, &environment) })
        self = candidate; globals = state; context = environment
        return result
    }
}
