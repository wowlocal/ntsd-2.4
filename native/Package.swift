// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NTSDNative",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NTSDNative", targets: ["NTSDApp"]),
               .executable(name: "NTSDFrameCheck", targets: ["NTSDFrameCheck"]),
               .executable(name: "NTSDMovementCheck", targets: ["NTSDMovementCheck"]),
               .executable(name: "NTSDCombatCheck", targets: ["NTSDCombatCheck"]),
               .executable(name: "NTSDStateCheck", targets: ["NTSDStateCheck"]),
               .executable(name: "NTSDBootstrapCheck", targets: ["NTSDBootstrapCheck"]),
               .executable(name: "NTSDCatalogCheck", targets: ["NTSDCatalogCheck"]),
               .executable(name: "NTSDObjectCheck", targets: ["NTSDObjectCheck"]),
               .executable(name: "NTSDBGCheck", targets: ["NTSDBGCheck"]),
               .executable(name: "NTSDStageCheck", targets: ["NTSDStageCheck"])],
    targets: [
        .target(name: "NTSDReplayCodec", exclude: ["README.md", "upstream.json"],
                publicHeadersPath: "include", cSettings: [.unsafeFlags(["-Wno-deprecated-non-prototype"])]),
        .target(name: "NTSDCore", dependencies: ["NTSDReplayCodec"], resources: [.copy("Resources/OriginalStartup"), .copy("Resources/OriginalCommonSounds"), .copy("Resources/OriginalLoadingInterface")]),
        .target(name: "NTSDReferenceChecks", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDBootstrapCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDCatalogCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDObjectCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDBGCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDStageCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDFrameCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDMovementCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDCombatCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDStateCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDApp", dependencies: ["NTSDCore"],
                          linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("SpriteKit"),
                                           .linkedFramework("AVFoundation")]),
        .testTarget(name: "NTSDCoreTests", dependencies: ["NTSDCore", "NTSDReferenceChecks"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
