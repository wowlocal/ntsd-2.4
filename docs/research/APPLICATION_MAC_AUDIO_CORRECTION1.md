# Native PCM candidate: package passes, test snapshot lifetime fails

2026-09-27. The [two-assertion correction](APPLICATION_MAC_AUDIO_CORRECTION1_PLAN.md)
builds and passes the separate package check. The first selected method crashes
while reading a pointer from a temporary test snapshot. Zero methods pass and
119 remain unstarted. This does not establish PCM comparison or device fidelity;
the preceding [all105 result](APPLICATION_STARTUP_AUDIO_CORRECTION1.md) is unchanged.

## Candidate and checks

The exact2284-file clone has manifest
414ac467dcbfd1da3a4065918f1436043a186f1f4b74d08f4cbde64949725894.
Only two assertions in OriginalMacAudioBackendTests require optional values with
XCTUnwrap. Core, Reference, Mac implementation, other tests and all expected
bytes/masks remain identical to the [preserved first round](APPLICATION_MAC_AUDIO.md).
The same120 methods and limits are frozen; no source capture was repeated.

Preparation77247 completed0/absent in13.412055542s. Build78660 completed0/absent
in310.094898125s, sampled peak RSS7012057088, with no guard, signal or remaining
observed child. Package verification checks206 Core/61 Reference/11 Mac/289 test
sources,385 fixtures/1301 runtime files and the68851192-byte test binary.

Queue97025 stops after test-01, OriginalMacAudioBackendTests/
testOriginalWAVsThroughOwnedBuffers. XCTest97182 exits-11 in2.190000291s;
the log contains the method start but no completion. Its report records
EXC_BAD_ACCESS/SIGSEGV at2026-09-27 04:47:50.2769+0300. Binary UUID
8213c4aa-ef88-3da0-a9b8-95e7e81485ae matches the crash image. Queue and child
are terminal/absent. No runner resource guard or termination signal was issued.

## Diagnosis and preserved evidence

The crash is at test line117 in check(_:_:_:), after its snapshot mutation.
That assertion accesses b.pcmSnapshot(token).floatChannelData directly, allowing
the temporary AVAudioPCMBuffer owner to be released before its pointer is read.
The saved release binary makes this concrete: pcmSnapshot call0xe625ec,
floatChannelData0xe625fc, objc_release0xe62608, then return only the pointer;
the calling assertion dereferences it at0xe625b4/0xe625b8. The crash PC is0xe625b8.
This is a test-owner lifetime defect; no completed409-file comparison, source
fault or successful backend validation is inferred from partial execution.

The full crash report stays in the task archive. The public
[failure record](../evidence/application-mac-audio-correction1-failure.json)
contains the relevant frames, exact exception, UUID and pinned disassembly.
The existing stop-on-first-failure queue leaves119 methods unstarted.

An additional read-only precheck indexed an unavailable diskutil key,
ReadOnlyVolume, and raised KeyError. It changed no data. The following package
verifier still ran and passed because that shell did not stop on the preceding
error. A corrected observation verified WritableVolume/WritableMedia, UUID,
APFS and both reserves before testing. The exact error is archived separately.
The parent queue wrapper's CalledProcessError reports the queue's expected
nonzero exit; it is not a second execution or Native failure.

[Publication](../evidence/application-mac-audio-correction1.json),
[close receipt](../evidence/application-mac-audio-correction1-close.json) and
the exact one-file [patch](../evidence/application-mac-audio-correction1.patch)
retain separate build/package/comparison/archive gates. The finalizer verifies
root1034/prior2257/base2284/source55, patch round-trip, artifact membership and
archive bytes/modes/nanosecond mtimes. Its final counts and terminal identity
are pinned by the documentation receipt. No root Native files are promoted.

## Next boundary

Make correction2 as a separate exact clone. Retain each new test PCM owner with
withExtendedLifetime while accessing its raw channel pointers, including the
independence assertion and offline output reads. Keep the actual checks and
expected sample arrays unchanged. Fresh build/package and the same120 methods
follow; do not rerun or edit this frozen candidate. Commit this saved increment
before starting correction2. Independent review remains unavailable/open.

Common/catalog request propagation, ordered runtime commands, WMA/music graph,
endpoint output, pan/volume/mixing/resampling/latency, Windows font/cursor/device,
root integration, clean-Mac, full match/game and safety incidents remain open.
The host is locked; installer approvals persist. Source59727 terminal34Objects
does not cover137. No original execution, EXE-envelope update or game acceptance
is claimed; NTSDApp remains Practice.
