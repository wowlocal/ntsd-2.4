// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NTSDNative",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NTSDNative", targets: ["NTSDApp"]),
               .executable(name: "NTSDFrameCheck", targets: ["NTSDFrameCheck"]),
               .executable(name: "NTSDMovementCheck", targets: ["NTSDMovementCheck"])],
    targets: [
        .target(name: "NTSDCore"),
        .executableTarget(name: "NTSDFrameCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDMovementCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDApp", dependencies: ["NTSDCore"],
                          linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("SpriteKit"),
                                           .linkedFramework("AVFoundation")]),
        .testTarget(name: "NTSDCoreTests", dependencies: ["NTSDCore"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
