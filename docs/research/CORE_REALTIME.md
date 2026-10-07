# RT — Real-time play on slow phones (core redesign)

Workflow: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md); parent
studies [MOBILE_PERFORMANCE](MOBILE_PERFORMANCE.md) (steps 1–8) and
[CROSS_PLATFORM](CROSS_PLATFORM.md) (P8 Android).

**Consumer in native/ and integration criterion:** the Android app on the user's
Galaxy A12 (Helio P35, Cortex-A53 cores, 2.8 GB RAM): the scripted VS match runs
at the game's own rate, **≥ 30 gameplay ticks per second** without frame capture
(`tools/crossplatform/android_speed.py`, bodies 300→1800), and then plays
smoothly by hand. Every host keeps exactly the same game.
**Frame-time targets (user, 2026-10-06):** "I want 8ms per frame on the A12.
starting from 33ms per frame, them we should strive to 16ms, then to 8ms".
Frame time is the engine's compute per gameplay tick on each thread (main
and render each within the budget), from schedstat in `android_speed.py`
(`mainMsPerTick`, `renderMsPerTick`); wall time per tick includes the
original's own 33 ms pacing sleeps. **Tier 1 met on 2026-10-06 (phase 4f):**
virtual clock main 30.4 / render 22.2 ms per tick; with `--real-clock` the
scripted match runs at **30.25 ticks per second, the game's own rate** (main
26.1, render 19.3 ms). Next: 16 ms, then 8 ms. Plan per tier:
[CORE_REALTIME_BUDGET](CORE_REALTIME_BUDGET.md). Wall time per tick under
the virtual clock, for history: ~99 ms at the branch start (10.1 ticks/s, the
main thread ~98% busy with rendering on it), ~59 ms after 1f, ~52 ms after
R3 stage 1, ~49 ms after 4f.
**Reason:** user decision 2026-10-06: "make an experimental branch and do core
redesign for real time play on slow phones like A12. Original game was published
at 2008 and Samsung A12 has comparable performance GPU/CPU to the average
computers at that time."
**Status:** research and transfer.
**Branch:** `exp/core-realtime`, from `dev/crossplatform` 9df1054. It tracks
`origin/exp/core-realtime` (since 2026-10-06 09:38) and the post-commit hook
pushes every commit; user decision 2026-10-06: "Keep auto-pushing". Not merged
into `dev/crossplatform`/`main`, CI not enabled, nothing published without the
user.
**Game result:** unchanged by definition. Only how the port computes the game
changes (architecture, representation, loops), never what it computes or shows.
**Reference:** the pinned EXE (SHA-256 `3f7ac67c…ff71c`) is not touched. The
comparators are the frozen app_e2e references (10 scenarios), the frame
references (`m1-frames-ref`, the AppKit runs, the matrix groups) and the Core
suites.
**Declared scope:** the per-cycle architecture of Core and the runtime: the
session ↔ match-model bindings, rollback/transaction copies, per-cycle attempt
setup, allocation tables and record storage; the display backend's drawing and
present path; the Android host's drawing.
**Out of scope:** game rules, numeric semantics, error boundaries and their
order, fixtures, references and expected values; dropping runtime safety checks
(e.g. `-enforce-exclusivity=unchecked`) without the user.
**Executor / independent reviewer:** Claude / a separate read-only reviewer agent
for every storage-model or architecture change; a missing review is stated.
**Allowed paths:** `native/Sources/NTSDCore`, `native/Sources/NTSDRuntime`,
`native/Sources/NTSDAndroid`, `native/Sources/CAndroidNative`, test helpers and
new tests in `native/Tests`, `tools/crossplatform`, this card and its evidence.

## Starting point (2026-10-06, 9df1054)

Galaxy A12: **10.2 ticks per second** (5.4 before MOBILE_PERFORMANCE steps 1–8),
the main thread 98% busy. Inclusive phone profile after step 6b (simpleperf,
24,072 samples):

| Phase | Share |
| --- | ---: |
| Front-buffer drawing (`performFront`; copy loop ~14% own, Android window 4%, frame copy 3%) | 26.1% |
| Gameplay session (gameplay body 11.4%) | 17.1% |
| Loaded cycle (`LoadedMatchEntry.run` 4.0%) | 10.9% |
| Bindings store / read (model ↔ session state every cycle) | 7.0% / 2.5% |
| Loaded menu attempt (setup over every live allocation) | 4.6% |
| Menu state replace | 2.2% |

By symbol: `memcpy` 12.5%, reference counting ~15%. The remaining cost is spread
over the per-cycle round trip between the session state and the match model,
whole-state rollback copies, and drawing; each local fix in MOBILE_PERFORMANCE
gained a few percent, step 8 none measurable.

## Plan

Profile first, then one mechanism per increment, measured on the phone before
and after.

| Phase | Work | Status |
| --- | --- | --- |
| 0 | Measurement harness in the repository: `tools/crossplatform/android_speed.py` (speed without frame capture, peak memory, optional simpleperf profile with an inclusive phase table and restoring the phone's settings); baseline at the branch start | **done** |
| 1 | Display path: the keyed sprite copy loop (a third of the copied pixels), the present path (frame copy, Android channel swap), fill loops | 1a, 1d done |
| 1c | **Render pipelining:** replay each committed batch's draw commands on a render thread while the main thread computes the next tick. The Core records declared results for draws and never reads pixels back (`OriginalMacRuntimeLoading.replay`), so the replay (pixel copies, frame copy, Android drawing: ~25–30% of the phone's main thread) only needs its order kept and flushes wherever a frame is observed (captures, frame digests, window events, errors). The A12 has eight cores with one busy. A design note first (display backend isolation, flush points, error propagation) | done |
| 2 | Per-cycle round trip: keep the match model across cycles instead of `bindings.read`/`store` every cycle; a design note first (who reads the session memory between cycles, which invariants and commit points must hold): [CORE_REALTIME_DATAFLOW](CORE_REALTIME_DATAFLOW.md) | 2a, 2b done; R3–R5 open |
| 3 | Rollback copies: the allocation table copied per cycle; the attempt's per-cycle setup over every allocation made incremental | queued |
| 4 | Gameplay session/body overheads and reference-counting traffic (record copies, dictionary iteration) | queued |
| 5 | Loading time on the phone (~4.5 minutes) | queued |
| 6 | Frame-time tiers 33 → 16 → 8 ms per tick on the A12 (user, 2026-10-06): where each millisecond goes and the steps per tier, [CORE_REALTIME_BUDGET](CORE_REALTIME_BUDGET.md) | tier 1 in progress |

