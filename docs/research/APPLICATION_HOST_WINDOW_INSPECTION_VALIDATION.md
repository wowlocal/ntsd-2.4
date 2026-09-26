# Host inspection correction — eight comparisons passed

The fresh build, package verification and all eight selected methods passed on
the unchanged 2247-file correction candidate. The post-handoff coordinator-to-Host
lock edge is removed in code, and the declared inspection/input controls pass.
This closes this bounded Native comparison, not independent contract review or
all possible thread schedules. The earlier possible cycle was a static finding,
not an observed old hang. Actual application/device integration remains open.

The [plan](APPLICATION_HOST_WINDOW_INSPECTION_VALIDATION_PLAN.md),
[implementation](APPLICATION_HOST_WINDOW_INSPECTION.md),
[publication](../evidence/application-host-window-inspection-validation.json) and
[closure](../evidence/application-host-window-inspection-validation-close.json)
retain the scope, exact inputs and separate gate results. Base HEAD is 379d266;
the candidate includes the actual accumulated inputs, not a HEAD-only checkout.
Candidate manifest SHA256 is
`3a3595560f2a8f82c637c356401cc946330eb6eec2f6f7cbda14dbdd4c9b1242`.

## Analysis and implementation boundary

Application/count inspection uses Host's own lock without holding the coordinator
lock. After successful handoff, coordinator platform copying rejects before Host
access; the returned Host still supplies independent copies. Before handoff, the
private Host retains the existing staged-copy and reentry contract. This preserves
one Host, committed state, reply receipts and resource lifetimes. Host, Bootstrap,
exchange and the recovered window/WinMain/input algorithms remain unchanged.

This validation changed no Native file, expectation, mask or comparator. The prior
28- and 82-method comparisons remain separate evidence. Their unmodified consumers
are not relabeled as newly exercised by this eight-method selection. Author source
analysis is not independent review; no separate reviewer was available.

## Actual build and comparison

Preparation 64523 finished with exit 0 in 12.906 seconds, checking all 2247 regular
clones by body, mode, nanosecond mtime, membership and distinct inodes. Build 71816
finished with exit 0 in 286.723 seconds; sampled process-tree peak was 6,425,821,184
bytes. The native-SwiftPM release build uses Swift 6.4 in Swift 5 language mode,
targets macOS 14, and enables testability with two build jobs.
Package verification checks 194 Core, 61 Reference and 275 test sources plus generated
accessors, fresh outputs and all 1686 packaged files: 385 fixtures and 1301 Core files.
The XCTest binary is 64,236,616 bytes, SHA256
`1a279ed61b32e4c696e6023d4a2a99c2acaa5055e562e22e0f0412993a40fcc1`.

All three new complete methods passed:

- Platform copying rejects on the coordinator while an actual input transaction
  holds the returned Host's lock. Direct Host copies remain independent, and the
  committed message, receipts and retained startup context compare.
- 32 whole key transactions include 16 Application readers and 16 count readers
  alongside exchange observation during the Host callback. All workers join.
  Full committed state/count, key effects, queue/reservations, publication sequence
  and retained earlier context compare. Semaphore waits are bounded at five seconds;
  this is a finite overlap check, not exhaustive scheduler coverage.
- Preparation failure, reentry, outstanding requests, cancellation, late response
  and indeterminate outcome preserve private inspection and committed values.
  A separate successful whole startup preserves the handoff inspection boundary.

All five unchanged whole-startup methods also passed. They retain the distinct
23 complete/5 original-stop/7 provenance outcomes, 6325 event and 119 WAV comparisons,
650 once-served window replies, six late rollback/retry sites, publication-copy and
cursor failures, permit/reentry/cancellation controls, actual key handoff and resource
lifetimes after coordinator destruction. The 35 outcomes are not 35 matches.

Queue 82338 finished with exit 0 at 2026-09-26T12:35:45.658600Z in 38.370 seconds.
All eight exact saved results have one passed named method, three one-test/zero-failure
summaries and a Selected-tests pass; no guard, signal or residual process is recorded.
The sum of child process times is 16.458 seconds, sampled peak 448,528,384 bytes.
Original per-method limits were retained; no source or passing comparison was rerun.

## Preservation and archives

Finalizer 84149 finished with exit 0 at 2026-09-26T12:37:07.473773Z in 59.486 seconds
and is absent. Preparation/build/queue and all observed child processes are also absent.
The finalizer reread exact results and verified root 1034, prior 2246, both current
2247-file copies, all 55 source pins and package contents. The task is frozen.

The regular APFS artifact archive contains 4902 files, 210 directories, no links and
11,384,656,951 logical bytes. Every body/mode/nsmtime/member and distinct clone inode
was checked. Its manifest SHA256 is
`a816bdeac3f73979ed6f97585305565af54c420b03f586c282059d1ab44f8878`.
The 60-member PAX metadata archive has 5,201,920 bytes, SHA256
`5294f0c6f609373790a6f703cee4c62e5879d3506172664d846b67d52b0ab648`;
all member names, bytes, modes and nanosecond mtimes were verified.

The inherited monitor/reap behavior and exact result predicate are unchanged.
The first unexecuted finalizer draft retained three inherited schema names; a
separately pinned finalize2 corrected those names and its own job/input/log paths.
Both drafts and adaptation records are archived. No result or acceptance condition
changed, and no failed build/test/finalizer execution occurred.

At closure X5 had 168,935,714,816 free bytes and the internal volume 58,846,834,688.
Observed external decrease was 1,161,117,696 bytes, within the 28 GiB allowance and
26 GiB stop threshold; 40/6 GiB reserves plus the 17 GiB source commitment remain.
The task alias is `build/research/application-host-window-inspection-validation-20260926/`.
T7 remains separately authorized; these APFS-dependent builds and clones stay on X5.

## Next application boundary

Implement the production startup platform consumed by this coordinator and the same
Host, using bundled original inputs, Native-owned staged storage and explicit prepared
nonwindow observations. Reuse the existing provider inventory and freeze the concrete
ownership/request/failure contract before edits. The required result is a production
consumer replacing the XCTest-only startup adapter, with complete startup/late-failure
comparison and explicit physical-backend dependencies; another inventory or isolated
receipt helper alone is not the next milestone. This connects the recovered caller
toward the complete Naruto/Sasuke District match, which remains intermediate.

Physical window/resource mappings, synchronous callbacks, clock/queue acquisition,
audio, initialized loading messages/fills, independent review/root promotion and actual
Windows/device/clean-Mac checks remain open. NTSDApp still uses Practice. Source 59727
remains terminal at the previously recorded 34-Object publication boundary; full 137
source return/transport/provenance and existing safety incidents remain open. No original,
emulator, capture, affected refused operation, Windows or device executed in this phase.
EXE envelope was not recalculated. Full match and complete standalone game remain open.
