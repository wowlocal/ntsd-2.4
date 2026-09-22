# Application host transaction validation

**2026-09-22: the unchanged isolated candidate compiles, and all 25 declared
XCTest methods pass.** Package and archive verification also pass. Independent
contract review, root promotion and actual application/device acceptance remain
open. This validates the persistent startup/menu/input owner and its commit
handoff under saved controlled replies; it does not establish a playable game.

The [frozen plan](APPLICATION_HOST_TRANSACTION_VALIDATION_PLAN.md) follows the
[candidate](APPLICATION_HOST_TRANSACTION_CANDIDATE.md) and its
[host preflight](APPLICATION_HOST_TRANSACTION_PREFLIGHT.md). The candidate's
historical syntax-only status and proposed validation are superseded by this
separate result; its frozen evidence remains unchanged.
[Publication](../evidence/application-host-transaction-validation.json),
[closure](../evidence/application-host-transaction-validation-close.json) and
[documentation receipt](../evidence/application-host-transaction-validation-docs.json)
record separate gates. Root author performed implementation and verification;
no independent reviewer was available.

## Analysis and reference boundary

All expectations come from existing original startup, first-menu and input
corpora. Reference EXE SHA-256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
the pinned DLL/CRT and exact input manifest are identified in the plan/context.
No original code, Windows/device experiment or refused operation was newly
executed for this validation. Controlled allocation/API/clock replies remain
declared comparison inputs, not real host observations.

Whole first-menu comparisons retain the actual `0x43d110` return, owners,
state/masks, requests, events, graphics and numeric observations. The input
chains retain the real pending loading boundary at `0x41bc90`; a suspended child
is not a completed menu return. Existing source faults and explicit Native
rejections remain distinct from matching returned cases. No expected byte,
mask, comparator projection or source rule was changed during validation.

## Implementation and build

Base HEAD was `14cad6bd9a6b14e86a04bd39d9de64b7b3faf6e5`. Actual input was the
previous candidate's 1036-file manifest, including relevant dirty baseline files,
not a HEAD-only checkout. Preparation cloned and checked every body, mode,
membership and distinct regular inode into the new X5 task:
`build/research/application-host-transaction-validation-20260922/`.
The closed candidate and live-pinned root Native were not edited.

The installed Swift6.4 toolchain built release Swift5/macOS14 targets through
`swift-build --build-system native --build-tests -c release --jobs 2`, using fresh
task scratch/cache/config/security directories and no old relocated build cache.
The installed CLI documents this deprecated build-system option. Exact commands,
minimal environments, tool versions and process identities are retained in the
task configs/jobs/logs. Core has 191 original sources, ReferenceChecks61 and
CoreTests266; generated resource accessors add one source to Core and CoreTests.
Release optimization and whole-module compilation remained enabled.

Build1 failed after 151.058s with exit1 because release Core lacked testability:
`module 'NTSDCore' was not compiled for testing [#ModuleNotTestable]` at the
existing `@testable import`. This was a build-configuration failure, not a Native
comparison. Its full mutable build/cache/config/security/tmp tree was retained:
1160 files and127 directories, with bodies/modes/mtimes/membership verified.
`command-amendment1.json` preserves the failure and installed compiler help
supporting the added `-Xswiftc -enable-testing` flag. No candidate correction
or source execution was required.

Build2 completed with exit0 in290.706s. All three relevant target command lists
contain `-enable-testing`; Core and dependent modules, tests and application
linked. The XCTest executable is62,032,520 bytes. Compiler warnings include the
deprecated build-system option and unchanged source warnings; compilation had no
remaining error. A linked practice application is not application acceptance.

The first package checker incorrectly required every object mtime to be newer
than build2. Its assertion and original checker are preserved separately.
Forty Core objects retained their first-build timestamps: each matches that
task's preserved first fresh build by full body, mode and mtime. Checker2 verifies
this provenance for every such object; all modules and ReferenceChecks/test
objects must be from build2. It also checks exact source membership, generated
accessors, flags, linked binary and dependencies. No object was excluded or
accepted from an unrelated cache. A preliminary path-diagnosis ValueError is
also retained in `package-check-amendment1.json`. These author corrections have
not received independent review.

## Native validation

The frozen 25-method selection ran one named method per XCTest process, using
the final packaged resources with no raw-fixture override. Every child has exit0,
exactly its requested method marked passed, and complete zero-failure suite
summaries. Exit codes alone were not used as acceptance.

