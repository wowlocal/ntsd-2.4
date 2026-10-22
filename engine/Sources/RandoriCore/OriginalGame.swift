import Foundation

/// A game for the engine's hosts (ENGINE_SPLIT E4b): what it is called and
/// where its content is, in the main bundle or a `--resources` directory.
public struct OriginalGame: Sendable {
    public let identity: OriginalGameIdentity
    public let content: @Sendable (Bundle) -> OriginalContentLocation
    public init(identity: OriginalGameIdentity,content: @escaping @Sendable (Bundle) -> OriginalContentLocation) {
        self.identity = identity; self.content = content
    }
}
