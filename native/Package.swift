// swift-tools-version: 6.0
import PackageDescription

// The NTSD game (ENGINE_SPLIT E4a): its content, apps, hosts, checks and tests,
// on the engine package ../engine (by path; a dependency named here resolves
// to the engine's product of that name). The AppKit app and the tests in
// Tests/NTSDCoreTests/Mac build only on an Apple host. Cross builds from macOS evaluate this manifest on
// the host and opt out with NTSD_PORTABLE=1 (docs/research/CROSS_PLATFORM.md).
#if os(macOS)
let portable = Context.environment["NTSD_PORTABLE"] == "1"
#else
let portable = true
#endif

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

// The engine's products (../engine, package identity "engine").
func engine(_ product: String) -> Target.Dependency { .product(name: product, package: "engine") }
let core = engine("NTSDCore"), runtime = engine("NTSDRuntime"), musicDecoder = engine("NTSDMusicDecoder")
let macPlatform = engine("NTSDMacPlatform")

let macProducts: [Product] = portable ? [] : [.executable(name: "NTSDNative", targets: ["NTSDApp"])]
let macTargets: [Target] = portable ? [] : [
    .executableTarget(name: "NTSDApp", dependencies: [core, macPlatform, engine("NTSDAppKitHost"), "NTSDContent", "NTSDPractice"], swiftSettings: exclusivity,
                      linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("SpriteKit"),
                                       .linkedFramework("AVFoundation")])]
let macTestDependencies: [Target.Dependency] = portable ? [] : [macPlatform]

// NTSD_SDL=1 adds the SDL3 host (P6). NTSD_SDL_PREFIX names the SDL3 install
// (include/ and lib/); default builds never need SDL.
let sdl = Context.environment["NTSD_SDL"] == "1"
let sdlPrefix = Context.environment["NTSD_SDL_PREFIX"] ?? "/opt/homebrew/opt/sdl3"
let sdlProducts: [Product] = sdl ? [.executable(name: "NTSDSDL", targets: ["NTSDSDL"])] : []
// Non-Apple SDL builds rasterise text with a static FreeType from
// NTSD_FREETYPE_PREFIX (include/freetype2, lib); without it text stays blank.
let freetypePrefix = portable ? Context.environment["NTSD_FREETYPE_PREFIX"] : nil
let sdlTargets: [Target] = sdl ? [
    // The host itself, with CSDL3, is the engine's NTSDSDLHost (ENGINE_SPLIT E4b);
    // its include paths are needed here too, and the app links SDL3.
    .executableTarget(name: "NTSDSDL", dependencies: [engine("NTSDSDLHost"), "NTSDContent"],
                      swiftSettings: [.unsafeFlags(["-Xcc", "-I\(sdlPrefix)/include"]
                                                   + (freetypePrefix.map { ["-Xcc", "-I\($0)/include/freetype2"] } ?? []))] + exclusivity,
                      linkerSettings: [.unsafeFlags(["-L\(sdlPrefix)/lib"] + (freetypePrefix.map { ["-L\($0)/lib"] } ?? [])),
                                       // lld-link (Windows) has no rpath; SDL3.dll sits beside the exe there.
                                       .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "\(sdlPrefix)/lib"], .when(platforms: [.macOS, .linux]))])] : []

// NTSD_IOS=1 (with NTSD_PORTABLE=1) adds the iPad host (P8), built for an
// iOS triple and wrapped into an app by tools/crossplatform/ios_app.py; the
// host is the engine's NTSDUIKitHost (ENGINE_SPLIT E4b).
let ios = Context.environment["NTSD_IOS"] == "1"
let iosProducts: [Product] = ios ? [.executable(name: "NTSDiOS", targets: ["NTSDiOS"])] : []
let iosTargets: [Target] = ios ? [
    .executableTarget(name: "NTSDiOS", dependencies: [engine("NTSDUIKitHost"), "NTSDContent"], swiftSettings: exclusivity,
                      linkerSettings: [.linkedFramework("UIKit"), .linkedFramework("AVFoundation"), .linkedFramework("CoreText")])] : []

