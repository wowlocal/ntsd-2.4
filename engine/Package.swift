// swift-tools-version: 6.0
import PackageDescription

// The engine (ENGINE_SPLIT E4a): the model of the original EXE, the runtime,
// the codecs and the platform layers, without a game's content. The NTSD game
// (native/Package.swift) depends on it by path. Its switches are the game
// package's: the same environment variables choose the same settings.

// The AppKit platform layer builds only on an Apple host. Cross builds from
// macOS evaluate this manifest on the host and opt out with NTSD_PORTABLE=1
// (docs/research/CROSS_PLATFORM.md).
#if os(macOS)
let portable = Context.environment["NTSD_PORTABLE"] == "1"
#else
let portable = true
#endif

// Release builds of the shared libraries serialize their bodies for callers in
// other modules, so the generic Host, iteration and session code is
// specialized for the one platform type the runtime uses instead of running
// through value witnesses (CORE_REALTIME 4k). An optimization only: no
// floating-point or other semantic flag.
let crossModule: [SwiftSetting] = [.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))]

// Shipping builds drop Swift's dynamic exclusivity checks (CORE_REALTIME 4aa;
// the user's decision, 2026-10-08): about 3.5-4% of the A12's main thread.
// Opt-in with NTSD_UNCHECKED_EXCLUSIVITY=1, which the APK builder sets; every
// other build, the test bundles in particular, keeps the checks, and the
// define lets a test fail when its bundle was built without them. Behaviour
// of correct code is the same either way.
let uncheckedExclusivity = Context.environment["NTSD_UNCHECKED_EXCLUSIVITY"] == "1"
let exclusivity: [SwiftSetting] = uncheckedExclusivity
    ? [.unsafeFlags(["-enforce-exclusivity=unchecked"], .when(configuration: .release)),
       .define("NTSD_UNCHECKED_EXCLUSIVITY", .when(configuration: .release))]
    : []

let macProducts: [Product] = portable ? [] : [.library(name: "NTSDMacPlatform", targets: ["NTSDMacPlatform"]),
                                              .library(name: "NTSDAppKitHost", targets: ["NTSDAppKitHost"])]
let macTargets: [Target] = portable ? [] : [
    .target(name: "NTSDMacPlatform", dependencies: ["NTSDCore", "NTSDRuntime"],
            swiftSettings: exclusivity,
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("AVFoundation")]),
    // The AppKit host (ENGINE_SPLIT E4b): runs a game given as an OriginalGame.
    .target(name: "NTSDAppKitHost", dependencies: ["NTSDCore", "NTSDMacPlatform"], swiftSettings: exclusivity,
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("AVFoundation")])]

// FreeType glyph masks for the SDL host off Apple platforms and the Android
// host, from the static FreeType at NTSD_FREETYPE_PREFIX; without it text stays
// blank and the target is absent.
let freetypePrefix = portable ? Context.environment["NTSD_FREETYPE_PREFIX"] : nil
let freetypeProducts: [Product] = freetypePrefix != nil ? [.library(name: "NTSDFreeTypeText", targets: ["NTSDFreeTypeText"])] : []
let freetypeTargets: [Target] = freetypePrefix != nil ? [
    .systemLibrary(name: "CFreeType", path: "Sources/CFreeType"),
    .target(name: "NTSDFreeTypeText", dependencies: ["NTSDRuntime", "CFreeType"],
            swiftSettings: [.unsafeFlags(["-Xcc", "-I\(freetypePrefix!)/include/freetype2"])] + exclusivity,
            linkerSettings: [.unsafeFlags(["-L\(freetypePrefix!)/lib"])])] : []

// NTSD_WEB=1 (with NTSD_PORTABLE=1) adds the browser host library (TVOS_WEB
// W2b), built for wasm32-unknown-wasip1 only; its page functions are wasm
// imports (@_extern(wasm), the experimental Extern feature).
let web = Context.environment["NTSD_WEB"] == "1"
let webProducts: [Product] = web ? [.library(name: "NTSDWebHost", targets: ["NTSDWebHost"])] : []
let webTargets: [Target] = web ? [
    .target(name: "NTSDWebHost", dependencies: ["NTSDCore", "NTSDRuntime", "NTSDMusicDecoder"],
            swiftSettings: [.enableExperimentalFeature("Extern")] + exclusivity)] : []

