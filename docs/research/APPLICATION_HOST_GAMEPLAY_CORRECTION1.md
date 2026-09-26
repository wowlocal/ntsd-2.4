# Host gameplay correction1 — build passed, result-reader failure preserved

2026-09-26, terminal result. Fresh build and package checks passed. The unchanged
69-method queue stopped after57 accepted methods because its reader did not
recognize method58's complete passing XCTest result inside buffered output.
Methods59–69 were never started. This is a **result-reader failure**, with no
recorded XCTest assertion failure or resource guard. The old task is now frozen;
no test or source was restarted. [Publication](../evidence/application-host-gameplay-correction1.json),
[closure](../evidence/application-host-gameplay-correction1-close.json),
[exact diagnosis](../evidence/application-host-gameplay-correction1-reader-failure.json).

## Terminal comparison and diagnosis

Queue20715 exited1 after1,511.394s; its58 test processes totaled1,353.367s.
Methods1–57 have exact named passes, three complete one-test/zero-failure suite
summaries, exit0, no guard and verified process absence. They include the prior53
host/parent controls, two saved-source readers and both neutral projections.
No new HostGameplayTests method64–69 has run yet; the full host gameplay retention
contract remains unaccepted. The candidate has not been promoted to root.

Method58, OriginalApplicationActiveOutputTests/testPrimaryOwnedOutputProjection,
ran under65072 and exited0 after87.191s with no guard/signals. Its sole named result
is `passed (86.589 seconds)`, at exact raw-log byte span[69969,70092). All three
suite summaries say one test/zero failures and Selected tests passed. However,
the named line starts immediately after the prefix
`Owned active preflight {"activeSlots":[0,1],"bodyDifferentialAccepted":f`.
The remainder of `false` follows the XCTest suite metadata. The old parser's
start-of-line anchor therefore yields zero matches and correctly stops its queue
under its existing rule. The preserved finalizer classifies this generically as
native-process-or-result-failure; the byte-level diagnosis narrows it to the reader.
It is not a Native assertion mismatch, source fault or safety refusal.

Removing only the identified XCTest metadata block in a separate in-memory
inspection reconstructs all48 complete ordered primary diagnostic rows. The raw
log, queue result, failed reader and binary remain unchanged. This inspection is
a diagnosis, not a retrospective rewrite of the queue's acceptance. The proposed
reader correction removes only the start-of-line anchor while keeping the exact
named result, end-of-line boundary, three complete summaries, actual exit and
no-guard/process-absence gates. Positive/negative controls and separate saved-log
recovery are the next task; no corrected-parser acceptance is claimed here.
The earlier active-notices study independently encountered buffered XCTest output;
its completed capture/auditor was read as context and was not executed again.

## Archive and preservation gates

Finalizer70559 exited0 in32.300s and is absent. It verified root1034, corrected1040,
both prior1040 candidates,29 protected inputs/source55, exact one-declaration delta,
the fresh binary/products and487 packaged resource files. All58 test processes
and their observed descendants are terminal/absent. The57 accepted outcomes and
method58's nonpass are retained distinctly; all11 unstarted names remain explicit.

The APFS clone artifact archive contains2,488 regular files and156 directories
(154 traversed plus two parents),10,047,065,022 logical bytes. Its manifest SHA is
`1fd82085678f026286ed2375e2de6c5ebd57f9454c189d9b043f7665bf590c41`.
Full bodies, modes, nanosecond mtimes and membership were checked, with distinct
regular inodes. The275-member metadata archive is3,768,320 bytes, SHA256
`2ec9985397d8fe4e216fd5b7d70b7ec88f96eedf66c5527792290260e4e53c1c`;
its PAX member bodies/modes/mtimes/membership were read back separately.

Observed external free-space decrease1,142,325,248 bytes is within24GiB;
external124,308,156,416/internal63,094,628,352 free bytes preserve original40GiB/6GiB
reserves. X5 UUID was revalidated. No evidence was deleted and no reserve reduced.
Source59727 remains terminal at its separately documented publication boundary.
The earlier read-only child-job observation race is preserved in
observation-diagnostic1.json; it neither stopped nor restarted the queue.

## First permissible continuation

Freeze a separate unchanged-binary result-reader recovery/continuation. Check the
one-anchor parser correction against the saved method58 span and finite negative
controls; preserve all old results. If the saved exact result is validated, retain
it plus the57 prior passes and execute only unstarted59–69 with unchanged limits,
comparison bodies, expected, masks and entire17/48/14 schedules. Reuse the existing
unchanged-binary completion runner/package/archive procedures; no rebuild or
re-execution of method58. Stop on the first nonpass. Independent reader/contract
review remains unavailable and open; author checks are not independent review.
After all69 and publication gates, reassess the next app/match consumer. Catalog
transport/provenance, full catalog return, installed trajectory, app/devices,
Windows/clean-Mac, first full match and full game remain open. This supersedes the
live-queue NEXT in the historical build/start observation below.

## Earlier build/start observation (preserved)


