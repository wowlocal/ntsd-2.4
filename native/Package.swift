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
// Non-Apple SDL builds rasterise text with a static FreeType from
// NTSD_FREETYPE_PREFIX (include/freetype2, lib); without it text stays blank.
let freetypePrefix = portable ? Context.environment["NTSD_FREETYPE_PREFIX"] : nil
let sdlTargets: [Target] = sdl ? [
    .systemLibrary(name: "CSDL3", path: "Sources/CSDL3"),
    .executableTarget(name: "NTSDSDL", dependencies: ["NTSDCore", "NTSDRuntime", "NTSDMusicDecoder", "CSDL3"] + (portable ? [] : ["NTSDMacPlatform"])
                          + (freetypePrefix == nil ? [] : ["NTSDFreeTypeText"]),
                      swiftSettings: [.unsafeFlags(["-Xcc", "-I\(sdlPrefix)/include"]
                                                   + (freetypePrefix.map { ["-Xcc", "-I\($0)/include/freetype2"] } ?? []))],
                      linkerSettings: [.unsafeFlags(["-L\(sdlPrefix)/lib"] + (freetypePrefix.map { ["-L\($0)/lib"] } ?? [])),
                                       // lld-link (Windows) has no rpath; SDL3.dll sits beside the exe there.
                                       .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "\(sdlPrefix)/lib"], .when(platforms: [.macOS, .linux]))])] : []

// NTSD_IOS=1 (with NTSD_PORTABLE=1) adds the iPad host (P8), built for an
// iOS triple and wrapped into an app by tools/crossplatform/ios_app.py.
let ios = Context.environment["NTSD_IOS"] == "1"
let iosProducts: [Product] = ios ? [.executable(name: "NTSDiOS", targets: ["NTSDiOS"])] : []
let iosTargets: [Target] = ios ? [
    .executableTarget(name: "NTSDiOS", dependencies: ["NTSDCore", "NTSDRuntime"],
                      linkerSettings: [.linkedFramework("UIKit"), .linkedFramework("AVFoundation"), .linkedFramework("CoreText")])] : []

// NTSD_ANDROID=1 (with NTSD_PORTABLE=1) adds the Android host (P8): a
// NativeActivity library, built for an Android triple and packed into an APK
// by tools/crossplatform/android_app.py.
let android = Context.environment["NTSD_ANDROID"] == "1"
let androidProducts: [Product] = android ? [.library(name: "NTSDAndroid", type: .dynamic, targets: ["NTSDAndroid"])] : []
let androidTargets: [Target] = android ? [
    .target(name: "CAndroidNative", linkerSettings: [.linkedLibrary("android"), .linkedLibrary("log"), .linkedLibrary("aaudio")]),
    .target(name: "NTSDAndroid", dependencies: ["NTSDCore", "NTSDRuntime", "NTSDMusicDecoder", "CAndroidNative"] + (freetypePrefix == nil ? [] : ["NTSDFreeTypeText"]),
            swiftSettings: [.unsafeFlags(freetypePrefix.map { ["-Xcc", "-I\($0)/include/freetype2"] } ?? [])])] : []

// FreeType glyph masks for the SDL host off Apple platforms and the Android
// host, from the static FreeType at NTSD_FREETYPE_PREFIX.
let freetypeTargets: [Target] = (sdl || android) && freetypePrefix != nil ? [
    .systemLibrary(name: "CFreeType", path: "Sources/CFreeType"),
    .target(name: "NTSDFreeTypeText", dependencies: ["NTSDRuntime", "CFreeType"],
            swiftSettings: [.unsafeFlags(["-Xcc", "-I\(freetypePrefix!)/include/freetype2"])],
            linkerSettings: [.unsafeFlags(["-L\(freetypePrefix!)/lib"])])] : []

let package = Package(
    name: "NTSDNative",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: macProducts + sdlProducts + iosProducts + androidProducts + [
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
    targets: macTargets + sdlTargets + iosTargets + androidTargets + freetypeTargets + [
        .target(name: "NTSDReplayCodec", exclude: ["README.md", "upstream.json"],
                publicHeadersPath: "include", cSettings: [.unsafeFlags(["-Wno-deprecated-non-prototype"])]),
        .target(name: "NTSDCore", dependencies: ["NTSDReplayCodec"], resources: [.copy("Resources/OriginalStartup"), .copy("Resources/OriginalCommonSounds"), .copy("Resources/OriginalLoadingInterface"), .copy("Resources/OriginalCharacterMenu"), .copy("Resources/OriginalWarMenu"), .copy("Resources/OriginalMatchArenas"), .copy("Resources/OriginalCatalog")]),
        .systemLibrary(name: "CZlib", path: "Sources/CZlib"),
        .target(name: "NTSDRuntime", dependencies: ["NTSDCore"]),
        // The vendored decoder learns the byte order from TargetConditionals.h
        // on Apple platforms and only for x86 elsewhere; every non-Apple target
        // built here (aarch64, x86_64) is little-endian.
        .target(name: "CALAC", exclude: ["README.md", "upstream.json", "vendor/LICENSE"],
                cSettings: [.define("TARGET_RT_LITTLE_ENDIAN", to: "1", .when(platforms: [.linux, .android, .windows]))],
                cxxSettings: [.define("TARGET_RT_LITTLE_ENDIAN", to: "1", .when(platforms: [.linux, .android, .windows]))]),
        .target(name: "NTSDMusicDecoder", dependencies: ["CALAC"]),
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
        .testTarget(name: "NTSDCoreTests", dependencies: ["NTSDCore", "NTSDReferenceChecks", "NTSDRuntime", "NTSDMusicDecoder", "CZlib"] + macTestDependencies,
                    exclude: portable ? ["Mac"] : [], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
