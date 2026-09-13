/// Semantic ownership of original459ff8, written by the bundled library's
/// match-preparation hooks and consumed by its post-draw command3 path.
/// Nil preserves unavailable initial backing until an actual preparation hook
/// writes it. This word lies beyond the EXE section's declared virtual extent;
/// a native application must not infer a known zero from ordinary PE BSS.
public struct OriginalLibStageCommands: Equatable {
    public internal(set) var requestedObjectID: Int32?
    public init(requestedObjectID: Int32? = nil) { self.requestedObjectID = requestedObjectID }
}
