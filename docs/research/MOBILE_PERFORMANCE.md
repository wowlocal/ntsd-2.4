# M2 — Game speed on slow devices

Workflow: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md); parent studies
[CROSS_PLATFORM](CROSS_PLATFORM.md) (P8 Android) and [MEMORY_FOOTPRINT](MEMORY_FOOTPRINT.md).

**Consumer and criterion:** the Android app on the user's Galaxy A12 (Cortex-A53
cores, 2.8 GB RAM): a match must run at the game's own rate (about 30 game ticks
per second), which needs the native port's per-tick work to fit the device.
**Reason:** after the memory work the game loads and plays exactly on that phone,
but at about 5.4 ticks per second without frame capture (2026-10-05).
**Status:** research and transfer.
**Game result:** unchanged by definition; only how fast the port computes it.
**Out of scope:** any change to game rules, timing semantics, error boundaries,
frames or references.
**Executor / reviewer:** Claude / an independent read-only reviewer per change.

## Measurements

| Run | Ticks per second (gameplay bodies 300→1800) | Notes |
| --- | ---: | --- |
| macOS headless (M-series), vs script, frame digests on | 27.0 | busy 24 s of the run; the rest is the game's own sleeps |
| Galaxy A12, vs script, frames and digests on | 4.5 | memory steps 1–3 |
| Galaxy A12, vs script, no frame capture | 5.4 | busy 454 s; peak resident 1.26 GB |
| macOS headless after steps 1–2 | 30.1 | busy 16.4 s |
| Galaxy A12 after steps 1–2 | **7.6** | busy 339 s ([evidence](../evidence/crossplatform-speed-steps12-20261005.json)) |
| Galaxy A12 after step 3 | **8.8** | peak RSS 1.32 GB |
| Galaxy A12 after steps 3–4 | **9.2** | |
| Galaxy A12 after steps 3–5 | **9.3** | ([evidence](../evidence/crossplatform-speed-steps45-20261005.json)) |
| Galaxy A12 after step 6 | **9.4** | exclusivity TLS 5.4% → 1.6% of samples ([evidence](../evidence/crossplatform-speed-step6-20261005.json)) |
| Galaxy A12 after step 6b | **9.9** | ([evidence](../evidence/crossplatform-speed-step6b-20261005.json)) |
| Galaxy A12 after step 7 | **10.2** | ([evidence](../evidence/crossplatform-speed-step7-20261005.json)) |

macOS `sample` of the headless match (20 s): before step 1 the main thread's
time was in the display backend's front-buffer drawing (`performFront` 1418
and `frontCopy` 1066 top-of-stack samples, `memmove` 831).

**Phone profile after steps 1–2** (simpleperf `record --app --call-graph fp`,
30 s of scripted VS gameplay on the Galaxy A12, 25,088 samples, 98% on the
main thread; inclusive shares):

| Phase | Share |
| --- | ---: |
| Front-buffer drawing (`performFront`) | 26.5% |
| Loaded cycle (`OriginalApplicationLoadedCycleSession.advance`) | 22.9% |
| …input/replay entry (`OriginalLoadedMatchEntry.run`) | 18.1% |
| …the replay packet's byte writes (`OriginalStateRecord.write<Int8>`), almost all `memcpy` | 16.1% |
| Gameplay session | 13.0% |
| Android window drawing (`WindowHost.draw`) | 5.0% |
| Bindings store / read | 4.5% / 2.0% |
| `madvise` (freeing the large copies) | 2.4% |

By symbol: `memcpy` 25.8%, `performFront` 16.7%, `swift_retain`/`release`
11.9%. A temporary copy-on-write probe on macOS showed why: every cycle's
rollback copy shares the 0x630e18-byte replay recording buffer, and the
packet write duplicates it (1,659 copies in a match, ≈21.5 GB with the
definedness mask), plus 2.9 million actor-record copies.

## Plan

| Step | Change | Why it keeps behaviour | Status |
| --- | --- | --- | --- |
| 1 | `frontKnown` returns at once when `presentUnknownAsBlack` is set (every host's runtime sets it): its scan of the whole delivered rectangle, run twice per blit, can only throw an unknown-pixel boundary, which that flag rules out | the scan has no other effect than that throw | **done** (review OK) |
| 2 | Read `values`/`known` once before each per-pixel loop (the step-3 reviewer's note) | nothing records a write inside those loops | **done** (review OK) |
| 3 | `OriginalStateRecord` keeps records of ≥ 4 MiB (the replay buffers) in 16 KiB pages, so a rollback copy that is written duplicates one page; the assembled contents are cached per written version; the replay writer reads its buffers once without caching | same contents, errors and equality; reviews OK; 31 Core suites, all 10 scenarios, AppKit equal ([evidence](../evidence/crossplatform-speed-step3-20261005.json)) | **done** |
| 4 | Front-buffer copy loop by row: the source index steps ±1, key bounds read once; `allKnown` by 64-bit words | same pixels in the same order; review OK | **done** |
| 5 | Copy loop: a fully known source span skips the per-pixel test; the target's known bits are gathered per word and written once | same pixels and bits; the loop never reads the target mask; review OK | **done** |
| 6 | `LoadedMenuSession.Attempt` collects its address ranges locally (each append to the class property paid a dynamic exclusivity check) and walks the wave owners by index | same ranges, order and throw points; review OK | **done** |
| 6b | `GameplaySession.advance` collects its sound-buffer tokens without concatenating the three load lists (copied every `OriginalWaveLoadResult` each cycle: 672 refcount samples) | same set, used only for membership; review OK | **done** |
| 7 | Copy loop: rows that are fully known, unkeyed and forward (two thirds of the copied pixels: whole-screen copies) are copied with one row copy and whole mask words | same values and bits; review OK | **done** |
| 8 | `MenuSession.State.replace` overwrites the record in place (`OriginalStateRecord.overwrite`) instead of copying it twice and rebuilding it | same record; review OK; no measurable phone change (10.2 → 10.1, noise) ([evidence](../evidence/crossplatform-speed-step8-20261006.json)) | **done** |

**Phone profile after steps 3–4** (24,085 samples): `performFront` self
16.2% (half of it `KnownMask` bit get/set in the copy loop), `memcpy` 12.0%
(framebuffer copies 763 samples, bindings store/read 700), reference
counting 19.9% (`OriginalWaveLoadResult` copies 570, record copies 281, menu
state 227), exclusivity TLS lookups 5.4% (791 in `Attempt.reserve`).

Not pursued without the user: building Android with
`-enforce-exclusivity=unchecked` would remove the TLS lookups everywhere, but
it drops a runtime safety check rather than changing representation.

**Where the phone's time goes after step 6b** (simpleperf, 24,072 samples,
inclusive): front-buffer drawing 26.1% (its own copy loop ~14%, Android
window drawing 4%, the framebuffer copy 3%), gameplay session 17.1%
(gameplay body 11.4%), loaded cycle 10.9%, bindings store 7.0% and read 2.5%
(per-cycle conversion between the match model and the session state: 400
actor records and the allocation dictionary copied each cycle), loaded menu
attempt 4.6% (iterating every live allocation), menu state replace 2.2%.
By symbol: `memcpy` 12.5%, `swift_retain`/`release` and atomics ~15%.
Each remaining item is worth a few percent; reaching the game's ~30 ticks per
second on this phone would need the per-cycle state plumbing restructured
(the bindings' round trip and the rollback copies), not further local fixes.
