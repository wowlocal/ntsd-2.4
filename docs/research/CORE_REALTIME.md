# RT — Real-time play on slow phones (core redesign)

Workflow: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md); parent
studies [MOBILE_PERFORMANCE](MOBILE_PERFORMANCE.md) (steps 1–8) and
[CROSS_PLATFORM](CROSS_PLATFORM.md) (P8 Android).

**Consumer in native/ and integration criterion:** the Android app on the user's
Galaxy A12 (Helio P35, Cortex-A53 cores, 2.8 GB RAM): the scripted VS match runs
at the game's own rate, **≥ 30 gameplay ticks per second** without frame capture
(`tools/crossplatform/android_speed.py`, bodies 300→1800), and then plays
smoothly by hand. Every host keeps exactly the same game.
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
| 2026-10-06 | Phase 1d: colour fills by row | The DirectDraw colour fill (`blt`, served by the menu loop every frame) and the front fill write one row store and whole mask words per row instead of a value and a bit per pixel. **11.94/11.92 → 12.11/12.10 ticks per second** (+1.5%); Mac process CPU −3.0%. All 10 scenarios and AppKit equal, frames identical; 13 suites; review OK | [evidence](../evidence/rt-1d-row-fills-20261006.json) | this commit |

## Next task

Phase 1e, pipelined text (in the working tree): a Mac sample of the 1d build
showed the main thread waiting on the render thread for 20% of its busy time
(`RenderExecutor.flush ← performFront ← replay`): every text step flushed, so
any batch that draws HUD text gave up most of the overlap. Now only TextOutA
touches pixels; it keeps its checks and glyph mask on the main thread and
queues the pixels and present (the synchronous path is the old code after a
flush). Done so far: vs equal with 1,832 frames identical (frozen 93d8d0b2),
full-overlap vs, playback and war equal. Open: Mac A/B, a Mac sample for the
remaining waits, all 10 scenarios, ThreadSanitizer, AppKit, the display suites,
review, phone.

Then profile the phone on that build. The phone's main thread after 1d is two
thirds of its samples (render thread 29%); retain/release 24%, their atomics
5% and memcpy 9% of it. On the Mac the largest single source of copying is
`Array._consumeAndCreateNew` under `OriginalStateRecord.write`/`overwrite`
(record buffers copied on write because another reference holds them: the
menu state's `replace`, the loaded match entry, the bitmap font's resource
writes), 12% of busy time. Candidates: keep those records uniquely referenced
(or write through the owner), the discarded host results, R4. The DWARF
profile on the phone (`--call-graph dwarf,65528 -f 100`) produced no data;
`dwarf,16384 -f 200` gives truncated stacks.
