import Foundation
import NTSDCore

/// NTSD 2.4's content packages (ENGINE_SPLIT E1): the game's side of the
/// engine's OriginalContentLocation.
public enum NTSDContent {
    /// The SwiftPM resource bundle that holds the packages. An installed app
    /// carries the same folders in its own resources and never needs it.
    public static var bundle: Bundle { .module }
    /// `bundle`, looked up only when it is needed (an app has no SwiftPM bundle).
    public static let fallback: @Sendable () -> Bundle? = { NTSDContent.bundle }
    /// The packages as the engine finds them: `appBundle`'s folders, else `bundle`.
    public static func location(in appBundle: Bundle = .main) -> OriginalContentLocation {
        .init(appBundle:appBundle,fallback:fallback)
    }
}
