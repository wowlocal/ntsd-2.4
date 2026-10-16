# A scalable game window and native full screen on every host

Branch `exp/window-scaling`, from `main` 9d7beb8a (2026-10-12). Requested by
the user on 2026-10-12: "как закончишь с web-ом влей в main и отведи
отдельную ветку где поработай над тем чтобы мы могли скейлить окно игры и
использовать нативные кнопки fullscreen для запуска игры на полный экран.
запуск в оригинальном формате оставь под флагом. на всех платформах должно
работать особенно на apple tv где запуск должен быть на весь экран
телевизора" — and "ну и браузер тоже важен".

## Goal

On every host — the macOS app, SDL on Linux and Windows, the iPad, Apple TV,
Android and the browser — the game's picture scales with its window or
screen, and the platform's own full-screen control puts it on the whole
screen. Apple TV starts filling the TV. The original presentation (the
794×550 client at one point per pixel, a fixed window) stays available behind
a flag on every host.

Done when each host has: a scalable presentation by default (a resizable
window where the platform has windows, the whole screen where it does not),
its native full-screen control working, the original-format flag, input
mapped exactly through the scaled picture, and the game's frames, behaviour
and scenarios unchanged — checked on that host as the gates say.

## Verified starting point (2026-10-12, survey of 9d7beb8a)

- Every host draws the 794×550 crop with its aspect kept, centred on black,
  nearest filtering (Android leaves filtering to the compositor).
- The shared window backend presents a frame only when it matches the client
  size, unless the window is the game's full-screen popup or the host holds
  the previous geometry (`OriginalRuntimeWindowBackend.swift` 116-133,
  177-185, 362-372): the macOS host's native full screen already holds the
  game's 794×550 geometry while its window changes size.
- The original's Alt+Enter is the game's own code everywhere (it destroys
  and recreates its window as a full-screen popup at display mode
  794×550×8); it stays exactly as the original (user, 2026-10-01). Native
  full screen is a separate, host-side control.
- macOS app: window 794×550 points, not resizable; native full screen via the
  View menu (⌃⌘F) with held geometry; Alt+Enter as a borderless popup.
- SDL: window not resizable, no high pixel density; presents letterboxed to
  the current window size; the app toggle unsupported; Alt+Enter → SDL
  full-screen window.
- iPad/Apple TV: the view is the whole screen, aspect fit, nearest; iPad
  hides the status bar; tvOS unobserved on a TV (expected 1559×1080 pt on a
  1920×1080 pt screen, no overscan handling).
- Android: immersive full screen, the buffer padded to the surface's aspect.
- Browser: the canvas fitted to the window (CSS), a Full screen button with
  the Escape key locked for the game.
- No host has a window-size or original-format option.

## Boundaries

- Presentation only. The game's frames, its window and client geometry as
  the game sees them (794×550), its input semantics, timing and behaviour do
  not change; scenarios and frame references stay as they are. Scaling maps
  the presented frame to a view and the view's input back to client pixels.
- No Core change; Runtime changes only where the shared window backend must
  learn to hold the game's geometry for a resized host window (then the
  existing hosts' gates, the A12 included).
- Alt+Enter stays the original's. Native full screen never runs the game's
  display-mode switch.
- The original format behind a flag keeps today's presentation exactly
  (window size, one point per pixel, fixed size).
- Performance is not traded: scaling stays a nearest-filter copy in the
  platform's compositor or a single draw.

## Harness

- Scenarios: `run_headless_scenarios.py` per host as before (unchanged
  frames are the main gate: scaling must not reach the game).
- macOS: the AppKit app's vs and playback, plus windowed checks at several
  sizes (screenshots of the window and clicks at known client pixels).
- tvOS/iPad: `ios_app.py --platform tvos|ios` on simulators: screenshots at
  1080p and 4K (Apple TV 4K at 1080p and at 4K), the picture's box measured.
