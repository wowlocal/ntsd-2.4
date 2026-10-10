# RT tier 3 — 8 ms per tick on the A12

Written 2026-10-08 after `rt-60fps-a12` (4aa/4ab): main thread 16.25 ms (vs) and
16.13 ms (Demo) per tick, render 13.8 / 12.0 ms. Source: a read-only planning
pass over the shipping build's DWARF profiles `rt4ab-vs-dwarf` and
`rt4ab-demo-dwarf` (7,010 and 4,626 main-thread samples, each assigned to one
group; the chains that stop at the gameplay body (32% / 41%) or at array deinit
(11% / 6%) are split by inference) and the run telemetry.

## Where the main thread's ~16 ms goes (ms per tick, vs / Demo)

| Cause | vs | Demo | Notes |
| --- | ---: | ---: | --- |
| Graphics command pipeline (`Attempt.front`/`emit`, `consume`, a Command and an Operation per Blt, their destroys) | 2.7 | 2.0 | Blts copy `BitmapInputs` (0.63%) and the whole graphics owner although Blt/fill only read it; each Blt is stored twice |
| Runtime replay and display checks on the main thread | 1.2 | 1.0 | a string switch per command, `serveFront` allocations |
| Drawing code (per glyph and sprite) | 1.2 | 3.4 | two `[Int32]` arrays, closures and 6–8 checked word reads per glyph; the Demo's font is 14.9% but little of it reaches `emit` (glyphs clipped?) |
| Record and array copies and their destroys | 1.5 | 1.1 | ~0.15 ms per transactional level of the 400-actor array; record-array destroys 3.9% / 2.4%; the globals copied ~4 times per tick |
| Replay recording buffer page tables (vs only) | 1.0 | 0.1 | each tick's packet write copies both 397-entry page arrays (2.9%) and frees them later |
| Idle iterations (Core part) | 1.1 | 0.9 | 3.12 × 0.69 ms in all |
| The due tick's message-loop step | 1.0 | 0.95 | a full Host step each tick |
| Host, session and attempt layering | 1.2 | 1.0 | four Host attempts per tick; `stagedCopy` 2.0% |
| Bindings read/store | 0.85 | 0.75 | 400 seat conversions each way, `MatchPreparation.init` |
| Game logic: the body's passes | 2.2 | 2.0 | checked `integer(at:)` reads 5.5% as a leaf |
| Game logic: entry input, AI, round | 0.7 | 1.15 | |
| Runtime and OS | 1.4 | 1.25 | Looper wake-ups ~0.55, music present 0.14, timer re-arm 0.11 |
| Unattributed | 0.5 | 0.5 | |

Across groups, retain + release is 33% / 30% of the main thread. Render thread
(13.9 / 12.0 ms): `copyPixels` 5.8 / 4.0, frame crop 1.8, Android channel swap
2.0, Android window post 1.35, window draw 0.5.

## Candidates (conservative savings, ms per tick, vs / Demo)

