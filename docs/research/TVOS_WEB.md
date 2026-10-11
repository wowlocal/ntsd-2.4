# TW — Apple TV and Web hosts

Workflow: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md); parent
study [CROSS_PLATFORM](CROSS_PLATFORM.md) (its phases P0–P8: Linux, Windows,
iPad, Android); gates and measurement from [CORE_REALTIME](CORE_REALTIME.md) and
[MEMORY_LOADING](MEMORY_LOADING.md).

**Reason:** user request 2026-10-11, after the real-time and memory/loading
work was merged into `main`: "теперь изучи как ты делал кросскомпиляцию игры и
поддержку android/linux/windows/ios/ipad. хочу чтобы ты сделал хороший
качественный харнес и запустил loop с сборкой поддержки apple tv и web (вроде
как swift умеет компилироваться в wasm)".
**Status:** research and transfer.
**Branch:** `exp/tvos-web`, from `main` 6b4bffd. Local only: it has no
upstream, so the post-commit hook's push fails harmlessly. Publishing it,
merging into `dev/crossplatform`/`main`, enabling CI or publishing builds need
the user.
**Game result:** unchanged by definition. A new host answers the same
`OriginalRequestExchange` requests as every other host; Core and Runtime
changes are behaviour-neutral portability patches only.
**Reference:** the pinned EXE (SHA-256 `3f7ac67c…ff71c`) is not touched. The
comparators are the frozen app_e2e references (10 scenarios,
`tools/app_e2e_*_reference.json`), the frame references by text-rasteriser
group (`matrix.py`: `none` = headless/`m1-frames-ref`, `coretext` = AppKit/iOS,
`freetype` = SDL/Android, `gdi`), `compare_text_frames.py` across groups, and
the Core suites.

## Consumers and integration criteria

