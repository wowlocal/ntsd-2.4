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

## Plan

| ID | Step | Status |
| --- | --- | --- |
| S0 | This card; the per-host survey | **done** |
| S1 | Apple TV: verify and make the launch fill the TV at 1080p and 4K (the view, its scale, safe areas/overscan), the original-format flag (1:1 at the screen's centre) | **done** |
| S2 | Browser: the original-format option (`?original`, config) beside today's fit and Full screen; integer or device-pixel snapping considered | **done** |
| S3 | macOS app: a resizable window (aspect kept, the game's geometry held at any size), the green button's native full screen, a default size larger than 1× where the screen allows, `--original-window` for today's fixed window | **done** |
| S4 | SDL (Linux, Windows): a resizable, high-density window holding the game's geometry, the native full-screen toggle, the original flag | queued |
| S5 | iPad and Android: the original flag, nearest filtering on Android, checks at several screens | queued |
| S6 | All hosts: the flag's name and defaults documented in one place, launch notes for each app | queued |

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
| 2026-10-13 | S3: the macOS scalable window | **By default the game window scales**: the game's 794×550 client is held from creation (the native full screen's mechanism, set on the lease since the backend registers it after `windowCreated`), the window resizes with its aspect kept (half size at least) and opens at the largest whole multiple ≥2 within 85% of the screen, else the fraction that fits (2× on the 6K test display); the size at the game's DestroyWindow (Alt+Enter) is the next window's. The picture is the layer's contents, scaled by the compositor, nearest. Clicks and GetMessagePos map through the picture. The green button's full screen fills (aspect kept) and returns. `--original-window` / `-NTSDOriginalWindow YES` keep the fixed window; scripted runs keep it unless `--scalable-window`. The new geometry test caught the hold silently failing on its first run (fixed). All 10 AppKit scenarios equal with 18,088 frames identical, fixed and scalable; live on the 6K display (upright, 98.7% of 4×4 px blocks uniform, a pid-posted click lands on its client pixel, full screen in and out, both flags). A/B fixed vs 2×: ms per tick 2.02 vs 1.74, process CPU 4.66 vs 3.30, peak 799 vs 692 MB (vs), 813 vs 702 MB (Demo); the first build's window-sized backing store cost +73..78 MB and was replaced. Two review rounds: round 1 found GetMessagePos inconsistent with the hold, clicks before the first frame, the remembered size and small screens (all fixed); round 2 OK. Boundaries: a moved window no longer reaches the fixed window's off-screen stops; MSG.pt in the game's own popup stays physical (pre-existing); hand checks of a real click and the green button open | [evidence](../evidence/ws-s3-macos-scalable-window-20261013.json) | this commit |

## Next task

S4: SDL (Linux, Windows). The SDL host already keeps the game's client
constant (`SDLWindows.swift` `w.client`) and letterboxes each present to the
window's current size with nearest scaling (105-121), mapping input back
through `drawn` (124-128). Add: `SDL_WINDOW_RESIZABLE` and
`SDL_WINDOW_HIGH_PIXEL_DENSITY` for the game's window, its aspect kept
(`SDL_SetWindowAspectRatio`), an initial size as on macOS (the largest whole
multiple ≥2 within 85% of the usable display bounds, else the fraction, at
least half), drawing in pixels (`SDL_GetWindowSizeInPixels`) while mouse
events stay in window coordinates; the platform's full-screen control
(`SDL_SetWindowFullscreen` desktop full screen on F11 and the window
manager's maximise/full-screen button, `toggleFullScreen` instead of the
unsupported boundary); `--original-window` (and `NTSD_ORIGINAL_WINDOW=1`)
keeps today's fixed window; scripted runs stay fixed unless
`--scalable-window`, as on macOS. Alt+Enter stays the game's popup. Gates:
the SDL scenarios (`--linux-sdl` offscreen) equal with frames identical; a
windowed check under a window manager (Linux in Docker with Xvfb and a
window manager, or the Windows build under CrossOver) at several sizes with
clicks; full screen in and out; the flag; review.