| ID | Mechanism | Saving | Risk | Changes what survives a failure? |
| --- | --- | ---: | --- | --- |
| G1 | Font and sprite path without per-glyph allocation when unobserved: clip on stack values, arrays only for a visible Blt; the font's style, target and viewport words read once at first use; no `fontGlobals` | 0.2–0.4 / 0.8–1.3 | low | no |
| G2 | Typed front-event lane: observer-only events not built when unobserved; Blt/fill/method by an enum code, not a string | 0.4–0.7 / 0.3–0.6 | medium | no |
| G3 | Compact command batch: Blt/fill checked without copying the owner or the inputs and stored as one fixed-size record; the public lists built only when read; the replay walks the records into one display entry with the same checks | 0.7–1.3 / 0.5–1.0 | medium-high | no |
| S1 | Two-level page tables for paged records (R3 stage 2): a write copies ~40 references instead of ~800 | 0.4–0.7 / 0 | low | no |
| S2 | Record storage v2: one buffer object per record (bytes, bit mask, undefined count), a fast path for fully defined records, whole-record `bytes`/`defined` only on demand | 0.4–0.8 / 0.3–0.6 | high | no |
| S3 | Actor table copied per chunk (25 × 16 records) behind Array's API | 0.2–0.4 | medium-high (after S2) | no |
| H1 | Bindings: the world pair cache (B1 3c); seat conversion skipped for unchanged buffers | 0.2–0.4 | low-medium | no |
| H2 | One fused loaded Host attempt per tick (B3 `advanceLoadedTick`), each phase's value kept so every failure leaves today's retained stage | 0.3–0.5 | medium | no |
| H3 | A due-tick step lane like `stepIdle`, the full path as fallback | 0.2–0.4 | medium | no |
| A | Idle lane: A3 L4b, L5, L6 | 0.5–0.9 | medium | no |
| R0 | Small runtime cuts: music presented only on change, flags parsed once, the random table checked with `memchr` | 0.1–0.3 | low | no |
| L | Typed hot fields in the body (after S2); dictionary lookups out of the per-Blt/per-actor loops | 0.3–0.6 | medium | no |
| B | One transactional copy for entry and body (an undo journal would keep today's behaviour but needs per-write logging; not worth it) | 0.15–0.4 | medium | **yes (Q1)** |
| D | Direct gameplay tick: one Host attempt over one pre-tick snapshot, bindings stored once | 0.6–1.2 (incl. B, H2) | high | **yes (Q2)** |
| L6b | Idle commits keep the previous committed platform | 0.15–0.3 | low | **yes (Q3)** |
| P | The display's checks on committed draws on the render thread | 0.4–0.9 | medium | **yes (Q4)** |

Render thread (no decisions): P2 (the back buffer lent as the frame, −1.0 to
−1.7 ms); the Android present (swap, draw, post) on its own thread with at most
one frame in flight per stage, latency unchanged (−3 to −4 ms); the frame drawn
by two threads owning half the rows each, operation order unchanged (−1.5 to
−2.5 ms).

## Order

1. Probe (telemetry only): glyph calls vs visible Blts, commands per tick,
   copies by size, actor-array copies, whole-record `bytes` reads; confirms or
   rejects the Demo clipping guess.
2. S1, G1 → ~15.4 / 15.0 ms.
3. G2, G3 → ~13.8 / 13.8.
4. A (L4b, then L5 and L6) → ~13.0 / 13.0.
5. S2, S3, H1 → ~12.0 / 12.3.
6. H2, H3, R0, L → ~11 / 11.5.

The render work runs alongside (P2, the present thread, the two-thread split)
toward ~7–9 ms. Every step takes the card's gates and phone runs of both
scenarios interleaved with the previous build; steps under ~0.25 ms are judged
by probes across several steps. S1–S3, G3, H2, H3, A and D get an independent
review.

**8 ms:** without the user's decisions the main thread reaches about 11 ms
(range 9–12.5) and the render thread about 8. Game logic alone is 2.9 / 3.2 ms;
with the drawing that cannot go, the idle wake-ups and one Host attempt there is
little room left. With Q2–Q4 the main thread lands around 9–10 ms; 8 then needs
L near its paper estimate (plausible for vs, doubtful for the Demo).

## Decisions for the user

Production stops on any error (`OriginalRuntimeSession.iterate` calls `stop`),
so Q1–Q3 change only what tests observe after a failure; Q4 moves when an error
surfaces by one tick.

- **Q1.** May a failed loaded tick leave the Host with only its pre-tick pending
  input instead of the post-entry Ready (changes
  `OriginalApplicationHostGameplayTests`)? Unlocks B.
- **Q2.** May any failure from the due iteration through the tail leave the Host
  at its last committed batch (no retained pending/Ready/returned stage, no tail
  retry)? Unlocks D and covers Q1.
- **Q3.** May idle commits keep the previous committed platform object (tests
  see different `platformSnapshot` values)? Unlocks L6b.
- **Q4.** May a display error on committed draws stop the game one tick later,
  after the next tick's Core work ran? Unlocks P.