// NTSD_ANDROID=1 (with NTSD_PORTABLE=1) adds the Android host (P8): a
// NativeActivity library, built for an Android triple and packed into an APK
// by tools/crossplatform/android_app.py.
let android = Context.environment["NTSD_ANDROID"] == "1"
let androidProducts: [Product] = android ? [.library(name: "NTSDAndroid", type: .dynamic, targets: ["NTSDAndroid"])] : []
let androidTargets: [Target] = android ? [
    // The host, with CAndroidNative's NativeActivity entry, is the engine's
    // NTSDAndroidHost (ENGINE_SPLIT E4b); its FreeType include path is needed here too.
    .target(name: "NTSDAndroid", dependencies: [engine("NTSDAndroidHost"), "NTSDContent"],
            swiftSettings: [.unsafeFlags(freetypePrefix.map { ["-Xcc", "-I\($0)/include/freetype2"] } ?? [])] + exclusivity)] : []

// NTSD_WEB=1 (with NTSD_PORTABLE=1) adds the browser host (TVOS_WEB W2b),
// built for wasm32-unknown-wasip1 only (it uses the WASI-only main queue and
// sockets stub) and run in a page's worker by tools/crossplatform/web_run.mjs;
// the host, with its page functions (wasm imports), is the engine's NTSDWebHost
// (ENGINE_SPLIT E4b).
let web = Context.environment["NTSD_WEB"] == "1"
let webProducts: [Product] = web ? [.executable(name: "NTSDWeb", targets: ["NTSDWeb"])] : []
let webTargets: [Target] = web ? [
    .executableTarget(name: "NTSDWeb", dependencies: [engine("NTSDWebHost"), "NTSDContent"], swiftSettings: exclusivity)] : []

let package = Package(
    name: "NTSDNative",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: macProducts + sdlProducts + iosProducts + androidProducts + webProducts + [
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
    dependencies: [.package(path: "../engine")],
    targets: macTargets + sdlTargets + iosTargets + androidTargets + webTargets + [
        // The game's side (ENGINE_SPLIT E1): NTSD 2.4's content packages, found
        // by the engine through OriginalContentLocation. The music joins the
        // bundle in Mac builds only, as NTSDMacPlatform's did (E1b); the portable
        // packagers copy it beside the program themselves.
        .target(name: "NTSDContent", dependencies: [core], exclude: portable ? ["Resources/OriginalMusic"] : [], resources: [.copy("Resources/OriginalStartup"), .copy("Resources/OriginalCommonSounds"), .copy("Resources/OriginalLoadingInterface"), .copy("Resources/OriginalCharacterMenu"), .copy("Resources/OriginalWarMenu"), .copy("Resources/OriginalMatchArenas"), .copy("Resources/OriginalCatalog")]
                    + (portable ? [] : [.copy("Resources/OriginalMusic")]),
                swiftSettings: exclusivity),
        .systemLibrary(name: "CZlib", path: "Sources/CZlib"),
        // The game's side (ENGINE_SPLIT E3a): the Naruto/Sasuke practice model
        // behind NTSDApp's lab and the movement/combat checks; not on the
        // runtime path.
        .target(name: "NTSDPractice", dependencies: [core], swiftSettings: exclusivity),
        .executableTarget(name: "NTSDHeadless", dependencies: [engine("NTSDHeadlessHost"), "NTSDContent"], swiftSettings: exclusivity),
        .target(name: "NTSDReferenceChecks", dependencies: [core, "CZlib"]),
        .executableTarget(name: "NTSDBootstrapCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDCatalogCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDObjectCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDBGCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDStageCheck", dependencies: ["NTSDReferenceChecks"]),
        .executableTarget(name: "NTSDFrameCheck", dependencies: [core]),
        .executableTarget(name: "NTSDMovementCheck", dependencies: [core, "NTSDPractice"]),
        .executableTarget(name: "NTSDCombatCheck", dependencies: [core, "NTSDPractice"]),
        .executableTarget(name: "NTSDStateCheck", dependencies: [core]),
        .testTarget(name: "NTSDCoreTests", dependencies: [core, "NTSDReferenceChecks", runtime, musicDecoder, "CZlib", "NTSDContent", "NTSDPractice"] + macTestDependencies,
                    exclude: portable ? ["Mac"] : [], resources: [.copy("Fixtures")], swiftSettings: exclusivity)
    ],
    swiftLanguageModes: [.v5]
)
