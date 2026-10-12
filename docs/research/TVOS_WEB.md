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
**Branch:** `exp/tvos-web`, from `main` 6b4bffd. Pushed to GitHub with the
user's approval (2026-10-11: "публикуй на github, без проблем"); it tracks
`origin/exp/tvos-web` and the post-commit hook pushes every commit. Merging
into `dev/crossplatform`/`main`, enabling CI or publishing builds still need
the user.
**Hosting (user, 2026-10-11):** test locally; for publishing later the user
plans Vercel and wants it free or at minimal cost (no income from it). W3
measures what a player must download (data after compression, what is
needed before the first frame, the `.wasm` size) and compares free tiers
(checked 2026-10-11: Vercel Hobby 100 GB/month, 100 MB per file; Cloudflare
R2 10 GB with free egress; Cloudflare Pages 25 MiB per file). The data are
the original game's files: publishing them is the user's call; a page that
opens the player's own copy avoids distributing them.
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
| `run_headless_scenarios.py --browser WASM` with `web_run.mjs` (done, W2a) | Headless Chromium or WebKit (Playwright's cached builds; `NTSD_BROWSER_ENGINE=webkit`) | The same `.wasm` in a page: `web/wasi-worker.js` (a WASI preview-1 shim in a worker: lazy files over synchronous XHR, writes uploaded, read-only `/app` and `/music`, `Atomics.wait` sleeps), a local `node:http` server with cross-origin isolation; the same output as `--wasi`, plus `browser-metrics.json` (linear memory, seconds, user agent) |
| `web_app.py` (W2b) | Headless Chromium (and WebKit) | The browser host proper (canvas, input, audio): serves page, `.wasm` and data, opens the page with the scenario's arguments, collects events and frames into the same layout |
| `matrix.py` rows | all | Adds `tvos` (`coretext`, done), `wasi` (`none`) and `browser` (its own text group, or `none` without text) |

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
| H0 | Harness: `ios_app.py --platform tvos` and the `tvos` matrix row (done, T0), `run_headless_scenarios.py --wasi`, `web_app.py`; each first reproduces an existing host's result | partly done |
| T0 | tvOS: simulator runtime; `NTSDiOS` builds for tvOS (`#if os(tvOS)`); vs in the Apple TV simulator equal, frames identical to `coretext` | **done** |
| T1 | tvOS: all 10 scenarios (T1a done). **T1b (user, 2026-10-11: "надеюсь мы на apple tv сделаем поддержку джойстиков"):** Bluetooth gamepads (Xbox, PlayStation, MFi) as the game's joysticks through GameController, as the AppKit host does, in one implementation shared by AppKit, the iPad and Apple TV (done); the Siri Remote as keys for the menus (done: swipes and the 2nd-generation ring as arrows, its centre or a click as Enter; Menu unmapped because Esc always asks to quit; GCEventViewController keeps gamepad presses away from UIKit). Open: a hand check with a real controller (connected to the Mac for the simulator, or a device), Menu during startup and the Mac keyboard in the tvOS simulator, Menu at the root before App Store distribution | **done** (hand checks open) |
| T1c | Android gamepads (user, 2026-10-11: "ну и геймпад также будет поддерживаться для ios/android сборок?"): the NativeActivity host reports 0 joysticks, turns joystick motion into touch moves and lets an unhandled B fall back to Back = Esc (the quit question). The first two gamepads present at launch (InputDevice through JNI), axes, hat and A/B/X/Y from the input queue sampled every 25 ms as the SDL host maps them; gamepad events consumed so B is no longer Back. Gates: Android scenarios, phone A/B, review; a real controller on the A12 needs the user | **done** (real controller open) |
| T2 | tvOS: overlay storage tvOS keeps, 1080p/4K presentation, audio session, lifecycle (background/foreground) | queued |
| W0 | WASI: `NTSDHeadless` builds for `wasm32-unknown-wasip1` — WASI branches for OS imports, single-threaded paths for the read-ahead, parallel loads, deferred release and the render queue, a scheduler without Dispatch; vs under a WASI runtime equal | **done** |
| W1 | WASI: all 10 scenarios equal, frames identical to the `none` group; load time measured (memory in the browser, W3) | **done** |
| W1b | wasm32 error boundaries: older code traps with a 32-bit Int where 64-bit hosts throw (`Int(UInt32)` reads of values ≥ 2³¹: OriginalWorldCPoints frame −6, a playback file's payload length, ~60 table reads, BMP header words; overflows only reachable through corruption) — the same errors on every host, with tests; plus W0's low review follow-ups | **done** |
| W2a | Browser runner: the WASI build of `NTSDHeadless`, unchanged, in headless Chromium (and WebKit) through a small browser WASI shim with an in-memory file system, driven over the DevTools protocol from Node (no new dependency); all scenarios equal and frames identical to the `none` group; load time and memory in the browser | **done** |
| W2 | Browser: `NTSDWeb` host (canvas presenter, keyboard and gamepad, Web Audio effects and music, data delivery); vs in headless Chromium equal | queued |
| W3 | Browser: all scenarios; frame time per tick and memory in the browser; data delivery options measured for the user's decision | queued |

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-11 | Study and setup | Read the cross-platform work (hosts, packaging, harness, pitfalls); branch `exp/tvos-web`; wasm SDK installed (checksum verified; Foundation without Dispatch); tvOS simulator runtime download started; this card | this card | a16fe0d |
| 2026-10-11 | T0 + H0 (tvOS runner): the iOS host on the Apple TV simulator | tvOS 27.0 simulator runtime installed (Apple, 3.76 GB). `NTSDiOS` builds for `arm64-apple-tvos17.0-simulator` once three iOS-only UIKit members are left out on tvOS; the default overlay is Caches there (no Documents; persistence is T2). `ios_app.py --platform tvos` (triple, SDK, bundle id, tvOS Info.plist, Apple TV 4K 1080p simulator, device lookup per platform) and a `tvos` row in `matrix.py` (`coretext`). **vs on the Apple TV simulator: equal, all 6 frames and 1,826 frame digests identical to AppKit**; the same runner reproduces the iPad (equal, frames identical). Core, Runtime and `Package.swift` unchanged (no `.tvOS` entry needed with the Swift Build backend: the triple sets the deployment target, tvOS 17.0; a `--build-system native` build would need it). On tvOS the touch handlers are left out (the Siri Remote's indirect touches must not become clicks; its input is T1); the runner reports a missing simulator, and a failing tvOS row is marked blocked instead of ending the matrix run (review follow-ups). First wasm32-wasip1 build: blocked in NTSDCore by the startup clock (`clock_gettime`/`CLOCK_MONOTONIC_RAW`) and `DispatchQueue.concurrentPerform` | [evidence](../evidence/tw-t0-tvos-simulator-20261011.json) | a1f3ac0 |
| 2026-10-11 | T1a: all 10 scenarios on the Apple TV simulator | Every scenario equal to its reference; **all 18,088 frames and their digests identical to the AppKit app's** (the `coretext` reference, taken anew for all 10 scenarios from the frozen AppKit app of ml-l20, itself equal everywhere) | [evidence](../evidence/tw-t1a-tvos-all-scenarios-20261011.json) | 76c4043 |
| 2026-10-11 | W0 + W1: the game under WASI | `NTSDHeadless` builds for `wasm32-unknown-wasip1` (swift.org's 6.4.0 SDK: Foundation without Dispatch, a 32-bit `Int`) after behaviour-neutral portability patches: a WASI clock, `OriginalMainQueue` (the main dispatch queue as before; on WASI a timer list in deadline then creation order), inline paths for the parallel loads, the read-ahead, the render queue and deferred releases, no BSD sockets (a stub), atomic writes as plain writes, and three 32-bit traps (the display budget's `3<<30`, `Int(UInt32.max)` in five checks). `run_headless_scenarios.py --wasi` with `wasi_run.mjs` (Node 26; Node 20's V8 crashed on the 96 MB module). **All 10 scenarios under WASI equal and all 18,088 frames identical to the Mac headless run**; load ~0.9 s against 0.33 s natively. Existing hosts: all scenarios, AppKit, unchecked and emulator equal, frames identical; 12 suites; A12 A/B with music and sounds within its spread (main 10.82–10.84 against 10.74–10.80 ms, L20's warm-up 10.84; no W0 change runs per tick on Android). Review OK; its findings of older 32-bit traps are W1b | [evidence](../evidence/tw-w0-w1-wasi-headless-20261011.json) | 6a17823 |
| 2026-10-11 | T1b: gamepads on the iPad and Apple TV, the Siri Remote | The AppKit host's GameController sampler moved unchanged into `OriginalGameControllerJoysticks` (NTSDRuntime), used by AppKit and the iOS/tvOS host (which reported 0 joysticks). The first review found that Menu → Esc would quit (Esc always asks; the iOS message box answers Yes) and that tvOS sends a gamepad's B as Menu; reworked: on tvOS a `GCEventViewController` with UIKit controller interaction off, the remote sampled through GameController (swipes, the 2nd-generation ring, centre/click as Enter), Menu unmapped; the game starts from a run-loop block so the launch probe sees paired controllers. Scenarios cannot change (scripted runs never probe). Existing hosts: all 10 scenarios, AppKit, unchecked, emulator equal with frames identical; 6 suites; phone and Mac A/B within spread. tvOS and iPad joystick/vs/demo equal, frames identical to AppKit; unmuted interactive launches reach the menu with CoreAudio running. Second review OK. A real controller not yet tried | [evidence](../evidence/tw-t1b-gamepads-tvos-ipad-20261011.json) | 64b6e7e |
| 2026-10-11 | T1c: gamepads on Android | `NTSDAndroidGamepads`: the first two SOURCE_GAMEPAD devices at launch (InputDevice through JNI), axes, hat, A/B/X/Y (BUTTON_1–4 on generic pads) and d-pad keys from the input queue, sampled every 25 ms as the SDL host maps them; joystick motion (before: mouse moves near the top-left) and gamepad buttons consumed. **Before, a gamepad's B ended the game** (Back = Esc, the quit question answered Yes; reproduced on the emulator); now the menu stays and system Back still acts as Esc. Review round 1 found a direction that could stick after a cancelled motion (fixed with resets on cancel and focus loss) and three low gaps (fixed); round 2 OK. Emulator vs/joystick/demo equal, frames identical; phone A/B with music and sounds within spread. The A12's own devices are not gamepads (0 joysticks without a controller). A real controller not yet tried. Session gate outputs archived to T7 `tw-gate-artifacts-20261011` (verified) to keep X5 above its reserve | [evidence](../evidence/tw-t1c-gamepads-android-20261011.json) | 3566265 |
| 2026-10-12 | W1b: wasm32 error boundaries | File- and DAT-supplied values of 2³¹ and more trapped on wasm32 (a 32-bit `Int`) where 64-bit hosts throw: BMP header words and palette count, DIB image size, colour count and RLE end, a playback file's payload length, the RIFF chunk size, cpoint frame −6, and — found by the review — a bitmap glyph word for a player-name byte of 0x80–0xFB (GBK names: wasm32 trapped on the first match frame). Each is now compared in 64 bits **under `#if arch(wasm32)` only**: the first gate, with the 64-bit form on every host, raised the Mac footprint after load by ~80 MB (bisected to `OriginalDIBPixels`; the same live heap bytes, memory macOS malloc kept, as in M9), so other hosts compile the previous lines (a mechanical check per file; the final Mac binary's code and data sections identical to T1b's, the Android library's to T1c's but for a T1c closure). A wasm32 probe of the tests' inputs gives the macOS outcomes in all 47 cases and traps in all 9 categories on the old sources; WASI scenarios equal, frames identical. Gate: all scenarios, AppKit, unchecked, emulator equal with frames identical; 18 suites; A/Bs within spread (the Mac footprint spread is the allocator's: HEAD alone showed the same high runs). `OriginalWord32BoundaryTests` pin the 64-bit outcomes. Also W0's follow-ups. Finding for the core port: such names are an `outOfBounds` boundary on 64-bit hosts too (the original reads allocator words in front of the glyph record) | [evidence](../evidence/tw-w1b-wasm32-boundaries-20261012.json) | d5cf2f0 |
| 2026-10-12 | W2a: the game in a browser | The WASI build of `NTSDHeadless`, unchanged, runs in headless Chromium 153 and in WebKit (Safari's engine, Playwright's build) through `web_run.mjs`, a page and a WASI preview-1 shim in a worker (all 34 imports the module uses; files fetched lazily, so the 726 MB bundle is never copied whole; read-only `/app` and `/music`, W0's last review follow-up), with no new dependency. **All 10 scenarios equal and all 18,088 frames identical in both engines** (and vs identical to `m1-frames-ref`). Load 0.76–0.81 s in Chromium, 0.55–0.57 s in WebKit (0.33 s natively, ~0.9 s under Node WASI); the module's linear memory reaches 1.59–1.62 GB — fine on desktop, a question for iOS Safari (W3). Review round 1 found reliability defects in the harness (output tail lost at exit, no crash detection, a cleanup race, file bytes kept), round 2 OK after fixes; a synchronous-write fix then corrupted output through Python's non-blocking pipe and was replaced by awaited writes (caught by the run, documented) | [evidence](../evidence/tw-w2a-browser-runner-20261012.json) | this commit |

## Next task

W2b: an `NTSDWeb` host — the game played in a browser. A new target built
for `wasm32-unknown-wasip1` (behind `NTSD_WEB=1`, as `NTSD_IOS`/`NTSD_SDL`)
implementing `OriginalRuntimeSessionHost` against imports the page provides:
present (the framebuffer to a canvas), keyboard and mouse from DOM events,
gamepads through the Gamepad API sampled at the capture period, sound and
music through Web Audio, the overlay in browser storage; the main loop driven
by the page (an exported pump that runs the due main-queue calls and returns
the next deadline) instead of blocking in `OriginalMainQueue.run`. Text: the
`none` group first (frames must stay identical to it), a canvas or FreeType
rasteriser later as its own group. Gates: the scenarios through `web_app.py`
in Chromium and WebKit equal with frames identical to `none`; Package.swift
changes, so the existing hosts' gates; an independent review of the host
layer and its threading. Then W3 (browser performance, memory against iOS
Safari's limits, data delivery for the user's hosting decision).
