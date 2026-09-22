# Host loading assertion correction, round1

**2026-09-22: fresh compilation/package checks passed;27 methods passed,
method28 hit its resident-memory guard, and14 methods remain unstarted.**
Native comparison remains incomplete. Independent comparator/contract review, root promotion and actual app/device
acceptance remain open.

The [frozen plan](APPLICATION_HOST_LOADING_CORRECTION1_PLAN.md) follows the
[preserved failed validation](APPLICATION_HOST_LOADING_VALIDATION.md). It keeps
the same game question, original artifacts,42-method selection, operation/state/
mask/resource comparisons and controlled Native composition. No new original
execution or device behavior is claimed. Root author owns this correction;
author inspection is not independent review. See the separate
[publication](../evidence/application-host-loading-correction1.json),
[patch](../evidence/application-host-loading-correction1.patch),
[closure](../evidence/application-host-loading-correction1-close.json) and
[documentation receipt](../evidence/application-host-loading-correction1-docs.json).

## Analysis and implementation

Base HEAD is `03afa4ed7ca343b185e9fb26487cbda782c18010`. The actual1037-file input
comes from the frozen loading candidate, including relevant dirty baseline.
Only `OriginalApplicationHostLoadingTests.swift` changes in a new task. Its
prefix equality now distinguishes actual fresh loading from cached cycles:
fresh retains Input.preceding→Pool.preceding→Catalog.preceding→Loading.menu;
cached retains Input.menu. Each effect is still compared with its entire payload
and mask. No flattening, filtering, skipped operation or new source expectation
is introduced. All other Native/test files and487 resources remain byte-identical.

The prior method26 failure remains failed with its original two assertions,
logs, candidate and products preserved. Existing Loading:44, Catalog:141,
Pool:73, Input:72 and LoadedCycle:31 constructors establish the distinct wrapper
provenance; the prior diagnosis pins their exact source. This correction changes
the new Native assertion, not an original Windows expected result. Independent
review of this comparator change remains an explicit unclosed gate.

Preparation saved the before/after manifests and exact one-file patch. Applying
that patch to a separate copy of the original file reproduced the corrected file
byte for byte. Core, fixture and resource inputs did not change. The runner is
byte-identical to the previous runner after substituting only the new task name;
its entire monitoring loop and ownership/transition predicates are unchanged.

## Validation

Preparation PID27880 completed exit0 after cloning/checking1037 regular files.
Build PID27983 completed exit0 in296.533s; sampled peak tree RSS6,343,606,272 bytes.
The fresh Swift6.4 release build used Swift5/macOS14, whole-module optimization,
two jobs and testability enabled from the outset. The package verifier checked
Core191/ReferenceChecks61/Tests267 original sources, two generated accessors and
fresh object/module outputs. All385 fixtures plus102 runtime resources are regular
files with exact bytes/membership. The test executable is62,536,360 bytes.

Build/test commands, minimal environments and process receipts are in
`build/research/application-host-loading-correction1-20260922`. Queue PID30915 completed in518.709s. All25 previous host methods
and the first two new HostLoading methods passed with actual exit0, exactly the
requested method and complete zero-failure summaries. The corrected first-loading/
three-cached-cycle method passed in98.472s; preparation/final-tail rollback and
same-child retry passed in50.333s. Neither erases the original failed candidate.

Method28 `testDifferentSameRevisionTicketsAndRepeatedCompletionAreRejected`
(PID33178) was terminated at112.906s by its declared8GiB RSS guard. Peak sampled
tree RSS was8,786,558,976 bytes,196,624,384 above8,589,934,592. The monitor recorded
the exact process identity/cwd before SIGTERM and reaped exit-15 with no remaining
processes. The log contains the requested method start but no assertion error,
method completion or suite result. This is an incomplete resource-limited run,
not a successful comparison or an assertion mismatch. Methods29–42 never started.
The original8GiB bound and overshoot remain preserved; no automatic rerun occurred.

The finalizer verifies all27 named passes and the distinct guard outcome, plus
the one-file correction/patch roundtrip, exact candidate/package bytes and task
process absence. It archives2482 regular candidate/release files and separate
metadata with full byte/mode/mtime/membership checks. Exact counts/hashes and
observed storage figures are in the publication/closure. Native comparison stays
false; package/archive verification are separate. The root1034 files, original
candidate,55 live source pins and original40/6GiB reserves remain protected.

Next is a separate bounded continuation of this unchanged binary/package:
retain27 passes, rerun whole method28 with a declared12GiB RSS ceiling, then the
14 unstarted methods. The saved host observation reports24GiB physical memory,
with source RSS451472KiB; these are observed capacity facts, not a guarantee of
future availability. Keep all stop/identity/space limits and the prior guard.
No code, expected value, mask, selector or method body is changed for that round.

## Remaining work

This finite loading handoff remains controlled Native composition, not the whole
running Catalog53 source result or a playable game. The fourth selection input
boundary is an injected stop, not a returned iteration. Later typed child
retention, real providers/timing/window/input/audio, root promotion, whole-source
comparison, existing safety dependencies and clean-Mac/full-game acceptance stay
open. The original source capture is preserved and is never restarted by this
correction.
