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
    /// The packages built from NTSD 2.4 (2.0a distribution, EXE SHA-256 3f7ac67c…):
    /// the manifest digests and counts the engine's loaders check (E2).
    public static let identity = OriginalContentIdentity(
        exeSHA256:"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
        catalog:.init(manifestSHA256:"fd42d041549f00f5ba715063d7e560a9e2b01ab720017d1da5e032c34ca9451d",entries:1198,files:521,bitmaps:669,music:8),
        startup:.init(manifestSHA256:"f67aff089a95f230b4e7f5c381ac92b420a5541f7fea6b6a268986aa6b7ef177",entries:45,absentFiles:["data/ad0.txt"]),
        loadingManifestSHA256:"b1a519e2db09f18aa0d2bbaf29aa44226fba6a04852f8a4062778ae7d8e8a2f3",
        interfaceManifestSHA256:"9f8cb29ac2546c0718e7c83541972b6e4589c64488ec057027b4fe4edd55af82",
        menuManifestSHA256:"f0c363739088e477c8b51b597374f29bccae9f63d7d09f7169128c57b01b1161",
        warMenuManifestSHA256:"784c222b2313833f37219eae36b2424a61d4d0f2f257e5aaff083a82aaa5406a",
        arenaManifestSHA256:"60652ed8df36c7ff0bbaa167dcf1dd7be07140dac766c529d275f0705fc40519")
    /// The packages as the engine finds them: `appBundle`'s folders, else `bundle`.
    public static func location(in appBundle: Bundle = .main) -> OriginalContentLocation {
        .init(appBundle:appBundle,identity:identity,fallback:fallback)
    }
}
