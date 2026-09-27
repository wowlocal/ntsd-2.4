# Native audio consumer and its remaining callers

2026-09-27. Static preflight after the [all105 startup-audio candidate](APPLICATION_STARTUP_AUDIO_CORRECTION1.md).
The next implementable step is a Native PCM-buffer owner and startup service,
with actual AVAudioPCMBuffer readback and bounded offline transport checks.
Menu/gameplay scheduling, WMA music and physical output remain separate open
dependencies. This advances sound in the complete Naruto/Sasuke District match;
it does not establish a playable match or audible equivalence.

The [plan](APPLICATION_MAC_AUDIO_PREFLIGHT_PLAN.md),
[publication](../evidence/application-mac-audio-preflight.json),
[static anchors](../evidence/application-mac-audio-preflight-observations.json),
[input inventory](../evidence/application-mac-audio-preflight-wav-inputs.json) and
[next comparison](../evidence/application-mac-audio-preflight-next-comparison.json)
refer to the2281-file candidate whose manifest is
7b609b8c4f61f1ec6d3903c84239478f84dba89f9820d2e3182fac262ef6a4ea.
Root Native remains older and unpromoted.38 Native files,17 study/publication
documents and5 installed AVFAudio SDK headers are pinned;79 anchor patterns
identify the actual call sites. Author inspection is not independent review.

## Original assets and ownership

All409 WAV paths match the existing original-source SHA/length entries:
15412062 file bytes,23 distinct format tuples and18 distinct rates.378 files are
16-bit mono,21 are8-bit mono and10 are16-bit stereo. Every file is PCM, its first
chunk is fmt, its data length is block-aligned and its rate/alignment arithmetic
is consistent. Rates are10000,10989,11025,11300,16000,18000,20000,20200,21000,
22000,22050,22100,23600,32000,38400,40000,44000 and44100Hz. Do not round them to
a conventional rate or choose a smaller supported subset silently.

