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
| 3 | `OriginalStateRecord` keeps records of ≥ 4 MiB (the replay buffers) in 16 KiB pages, so a rollback copy that is written duplicates one page | same contents, errors and equality; review OK | done when its Core suites pass |
| 4 | Front-buffer copy loop by row: the source index steps ±1, key bounds read once; `allKnown` by 64-bit words | same pixels in the same order; review OK | **done** |
| 5 | Copy loop: a fully known source span skips the per-pixel test; the target's known bits are gathered per word and written once | same pixels and bits; the loop never reads the target mask (no independent review: recorded gap) | **done** |
| 6 | `LoadedMenuSession.Attempt` collects its address ranges locally (each append to the class property paid a dynamic exclusivity check, 3.3% of the phone's time in TLS lookups) and walks the wave owners without copying them (`OriginalWaveLoadResult` copies: 570 refcount samples) | same ranges, order and throw points | next |
| 7 | Re-profile; then the framebuffer/present path (`memcpy` from `performFront`, Android `WindowHost.draw`) and the bindings' record copies | — | queued |

**Phone profile after steps 3–4** (24,085 samples): `performFront` self
16.2% (half of it `KnownMask` bit get/set in the copy loop), `memcpy` 12.0%
(framebuffer copies 763 samples, bindings store/read 700), reference
counting 19.9% (`OriginalWaveLoadResult` copies 570, record copies 281, menu
state 227), exclusivity TLS lookups 5.4% (791 in `Attempt.reserve`).

Not pursued without the user: building Android with
`-enforce-exclusivity=unchecked` would remove the TLS lookups everywhere, but
it drops a runtime safety check rather than changing representation.
