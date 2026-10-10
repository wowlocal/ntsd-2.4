# ML — Memory footprint and loading time

Workflow: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md); parent
studies [MEMORY_FOOTPRINT](MEMORY_FOOTPRINT.md) (M1, steps 1–3) and
[CORE_REALTIME](CORE_REALTIME.md) (its phase 5, "loading time on the phone",
was queued there; its gates and A/B protocol are reused here).

**Consumer in native/ and integration criterion:** every host, first the Android
app on the user's Galaxy A12 (Helio P35, eight Cortex-A53 cores, 2.8 GB RAM,
eMMC storage, ~1.3 GB free): the time from launch until the game is ready
(its data loaded) and the memory the game holds while loading and playing,
measured with `tools/crossplatform/load_memory.py`. Every host keeps exactly
the same game.
**Reason:** user decision 2026-10-10, after the real-time work reached its
wall: "now lets do the loop for optimizing memory footprint and loading times.
you can create a new branch and start developing. build strong methodology as
you progress."
**Status:** research and transfer.
**Branch:** `exp/memory-loading`, from `exp/core-realtime` 0034e45. It tracks
`origin/exp/memory-loading`, created with its upstream at 22:12 on 2026-10-10
outside this study's commands, so the post-commit hook pushes every commit.
Merging into `dev/crossplatform`/`main`, CI and publishing wait for the user.
**Game result:** unchanged by definition. Only how the port holds and prepares
data changes, never what the game computes, shows or fails on.
**Reference:** the pinned EXE (SHA-256 `3f7ac67c…ff71c`) is not touched. The
comparators are those of CORE_REALTIME: the frozen app_e2e references (10
scenarios, including the `loaded` milestone's counts of allocations, audio and
bitmap requests and files), the frame references (`m1-frames-ref`, the AppKit
runs, the emulator's), and the Core suites.
**Declared scope:** how inputs are read, verified and held (bundled packages,
bitmaps, sounds); the loading session's own bookkeeping (file streams, operation
logs, transactional copies); representations of loaded data the game already
owns (frame records, surfaces, masks), each change proven value-identical.
**Out of scope:** game rules, numeric semantics, the order and kind of the
original's observable loading calls (file reads, bitmap and sound requests,
allocations), error boundaries (an input that fails to load still fails at the
same point with the same error), pixel formats the game observes, fixtures,
references and expected values; weakening the packaged-input integrity check
(the manifest digests) without the user.
**Executor / independent reviewer:** Claude / a separate read-only reviewer
agent for every storage-model or architecture change; a missing review is stated.
**Allowed paths:** `native/Sources/NTSDCore`, `native/Sources/NTSDRuntime`,
`native/Sources/NTSDAndroid`, `native/Sources/CAndroidNative`, host targets,
build settings in `native/Package.swift`, test helpers and new tests in
`native/Tests`, `tools/crossplatform`, this card and its evidence.

## Metrics and how they are measured

`tools/crossplatform/load_memory.py` runs app_e2e's computer-vs script (or the
Demo) as `android_speed.py` does — virtual clock, music, sounds and network
off, no frame capture — and stops the game at the progress event of 600
gameplay bodies. It reuses `android_speed.py`'s device helpers (install, wake,
progress events, simpleperf recorder); it is a separate harness because it
measures at fixed points (the `loaded` event, body N) and on the Mac too,
where `android_speed.py` measures tick rates on Android only.

| Metric | Definition | Primary host |
| --- | --- | --- |
| **Load** (`loadSeconds`) | the `loaded` event's own seconds: the first loading cycle, from reading the catalog, menu, interface and arena packages to the loaded menu (the game's whole data load behind its loading screen) | A12 |
| Startup (`startupSeconds`) | process start → the `started` event (startup package, window, display); on Android from `/proc/<pid>/stat` starttime | A12 |
| Start to loaded | process start → the `loaded` event (startup, the scripted menu iterations before the load, the load) | A12 |
| **Peak footprint** (`peakFootprintMB`) | the largest VmRSS + VmSwap seen while polling (every ~0.5 s) until body 600: the game's whole memory, resident or swapped to zram (Mac: `phys_footprint_peak`, which counts compressed memory) | A12 |
| Peak resident (`peakResidentMB`) | VmHWM at body 600; varies with the phone's memory pressure (what the kernel swapped out is not resident), so it is reported, not compared | A12 |
| Resident when loaded / in the match | VmRSS (anonymous and file parts) at the `loaded` event and at body 600; Mac `phys_footprint` | A12 |
| PSS | `dumpsys meminfo` summary at body 600 | A12 |
| Attribution | Mac `heap -sortBySize` at both points (`--snapshots`), `sample` / simpleperf profiles of the load | Mac, A12 |

The macOS footprint counts compressed memory and varies between identical runs
(MEMORY_FOOTPRINT); it is used for attribution and as a cross-check, the
phone's VmHWM/VmRSS decide.

