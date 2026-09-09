/// Semantic ownership of original459ff8, written by the bundled library's
/// match-preparation hooks and consumed by its post-draw command3 path.
/// Initial backing must be supplied until outer application startup is joined.
public struct OriginalLibStageCommands: Equatable {
    public internal(set) var requestedObjectID: Int32
    public init(requestedObjectID: Int32) { self.requestedObjectID = requestedObjectID }
}
