# Native PCM storage and startup: retained snapshot owners

2026-09-27. This [second correction](APPLICATION_MAC_AUDIO_CORRECTION2_PLAN.md)
keeps test PCM owners alive while their raw channel pointers are used. All120
selected methods pass: the five new PCM/startup/lifetime/protocol/offline groups
and115 retained methods. The earlier crashes and compiler errors remain separate
failed candidates. Machine checks pass for the bounded Native storage and offline
transport contract; independent review, actual endpoint/Windows and shipping
integration remain open.

## Scope and provenance

The exact2284-file candidate derives from the frozen
[correction1](APPLICATION_MAC_AUDIO_CORRECTION1.md), whose first test crashed at a
pointer obtained from a released temporary AVAudioPCMBuffer. Its crash report,
matching image UUID, disassembly and119 unstarted methods remain immutable.
The new candidate manifest is
80ced805b198ebdc49068ca1c7e6068ccd7da41828d5c9053be0df04f16ce981.
This correction changes only OriginalMacAudioBackendTests.swift. All102 assertions,
sample arithmetic, expected arrays, source bytes/masks and the120 method names/
limits are retained. Core, Reference and Mac backend files are unchanged.

withExtendedLifetime encloses the first snapshot's sample reads and mutation,
the second independent snapshot's read, and offline output reads. The pinned
local Swift SDK interface implements it with deferred _fixLifetime after the
body. The lifetime fix does not replace unknown data with zeros, weaken sample
equality, import an expected after-state or alter original game behavior.

Preparation7877 completed0/absent in13.315668833s. Build8660 completed0/absent
in310.464647834s, sampled peak RSS6946308096, without a guard, signal or remaining
observed child. The fresh package checks206 Core/61 Reference/11 Mac/289 test
sources,385 fixture/1301 runtime files and the68851144-byte test binary.

Queue20414 completed0/absent in1075.075001792s: all120 selected methods have exact
passing XCTest completion, exit0, no guard/signals or remaining observed process.
Their process times sum to708.722345215s; sampled peak RSS7603634176. Zero RSS
for a short process means no sample, not known zero memory use.
The selection retains all105 previously checked methods and ten older
queued-sound/catalog/music/graph methods, plus the five new groups below.
This is a declared regression selection, not the entire repository's test suite.

## New comparisons

The file-input decoder reads only corpus source hashes/blobs, not expected cases
or after-state. All409 original WAV inputs pass own raw bytes/defined masks,
PCM sample conversion, format/rate/channel counts, ready/Lock state and exported
snapshot independence. Their payloads total15353018 bytes:23 format tuples and
18 rates. Reloading a path produces a separate410th buffer owner. Empty initial
storage and undefined a5-filled Lock storage stay distinct from copied PCM.

Whole own WinMain creates one Native window, four display resources, an actual
Native audio storage owner and five menu buffers through22 audio operations.
Prepared file inputs bind to the device returned at runtime. Other file/MMIO,
music/joystick and platform boundaries remain declared; this is Native
composition, not new actual Windows evidence. A late Core retry retains the
completed physical service receipts and does not duplicate those operations.

Protocol controls cover foreign/repeated/cancelled permits, stale/repeated/foreign
preparations, malformed descriptors/formats, unknown samples, explicit diagnostic
delivery, allocation-budget failure and mixed preparation rejection. Journal
resources survive their original backend scope and release with the journal.
Physical effects are retained across Core rollback; physical undo is not claimed.

AVAudioEngine manual offline rendering passes exact Float32 array equality for
one lexically selected source of each23 format tuples, totaling418363 frames.
Each output uses the original rate/channels, requires success and the requested
frame count. This establishes the bounded same-format offline transport only.
No audio endpoint or microphone was opened; hardware mixing, resampling, latency,
volume/pan and Windows device equivalence remain unverified.

## Preservation and remaining work

[Publication](../evidence/application-mac-audio-correction2.json),
[close receipt](../evidence/application-mac-audio-correction2-close.json) and the
one-file [patch](../evidence/application-mac-audio-correction2.patch) separate
build, package bytes, Native comparison and archive gates. The finalizer verifies
root1034/prior2257/base2284/source55, the exact patch round-trip and full artifact
membership/bytes/modes/nanosecond mtimes. Its terminal identity, counts and archive
hashes are pinned in the documentation receipt. Root Native is not promoted.
Finalizer54098 completed0/absent in111.876913958s. The artifact contains4986
regular files/213 directories/no links,11450203389 logical bytes, manifest
fb6cc9c26dd574eaabf3e24ba313738cb4f150cd51f57efc5c74cf71c2569f3d.
The515-member7628800-byte metadata archive has SHA-256
baaac3df03fde628c78e7cc6f21170d5458355bd05127ab042c0bd2188053722.
The task is frozen with142306541568 bytes free on X5,1232719872 observed decrease,
and the original121GiB combined reserve retained.

An optional author audit initially guessed an obsolete Swift interface path and
expected four textual pointer-property uses; actual before/after both contain
three. Those read-only command errors and the corrected102-assertion/three-owner
observation are retained separately. They caused no candidate edit, Native test
failure or restart. Author checks are not independent review.

UTM observation returned cgWindowNotFound; a read-only console-status query
confirmed the host remains locked. No guest input was sent. Installer approvals
persist. Source59727 terminal34Objects is not137. No original/Unicorn/Windows
capture is repeated, and no EXE-envelope update is made.

Root promotion and independent review remain open. The next consumer boundary
is propagation of the existing per-call WAV service into common/registered
catalog loading, preserving independent owners for repeated paths and the live
sound cache. Define its finite caller comparison before implementation; do not
infer it from this startup result. Runtime playback, WMA/music graph, real
device/input/font/cursor, clean-Mac and full match/game remain open. NTSDApp still
runs Practice, and this candidate is not a standalone accepted game.