**Comparison protocol.** Every change is measured against the previous build in
one session, interleaved run by run (`--local A --local B --runs K`, or
`--apk A --apk B` on the phone; the phone drifts between sessions): three runs
of each on the Mac, three new against two previous on the A12 as in
CORE_REALTIME. Results are medians with their ranges. The noise floor is taken
from the baseline's repeated runs before the first change (below). A change
counts as measured when its range does not overlap the previous build's; a
memory reduction may also be shown deterministically (live bytes of the holder
in `heap`, allocation counts) when it is below the phone's run-to-run spread.

**Profiling.** Mac: `sample` of the frozen unchecked headless binary during the
load, read with an inclusive call-tree table; A12: `load_memory.py
--profile-loading S` (simpleperf, DWARF call graphs, from launch). Profiles
explain a result and choose the next mechanism; they never replace the
timed comparison.

## Baseline (2026-10-10, 0034e45 sources; Mac frozen unchecked `rte5` binary, A12 APK `rte5`/`ml-p0`)

| | Mac (M-series, headless) | Galaxy A12 |
| --- | ---: | ---: |
| Startup | 0.11–0.13 s | 2.89–2.94 s |
| **Load** | **5.05–5.43 s** | **122.1–124.6 s** |
| Peak footprint | 1976–2036 MB | **1595–1601 MB** (RSS + swap) |
| Peak resident | | 1109–1550 MB (VmHWM; 190–250 MB swapped) |

Noise floor (unprofiled repeats of the same build): A12 load ±0.6 s (0.5%),
startup ±0.03 s, footprint ±10 MB; Mac load ±0.2 s (4%), footprint ±30 MB.
The A12 load is CPU-bound on the game thread (131 s on-CPU by the `loaded`
event, of 135 s since start). [Evidence](../evidence/ml-baseline-20261010.json).

Data packaged with the game: 834 24-bit BMPs (638 MB), 58 other bitmaps
(21 MB), 155 DAT files (5.3 MB), 388 WAV files (15 MB), 8 music tracks.

A12 load profile (simpleperf, DWARF stacks, 12,308 game-thread samples over
the load, inclusive): the catalog session 49% — object files 32% (sprite-sheet
finishing 19%, of it copies of the whole loaded-bitmap array 9.7%; file
decoding 16%; frame bodies 9.5%), sounds 4% — and reading and verifying the
catalog package 25% (the portable SHA-256 15%, bitmap headers and validation
decode 8.8%); the arena package 2.5%.

Mac load profile (`sample`, 2,492 samples in `OriginalMacRuntimeLoading.run`,
inclusive): the catalog's DAT parsing 99%, of which file decoding
(`OriginalLoadingFiles.decodeDAT`) 38% — three quarters of it copying and
destroying the whole `Stream` value (its byte arrays retained and released) for
every character read, scanned or written, and a one-element array per decoded
byte; frame bodies 25% (`projected` frame dictionaries 8%); sprite-sheet
finishing 19% (bitmap construction, arrays of loaded bitmaps copied on append);
sounds 13% (the audio backend copying optional records); the parsed text
converted to a String scalar by scalar.