- Android: the emulator and the A12 (`android_app.py`), screenshots.
- SDL: the Linux host in Docker or the Windows host under CrossOver, with a
  window manager where needed; screenshots after resizing.
- Browser: `web_run.mjs` steps (viewport, clicks, captures) as in W2b-4b.

## Gates (every increment)

1. The host's scenarios equal with frames identical to its text group's
   references.
2. The scaled presentation checked on that host: the picture's box keeps the
   aspect at several sizes, clicks land on the exact client pixel, the
   native full-screen control enters and leaves full screen, the original
   flag shows today's presentation.
3. Runtime changes: the existing hosts' gates (`mlgate.sh`, A12 A/B).
4. An independent read-only review of each host layer change.
5. One commit per checked increment on `exp/window-scaling`, evidence in
   `docs/evidence/ws-*.json`.

## Flags and controls (all hosts)

By default the game's picture scales with its window or screen, aspect
kept, nearest pixels (Android's default leaves the scaling to the
compositor, which filters); the game itself still sees its own 794×550
window.
The original window (the 794×550 client at one point per pixel, a fixed
window) is behind one flag name on every host, `original-window`:

| Host | Default | Original window | Full screen |
| --- | --- | --- | --- |
| macOS app | resizable window opening at the largest whole multiple of 2× or more within 85% of the visible screen, else the fraction that fits (down to half); its size is kept across Alt+Enter | `--original-window`, or `defaults write local.ntsd.native NTSDOriginalWindow -bool YES` (a bare executable: `-NTSDOriginalWindow YES`) | the green button or View ▸ Enter Full Screen (⌃⌘F) |
| SDL (Linux, macOS SDL; Windows shares the code, not built) | resizable, maximisable, high pixel density, the same initial size rule | `--original-window` or `NTSD_ORIGINAL_WINDOW=1` | the window manager's maximise and full-screen controls (macOS SDL: the green button, a zoom, not tried by hand); no game key is taken, since the original receives F1–F12 |
| Apple TV | the whole TV, aspect kept | the launch argument `--original-window` or the NTSDOriginalWindow default | always full screen |
| iPad | the whole screen, aspect kept | as Apple TV | always full screen |
| Android | the whole screen, aspect kept (the compositor scales) | `--original-window` in the app's `files/args.txt` (one argument per line; needs adb `run-as`): one device pixel per pixel, centred | always immersive full screen |
| Browser | the canvas fitted to the page | `?original-window` (alias `?original`; `=0`, `=false`, `=no` turn it off; the real name wins over the alias), or `"originalWindow": true` in config.json; `web_run.mjs --original-window` | the page's Full screen button; the browser's own full screen (F11, the green button) enlarges the page, which the default fit follows, while the original window stays 1:1 there |

Common rules: the game's own Alt+Enter is the original's (a full-screen
popup at the display mode it asks for), and that popup fills the screen in
either mode; scripted runs (`--script`) keep the original window unless
`--scalable-window` (macOS, SDL) so their captures do not depend on the
display; the scenario runner passes extra game arguments with
`NTSD_GAME_ARGS`. In the original window a window smaller than the frame
shrinks the picture rather than cropping it (browser, Android).

## Plan

