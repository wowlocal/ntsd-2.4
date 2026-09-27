# Own Native PCM startup candidate: test compilation failure retained

2026-09-27. The five-path implementation from
[APPLICATION_MAC_AUDIO_PLAN](APPLICATION_MAC_AUDIO_PLAN.md) exists in an exact
2284-file candidate. Core and the new Mac module compile, but the new test file
has two missing optional unwraps. No selected method ran; package/comparison and
actual audio acceptance remain open. The preceding [all105 result](APPLICATION_STARTUP_AUDIO_CORRECTION1.md)
is unchanged. This is progress toward sound ownership in the native match, not a
working or validated audio port.

## Implementation and provenance

Base: the frozen2281-file startup-audio-correction1 candidate, manifest
7b609b8c4f61f1ec6d3903c84239478f84dba89f9820d2e3182fac262ef6a4ea.
New candidate manifest:
a2cbdd3e3465631db8507cb320a65db492bb1a6924c482387437283433bd9706.
Root Native is not promoted. Existing test bodies, Reference code, original
fixtures/expected bytes/masks and old Mac files remain unchanged.

Core's new OriginalWaveFileInput contains only file/MMIO controls and prior
storage. PreparedStartupPlatform binds index/path/destination to the actual device
reply when waveInput is called. Fixed-binding and legacy preparation remain;
mixed preparations reject without consuming a row. This removes the dependency
on predicting the Native device token before its creation.

OriginalMacAudioBackend uses the shared MainActor identity pool and current
window lease. It owns device/buffer/Lock resources, raw bytes/masks and real
AVAudioPCMBuffer allocations. Request preflight is separate from single-use,
generation-bound execution. Copy preserves raw bytes and masks; fully known PCM
is converted with explicit8/16-bit representation arithmetic. Unknown samples
prevent PCM exposure. Exported PCM snapshots use separate storage. The128MiB
budget is a Native resource limit, not an original game/voice rule.

OriginalMacAudioService serves typed sound/WAV requests after Core unwinds, begins
the exchange permit before mutations and retains owners on success or failure.
Already fulfilled allocations/copies are not repeated on a later Core retry.
DeviceCreate represents a Native storage owner; it does not open an endpoint.
Cooperative success binds the current Native window. Diagnostic messages require
an explicit callback; unsupported inputs are not manufactured Windows HRESULTs.

Five new test methods cover the409 source-file inputs, whole own WinMain with
five menu buffers and Native window/display, late retries/lifetimes, protocol/
unsupported boundaries and23-format same-rate offline transport. Source files are
obtained only from the immutable corpus source hashes; expected cases/after-state
are absent from the decoder's input type.115 retained methods plus these5 make
the frozen120 selection. None has executed in this round.

## Saved validation result

Preparation59464 completed0/absent in14.503966625s: exact APFS clone, five-file
patch, Swift syntax parse and120 method/limit/runner controls pass. Candidate
membership is206 Core/61 Reference/11 Mac/289 test sources,385 fixture files and
1301 runtime files. The parse is not a typecheck.

Build60564 completed1/absent in154.532980084s with no resource guard or signal;
the runner reports no remaining process group or observed child. Sampled peak
RSS3099279360. Compiler errors in the new test:

- line126 accesses first through optional OriginalWaveStorage without unwrapping;
- line148 passes optional package.file output where nonoptional bytes are required.

The fix is to require both values with throwing XCTUnwrap, preserving a missing
value as a failed check. Do not substitute empty storage/file data or change any
Core/backend/reference/expected value. Both exact diagnostics and the complete
log are pinned in the task's failure-diagnosis1.json and build1.log.

A separate one-shot closure-preparation command initially indexed the absent
optional guardReason job key. It failed before writing a diagnosis or copying/
running the finalizer; a subsequent shell invocation therefore found no finalizer
file. The exact errors are retained in closure-preparation-failure1.json. The
corrected preparation uses get; the build job and finalizer producer are unchanged.
This was an orchestration error, not a second Native failure or a source fault.

[Publication](../evidence/application-mac-audio.json) and
[close receipt](../evidence/application-mac-audio-close.json) distinguish the failed
build, unstarted120 comparisons, copied partial resources and archive checks.
The five-file [patch](../evidence/application-mac-audio.patch) round-trips exactly.
The finalizer verifies root1034/prior2257/base2281/source55, full candidate/release
artifact membership and metadata archive bytes/modes/nanosecond mtimes. Its exact
terminal identity and counts are recorded by the documentation receipt; exit0
there does not turn this candidate into an accepted Native implementation.

## Next and remaining gates

Make a separate exact-clone correction changing only the two optional assertions,
then a fresh build/package check and the same120 methods/limits. Preserve this
candidate, templates, errors, plan and all earlier source evidence. No capture or
completed job is restarted. Commit this retained increment before correction.

Independent review is unavailable/open. Common/catalog request propagation,
ordered runtime sound commands, WMA/music notifications, physical endpoint,
pan/volume/mixing/resampling/latency, Windows and clean-Mac checks remain open.
Host is locked; installer approvals persist and CrossOver remains available.
Source59727 terminal34Objects is not full137. No original/Windows/audio API
executed, no root promotion, EXE envelope update, full match/game acceptance or
safety-incident resolution is claimed. NTSDApp remains Practice.
