# Startup audio: per-call sound and WAV replies are the next missing consumer

Static preflight uses the frozen2278-file Native front-raster candidate
`eb462e3c418407b6bb467129b03f50e8c069c4adf6e9d019fd52b2f9f4d0bc9d`.
The preceding all95 comparisons and package/archive gates remain checked.
This audit implements no audio and runs no original, fixture decoder, Native
test or device. See the [finite plan](APPLICATION_STARTUP_AUDIO_PREFLIGHT_PLAN.md).
Independent review remains unavailable; source inspection is not a new D/W result.

## Finding and immediate consumer

Music already has per-call responses in OriginalStartupRequest.music. The missing
startup interface is DirectSound initialization plus the device/copy part of all
five shared WAV children. OriginalApplicationPreparedStartupPlatform.sound is a
nonthrowing fixed property; its observed `.wave` returns the entire
OriginalWavePlatform before the loader performs even Open. Current observations
log later requests with that aggregate. Serving this aggregate through a real
backend would require predicting future requests and outputs or performing the
whole load in the service. Neither is the existing common loader's contract.

The next implementation must replace that dependency with per-call sound/WAV
requests consumed by the existing whole startup journal, preserving the old
aggregate adapter and every original comparison. It must include the five-child
caller, InputStartup, WinMain, bridge and prepared/observed platform, rather than
stop at an isolated queue. This enables a subsequent actual Native sound service;
it does not itself establish a mixer, decoding, timing or Windows equivalence.

## Exact request and response dependencies

| Boundary | Current behavior and evidence | Required consumer contract |
| --- | --- | --- |
| DirectSoundCreate401970 | `deviceCreate` precedes an optional output store to44eecc. Only exact result0 succeeds; any other signed value clears44eecc. A missing/zero successful output rejects. | Issue the original arguments first, then consume the actual result and independent optional output. Preserve output-before-clear order and global store/event positions. |
| Cooperative level / failure message | Successful create calls `(device,live HWND,1)`; its result is ignored. Failed create reloads HWND, requests the original MessageBox, then attempts all five WAV helpers. | Retain even ignored numeric replies in the journal. No implicit success, invented Release or suppression of ordinary failure messages. |
| Five loads | Paths/destinations are fixed in MenuSoundStartup. `wavePlatform` is obtained before the `load` observation; destination clears before file access when device exists. Device0 preserves every prior slot and does no file IO. | Bind every request to call index/path/destination/device; keep helper observations separate from terminal service. Do not acquire a file/device just because an aggregate configuration was requested. |
| WAV file path | Open/Descend/Read/Ascend/Close decisions use explicit controls, with RIFF positions calculated by the shared Native parser from immutable bytes. Next-chunk flags0 and18-byte format reads remain exact. | Keep prepared file/MMIO controls explicit for this audio increment. They are not measured Windows IO. Native package bytes are inputs, not another Open/Read performed while draining operations. |
| CreateSoundBuffer | Native constructs18 format bytes and36 descriptor bytes before `.create`; cbSize is low16(destination). Descriptor format-pointer normalization is a declared research boundary. Any nonzero create result emits the diagnostic/free then returns `invalidCreateContinuation`. | Present the actual Native-computed format/descriptor and masks, consume the actual result/output, and preserve the failed continuation as a distinct stop. Do not execute the source's unsafe fall-through or fabricate a normal return. |
| Lock/Restore | Exact88780096 requests Restore and a second Lock. Restore and final Lock results are ignored. Existing controls use one first/second output pair even when Lock repeats. | Each actual Lock needs its own reply and output provenance. Preserve declared controls; do not infer that real repeated Lock calls return identical spans. Require valid owned leases and reject missing/unsupported outputs explicitly. |
| PCM copy | Current `.copy` carries only region index/source offset/count. Bytes live in `result.temporary`, then Native writes `first`/`second`; the event is emitted before the write. | A serviceable copy must carry immutable bytes/mask from the current Native temporary and the actual destination lease/span. Never take expected result bytes or reopen/redecode the WAV for this copy. Keep the original observation order. |
| Unlock/free/return | Unlock arguments preserve both pointers/counts, including a nonzero second pointer with zero count. Its result is ignored. Temporary then becomes dead; output gets the buffer token. Short reads leave the temporary live. | Retain the actual Unlock reply and lease lifetime; preserve copied snapshots and short-read ownership. Core allocation/free are not commands to replay later. No successful match is claimed for an indeterminate physical operation. |
| Music | `.music` already carries actual create/query/method/file/allocate/convert/message responses through the startup cursor. Helper/format notifications return locally and are omitted from terminal operations. | Reuse this existing boundary. A new service must not execute helper notifications or duplicate terminal music work. Device/codec/format and file output behavior remain unobserved. |
| Music path storage | Wide-path allocations retain unknown masks until explicit conversion writes. RenderFile carries raw backing bytes in its event, without a mask field. Allocation remains retained even after render failure. | A real consumer must derive/retain defined ranges through allocation/conversion receipts or receive an explicit masked input; raw backing alone is not proof of a valid string. This is a later music-service dependency, not permission to mark unknown bytes zero. |