- **Apple TV (tvOS).** The iOS host (`NTSDiOS`, UIKit) built for tvOS runs in
  the Apple TV simulator: every app_e2e scenario equal and its frames identical
  to the `coretext` group (iOS draws text with CoreText). Then input as on a
  TV: the Siri Remote and game controllers through GameController (the AppKit
  host's sampler), the Menu button, focus, overlay storage that tvOS keeps
  (no Documents), presentation at 1080p and 4K. A real Apple TV run stays open
  until a device is available.
- **Web, terminal first (WASI).** `NTSDHeadless` built with swift.org's
  WebAssembly SDK (`swift-6.4.0-RELEASE_wasm`, `wasm32-unknown-wasip1`) runs
  under a WASI runtime with the packaged data mapped in: every scenario equal,
  frames identical to the `none` group (`m1-frames-ref`). The WASI runtime is a
  test harness, as Rosetta and Wine are for other hosts.
- **Web, browser.** A browser host (`NTSDWeb`): the framebuffer drawn to a
  canvas, keyboard and gamepad input, effects and music through Web Audio, the
  data delivered to the page. A headless Chromium run (Playwright) of every
  scenario equal; frames identical to the `none` group outside text, and text in
  the same frames (`compare_text_frames.py`) when the page draws text. Then
  frame time and memory in the browser, and how the ~840 MB of data reach a
  player (a decision for the user once measured).

## Verified starting point (2026-10-11, 6b4bffd)

- Hosts: Headless, SDL (Linux/Windows), iOS/iPad (`NTSDiOS`, UIKit, CGImage
  layer contents, touch → `OriginalRuntimeTouchMouse`, `UIPress` → HID keys, no
  GameController, AVAudioEngine + AVAudioPlayer, overlay in Documents), Android,
  AppKit. Host contract: `OriginalRuntimeSessionHost`
  (`OriginalRuntimeSession.swift:10-62`), `OriginalRuntimeStartupHost`,
  `OriginalRuntimeWindowHost` (XRGB8888 frames), music player, sockets, loading
  dialogs, overlay; static hooks `OriginalConcurrentInputs.parallelLoop` /
  `backgroundStart`, `OriginalDeferredRelease.threadStart`,
  `PortableSHA256.install`.
- `native/Package.swift`: `platforms: [.macOS(.v14), .iOS(.v17)]` (tvOS
  missing); switches `NTSD_PORTABLE`, `NTSD_IOS`, `NTSD_ANDROID`, `NTSD_SDL`,
  `NTSD_UNCHECKED_EXCLUSIVITY`; cross-module optimization for Core and Runtime.
- Xcode: tvOS 27.0 device and simulator SDKs; simulator device types Apple TV
  4K (2nd/3rd generation, 1080p and 4K). Installed simulator runtime: iOS 26.5
  only — the tvOS runtime is being installed (`xcodebuild -downloadPlatform
  tvOS`).
- WebAssembly: `swift-6.4.0-RELEASE_wasm` installed with the open-source 6.4.0
  toolchain (archive checksum `f07b7be3…aa86d` verified by `swift sdk
  install`). Target `wasm32-unknown-wasip1`, single-threaded. It provides
  Foundation (Essentials, Internationalization with ICU, XML), Synchronization,
  XCTest and Testing, **but no Dispatch**: every `DispatchQueue` use in Runtime
  and the hosts needs a WASI path.
- Browser tooling: Playwright's Chromium and headless shell
  (`~/Library/Caches/ms-playwright`), Node via fnm, Google Chrome. No
  `wasmtime`/`wasmer`.
- Portability facts (study of 2026-10-11): threads in Runtime and Core
  (`OriginalConcurrentInputs.Background` with a `Thread` and `NSCondition`,
  `map` through `DispatchQueue.concurrentPerform`, `OriginalDeferredRelease`'s
  thread, the display backend's serial render queue, `DispatchQueue.main`
  scheduling in TouchMouse, shell and loading open, the headless host's
  `RunLoop.main.run()`); OS imports that branch on Darwin/Glibc/Musl/Android/
  Windows only (`OriginalFileFacts.swift`, `OriginalMacStartupClock.swift`,
  `OriginalMacWinsock.swift`); time zones feed game state (TZ `Etc/GMT-1`);
  every packaged file is digested at load (~726 MB) with `PortableSHA256` off
  Apple; C targets `NTSDReplayCodec` (zlib 1.1.4) and `CALAC`; peak ~565 MiB
  on the A12 with music off; wasm32 addresses 4 GiB.

## Boundaries

- One Core. No per-platform gameplay branches, no second engine, no change to
  simulation behaviour. A Core or Runtime edit is a behaviour-neutral
  portability patch (conditional import, single-threaded fallback that runs the
  same work in the same order, clock source) that every existing host's gates
  still pass unchanged.
- Fixtures, expected bytes, masks, frozen plans and frame references are
  immutable. A difference on a new host is a recorded mismatch, never a new
  expected value.
- The AppKit app and the existing hosts must not regress: every increment that
  touches Core, Runtime or `Package.swift` runs their gates.
- Performance is not traded (user, 2026-10-11): an increment that touches
  shared code keeps load time and the A12's per-tick time unchanged (the
  `mlgate.sh` phone and Mac A/B with music and sounds).
- No emulation in a shipping runtime. The WASI runtime and the simulators are
  test harnesses; a browser is the Web host's real platform.
- Downloads: toolchains and SDKs only from their vendors (Apple, swift.org,
  npm for Playwright pieces already present), with published checksums where
  they exist; record each in the ledger. Installing paid or licensed software,
  publishing, CI and pushes need the user.
- Storage: build products on X5 (keep 20 GiB free), archives on T7 (keep
  40 GiB free); verify mounts first.

## Harness

One output layout for every host, so the existing comparators judge them all:
`OUT/<scenario>/events.jsonl`, `OUT/<scenario>/frames/f*.png` (`--body-frames`),
the frame digests in the events, the overlay files and the exit code — what
`run_headless_scenarios.py` writes and `compare_headless.py`,
`compare_frames.py`, `compare_text_frames.py` and `matrix.py` read. Every runner
passes app_e2e's own command line for the scenario (virtual clock, scripted
input, TZ `Etc/GMT-1`, `--events-file` where stdout is not forwarded).