2026-09-26. The single declaration correction specified by the
[failed validation](APPLICATION_HOST_GAMEPLAY_VALIDATION.md) now passes a fresh
release build and package verification. The unchanged69-method selection is
running; complete comparison, artifact/archive publication and independent review
are **not yet accepted**. See the [frozen plan](APPLICATION_HOST_GAMEPLAY_CORRECTION1_PLAN.md),
[build/start receipt](../evidence/application-host-gameplay-correction1-start.json),
[exact patch](../evidence/application-host-gameplay-correction1.patch) and
[tool adaptations](../evidence/application-host-gameplay-correction1-tools.json).

## Analysis and implementation

Base HEAD `47ef76e` is recorded by the actual context; its full hash is retained
in the context/receipt. The previous turn
was progress: it preserved a failed compile and identified a missing parameter.
The task continues retained host input/body/paused handling through the existing
outer return, a dependency of the first full Naruto/Sasuke District match.

The new1040-file candidate adds only the optional
`driver: OriginalApplicationLoadedTestDriver? = nil` parameter to
OriginalApplicationActiveOutputTests.sequence. Its body already forwarded that
argument, and HostGameplayTests already supplied it. No Core, comparison body,
expected value, mask, source resource or method selection changed. Default nil
preserves the historical Bootstrap route. Both prior1040-file trees, including
the failed build candidate, remain unchanged; all root1034/source55 pins and
file memberships were verified. The failed compile/log/archive are preserved.

Corrected manifest SHA256:
`5505b78d77d5c92eb6932508deeab30184ee406452d22ce2522e151df70490b5`.
The exact750-byte patch SHA256 is
`c4ec433b664ea720fac97350db02bdc8cf58b60423276724cd847b0dd0d6a9cb`.
The existing preparation/runner/queue/package/finalizer are reused through pinned
generated copies. Their changes are recorded verbatim: task/tool paths, the one
declaration, baseline verification and terminal-source observation. The monitor's
ownership/transition/guard/reap body remains byte-identical. Existing finite cwd,
compiler-transition, transient-exit and phase controls passed; all69 definitions
exist exactly once. These author checks are not independent contract review.

## Completed validation

Preparation9321 exited0; the candidate was APFS-cloned with distinct regular
inodes. Fresh installed Swift6.4, Swift5/macOS14 release/WMO, SwiftPM native build
system, jobs2 and enable-testing used new scratch/cache/config/security paths and
the declared minimal environment. Build10257 exited0 in282.927s; observed peak
aggregate RSS6,393,593,856 bytes, no guard/signals, no remaining group/descendants.
Its actual build log reports280.73s; the longer value is the monitored process
duration. The pre-existing deprecated-build-system warning is retained.

Package verification checks actual compiled191 Core/61 ReferenceChecks/270 Tests
source membership and fresh products. The63,174,872-byte XCTest binary and all
385 fixture/102 runtime resource payloads are regular files with verified bytes.
This package result is separate from behavioral comparison and archive gates.
No old binary pass validates this candidate.

The69-method queue started under PID20715 at06:27:47 UTC. At the immutable
build/start observation it was confirmed live by PID/start/full command/cwd/job,
with the first three methods passed. This count is a timestamped observation,
not a final queue result. The authoritative current job is
`build/research/application-host-gameplay-correction1-20260926/tests1-queue.job.json`.
The exact named result, all three one-test/zero-failure summaries, actual exit,
guard and process absence are checked per method. Stop-on-first-nonpass and all
whole17/48/14 schedules, both backings, rollback/retry controls and prior limits
remain unchanged. Do not duplicate this queue or rerun completed methods.

## Source and storage state

Source59727 is now terminal0/absent, ended2026-09-23T00:10:17.364994Z after
49,093.526s. Its reported result is researchBoundary/end dependency, with a
logical-cap publication boundary; this is not full catalog return or acceptance.
The immutable source-terminal-observation1.json links its job and records this
distinction. It does not audit the249,780,969-byte publication. No original
instructions or capture/auditor were executed again, and no source process was
restarted or signaled. Previous safety incidents remain open.

X5 APFS UUID matched `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`; observed free space
before preparation was125,450,493,952 external and63,105,515,520 internal bytes.
Original40GiB/6GiB reserves, source17GiB commitment and this task's24GiB allowance
are retained. Large files stay in the task-owned X5 directory; no evidence was
deleted or reserve lowered. Full artifact and metadata archives await terminal
comparisons and the existing finalizer; no archive acceptance is claimed now.

## First remaining gate

Revalidate the queue/job and current child by PID/start/command/cwd, then observe
the same execution. If terminal, preserve and diagnose any first nonpass; if all69
pass, run the generated finalizer with package/protected/archive verification.
Generated tools live in
`build/research/application-host-gameplay-correction1-20260926-tools/`.
Do not edit their pins, either candidate, expected or source. Do not restart the
failed validation task or terminal source. An observation timeout does not stop
the queue. This supersedes the compiler-correction NEXT.

Independent review, root promotion, installed whole-application trajectory,
complete catalog source/comparison, actual app/window/input/audio, Windows and
clean-Mac checks, first full match and full game remain open. Saved synthetic
platform/input/ABI/FPU and unknown-storage boundaries remain unchanged.
