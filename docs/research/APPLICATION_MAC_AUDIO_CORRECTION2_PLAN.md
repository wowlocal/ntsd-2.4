# Native PCM candidate: retain test buffer owners during pointer reads

2026-09-27, HEAD e6b3dbad1370659f6511433044f18aeb5b364e57.
Continue APPLICATION_MAC_AUDIO_PLAN and correction1 without reducing acceptance.
Correction1 is frozen: build78660/package passed; first XCTest97182 exited-11,
0 passed/119 unstarted. Its matching crash UUID, source line117 and generated
objc_release before pointer dereference establish a test snapshot lifetime bug.
Finalizer527 completed0/absent;4986-file/162-member archives verify. Preserve the
crash, original compile failure and separate orchestration errors verbatim.

Clone all2284 files from correction1, manifest
414ac467dcbfd1da3a4065918f1436043a186f1f4b74d08f4cbde64949725894,
using APFS clonefile with distinct inodes. Change only the new test file:
withExtendedLifetime(pcm) encloses its sample reads and snapshot mutation;
retain the second snapshot explicitly through its independent sample read;
withExtendedLifetime(output) encloses offline rendered sample reads. These
closures keep raw channel pointers within the lifetime of their actual owners.
Preserve sample arithmetic, exact arrays, counts, assertions, masks, method order
and120 selected methods/limits. No Core/Reference/Mac or fixture change.

Perform one fresh release build-tests --jobs2,3600s/12GiB RSS, then the existing
package checker and frozen120-method queue. New5 methods600s/8GiB, extra10
historical methods900s/10GiB, all105 earlier limits unchanged; queue7200s stops
on first nonpass. Retain all result predicates and process identity checks.
Only task paths change in existing runner/verifier. This is correction round2
of the declared maximum3; any further failure requires its own saved diagnosis.

No original/Unicorn/Windows/historical capture execution. Actual AVAudioPCMBuffer
storage is exercised; AVAudioEngine is offline at the original rates/channels
only in its selected test. No endpoint/microphone. Whole startup uses declared
file/MMIO and non-audio responses. Partial tests do not establish full comparison.

Task application-mac-audio-correction2-20260927 uses writable X5 APFS UUID
3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548. Require131GiB external/9GiB internal before
preparation; retain121GiB external (40+17 source+64 VM) and6GiB internal.8GiB
allowance,6GiB observed-decrease stop,150GiB logical cap, root additions4MiB,
metadata32MiB. Preparation1800s/build3600s/queue7200s/finalizer3600s. No deletion,
reserve change or T7 IO; previous jobs/archives remain unchanged.

Mutable only this task/alias, lifetime correction helper/preparation/finalizer,
plan/study/evidence and own navigation. Root1034/prior2257/base2284/source55,
original templates, archive instructions, earlier plans/errors and refusal
records remain protected. Verify actual process identities before action; no
restart for silence. Reuse patch round-trip/full-artifact/PAX byte/mode/ns-mtime
verification. Commit the checked increment before the next independent task.

Independent reviewer unavailable; author review is not independent. Root
promotion, common/catalog propagation, runtime playback/WMA/graph, pan/volume/
mixing/resampling/latency, actual Windows/device, font/cursor, clean-Mac and full
match/game remain open. Host locked; installer approvals persist. Source59727
terminal34Objects is not137. No EXE-envelope update or incident resolution.
