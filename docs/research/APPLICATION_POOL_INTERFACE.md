# Owned application pool and loading interface

This card connects the actual completed `OriginalApplicationCatalogSession.PendingPool`
to the shared loading continuation: 400 Actor allocations/constructions, eight
staging reconstructions, ten embedded UI bitmaps and the loading flag clear at
`41c577`. Its result is `PendingInput`, before `41c581`. It retains the catalog,
common/startup/registered sounds, command buffers, current application state and
staged operations. The input/outer-loop continuation and backend delivery remain
open; this is not a whole original application return or a played match.

All 26 bundled release tests passed in 190.426s (build 313.61s) on frozen
candidate3. Work records are in `build/research/application-pool-interface-native-20260913/`.

## Evidence and environment

The behavioral reference remains the original NTSD Windows distribution, EXE
SHA-256 `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
CRT `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
This card reads saved controlled traces, original PE resource bytes and extracted
BMP files as data. It executes a new data-only decoder and Native Swift, without
running the original, an emulator or historical producers/auditors. Prior safety
incidents remain open; no blocked operation is retried.

Dependencies are [the owned full catalog](APPLICATION_CATALOG_FULL_NATIVE.md),
[loading continuation](INITIAL_LOADING_CONTINUATION.md),
[pool/interface composition](INITIAL_POOL_INTERFACE.md),
[whole interface helpers](INITIAL_INTERFACE_SURFACE.md) and
[surface source colors](APPLICATION_SURFACE_COLORS.md). The ten saved whole
pool/UI cases and two continuous initial-loading cases remain required regressions.
Their supplied catalog/World/device environments remain distinct from this own
application composition.

All 203 blobs (4,169,710 bytes) in the saved interface corpus were verified.
Each of the ten DIBs matches its blob, the exact pinned PE resource entry
`RT_BITMAP / name / 1028`, and the extracted BMP after its 14-byte file header.
A new data-only reference uses the already accepted pure DIB decoder definitions;
an independent reviewer reparsed the PE tree, all 4,191 RLE commands and the
entire pixel payload. Nine resources use RLE8; `BARS` uses 24-bit BI_RGB.

The original DIBs total 40,102 bytes. The independent RGB/mask reference contains
411,732 bytes for 102,933 pixels and 313 rows: 96,058 pixels are written and
6,875 remain unknown. Unknown pixels do not become black or transparent device
pixels. None of these ten DIB hashes was in the earlier startup/catalog goldens.
Reference files are test-only; the ordinary `OriginalLoadingInterface` runtime
package contains the ten original DIBs and a pinned manifest. Existing startup
and common-sound packages remain unchanged.

## State and ownership

`OriginalApplicationPoolSession` calls `OriginalInitialLoadingContinuation` and
the existing pool/UI handlers. It takes current globals from the catalog entry
and current World from full storage `[bb00:c2d8]`; it never reconstructs World
or copies an earlier common-prefix cache over live state. The canonical full
record retains its outer/World and replay-pointer aliases.

The shared bootstrap keeps canonical ordinals. At each completed pool phase,
the session binds World catalog/Actor slots and Actor `+368` to its own logical
allocation identities. Canonical bootstrap records remain owned separately for
their next game consumer. Other pointer-looking bytes and their masks are not
normalized. The eight late Object `+90` consumers read the actual first loaded
Object (`chars\pein.dat`, known word zero), rather than the old controlled
`12345678` input. Staging positions/order remain the shared recovered rules.

The declared Native provider uses Actor tokens `75000020 + slot*500` and UI
wrapper tokens `76000020 + index*2000`. These are logical test identities, not
host pointers or Windows allocator behavior. The historical UI base `50000020`
would collide with the current catalog Object and is not reused. Allocation
ranges exclude the whole canonical globals/outer/World record, prior live menu
allocations, all catalog allocations, existing file buffers and all retained
startup/common/registered PCM regions. NULL Actor allocation is an explicit
unsupported boundary; numeric UI outcomes retain the existing shared handlers.

The new image/surface/memory-DC/surface-DC identities use declared
`7a100000/7b100000/7c100000/7d100000 + 16*index` ranges. The existing graphics
registries retain generations and reject conflicting live handles. Core derives
BITMAP output from owned DIB bytes and surface descriptions from its own request;
captured response writes are rejected. Canonical bitmap surface `1/0` becomes
the actual surface token/zero in the application memory view. No old wrapper is
released by this loading path.