| Family | Passed methods | Retained scope |
| --- | ---: | --- |
| New HostSession | 5 | 48 first-menu attempts,17 late controls, same-prepared-input final-hook retries,50 input chains, six startup late controls, copy/reentry/handoff/pending ownership |
| Bootstrap | 2 | Startup cursor/commit and late first-menu rollback |
| MenuReturn | 2 | Whole first due iteration and late rollback |
| MenuInput | 4 | Whole queued input/loading chains, late failures, unknown aliases, bitmap lifetimes |
| StartupInputs | 4 | Package provenance, owned snapshots, missing/corrupt/extra files and bitmap replies |
| Graphics | 3 | Text/DC boundaries, generations, palette/rectangles and source snapshots |
| MessageLoop | 3 | Whole loop/callbacks, committed press/failed release and late rollback |
| WinMainStartup | 2 | Whole startup boundaries and late rollback |

The 17 earlier failure positions are rollback controls; the successful
same-prepared-input retries occur at the final hook. Overlapping source cases
across families are not additional coverage. Initialized Menu53/Loading53 and
whole catalog tests were not part of this selection and were not rerun here.

Queue PID9493 finished with exit0 in248.076s; summed child process wall time was
195.320s. Build2's sampled descendant peak was6,285,574,144 bytes; the sampled
test peak was2,459,877,376 bytes. Some short methods finished before an RSS sample:
their recorded0 means no sample, not zero memory consumption. All build/test
leaders and observed descendants were absent at finalization; no guard signal
was needed. Synthetic process-classification checks are monitor checks, not
actual compiler-exec or Windows behavior observations.

## Package, archive and process preservation

The native SwiftPM layout has two sibling regular resource bundles, containing
385 fixture files and102 runtime files. All487 files match their declared bytes
and membership. This is distinct from the earlier build system's duplicated
bundle layout. All root1034 files, candidate1036 files,55 live source code pins
and12 protected context inputs were verified unchanged.

The regular artifact archive contains2480 files and154 directories, totaling
10,038,252,971 logical bytes, including the candidate and final release products.
Bodies, modes, mtimes, membership and distinct regular inodes were verified.
Its manifest SHA-256 is
`a0c3bb22d64718403b321ac5f1657422d09f6c8c765ef9050ebf7791e7a70d9c`.
The separate137-member metadata archive preserves configs, logs, receipts and
frozen helpers:3,164,160 bytes, SHA-256
`758620751d35d870040a489ce3a2d6220baf21f9e13dc502d2cc420dbfecd5ac`.
The failed build remains retained separately. Publication, closure and the
finalizer's subsequent terminal receipt are pinned by the documentation receipt.

Finalizer PID12164 completed with exit0 in34.168s at14:48:59 UTC. Closure recorded
2,376,404,992 bytes of observed free-space decrease within the24GiB allowance,
including concurrent source growth; original40GiB external/6GiB internal reserves
remained intact. The external task is frozen; do not rebuild or write there.

At14:48:59 UTC the same source PID59727/start/full command/cwd/running job were
revalidated:1768 chunks,12 returned Objects and433556355 stores. The original
capture was neither restarted nor signaled. This is a live observation, not whole
Catalog53 return; the initialized source's CW023f must not be conflated with the
older first-menu corpus's CW037f. Existing safety incidents remain open.

## Next task and limits

Next independent task: a bounded read-only preflight mapping the host's actual
pending ticket and staged platform through existing loading/cycle owners to
`Bootstrap.finishLoadedMenu`. Identify saved whole-caller cases and the exact
ownership, failure and final-commit boundaries before extending the driver.
Do not synthesize a child return, reconstruct live owners from expected state,
rerun the successful selection, or promote the candidate into the live-pinned
root. Continue monitoring the same source and audit a new whole-caller publication
when available.

Actual host reply acquisition remains unresolved, including when live clocks
are sampled; prepared clock arrays do not prove that timing contract. Physical
effect delivery, partial backend failure, callback reentrancy, raster/audio/input,
Windows/device and clean-Mac acceptance remain open. The driver currently retains
loading without finishing its child. Independent review, full catalog comparison,
first complete match and the full game objective remain open. This coherent
validation result is committed under WORKFLOW's iterative-commit rule.
