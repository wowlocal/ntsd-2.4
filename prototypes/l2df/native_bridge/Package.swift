// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NTSDNativeBridge",
    platforms: [.macOS(.v14)],
    products: [.library(name: "NTSDNativeBridge", type: .dynamic, targets: ["NTSDNativeBridge"])],
    targets: [
        .target(name: "NTSDReplayCodec", exclude: ["README.md", "upstream.json"],
                publicHeadersPath: "include", cSettings: [.unsafeFlags(["-Wno-deprecated-non-prototype"])]),
        .target(name: "NTSDCore", dependencies: ["NTSDReplayCodec"]),
        .target(name: "NTSDNativeBridge", dependencies: ["NTSDCore"])
    ],
    swiftLanguageModes: [.v5]
)