All work belongs to a fresh tentative attempt. The shared context and the
session's private state buffer changes until the final observer returns.
Callbacks expose constructor records, completed pool phases, UI globals and API
events, not a claimed per-instruction full-memory snapshot. Allocations and
terminal bitmap APIs extend one operation journal; helper observations are not
second backend operations. Even a successful `PendingInput` awaits the enclosing
input/outer-loop boundary before backend publication.

## Comparison

The new test constructs its full parent through the accepted Native bootstrap,
menu, common resources and 137-Object catalog, including the full parent
comparator. It reuses that immutable owner for independent pool attempts.

Comparison-only replay starts at original store 109 (`41c052`), after the old
World constructor and two supplied fields. Actual current World is the retained
input operand; original writes determine every subsequent compared byte/mask.
All 408 constructor returns and both 400-record pool phases compare. Only typed
catalog/Actor/Object references and the eight proven input-derived `+31c` stores
are rebound. The Object read occurs one store before its `+31c` write, with an
intervening x-position store; the original trace and its indices remain intact.

The complete final application record, all old memory owners, 400 newly bound
Actors, ten final bitmap records, both command buffers and sound owners compare.
Every saved UI API request/response is checked with typed device/handle rebinding,
including known bytes and masks; unknown private API backing is not imported.
The comparison checks the complete operation sequence, graphics commands and
resource/DC generations, prior owners and new source RGB/masks against the
independent data reference. This is a composed Native contract under declared
platform responses, not a missing whole original application trace.

## Validation and preservation

Six new test methods cover the full owned join, eight late Native cancellations,
19 allocation/input guards, complete pixel/mask/row comparisons, ordinary app
resource packaging and missing/corrupt/extra/symlink rejection. Twenty retained
methods cover the full catalog, three earlier 20-Object parents, bootstrap and
whole loading/pool/UI contracts. All 26 passed on the final bundled release
candidate without raw overrides; `NTSDNative` linked. An app-style test bundle
is not an actual window or device run, and the full packaging command was not
executed for this card.

Late cancellation points are allocation399, constructor407, completed staging,
last CreateSurface, last DeleteObject, last UI global, controls.finish and final
publication. Three complete comparisons reach beforeCommit; one is deliberately
cancelled there and two publish PendingInput, including a fresh-provider retry.
Sixteen range guards cover Actor and UI overlap with canonical World, catalog,
Object, old menu allocation, three PCM classes and an existing file buffer.
Three more guards reject NULL Actor, overflowing extent and captured bitmap writes.
These are Native rollback contracts, not source API-failure matches.

Native1 passed all26 tests in191.450s/build318.91s, before independent review
strengthened the comparator. The unexecuted frozen candidate2 is preserved.
Native2/frozen2b failed compilation before tests because the new final checker
redeclared local `b`; candidate3 changes only that local name and its uses.
The compiler error and the review gap that missed it remain. Core and original
expected bytes did not change between these Native rounds. The initial plan's
EXE basename lookup, first data decoder's raw-DEFLATE assumption and a later
review-report display-key lookup failed before their respective publications;
all are retained separately with their corrections.

Independent reviews cover source data, Core, comparator, mechanical compile
correction and preservation gates. The initial Core range gap was corrected
before Native1 by reserving full globals/outer/World storage. Comparator review
added exact source-derived global stores, final canonical pool, complete retained
catalog/WAV fields, old state owners, all graphics metadata and nil API bytes.
Publication review tied job/config/candidate/review pins and every archive member
to their original manifests. No historical expectation was changed or omitted.

The preservation gate covers all934 Native files, four frozen versions,381
current fixtures including379 unchanged old fixtures,46 unchanged startup files,
19 unchanged common-sound files and11 new UI package files. Earlier candidates
reconstruct from the final Native archive plus five explicit overlays. Current
`tools/package_assets.py` is a separate evidence archive member; its old Git-base
version also remains. Every archived name, byte, SHA and mode is compared to its
pinned source. Final results and exact archive hashes are in the
[machine-readable evidence](../evidence/application-pool-interface.json).
The32GiB task/6GiB internal reserves remain; shipping resources are regular local
files. All three Native jobs are terminal and their PIDs were checked absent.
The final Native archive contains934 members/4,435,640,320 bytes; the evidence
archive contains124 members/137,492,480 bytes. Both were read back in full.

## Remaining boundary

Continue from `PendingInput` through `41c581`, input/menu/loading caller and the
outer loop before publishing effects. Preserve the newly owned pool and UI with
the same catalog, RNG, sounds and aliases. Full original application return,
downstream consumers of newly loaded surfaces, actual format/palette/raster,
Windows/device, AppKit input/audio, complete matches/content/network and clean-Mac
acceptance remain open. Completed original captures must not be restarted.
