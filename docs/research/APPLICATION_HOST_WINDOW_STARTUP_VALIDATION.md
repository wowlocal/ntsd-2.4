# Same-Host startup — all 28 comparisons passed, lock-order gap open

All28 selected methods passed on the unchanged2246-file candidate. Fresh build and
exact package bytes passed. This accepts those controlled comparisons, not the
complete coordinator contract: author inspection identified an additional possible
post-handoff lock-order cycle, described below. Independent review, its correction,
root promotion and production device integration remain open.

The [plan](APPLICATION_HOST_WINDOW_STARTUP_VALIDATION_PLAN.md),
[candidate](APPLICATION_HOST_WINDOW_STARTUP.md),
[publication](../evidence/application-host-window-startup-validation.json) and
[closure](../evidence/application-host-window-startup-validation-close.json) retain
the declared inputs, exact selection, process records and separate gate results.

## Implementation and actual comparison

This phase made no candidate or root Native change. The new coordinator reuses one
Host, installs independent prepared window cursors, unwinds before issuing a permit,
and validates completed receipt consumption after the last fallible publication
copy. It supplies no invented response and performs no physical window IO.
Candidate manifest SHA256 is
`87b587d087afa1d870cdaf80e76e11aff486ad9bf25aecaafb3313b90186e8dc`.

Preparation12320 cloned all2246 files in12.944s with full bytes/modes/nsmtimes,
membership and distinct regular inodes checked. Build12957 completed in287.020s,
sampled process-tree peak6,432,227,328 bytes. The native-SwiftPM release build used
Swift5/macOS14, two jobs and testability. Package verification checked194 Core,
61 Reference and274 test sources plus generated accessors, fresh outputs, and all
1686 resource files:385 fixtures and1301 Core files. The XCTest binary is64,109,240
bytes, SHA256 `be34a6d78d3467dc6d93989afcb976b3876c65af0262bf0b1d3b6f4f90bfc2e1`.

The five new complete methods passed:

- All35 original WinMain parents through the same retained Host preserve23 complete
  chains,5 original stops and7 provenance rejections; these are not35 matches.
  The source comparators retain6325 events and119 whole WAV results;650 window
  replies were served once. Complete cases also compare full Bootstrap state,
  ordered operations/graphics and retained publication context.
- Six late startup failure sites retain Host state and the answered journal,
  then complete startup on the same owner without serving a window request again.
- Preparation failure, throwing/shared publication copies, and missing/foreign/
  stale/unconsumed/suspended completion cursors preserve answers and publish nothing.
  Each final failure reports once; successful retry publishes sequence1 once.
- Outstanding/foreign/stale/duplicate permits, reentry, cancellation before/after
  issuance, late reply and indeterminate outcome stay distinct without automatic
  physical retry or fabricated success.
- The returned actual Host runs key-down/key-up iterations. Startup context and
  response resources survive coordinator/Host destruction and release after the
  final retained owner drops; cancelled late replies retain their own resources.

All23 retained methods also passed: the preceding ten window/WinMain methods,
five HostSession, six HostDeliveryContext and two Bootstrap. This includes all280
whole windows/4574 once-served requests, existing first-menu/input chains, delayed
loaded owners on both backings and late loaded-publication failures. Old methods,
comparators, fixtures and masks were not changed. Earlier82-method results remain
separate and were not relabeled as a fresh82-method comparison.

Queue23770 completed with exit0 in463.554s, 12:02:26.620893–12:10:10.165746 UTC.
Sum of individual test-process durations is385.265s; sampled peak10,290,331,648
bytes, below inherited16GiB limits for the loaded-context methods. Each exact
method has one passed result, three one-test/zero-failure summaries and a Selected
tests pass, with no guard/signal/residual process. The saved-result predicate is
unchanged. RSS0 for tests09/10 denotes absence of a sample, not known zero memory.

## Preservation and archives

Finalizer38551 completed with exit0 in67.411s and is absent. Its saved-result reader
verified all28 logs against their jobs and unchanged exact pass predicates. Root1034,
prior2244, both current2246 copies and55 source pins are preserved. The task is frozen;
no queue, source or completed producer is restarted.

The full regular APFS candidate/release archive contains4900 files/210 directories,
no links and11,383,163,548 logical bytes. Every body/mode/nsmtime/membership and
regular clone's distinct inode was checked. Manifest SHA256 is
`3f27285d6796c418f5cdb2417a9033598be87a5fd5cdce4e816dce0f1e28f3d9`.
The140-member PAX metadata archive is5,529,600 bytes, SHA256
`dfd0f5e46cb75ecaad845e9db4c95787e70616d357bbe0fff67c41c1471e4045`;
all names/bodies/modes/nsmtimes were verified, including the author lock-order
finding. Mutable finalizer job/log were retained separately and pinned at delivery.
Closure records170,102,210,560 external and58,893,438,976 internal free bytes;
observed external decrease1,160,032,256 bytes is within28GiB and is not a per-task
allocation measurement. Original40/6GiB reserves and17GiB commitment remain intact.

## Additional author finding and next task

The [pinned finding](../evidence/application-host-window-startup-lock-review.json)
records a possible lock-order cycle inferred from this compiled source. After
successful startup, external code receives the Host. Coordinator inspection
currently acquires coordinator lock then Host lock. A concurrent Host callback
already holding Host lock can read `exchangeSnapshot` and wait for coordinator
lock. The no-IO/no-shared-mutation callback rule does not prohibit this read-only
observation. These two paths can form a cycle.

This is static author analysis, not an observed hang, a failing saved method,
independent review, original game behavior or a safety refusal. The frozen28-method
selection does not include concurrent inspection after handoff. It stays unchanged;
passing it cannot close the additional ownership gap. No process was interrupted
and no pinned source was edited to address the finding during validation.

NEXT: freeze a small correction and finite post-handoff inspection checks. Remove
the coordinator-to-Host lock nesting from committed value reads; define platform
inspection after handoff so it cannot reintroduce the cycle, while keeping actual
Host inspection available through the returned owner. Preserve startup reentry,
receipt/failure/cancellation contracts and one Host; retain these28 results as
baseline evidence. Do not narrow the game or silently impose a single-thread-only
contract. Fresh comparison must exercise the corrected code, not these old bytes.

## Scope and open gates

Only the original Windows distribution is a behavioral reference: EXE SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`; pinned lib/CRT
hashes are in the plan. The data/API/backing observations remain declared controls.
No original/emulator/capture/auditor, affected refused operation, Windows or host
device executed. EXE envelope was not recalculated. Source59727 remains terminal
at its earlier34-Object publication boundary, not an accepted full137 return.

Root Native remains unpromoted; actual production nonwindow observations, physical
resource mapping/callbacks, initialized loading messages/fills, audio, full137
source/transport, existing incidents, independent review, actual window/input/audio/
Windows/clean-Mac, complete Naruto/Sasuke District match and full game remain open.
