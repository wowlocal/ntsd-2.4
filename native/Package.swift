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
               .executable(name: "NTSDCatalogCheck", targets: ["NTSDCatalogCheck"])],
    targets: [
        .target(name: "NTSDCore"),
        .target(name: "NTSDReferenceChecks", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDBootstrapCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDCatalogCheck", dependencies: ["NTSDReferenceChecks"]),
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
