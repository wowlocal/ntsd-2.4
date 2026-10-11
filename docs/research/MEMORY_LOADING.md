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
**Performance is not traded (user, 2026-10-11):** "we must not compromise on
performance (loading speed and frame time) while we optimize memory
footprint". A memory saving that measurably costs load time or frame time
(on any thread, the audio callback included) is fixed in the same increment
or dropped, never recovered later.
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
| **Frame time** (`--ticks 600,1500`) | the same run kept going to body 1500: each thread's on-CPU share of the wall time over bodies 600–1500 times the wall time per tick (`mainMsPerTick`, `renderMsPerTick`, the whole process `processMsPerTick`, every thread `threadMsPerTick`), with the sound effects mixed as in play (`--sounds`, media volume held at 0); Mac: the game thread's busy time per tick from the progress events (`completeMsPerTick`) and the process's CPU per tick | A12 |

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

**Attribution.** `malloc_history`/`heap` report allocated bytes, not resident
ones: an allocation's untouched capacity is not resident, and the allocator
keeps freed memory resident. Rank memory holders by allocation stacks, but
decide by the gate's interleaved footprint comparison (single probe runs
are noisy); on the A12 the harness also keeps `dumpsys meminfo` (native heap
allocated and free) and `smaps_rollup` at body N.

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
| L3 | Package entries read, verified and decoded on all cores, taken in manifest order (same first error); the portable SHA-256 without a per-block allocation; digests without a Data copy (A12 catalog package 25%, arena 2.5%) | **done** |
| L4 | Bitmap headers read in place and images validated without decoding (`OriginalDIBPixels.validate`, the decoder's checks and errors; A12 Bitmap.init 8.8%); L3's review follow-ups | **done** |
| M1 | The sprite sheets' file bytes kept compressed in memory (LZ4 block format, ~13x on 24-bit sheets) and decompressed when a surface first needs its pixels (77 reads in a whole vs run); the largest resident holder, 678 MB of byte arrays | **done** |
| M2 | Frame records' words in 94 slots with a presence mask instead of `[String: Int32]` dictionaries (54,800 of them, 161 MB); the same equality and JSON | **done** |
| L5 | Bitmap effects without whole-table copies: the bitmap inputs' `response` and the graphics' `bitmap` throw only before their first change, so they run in place; the catalog session holds each owner alone while it changes (A12 ~10%: dictionary copies on every bitmap effect) | **done** |
| L6 | Frame heap lookups by binary search over its address order (the linear overlap scan was A12 6.1%) | **done** |
| L7 | Text: tokens and parsed files converted without building Strings scalar by scalar (A12 11% after L5) | **done** |
| L8 | Sounds: the audio backend converted each WAV to float samples reading the record (a class property) per byte, copying it each time (A12 ~7.5% after L5) | **done** |
| M3 | The compressed sprite sheets kept at their own size: the compressor's buffer kept its reserved capacity (130 MB held for 52 MB); the sound conversion reads its bytes without caching them (L8 follow-up) | **done** |
| M4a | The 60 Stage slots in one record of shared pages | **shelved**: the loader's initialisation writes every page of the ~52 stages the catalog defines (87 → 80 MB in a probe); superseded by M6 (per-slot pages, filled slots flat: 25 slots filled in M6's probe) |
| L9 | New surfaces' source colours kept implicit (all unknown on zero backing) until read or partly written: allocating and zeroing a colour and a definedness array per surface was 9% of the A12 load | **done** |
| L10 | Text-mode translation into one array (`flatMap` built an array per byte, ~6%) | **done** |
| L11 | The packaged inputs' SHA-256 on Android with the ARMv8 SHA-2 instructions (C block function in CAndroidNative, installed after it gives the Swift digests; ~11% of the game thread plus the workers) | **done** |
| L12 | The package workers on all cores: measured on the A12, Dispatch's workers run on CPUs 0–3 only (inherited from the game thread's fast-cluster pin); a host parallel loop (`threadLoop`, the caller working too) on threads allowed on every core | **done** |
| L13 | The loading packages read ahead from the end of startup, during the menu (the game thread waited ~4 s for them after re-reading the startup package); the startup package read once | **done** |
| M5a | Sound records: the copied region is the temporary when it takes all of it (two equal 17 MB sets of records), PCM read into the temporary in one overwrite, the backend's definedness checks without whole arrays (16 MB kept per buffer) | **done** |
| M6 | The 60 Stage slots each paged over one shared backing, a slot flat again when the loader fills it (the sentinel write made 60 flat copies, 87 MB; a probe: 41 MB) | **done** |
| L14 | Registered sounds loaded in place: the catalog session copied the registry (two dictionaries of every earlier sound) for a rollback the attempt already provides (~3% of the A12's catalog window) | **done** (one gate with L15: below the A12's noise alone) |
| L15 | Definedness masks packed and expanded eight bytes at a time (`Flat.make` packed bit by bit with a branch per byte, the whole and range readers expanded bit by bit; ~11% of the catalog window) | **done** (with L14) |
| L16 | Objects loaded without rollback copies: the catalog hands each object loader a copy of its resources and the loader takes another for a rollback, so each object's first frame allocation copies every earlier one (~15,000); any error ends the catalog load. Also the file session's stream checks copied a `Stream` out twice per scanner access | **done** |
| L17 | The read-ahead is the bound again (the loading step waits ~0.4 s): on its threads `URL.resourceValues` is 21% (~1.8 ms per packaged file on Android), LZ4 compression 26%, SHA-256 20%, reads and copies ~30%. First step: the loaders' file facts from lstat/stat on Linux and Android | **done** |
| L18 | The catalog attempt's allocation overlap check by binary search (a scan over every earlier range per allocation, ~9% of the A12's catalog window) | **done** (one gate with L19) |
| L19 | Unwritten Frame slots share one record and projection (every object built a record and a projection for all 400 slots; ~28% of slots are written): ~6% of the catalog window, Mac heap −36 MB | **done** (with L18) |
| S2 | The first launch after an install or a data change extracts the APK's 726 MB of assets one file after another (~20–40 s on the A12); on every core, each asset read once into a buffer of its length. Measured with `load_memory.py --fresh-data` (the extraction marker removed before each launch) | **done** |
| M5b | Sound copies: the copy payload read without filling the temporary's whole-array caches, the audio backend's request logs (read only by tests) off in the runtime session, uniform audio bytes (a fresh buffer's lock reply) kept as one value. Probe: −64 MB on the Mac heap | **done** |
| M7a | Closed file streams keep no contents past the catalog load (the loaded menu keeps the catalog's files for the whole run; nothing reads a closed stream's arrays): probe −30 MB at the stream sites on the Mac heap | **done** |
| M7b | The file events' bytes in the catalog operation log, kept by the loaded menu's retained input (~22 MB on the Mac heap); every session level's tests compare those journals, so only the menu session's retained copy can be compacted | queued |
| M5c | Float samples for every sound buffer (32 MB on the Mac heap for 15 MB of PCM): keep the PCM and convert with the same expression while mixing; probe −16 MB | **done** |
| M7 | Bulk data kept by logs after loading: the file session keeps every closed stream's arrays (tests read them), the catalog session's operation log every read and write chunk (~55 MB on the Mac) | queued (retention study) |
| M5b | The audio path's remaining copies (~130 MB for 15 MB of PCM on the Mac heap after M6): float samples for every buffer (32 MB), the backend's raw records (18 MB), the loader's temporaries (17 MB), the lock replies' initial bytes and Bool masks (32 MB, kept by the wave results and the backend log), the copy requests' PCM and Bool masks (31 MB, one allocation each shared by the temporary's cached whole arrays and the backend log, so both holders must let go). Tests read only the log's counts and its create requests | queued (retention study) |
| M5 | Sound data held about ten times over (~145 MB for 15 MB of WAV files: load-result copies, cached whole arrays, float samples); a first step (non-caching reads) saved only ~15 MB because the load results' values keep the arrays — needs the results' retention reviewed | parked |
| M4 | Remaining holders by the attribution after L7 (~790 MB in use besides untouched surfaces): stage records (87 MB), whole-definedness caches (51 MB), the loading session's file streams and logs kept with the catalog (~55 MB), the catalog's file payloads (35 MB), startup replies (35 MB), PCM samples (32 MB) | queued |
| S1 | Android first launch after an install or data change: the app extracts its 726 MB of assets from the APK to `files/ntsd-data` (~23 s on the A12, seen when the low-storage install path drops the data) and then holds them twice on a phone with ~1 GB free; read them in place from the APK instead (stored uncompressed, opened through the asset manager's file descriptor) | queued |

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

**Frame time, in three tiers (since 2026-10-11).** (1) Every gate: the phone
A/B's runs go on to body 1500 with sounds mixed and report main, render and
whole-process ms per tick; the Mac A/B reports the game thread's and the
process's ms per tick (about two minutes more, inside the phone branch's
idle time; the Mac branch is the critical path). (2) When an increment touches
a per-tick or per-sample path (mixing, records read during play, display), or
tier 1 shows a difference beyond its ranges: the full interleaved
`android_speed.py` vs and Demo A/B (three rounds, ~40 min) with `--sounds`,
plus a microbenchmark of the changed loop on the Mac and the A12. (3) At each
milestone: the full A/B against the branch start.

