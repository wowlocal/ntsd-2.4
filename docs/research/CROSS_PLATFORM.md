# Cross-platform port — plan, rules and status

Requested by the user on 2026-10-03: make the native game run on Linux and
Windows, later iPad/Android, built by cross-compiling from this Mac. Work runs
as a self-paced `/loop` on branch `dev/crossplatform`; each iteration takes the
**Next task** below, finishes one checked increment and updates the ledger.

The starting point was an external architecture review pasted by the user.
Its claims are leads to verify, not evidence. Items it raised that are confirmed
in the tree are listed under "Verified starting point".

## Goal and boundaries

- One Core on every platform. Platform layers answer the same
  `OriginalRequestExchange` requests; no per-platform gameplay branches and no
  second engine. Ordering, retry/receipt and resource-lifetime rules stay.
- No change to simulation behaviour. A Core edit is allowed only as a small,
  behaviour-neutral portability patch (conditional import, OS clock, digest
  provider) that the unchanged macOS suites and reference checks still pass.
  Keep `OriginalExtended`, byte-record storage, the vendored replay codec and
  other compatibility code as they are; port them, do not simplify them.
- Fixtures, expected bytes, masks and frozen plans are immutable. A difference
  on a new platform is a recorded mismatch, never a regenerated expected value.
- The AppKit app remains the macOS shipping build and the reference backend
  for every new backend. It must not regress.
- No Wine, CrossOver or emulation in any shipping runtime. Linux containers,
  Rosetta x86_64 and Wine/CrossOver are test harnesses here; label their results
  as such. Actual Windows, Linux desktop and device observations stay open
  until they are performed.
- On 2026-10-03 the user approved pushing `dev/crossplatform`. It tracks
  `origin`, and the post-commit hook pushes each commit. They also accepted
  Microsoft's VS Build Tools license for `xwin` downloads. Enabling CI,
  publishing releases or installing other paid or licensed software still needs
  the user's confirmation. Everything else in this plan is authorized for the
  loop.

## Verified starting point (2026-10-03, `74be317`)

- Toolchain: Swift 6.3.3 via swiftly (`arm64-apple-macosx`); installed Swift SDK
  `swift-6.3.3-RELEASE_android` only; `clang-cl` and `lld-link` in swiftly's
  bin; SDL3 from Homebrew; OrbStack Docker (linux/aarch64, 12 CPU, 12 GiB).
  No Linux or Windows Swift SDK, mingw or qemu.
- `native/Package.swift`: `platforms: [.macOS(.v14)]`, executable products only,
  `NTSDCoreTests` depends on `NTSDMacPlatform`; `NTSDMacPlatform` and `NTSDApp`
  link AppKit/AVFoundation (App also SpriteKit).
- Non-portable imports. NTSDCore: `CryptoKit` (6 files) and `Darwin`
  (`OriginalMacStartupClock.swift`, `clock_gettime`). NTSDReferenceChecks:
  `CryptoKit` (6), `Compression` (4). NTSDApp: AppKit, SpriteKit, CryptoKit,
  GameController, AVFoundation. NTSDMacPlatform: AppKit, AVFoundation/AVFAudio,
  Darwin sockets, `os`, UniformTypeIdentifiers.
- Size: NTSDCore 223 files / 30.5k lines, NTSDReferenceChecks 68 / 11.3k,
  NTSDMacPlatform 4.5k, NTSDApp 1.5k. Resources: Core 726 MB, Mac music 112 MB,
  test fixtures 4.3 GB.
- Storage: internal data volume 37 GiB free (`build/` there is 200 GB);
  X5 (APFS `3A4F5FA6-…`) 45 GiB free; T7 (ExFAT) 1.8 TiB free.

## Cross-compilation toolchains

Established in P0 ([evidence](../evidence/crossplatform-p0-20261003.json)):

- The macOS reference build stays on Xcode's Swift 6.4 via
  `xcrun --toolchain XcodeDefault swift` (as in `tools/build-native.sh`).
- Cross builds use the open-source 6.4.0 toolchain at
  `~/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift`.
  It matches the Xcode compiler version and the installed
  `swift-6.4.0-RELEASE_static-linux-0.1.0` SDK.
- Do not use the swiftly default on PATH (6.3.3): it fails against this macOS
  SDK with `unknown argument: '-target-arch-variant'`. Keep only one SDK per
  triple; two make `--swift-sdk <triple>` ambiguous.
- Swift 6.4 uses swift-build by default. Products land in
  `<scratch>/out/Products/<Config>-staticlinux-<arch>`; locate them with
  `--show-bin-path`.
- Cross-built probe: `tools/crossplatform/probe`.

| Target | SDK built on this Mac | Test harness here | Real observation |
| --- | --- | --- | --- |
| Linux x86_64/aarch64, headless | Swift Static Linux SDK 6.4.0 (musl), checksum from swift.org's releases API — **working** | OrbStack container; aarch64 native, x86_64 under Rosetta | Linux host |
| Linux desktop (SDL3) | glibc Swift SDK (e.g. `swift-sdk-generator` from an Ubuntu 24.04 image), since static musl cannot `dlopen` SDL's video/audio drivers; SDL3 built for that sysroot | container with virtual display/audio for smoke runs | Linux desktop |
| Windows x86_64 (arm64 later) | `*-unknown-windows-msvc`: Windows SDK headers/libs plus the Swift Windows runtime; swift.org publishes no Windows SDK bundle for 6.4.0 (installer/Docker only), so feasibility is unproven and is P0-W's question | CrossOver/Wine, test only | Windows PC |
| Android arm64 | `swift-6.3.3-RELEASE_android` installed; move to the 6.4.0 Android SDK + NDK | emulator/device | device |
| iPadOS | Xcode iOS SDK | simulator | device |

If Windows cross-compilation proves infeasible, record the evidence. The fallback
is a native Windows build, e.g. a GitHub Actions runner, which requires the
user's approval to push. Until then, keep the other phases moving.

## Phases and gates

- **P0 Toolchains.** Install SDKs, cross-build a probe using Foundation, Dispatch
  and file IO for each triple, then run it in the harness. Gate: probe output
  recorded per triple.
- **P1 Package graph.** Library products for `NTSDCore`/`NTSDReferenceChecks`;
  Apple-only targets and linker settings conditional on platform; split
  `NTSDCoreTests` into portable tests and Mac-platform tests by moving files only,
  removing none. Gate: macOS build plus the moved tests pass unchanged.
