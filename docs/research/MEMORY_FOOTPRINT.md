# M1 — Memory footprint of the native game

Workflow: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md); parent study
[CROSS_PLATFORM](CROSS_PLATFORM.md) (P8 Android).

**Consumer in native/ and integration criterion:** every host, first the Android
app: the game must load and play on a phone with 3 GB of RAM (Galaxy A12, 2.8 GB
MemTotal), where Android's low-memory killer ended it during startup loading
([evidence](../evidence/crossplatform-p8-android-phone-20261005.json)).
**Reason:** user decision 2026-10-05 ("make the game fit in less memory").
**Status:** research and transfer, step by step.
**Game result:** unchanged by definition: only how the native port holds data
changes, never what the game computes or shows.
**Reference:** the pinned EXE (SHA-256 `3f7ac67c…ff71c`) is not touched; the
comparators are the frozen app_e2e references, the matrix frames and the Core
tests.
**Declared scope:** host-side and Core storage representations of data the
game already owns (loaded inputs, surfaces, masks), each change proven
value-identical.
**Out of scope:** any change to game rules, numeric semantics, pixel formats
the game observes, error boundaries (an input that fails to load must still
fail at the same point), or the frozen fixtures and references.
**Executor / independent reviewer:** Claude (this session) / a separate
read-only reviewer agent per storage-model change; a missing review is stated.
**Allowed paths:** `native/Sources/NTSDCore`, `native/Sources/NTSDRuntime`
(storage only), host targets, `tools/`, this card and its evidence.

## Measurement (2026-10-05, macOS headless, app_e2e computer-vs run)

[Evidence](../evidence/crossplatform-memory-footprint-20261005.json) and
[attribution](../evidence/crossplatform-memory-attribution-20261005.json):
peak footprint ~3.9 GB, almost all heap (mapped files 35 MB). Live heap at
3.7 GB, grouped by allocation stack (malloc_history, MallocStackLogging=lite):

| Holder | MiB | Allocations |
| --- | ---: | ---: |
| Display surfaces, pixel values (`Storage.init` ← `performBitmap` ← loading `bitmap`) | 1113 | 851 |
| Decoded catalog bitmaps kept in inputs (`OriginalDIBPixels` ← `Bitmap.init`) | 962 (+79 startup) | 1786 |
| Bitmap file bytes copied into `Bitmap.dib` (catalog, arena) | 604 (+62) | 1786 |
| Display surfaces, per-pixel `known` bytes | 283 | 851 |
| `OriginalStateRecord` writes (bytes and byte-per-flag definedness) | 181 | 55k |
| `OriginalFrameLoader.projected` dictionaries | 161 | 55k |
| Sounds (`OriginalMacAudioBackend`, wave loader) | ~90 | ~2.5k |

The same images are held three times: as file bytes, as decoded colours with a
definedness byte per pixel, and as 32-bit surface values with a known byte.

## Plan

| Step | Change | Expected saving | Proof | Status |
| --- | --- | ---: | --- | --- |
| 1 | `Bitmap` keeps its DIB bytes and resolved pixel offset, not the decoded copy (it still decodes at load, so the same images fail at the same point); each surface's source-colour record keeps a whole-copied bitmap instead of its decoded arrays (decoded once if read). | ~1.0 GB | **done:** live heap 4.1 → 3.02 GB; 15 Core suites (51 tests) pass; vs equal headless and AppKit, frames identical; independent review OK ([evidence](../evidence/crossplatform-memory-step1-20261005.json)) | done |
| 2 | Surface `known` mask one bit per pixel instead of one byte | ~0.25 GB | display backend tests, app_e2e, frames | in progress |
| 3 | `Bitmap.dib` without the extra copy of each file (slice or mapped file bytes) | up to ~0.6 GB | as 1 | queued |
| 4 | Remaining large holders (surface values, state-record definedness, frame-loader dictionaries) after re-measuring | open | to be decided from the new attribution | queued |

Metric: the live heap (`heap -s` 40 s into the computer-vs run). The macOS
footprint counts compressed memory and varied between 1.4 and 3.1 GB over
identical runs, so it is not used to compare steps.

Each step: macOS release build, the affected Core/runtime tests in a release
test build (`build/swiftpm-test-release`), the app_e2e scenarios, the
headless/Android frame comparisons, a new footprint measurement, an
independent read-only review of the representation change, then a commit.
Stop condition: the phone loads and plays, or the remaining holders need a
semantic change (then ask the user).