| ID | Step | Status |
| --- | --- | --- |
| S0 | This card; the per-host survey | **done** |
| S1 | Apple TV: verify and make the launch fill the TV at 1080p and 4K (the view, its scale, safe areas/overscan), the original-format flag (1:1 at the screen's centre) | **done** |
| S2 | Browser: the original-format option (`?original`, config) beside today's fit and Full screen; integer or device-pixel snapping considered | **done** |
| S3 | macOS app: a resizable window (aspect kept, the game's geometry held at any size), the green button's native full screen, a default size larger than 1× where the screen allows, `--original-window` for today's fixed window | **done** |
| S4 | SDL (Linux, Windows): a resizable, high-density window holding the game's geometry, the native full-screen toggle, the original flag | **done** (Windows not built) |
| S5 | iPad and Android: the original flag, nearest filtering on Android, checks at several screens | **done** (Android nearest filtering left to the compositor) |
| S6 | All hosts: the flag's name and defaults documented in one place, launch notes for each app | **done** |

Open for the user (not blocking): on a 16:9 TV the 794:550 picture keeps its
aspect with bars at the sides; a stretched or filled mode would distort or
crop the original — ask before adding one. Nearest filtering at a
non-integer scale (1.96× at 1080p) gives uneven pixels; a smoothed mode would
blur them — also the user's choice.

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-12 | S0: card and survey | Branch `exp/window-scaling` from `main` 9d7beb8a (exp/tvos-web merged by fast-forward at the user's request); the survey above | this card | 1d39dd65 |
| 2026-10-13 | S1: Apple TV fills the TV | Screenshots of the Apple TV 4K simulators: **the launch already fills the TV's height at 1080p (1560×1080 px) and 4K (3118×2160 px)**, 794:550 kept, bars at the sides. `--original-window` (or the NTSDOriginalWindow default) shows 794×550 points at the centre (794×550 px at 1080p, 1588×1100 px at 4K); the game's Alt+Enter popup still fills the screen in that mode (the review's medium finding, fixed). Safe area unchanged (the picture runs to the top and bottom edges; recorded). All 10 tvOS scenarios equal with all 18,088 frames identical to the AppKit reference, itself identical to T1a's pinned coretext reference; iPad vs equal, frames identical | [evidence](../evidence/ws-s1-tvos-full-screen-20261013.json) | f075d765 |
| 2026-10-13 | S2: the browser's original window | `?original-window` (alias `?original`; `=0`, `=false`, `=no` off) or `config.originalWindow`: the frame at one CSS pixel per pixel, centred, **shrunk to fit a smaller window, never cut**; the browser's full screen and the game's Alt+Enter popup fill the page (the web host now passes the popup flag with each present). Checked at 1600×900, 800×600, 801×601 and 400×600 (clicks exact at every size), full screen on and off, Alt+Enter, and the static page's flags. One CSS pixel per frame pixel, no device-pixel snapping (recorded). Review round 1 found the crop in small windows and full screen staying 1:1, fixed; round 2 OK, two small items queued for S6. Scenarios equal with all 18,088 frames identical in both engines | [evidence](../evidence/ws-s2-browser-original-window-20261013.json) | 71e5243a |
| 2026-10-13 | S3: the macOS scalable window | **By default the game window scales**: the game's 794×550 client is held from creation (the native full screen's mechanism, set on the lease since the backend registers it after `windowCreated`), the window resizes with its aspect kept (half size at least) and opens at the largest whole multiple ≥2 within 85% of the screen, else the fraction that fits (2× on the 6K test display); the size at the game's DestroyWindow (Alt+Enter) is the next window's. The picture is the layer's contents, scaled by the compositor, nearest. Clicks and GetMessagePos map through the picture. The green button's full screen fills (aspect kept) and returns. `--original-window` / `-NTSDOriginalWindow YES` keep the fixed window; scripted runs keep it unless `--scalable-window`. The new geometry test caught the hold silently failing on its first run (fixed). All 10 AppKit scenarios equal with 18,088 frames identical, fixed and scalable; live on the 6K display (upright, 98.7% of 4×4 px blocks uniform, a pid-posted click lands on its client pixel, full screen in and out, both flags). A/B fixed vs 2×: ms per tick 2.02 vs 1.74, process CPU 4.66 vs 3.30, peak 799 vs 692 MB (vs), 813 vs 702 MB (Demo); the first build's window-sized backing store cost +73..78 MB and was replaced. Two review rounds: round 1 found GetMessagePos inconsistent with the hold, clicks before the first frame, the remembered size and small screens (all fixed); round 2 OK. Boundaries: a moved window no longer reaches the fixed window's off-screen stops; MSG.pt in the game's own popup stays physical (pre-existing); hand checks of a real click and the green button open (a real HID-level click at 2× activated START after the commit, recorded in the evidence) | [evidence](../evidence/ws-s3-macos-scalable-window-20261013.json) | b7cd16c6 |
| 2026-10-13 | S4: the SDL scalable window | **By default the SDL game window scales** (macOS, Linux; the same code for Windows): resizable and maximisable with its aspect kept (`SDL_SetWindowAspectRatio`), high pixel density (drawn in output pixels, clicks in window points), half size at least, the macOS initial-size rule over the usable display bounds, the size at DestroyWindow reused; the game keeps the centred 1× client it asked for (`placed`) as its position, so moving or resizing never reaches it; clicks and GetMessagePos map through the picture; the window redraws its last frame when resized or uncovered. Full screen: the platform's own controls (maximise, the window manager's full screen, macOS SDL's green button = zoom) and the script's `fullscreen` (SDL desktop full screen); no host key, since F1–F12 all reach the game. `--original-window` / `NTSD_ORIGINAL_WINDOW=1` keep the fixed window; scripted runs keep it unless `--scalable-window`. Checks: macOS SDL all 10 scenarios equal with 18,088 frames identical to the CoreText reference, fixed and scalable; Linux SDL fixed and scalable against a baseline built from HEAD (see evidence); `linux_sdl_scaling.py`: X11 with real xdotool clicks at 1325×918 and, letterboxed, 1001×600 reaching a match, Wayland full screen in and out with identical frames; macOS SDL on the 6K display: 2× window, full screen and back, both flags, and a real HID click at density 2 activating START. `run_headless_scenarios.py` gains `NTSD_GAME_ARGS` (recorded per row). Two review rounds (round 1: clicks at density 2 untested — closed by the real click; stale picture box after a resize — fixed). Open: GetMessagePos exercised by no run; Linux window-manager maximise and aspect hints untried (no WM in the X11 run); Windows not built (DPI units, metrics 0,0,0) | [evidence](../evidence/ws-s4-sdl-scalable-window-20261013.json) | d45fd928 |
| 2026-10-13 | S5: iPad and Android | **iPad** (no code: the S1 view is shared): vs equal with frames identical; simulator screenshots on the iPad Air 13" and the iPad mini — the default fills, `--original-window` gives 794×550 points centred, the game's Alt+Enter popup fills (the app's landscape window appears shrunk in the portrait screenshots; a system banner inflated one box). **Android**: `--original-window` in `files/args.txt` shows the frame at **one device pixel per pixel**, centred, with no compositor scaling (794×550 dp would not fit a 720 px phone: recorded), fitted as by default when the surface is smaller; the popup fills; the one-to-one flag travels with each frame through the presenter thread. Gate: clean APK, emulator vs/joystick/demo equal with vs frames identical to the Android reference; A12 A/B against tw-w3e with music and sounds within noise (main 10.90 vs 10.86, render 7.18 vs 7.18 ms per tick). On the emulator (2560×1600) and the A12 (1600×720): both modes, a real `adb input tap` on START mapped through the measured picture loads the game, and the original window survives Alt+Enter and back. The opt-in original mode costs about 1 ms of CPU per tick on the A12 (full-surface buffer; 28.4 vs 27.4 ms process), within budget. Review OK (threading confirmed). Open: iPad taps not exercised; Android has no in-app switch (the flag needs adb: S6 documents it); nearest scaling on Android not attempted (compositor filtering kept) | [evidence](../evidence/ws-s5-ipad-android-20261013.json) | f7aeada1 |
| 2026-10-13 | S6: one place for the flags | The "Flags and controls" section: one table of the default, the original window and full screen per host, and the common rules (the reviewer checked it against each host's code and four claims were corrected). Browser: the real flag name now wins over the alias when both are given, and Safari's prefixed `webkitfullscreenchange` is handled. Checks: the static page's six flag cases, S2's window sizes, clicks, full screen and Alt+Enter unchanged, the web scenarios in both engines (see evidence) | [evidence](../evidence/ws-s6-flags-20261013.json) | this commit |
| 2026-10-16 | Fix: a moved macOS original window | User report with a screenshot: after moving the window the picture stayed behind, shifted up and left by the move, black to the right and bottom. The screenshot's window is **the original fixed window** (794-point client); the scalable window was not affected (checked: moves, drags, after full screen and a resize). **Cause**: the fixed window follows its live geometry — the primary is cropped and clipped at the window's live client (`OriginalMacDisplayBackend.rectangle`) — while the game Blts at the rectangle its WM_MOVE handler stored at 453ccc, and the host sent WM_MOVE only once, at startup. Reproduced with `--original-window` (a 292×58 pt drag: the picture shifted by exactly that). **Fix**: the fixed window's AppKit move sends the game WM_MOVE when its client's origin changed (coalesced, one pending; none for held geometries or the popup), and so does an Alt+Enter recreation away from the game's last origin. Checks: a new runtime-menu test (the shifted frame without WM_MOVE, the whole frame after it), the Mac menu/window suites 22 tests 0 failures; live after the fix the same drag leaves only the game's cursor different, the scalable window identical, a moved window recreated by Alt+Enter whole; dragged mid-match in the vs script (no boundary), its progress captures and counters at bodies 300–1800 stay byte-identical to the e2e reference; e2e vs pass. Open: the fixed window moved partly off the screen still stops at the geometry boundary (pre-existing, reproduced); the SDL fixed window has the same model without move handling (unchecked); no independent review yet | [evidence](../evidence/ws-fix-window-move-20261016.json) | this commit |
| 2026-10-16 | Review and merge of the move fix | Reviewed by the session that requested it: WM_MOVE reaches the recovered WndProc (`OriginalWindowLifecycle` case 3; DefWindowProc answered 0), the scalable window, macOS full screen and the popup get none, the coalescing reads live geometry, the new test shows the cause and the fix. Asked for and run by the fix's author: a real drag of the original window mid-match (no boundary, the match captures at frames 300–1800 byte-identical to the vs reference). Merged into `main` with MENU_GAMEPAD (no conflicts); on the merged tree the runtime-menu tests (7, the move and gamepad ones), e2e vs, title-joystick and joystick pass with references equal | [evidence](../evidence/ws-fix-window-move-20261016.json) | this commit |

## Next task

The plan is complete; exp/window-scaling is merged into main at the user's
request (2026-10-13). Open, in order of value:

1. The user's choices (not blocking): a stretched or filled mode for a
   16:9 TV (it would distort or crop the original), and smoothing at
   non-integer scales (it would blur the pixels).
2. Windows SDL: build it, run its scenarios under CrossOver and check the
   resizable window at high DPI (SDL3's units there; the metrics 0,0,0).
3. Hand checks the harness cannot do: the macOS green button by hand, a
   Linux window manager's maximise and aspect hints, iPad taps, the Apple TV
   on a real TV (overscan), a phone browser.
4. Small items: the browser's own full screen (F11) could count as full
   screen in the original window; Android's original mode could clear its
   borders only after a geometry change (about 1 ms per tick on the A12);
   GetMessagePos under the SDL scalable window is exercised by no run.
5. The original fixed window after the 2026-10-16 move fix: moved partly
   off the screen (or to another display) it still stops at the display
   backend's geometry boundary; the SDL fixed window where positions are
   known (X11, macOS SDL, Windows) crops at its live position and handles no
   move event, so it probably shows the same shifted picture (unchecked);
   in a live macOS run the game's own Alt+Enter popup did not take a second
   Alt+Enter (seen once, the popup path untouched by the fix; the borderless
   window probably cannot become key).