- **P2 Core portability.** Conditional digest provider for CryptoKit
  (swift-crypto or an in-tree SHA-256; the digests must equal CryptoKit's on
  every packaged input). Add a per-OS clock with the same contract and a portable
  replacement for `Compression` in the reference checks. Audit Foundation
  differences Core relies on (string encodings, number formatting, directory
  enumeration order, `Bundle.module`), libm transcendental calls, pointer width
  and LLP64 `long` in the C codec. Gate: Core, ReferenceChecks and the check
  executables cross-compile for Linux.
- **P3 Headless Linux determinism.** Run the cross-built reference checks and
  portable tests on the same fixtures in a container. Compare state bytes, RNG
  progression and replay bytes with the macOS results. Gate: identical, or each
  difference recorded with evidence.
- **P4 Headless Windows.** Do the same for windows-msvc under Wine, plus the
  LLP64 codec audit. Gate: identical under Wine; actual Windows stays open.
- **P5 Shared runtime (on macOS).** Extract platform-neutral orchestration from
  `OriginalRuntimeLaunch`, the `OriginalMacRuntime*` files, the surface
  semantics in `OriginalMacDisplayBackend` and the sound and music sequencing
  into `NTSDRuntime`. Put protocols in front of window, present, input, audio,
  socket, clock and filesystem. Gate: Mac app unchanged on the existing app e2e
  and Demo/VS cross-checks.
- **P6 SDL3 backend on macOS.** Add `NTSDSDLPlatform` with window, streaming
  texture present, keyboard/joystick and audio device. Gate: on the same machine,
  run a deterministic input replay through the Mac and SDL backends; per-frame
  framebuffers and state must match, and audio samples must match where decoding
  is shared.
- **P7 Linux/Windows apps.** Cross-build and package (Linux archive, Windows zip
  with `SDL3.dll`). Decode music on non-Apple platforms with samples verified
  against AVFoundation's decode, and add a socket adapter: POSIX on Linux, real
  Winsock on Windows. Gate: a replay-driven Naruto/Sasuke District match with
  matching state in each harness; real-device observations open.
- **P8 Mobile.** iPad with controller/keyboard first: lifecycle, storage and
  real-device memory (desktop soak footprint ≈2 GB). Then touch, then Android.

## Iteration rules

- One checked increment per iteration. Commit only its files on
  `dev/crossplatform` (iterative commits are pre-authorized by AGENTS.md). Then
  update the ledger, **Next task** and the CURRENT_WORK link.
- Cheap checks first: compile the touched targets for macOS and one cross triple
  before heavy suites. Any change to Core, App or MacPlatform needs a macOS
  release build plus the affected tests before commit.
- Cross-build scratch goes on X5 under
  `/Volumes/X5/ntsd-2.4-research/crossplatform/`. Verify mount and UUID first
  and keep at least 20 GiB free there and on the internal volume. SDK installs
  may use the default SwiftPM location on the internal volume. No build trees on
  T7 (ExFAT has no symlinks).
- Run macOS tests in the project's release test path:
  `xcrun --toolchain XcodeDefault swift-build --package-path native --scratch-path build/swiftpm-test-release --build-system native -c release --build-tests -Xswiftc -enable-testing`,
  then `swift-test … --skip-build --filter …`. Plain `swift test` in
  `native/.build` uses swift-build and created an 11 GB `out/Products/Debug`
  tree on 2026-10-03. That tree was removed again to restore the internal
  volume's reserve.
- Linux tests cross-build with the generated glibc SDK
  `ntsd-6.4.0-ubuntu24.04-aarch64`; the static musl SDK has no XCTest. Run
  them in the `swift:6.4.0-noble` container, which supplies the Swift runtime.
- Before every commit, check `git diff --cached --stat` for entries that
  belong to another increment. `git mv` stages a rename immediately, and a
  partial commit takes the whole index.
- At most three failed rounds per mechanism; then diagnose before the next run.
- Long builds and test runs go to the background with recorded PID and command.
  A quiet log is not a stopped job.
- If the next task is blocked, record the blocker with evidence, take the next
  independent task, and list the exact input needed from the user.

## Status ledger

