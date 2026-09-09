/// Gameplay422994 output order through the normal422a95 epilogue continuation.
/// Native storage commits only after all four helpers succeed. Device observers
/// must buffer external effects until their enclosing whole tick commits.
public enum OriginalGameplayOutput {
    public static func apply(world: inout OriginalStateRecord, globals: inout OriginalStateRecord,
        memory: inout OriginalMenuPresentationMemory, input: OriginalMenuPresentationInput,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        soundRequest: OriginalQueuedSound.Request,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        var stagedWorld = world, stagedGlobals = globals, stagedMemory = memory
        let alternate = try stagedGlobals.integer(at: 0x450b84-0x44d000, as: UInt32.self)
        let mode = try stagedGlobals.integer(at: 0x451160-0x44d000, as: Int32.self)
        try observe(.init("stage", [0x41b130]))
        try OriginalModeLabel.draw(mode: mode, alternateLine: alternate, globals: &stagedGlobals,
            resourceBitmap: resourceBitmap, performBlit: performBlit, observe: observe)
        try observe(.init("stage", [0x4028a0]))
        try OriginalMenuPresentation.apply(.overlay, input: input, world: &stagedWorld,
            globals: &stagedGlobals, memory: &stagedMemory) {
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
        world = stagedWorld; globals = stagedGlobals; memory = stagedMemory
    }
}