The source string `Could not create a filter graph for this file!` appears in
the negative RenderFile branch in OriginalMusicPlayback. This identifies the
corresponding game branch; it does not diagnose the codec/device reason for the
user's earlier CrossOver dialog or establish that the actual branch was traced.

## Storage and rollback constraints

OriginalWavePlatform currently combines three different inputs: file/RIFF
controls, future device replies, and declared Native scratch/buffer backing.
The loader allocates its `first`/`second` value records from supplied counts and
ramp before testing device0. WaveLoaderReference and MenuSoundStartupTests compare
every byte and defined bit, including these untouched regions on early returns.
They do not discard unknown bytes from the comparison. Simply moving allocation
after Lock would change that existing controlled contract.

The request-driven shared implementation therefore needs an explicit own working
storage input distinct from future device replies. The legacy adapter must seed
only the existing declared `.input` backing/counts, never `.first`, `.second`,
`.temporary`, final globals or any expected record. Preserve those input regions
through early failure and compare them completely. An actual service may create
new lease-owned regions when its outputs become available; their prior contents
and masks must have a declared origin. Do not invent live allocation contents,
confuse a synthetic32-bit token with a host pointer, or discard prior storage.

Keep native temporary/format/descriptor computation in the shared loader. The
audio service receives a copy request containing the exact consumed Native PCM
slice and lease identity, performs external buffer work outside the transaction,
then records its actual completion once. Native result records remain value
snapshots of the corresponding owned bytes; they must not cause a second physical
copy when a committed batch is inspected or delivered. A pure copy acknowledgement
is distinct from an invented HRESULT. Validate support and spans before service;
an exception after beginService retains owners and becomes indeterminate.

The historical MENU_SOUND_STARTUP/WINMAIN_STARTUP/STARTUP_OUTPUT prose requires
staged effects until commit. Preserve those documents and their tests. The newer
APPLICATION_OBSERVED_STARTUP implementation refines the application boundary:
Core consumes a staged value cursor, unwinds on a missing response, and service
runs outside `resume`; fulfilled receipts survive a later Core rollback. The
historical no-host-IO-inside-Core rule remains in force. The new exchange does
not promise to undo a window, sound, file or buffer effect after physical service.
Existing `OriginalRequestExchange` identity, begin/answer/fail/cancel and retained
resources should be reused; no second queue/execution framework is needed.

## Finite next implementation and comparison plan