Commit an increment only when every gate passes, it is measurably faster or
smaller by the protocol above (or strictly less work or memory without added
complexity), and neither load time nor frame time is measurably worse;
otherwise record it here and revert. Keep X5 above 20 GiB free and
T7 above 40 GiB. Keep the phone awake only while measuring and restore
`svc power stayon false` when pausing.

### Method notes (learned during the study)

- **Critical path first.** A per-second timeline of the game thread by phase
  (`phone_timeline.py`: samples per second under named frames, and the other
  threads' samples beside them) showed what inclusive profiles hid: the menu
  left every load thread idle while the loading step later waited for the
  packages (L13). On Android new threads inherit the game thread's name, so
  profiles are split by thread id.
- **Probe a design's knob before its gate.** When a change has a free choice
  (L13: the read-ahead on every core or on the slow cluster), single-run phone
  probes of each variant pick it; the gate then measures the chosen one.
- **Rollback copies.** A copy-on-write value taken for a rollback that an
  outer layer already provides makes every mutation copy the whole structure
  (L14, L16, earlier L2/L5). Before working in place, establish the outer
  failure path from the code (nothing catches; the attempt or load is
  discarded) and keep the public API's rollback as the default, opting out
  only where the caller discards.
- **Quadratic scans** show up as a few percent that grow with the content
  (L6, L18). Replace them with a sorted structure that answers the exact
  predicate, and test it against the scan on generated inputs, edge cases
  (empty and overlapping ranges) included.
- **Identical values built repeatedly** (sentinel-only Stage slots, unwritten
  Frame slots) cost memory and time; build once and share (M6, L19), keeping
  the value per slot exactly what it was.
- **Memory attribution is deterministic, the phone's peak is not.** The A12's
  peak footprint (RSS + zram swap) varies by ±25 MB between identical runs;
  each memory change is attributed with a Mac heap snapshot by allocation
  stack, and the phone's ranges are reported as measured, overlapping or not.
- **One gate for two changes** only when one alone is below the noise floor
  (L14 with L15, L18 with L19); profiles and heap snapshots attribute each.
- **A test-only failure** (a test's own mistake, the sources unchanged) gets
  its suites rerun from a scratch worktree holding the gated sources plus the
  corrected test (`mltests.sh`, its own label); the gate's other branch keeps
  running. The failed log stays in the evidence.
- **Review before the gate.** Each storage, ownership, numeric or platform
  change gets an independent read-only review of the draft; its follow-ups go
  in before the gate starts.
- **Platform paths** (Android file facts, asset extraction) are exercised by
  the phone and emulator gates; a Mac test compares the new primitive with
  the platform API it replaces.
- **The first run of an A/B sequence is slow.** In three phone A/Bs the
  build that went first waited longest for the read-ahead (3.1, 1.4, 1.4 s),
  muted too, where the change under test never ran. The phone A/B gets a
  warm-up run before its measured runs. Since the read-ahead (L13), `load`
  alone depends on how long the menu ran (a faster menu waits longer for
  the packages); launch to loaded is the user's time, so both are compared.
- **The phone drifts within a day, too.** Launch to loaded rose by 1.2 s for
  every build between two gates (the phone's memory pressure); a cross-gate
  comparison of absolute phone times suggested a regression in M5b that an
  interleaved A/B refuted. Suspected regressions are checked by an
  interleaved A/B of the two builds in one session, never by the ledger.
- **Measure where the cost lands.** M5c moved the sample conversion from
  load time into the mixer, which runs on the audio callback thread; every
  speed and load run muted the sounds (the Android feed then outputs zeros
  without mixing) and headless never mixes, so no gate saw it. A change that
  moves work into a per-tick or per-sample path gets a microbenchmark of the
  old and new loop (same inputs, outputs compared bit for bit) on the Mac and
  the A12, and the in-play runs measure every thread with that path active.

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-10 | Phase 0: harness, baseline, noise floor | `load_memory.py` (Mac and A12, interleaved A/B, medians and ranges); `uptime` on the `started` and `loaded` events. A12: load 122.1–124.6 s, CPU-bound; footprint 1.6 GB of which ~0.2 GB swapped; Mac 5.1–5.4 s, 2.0 GB | [evidence](../evidence/ml-baseline-20261010.json) | with L1 |
| 2026-10-10 | Attribution probe (not committed) | A probe build counted the display surfaces touched and decoded-pixel reads: of 891 surfaces (1.14 GB allocated) only 65–77 (55–61 MB) are touched in a whole vs run, and `Bitmap.pixels` is read 77 times (31 MB). Live memory by allocation site at body 600 (malloc_history, 2.64 GB live including the untouched surfaces): sprite-sheet file bytes 613 MB (catalog) + 65 MB (arenas), frame projections 161 MB, stage records 87 MB, startup payload 57 + 35 MB, whole-definedness arrays 51 MB, the loading session's streams and logs ~55 MB | this card | — |
| 2026-10-10 | L1: loading-file streams in place | `character`, `scannerAccess` and `write` change their stream in place instead of copying the whole `Stream` (four byte arrays) out and back per character; `decodeDAT` runs on its two streams held locally; no one-element array per decoded byte. Same events, same values after success and every throw. **A12 load 123.9 → 101.8 s** (101.4–102.4 against 123.2–124.6), Mac 5.41 → 3.69 s; footprint unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 13 suites incl. a new rollback test; review: no behavioural difference | [evidence](../evidence/ml-l1-file-streams-in-place-20261010.json) | 17416cd |
| 2026-10-10 | L2: loader arrays in place | The object and background loaders' `bitmaps` (and `sounds`, `frameHeap`) get a `_modify` accessor: each write into one bitmap record copied the whole array of ~1,800 loaded bitmaps and that record. **A12 load 102.3 → 79.0 s** (75.7–79.4 against 101.8–102.9), Mac 3.45 → 3.10 s; footprint unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 15 suites; with L1's review follow-ups | [evidence](../evidence/ml-l2-loader-arrays-in-place-20261010.json) | 5e1ec59 |
| 2026-10-10 | L3: package entries on all cores | The catalog and arena packages' entries are read, size- and digest-checked and decoded concurrently and taken in manifest order (the first failing entry still decides the error); digests without a Data copy; the portable SHA-256 without an array allocated per block. **A12 load 79.0 → 48.4 s** (48.35–48.71 against 78.6–79.4), startup 2.87 → 2.60 s; Mac 3.10 → 2.10 s; footprint unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 12 suites incl. a new error-order test; review: no difference in values or errors, no data race (L2 confirmed too) | [evidence](../evidence/ml-l3-packages-on-all-cores-20261010.json) | 2e4d4dd |
| 2026-10-11 | L4: bitmap validation without decoding | Bitmap headers read from the bytes instead of a whole-file record with a definedness byte per byte; images validated by `OriginalDIBPixels.validate` (the decoder's checks, order and errors, without the decoded arrays). With L3's review follow-ups (an arena file of another size or unreadable is read in manifest order as before). **A12 load 48.1 → 46.2 s** (45.99–46.38 against 47.71–48.55), Mac 2.23 → 2.09 s. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 15 suites incl. seeded validate-versus-decoder mutations; review: equivalent (an arena precheck finding fixed before this gate) | [evidence](../evidence/ml-l4-bitmap-validation-20261011.json) | 5c3a5a4 |
| 2026-10-11 | A12 load profile after L4 | Load 46–48 s, CPU-bound: catalog session 58% (bitmap construction 29%, of it whole-dictionary copies ~10%; frame bodies 22%; sounds 12%), text conversion 8%, the parallel package read 8% (the game thread waiting) | `ml-load/ml-l4b-loadprof-profile` (X5) | — |
| 2026-10-11 | M1: bitmap bytes compressed in memory | Sprite sheets of 64 KiB or more keep their DIB bytes LZ4-compressed (~13x) and decompress when a surface first needs them; the startup package loads on all cores so its compression adds no time. **A12 peak footprint 1570 → 975 MB** (peak resident 1437 → 957 MB), load 46.3 → 46.4 s and startup 2.3 → 2.2 s (no change); Mac peak 2049 → 1466 MB. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 20 suites incl. codec, threshold and startup error-order tests; review: no defect. A first gate (ml-m1) measured +0.9 s startup and +1.1 s load, which the startup concurrency and the faster match extension removed | [evidence](../evidence/ml-m1-bitmap-bytes-compressed-20261011.json) | 8aceb53 |
| 2026-10-11 | Tick check of M1 | `android_speed.py` vs on the A12: main 11.09 ms, render 7.55 ms per tick, the same as before this study (surfaces decompress their image once, on first use); the whole scripted run 129 s against 207 s at the study's start | [evidence](../evidence/ml-m2-compact-frame-words-20261011.json) (notes) | — |
| 2026-10-11 | M2: compact frame words | Frame records keep their words in 94 slots with a presence mask instead of a `[String: Int32]` per record (54,800 projected frames); the same equality and JSON. **A12 load 46.3 → 43.7 s** (43.23–43.89 against 46.28–46.32), **peak footprint ~965 → 834 MB**, startup 2.3 → 2.0 s; Mac 2.02 → 1.75 s, 1447 → 1368 MB. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 12 suites incl. equality, subscript and JSON equivalence tests; review: no defect | [evidence](../evidence/ml-m2-compact-frame-words-20261011.json) | c4223e5 |
| 2026-10-11 | L5: bitmap effects in place | The bitmap inputs' `response` and the graphics' `bitmap` run in place (each throws only before its first change) and the catalog session holds each owner alone while it changes: no copy of the image, surface, DC and resource tables per bitmap effect. **A12 load 43.7 → 31.4 s** (31.14–31.51 against 43.38–43.96; the profile share was ~10%, the copies also cost allocation and cache misses charged elsewhere); Mac 1.77 → 1.59 s; footprint unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 16 suites incl. 42 rejections that must leave both values unchanged; review: no problem | [evidence](../evidence/ml-l5-bitmap-effects-in-place-20261011.json) | 1016ca7 |
| 2026-10-11 | A12 load profile after L5 | Load 31 s: catalog session 44% (frame bodies 26%, sounds 17%, bitmap construction 13%), the parallel package phase 14%, scalar-by-scalar Strings 11% | `ml-load/ml-l5-loadprof-profile` (X5) | — |
| 2026-10-11 | L6: frame heap index | The frame heap finds allocations by binary search over its address order instead of scanning all ~15,000 for each allocation, write and lookup; same results and errors. **A12 load 31.3 → 26.7 s** (26.53–26.78 against 31.01–31.5), Mac 1.60 → 1.55 s. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 11 suites incl. a test against the old scans (the gate's test bundle missed a type annotation; the suites passed on the corrected tree, sources unchanged); review: no problem | [evidence](../evidence/ml-l6-frame-heap-index-20261011.json) | e12472a |
| 2026-10-11 | L7: Latin-1 text | Parsed files, scanner tokens and record strings convert between Latin-1 bytes and Strings directly (ASCII as UTF-8), not scalar by scalar; identical Strings and bytes. **A12 load 26.5 → 23.0 s** (22.9–23.0 against 26.39–26.68), Mac 1.59 → 1.12 s. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 16 suites incl. a byte-for-byte equivalence test; review: no problem | [evidence](../evidence/ml-l7-latin1-text-20261011.json) | 961cd99 |
| 2026-10-11 | L8: sound bytes read once | The audio backend's conversion of each WAV to float samples reads the record's bytes once instead of copying the record for every byte. **A12 load 22.6 → 19.4 s** (19.38–19.53 against 22.55–22.7), Mac 1.23 → 0.91 s; peak footprint about +12 MB (the bytes getter caches each record's array; M3 reads without caching). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 8 suites incl. per-format sample equality | [evidence](../evidence/ml-l8-sound-bytes-once-20261011.json) | e68da21 |
| 2026-10-11 | M3: compressed sheets at their own size | The compressed sprite sheets are copied to their own size (the compressor's buffer kept its reserved capacity: 130 MB allocated for 52 MB) and the sound conversion reads without caching. **A12 peak footprint ~855 → ~790 MB** (789–792 against 850–858), Mac 1319 → 1254 MB; load unchanged (19.4 s). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 10 suites. A worktree probe (with M4a) looked small and noisy: the interleaved gate decides. M4a (shared Stage pages) shelved: initialisation writes every page of the ~52 defined stages | [evidence](../evidence/ml-m3-compressed-sheets-trimmed-20261011.json) | 1e8006d |
| 2026-10-11 | A12 memory split after M3 | `dumpsys meminfo` at body 600: native heap ~700 MB resident of 1844 MB allocated (the untouched surfaces' calloc pages), only 32 MB free inside the allocator: what is resident is data in use, not fragmentation. M5 probe: the sound data is held ~10× (records, copies, cached whole arrays, float samples); non-caching reads saved only ~15 MB (the load results' values keep the arrays); parked | `ml-load/ml-m3-loadprof-meminfo.txt` (X5) | — |
| 2026-10-11 | L9: implicit unknown surfaces | A new surface's source colours stay implicit (every pixel unknown on zero backing) until read or partly written, instead of allocating and zeroing two arrays per surface. **A12 load 19.4 → 18.7 s** (18.46–19.19 against 19.32–19.41), footprint unchanged there; Mac load 0.84 → 0.81 s, **Mac peak 1254 → 927 MB** (its allocator kept the transient arrays dirty). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 16 suites; review: no problem | [evidence](../evidence/ml-l9-implicit-unknown-surfaces-20261011.json) | 58d17b6 |
| 2026-10-11 | L10: text translation into one array | Text-mode writes append CR LF into one reserved array instead of building an array per byte (`flatMap`); same bytes. **A12 load 18.9 → 17.4 s** (17.23–17.66 against 18.79–19.04), Mac 0.81 → 0.72 s. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 12 suites incl. a comparison with the per-byte definitions | [evidence](../evidence/ml-l10-text-translation-20261011.json) | 0cdf24c |
| 2026-10-11 | L11: hardware SHA-256 on Android | The packaged inputs' SHA-256 uses the A12's ARMv8 SHA-2 instructions through a C block function, installed only after it gives the Swift digests on twelve inputs; same digests and checks. **A12 load 17.5 → 15.5 s** (15.47–15.73 against 17.41–17.5), every run reporting the hardware path; Mac unchanged (CryptoKit). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 10 suites; review: no bug (its follow-ups applied before the gate) | [evidence](../evidence/ml-l11-hardware-sha256-20261011.json) | 643ae9f |
| 2026-10-11 | L12: package loads on every core | On Android the package loader's parallel loop runs on its own threads allowed on every CPU (Dispatch's workers were on CPUs 0–3 only, inherited from the game thread's pin), the caller working too. **A12 load 15.5 → 14.5 s** (14.18–14.71 against 15.38–15.53); Mac unchanged (Dispatch). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 10 suites incl. a thread-loop test on the Mac; review of the first version found a possible hang if a thread failed to start, fixed before the gate. Every phone run re-extracted the assets after its install (25–43 s startups, S1) | [evidence](../evidence/ml-l12-package-loads-every-core-20261011.json) | 72e9fcc |
| 2026-10-11 | L13: packages read ahead during the menu | The session keeps the startup package it read at start (the loading step read and verified it again) and reads the five loading packages on a thread of its own from the end of startup; the loading step takes them in the old order (the first failing one throws its own error there). **A12 load 14.6 → 10.9 s** (10.64–10.94 against 14.13–15.13; waiting 0.2–0.5 s for the read-ahead), peak footprint ~795 → ~778 MB (769–789 against 793–798: the startup package no longer twice), Mac load 0.74 → 0.56 s. The menu before the load is ~0.8 s longer while the read-ahead runs (start to loaded 20.9 → 17.2 s); a slow-cluster-only variant kept the menu's pace but waited 2.5 s (load 13.1 s). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 8 suites; review: no bug (risks recorded in the evidence) | [evidence](../evidence/ml-l13-read-ahead-20261011.json) | 4615465 |
| 2026-10-11 | M5a: sound records | PCM read into the temporary in one overwrite; a lock region that takes the whole temporary is that record (the same value) instead of a second one; the audio backend checks definedness without whole arrays and Release paths without copying a buffer. **A12 peak footprint ~775 → ~730 MB** (730–735 against 768–782), A12 load 10.5 → 9.8 s, Mac peak 942 → 896 MB, Mac load 0.57 → 0.51 s. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 10 suites incl. the 431 EXE wave cases; review: no bug | [evidence](../evidence/ml-m5a-sound-records-20261011.json) | cb426f7 |
| 2026-10-11 | M6: paged Stage slots | The 60 Stage slots share one paged backing; a slot the loader fills becomes flat first. Stage records on the Mac heap 87 → 41 MB (25 slots filled; M4a's ~52 was wrong). **A12 resident at loaded 673–679 → 640–663 MB**, peak footprint median 736 → 685 MB (one run at 731: the peak ranges overlap), Mac peak 866–928 → 836–841 MB. A12 load 9.9 → 10.1 s (assembling the filled slots with the per-bit packing L15 replaces). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; the gate's test bundle failed on the new test (nested assertion handlers), corrected and the 13 suites rerun as ml-m6b from the same sources, all passing; review: no bug | [evidence](../evidence/ml-m6-paged-stage-slots-20261011.json) | 5b35a9a |
| 2026-10-11 | L14 + L15: sounds in place, definedness eight at a time | The catalog session registers sounds in the registry itself instead of a copy (each registration copied both dictionaries of every earlier sound); records pack and expand their definedness eight bytes per step. **A12 load 10.2 → 8.8 s** (8.74–8.93 against 10.05–10.27; the read-ahead wait grew to ~0.5 s as the menu got faster), Mac load 0.53 → 0.45 s, Mac startup 0.059 → 0.046 s; memory unchanged within noise. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 14 suites incl. both formulas against the bit definitions; review: no bug | [evidence](../evidence/ml-l14-l15-sounds-in-place-defined-bits-20261011.json) | fa06d04 |
| 2026-10-11 | L16: objects without rollback copies | The loaded catalog moves its resources into each object loader and loads without a rollback copy (any error ends the catalog load), and the object loader moves its heap and sounds to the Frame loader instead of copying them: each object's first Frame allocation copied every earlier one. Stream checks without copying the stream. **A12 load 8.7 → 6.7 s** (6.66–6.85 against 8.72–8.73), Mac load 0.45 → 0.39 s, Mac peak 827 → 780 MB; A12 peak footprint within noise (684–722 against 680–685). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 10 suites; review: no bug | [evidence](../evidence/ml-l16-objects-in-place-20261011.json) | 5aa5250 |
| 2026-10-11 | L17: file facts from lstat on Android | The package loaders' per-file checks use lstat/stat on Linux and Android (resourceValues built an attribute dictionary per call, ~1.8 ms per file there). **A12 load 7.0 → 6.5 s** (6.43–6.53 against 6.79–7.30): the loading step no longer waits for the read-ahead (0.0 s against 0.35–0.69 s) and the menu before it is ~0.2 s faster; the Mac runs the unchanged Darwin path; memory within noise. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; the new test compared error descriptions (they carry an address), corrected and the 8 suites rerun as ml-l17b, all passing; review: no bug | [evidence](../evidence/ml-l17-posix-file-facts-20261011.json) | d5fee4d |
| 2026-10-11 | L18 + L19: overlaps by binary search, unwritten Frame slots shared | The catalog attempt's allocation overlap check by binary search instead of a scan of every earlier range; slots no frame wrote share one record and one projection (Mac heap: Frame records and projections 50 → 14 MB). **A12 load 6.4 → 5.2 s** (5.20–5.28 against 6.43–6.44), **A12 peak footprint ~683 → ~656 MB** (643–680 against 681–685; in the match 612–657 against 659–662), Mac load 0.39 → 0.33 s, Mac peak 806 → 783 MB. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 11 suites incl. both against their definitions; review: no bug | [evidence](../evidence/ml-l18-l19-ranges-shared-frame-slots-20261011.json) | 97423ae |
| 2026-10-11 | S2: assets extracted on every core | The Android host extracts the APK's assets on every core, each read once into a buffer of its length (one after another, in 64 KB chunks, before). **A12 first launch after an install 24.7 → 16.8 s** (`--fresh-data` A/B: 16.75–18.61 against 22.75–26.63 s; flash writes bound the rest); the load unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; review: no bug on success (a failing extraction can name a different file) | [evidence](../evidence/ml-s2-parallel-asset-extraction-20261011.json) | 1e0b93e |
| 2026-10-11 | M5b: sound copies | The copy payload read without caching it in the temporary, the audio backend's request logs (tests only) off in the runtime session, a uniform sound buffer's lock reply kept as one value. **A12 peak footprint ~657 → ~587 MB** (585–598 against 649–665; in the match 547–553 against 624–630), Mac peak 758 → 679 MB; loads unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; the new test expected a one-byte buffer to stop being uniform when changed, corrected and the 11 suites rerun as ml-m5bb, all passing; review: no bug | [evidence](../evidence/ml-m5b-sound-copies-20261011.json) | ec84abd |
| 2026-10-11 | M7a: closed streams without contents | After the catalog load, closed file streams keep their allocation, path, mode, position and flags but not their arrays (nothing reads them; the loaded menu kept them for the whole run). **A12 peak footprint ~607 → ~589 MB** (561–592 against 598–615; in the match 508–548 against 573–592), Mac heap −30 MB at the stream sites; loads unchanged. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 8 suites; the gate's phone A/B stopped at a transient install failure, rerun as ml-m7a-ab2; review: no bug | [evidence](../evidence/ml-m7a-closed-stream-contents-20261011.json) | 49bf0bf |
| 2026-10-11 | M5c: PCM kept, converted while mixing | Sound buffers keep their unlocked PCM instead of float arrays; the mixer converts each sample as it reads it with the backend's expressions. Mac heap: float samples 31.9 MB → PCM 15.8 MB; the A12's peak does not separate the builds (546–564 against 562–575 MB, within its spread); loads unchanged. Output bit for bit as the previous mixer loop (test copy) on generated buffers. All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 7 suites; review: no bug | [evidence](../evidence/ml-m5c-pcm-samples-20261011.json) | b8d1c9b |
| 2026-10-11 | Frame-time audit of the branch | After the user's rule and their suspicion of M5c: the A12's per-tick compute, branch start (ml-p0) against HEAD (ml-m5c), `android_speed.py` vs and Demo, three interleaved rounds (sounds muted): main 11.05 against 11.27 ms (vs; ranges 11.03–11.26 and 11.15–11.27), 11.71 against 11.72 (Demo), render 7.51/7.60 and 6.08/6.15: every pair overlaps. Those runs never mixed: muted, the Android feed outputs zeros without calling the mixer, and headless never mixes. A benchmark of the mixer loop found M5c's cost: **+31% per voice-frame on the A12** (48.7 against 37.2 ns; ~4.5 ms of audio-thread CPU per second with 8 voices). The gates now measure frame time (three tiers, above) | [evidence](../evidence/ml-frame-time-audit-20261011.json) | — |
| 2026-10-11 | M5d: the mixer through the buffer's address, mono read once | PCM read through raw pointers where the loop's indices provably stay in the buffer (step ≥ 0 and, looping, shorter than the buffer; otherwise M5c's checked readers), and a mono voice reads each frame once for both channels; same expressions, output bit for bit. **A12 mixer 48.7 → 36.2 ns per voice-frame, below the float loop before M5c (37.2)**; in play (sounds mixed) the audio thread 1.12 → 1.03–1.07 ms per tick, main 10.29 against 10.39, render 7.03 against 7.38, process 26.36 against 26.96 ms per tick (overlapping); memory unchanged (M5c's 16 MB kept). Load unchanged: the gate's first run waited 3.1 s for the read-ahead, an order effect the 4+4 A/B with sounds and a muted control (mixer not running) showed (5.42–5.86 against 5.27–5.86 s; launch to loaded 12.38–12.64 against 12.48–12.76 s). All 10 scenarios, AppKit, unchecked and emulator equal, frames identical; 5 suites incl. the short-buffer and long-step test; review: one unreachable negative-step case fixed before the gate | [evidence](../evidence/ml-m5d-mixer-raw-mono-20261011.json) | ef7a6b7 |
| 2026-10-11 | Menu-phase check (S2 against M5b) | Launch to loaded had risen from ~11.2 s (S2 and L19 gates) to 12.2–12.8 s from the M5b gate on, in the menu phase before the load (~4.4 → 5.2–5.9 s), with the load now waiting for the read-ahead; the load metric hid it, and the M5b gate's previous-build runs had re-extracted their assets. An interleaved A/B with a warm-up run today: S2 12.71–12.87 s (menu 5.30–5.50 s), M5b 12.62–12.70 s (5.37–5.63 s), the same: the phone, not M5b, slowed since midday (idle, but 1.34 GB in zram swap and 630 MB free). `load_memory.py --warmup` runs one unmeasured build first (a build other than the first measured one); the gate uses it | [evidence](../evidence/ml-menu-phase-check-20261011.json) | this commit |

## Next task

The read-ahead wait: under the phone's present memory pressure the load
waits 0.3–0.8 s for the read-ahead in every build (0.0 s at the S2 gate);
the phone timeline of the menu phase shows whether the read-ahead can start
earlier or do less. Then, as before:
M7b (the file events' bytes in the catalog operation log, kept by the loaded
menu's retained input: ~22 MB on the Mac heap; every session level's tests
compare those journals, so only the retained copy can be compacted, and
`finishLoadedMenu` runs every tick). Remaining large holders that are not
resident in practice: surfaces (1.2 GB allocated, mostly untouched calloc
pages) and the startup heap blocks (zero-filled). S1 (assets read in place
from the APK instead of extracted) needs the user's decision. Remaining load (5.2 s on the A12): Frame bodies, bitmap construction,
sounds and DAT decoding, each a few percent of the catalog window. The catalog session is the load's
critical path (A12 L13 profile: frame bodies ~28%, sounds ~28%, file indexing
and scanning ~16%, bitmap construction ~8% of its ~10 s). M5b (the audio
logs' bulk copies, the float samples) needs a retention review. S1 (assets read in place
from the APK) waits for the user (APK size against first-launch time and
storage).
