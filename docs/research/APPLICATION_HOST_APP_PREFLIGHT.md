# Host app preflight — delivery mapped, production catalog inputs missing

2026-09-26. Bounded static analysis is complete under the
[plan](APPLICATION_HOST_APP_PREFLIGHT_PLAN.md). The next eligible implementation
is a regular original catalog/media input package and Native reader, replacing
the full catalog's fixture-supplied **input bytes** while preserving every
reference expectation and explicit device-response boundary. This is a necessary
shipping dependency of the current host, not acceptance of a renderer or match.
[Publication](../evidence/application-host-app-preflight.json),
[interface inventory](../evidence/application-host-app-preflight-observations.json),
[preservation receipt](../evidence/application-host-app-preflight-close.json).

The prior goal turn was progress: all69 host methods and package/archive gates
closed. This task starts from that unchanged1040-file candidate, not root1034 or
a HEAD-only tree. No original, Native test, fixture decoder or device executes.
The present findings are source-code observations and design inferences, not a
new D comparison or W observation. Independent contract review is unavailable
and stays open. EXE envelope was not recalculated.

## Current consumer and ordered work

NTSDApp's five Swift files still launch Melee/Movement practice or the inspector.
They contain no OriginalApplicationHostSession/takeCommitted consumer. Practice
key handling suppresses repeat and converts held macOS key codes directly into
fighter inputs; focus loss clears them and pauses its own timer. Its renderer
uses scene nodes, NSImage conversion and a blanket black-to-alpha pass. Audio
creates AVAudioPlayer instances, caps32 players and assigns0.65 volume. These are
existing practice choices, not recovered defaults for the new application path.
The shared original timer, WndProc, draw requests and sound methods must remain
the producers of game decisions. AppKit/SpriteKit/AVFoundation imports alone
establish no faithful event, raster or audio behavior.

The host's three batch variants have these actual producers:

| Variant | Authoritative chronological stream | Graphics association and lifetime |
| --- | --- | --- |
| startup | Bootstrap.Started.operations, produced by StartupBridge | Each `.window` call appends one resolved command. File/resource observations and owned allocations are not repeated host IO. The ordinary panel branch does not establish all panel-device behavior. |
| iteration | MenuSession.Committed.effects, appended by its `emit` | `Graphics.consume` produces one command for surface/lifecycle/bitmap/blit/fill/release/present/GetDC/graphics/startupGraphics effects, otherwise nil. Preserve effect position; graphics is an overlapping view. |
| loaded | LoadedCommit.operations: current prefix, actual child operations, then appended outer time/Sleep | First loading nests Loading → Catalog → Pool → Input → LoadedMenu `.preceding` wrappers. Each wrapper holds one operation, not another execution. Cached cycles start only with current PendingLoading.stagedEffects/Graphics; the historical pool entry supplies owners, not another loading prefix. |

Loaded menu emits graphics through the same `consume` call and appends the
corresponding `.menu(effect)` exactly once. Actual front surface methods route
there; non-surface audio/query/volume/shell/post/critical-section requests remain
`.front`. Recording callbacks append open/write/close and other declared terminal
operations. Helper/diagnostic events are deliberately omitted where their shared
children already emitted terminal work. The inventory records all19 startup,
17 iteration,15 loaded,5 input,3 pool,8 catalog and2 loading enum cases; these are
interface counts, not instruction coverage or additional test results.

A future single delivery view can associate commands by these exact producer
rules and verify full exhaustion, payloads, masks and resource generations.
It must not concatenate graphics after effects, deliver both lists, sort by
resource, strip failed requests, infer a NULL rectangle or resolve an old command
using only the latest resource registry. No new flattened runtime view is
implemented here. Its comparison would need independent source/event order,
not an expected list made by calling the proposed flattener itself.

## Owner and response boundary

