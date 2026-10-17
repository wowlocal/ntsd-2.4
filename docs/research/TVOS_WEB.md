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
| `web_app.py` (W2b, W5) | Headless Chromium (and WebKit) | The browser host proper (canvas, input, audio) as a static folder: `build` (W5: the data in packs, the stripped program, both brotli under `data-*/br/`), `verify` (every delivered byte against the build), `serve` (a test host: `--latency`, `--rate`, `--broken-encoding`), `visit` (cold or return visits of a served folder or the published site: first frame and data in) |
| `run_headless_scenarios.py --web` with `NTSD_WEB_PACKED=DIR` (W5) | Headless Chromium or WebKit | The scenarios read `/app` and `/music` from a built folder through the page's loader (`web_run.mjs --packed`), after `web_app.py verify` ties the folder to the build; `NTSD_WEB_DATA_IN_MEMORY=1` takes the loader's memory path |
| `matrix.py` rows | all | Adds `tvos` (`coretext`, done), `wasi` (`none`) and `browser` (its own text group, or `none` without text) |

Harness acceptance: each runner reproduces an existing host's result first
(the tvOS runner and the iPad runner agree on the iPad; the WASI mode runs the
Mac headless binary's scenario set through the same code path; the browser
runner's bridge round-trips a frame byte for byte) before it judges a new host.

WASI boundary (W2b-4b): a Foundation file call on a path outside every
mounted folder traps (createDirectory's recursion ends in a stack-protector
failure) instead of throwing, so a runner mounts every folder the program
touches: the scenarios pass `--overlay` inside `/out`, and the browser host
has a `/tmp` in memory for its temporary overlay when the page keeps no
`/save` (`web_saves_check.py` and the W2b-4b evidence).

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
| W2b-1 | Browser host `NTSDWeb` (behind `NTSD_WEB=1`, wasm32 only): headless services, the crop handed to the page through a shared frame buffer under a sequence lock and drawn on the page's canvas on each animation frame; scenarios through `run_headless_scenarios.py --web` in Chromium and WebKit equal, frames identical to `none`, the page canvas read back and compared with the source pixels | **done** |
| W2b-2 | Input: keyboard and mouse from DOM events and gamepads from the Gamepad API, sampled by the page into a shared input ring the host drains on a main-queue timer; an interactive launch (no `--script`); message boxes answered by the page (the worker waits on a shared flag) | **done** (gamepads by hand open) |
| W2b-3 | Audio: the effects mixer (and music) rendered by the worker into a shared ring an AudioWorklet plays; the page's focus as DirectSound's | **done** (a player's devices and Safari by hand open) |
| W2b-4a | Saves: the overlay the game writes under /save kept in the browser (IndexedDB), loaded before the start, changes stored in order; a check that a second page load reads the first one's saves | **done** (Safari, Firefox and a second tab by hand open) |
| W2b-4b | Page: the canvas scaled to the window keeping the game's aspect, full screen, a loading indicator, the saves' state and reset | **done** (iPad/iPhone Safari and touch by hand open) |
| W2b-4c | Delivery: the page, program and bundle served by a static host (no runner): a config file, lazy file fetches with caching, first-load bytes measured for the user's hosting decision | **done** (publishing and a real host need the user) |
| W2 | Browser: `NTSDWeb` host (canvas presenter, keyboard and gamepad, Web Audio effects and music, data delivery); vs in headless Chromium equal | **done** (W2b-1 to W2b-4c; hand checks open) |
| W3a | Browser frame time per tick (Chromium, WebKit) against Node WASI and the Mac for vs and the Demo, startup and load, the module's linear memory | **done** |
| W3b | Delivery: the data sent compressed (~100 MB instead of 881 MB on a first visit) with the program's reads byte-identical: host-side Content-Encoding for pre-compressed files where a host allows it, or decompression in the page with the reads unchanged; measured per option for the user's hosting decision | **done** (precompressed forms; a real host needs the user) |
| W3c | Startup: what the 5 s before the load are in the browser (reads of every packaged file, their SHA-256 digests in wasm) and whether they shrink without a behaviour change | **done** (attributed; levers W3e–W3g) |
| W3e | WASI's loading packages computed at first use (or in bounded slices in the menu's sleeps) instead of at creation, the same order and errors: the menu's first frame at ~1 s instead of ~5.6 s | **done** (at first use; slices not done) |
| W3f | The page prefetching in the program's read order while the program starts, so a first visit's downloads overlap the startup | **done** |
| W3g | A SIMD128 SHA-256 digesting four entries at once, the digests and their order unchanged | queued |
| W3d | A phone browser: the 1.6 GB module on iOS Safari and Android Chrome (needs the user's devices) | queued (needs the user) |
| W4 | The game's GDI text in the browser, drawn with the browser's fonts (user, 2026-10-13) | **done** |
| W5 | Loading on a real host (user, 2026-10-17: "loading times are kinda bad. super bad. no matter the internet speed … nobody is playing"): the live site measured; the data in packs in the program's read order, the stripped program, a loader worker keeping the packs in OPFS, the download and compilation from the page's load, the menu's track no longer waited for; every scenario through the packed path in both engines | **done** (publishing: the user's Codex session) |

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
| 2026-10-12 | W2a: the game in a browser | The WASI build of `NTSDHeadless`, unchanged, runs in headless Chromium 153 and in WebKit (Safari's engine, Playwright's build) through `web_run.mjs`, a page and a WASI preview-1 shim in a worker (all 34 imports the module uses; files fetched lazily, so the 726 MB bundle is never copied whole; read-only `/app` and `/music`, W0's last review follow-up), with no new dependency. **All 10 scenarios equal and all 18,088 frames identical in both engines** (and vs identical to `m1-frames-ref`). Load 0.76–0.81 s in Chromium, 0.55–0.57 s in WebKit (0.33 s natively, ~0.9 s under Node WASI); the module's linear memory reaches 1.59–1.62 GB — fine on desktop, a question for iOS Safari (W3). Review round 1 found reliability defects in the harness (output tail lost at exit, no crash detection, a cleanup race, file bytes kept), round 2 OK after fixes; a synchronous-write fix then corrupted output through Python's non-blocking pipe and was replaced by awaited writes (caught by the run, documented) | [evidence](../evidence/tw-w2a-browser-runner-20261012.json) | ce9b3c5 |
| 2026-10-12 | W2b-1: the browser host draws on the page | `NTSDWeb` (behind `NTSD_WEB=1`, wasm32 only): the headless host's services with present as a wasm import. The worker never yields while the game runs, so a transferred OffscreenCanvas would never reach the page (review round 1): each crop goes into a shared frame buffer under a sequence lock and the page draws the newest one on every animation frame. **All 10 scenarios equal and all 18,088 frames identical in Chromium and WebKit**; in every scenario the page drew nearly every present (e.g. 3,655 of 3,655), and the first non-black frame read back from the page canvas matched its source pixels exactly (e.g. 436,700 pixels at 794×550); the row fails otherwise. Existing hosts: gate equal, frames identical, phone A/B within spread; the Mac binary's code and data identical to W1b's (its A/B timing invalid: the browser runs loaded the machine). Review round 2 OK after fixes | [evidence](../evidence/tw-w2b1-browser-host-canvas-20261012.json) | b0b6b47 |
| 2026-10-12 | W2b-2: playing in the browser | Keyboard, mouse and gamepads from the page through a shared input ring the host drains every 2 ms; questions (the quit question, alerts, stops) asked on the page while the game waits on a shared flag; the overlay in a mounted /save; a start gesture (browsers show gamepads and allow sound only after one); held keys and buttons released when the page loses focus. Checked interactively in headless Chromium over the DevTools protocol: a click on START opens the mode menu, Escape asks to quit (Yes/No on the page; Yes quits, No plays on), settings saved. Scenarios (scripted) still equal with frames identical in Chromium and WebKit. Two reviews (round 1 found keys stuck after Alt+Tab, lost second mouse buttons, invisible gamepads; round 2 small items), all fixed. Bugs found while testing: a brace-less `if` in the runner answered every request with the config, an untyped `flatMap` gave `[[Any]]`. `web_run.mjs --serve PORT` serves the page for a player's own browser. Gamepads need a player's check | [evidence](../evidence/tw-w2b2-browser-input-20261012.json) | 6f4cb34 |
| 2026-10-12 | W2b-3: sound and music in the browser | The worker renders the effects mixer (`OriginalMacSoundEffects`, as SDL's audio thread pulls it) and the playing music into a shared ring of stereo floats from a 10 ms main-queue timer, ~150 ms ahead; an AudioWorklet plays it at 44.1 kHz (the tracks' rate; headless Chromium's default context ran at 192 kHz and overran the first ring). The packaged ALAC tracks are decoded packet by packet in the worker (`OriginalALACDecoder`, WASI only) and resampled to the context's rate. **The vendored decoder failed every packet on wasm32**: its little-endian define covered only Linux, Android and Windows (`Package.swift` now adds `.wasi`; a wasm32 probe of main.caf matches macOS sample for sample). Review round 1 found that a start by gamepad, touch or Esc would never launch (the page awaited `resume()`, which needs an activation), that losing focus silenced the music too (the other hosts silence only the effects), and that the main-loop mixer froze the music clock during loads and questions; fixed: the page no longer waits, focus mutes only the effects, and frames played short come back as owed and are rendered and dropped (up to 10 s), so voices and the music clock keep wall-clock time as on an audio thread. Round 2 OK, its small items fixed. **In the menu's Demo match: 0 underrun quanta over 62 s** (all 295, ~0.9 s, fell in the startup loads), music and effects audible (peak 1.25); scenarios (scripted, no audio) equal with all 18,088 frames identical in Chromium and WebKit. Existing hosts: gate equal with frames identical, the music output, startup and exclusivity suites; the Mac binaries' code and data identical to W2b's (the Mac footprint delta is the allocator's). The gate tree's Android library ran ~0.1 ms per tick slower in the phone A/B (its layout shifted by the then-unused decoder class); with the decoder WASI-only, a clean APK of the final tree gives an Android library whose code and data sections are byte-identical to W2b's. Sound on a player's own devices and in Safari are hand checks | [evidence](../evidence/tw-w2b3-browser-sound-20261012.json) | c1cd3f9 |
| 2026-10-12 | W2b-4a: saves kept in the browser | `web_run.mjs --persist /save`: the page keeps the folder in IndexedDB. The worker never yields, so the page loads the whole tree before it starts and the worker sends each change back (a closed file's bytes, a folder, a removal, a rename), stored in order with strict durability; at exit the page stores every change it was sent before it acknowledges. No Swift change (the host already wrote its overlay under a mounted /save). **`web_saves_check.py`: in Chromium and WebKit a second page load reads the first one's saves** — the first run sets player 1's up to Q, the second (same profile and origin) sets down to X and the stored control.txt holds both changes, byte-identical to the macOS headless host's after the same two runs; a fresh profile gives the second change alone. Testing found that Chromium's default durability lost the last save when the browser was killed, and that a new port is a new origin with empty storage (`--port`, `--profile`). Review round 1 found a latent loss (a kept file's bytes released at close would read empty on a second open), a black page without IndexedDB, and silent failures after the browser closes the connection; fixed, with failures shown to the player, one saving tab (a Web Lock), persist() asked and localhost sent to 127.0.0.1 (one origin). Scenarios (no persist mount) equal with all 18,088 frames identical in both engines. Safari, Firefox and a second tab are open | [evidence](../evidence/tw-w2b4a-browser-saves-20261012.json) | f829a55 |
| 2026-10-12 | W2b-4b: the page | The canvas fills the window keeping 794:550 with nearest pixels (as the iOS and SDL hosts scale) — checked at 800×600, 1600×900 and 400×600, and **clicks land on the exact canvas pixel at five window sizes**, corners included; START opens the mode menu in every scaled page. 'Loading…' until the first frame. A corner bar that fades: Full screen (the browser's; Esc kept for the game with the Keyboard Lock where available, as the game's Esc asks to quit) and Saves (kept, used without saving, unavailable, failed or not kept, with a reset): checked on and off, the panel's text, a reset that removes the stored control.txt after a real confirm. **Found while testing: without /save the browser host trapped at startup** — its temporary overlay in /tmp lay outside every mount and Foundation trapped (a stack-protector failure in createDirectory) instead of throwing; the browser host now has a /tmp in memory, and the trap is recorded as a WASI boundary. Review round 1 found a reset race (a store arriving during the reset could survive it), a reset offered before the saves' state was known, and smaller focus, touch and z-order gaps; fixed. Saves check pass; scenarios equal with all 18,088 frames identical in both engines. iPad/iPhone Safari and touch are open | [evidence](../evidence/tw-w2b4b-browser-page-20261012.json) | 4f678fa |
| 2026-10-12 | W2b-4c: the browser host from a static host | `web_app.py build` assembles a folder any static host serves without the runner: the page with a static config.json, the program, data and music in a content-named `data-<hash>/` folder with manifests instead of the runner's listings, and `_headers`/`vercel.json` with the isolation headers and an immutable cache for the data. **From a plain static server the game plays in Chromium** (cross-origin isolated, frames, START opens the mode menu, exit 0) **and WebKit fetches the same 1,529 files**; a first visit downloads 881.5 MB (every data file: the game loads all its data at startup, as the original; music tracks load when they play) — **123 MB with gzip, 99 MB with brotli 11**, as 691 MB of BMPs compress to 19 MB, but many hosts do not compress image/bmp on the fly (pre-compressed files, W3). The worker prefetches the data 8 at a time with progress, but only where a probe shows the browser's cache serving its synchronous reads: Playwright's WebKit downloaded every file twice without the probe; with it, each file once in both engines. Review round 1 found that the runner could not serve the page's config at all (a route-order bug that would have failed every runner run), that the worker was never told it ran without the runner, and that failures looked like a normal end; fixed, with retries, a MIME fallback and the exit code shown. Round 2 OK; low items queued. Saves check and the scenarios from the static folder's files equal with all 18,088 frames identical in both engines. Publishing needs the user | [evidence](../evidence/tw-w2b4c-browser-static-20261012.json) | 21f5caa |
| 2026-10-12 | W3a: frame time and memory in the browser | `load_memory.py --web/--wasi` measures the browser host and the headless build under Node's WASI from the game's own events (3 runs each, vs over bodies 600–1500, the Demo over 300–900). **Per tick, like for like (one thread, rendering inline): the Mac 1.9–2.0 ms, Chromium 2.2 ms (1.12–1.17× native), WebKit 3.0–3.3 ms (1.5–1.7×), Node WASI 3.5–3.7 ms (1.8–1.9×)** — the Mac measured with `--synchronous-render` (`load_memory.py --game-arg`), as its default figures (1.3–1.5 ms on the game thread with a render thread beside it; 3.2–3.3 ms CPU over all threads) compare with nothing here; all far inside the 60 fps budget (16.67 ms) and the game's 33 ms tick. The windows cover the same cycles on every run and the loaded counts match the Mac's. **Startup is the cost**: 'started' to 'loaded' takes 5.3–5.7 s in the browser (4.1–4.7 s under Node) against 0.63 s on the Mac, almost all before the load, where WASI reads and digests every packaged file inline (W3c). The module's linear memory peaks at 1,617 MiB (vs), 1,588 MiB (Demo) in both engines; a phone browser needs a device (W3d). Review round 1 found the tool would have run WASI twice for one folder and that the Mac's per-tick figure is not like for like (render thread); fixed, remeasured, and the like-for-like Mac run added. W2b-4c's queued page items fixed; scenarios equal with all 18,088 frames identical in both engines | [evidence](../evidence/tw-w3a-browser-frame-time-20261012.json) | ef6e880a |
| 2026-10-12 | W3b: the data sent compressed | `web_app.py build --compress` writes each data file's gzip and brotli forms beside it (verified to decode to the same bytes: 1,404 + 1,517); a host serves them for the plain name with Content-Encoding (nginx gzip_static/brotli_static, S3/R2 metadata behind a CDN for the isolation headers), so the program's reads are unchanged — and the worker now fails a file whose size differs from the listing, should a host strip or double an encoding. **A first visit at 100 Mbit/s: 881.5 MB and 75 s to the first frame plain, 99.5 MB and 12.8 s with brotli (Chromium); 120.9 MB with gzip in WebKit** (it advertises brotli only over HTTPS); the data itself arrives in 6.1 s instead of 68.7 s, and the remaining ~6 s are the game's startup (W3c). Bandwidth-bound lower bounds (the test server's `--rate`; no round trips). **The scenarios run from the delivered files** (the runner serving the forms, `--precompressed`, the browser decoding every read): equal with all 18,088 frames identical in both engines — after a first run stopped every scenario at startup because the runner listed the forms as files of the bundle (now hidden). A misconfigured host (forms without their header, `serve --broken-encoding`) stops the game before any frame with the worker's message '2815 bytes, listed 5326 (the host altered it)'. Decoding costs ~0.7 s unthrottled (3 runs each). Review round 1 found the first matrix compared different page builds and measured the engines differently, and corrected the host claims (Vercel compresses image/bmp on the fly per its documentation; S3/R2 need a CDN for the headers; GitHub Pages unsuitable); round 2 found the scenario gate still open; both fixed. A real host needs the user | [evidence](../evidence/tw-w3b-browser-compressed-20261012.json) | 5d24e399 |
| 2026-10-12 | W3c: the startup attributed | Worker CPU profiles (`web_run.mjs` profile steps; `node --cpu-prof` for WASI): before the first frame (5.6 s on the static page) the browser host spends **~2.2 s digesting every packaged file (757.7 MB, SHA-256 in wasm at ~379 MB/s), ~1.1 s waiting for the prefetch, ~0.8 s reading from the cache, ~0.5 s in LZ4**. An unrolled C SHA-256 for wasm runs at ~290 MB/s, slower than the Swift code: no cheaper block function. The first conclusion (threads as the only lever) was wrong, the review found: on WASI the loading packages are computed at creation, so ~728 MB are read and digested before the menu's first frame though the menu needs 29.7 MB (the native hosts do it on a thread behind the menu) — computing them at first use would bring the first frame to ~1 s (W3e); the page could prefetch while the program starts (W3f); a SIMD multi-buffer SHA (W3g). W3b's queued items fixed (forms for read-only mounts only; the runner counts responses by encoding: every scenario's run shows its br responses). Scenarios from the compressed files equal with all 18,088 frames identical in both engines | [evidence](../evidence/tw-w3c-browser-startup-20261012.json) | b90394c0 |
| 2026-10-12 | W3e: the menu first, the packages at first use | On WASI `OriginalConcurrentInputs.Background` now runs its computation at the first `get()` — where a threaded host waits for its thread — instead of at creation, so the loading packages (every packaged file read and digested) no longer run before the menu exists. **The static page's first frame: 5.35–5.53 s before, 1.81–1.85 s after** (3 cold visits each, Chromium); 'started'→'loaded' unchanged (the same work at the first loading cycle; frame time unchanged). Scenarios equal with all 18,088 frames identical under Node WASI, in Chromium and in WebKit (built before the review's comment fixes: comments only). Existing hosts: the gate on the final tree equal with frames identical, the read-ahead suite and two more pass, phone A/B within spread; the Mac binaries' data identical and their code different in five line-number immediates of force-unwrap failures (comments shifted the lines); the Mac A/B's ~2.5% gap followed the run order and vanished reversed. Review OK; the ~3 s now come at the start of loading with the menu's last frame on screen (slices in the menu's sleeps would hide them) | [evidence](../evidence/tw-w3e-wasi-lazy-packages-20261012.json) | 05e9c595 |
| 2026-10-12 | W3f: the download overlaps the start | The worker probes the cache and, once its module is in, hands the page the file list (the startup package first); the page fetches 4 at a time while the program runs, yielding to the program's own reads until the first frame (a shared fetch gate) and with two lanes regardless afterwards. **A first visit at 100 Mbit/s: the first frame at 5.6 s precompressed (12.8 s in W3b) and 13.6 s plain (75.5 s)**; unthrottled 1.0–1.3 s; 3 runs each, no file fetched twice, none failed. Two intermediate variants measured why: with 8 lanes and no gate the menu's music (a 27.5 MB synchronous read) waited behind the download (55.8 s); with the list handed over during compilation the 96 MB module waited (38 s). Review round 1 found a lane that could crash at the list's end and a gate that could serialise a program reading ahead; fixed; round 2 OK. WebKit still skips the prefetch (its reads miss the cache). Scenarios equal with all 18,088 frames identical in both engines | [evidence](../evidence/tw-w3f-browser-prefetch-overlap-20261012.json) | this commit |
| 2026-10-13 | W4: the browser draws the game's text | The user, testing the web version, found the GDI text missing (counts, names, settings values, the match summary's numbers: the web host had no glyph rasteriser, the `none` group) and chose the browser's fonts. A wasm import `ntsd.text` draws each new string with OffscreenCanvas in the worker — the platform's UI sans-serif bold at 13 px (SF, Segoe UI, Roboto, then the Linux faces closest in width), the CoreText/FreeType cell geometry, half coverage and up as the mask; a failure leaves the text blank. Both engines: 10 scenarios equal; **text in exactly the same 9,565 frames as CoreText and the 8,465 text-free frames identical** (`compare_text_frames.py`); Chromium and WebKit differ in 39 frames (each engine its own text group); Chromium identical run to run. Review fixed a throw ending the run, signed wasm pointers, the BOM and the font order; recorded: antialiased masks cut at half coverage, control bytes, no page fonts in the worker, advance parity unmeasured | [evidence](../evidence/web-text-20261013.json) | this commit |
| 2026-10-17 | W5: loading on a real host | The live site (Vercel, f0471f13's build) measured from this Mac: **a cold visit's first frame at 9.3 s and its data in at 46.5 s** on a fast line (return visits 1.6/1.9 s) — latency-bound: 1,521 files each a CDN round trip, four page lanes, and WebKit skipped the prefetch (one file at a time); W3b–W3f's lower bounds had no round trips. Now `web_app.py build` writes the data as 12 packs in the program's read order (`web/read-order.json`, from the browser host's own request log: every file read once; pack 0 = the 48 startup reads) behind a 64-byte header naming the pack, brotli-11 under `data-*/br/` (**43.8 MB on the wire for 757.7 MB**, per-file brotli 51.5 MB, Vercel's on-the-fly ~70 MB) with the program stripped of its custom sections (**14.1 MB instead of 29.3 MB**, code and data sections the build's); a loader worker (`web/pack-loader.js`) streams the packs into OPFS from the page's load and serves the game worker's synchronous reads (a MessagePort and a shared status word), a later visit reusing them; the module compiles before the player's click; the web host's music player keeps time silently until its track is in (the menu waited for its 27.5 MB track). **Locally with 100 ms per response, cold: first frame 5.5–7.0 s → 1.36–1.39 s, data 44–46 s → 1.9 s; at 50 Mbit/s 13.0 → 3.75 s and 53.7 → 14.1 s; return visits: nothing fetched, data in at 0.4 s.** Gates: **all 11 scenarios through the packed path and through the runner, in Chromium and WebKit, equal with all 18,384 frames identical to HEAD's** (a HEAD-tools baseline on HEAD's clean build); every pack in OPFS in both engines; `verify` (every delivered byte); the saves check; a host without the encoding refused before any byte reaches the game; the memory path (vs equal, frames identical). Two review rounds (a name not covering the layout, files ready before a pack was checked, the memory path, reuse races, a track never refetched, a retry skipping the header check, …), all fixed or recorded. Core, Runtime and Package.swift unchanged. Publishing: the user's Codex session | [evidence](../evidence/tw-w5-web-packed-loading-20261017.json) | this commit |

## Next task

W5 (2026-10-17) is in `main`; its publication is the user's Codex session's
(the archive, Vercel's `data-*/br/` Content-Encoding rule checked on a
preview, then production; `web_app.py visit` on the published site gives the
CDN's own figures). Open after it: the ~2.2 s digest of every packaged file
after START (W3c; W3g or the menu's idle time), the memory path's limits
(a re-read fetches its pack again; progress completes only once every pack
was read; Netlify's `_headers` placeholders unverified), phone browsers (W3d).

The web work is done for now (user, 2026-10-12: "как закончишь с web-ом влей
в main"): `exp/tvos-web` merges into `main`, and the next work — a scalable
game window with the platforms' native full screen on every host, Apple TV
filling the TV and the browser included, the original fixed format behind a
flag — continues on its own branch and card. Left here: W3g (a SIMD
multi-buffer SHA-256, optional), W3d (a phone browser: the user's devices),
the hand checks (real controllers on tvOS, iPad, Android and the web; touch
on a device; Safari), and T2's storage, audio session and lifecycle (its
1080p/4K presentation moves to the window work).