These are static source-input facts, not MMIO/device observations. The inventory
retains raw format bytes and the18 bytes read by the existing loader, including
the next header bytes when fmt is16 bytes long. The recovered loader overwrites
cbSize with the destination's low word; that record stays exact. A PCM consumer
may ignore this field as documented by Microsoft; it must not rewrite the source
record. [WAVEFORMATEX](https://learn.microsoft.com/en-us/windows/win32/api/mmeapi/ns-mmeapi-waveformatex).

Inspector1 hit its256-header limit at data\\heart.wav after the data chunk.
Its terminal error is retained. The [declared amendment](APPLICATION_MAC_AUDIO_PREFLIGHT_AMENDMENT.md)
stops inspector2 at the first data chunk, matching the existing loader's search
boundary. All409 files remain included and completely hashed;400 have subsequent
RIFF bytes left uninterpreted. Inspector2 passed without modifying source or
expected bytes. This is an audit-limit correction, not a source fault or a
comparator mismatch. Both producers and jobs remain in the archive.

## Caller map

| Boundary | Current owner and actual consumer | Missing Native connection |
| --- | --- | --- |
| WinMain device and five menu WAVs | StartupAudio carries device/output replies, per-Lock regions, raw copy bytes and masks through the retained startup exchange. WaveLoader owns descriptor/format/temporary records; WinMain stores returned tokens. | Implement the real Native PCM owner and service for these requests. Initial storage and later Lock outputs stay distinct. |
| Eighteen common WAVs | InitialSoundLoading accepts the per-call factory. InitialLoadingCommon omits that argument; ApplicationLoadingSession still supplies aggregate waves. | Thread the existing request path through this caller and its retained journal. The leaf extension alone did not connect common loading. |
| Registered catalog WAVs | RegisteredSoundLoading owns buffers by registration index; CatalogSession calls its legacy aggregate loader, then volume callback, then path/count cache commit. | Add per-call WAV/payload service here. Preserve400 buffer registrations/365 paths and overlap-sensitive cache writes; never deduplicate resources by filename. |
| First-menu sound commands | MenuSession emits soundMethod with responses.sound. Its frontProvider covers graphics, not this case; MenuGraphicsRequest does not accept a soundMethod front reply. | Add a typed sound-method branch to the same ordered iteration journal before performing playback. Merely extending the graphics service cannot receive these calls. |
| Loaded-menu, launch and gameplay sound | LoadedMenu/MatchLaunch buffer effects; GameplaySession verifies tokens against startup/common/catalog owners, then returns outputInput.methodResult. QueuedSound computes exact pan/volume and Stop→SetCurrentPosition→Play. | Supply per-call replies outside the Core attempt, sharing the same PCM owner and command order. Preserve400 catalog then80 builtin traversal, right-before-left reads and ignored HRESULTs. |
| Music graph/control | Startup and LoadedMenu have per-call music replies; MusicPlayback owns allocations and recovered release/create/query/render/volume/run order. MatchLaunch calls the common music path. | A real file/codec/player and retained graph/interface identities are still absent. WMA decode, code-page conversion, errors, logging and endpoint timing remain open. |
| Music notifications | GraphEvents drains supplied replies until exact E_ABORT, keeps live local outputs, seeks and frees event parameters in source order. | Connect an actual completed-track event producer and the current window/graph owner. Native player completion is not by itself proof of the original notification timing. |

Earlier QUEUED_SOUND/GRAPH_EVENTS and application comments require buffered
external effects. The newer retained exchange refines this: Core unwinds before
service begins; a fulfilled receipt retains its resource and reply across retries.
Core rollback does not undo already served IO and must not submit it again.
Do not add host IO to the existing callbacks merely because they are named Request.
Extending music or playback still requires their own ordered service contract.

Older MUSIC_PLAYBACK prose saying match music selection is unjoined is superseded
for the recovered caller by MATCH_LAUNCH and OriginalApplicationMatchLaunchSession.
It remains true that there is no verified physical codec/music output. The old
source cases, disabled-music historical branches and failures remain unchanged.

## Chosen Native implementation boundary

Create one MainActor PCM backend using OriginalMacResourceIdentityPool, plus a
startup service analogous to OriginalMacBitmapService. Retain device, buffer and
Lock-region owners independently of logical Core rollback. Tokens must neither
encode source addresses nor expose host pointers; identities are not recycled.
Preflight request shape/ownership before beginService. After beginService, retain
resources and report an indeterminate failure if work throws; do not manufacture
a Windows HRESULT or repeat physical mutations after a lost/late response.

The buffer keeps original interleaved bytes/masks and a separately owned
AVAudioPCMBuffer. Allocate from the requested descriptor and decoded PCM format,
accept all23 original tuples and preserve their exact rate/channel order. Whole
offset-zero Lock exposes its own storage; copy writes the actual supplied payload.
Do not infer zero backing. Convert only fully known samples; an incomplete mask
must leave an explicit unsupported transport boundary and retained raw storage.
Unknown format/device behavior is not an original successful return.

For the Native representation, map unsigned8-bit samples to Float32(sample−128)/128
and signed little-endian16-bit samples to Float32(sample)/32768, retaining each
channel. This is an exact representation choice, not recovered Windows DSP
rounding. [Microsoft PCM packing](https://learn.microsoft.com/en-us/windows/win32/multimedia/devices-and-data-types).
Compare every resulting sample with an independent calculation from the original
input payload, while the existing source-byte/mask comparisons remain unchanged.

Use AVAudioEngine manual rendering only for bounded transport checks on these own
buffers, at each original format's rate and channels. Enable it before accessing
mixer/input/output nodes, as the pinned SDK requires. Record render status and
actual frameLength; no unreturned samples become known silence. No physical
output, microphone or resampling equivalence is implied. This is supported by
the [Apple engine API](https://developer.apple.com/documentation/avfaudio/avaudioengine)
and the five pinned SDK headers, not by a new original execution.

DeviceCreate success in this step means the Native PCM service has an owner; it
does not assert a physical endpoint was opened. Cooperative-level handling must
validate the current window owner and record the native policy explicitly.
Diagnostics need an explicit consumer. Unsupported requests fail visibly before
claim where possible; ordinary original failures remain in the retained corpus.
The first actual consumer is whole WinMain/five menu loads. The next consumers
are common/catalog loading and the ordered menu/gameplay sound requests above.

Do not map DirectSound pan directly to Apple pan or copy Practice gain/voice caps.
DirectSound pan attenuates one channel while preserving the other, cumulatively
with volume; Apple exposes a different parameter range without establishing the
same law. [SetPan](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ee418148(v=vs.85)),
[SetVolume](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ee418150(v=vs.85)).
Exact invalid-range retention, device failures, gain rounding, mixed-rate output,
simultaneous sounds and latency need separate evidence. Do not mute music to
bypass its open backend, synthesize graph completion or normalize all errors.

## Finite next comparison

Preserve all105 current selected methods; add the10 existing queued-sound,
catalog-sound, music and graph-notification methods listed in the pinned proposal.
Propose five new groups, for120 methods total:

1. All409 original WAVs through own buffers, raw bytes/masks, all samples/rates,
   separate handles for repeated paths and no future response import.
2. Whole observed startup with the five own menu buffers and retained surrounding
   dependencies. Distinguish this Native composition check from the unchanged
   controlled source WinMain comparisons; do not rewrite source tokens/expected.
3. Late load/publication retries, owner lifetimes and exactly-once service work.
4. Request families, foreign/stale/duplicate/cancelled permits, bad descriptor/
   format/extent, unknown masks and preflight-versus-indeterminate failures.
5. Offline AVAudioEngine transport for one independently selected original input
   per23 format tuple, with source-derived samples and explicit status/length.

Freeze actual new method names, resource/time bounds, changes and selection in
the implementation plan before building an exact candidate clone. Reuse the
existing105-capable runner and package/archive verifiers; no new test framework
or original capture. The implementation gate, root promotion and independent
review remain open until their own checks occur. A failed transport case is a
Native/platform discrepancy, not permission to loosen original masks or expected.

## Preservation and open gates

Publication verifies the previous all105 queue and terminal/absent producer jobs,
root1034/prior2257/base2281/source55, consulted files and original409 WAVs. Archive
membership, bytes, modes and nanosecond mtimes are a separate gate; terminal job
and closing storage are recorded in the publication/close receipts. No Native,
original, Windows or audio API executed in this preflight; no EXE envelope changed.

Host IORegistry still reports locked. The same Windows installer can resume when
observable, with all existing approvals retained. CrossOver remains available.
Source59727 remains terminal after34Objects, not full137. Actual audio, cursor101
unknown pixels/fonts, Windows/device comparison, review, root/app integration,
clean-Mac/full match/full game and all recorded safety incidents remain open.