Host publication is one in-process commit; `takeCommitted` destructively removes
the oldest batch. It does not acknowledge device execution or recover a partially
delivered batch. Host can advance while previous batches remain queued. Startup
and ordinary iteration batches do not themselves retain the entire corresponding
Application/Platform snapshot; a late `host.snapshot` can belong to a later commit.
LoadedCommit does retain its PendingReturn and Native child owners. A shipping
consumer therefore needs an explicit retained resource context at each commit,
with a defined lifetime through delayed delivery, rather than current-state lookup.

Graphics commands already keep generation-qualified bindings and source-color
snapshots. They explicitly do not implement a framebuffer: palette realization,
offscreen format, bitmap conversion, clipper, GDI font/codepage/DPI, device lease
validity and initial pixels remain open. The accepted DIB decoder keeps RLE holes
unknown and differs from ImageIO at documented written pixels. Neither Practice
NSImage output nor zero-valued unknown pixels is a replacement reference.

WAV operations demonstrate a concrete missing payload edge. WaveEvent.copy holds
region/count arguments, not PCM bytes. OriginalWaveLoadResult.first/second own the
copied bytes and masks; StartupPlatform.wave supplies logical identities and
numeric controls. Subsequent catalog/common/startup sound owners remain reachable
through the loading chain. The backend must retain and bind those actual Native
owners when preparing playback; re-opening a WAV for every copy or sound event
would invent different stream, copy and buffer behavior. Music allocations and
surface/DC generations have the analogous lifetime requirement. Unknown sound
bytes and failed release requests do not become initialized data or destruction.

Device replies are needed **before** commit. The existing staged-copy/provider
contract forbids live IO inside Core callbacks and requires independent mutable
queue/allocation/reply ownership. Returning0 from a future backend after merely
queueing an operation does not establish the result already consumed by Core.
Actual reservations/observations, their cancellation and externally visible
failures need a separate prepared-backend contract. A Swift rollback cannot undo
submitted drawing, file writes, network sends or audio. No universal post-commit
rollback or automatic replay policy is inferred here.

## Complete public input inventory

The machine inventory covers all22 WinMainStartupPlatform members plus
stagedCopy exactly once. Its nine groups distinguish:

| Group | Members and current ownership | Missing production boundary |
| --- | --- | --- |
| Copy/validation | stagedCopy, observe; transactional platform and validation hooks | Independent mutable storage; no device delivery from observers |
| Immutable files/images | file, panelBitmap; packaged original bytes and Bitmap metadata | Overlay/error provenance and the missing full content producer |
| Panel stream | panelIO, writePanel, closePanel; own parser and buffered journal | Stream identity, actual reads/results and write/close preparation |
| Allocations | allocatePanel, allocateCalendar; Native records and logical addresses | Reservations, backing provenance, aliases, cancellation; no source-private ABI import |
| Clock/calendar | milliseconds, filetime, environmentTZ, timezone, convertZoneName | Actual time/zone/codepage inputs; no saved clock or date defaults |
| Window/runtime | initializeCriticalSection, initializeCOM, window, panelDevice, cursor | Backend replies, resource/errors and callback order; opaque backing remains explicit |
| Audio | sound, music, wave; owned music and PCM results | Actual mixer/media/device contract and buffer leases |
| Device input | joystick; recovered startup request model | Real capabilities/capture and event delivery |

The same receipt inventories nine later provider groups: Host.Inputs,
common loading, catalog controls, pool/UI, loaded input, loaded menu, match launch,
gameplay/paused body and the outer time/Sleep tail. Their callbacks and complete
input-name sets are pinned to the current source. Existing owners already supply
RNG, current catalog/Actors, bitmap metadata, file-stream computation, aliases,
installed library state and the writer. Providers must not recompute these from
expected snapshots or replace them with direct Practice fighter input.

For message acquisition, empty/nonempty PeekMessage and exact-zero GetMessage
are recovered Core decisions. MSG is28 bytes with a retained defined mask; a
message iteration skips the timer. macOS key layout/repeat/focus/mouse/joystick
translation, synchronous callbacks, clock origin and latency remain actual host
contracts. The 53-bit caller precision remains explicitly supplied at the
initialized input boundary; WinMain alone does not establish its earlier origin.

## Shipping input gap and next implementation

