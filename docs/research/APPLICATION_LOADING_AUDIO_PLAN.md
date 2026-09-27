# Per-call common and catalog audio with owned regions

2026-09-27 Europe/Moscow. HEAD5ab3e9b1eacd32047f158d401ebfdb7909151524.
Implement the complete contract in APPLICATION_LOADING_AUDIO_PREFLIGHT, using
WORKFLOW and the unchanged checked application-mac-audio-correction2 candidate
(2284 files, manifest80ced805b198ebdc49068ca1c7e6068ccd7da41828d5c9053be0df04f16ce981).
This advances audio ownership across first loading toward the full native game.
One author owns edits; no independent reviewer is available in this session.
Author inspection and deterministic comparison do not close that review gate.

## Contract and declared changes

Retain one WAV algorithm and both legacy and observed inputs. A preparation
selects legacy aggregate replies or file/MMIO inputs plus a per-call handler.
Do not move legacy validation, file access, request-factory evaluation or events
earlier. Prior backing remains independent of subsequent actual Lock responses.
Thread the preparation through InitialSoundLoading, InitialLoadingCommon,
ApplicationLoadingSession, RegisteredSoundLoading and CatalogControls/Session.
Keep old APIs and expected bytes/masks/events. False common returns still count;
invalid Create and live short-read temporaries remain explicit boundaries.

Wave ownership carries binding, result and addressed versus opaque identity
domain. Legacy source owners retain their strict output/count/range checks.
Observed owners derive storage from actual Lock replies and result.regions.
Opaque owners retain backend identity, matching actual buffers/regions and their
physical resource leases; integers are not byte addresses. Catalog, pool and
loaded-menu consumers keep addressed reservations and retain opaque owners.
Foreign namespaces, malformed bindings or incomplete ownership cannot authorize
a downstream allocation. Repeated paths keep distinct buffer owners.

Use OriginalRequestExchange for one chronological loading journal and a Host
coordinator. Resume consumes retained replies only; service runs after the whole
Core/Host stack unwinds. Finish the cursor at the final fallible beforePrepared
hook, before nonthrowing Host publication. Preserve cancellation, indeterminate
service, stale tickets, exactly-once effects and resource lifetime semantics.
Backend preparation is namespace-bound and single-use. Extend the Mac audio
service with loading replies and ordered SetVolume(-10000) scalar ownership.
Assignment precedes WAV and volume; cache path+NUL/count follows. Ignored HRESULTs
remain observations. This is not a gain, playback, mixing or endpoint proof.

Allowed candidate changes: new Core OriginalWaveOwnership.swift,
OriginalWavePreparation.swift, OriginalLoadingAudioExchange.swift and
OriginalApplicationObservedLoadingAudio.swift; the eight existing Core files
listed above plus ApplicationPoolSession and ApplicationLoadedMenuSession;
OriginalInitialLoading.swift forwards its optional per-call audio factory for
the retained whole historical loading comparison;
Mac OriginalMacAudioBackend.swift/OriginalMacAudioService.swift; new tests
OriginalLoadingAudioTests.swift/OriginalMacLoadingAudioTests.swift. Existing
reference/test helpers may gain an optional observed-input path with unchanged
default behavior and comparison assertions: CatalogSoundsReference,
InitialLoadingReference, OriginalApplicationLoadingPrefixTests and the direct
full-catalog/pool/menu fixture helpers if needed. Freeze the exact changed-file
manifest before build; no fixture, expected byte/mask or old test-method removal.

## Finite comparison and stop boundaries

Retain all145 existing selectors in the preflight next-comparison inventory.
Preserve limits for the prior120; the additional25 each1800s/12GiB RSS.
Add exactly these six selectors:

1. OriginalLoadingAudioTests/testWholeCommonAndInitialLoadingWithObservedReplies:
   all12 saved common application cases and both retained full initial-loading
   passes through actual per-call reply plumbing, including stopped outcomes.