Mac live heap at body 600 (`heap`, 2.73 GB allocated, 1.94 GB resident): surface
pixel values 1.22 GB (888 surfaces, filled lazily; M1 step 3), byte arrays
915 MB (36,336; mostly the bitmap files' bytes, M1 step 3b), state records
196 MB (75,527), frame-record dictionaries 168 MB (54,800 `[String: Int32]`:
400 projected frames for each of 137 objects), Bool arrays 61 MB, surface known
bits 42 MB, sample arrays 35 MB, the catalog and pool sessions' operation logs
39 MB.

## Plan

Profile first, then one mechanism per increment, measured before and after.

| Phase | Work | Status |
| --- | --- | --- |
| 0 | Harness (`load_memory.py`; `uptime` on the `started` and `loaded` events), baseline, noise floor, phone load profile | **done** |
| L1 | Loading-file streams changed in place (A12 decodeDAT 16%) | **done** |
| L2 | The object and background loaders' resource arrays mutated in place: `bitmaps`, `sounds`, `frameHeap` are computed get/set properties, so every write into one bitmap record copied the whole array of loaded bitmaps (A12 9.7%) | **done** |
| L3 | Package entries read, verified and decoded on all cores, taken in manifest order (same first error); the portable SHA-256 without a per-block allocation; digests without a Data copy (A12 catalog package 25%, arena 2.5%) | next |
| L4 | Bitmap headers read in place and images validated without decoding (`OriginalDIBPixels.validate`, the decoder's checks and errors; A12 Bitmap.init 8.8%) | drafted |
| L5 | Frame heap lookups indexed by address (linear `contains`/`lastIndex` over ~15,000 allocations per allocation and write), scanner tokens without String building, projections once | queued |
| L6 | Sounds: the audio backend's optional-record copies (A12 2.8%) | queued |
| S1 | Android first launch after an install or data change: the app extracts its 726 MB of assets from the APK to `files/ntsd-data` (~23 s on the A12, seen when the low-storage install path drops the data) and then holds them twice on a phone with ~1 GB free; read them in place from the APK instead (stored uncompressed, opened through the asset manager's file descriptor) | queued |
| M1 | The sprite sheets' file bytes kept compressed in memory (LZ4 block format, ~13x on 24-bit sheets) and decompressed when a surface first needs its pixels (77 reads in a whole vs run); the largest resident holder, 678 MB of byte arrays | drafted |
| M2 | Frame projections compact (54,800 `[String: Int32]` dictionaries, 161 MB) | queued |
| M3 | Remaining holders by the attribution: stage records copied per stage (87 MB), the startup package's payload and replies (~90 MB), whole-definedness arrays (51 MB), the loading session's streams and logs kept after the load (~55 MB) | queued |

## Gates (every increment)

As CORE_REALTIME's gates 1–5 and 7: clean builds; headless vs equal with its
1,832 frames identical to `m1-frames-ref`; all 10 scenarios equal on a frozen
binary (their `loaded` milestones keep the same counts); AppKit vs and playback
equal, frames identical; the emulator's vs frames identical; the affected Core
suites in a release test build; an independent read-only review for storage or
architecture changes. Gate 6 here is `load_memory.py`'s comparison on the Mac and
the A12. A loading change must also keep every error boundary: the existing
failure tests of the touched loader pass unchanged, and a new test covers any
rollback path the change rewrites.

The gates run as one script on task storage,
`/Volumes/X5/ntsd-2.4-research/crossplatform/ml-tools/mlgate.sh LABEL PREV SUITE…`
(clean builds of the tested tree, recorded in `logs/LABEL-tested-trees.txt`;
the phone and Mac A/B against PREV's frozen binary and APK), and
`ml_evidence.py` there writes the increment's evidence from its logs. A commit
stages the native files of the tested tree, not the working copy, so the next
increment can be developed once the gate's test bundle has compiled. Probes
(single runs, profiles, attribution builds) never replace the gate.

Commit an increment only when every gate passes and it is measurably faster or
smaller by the protocol above, or strictly less work or memory without added
complexity; otherwise record it here and revert. Keep X5 above 20 GiB free and
T7 above 40 GiB. Keep the phone awake only while measuring and restore
`svc power stayon false` when pausing.

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-10 | Phase 0: harness, baseline, noise floor | `load_memory.py` (Mac and A12, interleaved A/B, medians and ranges); `uptime` on the `started` and `loaded` events. A12: load 122.1–124.6 s, CPU-bound; footprint 1.6 GB of which ~0.2 GB swapped; Mac 5.1–5.4 s, 2.0 GB | [evidence](../evidence/ml-baseline-20261010.json) | with L1 |
| 2026-10-10 | Attribution probe (not committed) | A probe build counted the display surfaces touched and decoded-pixel reads: of 891 surfaces (1.14 GB allocated) only 65–77 (55–61 MB) are touched in a whole vs run, and `Bitmap.pixels` is read 77 times (31 MB). Live memory by allocation site at body 600 (malloc_history, 2.64 GB live including the untouched surfaces): sprite-sheet file bytes 613 MB (catalog) + 65 MB (arenas), frame projections 161 MB, stage records 87 MB, startup payload 57 + 35 MB, whole-definedness arrays 51 MB, the loading session's streams and logs ~55 MB | this card | — |
| 2026-10-10 | L1: loading-file streams in place | `character`, `scannerAccess` and `write` change their stream in place instead of copying the whole `Stream` (four byte arrays) out and back per character; `decodeDAT` runs on its two streams held locally; no one-element array per decoded byte. Same events, same values after success and every throw. **A12 load 123.9 → 101.8 s** (101.4–102.4 against 123.2–124.6), Mac 5.41 → 3.69 s; footprint unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 13 suites incl. a new rollback test; review: no behavioural difference | [evidence](../evidence/ml-l1-file-streams-in-place-20261010.json) | 17416cd |
| 2026-10-10 | L2: loader arrays in place | The object and background loaders' `bitmaps` (and `sounds`, `frameHeap`) get a `_modify` accessor: each write into one bitmap record copied the whole array of ~1,800 loaded bitmaps and that record. **A12 load 102.3 → 79.0 s** (75.7–79.4 against 101.8–102.9), Mac 3.45 → 3.10 s; footprint unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 15 suites; with L1's review follow-ups | [evidence](../evidence/ml-l2-loader-arrays-in-place-20261010.json) | this commit |

## Next task

L3 (package entries on all cores), then L4 and M1 (drafted), then a new A12
load profile to rank what remains.