// NTSD_SDL=1 adds the SDL3 host library (P6). NTSD_SDL_PREFIX names the SDL3
// install (include/ and lib/); the game's app links SDL3 itself (its -L and
// rpath), so this target carries only the include paths its clients share.
let sdl = Context.environment["NTSD_SDL"] == "1"
let sdlPrefix = Context.environment["NTSD_SDL_PREFIX"] ?? "/opt/homebrew/opt/sdl3"
let sdlProducts: [Product] = sdl ? [.library(name: "NTSDSDLHost", targets: ["NTSDSDLHost"])] : []
let sdlTargets: [Target] = sdl ? [
    .systemLibrary(name: "CSDL3", path: "Sources/CSDL3"),
    .target(name: "NTSDSDLHost", dependencies: ["NTSDCore", "NTSDRuntime", "NTSDMusicDecoder", "CSDL3"] + (portable ? [] : ["NTSDMacPlatform"])
                + (freetypePrefix == nil ? [] : ["NTSDFreeTypeText"]),
            swiftSettings: [.unsafeFlags(["-Xcc", "-I\(sdlPrefix)/include"]
                                         + (freetypePrefix.map { ["-Xcc", "-I\($0)/include/freetype2"] } ?? []))] + exclusivity)] : []

// NTSD_IOS=1 (with NTSD_PORTABLE=1) adds the UIKit host library (P8, TVOS_WEB
// T0): the iPad and the Apple TV, built for an iOS or tvOS triple.
let ios = Context.environment["NTSD_IOS"] == "1"
let iosProducts: [Product] = ios ? [.library(name: "NTSDUIKitHost", targets: ["NTSDUIKitHost"])] : []
let iosTargets: [Target] = ios ? [
    .target(name: "NTSDUIKitHost", dependencies: ["NTSDCore", "NTSDRuntime"], swiftSettings: exclusivity,
            linkerSettings: [.linkedFramework("UIKit"), .linkedFramework("AVFoundation"), .linkedFramework("CoreText")])] : []

// NTSD_ANDROID=1 (with NTSD_PORTABLE=1) adds the Android host library (P8): a
// NativeActivity (CAndroidNative's entry calls the game's ntsd_android_on_create),
// built for an Android triple into the game's dynamic library.
let android = Context.environment["NTSD_ANDROID"] == "1"
let androidProducts: [Product] = android ? [.library(name: "NTSDAndroidHost", targets: ["NTSDAndroidHost"])] : []
let androidTargets: [Target] = android ? [
    .target(name: "CAndroidNative", linkerSettings: [.linkedLibrary("android"), .linkedLibrary("log"), .linkedLibrary("aaudio")]),
    .target(name: "NTSDAndroidHost", dependencies: ["NTSDCore", "NTSDRuntime", "NTSDMusicDecoder", "CAndroidNative"]
                + (freetypePrefix == nil ? [] : ["NTSDFreeTypeText"]),
            swiftSettings: [.unsafeFlags(freetypePrefix.map { ["-Xcc", "-I\($0)/include/freetype2"] } ?? [])] + exclusivity)] : []

let package = Package(
    name: "NTSDEngine",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: macProducts + freetypeProducts + webProducts + sdlProducts + iosProducts + androidProducts + [
        .library(name: "NTSDCore", targets: ["NTSDCore"]),
        .library(name: "NTSDRuntime", targets: ["NTSDRuntime"]),
        .library(name: "NTSDMusicDecoder", targets: ["NTSDMusicDecoder"]),
        .library(name: "NTSDHeadlessHost", targets: ["NTSDHeadlessHost"])],
    targets: macTargets + freetypeTargets + webTargets + sdlTargets + iosTargets + androidTargets + [
        .target(name: "NTSDReplayCodec", exclude: ["README.md", "upstream.json"],
                publicHeadersPath: "include", cSettings: [.unsafeFlags(["-Wno-deprecated-non-prototype"])]),
        .target(name: "NTSDCore", dependencies: ["NTSDReplayCodec"], swiftSettings: crossModule + exclusivity),
        .target(name: "NTSDRuntime", dependencies: ["NTSDCore"], swiftSettings: crossModule + exclusivity),
        // The vendored decoder learns the byte order from TargetConditionals.h
        // on Apple platforms and only for x86 elsewhere; every non-Apple target
        // built here (aarch64, x86_64, wasm32) is little-endian (without it the
        // decoder byte-swapped every packet on wasm32, TVOS_WEB W2b-3).
        .target(name: "CALAC", exclude: ["README.md", "upstream.json", "vendor/LICENSE"],
                cSettings: [.define("TARGET_RT_LITTLE_ENDIAN", to: "1", .when(platforms: [.linux, .android, .windows, .wasi]))],
                cxxSettings: [.define("TARGET_RT_LITTLE_ENDIAN", to: "1", .when(platforms: [.linux, .android, .windows, .wasi]))]),
        .target(name: "NTSDMusicDecoder", dependencies: ["CALAC"], swiftSettings: exclusivity),
        // The hosts (ENGINE_SPLIT E4b): each runs a game given as an OriginalGame.
        .target(name: "NTSDHeadlessHost", dependencies: ["NTSDCore", "NTSDRuntime"], swiftSettings: exclusivity),
    ],
    swiftLanguageModes: [.v5]
)