2. OriginalLoadingAudioTests/testWholeSourceCatalogAndInterleavedObservedReplies:
   unchanged full400 and interleaved29 comparisons, all bytes/masks/events/cache.
3. OriginalLoadingAudioTests/testOwnershipDomainsAndOrderedCacheControls:
   addressed overlap rejection, actual Lock provenance/aliases, incomplete and
   foreign owners, repeated paths and volume-before-cache/cache-hit behavior.
4. OriginalMacLoadingAudioTests/testOwnedStartupCommonAndRegisteredBuffers:
   one backend from whole own startup through18 common and registered WAVs,
   exact input-derived raw/sample values and retained actual buffer identities.
5. OriginalMacLoadingAudioTests/testWholeCatalogPoolLoadedMenuHostWithOwnedAudio:
   full Native137-Object catalog/400 registrations with declared non-audio
   controls, then pool/loaded-menu/Host handoffs retaining the same audio owners.
   This is not a new full original application return (source59727 ended at34).
6. OriginalMacLoadingAudioTests/testLateRetryProtocolAndRetainedOwners:
   late rollback/retry, cancellation, foreign/stale/repeated replies and permits,
   service failure, no duplicate allocation/copy/volume, owners outlive drivers.

New methods each1800s/12GiB except full Native catalog/handoffs3600s/12GiB.
One fresh release build-tests --jobs2 -enable-testing,3600s/12GiB; queue14400s.
Bound replay to3000 loading requests and3002 resume attempts for full Native
catalog. Never serve IO inside Core or drop the full caller after a timeout.
Use the existing one-method runner and exact XCTest parser, stop first nonpass,
retain all failures and unstarted methods. No new original execution/capture.
Existing source blobs are inputs; expected after-state is comparison only.
Controlled protocol errors are not claimed reachable Windows/device failures.

## Inputs, storage and delivery

EXE3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c;
lib.dll28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba.
Apply archive835–905,1322–1344,1543–1575,2492–2525,3349–3485,3648–3681,
4380–4405 and current preflight reconciliation. Retain root1034/prior2257/
base2284/source55, old producers/plans/failures and the immutable archive.

Task application-loading-audio-20260927 on writable X5 APFS UUID
3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548. Verify mount/UUID/free space before IO.
Require131GiB external/9GiB internal to prepare; preserve121GiB external
(40+17source+64VM) and6GiB internal.8GiB allowance/6GiB observed decrease stop,
150GiB logical task cap. No evidence deletion or reserve reduction. T7 unchanged.
Root additions4MiB; metadata archive32MiB; finalizer3600s. Use existing cloning,
manifest, guarded build/queue, package, artifact and PAX verification procedures.
Root writes: this plan/study/evidence, tools/loading_audio_candidate templates,
task-specific apply/prepare/finalizer helpers and own navigation additions.
No root Native promotion. Mutable templates are preparation, not accepted code;
freeze all producers and exact inputs before starting a build or comparison.

The implemented template inventory is21 Swift paths:13Core (4new),2Mac,
2Reference and4Tests (2new). Exact-clone candidate2290 files therefore retains
210Core/61Reference/11Mac/291Tests and all385fixtures/1301runtime resources.
The extra full-catalog helper is OriginalApplicationCatalogFullReference.swift:
the unchanged non-audio record checks are factored into completeRecords, while
the old complete method still runs every old WAV comparison. The new Native
test checks its actual whole-Lock raw/masks/samples against source input files.
This declared Native response shape does not replace the old split-Lock corpus.

Build, package bytes,151 comparisons, artifact/archive verification and review
are separate gates. Max3 correction rounds with diagnosis, never blind retries.
Commit each checked coherent increment. Playback/WMA/gain/device, independent
review/root integration, Windows/font/cursor/clean-Mac/full match/game remain
open. Existing safety incidents remain open and are not retried. Host is locked;
Windows approvals persist and no blind UI input is authorized by this plan.