## Gates (every increment)

1. Cheap compile checks, then the macOS release headless build.
2. Headless vs equal and its 1,832 frames identical to `m1-frames-ref`.
3. All 10 scenarios equal on a frozen copy of the binary.
4. AppKit vs and playback equal, frames identical to the previous AppKit run.
5. The affected Core suites in a release test build (`build/swiftpm-test-release`;
   no source edits while a bundle compiles).

Gate binaries come from clean builds (4u): remove the scratch folder (and on
X5 `build-android-aarch64`) before building the headless and AppKit binaries,
the release test bundle and the APK. Release builds compile each module whole,
and with cross-module optimization (4k) an unchanged client module keeps the
inlined code and class sizes of an older dependency: an incremental AppKit app
allocated `OriginalRuntimeSession` 24 bytes short and corrupted its heap at
startup. A clean build takes ~2 minutes per binary and ~6 for the test bundle.
6. Phone speed with `android_speed.py`; a profile when the result needs explaining.
7. An independent read-only review for storage-model or architecture changes.
8. At each phase end: the full nine-host matrix (`matrix.py`).

Commit an increment only when every gate passes and it is either measurably
faster or strictly less work without added complexity; otherwise record the
result here and revert. While the phone cannot be measured (unavailable, or
busy with another measurement), an increment whose other gates pass and that is faster in the Mac A/B
of frozen binaries and on the emulator may be committed with gate 6 recorded as
open (AGENTS.md: a missing device check blocks only its dependent work and
acceptance); it is measured on the phone as soon as possible and reverted if it
is not faster there. Keep X5 above 20 GiB free (archive finished runs to T7
with per-file verification). The phone has only a swipe lock (AGENTS.md, Test
devices): a lock screen pauses the game, so it is dismissed over adb, and
`android_speed.py` does that and keeps the phone awake (`svc power stayon usb`)
while measuring; restore `svc power stayon false` when the loop pauses or stops.

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-06 | Branch and card | `exp/core-realtime` from 9df1054; this card | — | 36edf83 |
| 2026-10-06 | Phase 0: harness and baseline | `android_speed.py` committed; **baseline 10.07 ticks per second**, peak 1.33 GB. Inclusive: front-buffer drawing 19.7%, gameplay session 17.3% (body 11.4%), loaded cycle 11.3%, bindings store 7.4%, Android window drawing 6.8%, loaded menu attempt 4.7%, loaded match entry 4.2%, display perform 3.1%, bindings read 2.7%, menu state replace 1.9%. Self: memcpy 16.1%, retain/release 14.6% (+ atomics 3.9%) | [evidence](../evidence/rt-baseline-20261006.json) | 35ec7a3 |
| 2026-10-06 | Phase 1a: Android window drawing | Black only outside the frame, channel swap four pixels at a time (SIMD). Window drawing 6.8% → 3.2% of phone time; 10.07 → 10.16 ticks per second (within run variation). Emulator vs equal, frames identical; swap checked equal to the old formula. | [evidence](../evidence/rt-1a-android-draw-20261006.json) | f8a3758 |
| 2026-10-06 | Phase 2a: per-session caches (R1, R2) | MatchBindings and the static address ranges built once per loaded session; the attempt's starting ranges collected only when an allocation needs them. **10.07/10.16 → 10.47/10.48 ticks per second** (two runs). 86 suites, all scenarios and AppKit equal; review OK | [evidence](../evidence/rt-2a-session-caches-20261006.json) | 90e23bf |
| 2026-10-06 | Phase 2b: actor pair cache | MatchBindings keeps each actor's last session/model record pair; an actor unchanged since the last read or store is neither converted nor rewritten (first step toward DATAFLOW R3). **10.47/10.48 → 11.21/11.20 ticks per second** (+7%); Mac busy time −7.3%. 87 suites, all scenarios and AppKit equal; review OK | [evidence](../evidence/rt-2b-actor-pairs-20261006.json) | 6bbda82 |
| 2026-10-06 | Phase 1c: render pipelining | Committed gameplay batches' pixel work, crop and present run on a serial render thread on headless and Android (at most one batch in flight; every other display entry point, observation and exit flushes; AppKit/iOS/SDL unchanged). **11.21/11.20 → 11.94/11.92 ticks per second** (+6.5%); game-thread busy 285 → 270 s; Mac busy −6.2%. All 10 scenarios equal with frame digests and with full overlap, frames identical; ThreadSanitizer clean; AppKit equal; 13 suites; review OK after four fixes | [evidence](../evidence/rt-1c-render-pipelining-20261006.json), [design](CORE_REALTIME_RENDER.md) | 72b9521 |
| 2026-10-06 | Phase 1d: colour fills by row | The DirectDraw colour fill (`blt`, served by the menu loop every frame) and the front fill write one row store and whole mask words per row instead of a value and a bit per pixel. **11.94/11.92 → 12.11/12.10 ticks per second** (+1.5%); Mac process CPU −3.0%. All 10 scenarios and AppKit equal, frames identical; 13 suites; review OK | [evidence](../evidence/rt-1d-row-fills-20261006.json) | 1e364bc |
| 2026-10-06 | Phase 1e: pipelined text | Every text step flushed the render queue, so a batch drawing HUD text waited for its pixel work (20% of the Mac main thread's busy time). The DC steps no longer flush; TextOutA keeps its checks and glyph mask on the main thread and queues the pixels and present. **12.11/12.10 → 14.22/14.18 ticks per second** (+17%). All 10 scenarios and AppKit equal, frames identical; Android frames (with glyphs) identical; ThreadSanitizer clean; 13 suites; review OK | [evidence](../evidence/rt-1e-pipelined-text-20261006.json) | 86d5e5d |
| 2026-10-06 | Phase 2c: resource records kept per session | A copy probe found gameplay's `resource` helper copying the 0x1f50-byte bitmap resource record ~108 times per cycle; the model branch's no-op write is dropped and the allocated branch's result is kept per token in `PendingInput.Derived`. 0x1f50 copies 363,586 → 119,791 per run (the rest at load). **14.22/14.18 → 14.55/14.54 ticks per second** (+2.4%). All 10 scenarios and AppKit equal, frames identical; 94 suites; review OK | [evidence](../evidence/rt-2c-resource-records-20261006.json) | 709c178 |
| 2026-10-06 | Phase 2d: unchanging record writes return early | The probe found most copy-on-write copies of large records caused by writes storing what was already there (the globals' 8-byte replace 26,688 times per run, its slice 16,202, actor records 82,975). Flat `write`/`overwrite` now return when the bytes and definedness are already there; a unit test covers the four cases. **14.55/14.54 → 14.85/14.69 ticks per second** (+1.5%). All 10 scenarios and AppKit equal, frames identical; 154 suites (437 tests); review OK | [evidence](../evidence/rt-2d-unchanging-writes-20261006.json) | f3cf76a |
| 2026-10-06 | Phase 4a: loaded-session data in one shared object | `PendingInput` (built once per loaded session, ~250 retained references, copied ~40 times per cycle inside the menu session, bootstrap and continuations) keeps its fields and memo in one final class read through `_read` accessors ([copy map](CORE_REALTIME_COPIES.md) M1). **14.85/14.69 → 16.01/16.04 ticks per second** (+8.5%); Mac sample: MenuSession 3.0% → 1.3%, Bootstrap 2.0% → 0.7% of busy time. All 10 scenarios and AppKit equal, frames identical; 94 suites; review OK | [evidence](../evidence/rt-4a-shared-loaded-session-20261006.json) | 45f3cdf |
| 2026-10-06 | Phase 4b: graphics consumed in place per draw | Both `emit` paths called `consume` on a copy of the graphics owner and stored it back; `consume` is all-or-nothing, so it now runs on the owner in place ([copy map](CORE_REALTIME_COPIES.md) M4). 16.01/16.04 → 16.01/16.06 ticks per second (no measurable change; committed as strictly less work: one owner copy, about 14–21 reference-count operations, fewer per draw). All 10 scenarios and AppKit equal, frames identical; 105 suites; review OK | [evidence](../evidence/rt-4b-graphics-in-place-20261006.json) | 7190530 |
| 2026-10-06 | Phase 4c: flat record reads through the buffers | `integer(at:as:)` (3.4% self plus `checkedRange` 1.8% of the phone's main thread) checked definedness through an array slice and assembled the value byte by byte; it now loops over the mask's buffer and loads the value unaligned, with the same errors in the same order. 16.01/16.06 → 16.10 ticks per second (one run; within noise, less work). All 10 scenarios and AppKit equal, frames identical; 154 suites and a new flat-read unit test; review OK | [evidence](../evidence/rt-4c-flat-reads-20261006.json) | 81b40e4 |
| 2026-10-06 | M2a: message-queue requests served inside the Host attempt | A gameplay tick ran the menu loop's Host attempt 5–6 times, once per unrecorded request; an opt-in accepting inline cursor now serves `.queue` requests inside the attempt (same requests, order, replies, counters and bound; production passes no observers) ([design](CORE_REALTIME_M2.md)). **16.10 → 16.70/16.57 ticks per second** (+3.6%); Mac CPU −2.6%. All 10 scenarios and AppKit equal, frames identical; 105 suites; side-by-side test (counters, messages, clock calls, committed globals, frames, bounds, a failing clock); review OK | [evidence](../evidence/rt-m2a-inline-queue-20261006.json) | dda500b |
| 2026-10-06 | M2b: the window Blt served inside the attempt | The back-buffer clear (dispatch entry each iteration, ArtSetup, Alt+Enter) is served inline too, so a gameplay tick runs the Host attempt once; its target is always the back buffer (nothing presented). 16.70/16.57 → 16.66/16.73 ticks per second (within noise); Mac CPU −2.7% (four rounds). All 10 scenarios and AppKit equal, frames identical; 105 suites; review OK | [evidence](../evidence/rt-m2b-inline-blt-20261006.json) | b22545a |
| 2026-10-06 | Phase 1f: back-buffer fill queued on the render thread | The DirectDraw colour fill that clears the back buffer every iteration (the menu step's Blt, 2.5% of the phone's main thread after M2b) joins the render queue without a flush on hosts that present concurrently, in menus too; a primary's fill flushes and presents on the main thread. **16.66/16.73 → 16.87/16.87 ticks per second** (+1%). All 10 scenarios and AppKit equal, frames identical; full-overlap runs equal; ThreadSanitizer clean; 13 suites; review OK | [evidence](../evidence/rt-1f-back-fill-20261006.json) | e122049 |
| 2026-10-06 | R3 stage 1: the actor tier | The presentation memory's allocations become an `OriginalAllocationTable` (the dictionary's API) whose actor tier holds the 400 actor records in match-model form while a match is loaded; `read` takes them as they are and `store` keeps today's per-index checks with constant-time shortcuts and installs the model's records instead of converting and writing 400 entries; any other actor change moves the tier back into the dictionary ([design](CORE_REALTIME_R3.md)). **16.87/16.87 → 19.09/19.26 ticks per second** (+13.6%; 59 → 52 ms per tick); Mac CPU within noise. All 10 scenarios and AppKit equal, frames identical; 162 suites incl. oracle tests (store and read against the per-entry algorithm under single and multiple faults) and a table-against-dictionary test; no tier dissolves in a vs run; review OK after a compile fix | [evidence](../evidence/rt-r3s1-actor-tier-20261006.json) | a83c5ad |
| 2026-10-06 | Phase 1g: known-mask full flag (render thread) | The display backend's known mask keeps a flag meaning every pixel is known (set by a whole fill, a whole unkeyed copy of a full source or `setAll`, cleared by any bit-clearing write, recomputed after recorded image writes); the render thread's per-row `allKnown`/`setRange` work (13.9% of its samples) returns at once while it is set, which in the live app is always. Phone 19.19/19.10 ticks per second (main thread unchanged); **render thread −7.4% per tick** (render/main samples 0.606 → 0.561, ~32 → ~29.6 ms). All 10 scenarios and AppKit equal, frames identical; 13 suites incl. a new flag regression test; review OK | [evidence](../evidence/rt-1g-known-flag-20261006.json) | 11bb598 |
| 2026-10-06 | Phase 4d: no drawing detail nobody observes | On every gameplay tick each bitmap draw built read and clip records and the drawing helpers built draw and rectangle events, all no-ops in every session's `front`, for observers production never attaches (4.7% of the main thread for reads alone). A `detail` parameter (default true) lets the runtime, which passes no observer, skip them; stage events and blits are never gated. **19.19/19.10 → 19.82/19.78 ticks per second** (+3.4%; ~50.5 ms per tick). All 10 scenarios and AppKit equal, frames identical; a side-by-side test of every active gameplay tick with and without detail; 54 suites; review OK | [evidence](../evidence/rt-4d-draw-detail-20261006.json) | 29a15de |
| 2026-10-06 | Phase 4e: the random table in one copy | Fourteen sites (AI, physics, links, contacts, hits, control, post-draw, mission, war, music…) rebuilt the 3000-byte random table on every random draw with 3000 checked single-byte reads; `OriginalRandom.table` copies it at once when every byte is in range and defined and otherwise runs the same reads (same first error). AI draw 4.5% → 0.9% of the main thread. 19.82/19.78 → 20.30/19.94 ticks per second (~+1%: the harness's virtual clock adds ~16 ms of the game's own sleeping to every tick). All 10 scenarios and AppKit equal, frames identical; 146 suites and a new table test; review OK | [evidence](../evidence/rt-4e-random-table-20261006.json) | 6d06ad3 |
| 2026-10-06 | Phase 4f: the presentation input built directly | The runtime built the gameplay session's `OriginalMenuPresentationInput` every tick through JSONSerialization and JSONDecoder (2.6% of the main thread) for want of a public initializer; it now has one and the runtime builds the same values directly. 20.30/19.94 → 20.39/20.28/20.35 ticks per second (+1.4%); compute per tick main 30.4 ms, render 22.2 ms; real clock 30.25 ticks per second. All 10 scenarios and AppKit equal, frames identical; 35 suites and the 4e review's extra table cases | [evidence](../evidence/rt-4f-presentation-input-20261006.json) | e4b89f0 |
| 2026-10-07 | Phase 4g: each replayed draw validated once; menu-step timing | `prepareFront` validated every draw and discarded the result before `performFront` validated it again; the committed-batch replay now uses `prepareAndPerformFront` (one validation). The progress events also time the message-loop iteration, and the harness reports the tick split. Phone: complete 22.5 → 22.3/22.4 ms, main 30.7 → 30.4/30.6 ms per tick (within variation; committed as strictly less work). Split: loaded cycle 22.3 ms + 4.12 iterations × 1.51 ms + ~2 ms. All 10 scenarios and AppKit equal, frames identical; 13 suites incl. a side-by-side test of both paths; review OK | [evidence](../evidence/rt-4g-single-validation-20261007.json) | 97df2ec |
| 2026-10-07 | A0: no merged copy for an absent observer | Each message-loop iteration and each tick copied the ~100 KB `full` record only to give a `beforeCommit` observer a merged state; production attaches none, so the runtime passes `observesCommit: false` and the menu session runs the merge's checks without the copy ([design](CORE_REALTIME_TIER2.md)). Iteration 1.51 → 1.44 ms, main 30.4/30.6 → 29.9/30.3 ms per tick. All 10 scenarios and AppKit equal, frames identical; 48 suites and an on/off test (its first setup was wrong and was fixed); review OK | [evidence](../evidence/rt-a0-lazy-merge-20261007.json) | 0ae8cbf |
| 2026-10-07 | A1 + A2: idle iterations through a Host kernel | An idle message-loop iteration (no message, the timer not due) runs the step's own loop code on a copy and commits in place (`HostSession.stepIdle`, `ObservedIteration.resumeIdleFirst`); anything else falls back to the whole step over a fresh cursor that replays the served requests; the iteration delivery's cursor is updated in place ([design](CORE_REALTIME_TIER2.md)). Iteration 1.44 → 1.22 ms, main 29.9/30.3 → 29.2/29.0 ms per tick (−1 ms; the design estimated ~3: a kernel iteration still costs ~1.05 ms on the phone); real clock 30.24 ticks per second, main 25.5 ms. All 10 scenarios and AppKit equal, frames identical; 50 suites and a side-by-side test (menus, a key press, request bounds, a clock leap past the 100 ms catch-up, clock failures); review OK (gap: the design's Core-level two-Host oracle) | [evidence](../evidence/rt-a1-idle-kernel-20261007.json) | 3b3d7f5 |
| 2026-10-07 | Phase 1i: crop buffers reused (1h tried and reverted) | Every present allocated and zero-filled a fresh 1.75 MB crop buffer and freed it (page faults, zeroing, returning the pages); the display backend now reuses the oldest of the last three (copy-on-write if anything still holds it; every byte overwritten). **Render thread 22.0/22.3 → 20.4/20.2 ms per tick** (−8.5%). 1h (keyed and mirrored copies four pixels at a time) gave no measurable gain (the render thread is bound by memory traffic) and was reverted; its strengthened copy-model test is kept. All 10 scenarios and AppKit equal, frames identical; 13 suites | [evidence](../evidence/rt-1i-crop-buffers-20261007.json) | 8d02926 |
| 2026-10-07 | Phase 4h: glyph masks remembered by string | The display backend asked the host's font for every TextOut's glyph mask (FreeType 2.5% of the phone's main thread); it now remembers masks by the string's bytes (bounded), every host's provider being a fixed function of the bytes. Main 29.0 → 28.3/28.2 ms per tick. All 10 scenarios and AppKit (real Mac text) equal, frames identical; emulator frames (FreeType text) identical; 9 suites | [evidence](../evidence/rt-4h-glyph-masks-20261007.json) | d8a1a21 |
| 2026-10-07 | B1 3a: a record in parts (no production record split) | `OriginalStateRecord` gains fixed flat parts next to flat and paged storage: a slice or overwrite at one part's exact extent shares or installs its buffers, everything else runs over logical offsets with the flat record's values and errors, whole reads are assembled on demand, cached and counted; the hot `full.bytes` sites use `byteCount` and range accessors ([plan](CORE_REALTIME_B1.md)). A first version with `parts` as a second optional field made every flat record 48 bytes instead of 40 and cost main 28.2/28.3 → 29.3/29.2 ms per tick; paged and parted storage now share one field (40 bytes), main 28.5/28.4 ms (within variation). All 10 scenarios and AppKit equal, frames identical; 170 suites (496 tests) incl. a model test against flat records; review OK (the fold reviewed with 3b) | [evidence](../evidence/rt-b1a-parts-20261007.json) | 74a3583 |
| 2026-10-07 | B1 3b: the menu state's `full` record in parts | `MenuSession.State.init` holds `full` in parts at globals, outer local, loop counter, saved playback, replay alias, rest of the outer block, World and the tail; every production slice and replace is one part or inside one, so bindings read/store, the iteration's counter write and alias merge and `validateAliases` share or install buffers instead of copying ~100 KB; whole reads are counted (`partAssemblies`, 0 per tick on the phone and through a headless vs run). Main 28.5/28.4 → 27.9/27.6 ms per tick, complete 21.5 → 21.1/21.0 ms, iteration 1.23 → 1.14 ms (the plan estimated 1.2–2.2 ms). All 10 scenarios and AppKit equal, frames identical; 170 suites (500 tests) incl. flat-twin tests at the record, state and step level and byte checks after failed attempts; review OK after test and probe fixes | [evidence](../evidence/rt-b1b-parts-live-20261007.json) | b62edc7 |
| 2026-10-07 | Phase 4i: bitmap owner checks and sound tokens per loaded session | Every bitmap draw compared the kept resource record and the model's bitmap record (0x1f50 bytes and mask, equal but in different buffers; 2.8% of the main thread) and every tick rebuilt the sound-buffer token set; the loaded session's cache keeps the token set and, per token, the last pair found equal, which is equal again while both buffers are the same. Main 27.9/27.6 → 26.9/27.1 ms per tick. All 10 scenarios and AppKit equal, frames identical; 54 suites incl. a seeded test against `==` | [evidence](../evidence/rt-4i-session-memos-20261007.json) | ae480dc |
| 2026-10-07 | Phase 4j: the store's actor-pair checks in one pass | `bindings.store` looked up each of the 400 actors' pairs (a lock, two optional record copies and a compare each; with exclusivity checks 1.5%+ of the main thread); the pairs now keep each model record's buffer identity and answer for all 400 in one lock whether the record still shares the model's buffers, and only the others take the lookup. Main 26.9/27.1 → 25.9/25.6 ms per tick. All 10 scenarios and AppKit equal, frames identical; 55 suites and a unit test that every shortcut answer agrees with the lookup | [evidence](../evidence/rt-4j-pair-identity-20261007.json) | 693348e |
| 2026-10-07 | Phase 4k: cross-module optimization in release builds | NTSDCore and NTSDRuntime build with `-cross-module-optimization` in release configurations (no semantic flag), so the generic Host, iteration and session code that the runtime uses with one platform type is specialized instead of running through value witnesses (`takeCommitted`: 0 → 4 specialized symbols; binary +5.5%; Mac CPU −2%). Main 25.9/25.6 → 24.9/25.0 ms per tick, message-loop step 1.13 → 0.97 ms. All 10 scenarios and AppKit equal, frames identical; all 172 suites (503 tests) | [evidence](../evidence/rt-4k-cross-module-20261007.json) | 563f1d9 |
| 2026-10-07 | Phase 4l: the pending loading's values in one shared object | `MenuSession.PendingLoading` (a whole State plus staged lists) is copied and dropped many times per tick (Host attempts, retained stages, the runtime's loaded cycle); its destroys alone were 2.5% of the main thread (DWARF profile `rt4k-dwarf`). Its fixed values now live in one private final class read through `_read` (as 4a), so a copy retains one object. Main 24.9/25.0 → 24.6/24.5 ms per tick, iteration 0.97 → 0.94 ms. All 10 scenarios and AppKit equal, frames identical; all 172 suites (503 tests); review OK | [evidence](../evidence/rt-4l-pending-loading-20261007.json) | 8840eb3 |
| 2026-10-07 | Phase 4m: the loaded cycle's continuation, pending return and match prelude in shared objects | `Input.PendingContinuation` (~380 references per copy) and `PendingReturn` / `PendingMatchPrelude` (a continuation plus a Snapshot, ~460) are copied in the Host's pending and prepared stages, `LoadedCommit.menu` and every loaded batch; their fixed values now live in one private final class each (as 4a, 4l). Main 24.6/24.5 → 23.8/23.9 ms per tick, iteration 0.94 → 0.89 ms. All 10 scenarios and AppKit equal, frames identical; all 172 suites (503 tests); review OK | [evidence](../evidence/rt-4m-loaded-continuation-20261007.json) | bf5628e |
| 2026-10-07 | Phase 1j: keyed copies without known-bit work over a full target (render thread) | A row whose source span is fully known over a target whose mask is full (always in the live app) takes only the key test and the store; the bits it would gather are already set and none is cleared. A12 benchmark of 300 keyed 80×80 blits: 18.6 → 11.3 ms per frame (branchless 21.5 and SIMD 19.6 ms: the phone is bound by memory traffic, which explains 1h); present passes cost ~1.7 ms per frame whatever the per-pixel work. Render thread 18.1 → 17.5 ms per tick. All 10 scenarios and AppKit equal, frames identical; 12 suites incl. the per-pixel model over a full target | [evidence](../evidence/rt-1j-keyed-full-target-20261007.json) | e3dcd6a |
| 2026-10-07 | Phase 4n: the loaded owners and the batch delivery context in shared objects | `MenuSession.LoadedOwners` (the match model, music, resources, backgrounds) is copied with every menu session copy and `Host.DeliveryContext` (a whole Bootstrap plus the retained platform) travels in every batch; their fixed values now live in one private final class each (as 4a, 4l, 4m). Main 24.1/24.0 → 23.5/23.8 ms per tick, iteration 0.90 → 0.80/0.83 ms. All 10 scenarios and AppKit equal, frames identical; all 172 suites (503 tests); review OK | [evidence](../evidence/rt-4n-owners-context-20261007.json) | e209133 |
| 2026-10-07 | Phase 4o: no read-only copies of the session in Host attempts | Host `step` bound a copy of the whole menu session to read `.state`, `prepareBoundary` and `makeLoadedCycle` to test the loaded owners, and the loaded run copied the whole committed Bootstrap under the lock to read `startup`; they now read in place after the same checks (and `committedStartup`). Main 23.5/23.8 → 23.8/23.7 ms per tick (no measurable change; committed as strictly less work). All 10 scenarios and AppKit equal, frames identical; all 172 suites (503 tests) | [evidence](../evidence/rt-4o-session-reads-20261007.json) | aba1e4e |
| 2026-10-07 | R1: the present's back-buffer copy and crop fused (render thread) | When a pipelined present copies the whole known back buffer unkeyed onto exactly the presented rectangle, the frame is cropped from the back buffer (the same bytes) and the copy into the primary is recorded, written by the primary's next access; a covering newer copy replaces it, a moved one writes it at once ([plan](CORE_REALTIME_RENDER_PASSES.md) P1). **Render thread 17.5/17.3 → 15.8/14.2 ms per tick: tier 2 met on the render thread.** All 10 scenarios, AppKit and the emulator equal, frames identical; 12 suites; review OK after a fix for moved rectangles (gap: no unit oracle, as no test window host presents from the render thread) | [evidence](../evidence/rt-r1-present-crop-20261007.json) | 6941d89 |
| 2026-10-07 | Phase 4p: frame allocation order made once per loaded catalog | World contacts and actor hits sorted the ~14,600 frame allocations by address on every construction, twice per tick (4.5% of the main thread); the loaded catalog now keeps the order (same comparator) and the two production sites pass it, a match's allocations keeping the catalog's addresses in its order. A first version (skip the sort when already ordered) did nothing: the allocations are not in address order. **Main 23.6/23.3 → 21.8/21.9 ms per tick.** All 10 scenarios and AppKit equal, frames identical; all 173 suites (504 tests; part rerun after the Mac restarted); review OK | [evidence](../evidence/rt-4p-frame-order-20261007.json) | 606cfd1 |
| 2026-10-07 | Phase 4q: the post-draw slot event adapter made once per pass | `PostDrawLifecycle.Body.run` built a fresh escaping closure converting slot events for each of the 400 slots per tick; it is built once per pass. Main 21.8/21.9 → 21.9/21.7 ms per tick (no measurable change; committed as 400 fewer allocations per tick). All 10 scenarios and AppKit equal, frames identical; 59 suites | [evidence](../evidence/rt-4q-slot-adapter-20261007.json) | b9d59af |
| 2026-10-07 | B2 P1: post-draw slot passes and the actor scheduler in place | The slot prefix, opoint and scheduler gain an in-place mode that moves the caller's records into the pass and writes them back in a `defer` (the default stays all or nothing); the post-draw lifecycle, which drops its body on any throw, calls the prefix and opoint in place, and the prefix calls the scheduler in place ([plan](CORE_REALTIME_B2.md)). Main 21.9/21.7 → 20.9/20.9 ms per tick. All 10 scenarios and AppKit equal, frames identical; all 173 suites (504 tests; part rerun after the Mac restarted); review OK | [evidence](../evidence/rt-b2p1-postdraw-in-place-20261007.json) | f335320 |
| 2026-10-07 | B2 P1b: one in-place body per pass; corpora through both paths | The B2 P1 review's follow-up: the copying forms copy, call the in-place form and assign; the prefix, opoint and scheduler corpora run every case through both forms against the same recorded expectations; a scheduler throw inside the prefix leaves the prefix's caller unchanged. The check's first version waited for two scheduler sounds (none exist) and failed; it now throws at the first. Main 21.1/21.0 ms per tick (unchanged). All 10 scenarios, AppKit and the emulator equal, frames identical; 65 suites | [evidence](../evidence/rt-b2p1b-one-body-20261007.json) | 2a03667 |
| 2026-10-07 | Phase 4r: inactive post-draw slots end before their passes | The slot prefix ran its setup for all 400 slots per tick and returned at once for the ~350 inactive ones; the lifecycle reads the slot's activity byte first (the prefix's own first read, with its error) and ends an inactive slot. Main 21.1/21.0 → 20.5/20.3 ms per tick. All 10 scenarios, AppKit and the emulator equal, frames identical; 65 suites | [evidence](../evidence/rt-4r-inactive-slots-20261007.json) | 1d1055f |
| 2026-10-07 | B2 P2: the loaded match entry's sub-steps in place | The entry copies its state, commands and context once and drops them on any throw; its control, received-input, replay and round sub-steps now run their existing bodies on that copy instead of copying again ([plan](CORE_REALTIME_B2.md)). Main 20.5/20.3 → 20.1 ms per tick (four runs). All 10 scenarios, AppKit and the emulator equal, frames identical; all 173 suites (504 tests); review OK | [evidence](../evidence/rt-b2p2-entry-in-place-20261007.json) | b189ee9 |
| 2026-10-07 | B2 P2b: one received-input core | The B2 P2 review's follow-up: `receiveInput` runs the in-place core (with its observer), sharing one command-extent check with the remote and playback steps; the initial entry's rollback test also throws right after the in-place control, received and replay sub-steps. Main 20.0/20.0 ms per tick (unchanged). All 10 scenarios, AppKit and the emulator equal, frames identical; 73 suites | [evidence](../evidence/rt-b2p2b-receive-core-20261007.json) | c761435 |
| 2026-10-07 | B2 P2c: local input in place | `beginLocalInput` and `localInput` copied the entry's candidate twice more (the actors array, an actor record and the globals); their bodies now run on the entry's own copy, and the AI/object children receive it. Main 20.0/20.0 ms per tick (no measurable change). All 10 scenarios, AppKit and the emulator equal, frames identical; 74 suites; review OK | [evidence](../evidence/rt-b2p2c-local-input-20261007.json) | ba69395 |
| 2026-10-07 | B2 P2d: entry and local-input rollback test | Test only (the P2 and P2c reviews): the loaded entry, run directly, throws at each checkpoint, replay and round event and from an AI child after its writes, leaving the caller's model, commands and context unchanged, with a retry equal to the uninjected run; the transactional local-input forms keep their caller's values. Sources as P2c; the menu-startup and application-input suites pass | [evidence](../evidence/rt-b2p2d-entry-rollback-test-20261007.json) | 96661df |
| 2026-10-07 | B2 P3: the AI and object-input children in place | The character-AI and object-input passes copied the match's world, actors and globals while the caller held them, so each call copied the actors array, an actor record and the globals; `applyInPlace` moves them into the pass and writes them back in a `defer`, and the production child (whose callers all drop the match on a throw) uses it. Both reference corpora run through both forms. Main 20.0/20.0 → 19.8/19.6 ms per tick. All 10 scenarios, AppKit and the emulator equal, frames identical; 74 suites; review OK | [evidence](../evidence/rt-b2p3-ai-children-in-place-20261007.json) | e7dedda |
| 2026-10-07 | B2 P3b: AI and object-input rollback checks through both forms | Test only (the P3 review): an observer throwing at the first and last event leaves the all-or-nothing caller unchanged and the in-place records whole; a corrupted Object binding gives the same error from both forms. Sources as P3; both suites pass | [evidence](../evidence/rt-b2p3b-ai-rollback-checks-20261007.json) | 67f4083 |
| 2026-10-07 | A3 P0: idle iterations measured apart | The runtime and the speed harness split the message loop: on the A12 an idle iteration costs 0.66 ms in its step and 0.81 ms in all, 3.12 per tick (~2.5 ms per tick); the tick's own step 1.38 ms; the loaded cycle 14.5 ms. Telemetry only; all 10 scenarios, AppKit and the emulator equal, frames identical; the runtime suites pass | [evidence](../evidence/rt-a3p0-idle-split-20261007.json) | 3f7e9cb |
| 2026-10-07 | A3 L3: the idle loop on an empty context | The idle iteration copied the whole State twice as the loop's context, which on that path only reads the speed flag; it now runs on an empty context. Idle step 0.66 → 0.63 ms on the A12 (0.033 → 0.019 ms on the Mac); main 19.8/19.9 ms per tick. All 10 scenarios and the emulator equal, frames identical; AppKit equal on a clean build (the incremental app had a stale inlined class size, see 4u); all 173 suites; review OK | [evidence](../evidence/rt-a3l3-idle-context-20261007.json) | 4e13691 |
| 2026-10-07 | A3 P5a: the Android host's iteration timer | Each iteration's `asyncAfter` woke libdispatch's manager thread with a write syscall (1.55% of the main thread); the runtime asks its host to schedule the next iteration (default: the same `asyncAfter`), and the Android host arms one timerfd on the main looper. Main 19.8/19.9 → 19.0/19.2 ms per tick, render 15.7/16.6 → 13.7/14.4 ms. All 10 scenarios, AppKit and the emulator equal, frames identical; the runtime suites pass; review OK | [evidence](../evidence/rt-a3p5a-android-timer-20261007.json) | bf85e22 |
| 2026-10-07 | A3 P5b: the Android iteration timer hardened | The P5a review's follow-up: the iteration runs only on a full 8-byte expiration read, a failed timer setup is tried once and reported, and the timer uses the app's main looper. Main 19.2/19.2 ms per tick; the emulator equal, frames identical | [evidence](../evidence/rt-a3p5b-timer-hardening-20261007.json) | 8ac7969 |
| 2026-10-07 | 4u: gate binaries from clean builds | The L3 AppKit gate's incrementally built app crashed at startup: its unchanged NTSDApp module had `OriginalRuntimeSession`'s allocating init inlined with the size from before A3 P0 (448 of 472 bytes), so `init` wrote past the object (Guard Malloc). `-disable-incremental-imports` did not help (probe reverted). Gate binaries now come from clean builds, and HEAD was regated so: all 10 scenarios, AppKit and the emulator equal, frames identical; 173 suites; 20 of 20 launches clean; main 19.3/19.2 ms per tick | [evidence](../evidence/rt-4u-clean-gate-builds-20261007.json) | 180d845 |
| 2026-10-07 | Phase 4s: bitmap draws read their words in place | `OriginalBitmapDrawing.word` read the computed `bytes` array up to six times per word, retaining and releasing it each time (3.1% of the main thread); it reads the raw little-endian word in place (`rawWord(at:)`, defined or not, as before). Main 19.3/19.2 → 18.9/18.8 ms per tick. Clean builds: all 10 scenarios, AppKit and the emulator equal, frames identical; all 174 suites; review OK | [evidence](../evidence/rt-4s-bitmap-raw-words-20261007.json) | cbb15b5 |
| 2026-10-07 | Phase 4t: the loaded cycle's finish without copies | The runtime's `finish` copied the frame's graphics commands before replaying them and wrapped every operation in single-element arrays for the music and sound helpers; it replays the slice and passes operations one at a time. Main 18.9/18.8 → 18.6/18.5 ms per tick. Clean builds: all 10 scenarios, AppKit and the emulator equal, frames identical; the runtime suites pass; review OK | [evidence](../evidence/rt-4t-finish-copies-20261007.json) | 8d888a3 |
| 2026-10-07 | A3 L4a: the idle attempt's queue requests without permits | Each idle request went through the iteration exchange's claim, permit, service record and answer (with their locks and a permit object); with a direct server the idle attempt answers them into a log that the exchange receives in one call before anything reads it, leaving its receipts, status and failure as before. Idle step 0.62 → 0.60 ms on the A12; main 18.5 ms per tick. Clean builds: all 10 scenarios, AppKit and the emulator equal, frames identical; the suites pass (the new exchange-state test after fixing its own path expectations); review OK | [evidence](../evidence/rt-a3l4a-direct-idle-queue-20261007.json) | 54bb195 |
| 2026-10-07 | Phase 1k: one render dispatch per replayed batch | The display backend dispatched every pipelined draw to the render thread separately (a block, a closure allocation and a wake each, ~130 per gameplay body); work submitted during the runtime's replay of a batch now goes as one block when the replay ends or anything flushes first, in the same order. Main 18.5/18.5 → 18.3/18.2 ms per tick. Clean builds: all 10 scenarios, AppKit and the emulator equal, frames identical; the display and runtime suites pass; review OK | [evidence](../evidence/rt-1k-render-batch-20261007.json) | this commit |

## Next task

**Measurement first (2026-10-06 evening).** The speed harness's virtual
clock (`--virtual-clock 123456789 8`: 8 ms per message-loop iteration) makes
the game's 33 ms timer take about four iterations per tick, and the idle
ones sleep 5 ms each for real: ~16 ms of every tick is the game's own pacing
whatever the compute time (off-CPU profile `rt4f-offcpu-profile`: 99.8% of
the main thread's off-CPU time in `Looper::pollOnce`, waits of ~5 ms). So
ticks per second under the virtual clock undercount compute savings (4e, 4f:
~+1% each). `android_speed.py` now reports each thread's compute per tick
(`mainMsPerTick`, `renderMsPerTick`, from schedstat between bodies 600 and
1500) and has `--real-clock`; the [budget](CORE_REALTIME_BUDGET.md)'s frame
time becomes compute per tick (to be rewritten with the first measurements).

Tier 2 ([design](CORE_REALTIME_TIER2.md), 16 ms per thread; main 30.4 ms
and render 22.0 ms per tick under the virtual clock after 4g), in order:

Profile after 3b (`rtb1b2-profile`, main 27.6 ms per tick): orchestration
still ~19 ms around a ~8.5 ms gameplay body; reference counting ~13% of the
main thread; message-loop iterations 4.12 × 1.14 ms; render thread 18.7 ms,
~85% blitting (`copyPixels` and its row copies). In flight:

- **Render passes** ([plan](CORE_REALTIME_RENDER_PASSES.md)): render 17.5 ms
  per tick after 1j; each full-frame pass costs ~1.7 ms on the A12. P1 (the
  present's back-buffer copy and crop fused) next, then P2 (the back buffer
  lent as the frame).
- **Status (2026-10-07 evening, 1k):** main 18.3/18.2 ms and render ~14.4 ms
  per tick on the A12; tier 2 needs ~2.2 ms more on the main thread. Gate
  binaries come from clean builds (4u).
- **B2** ([plan](CORE_REALTIME_B2.md)): in-place nested passes under the first
  transactional copy; P1–P3 done. P4 (the gameplay body's passes family by
  family, by a fresh profile) remains.
- **Idle iterations** ([A3 design](CORE_REALTIME_A3.md)): 3.12 per tick at
  0.60 ms in the step (0.68 ms in all) after L3, P5a/P5b (the Android
  iteration timer) and L4a. Next: L4b, the idle attempt without a per-step
  Driver and exchange (Driver creation, cursor views, the exchange's own
  copies), then L5 (the two platform copies per idle commit, ~0.66% of the
  main thread in `rt4t-dwarf`) and L6.
- **Other measured targets** (`rt4t-dwarf`, share of the main thread):
  `LoadedMenuSession.Attempt.emit` 7.3% inclusive (graphics `consume` 3.8%
  with its whole-owner copy for rollback, the attempt's `graphics` array
  copied from the entry on its first append 0.96%); `MatchBindings.store`
  3.3% (the 400-entry world table and actor loops each tick); the display
  backend's `serveFront` 3.2%; the menu session's step closure 1.4% and its
  State destroy 1.0%, with an `__openat` 0.6% per tick to explain.
- Then B1 3c (world pair cache), B2 (R5/M3 in-place nested
  candidates), B3 (one loaded attempt per tick), the replay check, R3 stage
  2; then the gameplay body and the render thread.
