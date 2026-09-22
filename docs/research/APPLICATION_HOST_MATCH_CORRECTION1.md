# Typed host platform correction: build passed, loading guard retained

**2026-09-22: fresh build/package passed;25 methods passed.** Method26,
`testOwnFreshLoadingAndThreeCachedCyclesUseHostHandoff`, exceeded its declared
8GiB resident limit and has no completed XCTest result. Methods27–53 were not
started. This is a Native resource guard, not a completed assertion failure,
original-game fault or safety refusal. The complete native game remains open.

The [frozen correction plan](APPLICATION_HOST_MATCH_CORRECTION1_PLAN.md) follows
the [preserved compiler failure](APPLICATION_HOST_MATCH_VALIDATION.md).
Base HEAD `4d1ff161d801334831f96645e2e5964adcca12d3`; actual input is its frozen1039-file
candidate, including the earlier dirty baseline. One isolated Core path changed:
OriginalApplicationHostSession.finishLoadedMenu renames the returned-case local
to `preparedPlatform`, clones it, and explicitly installs `self.platform` at
successful outer commit. The1038 other files, all53 exact method names, fixtures,
resources, source expectations and masks are unchanged. Root Native remains
the protected1034-file tree and was not promoted.

The [patch](../evidence/application-host-match-correction1.patch) round-trips
against the failed source. Author inspection confirms that host application,
platform and prepared/pending state still install after the enclosing return
and final observer. This is author inspection, not independent contract review.
The new build establishes that the correction resolves the earlier compiler
assertion; it does not establish the unexecuted Start/launch comparisons.

[Publication](../evidence/application-host-match-correction1.json),
[closure](../evidence/application-host-match-correction1-close.json) and
[documentation checks](../evidence/application-host-match-correction1-docs.json)
identify the exact inputs, commands, logs, guard diagnosis and archives.
External task: `build/research/application-host-match-correction1-20260922`.

## Native result and guard

Preparation59149 exited0 in6.296s and verified1039 distinct regular clones.
Fresh build59931 exited0 in294.670s, sampled peak tree RSS5,770,444,800 bytes.
Installed Swift6.4 (`swiftlang-6.4.0.34.1`, clang2100.3.34.1), Swift5/macOS14,
release/WMO, testing enabled, native SwiftPM/jobs2 and new task-local build/cache
paths were used. Existing compiler warnings remain in the complete log.

Package verification checks191 Core,61 ReferenceChecks and269 Tests source files
plus the two generated resource accessors, fresh objects/modules, linked binary
and all385 fixture/102 runtime payloads. The test binary is62,637,720 bytes.
Package acceptance is separate from the incomplete Native comparison gate.

Queue62872 exited1 after340.283s. Methods1–25 each have the exact named pass,
three complete one-test/zero-failure summaries, Selected-tests pass, exit0 and
no guard. Method26 PID64311 ran86.344s; at86.064s the monitor observed
8,894,627,840 resident bytes against8,589,934,592. It revalidated PID, start,
full command, cwd and job before one SIGTERM. Child exit-15 was reaped; the
queue stopped and methods27–53 have no job files. The partial log contains
the named start, no assertion message and no completed method/suite result.
No stack/allocation sample was taken, so memory attribution remains unknown.

The older [loading round3](APPLICATION_HOST_LOADING_CORRECTION3.md) method26
passed in98.475s with sampled peak8,192,737,280 bytes. Its HostLoading test
source is byte-identical to this candidate's file. This comparison establishes
that the original8GiB limit was close to the previous observation; it does not
prove equivalent memory behavior or transfer that older pass to this binary.
All earlier compiler/assertion/guard failures remain immutable.

## Preservation and continuation

The existing runner's process identity, guard and reap logic is byte-identical
apart from task identity/import references. The queue and finalizer retain the
same complete named XCTest pass criterion. Finalization verifies the protected
root1034, previous/current1039 candidates, source55 pins, exact one-file delta,
packaged bytes, terminal processes and archive membership/body/mode/mtime.
Finalizer65026 exited0 in105.143s and is absent. The artifact archive contains
2486 regular files,156 directories (154 traversed plus2 parents) and10,043,104,650
logical bytes; exact bodies/modes/nanosecond mtimes/membership and distinct file
inodes verified. The separate164-member metadata archive is3,041,280 bytes.
Observed external decrease1,471,164,416 bytes, including concurrent source growth,
stays within24GiB. Original40GiB external/6GiB internal reserves are retained;
the external task is frozen. Source identity/cwd was revalidated18:23:09 UTC
at3155 chunks/21 Objects, still running under PID59727.

Next bounded task: retain this exact binary and25 passes, then run whole method26
with12GiB RSS/600s and methods27–53 under their unchanged limits, queue7200s.
Keep the same53 cases/comparison bodies; stop at the first new nonpass. This is
a separately planned resource-bound continuation, not another code correction,
an automatic repeat of the closed attempt, or acceptance of a truncated method.
Do not rebuild or edit this frozen candidate, omit the guarded method, reduce
reserves, restart source59727 or alter expected results.

No original execution or device IO was added. The pinned EXE remains
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
the EXE envelope was not recalculated. Original catalog capture remains a
separate incomplete source dependency. Independent review, full53 comparison,
root promotion, retained gameplay beyond the first-input inspection boundary,
actual host delivery/window/input/audio, Windows/clean-Mac/full-match/full-game
and existing safety dependencies remain open.
