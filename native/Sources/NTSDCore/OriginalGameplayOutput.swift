/// Gameplay422994 output order through the normal422a95 epilogue continuation.
/// Native storage commits only after all four helpers succeed. Device observers
/// must buffer external effects until their enclosing whole tick commits.
public enum OriginalGameplayOutput {
    /// Include424746's held-button clear after the match returns, followed by
    /// the outer dispatcher's normal return. The enclosing tick still buffers
    /// device effects; no machine stack or expected source bytes are imported.
    public static func returnFromDispatcher(world: inout OriginalStateRecord, globals: inout OriginalStateRecord,
        memory: inout OriginalMenuPresentationMemory, input: OriginalMenuPresentationInput,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        soundRequest: OriginalQueuedSound.Request,
        textRenderer: OriginalSurfaceText.Renderer? = nil,
        detail: Bool = true,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        // All or nothing: in place on copies, assigned when it completes.
        var stagedWorld = world, stagedGlobals = globals, stagedMemory = memory
        try returnFromDispatcherInPlace(world: &stagedWorld, globals: &stagedGlobals, memory: &stagedMemory,
            input: input, resourceBitmap: resourceBitmap, performBlit: performBlit,
            soundRequest: soundRequest, textRenderer: textRenderer, detail: detail, observe: observe)
        world = stagedWorld; globals = stagedGlobals; memory = stagedMemory
    }
    /// `returnFromDispatcher` on the caller's world, globals and memory, the
    /// output and mode label in place too (CORE_REALTIME B2 P4g): for callers
    /// that drop all three when this throws.
    package static func returnFromDispatcherInPlace(world: inout OriginalStateRecord, globals: inout OriginalStateRecord,
        memory: inout OriginalMenuPresentationMemory, input: OriginalMenuPresentationInput,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        soundRequest: OriginalQueuedSound.Request,
        textRenderer: OriginalSurfaceText.Renderer? = nil,
        detail: Bool = true,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        try applyInPlace(world: &world, globals: &globals, memory: &memory,
            input: input, resourceBitmap: resourceBitmap, performBlit: performBlit,
            soundRequest: soundRequest, textRenderer: textRenderer, detail: detail, observe: observe)
        try globals.write(UInt32(0), at: 0x457580-0x44d000)
        try observe(.init("dispatcherWrite", [0x457580, 0]))
    }

    public static func apply(world: inout OriginalStateRecord, globals: inout OriginalStateRecord,
        memory: inout OriginalMenuPresentationMemory, input: OriginalMenuPresentationInput,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        soundRequest: OriginalQueuedSound.Request,
        textRenderer: OriginalSurfaceText.Renderer? = nil,
        detail: Bool = true,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        // All or nothing: in place on copies, assigned when it completes.
        var stagedWorld = world, stagedGlobals = globals, stagedMemory = memory
        try applyInPlace(world: &stagedWorld, globals: &stagedGlobals, memory: &stagedMemory,
            input: input, resourceBitmap: resourceBitmap, performBlit: performBlit,
            soundRequest: soundRequest, textRenderer: textRenderer, detail: detail, observe: observe)
        world = stagedWorld; globals = stagedGlobals; memory = stagedMemory
    }
    /// `apply` on the caller's world, globals and memory, the mode label in
    /// place too (CORE_REALTIME B2 P4g): for callers that drop all three when
    /// this throws.
    package static func applyInPlace(world stagedWorld: inout OriginalStateRecord, globals stagedGlobals: inout OriginalStateRecord,
        memory stagedMemory: inout OriginalMenuPresentationMemory, input: OriginalMenuPresentationInput,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        soundRequest: OriginalQueuedSound.Request,
        textRenderer: OriginalSurfaceText.Renderer? = nil,
        detail: Bool = true,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        let alternate = try stagedGlobals.integer(at: 0x450b84-0x44d000, as: UInt32.self)
        let mode = try stagedGlobals.integer(at: 0x451160-0x44d000, as: Int32.self)
        try observe(.init("stage", [0x41b130]))
        try OriginalModeLabel.drawInPlace(mode: mode, alternateLine: alternate, globals: &stagedGlobals,
            resourceBitmap: resourceBitmap, performBlit: performBlit, detail: detail, observe: observe)
        try observe(.init("stage", [0x4028a0]))
        try OriginalMenuPresentation.apply(.overlay, input: input, world: &stagedWorld,
            globals: &stagedGlobals, memory: &stagedMemory, textRenderer: textRenderer) {
                try observe(.init($0.kind.rawValue, $0.arguments, $0.strings))
            }
        try observe(.init("stage", [0x43e940]))
        try OriginalMenuPresentation.presentSurface(globals: stagedGlobals) {
            try observe(.init($0.kind.rawValue, $0.arguments, $0.strings))
        }
        try observe(.init("stage", [0x419e60]))
        try OriginalQueuedSound.drain(globals: &stagedGlobals) {
            try observe(.init($0.kind.rawValue, $0.arguments))
            return try soundRequest($0)
        }
    }
}
