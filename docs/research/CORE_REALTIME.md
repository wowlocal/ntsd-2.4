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
| 2026-10-06 | Phase 4f: the presentation input built directly | The runtime built the gameplay session's `OriginalMenuPresentationInput` every tick through JSONSerialization and JSONDecoder (2.6% of the main thread) for want of a public initializer; it now has one and the runtime builds the same values directly. 20.30/19.94 → 20.39/20.28/20.35 ticks per second (+1.4%); compute per tick main 30.4 ms, render 22.2 ms; real clock 30.25 ticks per second. All 10 scenarios and AppKit equal, frames identical; 35 suites and the 4e review's extra table cases | [evidence](../evidence/rt-4f-presentation-input-20261006.json) | this commit |

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

In flight:

- Then, by compute per tick: FreeType glyph masks (2.5%), the Host step
  closure (3.6%) and `store` (4.0%), R3 stages 2–4, R5/M3, the render
  thread (copy loop and frame copy, ~29 ms per tick).
