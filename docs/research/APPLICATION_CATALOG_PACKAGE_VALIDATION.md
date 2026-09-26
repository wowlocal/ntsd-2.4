# Catalog package validation — complete comparison and artifact gates passed

2026-09-26. The unchanged [catalog package candidate](APPLICATION_CATALOG_PACKAGE.md)
has passed the finite [validation plan](APPLICATION_CATALOG_PACKAGE_VALIDATION_PLAN.md):
fresh build, exact package bytes, all76 Native comparisons, standalone Core input
reading and complete artifact/archive verification. Queue42094 and finalizer29333
are terminal0 and absent. The task is frozen; do not rebuild or rerun it.
[Publication](../evidence/application-catalog-package-validation.json),
[closure](../evidence/application-catalog-package-validation-close.json).

This closes the production catalog input dependency of the existing Host within
the declared input domain. Independent contract review remains unavailable/open;
author verification is not independent review. Root Native promotion, retained
backend delivery, actual app/Windows/device/clean-Mac/full-match/full-game acceptance
remain open. EXE envelope was not recalculated. No original code executed.

## Fresh build and package

Preparation24323 exited0 in15.658s after verifying and APFS-cloning all2241 Native
files from manifest41725682877ec5430eca64c165ac46f857e25af8ea534c7ed388208293cfde54.
The clone retains exact bytes/modes/ns mtimes with distinct inodes. Root1034,
prior1040, candidate2241 and55 source producer pins remain separate and protected.

Build25257 exited0 in311.585s with no guard or residual process. Observed peak
RSS was6,309,658,624 bytes; this is a sampled value, not an exact allocation peak.
Fresh output/source verification finds192 Core,61 Reference and271 test Swift
sources, plus the expected generated resource accessors. The actual target is
arm64-apple-macosx14.0, optimized Swift5 language mode, -enable-testing, two jobs.
The environment is Apple Swift6.4/Xcode macOS27 SDK as recorded by the installed
toolchain. Existing compiler warnings are retained in the log.

The63,290,920-byte XCTest binary and1,686 packaged files were independently
verified against the candidate:385 unchanged test fixtures and1,301 ordinary
Core resources, including all1,199 OriginalCatalog package files. Build/linkage,
package-byte comparison and XCTest acceptance remain distinct gates.

## Standalone Core read with prohibited development inputs

The validation-only CatalogRead client links the exact193 fresh Core objects
(192 source files plus generated bundle accessor) and six codec objects.
No Reference/XCTest object or fixture is linked or installed. Link dependencies
were inspected; the ordinary app has1,201 files: executable, Info.plist and1,199
catalog package files. The client source/objects/binary, commands and resource
bytes are pinned before execution. Client compilation37988 exited0 in1.145s.

The app resides at
/private/tmp/ntsd-catalog-package-validation-20260926-01a0dc49/CatalogRead.app,
outside checkout and research volumes. Its declared sandbox-exec profile denies
file reads below the repository, /Volumes/X5 and /Volumes/T7. Three fixed probes
actually returned the Cocoa no-permission boundary for the existing repository
AGENTS file, X5 candidate manifest and T7 root; missing paths do not count as
evidence of denial. These are intentional local filesystem restrictions, not an
original-game or model safety refusal, and no broader OS equivalence is inferred.

The same restricted process then calls the public bundled reader successfully:

| Observed input | Count / bytes |
| --- | --- |
| File inputs |521 /19,144,880 |
| Image inputs |669 /628,035,022;665 BMP and4 embedded DIB |
| Music inputs |8 /14,455,318 |
| Pixels |227,762,176 total;227,759,411 defined;2,765 remain unknown |

The reported bundle path is the actual relocated app and its manifest identity
matches the compiled reader pin. After moving only this app's package aside,
the next run returns the expected missing-app-package boundary; it cannot fall
back to the developer module resource. All original app package bytes are then
restored and reverified. Queue40449 exited0/18.379s; all five checks pass and all
child processes are terminal. Its672,650,373 internal artifact bytes remain
below the declared2GiB bound. No window, input device, WMA decoder or audio output
was exercised; this is a standalone-data gate, not clean-Mac game acceptance.

The standalone monitor derives from the existing guarded runner. Only its fixed
command/phase/input domain, exact own internal cwd and sandbox-exec-to-CatalogRead
transition extend the compiler/test domain. PID/start identity, descendant
ownership, RSS/time/space guards, action revalidation and reaping remain in force.
The exact adaptation and positive/negative cwd/transition checks are recorded;
there is no blanket executable/cwd exception.

## Complete Native comparison

The exact76-method selection passed:4 new reader methods,3 direct full-catalog
methods and all69 inherited host/caller methods. Queue42094 exited0 after2760.053s;
summed test process time was2498.359s and sampled peak tree RSS12,099,895,296 bytes.
Every method has its unique named pass, three one-test/zero-failure summaries,
Selected-tests pass and exit0, with no guard, signal or residual owned process.
Short-process RSS0 means no sample, not proven zero memory use. The inherited
methods kept their original ordinal-based time/RSS bounds after seven prepends.

