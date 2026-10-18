import Foundation

/// Where a game's content packages are (ENGINE_SPLIT E1). An installed app
/// (build-native.sh/package_assets.py) or a `--resources` directory holds the
/// packages as ordinary folders in its resources; SwiftPM command-line and test
/// clients find the same packages in the game's resource bundle, which the game
/// supplies here and which is only looked up when the app bundle has none.
public struct OriginalContentLocation {
    public let appBundle: Bundle
    /// The packages' identity, which the loaders check (E2).
    public let identity: OriginalContentIdentity
    private let fallback: @Sendable () -> Bundle?

    public init(appBundle: Bundle,identity: OriginalContentIdentity,fallback: @escaping @Sendable () -> Bundle?) {
        self.appBundle = appBundle; self.identity = identity; self.fallback = fallback
    }
    /// The package folder `name`: the app bundle's when it has one or is an
    /// `.app` (an app must not use developer resources), else the fallback's.
    public func directory(_ name: String) -> URL? {
        if let resources = appBundle.resourceURL {
            let directory = resources.appendingPathComponent(name,isDirectory:true)
            if appBundle.bundleURL.pathExtension == "app" || FileManager.default.fileExists(atPath:directory.path) { return directory }
        }
        return fallback()?.url(forResource:name,withExtension:nil)
    }
}
