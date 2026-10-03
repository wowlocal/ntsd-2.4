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
- Pushing branches, enabling CI, publishing releases or installing paid or
  licensed software needs the user's confirmation. Everything else in this
  plan is authorized for the loop.

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

| Target | SDK built on this Mac | Test harness here | Real observation |
| --- | --- | --- | --- |
| Linux x86_64/aarch64, headless | Swift Static Linux SDK 6.3.3 (musl), checksum from swift.org, same version as the host toolchain | OrbStack container; aarch64 native, x86_64 under Rosetta | Linux host |
| Linux desktop (SDL3) | glibc Swift SDK (e.g. `swift-sdk-generator` from an Ubuntu 24.04 image), since static musl cannot `dlopen` SDL's video/audio drivers; SDL3 built for that sysroot | container with virtual display/audio for smoke runs | Linux desktop |
| Windows x86_64 (arm64 later) | `*-unknown-windows-msvc`: Windows SDK headers/libs plus the Swift Windows runtime; feasibility with 6.3.3 is unproven and is P0's question | CrossOver/Wine, test only | Windows PC |
| Android arm64 | installed `swift-6.3.3-RELEASE_android` + NDK | emulator/device | device |
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
- At most three failed rounds per mechanism; then diagnose before the next run.
- Long builds and test runs go to the background with recorded PID and command.
  A quiet log is not a stopped job.
- If the next task is blocked, record the blocker with evidence, take the next
  independent task, and list the exact input needed from the user.

## Status ledger

| Date | Phase | Result | Checks | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-03 | — | Plan and inventory written | text/links only | this commit |

## Next task

P0: install the Swift Static Linux SDK matching 6.3.3 (verify its checksum),
cross-build and run a Foundation/Dispatch probe for `aarch64-swift-linux-musl`
in an OrbStack container, then try `swift build --target NTSDCore` for that
triple and record the first failures.
