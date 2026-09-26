# Window coordinator inspection after Host handoff

2026-09-26; HEAD51828ed. Previous goal turn was progress: one retained Host startup
was implemented, all28 selected methods/build/package/archive gates passed, and
an additional author lock-order finding was preserved. Queue23770/finalizer38551
are terminal0 and absent. Their candidate and evidence remain frozen.

## Game result, evidence and scope

Remove the concrete coordinator/Host inspection cycle before attaching an actual
window provider to recovered application startup. The direct consumer is the same
returned Host executing its existing input/menu transactions. This advances native
application integration toward the complete Naruto/Sasuke District match; the full
standalone game remains the goal. Do not impose a new single-thread-only runtime.

Read WORKFLOW/CURRENT_WORK/TASK_TEMPLATE, the Host window startup implementation/
validation, pinned lock review, Host delivery-context/transaction and window/WinMain
dependencies. Archive1203–1235/1792–1831/1942–1948/3337–3349 rules remain binding.
The possible deadlock is a Native design finding from lock order, not an observed
hang or recovered Windows rule. Independent review is unavailable and stays open.

Only behavioral reference: original distribution, EXE SHA256
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c,
lib28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba,
VC80c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d.
Read saved controls and original package initial data; no original/emulator/capture/
auditor, affected refused operation or actual window/device/Windows execution.

## Contract before edits

- Coordinator `snapshot` and `pendingBatchCount` delegate directly to the Host's
  existing locked committed getters. They must not acquire coordinator lock while
  waiting on Host. Their data remains current Host state, never a startup cache.
- Coordinator `platformSnapshot` keeps existing pre-handoff independent-copy and
  reentry behavior. Once exchange completion has committed the handoff, reject
  with existing `.closed(.finished)` before taking Host lock. The returned Host's
  platformSnapshot remains available and independent. Cancellation/indeterminate
  states without a handoff retain their old coordinator inspection behavior.
- No other coordinator action takes Host lock after completion: resume rejects
  on the closed exchange first; answer/fail/cancel operate only on the exchange.
  The private Host remains inaccessible before successful startup publication.
- Preserve one Host, fixed initial inputs, staged copies, receipt consumption,
  suspension/cancellation/indeterminate boundaries, final publication and resource
  retention. No change to Bootstrap, Host, exchange, window algorithms, observed
  device replies, timer/input rules or underlying state ownership.

Only two candidate paths may change: Core OriginalApplicationWindowStartup.swift
and new Tests/NTSDCoreTests/OriginalApplicationWindowInspectionTests.swift. All old
test files/methods/comparators/fixtures/resources and root Native remain immutable.

## Finite checks frozen before execution

Three new complete XCTest methods, using existing actual startup/input composers:

1. Platform inspection remains an independent copy before handoff. After successful
   startup, a worker tries coordinator platform inspection while the actual Host
   holds its transaction lock in an input callback. It must return closed(finished)
   before that callback releases Host. Host's own inspection then succeeds; mutating
   its returned copy cannot change Host/batch owners. No additional batch/reply.
2. Thirty-two actual key transactions (16 down/up pairs), alternating coordinator
   Application/count readers on a worker while Host's final callback holds its
   lock. A second worker reads exchange state; that read must finish before Host
   callback returns. After release, both readers join and committed value/count,
   exact key state/effects/queue reservations and retained startup context compare.
   Signals order the attempts; no sleep-based scheduling claim. This is a bounded
   overlap test, not proof of every scheduler interleaving or an observed old hang.
3. Before handoff, fresh/outstanding/cancelled/indeterminate inspection retains
   independent original platform state and receipts; startup callbacks still allow
   committed value reads while rejecting reentrant platform copying. Keep the
   actual prepared failure, retry/receipt ownership and zero publication explicit.

All worker waits are bounded at5s and joined outside the Host callback. Callback
timeouts record a failing check and return to release Host so workers can unwind;
do not leave intentionally deadlocked workers or claim a timeout is termination.
No physical IO occurs inside callbacks. These are Native concurrency controls.

Retain the five complete OriginalApplicationWindowStartupTests methods exactly,
including all35 WinMain outcomes (23 complete/5 stops/7 provenance),6325 events,
119 WAV results/650 window replies, six late failures, protocol and resource/key
handoff checks. Select3+5=8 methods. The change affects only coordinator inspection;
all other Core files and old tests remain byte-identical. The prior28/82 results
remain separate evidence, not a newly rerun broader suite. Do not weaken any check.

## Bounds, ownership and delivery

Actual base application-host-window-startup-validation-20260926/candidate1 has2246
files, manifest87b587d087afa1d870cdaf80e76e11aff486ad9bf25aecaafb3313b90186e8dc.
Preserve dirty-baseline provenance; root1034 is not this candidate. Reuse existing
verified preparation/parse/patch-roundtrip/APFS/PAX tools into task/alias
application-host-window-inspection-20260926 under
/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408/.
Verify writable APFS UUID3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548 and65GiB external/
9GiB internal before IO. Retain40/6GiB reserves plus17GiB source commitment.
Implementation bounds4GiB physical/3584MiB observed-decrease stop,16GiB logical,
metadata16MiB/root2MiB/7200s; no build in this phase. T7 remains authorized separately.

One owner edits only the two candidate paths, new task/alias, preparation adapter,
plan/study/evidence and own navigation additions. Pin adaptations and preserve
drafts before corrections. Parse both sources, verify all old inputs/method bodies,
two-file patch roundtrip and full candidate/metadata archives. Commit this checked
increment before separately bounded fresh build/package/eight-method comparison.
This is correction round1 for the static lock-order finding; up to three rounds,
with every failure preserved/diagnosed. No automatic reruns or expected changes.

Revalidate PID/start/command/cwd/job before process actions. No completed source or
comparison is restarted. Source59727 remains terminal at34 Objects, not full137.
Existing incidents stay open. Independent review/root promotion, production
providers/backend/callbacks, loading messages/fills/audio, full137 source/transport,
devices/Windows/clean-Mac/full match/game remain open. EXE envelope not recalculated.