The reader methods compare complete file/image maps and origins against the old
input reconstruction, preserve owned snapshots and absent/empty overlays, reject
eleven missing/corrupt/duplicate/conflicting/extra/nonregular controls without
partial publication, and verify strict relocated-app lookup. The three direct
catalog methods cover the owned complete return, late Stage cancellation and
prepublication cancellation followed by a fresh successful retry.

The existing69 bodies, expected records, masks and controls remain unchanged.
Their actual input producer now uses the ordinary original-byte package. Full
startup/menu/loading/selection/launch parents, neutral17-return chain, both active
48-call schedules, both paused14-call schedules, late rollback/retry and foreign/
consumed-ticket/reentry checks all passed. No schedule was shortened or split.
The old input reconstruction is comparison-only; no expected after-state, captured
device result or unknown source backing becomes a Core runtime input.

The previously corrected one-anchor XCTest reader recognized the buffered output
case directly in this run. Its unique-method/line-end/suite/exit/guard/process
predicates were retained. The historical nonpass and recovery controls remain in
the earlier closed task; current tests were not rerun to repair classification.

## Preservation and archives

Finalizer29333 exited0 in101.459s. It reverified root1034, prior1040, base/current
2241-file Native memberships and bytes, all55 source-code pins, protected plans,
incidents/history, compiled outputs, resource membership and the standalone app's
installed bytes/linked inputs/configurations/results. The complete previously
published156-member progress archive was also reverified; its hash is unchanged.

The regular artifact archive contains6093 files,242 directories and no links:
2241 candidate files,2651 release-product files and1201 standalone app files.
Its12,046,872,540 logical bytes were verified by full membership, contents, modes
and nanosecond mtimes. X5 members use distinct-inode APFS clones; the internal app
uses ordinary cross-volume copies with the same complete verification. The three
implicit archive parent directories are declared separately from source directories.
The381-member PAX metadata archive is8,591,360 bytes, SHA256
77bd31ba4b426df6e5694af38ecb44e76f1009229a5bb799fe8ee48bb4bcb0e6;
each member's name/body/mode/nsmtime was checked, not just the archive checksum.

The final external free space is173,601,914,880 bytes and internal free space
59,041,873,920 bytes. Observed external decrease1,837,572,096 bytes remains within
the28GiB physical allowance;40GiB external/6GiB internal reserves and17GiB source
commitment were retained. Internal standalone artifacts remain672,650,373 bytes.
The frozen task is build/research/application-catalog-package-validation-20260926.
No evidence was deleted and no live or completed source was restarted.

The initial unexecuted finalizer and its prelaunch revision2 remain preserved.
Two read-only status observations encountered missing job paths during test56/74
admission, after the queue selected a phase but before the child wrote its job.
Both errors and later live-process observations are preserved separately; neither
was a Native failure, a stopped queue or a reason to rerun a test. The dated start
and57-method checkpoints remain in their immutable receipts and archived study
copies. They are historical observations, superseded by the terminal76 result.

## Application readiness and next dependency

The accepted comparison boundary now includes self-contained production catalog
inputs through the unchanged full host/caller comparisons. This is not a complete
original application-source comparison: source59727 remains terminal at its
previous34-Object publication boundary, and full137 return plus saved transport/
provenance audits remain open. Existing safety incidents are unchanged. Controlled
API/time/device responses are not measured Windows or actual macOS device behavior.
WMA bytes are installed, but decoding/playback, native rendering/input/audio and
a clean-Mac full match have not been exercised by this task. NTSDApp still uses
Practice and has no consumer for the recovered Host's committed batches.

NEXT: implement and compare a retained per-commit delivery context for all three
Host.Batch variants in a fresh candidate derived from this2241-file tree. Use the
existing [host/app preflight](APPLICATION_HOST_APP_PREFLIGHT.md), not a new broad
inventory. Freeze a finite contract and cases before implementation: a delayed
consumer must resolve the actual Native resources of its own commit after later
host commits; startup/iteration/loaded order and generation-qualified identities
must be retained; failed preparation must publish neither a batch nor partial
owners; previous queued batches and all existing whole-caller comparisons remain
intact. Comparison must use independently declared owner/event expectations, not
the proposed delivery producer as its own oracle. Preserve the fixed current
candidate and root dirty inputs; review remains an explicit open gate.

Actual device observations/reservations, cancellation and post-commit failure
semantics are the subsequent prepared-backend dependency. They must precede real
AppKit presentation/audio/file delivery: queuing an operation cannot supply the
successful reply already consumed by Core, and Swift rollback cannot undo device
side effects. This next owner-retention step removes a concrete app integration
obstacle on the path to the complete Naruto/Sasuke District match and full game.