Implement a request-driven shared sound/WAV child and connect it through the
whole startup path. Preserve aggregate callers as adapters to that common child.
Sound requests cover create/cooperative/message. WAV device requests cover
create/Lock/Restore/copy/Unlock and their diagnostic replies, with exact call
bindings and masked Native payloads. File/RIFF controls and Native backing remain
explicit separate inputs in this increment; live MMIO/file handling remains open.
This scope removes the audio result dependency, without claiming all startup IO.

Keep old operation encoding available for the existing prepared path. The observed
path needs actual per-call reply operations; the bridge must emit those once and
avoid appending the observer's aggregate as a second operation. Full comparison
must check every request, actual reply and source event position. If a comparison
projects the old aggregate, define and review that projection before execution;
never drop an unmatched event, expected byte or mask to pass a candidate.

Before a build, freeze one exact clone of this candidate, a patch, method list,
per-method bounds and source/runner pins. Proposed change families are the common
MenuSoundStartup/WaveLoader, their InputStartup/WinMain consumers, startup request/
response and bridge/prepared platform. Music algorithm and generic exchange stay
unchanged. Any new files or reference injection entry must be explicitly listed
in that implementation plan; a list of families is not permission for broad edits.

Five new finite comparison groups are required:

1. All431 saved WAV cases and3/54 initial-sound caller loads through per-call
   replies, using an injected loader entry while retaining every existing source
   comparison. Check both saved early-return backing and actual per-call payloads.
2. All122 menu-sound cases through the new child:112 returned segments and10
   separately rejected Create continuations, all590 recorded load results and
   all source events/global stores/bytes/masks. Never report122 whole matches.
3. All35 whole WinMain cases through one observed journal:23 complete chains,
   five original stops and seven provenance rejections. Preserve6325 compared
   events,119 completed Native WAVs and full state/music/graphics/operation checks.
4. Finite protocol/lease controls: wrong family, foreign/stale/duplicate permit,
   invalid/missing span, cancelled before begin, cancelled late reply, thrown
   service after begin, and retained resources after Host loss. None supplies
   a successful device result for a rejected or unknown operation.
5. Late fifth-wave and final-publication failures with retry: earlier work is
   served once, native globals/owners/publication roll back, actual receipts do
   not. Include absent device, positive1 create failure, ignored cooperative error,
   ordinary missing WAV, short read, buffer-lost retry and split/zero-length copy.

Retain all95 current methods plus the five existing menu-sound/WAV/input methods
not in that selection: two OriginalMenuSoundStartupTests, one OriginalWaveLoaderTests
and two OriginalInputStartupTests. The two whole WinMain methods are already in95.
Thus the proposed next selection is105 distinct methods:100 retained plus5 new.
The exact retained names and current source anchors are published in the audit;
the new five method names and resource/time bounds must be pinned before execution.
Music source is unchanged, so its two long standalone suites are not rerun solely
for this preflight. Existing whole-startup music/owner checks stay required.

If the legacy storage model cannot support distinct observed Lock outputs while
preserving declared backing, stop that candidate and diagnose the model. Do not
weaken full-byte comparison or synthesize outputs from a future expected state.
Changing a reference injection/comparison adapter requires an explicit review gap
and preserved old entry/checks; author checks do not become independent review.

## Preservation and open gates

Preparation49981 completed0 in9.821s. Root1034/prior2257/base2278 memberships,
bytes and metadata plus55 source pins were verified. The additional direct
prepared-platform dependency was pinned before reading, for28 Native files total.
No fixture was decoded and no new source/native/device execution occurred.
The final publisher separately verifies consulted pins, anchors, retained method
membership, process absence and a complete PAX archive before this audit closes.

Windows setup remains on the same approved installer behind the locked host.
No blind guest input, unlock, restart, permission or safety-setting change was
attempted. Existing incidents remain open; source59727 is terminal34Objects,
not a137-Object whole return. Actual sound, music codec/latency, Windows font/
cursor/device, root promotion, independent review, clean-Mac, complete match/game
remain open. NTSDApp stays Practice; EXE envelope was not recalculated.
