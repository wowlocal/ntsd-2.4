# Common/catalog audio requires an explicit identity domain

2026-09-27. The [checked PCM startup candidate](APPLICATION_MAC_AUDIO_CORRECTION2.md)
has a working Native buffer owner and per-call WAV service. Connecting it to
common/catalog loading also requires an ownership change: three later consumers
treat legacy PCM pointers as byte addresses, while the Native backend deliberately
allocates opaque resource identities. Passing its tokens through the old
OriginalWavePlatform ownership fields would give false overlap results.

This [finite preflight](APPLICATION_LOADING_AUDIO_PREFLIGHT_PLAN.md) reads39 Native
files and15 studies/publications from the2284-file candidate with manifest
80ced805b198ebdc49068ca1c7e6068ccd7da41828d5c9053be0df04f16ce981.
It verifies54 line-numbered anchors, one synthetic arithmetic witness and four
range controls. No original, Native, compiler or audio/device code executes.
The existing409-file input inventory is read as saved evidence; original asset
bodies are not reread. Author inspection is not independent review.

## Why threading the callback alone is insufficient

OriginalInitialSoundLoading already accepts a request factory, but
OriginalInitialLoadingCommon and ApplicationLoadingSession omit it. The latter's
PendingCatalog carries aggregate WavePlatform records. RegisteredSoundLoading
similarly calls the legacy WAV interface, then SetVolume, then lets its registry
caller copy the path and increment the cache count. CatalogControls supplies
aggregate WAVs and separate volume replies.

CatalogSession.StartupSounds carries the five startup results alongside those
platform records. CatalogSession retains startup/common/registered PCM by checking
the predicted buffer/count and reserving [firstPointer,firstPointer+byteCount).
PoolSession and LoadedMenuSession repeat the same reservation using the retained
platform arrays. Their protections are correct for the declared addressed source
model; they are not valid for an opaque Native token namespace.

OriginalMacResourceIdentityPool starts at1 and increments by1 for every resource;
its tokens explicitly do not encode pointers or address ranges. AudioBackend
allocates a Device, then a Buffer and a Lock Region for each successful WAV.
WaveLoader already records actual Lock replies and region-owned bytes/masks.
That actual provenance must cross the caller handoffs instead of manufacturing
an aggregate future buffer/pointer response.

## Concrete static witness

For a fresh pool, two ordinary successful loads allocate device1, buffers2/4 and
regions3/5. The saved source inputs data\\001.wav and data\\002.wav have23568 and
23578 data bytes. Interpreting region3 as [3,23571) and region5 as [5,23583)
reports an intersection [5,23571),23566 bytes, despite the distinct identities.

These numbers follow the pinned allocation statements and existing source input
lengths. They are a synthetic arithmetic witness, not recorded values from a new
Native execution, a Windows allocation observation or a source fault. Four
additional arithmetic controls retain disjoint addressed ranges, overlapping
addressed ranges, exclusive-end contact and an empty extent. They are audit
controls, not claims that all such states are reached in the game.

Deleting the old overlap checks would lose the existing source contract and its
regression rejecting a catalog allocation over common PCM. Spacing opaque tokens
by assumed buffer sizes would incorrectly turn an identity pool into a heap model.
The required change is an explicit distinction between addressed storage and
opaque resources, with validation and retention appropriate to each domain.

## Required implementation contract

The next candidate must preserve the following complete chain.

1. Use file/MMIO-only inputs bound to the actual device and destination at each
   request. Keep initial backing separate from later Lock outputs. Continue using
   the shared WAV implementation; retain the legacy adapter for immutable source
   comparisons and existing callers.
2. Carry actual result/Lock-derived region ownership from startup through common
   loading, catalog, pool and loaded menu. Addressed source regions retain range
   checks; Native regions retain identities, bytes/masks and physical owner
   lifetimes. Do not infer address intervals, host pointers, padding or zero data.
   Validate the identity namespace and binding rather than accepting a token from
   an unrelated backend just because its integer happens to match.
3. Thread per-call WAV replies through the common and registered callers. Preserve
   the18 common slots/count, invalid Create continuation, ordinary false returns
   and live short-read temporaries. Existing catalog rejection of unestablished
   ownership stays an explicit boundary until separately recovered.
4. Preserve registry assignment, WAV, SetVolume(-10000), full path+NUL copy and
   count increment in their original order. Ignored HRESULTs remain observed
   replies. Cache hits skip reload/volume. Preserve the400 registrations/365 paths
   and20-byte-stride overwrite behavior; filenames do not identify resources.
5. Serve physical effects only after the whole Core attempt unwinds, using the
   existing retained exchange. A late retry must consume saved receipts, with
   no repeated allocation/copy/volume action. Retain receipts through successful
   and cancelled/failed handoffs according to the existing exchange contracts.
   An indeterminate physical failure is not successful Core rollback.
6. Exercise the next pool/loaded-menu/Host consumers in the same candidate.
   Scalar volume ownership may precede playback, but must not be presented as
   validated DirectSound gain, mixing, scheduling or endpoint behavior.

The current exchange retries a whole Core attempt for each new request. Complete
catalog replay can be expensive. The implementation plan must bound that work
and record actual execution; a timeout remains incomplete. Do not drop full
caller comparisons or perform IO inside Core just to obtain a faster pass.

## Comparison inventory and publication

The [next-comparison inventory](../evidence/application-loading-audio-preflight-next-comparison.json)
preserves all120 currently checked methods and identifies25 additional existing
methods in affected initial-loading, catalog, pool, loaded-menu and Host files.
Each of the145 unique selectors exists exactly once. None was executed here.
Six finite new comparison groups cover source common/catalog callers, actual
Native ownership, full Native catalog/handoffs, failure/retry/lifetime controls
and cache/volume order. Freeze their actual method names and limits before build.

The full Native catalog137-Object composition is distinct from the saved own
application20-Object source prefixes and the older complete controlled catalog.
Source59727 terminal34Objects is not a full137-Object application return. This
preflight does not change those boundaries or restart any capture.

[Publication](../evidence/application-loading-audio-preflight.json),
[anchors](../evidence/application-loading-audio-preflight-observations.json),
[identity witness](../evidence/application-loading-audio-preflight-identity-witness.json)
and [close receipt](../evidence/application-loading-audio-preflight-close.json)
pin the analysis, prior all120 terminal queue and consulted inputs. The existing
publication procedure separately verifies root1034/prior2257/base2284/source55
and all metadata member names, bodies, modes and nanosecond mtimes. Terminal
identities and archive counts are pinned by the documentation receipt.

Implementation, new Native comparison, independent review and root promotion are
open. Runtime playback/WMA/music notifications, pan/volume/mixing/resampling/latency,
Windows font/cursor/device, clean-Mac and full match/game remain open. The last host observation was
locked; earlier installer approvals persist. No EXE-envelope recalculation or
safety-incident resolution is claimed. Commit this checked prerequisite, then
implement the full declared common/catalog ownership connection.