| Runner | Host | What it does |
| --- | --- | --- |
| `ios_app.py --platform tvos` (extend, not a new script) | Apple TV simulator | Builds `NTSDiOS` for `arm64-apple-tvos17.0-simulator`, assembles the `.app` (Info.plist for tvOS, ad-hoc signed), boots an Apple TV 4K simulator, installs, launches with the scenario's arguments, copies events and frames out of the data container |
| `run_headless_scenarios.py --wasi WASM` (a mode of the existing runner) | WASI runtime (test harness) | Runs the `.wasm` headless build with the scenario's arguments, the packaged data and overlay preopened; the same output as `--local` |
| `web_app.py` (new: no runner drives a browser) | Headless Chromium (Playwright) | Builds the browser target, serves page, `.wasm` and data locally, opens the page with the scenario's arguments, collects events and frames through the page's bridge into the same layout |
| `matrix.py` rows | all | Adds `tvos-sim` (`coretext`), `wasi` (`none`) and `browser` (its own text group, or `none` without text) |

Harness acceptance: each runner reproduces an existing host's result first
(the tvOS runner and the iPad runner agree on the iPad; the WASI mode runs the
Mac headless binary's scenario set through the same code path; the browser
runner's bridge round-trips a frame byte for byte) before it judges a new host.

## Gates (every increment)

1. Clean builds of every product the increment touches (cross-module
   optimization leaves stale incremental builds).
2. New host: the increment's scenarios equal and frames identical within the
   host's text group; failures kept with their logs.
3. Existing hosts when Core, Runtime or `Package.swift` change: headless vs and
   all 10 scenarios with frames identical (`m1-frames-ref`), AppKit vs and
   playback, the Android emulator's vs frames, the affected Core suites in a
   release test build — the `mlgate.sh` set, including the A12 load and
   per-tick A/B with music and sounds.
4. An independent read-only review for each host layer, threading change or
   Core/Runtime portability patch; its follow-ups before the gate or recorded.
5. One commit per checked increment on `exp/tvos-web`, staging only its files
   (the tested tree), with evidence in `docs/evidence/tw-*.json`.

## Plan

| ID | Step | Status |
| --- | --- | --- |
| H0 | Harness: `ios_app.py --platform tvos`, `run_headless_scenarios.py --wasi`, `web_app.py`, `matrix.py` rows; each first reproduces an existing host's result | queued |
| T0 | tvOS: simulator runtime; `.tvOS(.v17)` in `Package.swift`; `NTSDiOS` builds for tvOS (`#if os(tvOS)`: no touch, no Documents, presses only); vs in the Apple TV simulator equal, frames identical to `coretext` | queued |
| T1 | tvOS: all 10 scenarios; GameController input (Siri Remote, extended gamepads) through the AppKit sampler's mapping; Menu button and focus | queued |
| T2 | tvOS: overlay storage tvOS keeps, 1080p/4K presentation, audio session, lifecycle (background/foreground) | queued |
| W0 | WASI: `NTSDHeadless` builds for `wasm32-unknown-wasip1` — WASI branches for OS imports, single-threaded paths for the read-ahead, parallel loads, deferred release and the render queue, a scheduler without Dispatch; vs under a WASI runtime equal | queued |
| W1 | WASI: all 10 scenarios equal, frames identical to `m1-frames-ref`; load time and memory measured | queued |
| W2 | Browser: `NTSDWeb` host (canvas presenter, keyboard and gamepad, Web Audio effects and music, data delivery); vs in headless Chromium equal | queued |
| W3 | Browser: all scenarios; frame time per tick and memory in the browser; data delivery options measured for the user's decision | queued |

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-11 | Study and setup | Read the cross-platform work (hosts, packaging, harness, pitfalls); branch `exp/tvos-web`; wasm SDK installed (checksum verified; Foundation without Dispatch); tvOS simulator runtime download started; this card | this card | this commit |

## Next task

H0 + T0 together (the tvOS runner can only be accepted against a tvOS
build): once the tvOS simulator runtime is installed, add `.tvOS(.v17)`,
build `NTSDiOS` for `arm64-apple-tvos17.0-simulator` with the `#if os(tvOS)`
changes it needs, extend `ios_app.py` with `--platform tvos` (Info.plist,
device type, data container), check the runner still reproduces the iPad
result, then run vs on an Apple TV 4K simulator and compare with the
`coretext` group. In parallel (independent): try the first `wasm32-unknown-wasip1`
build of `NTSDCore` to list the WASI blockers for W0.
