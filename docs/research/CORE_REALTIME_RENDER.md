# RT phase 1c design note — render pipelining

Constraint map made by a read-only agent on 2026-10-06 at 7ab76e9 for
[CORE_REALTIME](CORE_REALTIME.md) phase 1c. Abbreviations under `native/Sources`:
RL = NTSDRuntime/OriginalMacRuntimeLoading.swift, DB = NTSDRuntime/
OriginalMacDisplayBackend.swift, WB = NTSDRuntime/OriginalRuntimeWindowBackend.swift,
RS = NTSDRuntime/OriginalRuntimeSession.swift, RM = OriginalMacRuntimeMenu.swift,
FS = OriginalMacFrontService.swift, AG = NTSDCore/OriginalApplicationGraphics.swift,
AH/AA = NTSDAndroid/NTSDAndroidHost.swift / NTSDAndroidApp.swift, MW =
NTSDMacPlatform/OriginalMacWindowBackend.swift, SW = NTSDSDL/SDLWindows.swift.
Line numbers are as of 7ab76e9.

## What feeds back

- **Loaded replay (the hot path) is output-only.** `finish` (RL:450) replays
  each committed batch (RL:490 → RL:548-569) after quit/sleep/shell and before
  sounds, music, postMessage and replay files. The Core recorded fixed
  declared results (RL:139-142, 179, 182, 277); replay reads only the getDC
  handle check (throws, RL:561) and a test counter (RL:568).
- **Synchronous services whose results reach the Core** stay synchronous:
  `performBitmap` (DB:580-659), front-menu permits (RM:133-148 → FS:62-64), the
  DirectDraw `perform` (DB:363-439, also Alt+Enter inside `menu.step()` every
  tick), window size queries (WB:302-331).
- **Replay throws come from metadata** (lookup, released surface, rectangle,
  flags, text DC, window closed or wrong size), never from pixels, because the
  runtime sets `presentUnknownAsBlack` (OriginalMacRuntimeStartup.swift:87), plus
  `host.present` itself.
- **Errors are observable:** a replay throw at RL:490 skips that batch's
  sounds, music, postMessage and replay files, and the boundary reports that
  tick (`tools/app_e2e.py` compares boundary, milestones, overlay files). So
  validation stays on the main thread at the same point.

## Shared state

All of DB, WB, the hosts, RL, RS are `@MainActor`; the package is Swift 5 mode
(no data-race diagnostics: run ThreadSanitizer). Shared mutable state: surface
tables `live`/`history` (DB:167), `Surface.storage` (swapped by Flip DB:956,
nil on Release DB:317), `textDC` (DB:175), lazy `Storage.pending` writes
(DB:116-123, recorded by stretch DB:626-637), the Budget (already locked
DB:48-60), `presented`/`contentSize` (WB:90-92; read by `presentedPNG`, body
frame digests RS:387, the Mac input mapping MW:218), host state feeding input
(Android `frame`/`shown` AH:58 → touch and GetCursorPos; iOS `shown`; SDL
`textureSize`/`drawn`), text rasterisers (non-Sendable closures).

## Flush points

Before any synchronous display/bitmap/window service (FS:42,
OriginalMacBitmapService.swift:42, RL:144, WB.perform), observations (RS:316,
371-399, 509-523, 576), exits (RS:300-304, 320, 403, 524, `stop` RS:663),
Android surface callbacks (AA:45-49, 111-116), and in tests (`finish()` stays
synchronous by default).

## Hosts

| Host | Rule | Pipeline |
| --- | --- | --- |
| Headless | present is a no-op | first: correctness gates |
| Android | ANativeWindow lock/unlockAndPost work off main; destroy/redraw callbacks must block on the render lock (acquire/release the window) | second: the payoff |
| AppKit / iOS | view/layer updates main-only; CGImage can be built off main | pixels/crop off main, present on main |
| SDL | renderer/window main-only | as AppKit |

## Design

**Two-phase replay.** Phase A on the main thread at exactly RL:490: validate,
apply metadata effects (references, `live`, storage swap, text DC), rectangle
and window checks, `contentSize`/`shown`/counters, the getDC check, and emit
render operations holding **strong references to `Storage`** (never
`surface.storage`) with rectangles, colours, key, mirror, text and target
window; phase A never reads pixels or the known mask, and throws at the same
tick in the same order. Phase B on one serial render executor: the operations
in order, the crop, the present through a host render target confined to the
executor, then publish `presented`; the concurrent presenter cannot fail (its
checks run in phase A; see As built).

**Backpressure:** wait for batch N before submitting N+1 (at most one in
flight): batch N's pixels overlap tick N+1's Core work. **API:**
`submit(ops, tag)`, `flush()` (wait for the queued work). **Digests:** body N's digest when batch
N completes (compare_frames matches by body number). **Opt-in:** only with
`presentUnknownAsBlack` and operation logs off; tests stay synchronous.

**Risks:** pixel-reading validation in test configurations (stays synchronous);
`pending` writes and Flip/Release swaps race unless every synchronous service
flushes first and phase B uses only captured `Storage`; budget release delayed
when a Storage is freed on the render thread (unobservable under the 3 GiB
budget with flush-before-create); input-related host state must stay in phase
A or GetCursorPos/mouse mapping would depend on render timing (virtual-clock
runs report (0,0) and would not catch it); serialise text rasterisers; never
merge presents within a batch; flush before `exit`; a TSan pass on macOS.

## As built (phase 1c)

- `OriginalMacDisplayBackend.pipelinesFront` is set only inside
  `OriginalMacRuntimeLoading.replay` (gameplay batches) when the window host
  declares `presentsConcurrently` (headless, Android); AppKit, iOS and SDL keep
  every draw synchronous, and `--synchronous-render` turns pipelining off.
  `replay` flushes the previous batch first (at most one in flight).
- Front fill, copy and flip validate and change metadata on the main thread;
  `WindowBackend.preparePresent` runs present's checks there and returns a
  delivery. The render closure holds only `Storage` objects and values (a copy
  takes a `CopyPlan`, not the surfaces), applies the pixels, crops and calls the
  host's non-throwing concurrent presenter, then records `presented` under a
  lock. A failed present check applies the pixels first and throws at the same
  draw, as before.
- Every other display entry point (perform, prepare, bitmap paths, text steps,
  observations, pixels, framebuffer) flushes first. Window observations
  (`presentedFrame`, `presentedPNG`, `flushPresents` before snapshots) flush,
  and the session flushes before every exit and in `stop`.
- Android keeps the frame, surface and buffer geometry in a locked target that
  the surface callbacks also take; the window and the presented size used for
  touches are set on the main thread when the draw is replayed.
- With `--body-frame-digests` every body flushes right after its replay (no
  overlap); `run_headless_scenarios.py` with `NTSD_NO_FRAME_DIGESTS=1` runs with
  full overlap and still compares the game state and the 300-body frames.
