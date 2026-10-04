// swift-tools-version: 6.0
import PackageDescription

// The AppKit app, its platform layer and the tests in Tests/NTSDCoreTests/Mac
// build only on an Apple host. Cross builds from macOS evaluate this manifest on
// the host and opt out with NTSD_PORTABLE=1 (docs/research/CROSS_PLATFORM.md).
#if os(macOS)
let portable = Context.environment["NTSD_PORTABLE"] == "1"
#else
let portable = true
#endif

let macProducts: [Product] = portable ? [] : [.executable(name: "NTSDNative", targets: ["NTSDApp"])]
let macTargets: [Target] = portable ? [] : [
    .target(name: "NTSDMacPlatform", dependencies: ["NTSDCore", "NTSDRuntime"], resources: [.copy("Resources/OriginalMusic")],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("AVFoundation")]),
    .executableTarget(name: "NTSDApp", dependencies: ["NTSDCore", "NTSDMacPlatform"],
                      linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("SpriteKit"),
                                       .linkedFramework("AVFoundation")])]
let macTestDependencies: [Target.Dependency] = portable ? [] : ["NTSDMacPlatform"]

// NTSD_SDL=1 adds the SDL3 host (P6). NTSD_SDL_PREFIX names the SDL3 install
// (include/ and lib/); default builds never need SDL.
let sdl = Context.environment["NTSD_SDL"] == "1"
let sdlPrefix = Context.environment["NTSD_SDL_PREFIX"] ?? "/opt/homebrew/opt/sdl3"
let sdlProducts: [Product] = sdl ? [.executable(name: "NTSDSDL", targets: ["NTSDSDL"])] : []
let sdlTargets: [Target] = sdl ? [
    .systemLibrary(name: "CSDL3", path: "Sources/CSDL3"),
    .executableTarget(name: "NTSDSDL", dependencies: ["NTSDCore", "NTSDRuntime", "CSDL3"] + (portable ? [] : ["NTSDMacPlatform"]),
                      swiftSettings: [.unsafeFlags(["-Xcc", "-I\(sdlPrefix)/include"])],
                      linkerSettings: [.unsafeFlags(["-L\(sdlPrefix)/lib", "-Xlinker", "-rpath", "-Xlinker", "\(sdlPrefix)/lib"])])] : []

let package = Package(
    name: "NTSDNative",
    platforms: [.macOS(.v14)],
    products: macProducts + sdlProducts + [
               .executable(name: "NTSDFrameCheck", targets: ["NTSDFrameCheck"]),
               .executable(name: "NTSDMovementCheck", targets: ["NTSDMovementCheck"]),
               .executable(name: "NTSDCombatCheck", targets: ["NTSDCombatCheck"]),
               .executable(name: "NTSDStateCheck", targets: ["NTSDStateCheck"]),
               .executable(name: "NTSDBootstrapCheck", targets: ["NTSDBootstrapCheck"]),
               .executable(name: "NTSDCatalogCheck", targets: ["NTSDCatalogCheck"]),
               .executable(name: "NTSDObjectCheck", targets: ["NTSDObjectCheck"]),
               .executable(name: "NTSDBGCheck", targets: ["NTSDBGCheck"]),
               .executable(name: "NTSDStageCheck", targets: ["NTSDStageCheck"]),
               .executable(name: "NTSDHeadless", targets: ["NTSDHeadless"])],
    targets: macTargets + sdlTargets + [
        .target(name: "NTSDReplayCodec", exclude: ["README.md", "upstream.json"],
                publicHeadersPath: "include", cSettings: [.unsafeFlags(["-Wno-deprecated-non-prototype"])]),
        .target(name: "NTSDCore", dependencies: ["NTSDReplayCodec"], resources: [.copy("Resources/OriginalStartup"), .copy("Resources/OriginalCommonSounds"), .copy("Resources/OriginalLoadingInterface"), .copy("Resources/OriginalCharacterMenu"), .copy("Resources/OriginalWarMenu"), .copy("Resources/OriginalMatchArenas"), .copy("Resources/OriginalCatalog")]),
        .systemLibrary(name: "CZlib", path: "Sources/CZlib"),
        .target(name: "NTSDRuntime", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDHeadless", dependencies: ["NTSDCore", "NTSDRuntime"]),
        .target(name: "NTSDReferenceChecks", dependencies: ["NTSDCore", "CZlib"]),
        .executableTarget(name: "NTSDBootstrapCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDCatalogCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDObjectCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDBGCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDStageCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDFrameCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDMovementCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDCombatCheck", dependencies: ["NTSDCore"]),
        .executableTarget(name: "NTSDStateCheck", dependencies: ["NTSDCore"]),
        .testTarget(name: "NTSDCoreTests", dependencies: ["NTSDCore", "NTSDReferenceChecks", "NTSDRuntime", "CZlib"] + macTestDependencies,
                    exclude: portable ? ["Mac"] : [], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