| Date | Phase | Result | Checks | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-03 | — | Plan and inventory written | text/links only | c753d7c |
| 2026-10-03 | P0 Linux | Static Linux SDK 6.4.0 installed; probe cross-built for aarch64/x86_64 musl and run in containers. Output equals macOS except `os`/`crypto`. First `NTSDCore` Linux build stops at `import CryptoKit`. | probe compare; Core build log | c649bac |
| 2026-10-03 | P2a digest | `PortableSHA256` (FIPS 180-4) in Core, exported as `SHA256` only where CryptoKit is missing. CryptoKit imports are conditional in Core (6), reference checks (6) and tests (7); Apple builds still use CryptoKit. The Linux Core build passes CryptoKit and stops at `import Darwin`. | macOS `PortableSHA256Tests`: vectors, lengths 0–200 split into regions, 1,528 packaged files / 874,627,316 bytes equal to CryptoKit; Xcode release build. First compile attempt failed on exclusivity (log `p2a-macos-sha-test.log`) | 4547acc |
| 2026-10-03 | P2b clock | `OriginalMacStartupClock` imports Darwin/Glibc/Musl/Android per OS with unchanged calls. **`NTSDCore` now cross-compiles for Linux** (aarch64 debug and release, x86_64 debug). `NTSDReferenceChecks` stops at `import Compression`. | macOS clock test `testActualMacClocksAtWholeCallerBoundaries`; Xcode release build; Linux build logs `p2b-*` | 65c6916 |
| 2026-10-03 | P2c inflate | `FixtureInflate.decode` keeps the `compression_decode_buffer(COMPRESSION_ZLIB)` contract. It uses `Compression` on Apple platforms and SDK zlib (new `CZlib` system-library target) elsewhere. Four reference checks and two tests call it; the pinned replay codec is untouched. **All nine check executables cross-compile for Linux aarch64.** | `FixtureInflateTests` with `NTSD_FIXTURE_INFLATE_ALL=1`: zlib equals Compression on all 1,934 fixture blobs (38 zlib-wrapped, header/trailer stripped as their test does), 3,157,901,771 packed / 18,326,948,532 inflated bytes, plus truncation for blobs ≤4 MiB. 21 regression tests (Object, Stage, Background, Bootstrap, WindowInput, CatalogDIBPixels, CatalogSession, LibWarFaultRejection) in the release test build; Xcode release build | 699f9ec |
| 2026-10-03 | P1 package | The manifest is portable on non-Apple hosts or with `NTSD_PORTABLE=1`; it then drops `NTSDMacPlatform`, `NTSDApp`/`NTSDNative` and the 19 test files now under `Tests/NTSDCoreTests/Mac/` (`git mv`, same target on macOS). The manifest cache honours the variable (16 ↔ 14 targets). Linux builds all portable targets. **The static musl SDK has no XCTest or swift-testing**, so the Linux test build needs a glibc SDK. | macOS: debug build with tests; `swift test list` = 696 tests = 696 `func test` declarations, and all 19 moved classes have full method counts; Xcode release build. Linux aarch64 `NTSD_PORTABLE=1` build of every portable target. Linux test build: `no such module 'XCTest'` (log `p1-linux-aarch64-tests-debug.log`) | 48db790 |
| 2026-10-03 | P0-W Swift side | The official 6.4.0 Windows installer unpacks on this Mac. From its WiX Burn bundle come the x86_64/aarch64 `Windows.sdk` (Foundation, Dispatch, WinSDK, XCTest) and the runtime DLLs. **Blocked:** linking also needs the MSVC CRT and Windows SDK, which only come with acceptance of Microsoft's license (asked). | attached container SHA-512 equals the burn manifest; two earlier offset attempts failed and are recorded. [evidence](../evidence/crossplatform-p0w-20261003.json) | 6203799 |
| 2026-10-03 | P0-L2 glibc SDK | `swift-sdk-generator` (6.4.0 tag) built the Ubuntu 24.04 aarch64 SDK `ntsd-6.4.0-ubuntu24.04-aarch64`, with XCTest and swift-testing, from `swift:6.4.0-noble`. **The portable test suite now cross-compiles for Linux.** Test-only changes: Linux-only no-argument inits for 252 suites (suites construct each other), a pass-through `autoreleasepool`, and one bridge cast removed. **First Linux run: 12 original-reference tests pass** (whole Stage table, Object streams, Bootstrap pools, Background, SHA-256). | XCTest smoke and glibc probe equal to macOS; six build rounds recorded; touched tests pass on macOS (6); Linux debug run 12/12 in 466 s. [evidence](../evidence/crossplatform-p0l2-20261003.json) | ebb9adc |
| 2026-10-03 | P3 (running) | Full portable run in `swift:6.4.0-noble`, release build. The first pass exposed one test-harness difference: Darwin `NSDictionary` treats JSON `true` as `1`, corelibs does not, which broke the Active* parent lookup. Fixed by `sameJSONObject` (Darwin path unchanged); the run resumed on the fixed binary. | macOS 10/10 affected tests; the helper equals Darwin on 18 JSON cases in Linux. Results so far: `/Volumes/X5/ntsd-2.4-research/crossplatform/p3-aarch64-release/results.jsonl` | 503af05 |
| 2026-10-03 | P5 step 1 | New portable target `NTSDRuntime` (Core only), re-exported by NTSDMacPlatform. IdentityPool, Heap, Zone and RuntimeMessages moved with `git mv`; `take()` became public and RuntimeMessages' unused AppKit import was dropped. [Design](CROSS_PLATFORM_RUNTIME.md) | release test build; RuntimeMenu, RuntimeStartup, ObservedIteration 14/14; `swift test list` = 696; Xcode release build; Linux `NTSD_PORTABLE=1` build of `NTSDRuntime` | fb61a77 |
| 2026-10-03 | P5 step 2 | The sound mixer (voices, positions, loop, volume/pan, render, call decoding) moved to `NTSDRuntime`; `backed(by:)` and the AVAudioEngine output stay in `OriginalMacSoundOutput.swift`. `OriginalRuntimeLock` is `OSAllocatedUnfairLock` on Darwin and an NSLock class elsewhere. The volume law `gain` moved to the mixer, and `OriginalMacMusicOutput.gain` forwards to it. Its `pow` is libm-dependent on other hosts; that is audio output, not simulation. | SoundEffects 6, MusicOutput 7, LoadingAudio 3 (the 55-minute whole-catalog test was not rerun; the code moved unchanged) = 16/16 on a fresh test build; 696 listed; Xcode release; Linux `NTSDRuntime`. The first gate run was invalid: the test build failed and `--skip-build` reran the step-1 binary. The gate script now aborts on a failed test build | 56ac79e |
| 2026-10-03 | P5 step 3 | Music sequencing moved to `NTSDRuntime`: `OriginalMacMusicOutput` (graph state, seeks, virtual clock, end events over the `Player` protocol) and `OriginalMacRuntimeMusic` (DirectShow answers). The AVAudioPlayer adapter and bundled-track lookup stay in `OriginalMacMusicPlayer.swift`. The MessageBoxA presenter is now a required init argument, and the Mac `init(identities:heap:)` supplies the same NSAlert, so a host cannot silently lose it. | MusicOutput, RuntimeLoading, RuntimeStartup 18/18 on a fresh test build; 696 listed; Xcode release; Linux `NTSDRuntime`. The first attempt stopped at the test build (missing `@testable import NTSDRuntime`), as the gate now requires | 1c2db2a |
| 2026-10-03 | P5 step 4 | `OriginalFramebuffer` (XRGB8888 little-endian words) in `NTSDRuntime`. The display backend now builds a framebuffer, and a Mac `cgImage()` wraps it with the unchanged sRGB `noneSkipFirst|byteOrder32Little` parameters. `OriginalMacWindowBackend.present(_:in:)` takes a framebuffer. The five display call sites are unchanged. | New `OriginalFramebufferTests` (bytes and format); Framebuffer, DisplayBackend, DisplayColor, BitmapBackend, FrontRaster, WindowBackend, WindowGeometry 27/27 on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime` | 882adc6 |
| 2026-10-03 | e2e baseline | Full `tools/app_e2e.py` at 882adc6: 8/10 scenarios pass. `playback` fails with "Recording file may be corrupted" **at pre-crossplatform 74be317 too** (pre-existing on main). `tournament-win` differed in its final capture once and passed twice on rerun, and passes at 74be317: a capture nondeterministic under load. No regression from P0–P5.4. | [evidence](../evidence/crossplatform-e2e-baseline-20261003.json) | 92985dd |
| 2026-10-03 | P5 step 5 | **The display backend (≈900 lines) moved to `NTSDRuntime`.** It talks to windows through `OriginalRuntimeWindowing` (identities, `windowLease`, `displayGeometry`, `present(OriginalFramebuffer,in:)`); the five presentations now call `present` with the same bytes. CoreText glyph masks are injected (`textMask:`), and the Mac convenience `init(windows:)` supplies them. `image(_:) -> CGImage`, `cgImage()`, `macWindows` (used by FrontService) and the window-protocol conformance live in `OriginalMacDisplayImage.swift`. DisplayGeometry is the runtime struct. Bitmap/Front/DisplayStartup services stay Mac for now. | 51 tests (display, color, bitmap, front raster, window, geometry, framebuffer, observed bitmap/graphics/iteration, runtime startup/menu) on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime` (object rebuilt). **Full app e2e: 9/10, the same as baseline** (only the pre-existing playback alert) | c5f5e0b |
| 2026-10-04 | P5 step 6 | The audio backend and AudioService moved to `NTSDRuntime`. A portable float `Samples` store replaces `AVAudioPCMBuffer`, keeping `ready` = frames > 0 and the byte budget. The AVAudioFormat/PCMBuffer allocation failure path is gone, since those inputs are already validated. The runtime exposes `samples(_:)`; the Mac `pcmSnapshot` builds the same standard-format AVAudioPCMBuffer from it. `windowClosed(_:)` was added to `OriginalRuntimeWindowing`. | 34 tests (AudioBackend, SoundEffects, LoadingAudio ×3, RuntimeStartup, Menu, Loading, ObservedIteration) on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime`; full app e2e 9/10 = baseline | 08e6f4f |
| 2026-10-04 | P5 step 7 (narrowed) | DisplayStartupService and BitmapService moved to `NTSDRuntime` unchanged; they only use runtime types. RuntimeStartupService needs the window request model (`prepare`/`perform` with the Mac `Prepared`), and RuntimeNetwork needs a Winsock provider, so both wait for their steps. | BitmapBackend, ObservedBitmap, RuntimeStartup, RuntimeMenu, ObservedIteration 24/24 on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime`. e2e not rerun: pure file move, no code change | 1dcf183 |
| 2026-10-04 | P3 memory | The heavy `Lib*` suites (LibSelectionCommands, LibSelectionStage, LibStageMode, LibTeamTournamentBracket/Preparation, so far) are OOM-killed on Linux even alone. `OriginalLibStageModeTests` peaks at 4.1 GB RSS on macOS (release, 64 s, passes), but in the container it grows 0.26→8.3 GiB in 21 s and is killed at the 11.7 GiB OrbStack VM limit (`OOMKilled=true`). `MALLOC_ARENA_MAX=2` changes nothing. Its fixture setup decodes a 1.19 GB JSON corpus with `JSONDecoder`, then parses it again into a full `JSONSerialization` `[String: Any]` tree, which corelibs Foundation represents far less compactly. Options: (a) rework these tests' corpus loading to avoid full trees, or (b) a larger VM, which is the user's OrbStack setting and restarts their containers. Asked the user. | samples `logs/mem-linux-LibStageMode*.tsv`, `logs/mem-macos-LibStageMode.log` | 6cdb5c2 |
| 2026-10-04 | P5 step 8 | **The window request model moved to `NTSDRuntime`.** `OriginalRuntimeWindowBackend` now owns: tokens; cursor, class and window leases; request validation; the `perform` dispatch with its order; operations; metrics rules; held/full-screen geometry; present checks. It drives an `OriginalRuntimeWindowHost` (screen size, frame metric, cursor, create, windowCreated, orderFront, update, show, close, nonisolated `released`, client bounds/frame, display geometry, desktop point, present). `OriginalMacWindowHost` reproduces the AppKit code line for line. `OriginalMacWindowBackend` is now a typealias; Mac-only services (observation, `display(CGImage)`, capture, input, close request, macOS full screen, hide, clientPoint, PNG snapshots) are extensions. The lease keeps the host strongly, so a released open window is still closed after the backend is gone. | 51 tests (window, geometry, display, color, framebuffer, front raster, startup, menu, observed ×3, audio) on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime`; full app e2e 9/10 = baseline, including altenter | d855299 |
| 2026-10-04 | P5 step 9 | RuntimeStartupService, WindowStartupService and WindowGeometryService moved to `NTSDRuntime`. The startup service takes its `OriginalMacRuntimeMusic` as an init argument, and the Mac `init(windows:heap:environment:)` supplies the NSAlert one. `FileEffect` gained a public init. | Startup, Menu, Loading, WindowBackend, WindowGeometry, ObservedIteration, ObservedGraphics, MusicOutput 41/41 on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime`; full app e2e 9/10 = baseline | 60b463b |
| 2026-10-04 | P5 step 10 | `OriginalRuntimeSockets` covers every Winsock call the original makes, plus `lastError`/`boundPort` and FD_* `post`. `OriginalRuntimeSocketNotification` and the pure `OriginalRuntimeSocketText` (inet_addr/ntoa/htons) are in `NTSDRuntime`. `OriginalMacRuntimeNetwork` moved there and takes its sockets; the Mac `init(localAddresses:)` supplies `OriginalMacWinsock`, whose statics forward. The first gate run stopped at the test build: the protocol lacked `boundPort`/`lastError`. | Winsock, NetworkHost, NetworkExit, RuntimeMenu, RuntimeLoading 23/23 on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime`; full app e2e 9/10 = baseline (including vs's online check) | fb2e1c0 |
| 2026-10-04 | P5 step 11a | FrontService moved to `NTSDRuntime`. It reaches the runtime window backend through the display's `windows` (a precondition names a display without it); the Mac-only `macWindows` cast is gone. | FrontRaster, ObservedGraphics, ObservedIteration, RuntimeMenu, RuntimeStartup 26/26 on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime`; full app e2e 9/10 = baseline | 6e68178 |
| 2026-10-04 | P5 step 11b | **The startup composition moved to `NTSDRuntime`:** `OriginalMacRuntimeStartup` (prepared inputs, overlay inputs, the attempt loop and audio/window/display/runtime dispatch, `Started`) and `OriginalMacRuntimeOverlay`. `run(...,host:)` takes an `OriginalRuntimeStartupHost` (window host, glyph rasteriser, MessageBoxA presenter). The Mac `run(inputs:overlay:environment:maximumAttempts:)` touches `NSApplication.shared` first and passes `.mac`; `Overlay.standard()` (Application Support) stays Mac; the NSAlert presenter is one shared `OriginalMacRuntimeMusic.alert`. | Startup, Menu, Loading, WindowBackend, ObservedIteration, LoadingAudio ×3 27/27 on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime`; full app e2e 9/10 = baseline | 5ffe2dc |
| 2026-10-04 | **P3 result (aarch64)** | **All 251 portable suites ran on Linux: 241 clean, 581 tests passed, 0 failed**, 1 skipped (FixtureInflate's reference is Apple's Compression). 10 heavy `Lib*` suites were OOM-killed in the 11.7 GiB VM before their assertions ran; that is memory, not a mismatch (see P3 memory). Core gives the same results on Linux as on macOS for everything that ran. | [evidence](../evidence/crossplatform-p3-linux-aarch64-20261004.json), per-suite results jsonl; harness `tools/crossplatform/run_linux_suites.py` | 414a2aa |
| 2026-10-04 | P5 step 11c | RuntimeMenu and RuntimeLoading moved to `NTSDRuntime`. The menu takes its Caps Lock read and MessageBoxA presenter. Loading takes `OriginalRuntimeLoadingDialogs` (recording chooser, "Error" alert, document open), still wrapped in `MainActor.assumeIsolated` and with the deferred open after Sleep. The Mac initializers and `bundled(...)` keep NSEvent, NSOpenPanel, NSAlert and NSWorkspace. **NTSDMacPlatform is down to ≈930 lines of AppKit/AVFoundation/Darwin adapters; NTSDRuntime is 25 files, ≈4,040 lines.** | Menu, Loading, NetworkHost, NetworkExit, Startup, LoadingAudio ×3 23/23 on a fresh test build (the first run stopped at the test build: missing `@testable import NTSDRuntime` in five Mac tests); 697 listed; Xcode release; Linux `NTSDRuntime`; full app e2e 9/10 = baseline | 706dc65 |
| 2026-10-04 | process note | **414a2aa does not build.** The docs-only P3 commit also took the step-11c `git mv` renames already staged in the index (RuntimeMenu/RuntimeLoading moved, not yet edited, so AppKit imports sat in NTSDRuntime). 706dc65 restores a building tree. Both were pushed; history was not rewritten. Skip 414a2aa when bisecting. | `git show --stat 414a2aa` | 2f5e707 |
| 2026-10-04 | P5 step 12 | **The app session moved to `NTSDRuntime`:** `OriginalRuntimeSession(arguments:host:)` owns options/scripts, virtual clock, startup → menu → loading → gameplay iteration, captures, network trace, summary, music presentation and the boundary stop, copied line for line. `OriginalRuntimeSessionHost` supplies: startup host, caps lock, sockets, loading dialogs, user data, timing activity, joysticks and their sampling, music and sound output, backing scale, cursor, window attach, captures, full screen, hide, message box, open, stop alert, didStart, terminate, exit. NTSDApp's launcher is now a thin delegate plus `OriginalMacSessionHost` (AppKit input, GameController, AVFoundation output, NSAlert/NSWorkspace, menu). `OriginalMacSoundEffects.backed(by:)` moved to the runtime over `samples(_:)`. The trace digest hashes the concatenated bytes and masks (same SHA-256 as the incremental CryptoKit). | SoundEffects, Startup, Menu, Loading, LoadingAudio ×3 26/26 on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime` (session object verified); **full app e2e 9/10 = baseline** | da2414f |
| 2026-10-04 | **P6 groundwork: first whole game on Linux** | New portable executable `NTSDHeadless` runs `OriginalRuntimeSession` on a headless host: offscreen windows with macOS geometry policy, framebuffer PNGs, silent music on the virtual clock with manifest durations (equal to `AVAudioPlayer.duration` for all 8 tracks), no sockets, blank glyph masks as a declared stand-in. The run loop must drain the main queue on the main thread; `dispatchMain()` failed MainActor isolation. **The app_e2e VS scenario (1,826 bodies, Summary, replay) matches the frozen AppKit reference on every state key, on macOS and in a Linux container (static aarch64, cross-compiled); all 7 captured frames are byte-identical between Linux and macOS.** | `tools/crossplatform/compare_headless.py`: exitCode, boundary, milestones 6, progress 6, overlayFiles equal on both; frame SHA-256 equal; Xcode release build with both executables; 697 listed. [evidence](../evidence/crossplatform-headless-vs-20261004.json) | 5dd1933 |
| 2026-10-04 | **All app_e2e scenarios on Linux** | `tools/crossplatform/run_headless_scenarios.py` runs every app_e2e scenario with app_e2e's own command line (plus `--no-network`) through the cross-built static `NTSDHeadless` in a Linux container, and compares each with its frozen reference. **9/10 equal:** vs, mission, demo, war, tournament, altenter, tournament-win, team-tournament, joystick. playback differs exactly as the AppKit app does on main (the original recording rejected at iteration 251), so the Linux build reproduces the Mac app's behaviour in all ten. | per-scenario compare outputs; [results](../evidence/crossplatform-headless-scenarios-linux-20261004.jsonl); 39–154 s per scenario | f7de972 |
| 2026-10-04 | **x86_64 Linux; Swift 6.4.0 Linux miscompile fixed in Core** | The x86_64 static `NTSDHeadless` crashed (SIGSEGV) in every scenario right after startup, under Rosetta and identically under QEMU 10 user mode. QEMU's gdb stub put it in `OriginalRetainedHistory.Node.deinit`: the open-source Swift 6.4.0 toolchain for Linux never stores the node into the stack slot it passes to the unspecialised generic `isKnownUniquelyReferenced(&node)`. aarch64 Linux has the same code and survived only by chance; Xcode's Swift 6.4 for macOS is correct, so the AppKit app was never affected. A 20-line reproducer crashes or silently truncates shared tails on both Linux arches. Fix: the tail walk moves to a private non-generic link class, called from the node's deinit, so release order and behaviour are unchanged; the check is now specialised to the loaded reference. Independent read-only review: equivalent; its requested unique-then-shared test was added. **x86_64 and aarch64 Linux both reproduce 9/10 app_e2e scenarios exactly (playback as on main), and all 63 frames are identical across both arches and the pre-fix aarch64 run.** The earlier aarch64 results stay as recorded but came from a binary with this undefined behaviour. | release tests: OriginalRetainedHistoryTests 5/5, 699 listed; Xcode release; **AppKit e2e 9/10 = baseline**; [evidence](../evidence/crossplatform-swift640-linux-uniqueness-20261004.json), [reproducer](../evidence/crossplatform-swift640-linux-uniqueness-repro/), [x86_64](../evidence/crossplatform-headless-scenarios-linux-x86_64-20261004.jsonl), [aarch64](../evidence/crossplatform-headless-scenarios-linux-aarch64-20261004b.jsonl) | a72ae97 |
| 2026-10-04 | **P6 step 1: SDL3 backend on macOS** | New `NTSDSDL` (behind `NTSD_SDL=1`, SDL3 3.4.16 from Homebrew via `NTSD_SDL_PREFIX`) runs `OriginalRuntimeSession` on SDL windows with a streaming texture, keyboard (SDL scancodes onto the existing key table), mouse, gamepads, an SDL audio stream for the effects mixer and SDL message boxes; music is silent by manifest duration until P7. On macOS it takes the AppKit host's window metrics (SDL cannot report Cocoa borders), CoreText glyph masks and Darwin Winsock. `NTSDRuntime` now keeps each window's last presented crop and writes it with one portable encoder (`--body-frames`, `--body-frame-every`, script `frame`). **All app_e2e scenarios: SDL 9/10 like AppKit, and all 51 presented frames byte-identical between SDL and AppKit;** Linux headless 9/10 on both arches with identical frames; Linux vs AppKit frames differ only in text pixels. | release tests 70/70 (affected runtime classes + new `OriginalFramebufferPNGTests`), 701 listed; Xcode release without SDL; AppKit with `--body-frames` equal to the full reference incl. capture hashes; [evidence](../evidence/crossplatform-p6-sdl-macos-20261004.json), `tools/crossplatform/compare_frames.py` | 6b6ed02 |
| 2026-10-04 | **P6 step 2: whole matches frame by frame** | `--body-frame-digests` reports the SHA-256 of every presented frame; the scenario runner turns it on and `compare_frames.py` compares the sequences. **AppKit vs SDL: all 15,909 per-body frames (plus the 51 PNGs) identical across the 10 scenarios; Linux aarch64 vs x86_64 likewise.** Linux vs AppKit: 6,698/15,909 equal, the rest are frames with text, which the Linux host does not rasterise yet. State 9/10 on all four hosts (playback as on main). | official app_e2e 9/10 = baseline; [AppKit vs SDL](../evidence/crossplatform-p6-frame-digests-appkit-sdl-20261004.jsonl), [Linux arches](../evidence/crossplatform-p6-frame-digests-linux-arches-20261004.jsonl) | 50c19ea |
| 2026-10-04 | **P7 groundwork: SDL build on Linux** | `tools/crossplatform/build_linux_deps.sh` builds SDL3 3.4.16 (X11, Wayland, PulseAudio, PipeWire, ALSA, offscreen, dummy) and static FreeType 2.13.3 for Linux in a `swift:6.4.0-noble` container from hash-checked tarballs. `NTSDSDL` cross-builds on this Mac with the generated glibc SDK against that SDL3 and runs in the container with SDL's offscreen video and dummy audio. **All scenarios: 9/10 like every other host, and all 15,960 frames identical to the Linux headless run.** | [evidence](../evidence/crossplatform-p7-linux-sdl-20261004.json), [results](../evidence/crossplatform-p7-linux-sdl-aarch64-20261004.jsonl) | 4bbf311 |
| 2026-10-04 | **P7: text on Linux** | Non-Apple `NTSDSDL` rasterises TextOutA with a static FreeType: 13 px em, monochrome, baseline at row 13, the same mask contract as CoreText. Following the user's font decision (SYSTEM_FONT ships with Windows, not the game), it uses the standard Linux font whose widths best match the macOS stand-in: DejaVu Sans Condensed Bold within ±3 px, then Liberation, Noto, FreeSans, then fontconfig's sans-serif bold; plain DejaVu Sans is 15 % wider and clipped the selection screen. **All scenarios: state 9/10; text appears in exactly the same 9,211 of 15,909 frames as on AppKit, and the 6,698 text-free frames are identical.** macOS SDL unchanged (VS 1,832/1,832 frames equal AppKit). | [evidence](../evidence/crossplatform-p7-glyphs-20261004.json), [text frames](../evidence/crossplatform-p7-text-frames-20261004.jsonl), `compare_text_frames.py` | 3e3c712 |
| 2026-10-04 | **P7: X11 window and real input** | `linux_x11_smoke.sh` runs `NTSDSDL` on Xvfb with SDL's x11 driver in real time with no script, driven by `xdotool`: the window opens at the client size and centre the game was told (794×550 at 243,237 on 1280×1024), and real mouse and keyboard input goes through START, mode and character selection to a Naruto/Sasuke District match (matchLaunched, gameplay, 400 bodies, clean exit). Presses must last like physical ones (150 ms): the game reads input once per iteration and missed xdotool's instant clicks; input during loading is lost, as expected. | [evidence](../evidence/crossplatform-p7-x11-input-20261004.json) | de3ad55 |
| 2026-10-04 | **P7: music without AVFoundation** | Apple's ALAC reference decoder (Apache-2.0, 13 files vendored unchanged) behind a C interface, and a Swift CAF reader in the new `NTSDMusicDecoder`, decode the packaged tracks; `NTSDSDL` plays them on SDL audio streams through the shared `OriginalMacMusicOutput`. **Every track decodes to exactly the manifest's PCM (frames, bytes, SHA-256) on macOS and on Linux.** The first Linux run failed: the vendored code takes the byte order from Apple headers or x86 macros only, so aarch64 Linux skipped its byte swaps; the manifest now defines it for non-Apple targets. Silent decode failures are now reported. SDL with music: 9/10 and all frames unchanged on macOS and Linux. | `OriginalALACTrackTests` 2/2 macOS release and Linux; [evidence](../evidence/crossplatform-p7-music-20261004.json), [Linux before fix](../evidence/crossplatform-p7-music-linux-suite-before-fix-20261004.jsonl), [after](../evidence/crossplatform-p7-music-linux-suite-20261004.jsonl) | 7c504a6 |
| 2026-10-04 | **P7: ONLINE GAME on Linux** | The BSD-socket Winsock moved into `NTSDRuntime` (name kept) and runs on Darwin, glibc and musl; `NTSDSDL` uses it everywhere. Linux needed errno mapping to the BSD numbers behind WSAE codes, MSG_NOSIGNAL, Winsock-number argument checks, and a readiness fix: the game selects before `listen()`, Linux reports that socket as hung up, which first produced the game's own "Accpet() Error" box and then left Dispatch not watching (strace: the host never accepted); watching now starts once the socket listens or connects (Darwin unchanged). **The retained two-process ONLINE GAME probe passes between two Linux processes, two macOS SDL processes and two AppKit processes, all with the RNG hash of the retained 2026-10-02 run.** | Winsock tests now portable: macOS 17/17 network tests, Linux 8/8; app_e2e 9/10 = baseline; `pair_probe.py`; [evidence](../evidence/crossplatform-p7-sockets-20261004.json) | 927f319 |
| 2026-10-04 | **P7: Linux package** | `package_linux.py` cross-builds `NTSDSDL` with a static Swift runtime and assembles `ntsd-linux-aarch64` (the game, `libSDL3.so.0` beside it via `$ORIGIN`, the resource bundle, the packaged music, licences for SDL3, FreeType, ALAC and Swift, a README) into a reproducible 217 MB tar.gz with a per-file manifest; `NTSDSDL` now finds `OriginalMusic` beside itself. **In a plain Ubuntu 24.04 container without Swift the unpacked package resolves every library, starts with music and font found, reaches a match with real X11 input, and reproduces the vs scenario with identical frames.** Local artefact only. | `check_linux_package.sh`; [evidence](../evidence/crossplatform-p7-linux-package-20261004.json) | 0f91b25 |
| 2026-10-04 | **P7: package reproducibility** | Rebuilt from 0f91b25 with the same scratch path, the package differs from the first build only in `README.txt` (it names the commit); the binary is byte-identical. From a fresh scratch path the binary differs: it embeds its absolute scratch path 21 times (bundle accessor, build paths). Reproducible from the canonical scratch path; cross-path reproducibility would need path remapping. | [evidence](../evidence/crossplatform-p7-package-reproducibility-20261004.json) | ee2c6b8 |
| 2026-10-04 | **P7: Linux x86_64 package** | Generated the x86_64 glibc SDK (`ntsd-6.4.0-ubuntu24.04-x86_64`, same generator and options), built SDL3/FreeType for linux/amd64, and packaged `ntsd-linux-x86_64` with `package_linux.py --arch x86_64`. **In a clean amd64 Ubuntu 24.04 container (Rosetta harness) it resolves every library, starts with music and font, reaches a match with real X11 input and reproduces the vs scenario; all 1,832 frames, FreeType text included, equal the aarch64 package's.** | `check_linux_package.sh … linux/amd64`; [evidence](../evidence/crossplatform-p7-linux-package-x86_64-20261004.json) | e1eb5b8 |
| 2026-10-04 | **P0-W: first Windows executable** | The UCRT xwin downloads is 10.0.26624, which has no `corecrt_math.h`, `stdnoreturn.h` or `stdalign.h` (math lives in `math.h`); Swift 6.4's `ucrt.modulemap` expects an older layout. A reviewed patch removes those three modules in a copy of the SDK; MSVC 14.29 with SDK 10.0.22621 builds the modules (14.44's `threads.h` does not), and the SDK library folders are passed to lld-link explicitly. **A Swift 6.4 probe with Foundation cross-compiles to a PE32+ x86-64 exe and runs in a CrossOver bottle with the Swift runtime DLLs, printing the same results as macOS except the LLP64 `long` size.** | `windows_probe.sh`; [evidence](../evidence/crossplatform-p0w-probe-20261004.json) | c8f475b |
| 2026-10-04 | **P0-W: the game on Windows (headless)** | `make_windows_sdk.py` builds a Swift SDK bundle for `x86_64-unknown-windows-msvc`; SwiftPM's native build system cross-builds `NTSDHeadless` (swift-build has no Windows platform here). Fixes on the way: Clang's builtin headers linked into the SDK (otherwise MSVC's `iso646.h` pulled a C++-only module into C builds), `math.h` mapped to `corecrt.math` where the prebuilt Foundation module expects `pow`, a Windows branch for the startup clock, and an `OriginalFileFacts` helper for the input loaders (Windows reads file attributes natively; under Wine, Foundation's own path hits the unimplemented `SaferiIsExecutableFileType` and hung). Other hosts keep their exact code paths. **In a CrossOver test bottle the Windows exe reproduces 9/10 app_e2e scenarios (playback as on main) and all 15,960 frames equal the Linux headless run.** | macOS loader/startup tests 24/24, 703 listed; Linux musl builds; **AppKit e2e 9/10 = baseline**; `run_headless_scenarios.py --wine`; [evidence](../evidence/crossplatform-pw-headless-20261004.json), [results](../evidence/crossplatform-pw-headless-wine-20261004.jsonl) | d02c20b |
| 2026-10-04 | **P7 Windows: SDL build with GDI text** | `NTSDSDL` cross-builds for Windows against libsdl's official SDL3 3.4.16 VC package (rpath only on macOS/Linux, signed SDL enums under MSVC, C/C++ on the DLL runtime like Swift). On Windows text goes through GDI: TextOutA with the stock SYSTEM_FONT, the original's own font on real Windows (Wine substitutes its own). Sockets stay off on Windows until a real-Winsock adapter exists. **In the CrossOver bottle (offscreen/dummy SDL drivers) all scenarios give 9/10 like every host, and text appears in exactly the same 9,211 of 15,909 frames as on AppKit.** | macOS and Linux SDL still build (RUNPATH kept); [evidence](../evidence/crossplatform-pw-sdl-20261004.json), [results](../evidence/crossplatform-pw-sdl-wine-20261004.jsonl) | 6dfc200 |
| 2026-10-04 | **P7 Windows: package** | `package_windows.py` assembles `ntsd-windows-x86_64` (NTSDSDL.exe, SDL3.dll, the Swift and MSVC runtime DLLs from the Swift installer, resources, packaged music, licences) into a reproducible 219 MB zip with a manifest. **In a freshly created CrossOver bottle the unpacked package starts with its own music and GDI text and reproduces the vs scenario.** Local artefact only; ONLINE GAME is off until a Winsock adapter exists. | `check_windows_package.sh`; [evidence](../evidence/crossplatform-pw-package-20261004.json) | e300149 |
| 2026-10-04 | **P7 Windows: ONLINE GAME** | `OriginalWindowsWinsock` answers the original's Winsock calls with the real Winsock 2 stack under the BSD adapter's declared contract; readiness comes from a WSAPoll watcher thread, since the runtime has no real window for WSAAsyncSelect, and bind keeps Windows' default (no SO_REUSEADDR, which on Windows would let the client take the host's port). **The retained two-process ONLINE GAME probe passes between two NTSDSDL.exe processes in the CrossOver bottle, with the same RNG table as every other host and the original run.** | `pair_probe.py --wine`; [evidence](../evidence/crossplatform-pw-winsock-20261004.json), [result](../evidence/crossplatform-pw-pair-wine-20261004.json) | a8ed861 |
| 2026-10-04 | **P8 step 1: iPad (simulator)** | New `NTSDiOS` (behind `NTSD_IOS=1`): a UIKit scene app on `OriginalRuntimeSession` with one view showing frames scaled to fit, touch as mouse, hardware keyboard through the shared `OriginalHIDKeys`, CoreText masks with the iOS system font, AVAudioEngine effects, Darwin sockets. SwiftPM builds it for the simulator triple and `ios_app.py` wraps, installs and runs it. Resources go at the app root (the loaders' `.app` rule); events go to a file (simctl did not forward stdout); scripted muted runs open no audio output, since the simulator's CoreAudio aborted the app. **All scenarios: 9/10 like every host, and all 15,960 frames byte-identical to the AppKit app's.** | macOS release and Linux builds compile; [evidence](../evidence/crossplatform-p8-ios-20261004.json), [results](../evidence/crossplatform-p8-ios-sim-20261004.jsonl) | 8f6d1eb |
| 2026-10-04 | **Cross-host matrix baseline** | `matrix.py` builds and runs the app_e2e scenarios on every host this Mac drives and compares state and frames. With the Mac's screen locked (from 12:20) the AppKit app stalled, so the AppKit and macOS SDL hosts are reported as blocked and the other six ran: **iPad simulator, Linux headless aarch64 and x86_64, Windows headless, Linux SDL and Windows SDL all give 9/10 (playback as on main); the three textless hosts agree on all 15,960 frames, and FreeType (Linux SDL) and GDI (Windows SDL) put text in exactly the same 9,211 of 15,909 frames as CoreText (iPad).** Correction found on the way: CrossOver drops `SDL_*` variables, so the earlier Windows SDL runs used a real Wine window and WASAPI, not offscreen/dummy as recorded (their results stand); `NTSDSDL` now takes the drivers as hints from `NTSD_SDL_*`. | [report](../evidence/crossplatform-matrix-20261004.json), [correction](../evidence/crossplatform-pw-sdl-drivers-correction-20261004.json) | 87edc32 |
| 2026-10-04 | **Matrix baseline, all eight hosts** | With the screen unlocked (and kept awake with `caffeinate`), `matrix.py --reuse` added the AppKit app and macOS SDL. **On the clean tree e752f9c every host (AppKit, macOS SDL, iPad simulator, Linux headless aarch64/x86_64, Windows headless, Linux SDL, Windows SDL) gives 9/10 (playback as on main); AppKit, macOS SDL and the iPad agree on all 15,960 frames, the textless hosts on all 15,960, and FreeType and GDI put text in the same 9,211 of 15,909 frames as CoreText.** | [report](../evidence/crossplatform-matrix-20261004-full.json) | 59cb328 |
| 2026-10-04 | **P8: iPad music** | The iPad host plays the packaged tracks through AVAudioPlayer, as the macOS host does. With the screen unlocked AVAudioEngine starts in the simulator: the earlier abort came from the locked session. **The iPad host still gives 9/10 with frames identical to AppKit across all scenarios.** | [evidence](../evidence/crossplatform-p8-ios-music-20261004.json) | 3045f07 |
| 2026-10-04 | **P7: Wayland** | `linux_wayland_check.py` runs the Linux SDL build on SDL's Wayland driver under headless Weston. The first run had equal state but every frame shifted by the centred window origin: Wayland exposes no window positions, so the host now reports where it placed the window. `NTSDSDL` also reports the drivers SDL chose (`sdlDrivers`). **vs scenario equal, all 1,832 frames identical to the Linux SDL run.** | [evidence](../evidence/crossplatform-p7-wayland-20261004.json) | db3e341 |
| 2026-10-04 | **Swift miscompile reported** | With the user's approval, filed [swiftlang/swift#92905](https://github.com/swiftlang/swift/issues/92905). A rerun of the issue's short program narrowed the scope: **only the Static Linux (musl) SDK drops the store** (both arches crash 3/3); the glibc aarch64 SDK and macOS compile it correctly. The first filed text overstated the scope and was corrected in place. The Core workaround stays. | [evidence](../evidence/crossplatform-swift640-report-20261004.json) | b13b1de |
| 2026-10-04 | **P8 Android: first build** | Installed the Swift 6.4.0 Android SDK (checksum from swift.org's release data) and removed the unused 6.3.3 one. With NTSD_PORTABLE the whole headless game compiles for `aarch64-unknown-linux-android28`; only the socket adapter needed a Bionic branch (its own `h_errno` accessor, a named `net_device_flags` enum, and a non-null buffer for `send`). Linux-kernel behaviour already sits under `!canImport(Darwin)`. **Compile only, not run yet**; the static-runtime link needs `std::__hash_memory` (the runtime was built with Android clang 21–22). | macOS app release build, Linux musl and glibc builds | this commit |

## Next task

Inputs received 2026-10-04: the user accepted the Android SDK licences
(`sdkmanager --licenses`), approved publishing the Linux and Windows packages
and approved reporting the miscompile (done, #92905). Installed with Homebrew's
`sdkmanager` into `/opt/homebrew/share/android-commandlinetools` (7.8 GB):
platform-tools 37.0.1, emulator 37.2.12, NDK 27.3.13750724, platform 35 and
the `android-35;google_apis;arm64-v8a` system image.

1. **Publish the packages**: rebuild `ntsd-linux-aarch64`, `ntsd-linux-x86_64`
   and `ntsd-windows-x86_64` from a clean committed tree (the Wayland fix
   changed `NTSDSDL`), rerun `check_linux_package.sh` and
   `check_windows_package.sh`, then publish them as a GitHub pre-release of
   `wowlocal/ntsd-2.4` with SHA-256 sums and notes that state what was tested
   (containers, Wine) and what was not (real hardware).
2. **Android (P8)**: get the Swift 6.4.0 Android SDK matching the toolchain,
   build the portable products for `aarch64-unknown-linux-android`, then an
   app host (SDL3's Android Java glue or a NativeActivity) and run the
   scenarios in the arm64 emulator.

Still waiting on the user: real-hardware checks (Linux desktop, Windows PC,
iPad).

Following tasks:

- P3 x86_64 tests: the headless game passes on x86_64; the portable XCTest
  suites there need an x86_64 glibc SDK. Rosetta is a test harness; label it
  so.
- P0-W history (license accepted 2026-10-03). `xwin` 0.10.0 splats are on
  X5: MSVC 14.44.17.14 + SDK 10.0.26100 (`winsysroot`) and MSVC 14.29 + SDK
  10.0.22621 (`winsysroot-vs16`).
  - `swiftc -target x86_64-unknown-windows-msvc -sdk <Windows.sdk>` with
    `-visualc-tools-root <winsysroot>/VC/Tools/MSVC/14.44.17.14`,
    `-windows-sdk-root "<winsysroot>/Windows Kits/10"`, `-windows-sdk-version`
    and `-use-ld=lld` gets as far as the UCRT module.
  - Both splats use the same `ucrt.msi` (SHA-256 prefix 54448641…). It lacks
    `corecrt_math.h`, `corecrt_math_defines.h` and `stdnoreturn.h`, which
    Swift 6.4's `ucrt.modulemap` names; they are not in the unpacked cache
    either.
  - Next: get the full UCRT headers. The Windows SDK installer's "Universal
    CRT Headers Libraries and Sources" package is the candidate; check whether
    its terms are covered before downloading. Otherwise add audited shims plus
    a patched copy of the modulemap: removing `corecrt.math` moved the error on
    to `stdnoreturn.h`.
