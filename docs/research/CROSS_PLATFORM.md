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
| 2026-10-04 | P5 step 10 | `OriginalRuntimeSockets` covers every Winsock call the original makes, plus `lastError`/`boundPort` and FD_* `post`. `OriginalRuntimeSocketNotification` and the pure `OriginalRuntimeSocketText` (inet_addr/ntoa/htons) are in `NTSDRuntime`. `OriginalMacRuntimeNetwork` moved there and takes its sockets; the Mac `init(localAddresses:)` supplies `OriginalMacWinsock`, whose statics forward. The first gate run stopped at the test build: the protocol lacked `boundPort`/`lastError`. | Winsock, NetworkHost, NetworkExit, RuntimeMenu, RuntimeLoading 23/23 on a fresh test build; 697 listed; Xcode release; Linux `NTSDRuntime`; full app e2e 9/10 = baseline (including vs's online check) | this commit |

## Next task

P5 step 11, the remaining Mac files and the composition root. Left in
NTSDMacPlatform: RuntimeLoading (NSOpenPanel/NSAlert/NSWorkspace), RuntimeMenu
(NSAlert, caps lock), FrontService (needs only the runtime window backend),
RuntimeStartup (composition, `NSApplication.shared`), and the AppKit/AVFoundation
adapters.

- Move FrontService.
- Split RuntimeLoading and RuntimeMenu by injecting their dialogs and caps-lock
  reads.
- Add a runtime composition `OriginalRuntimeStartup.run(host:)` that the Mac
  wrapper calls.
- Then P6: an SDL3 host on macOS implementing `OriginalRuntimeWindowHost`,
  `OriginalRuntimeWindowing`, audio output and input, compared with the AppKit
  host on the same deterministic replay.

Following tasks:

- P3 x86_64: repeat on `x86_64` with a second generated SDK. Rosetta is a
  test harness; label it so.
- P5: the shared runtime extraction on macOS can start in parallel with long
  Linux runs.
- P0-W, continued (license accepted 2026-10-03). `xwin` 0.10.0 splats are on
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
