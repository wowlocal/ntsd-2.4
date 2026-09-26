# Window coordinator inspection correction

The isolated candidate removes the coordinator-to-Host lock edge after handoff.
Two changed Swift files parse; fresh compilation, eight selected methods and
independent review remain open. This is an implementation correction to the
[static finding](../evidence/application-host-window-startup-lock-review.json),
not an observed Windows/device result or a claim of complete game acceptance.

The [pre-edit plan](APPLICATION_HOST_WINDOW_INSPECTION_PLAN.md) uses HEAD51828ed
and the actual2246-file candidate from the [28-method validation](APPLICATION_HOST_WINDOW_STARTUP_VALIDATION.md),
manifest `87b587d087afa1d870cdaf80e76e11aff486ad9bf25aecaafb3313b90186e8dc`.
Its jobs, old results and archives stay frozen. Root Native and actual dirty inputs
remain protected and unpromoted. Previous goal work is classified as progress.

## Contract and implementation

Coordinator Application/count getters now call the Host's existing locked getters
directly. They read current committed Host state, without holding coordinator lock
while waiting for Host. They do not cache the startup snapshot or change Host's
own transaction boundaries. Before handoff, platform inspection still returns an
independent staged copy with the existing coordinator reentry guard. After exchange
completion it rejects with existing `closed(finished)` before touching Host; callers
use the returned Host's own independent platform inspection.

The Host remains private until startup publication succeeds. Once external code
can call Host, coordinator resume also rejects on the closed exchange before Host;
answer/fail/cancel only access exchange state. Thus an external Host callback that
reads exchange state has no opposite coordinator-to-external-Host lock edge to form
the reported cycle. This is author source analysis; the original possible cycle
was not executed or relabeled as an observed deadlock.

Only `OriginalApplicationWindowStartup.swift` and a new inspection test file change.
Host, Bootstrap, exchange, all recovered window/WinMain/input algorithms, old tests,
comparators, fixtures and resources remain byte-identical. One Host, receipt values,
resource retention, cancellation, indeterminate outcomes and publication order are
preserved. No new single-thread-only restriction or physical IO is introduced.

## Finite comparison design

Three new methods are selected before the five unchanged coordinator methods:

1. Independent platform inspection before handoff; after handoff, a worker must
   reject coordinator platform copying while the actual Host holds its lock inside
   an input transaction. The returned Host continues to provide independent copies.
2. 32 actual key transactions (16 down/up pairs). A worker alternately reads current
   Application/count while Host's final callback holds its lock; another reads the
   exchange. The exchange read must finish before the callback releases Host. Then
   workers join and current full state/count, key state/effects, exact queue and
   reservations, publication sequence and retained startup context compare.
3. Fresh/failed/outstanding/cancelled/indeterminate startup retains independent
   private Host inspection, old committed values, receipts and reentry rejection;
   a successful whole retry uses the same retained owner.

Semaphores order attempted reads;5s waits bound each observation/join. A callback
timeout records failure and releases Host before joining workers. This is a bounded
Native overlap check, not proof of every scheduler interleaving or a new original
threading rule. No sleep-based scheduling assertion or intentional permanent
deadlock is used. All old test methods and comparison predicates stay unchanged.

The retained five methods include all35 WinMain parents with23 complete/5 stopped/
7 provenance outcomes,6325events/119WAVs/650 once-served window replies, six late
failures, protocol and resource/key-handoff controls. The prior28 and82 comparisons
remain separate evidence. Only coordinator inspection changes; unchanged Host/
Bootstrap/loading implementations are protected instead of being relabeled as
freshly compared by this eight-method selection.

## Verification and handoff

Preparation50454 finished with exit0 in9.288s: all2246 source files were cloned and
checked by full body/mode/nsmtime/membership and distinct regular inodes. Parser55948
finished with exit0 in0.124s; two separately pinned commands have empty logs. Syntax
parsing does not establish typechecking, comparison or independent review.

The [publication](../evidence/application-host-window-inspection.json) and
[closure](../evidence/application-host-window-inspection-close.json) identify the
2247-file candidate, two-file patch roundtrip, preservation and complete regular
candidate/PAX metadata archives. Task alias is
`build/research/application-host-window-inspection-20260926/` in the declared X5
area. Implementation bounds4GiB physical/16GiB logical,40/6GiB reserves and17GiB
source commitment remain unchanged; T7 remains separately authorized.

Finalizer58464 finished with exit0 in22.105s and is absent; the task is frozen.
The complete candidate archive contains2247 files/59 directories and5,127,073,406
logical bytes; body/mode/nsmtime/membership and distinct clone inodes were checked.
The31-member PAX metadata archive has1,955,840 bytes, SHA256
`4fed64524fff0e5682c64f4b211b6c3dc97e2a8314d416017f658966205c7f43`.
Candidate manifest SHA256 is
`3a3595560f2a8f82c637c356401cc946330eb6eec2f6f7cbda14dbdd4c9b1242`.
Root1034, base2246,385 fixtures,1301 resources and55 source pins are preserved.
The frozen archive retains the earlier study snapshot; this terminal documentation
update and a list-spacing correction are pinned separately in the root receipt.

NEXT: fresh bounded build/package/eight-method validation of these exact bytes.
Keep all five whole-caller regressions intact; preserve any failure and diagnose it
before a separately identified correction. No root Native promotion or mutation of
the frozen candidate. After validation, resume the concrete production startup
provider/backend boundary; do not substitute another ledger-only study.

Only original NTSD artifacts provide behavioral evidence; EXE/lib/CRT pins are in
the plan. No original/emulator/capture/auditor, refused operation, device or Windows
executes here. Source59727 stays terminal at34 Objects; full137/transport and existing
incidents remain open. Independent review, production nonwindow observations and
physical resource/callback mapping, loading messages/fills/audio, devices/Windows/
clean-Mac/full match/game remain open. EXE envelope was not recalculated.