The five current ordinary packages contain45/18/10/11/13 payload entries for
Startup/CommonSounds/LoadingInterface/CharacterMenu/MatchArenas respectively,
plus five manifests:102 files already verified by the completed host task.
They provide original immutable bytes and strict bundle lookup and should remain
unchanged. `package_assets.py` additionally copies BMP/WAV assets and extracted
interface images; `build-native.sh` installs imported game.json. Neither script
installs the raw DAT catalog inputs or WMA files for the recovered full loader.

The test-only CatalogFullReference instead inflates original input bytes from
comparison corpora:156 catalog/child files plus365 WAV sources, and669 image
inputs (665 BMP files/four embedded DIBs). Its reference records/controls are
separate, but its file/image input dictionaries are still constructed in XCTest.
The accepted catalog-image study proves the format/ownership scope for those669
images; it did not create a production catalog package. All8 original WMA files
also lack a package route. A directory/stat inventory confirms their presence
in the baseline; this task neither reads/decompresses media nor claims decoding
or playback on macOS. WMA decode/output remains an audio dependency.

**Next finite candidate: OriginalCatalog input package and Native reader.**
Freeze an exact path/origin/length/SHA manifest from the existing accepted catalog
and image inventories and original distribution. Bind the521 file inputs,669
images and8 music files explicitly; count unique payloads separately when an
input appears in more than one role. Preserve case/path spellings, file headers,
embedded DIB origins, absence-versus-empty and every original byte. Raw encrypted
DAT must still pass through the existing recovered loader, not precomputed records.
Exclude executable/DLL code, test replies/expected state and generated temporary
files. Unknown names remain an explicit reader boundary, not successful empty data.

Use a fresh isolated candidate derived from the current1040 files. Reuse the
existing regular package/manifest reader and package_assets patterns. Supply
the catalog `Resources.files/bitmaps` from the new reader while keeping allocation,
file/device/error/time controls explicit. Keep the old fixture input producer
available as immutable comparison evidence; test both complete input maps for
equality before routing the existing full host/caller comparisons through the
production package. No source capture or rule/comparator change is needed for
this byte-provenance step. Native compilation, package copying and tests require
their own fixed memory/time/storage plan before execution; none occurred here.

Four finite new reader/consumer groups are required: exact complete source bytes/
origin/metadata; owned snapshots after source files disappear or change; missing,
corrupt, duplicate/conflicting, extra and non-regular package controls with no
partial publication; actual catalog/whole-host consumption on both existing
backings without expected-state input. Retain all69 methods and their full17/48/14
schedules, owners, masks and late rollback/retry. Verify the final app bundle's
regular payloads independently and prove its catalog reader runs without a
checkout, fixture directory or research volume. This artifact/read gate is not
a window/device or complete catalog-source acceptance gate.

This package closes an immediate standalone-data dependency without pretending
that an invented successful device response makes the host runnable. Subsequent
work must provide the retained ordered-delivery context and prepared backend
contracts described above, then connect actual AppKit input/presentation/audio.
Windows raster/callback/device evidence is still missing. The new package must
not be used to infer or conceal those results.

## Verification and remaining gates

Preparation40374 exited0 in5.032s. Root1034/current1040 memberships and bytes,
source55 and all selected protected inputs were verified. Queue90854 and
finalizer26386 remain terminal0/absent. Source59727 remains terminal at the saved
publication boundary after34 Objects; a full137 application return and saved
transport/provenance audit remain open. The previous reader nonpass and the
four preliminary read-only missing-path diagnostics are preserved separately.

The final preservation/archive receipt records consulted-file counts, exact
publication and archive hashes, time/storage limits and all terminal processes.
The current WORKFLOW/T7 amendment is pinned; its historical pre-T7 version stays
in the prior closed archive. No unrelated dirty Native or navigation bytes,
baseline resources, expected values, masks, incident records or immutable
instruction history changed. All original safety dependencies remain open.
Independent review, root promotion, live backend, installed Windows trajectory,
actual app/devices, clean-Mac validation, first complete match and full game are
not accepted by this preflight.
