# RT budget — 33, 16 and 8 ms per frame on the Galaxy A12

Study: [CORE_REALTIME](CORE_REALTIME.md). User, 2026-10-06: "I want 8ms per
frame on the A12. starting from 33ms per frame, them we should strive to 16ms,
then to 8ms".

## What is measured

Frame time is the unthrottled compute time per gameplay tick in
`tools/crossplatform/android_speed.py` (no frame capture, the scripted VS
match): **1000 / ticks per second**. The game itself keeps its own rate; a
shorter frame time is headroom (smooth play, slower phones, battery and heat).
Presenting at 60 or 120 Hz is a separate question: more ticks per second
would speed the game up, so higher presentation rates would need
presentation-only pacing, never extra ticks.

The render pipeline (phases 1c–1f) splits a tick over two threads: the main
thread computes tick n+1 while the render thread replays tick n's pixel work
and presents it. **Each thread must fit the budget on its own.**

| Target | Ticks per second | Main thread | Render thread |
| --- | ---: | ---: | ---: |
| 33 ms | 30 | ≤ 33 ms | ≤ 33 ms |
| 16 ms | 62.5 | ≤ 16 ms | ≤ 16 ms |
| 8 ms | 125 | ≤ 8 ms | ≤ 8 ms |

## Where the time goes (R3 stage 1, 2026-10-06)

Phone: 18.95–19.26 ticks per second, **~52 ms per tick**, the main thread busy
throughout. Profile `rt-speed/rtr3s1-profile-profile` (simpleperf, 31,978
samples: main thread 61%, render thread 37%), split by the deepest game type
in each sample's call chain (`phone_breakdown.py` in the session scratchpad).

**Main thread, ~52 ms:**

| Share | ms | What |
| ---: | ---: | --- |
| ~43% | ~23 | Orchestration: Host attempt and commit (HostSession 7.6%), gameplay session (6.1%, mostly the per-event observer closure), menu session state slices and replaces (4.9%), loaded menu attempt `front`/`emit` (4.4%), runtime loading (4.2%), match preparation (3.6%), bindings (3.5%), runtime session (2.2%), request exchange (1.5%), graphics (1.5%), staged platform copy (1.2%), observed iteration (1.1%) |
| ~18% | ~9 | No game frame in the chain: mostly `swift_release`/deallocation whose caller is lost (runtime leaves keep no frame pointer), i.e. dropping copied state, plus allocator work |
| ~24% | ~12.5 | Game logic: AI (4.4%), contact memory (2.7%), bitmap drawing (2.7%), gameplay body (2.4%), post-draw (3.6%), FreeType glyph masks (2.1%), camera (2.0%), contacts, control, links, hits, world drawing |
| ~4% | ~2 | Display backend work on the main thread |

The drawing event path alone: every bitmap read and clip builds an
`OriginalFrontScreenEvent` that travels through the gameplay session's
observer and the attempt's `front` (string dispatch, no effect) and is then
dropped: **read events ~4.7%** of the main thread, clip and blit events
another ~4%.

**Render thread, ~32 ms:** pixel copy loop 27%, `memcpy` (row copies, crop,
window copy) 27%, known-mask checks 14% (phase 1g), Android channel swap 8.5%,
window post (`ioctl`) 6%.

## Tier 1 — 33 ms (main thread −20 ms)

The render thread already fits after 1g. The main thread needs about −37%,
all from orchestration and copies, without touching game logic:

| Step | Estimate |
| --- | --- |
| 4d: no read/clip events when nobody observes them (a flag from the runtime, which passes no observers) | −2.5 ms |
| Front event dispatch by an enum kind instead of string compares; no re-wrapping per observer level | −1.5 ms |
| R3 stages 2–4 (replay slot tier, `full` in parts, world pair cache) | −3 to −5 ms |
| R5/M3: nested candidate copies of globals and actors inside one attempt (~600 KB per tick) | −3 to −5 ms |
| Host attempt commit: the staged platform copy, `takeCommitted`, the step closure's own copies | −2 to −3 ms |
| FreeType glyph masks kept per glyph and size (deterministic memo) | −1 ms |
| Exclusivity checks off (`-enforce-exclusivity=unchecked`; user decision) | −1.5 ms |

Sum: about −15 to −20 ms, so ~32–37 ms. Each step is measured on the phone;
the order follows the profile after each commit.

## Tier 2 — 16 ms (both threads about halved again)

- **Main thread: a direct gameplay tick.** Orchestration has to fall from
  ~23 ms to ~2 ms. When a tick needs no host round trip (the common case
  since M2), run the gameplay body on the match model in place and commit
  without rebuilding the menu and Host attempt state around it. A failure
  still restores exactly the state the attempt path would have committed,
  with the same errors and boundaries. This is an architecture change: design
  note, oracle tests against the attempt path, independent review.
- **Game logic −30%:** reads and writes of state records check per-byte
  definedness and copy on write. Give the hot loops a mask-free view of the
  fields that are always defined during a match, and use buffer-level access,
  without changing values or operation order.
- **Render thread to ≤ 16 ms:** colour-keyed copies four pixels at a time
  (SIMD compare and select); one fused pass from the back buffer into the
  window buffer (crop, channel order and copy together instead of three
  passes); a native window format that avoids the swap if the device offers
  one.

## Tier 3 — 8 ms

- **Render:** draw on the GPU. Sprites and backgrounds become textures once.
  Blits are integer rectangles with nearest sampling and a colour-key test in
  the shader, so they can produce exactly the CPU's pixels. Read-back only for
  frame comparison and captures. The comparison gates stay as they are: every
  captured frame identical.
- **Main:** game logic ~5 ms. Typed hot state for actors and world, SIMD where
  the original loops are data-parallel, and no allocation in a steady-state
  tick. The original's update order and numeric semantics stay fixed.
  Parallel phases only where the recovered order proves independence.

## Rules that do not change

Same game, same frames, same errors: every gate in the card applies to every
step. Fixtures, references and expected values are never changed. Every
storage-model or architecture step gets an independent review.
