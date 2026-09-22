# Application host loading validation

**2026-09-22: fresh compilation and package verification passed; the first25
methods passed, method26 failed with two assertions, and methods27–42 were not
started.** Native comparison remains unaccepted. The exact candidate, failed
result and build products are preserved. Independent review remains open.

This follows the [frozen plan](APPLICATION_HOST_LOADING_VALIDATION_PLAN.md) and
[loading candidate](APPLICATION_HOST_LOADING_CANDIDATE.md). See the separate
[publication](../evidence/application-host-loading-validation.json),
[closure](../evidence/application-host-loading-validation-close.json) and
[documentation receipt](../evidence/application-host-loading-validation-docs.json).
Root author performed the checks; author diagnosis is not independent review.

## Analysis

The bounded question is whether the host retains actual loading owners and
commits one complete loaded iteration, preserving rollback and retry. Reference
EXE SHA256 is `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The pinned original DLL/CRT, saved controlled API replies, source comparisons,
state/masks and declared Native composition are unchanged. No original code,
Windows/device observation or refused operation ran for this validation.

The failed method is
`OriginalApplicationHostLoadingTests/testOwnFreshLoadingAndThreeCachedCyclesUseHostHandoff`.
Its two failures are at line66, one for each bitmap backing. The new assertion
compares the operation prefix with `Input.Operation.menu(effect)` in both fresh
and cached loading. Fresh loading actually passes through Loading, Catalog,
Pool and Input: its complete prefix is
`Input.preceding(Pool.preceding(Catalog.preceding(Loading.menu(effect))))`.
Cached loading enters Input directly and retains `Input.menu(effect)`.

This distinction is established by the existing constructors in
`OriginalApplicationLoadingSession.swift:44`,
`OriginalApplicationCatalogSession.swift:141`,
`OriginalApplicationPoolSession.swift:73`,
`OriginalApplicationInputSession.swift:72`, and
`OriginalApplicationLoadedCycleSession.swift:31`. Their hashes and exact source
lines are pinned in the task's `failure-diagnosis1.json`. The recorded mismatch
shows identical surface request/response contents inside different wrappers.
The intended correction is a separately identified test candidate that checks
each path's full operation type and payload. The original assertion, result,
expected source records and masks remain immutable. This diagnosis does not
turn the failed method into a pass or establish its remaining coverage.

## Implementation and validation

Base HEAD was `452898f02159f1ff08263a7b0e1c221a7ef8b2e9`; actual input is the
frozen1037-file candidate manifest, including relevant dirty baseline files.
Preparation cloned and verified every file body/mode/membership and distinct
regular inode into `build/research/application-host-loading-validation-20260922`.
No candidate code changed in this task; root Native remains unchanged.

Swift6.4 built fresh Core and dependent targets with release optimization,
Swift5/macOS14, whole-module compilation, two jobs, native SwiftPM and
`-Xswiftc -enable-testing` from the outset. Minimal environment and new task
scratch/cache/config/security directories are recorded. Build PID21244 completed
exit0 in295.750s, sampled peak tree RSS6,245,220,352 bytes. There were no compiler
errors; existing warnings and deprecated native-build-system notice are retained.
Core191, ReferenceChecks61 and Tests267 original sources were verified against
the command graph, plus the two generated resource accessors. Every checked
object/module and the62,535,608-byte test binary was freshly produced.

The package checker verified385 fixtures and102 runtime resources as487 regular
files with exact bytes and membership in two sibling bundles. Tests used this
package, without raw-fixture overrides. Package success is separate from Native
comparison and actual application acceptance.

The first25 named XCTest methods passed with actual exit0 and complete one-test,
zero-failure summaries. They retain whole menu/input parents and startup,
rollback, ownership, resource and message-loop checks from the prior host
selection. Method26 PID25757 completed exit1 in98.440s, with two XCTest
assertion failures and zero unexpected failures. Its sampled peak RSS was
6,770,851,840 bytes, below the8GiB guard. Queue PID24338 stopped after26 methods
in349.938s. The remaining16 methods have configs but no jobs or execution claim.
No guard or signal caused this outcome. Short-method RSS0 means no sample.

## Preservation and continuation

The failure-only finalizer preserves the exact candidate and successful release
products as regular APFS clones, verifies full archive bodies/modes/mtimes and
membership, and archives command/job/log metadata separately. The unexecuted
success-finalizer draft is retained. Publication keeps Native comparison false;
package and archive verification do not erase the assertion failure. All task
processes are checked terminal and absent before closure. Source PID59727 is
revalidated separately and left running; no source capture is restarted.

Root1034 files, frozen candidate1037 files,487 resource files,55 source code pins
and the immutable instruction archive remain unchanged. Storage remains within
the declared24GiB observed allowance, including concurrent source growth, with
original40GiB external/6GiB internal reserves preserved. Exact archive counts,
hashes, finalizer identity and closure space figures are in the linked evidence.

Next: freeze a separate correction round, preserve the full fresh/cached operation
comparison, compile the corrected test candidate and run the same42 methods.
No method may be skipped to accept a candidate. Independent comparator/contract
review, root promotion, live timing/providers, actual window/input/audio, later
typed child retention, whole Catalog53 source and full-game acceptance remain open.
