# Memory growth in the game's menus

Branch `exp/menu-memory`, from `main` df74758a (2026-10-13). Found when the
user saw the tvOS/iPad simulator app at 11.22 GB in Activity Monitor ("по
памяти не утекает?"): an instance left idling in a menu for about seven
hours after the WINDOW_SCALING checks.

## Observation (2026-10-13)

- Idle in the main menu (real clock, music and sounds muted), `footprint`
  every 20 s: the Apple TV 1080p and iPad Air simulators grew linearly from
  165 to 386 MB over 460 s (≈29 MB per minute, ≈1.7 GB per hour) — the
  11 GB seen after about seven hours.
- macOS AppKit app, same state: `heap` live bytes 179 → 250 MB in 140 s.
- `heap` class counts 70–140 s apart: only the iteration delivery's history
  grows — `OriginalRetainedHistory` nodes of iteration cursors 1748 → 2431
  (tvOS, ≈10 per second) and 138 → 4404 (macOS, ≈30 per second), their
  receipt arrays ≈12 KB each (54 MB for 4406 on macOS); the bitmap and
  menu-graphics histories do not grow.

## Cause

`OriginalApplicationIterationDelivery` keeps every earlier nonempty iteration
cursor whose receipts hold a resource, so the resource stays alive through
copied platform/delivery contexts
([APPLICATION_ITERATION_HISTORY](APPLICATION_ITERATION_HISTORY.md)). Gameplay
ticks hold none and stopped being kept on 2026-09-30, but every menu
iteration draws through the display backend, whose replies retain the
surfaces they touched (`OriginalMacDisplayBackend` `retained = [s]`): the same
few surface objects every frame, each time with a whole cursor of requests
and replies. Nothing reads the kept cursors except their count.

## Change

The delivery keeps each distinct resource once — an array in the order first
held plus a set of their identities, both values that copies share until one
adds a resource — and counts the retaining iterations: the same resources stay
alive as before (the display backend looks resources up through a weak
history, so a released surface still gives `.released`, not `.owner`),
copies stay independent and a discarded attempt takes its additions with it,
but the requests and replies are no longer kept. The release order at the
last holder stays deterministic (insertion order; it was newest first).
`retainedIterationCount` keeps its meaning; `retainedResourceCount` is new and
joins the runtime-menu test's invariant hash and platform fingerprint.

The bitmap, menu-graphics and lifecycle deliveries keep their own
`OriginalRetainedHistory`, but their standalone drivers are only constructed
in tests (the runtime serves those requests through the iteration delivery),
so they do not grow in the app; the heap snapshots agree.

## Gates

1. Core suites in a release test build: the delivery, retained-history,
   observed iteration/graphics/bitmap/startup and runtime-menu suites, with
   the new regression test (1000 retaining iterations of the same surfaces
   keep two resources; copies keep what they had; everything is released
   with the last holder).
2. The existing hosts' gate (`mlgate.sh`): AppKit launches and all
   scenarios with frames, unchecked vs and Demo, the Mac load/frame-time A/B
   against the previous gate's binaries, the A12 A/B with music and sounds,
   the emulator's vs.
3. An idle-menu soak before and after on macOS (and a simulator): the
   footprint flat after warm-up, the history no longer growing.
4. Independent read-only review of the ownership change.

## Result (2026-10-13)

The AppKit app before (tw-w3e) and after, one at a time, heap live bytes from
the first sample to the end and the footprint:

| Run | Before | After |
| --- | --- | --- |
| Main menu, 4 min idle | 171 → 287 MB (7,441 history nodes) | 168.6 → 168.8 MB; footprint flat at 298 MB after warm-up |
| VS selection, 3 min idle | +13.8 MB (5,619 nodes) | −0.2 MB; footprint flat at 713 MB |
| VS session, 60,000 bodies (virtual clock) | +121 MB (35,460 nodes), footprint still rising ~1 MB per 10 s at the end | +37 MB (the first matches), footprint flat at 829 MB from 2 minutes on |
| Apple TV simulator, main menu, 4 min | +29 MB per minute | flat at 158 MB |

The gate (mm-2 against tw-w3e): the Core suites (the delivery suite with the
new test, retained history, observed iteration/graphics/bitmap/startup,
runtime menu, exclusivity) pass; 20 AppKit launches without a crash; all
AppKit scenarios equal with frames identical, the unchecked vs and Demo and
the emulator's vs identical; the Mac A/B 1.38 vs 1.43 ms per tick, process
3.33 vs 3.48; the A12 A/B main 10.86 vs 10.79 ms per tick in the gate and
10.86 vs 10.86 in a second interleaved A/B (drift), peak memory unchanged,
resident at body 1800 571 vs 583 MB.

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-13 | M1: each retained resource kept once | The idle menu stops growing on every host (≈30 MB per minute before); a long VS session's footprint goes flat; no frame-time or load cost (Mac faster, A12 equal in the second A/B); the gate passes; review OK (deterministic release order, one pass, the test and hash additions came from it) | [evidence](../evidence/menu-memory-20261013.json) | this commit |
