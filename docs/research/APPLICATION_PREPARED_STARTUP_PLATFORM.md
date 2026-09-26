# Production prepared startup platform candidate

OriginalApplicationPreparedStartupPlatform now implements the existing startup
platform in Core, with the same window coordinator and Host as its consumers.
Its production code contains no XCTest/reference dependency, fixture reader,
expected state or host IO. Two new Swift files pass syntax parsing; compilation,
all eleven selected methods and independent contract review remain open.

This implements the [bounded plan](APPLICATION_PREPARED_STARTUP_PLATFORM_PLAN.md)
on the actual 2247-file candidate from the
[completed inspection validation](APPLICATION_HOST_WINDOW_INSPECTION_VALIDATION.md),
base HEAD b12ebbd. No old Native file changes. The full standalone game remains
the goal; this removes the test-only platform dependency, not the still-missing
physical device producers or the Practice application path.

## Runtime contract

The platform retains OriginalApplicationStartupInputs and a value preparation.
Files use the original package with explicit prepared overrides; absent, empty
and unsupported names are distinct. Each existing nonwindow response family has
typed entries, including complete request arguments where the interface has them.
No entry means unavailable input and throws; there are no guessed successful
clock, allocator, codepage, window, joystick or audio responses.

Sixteen response families cover milliseconds, critical-section bytes, COM, panel
write/close/allocation/bitmap/device, FILETIME, timezone, calendar allocation/name
conversion, music, cursor, joystick and aggregate WAV inputs. Existing sound,
panel IO and TZ values remain explicit preparation data. Request mismatch or
missing input leaves its position and attempted output unchanged. Negative and
nil responses pass to the existing caller, which owns their recovered behavior.
validatePreparedConsumption checks all prepared response positions at the caller's
final callback; it does not finish the separately owned window exchange.

Staged copies have independent value positions, attempted panel bytes/close
results and window cursors. Immutable package/prepared bytes may share Swift
value backing. Opaque resource owners are retained through copies and delivery
contexts, never invoked or used as mutable queues. The attempted panel journal
does not represent physical writes or a second FILE implementation. Allocations
are declared Native reservations whose backing passes to existing owned children;
this adapter does not import private CRT storage or promote unknown bytes to known.

Window calls use the existing cursor and throw its existing suspension signal.
Music helper/format notifications have discarded results in the shared caller and
consume no terminal device response. Terminal music requests remain exactly bound.
The existing sound/WAV aggregate interface is retained; no per-call live mixer or
physical cancellation/replay policy is claimed. Native rollback cannot undo IO.

## Comparison design and author review

Three new methods precede all eight unchanged inspection/startup methods. The whole
comparison uses the actual new platform inside the coordinator/Host. A test-only
wrapper sends the same arguments, stores and observations to the unchanged source
adapter; only the new platform's replies feed Core. The reference adapter never
initializes the new platform from its computed or expected after-state.

Preparation projects declared spec/API inputs. Recorded allocation **backing** is
the separate pre-allocation input, not the later bytes/masks. Panel file paths bind
the controlled source requests; original menu WAV input bytes come from the real
package and compare against saved input hashes. The selection keeps all 35 parents,
their 23 complete/5 stop/7 provenance outcomes, full source event/store/owned-state
checks and operation/graphics comparison. These are selected checks, not new passes.

The other methods cover six late failures plus publication-copy failure, preparation
failure/retry, copied positions/output and retained owners. Finite direct controls
cover all sixteen families, missing/duplicate requests, thirteen mismatched bindings,
unconsumed input, absent/empty/unsupported files and missing window cursors. Synthetic
boundary inputs do not establish natural game reachability or device behavior.

Author pre-parse review found two issues in the new test preparation, both corrected
before execution. Throwing provider calls were moved outside XCTest autoclosures so
the error reaches the surrounding boundary assertion. The saved null-bitmap case
also retains an unused device control: the existing child returns immediately on
NULL allocation, before source/device requests. Its preparation now includes only
the allocation input for that branch. The case and all expectations remain intact.
Both earlier drafts and separate author-review records are retained. This is not
independent review and is not a claim that either earlier draft failed a Native run.

## Verification and handoff

Preparation 97242 completed with exit 0 in 9.367 seconds: all 2247 baseline files
were cloned and checked by bytes, modes, nanosecond mtimes, membership and distinct
regular inodes. Parser 11982 completed with exit 0 in 1.194 seconds; both file logs
are empty. Syntax parsing does not establish type correctness or Native comparison.

The [publication](../evidence/application-prepared-startup-platform.json) and
[closure](../evidence/application-prepared-startup-platform-close.json) record the
2249-file candidate, two-new-file patch roundtrip,
all prior test/fixture/resource/root/source preservation and full APFS/PAX archives.
Task alias is `build/research/application-prepared-startup-platform-20260926/`.
The declared 4 GiB physical/16 GiB logical bounds and 40/6 GiB reserves plus 17 GiB
source commitment remain. T7 remains separately authorized; these clones use X5.

Finalizer14906 completed with exit0 in22.763 seconds and is absent; the task is
frozen. The full candidate archive has2249 files/59 directories and5,127,113,934
logical bytes. Its manifest SHA256 is
`941ffb9c67ccf4accc0f5027729ac81e0e7ba8f9c13d0524cdf0c9d3ab6cc27b`.
The31-member metadata archive has2,068,480 bytes, SHA256
`50f6c0d9ee142e7be20ccb460c9acac5a30ee031398b12431f46d1c39e464d74`.
Candidate manifest SHA256 is
`295864416a72f76e19471ece43331fc40d4a2a2ec8b6d66dbe69251c7c977eb6`.
The archived study retains its earlier snapshot; this terminal documentation is
pinned separately in the root receipt. Root1034/base2247/source55,385 fixtures,
1301 resources and every old test file remain unchanged.

NEXT: fresh build/package and all eleven selected complete methods on the frozen
candidate. Preserve and diagnose a nonpass before a separately pinned correction;
do not edit the frozen candidate or restart old captures. After comparison, connect
actual prepared observations/resource ownership to the platform and application;
do not treat this value provider as a working physical backend.

Independent review, root promotion, physical window/resource mappings, synchronous
callbacks, clock/queue acquisition, audio, initialized loading messages/fills,
Windows/device/clean-Mac/full match and full game remain open. Source59727 stays
terminal at34 Objects, with full137/transport/provenance and existing incidents open.
No original, emulator, capture, affected refused operation or device executes here.
EXE envelope was not recalculated.
