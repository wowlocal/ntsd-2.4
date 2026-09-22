# Application transaction driver candidate

**2026-09-22: implemented in an isolated candidate; syntax passed. Fresh
compilation, tests, independent review and root promotion remain open.**
The [frozen plan](APPLICATION_HOST_TRANSACTION_CANDIDATE_PLAN.md) follows the
[host preflight](APPLICATION_HOST_TRANSACTION_PREFLIGHT.md). This advances the
recovered application's persistent owner and effect handoff; it does not replace
the practice app or supply actual window/input/device providers.

[Publication](../evidence/application-host-transaction-candidate.json),
[reviewable candidate patch](../evidence/application-host-transaction-candidate.patch)
and [external closure](../evidence/application-host-transaction-candidate-close.json)
identify the exact files. Candidate and metadata live at
`build/research/application-host-transaction-candidate-20260922/` on the verified
task X5 volume. Base HEAD is `e898b97117a73f2aeebc7b4cbc75579e6ac42ca3`, but the
actual input is the pinned 1034-file dirty Native tree, not that Git revision alone.

## Implementation

New `OriginalApplicationHostSession<Platform>` owns one Bootstrap and an
independent startup-platform copy. Each iteration receives immutable input
packets prepared against a new staged platform and the current committed State.
Core retains control of message retrieval, timer decisions, resource creation,
RNG, state/mask aliases and the ordinary first-menu return. The host driver
accepts no expected after-state.

Startup and a returned menu iteration commit their Core owner and platform
together. A failed attempt keeps earlier committed owners, queue positions and
reservations. An actual loading suspension retains the exact `PendingLoading`,
prepared inputs and staged platform; it publishes no tentative effect and rejects
another outer iteration. This phase deliberately does not dispatch the loading
child or implement `finishLoadedMenu` delivery.

Committed startup/iteration batches have host-only monotonic handoff ordinals.
`takeCommitted` removes one batch and cannot return it again. The driver preserves
the original ordered operation/effect list with its overlapping resolved graphics
metadata. It does not render both representations, flatten graphics ahead of
sound, perform physical IO or promise recovery after partial backend delivery.
Value snapshots expose committed Core state; platform inspection returns another
independent copy. A recursive lock serializes access and an in-flight guard
rejects same-thread reentry into mutation/handoff methods. Observations may read
the previous committed snapshot. Callbacks must remain synchronous and must not
wait on another thread trying to enter this locked owner. Actual device callback
behavior and concurrent-thread tests remain open.

The existing `OriginalApplicationBootstrap.step` now accepts optional first-menu
initialization and forwards the existing `bodyProduced` diagnostic hook. Passing
nil uses the already implemented Session contract for subsequent input/menu
iterations. All old callers still pass their same initialization value. This
small forwarding change is why validation must rebuild Core and dependent
targets; the previously linked binary cannot test this candidate.

Seven candidate files differ from the baseline: two Core files (new driver and
Bootstrap), a new host test file, and optional wiring in BootstrapTests,
MenuReturnTests, MenuInputTests and WinMainStartupTests. Package.swift is unchanged.
Root Native remains unchanged; the patch is the repository's reviewable copy of
these unpromoted changes.

## Comparison wiring and proposed validation

The old test composers retain their default Core path, all expected states/masks,
resource checks, event projections, graphics comparisons and terminal boundaries.
An optional path routes the same startup, resize, first menu and input iterations
through the new owner. The input path retains the actual host Bootstrap from its
parent; the existing reconstructed diagnostic view is compared, then replaced
by that actual owned Session for the host path. No source after-state initializes
the driver.

Host-only queue-position and reservation sentinels in the test platform are copied
with the staged adapter. They measure transaction isolation and are never game
state. The new five methods are written to cover:

- All 48 first-menu parent attempts using the committed-batch handoff, preserving
  the separate NULL-bitmap rejection.
- The existing 17 first-menu late failures with earlier commits retained.
- Case0 startup, resize and first-menu failures at the final commit hook followed
  by successful retries of the same prepared inputs. Inspection-copy mutation,
  rejected reentry and one-time batch removal are also asserted.
- All 50 saved input chains on the same host owner, including retained actual
  loading tickets, staged host cursors and rejection before a repeated prefix.
- The existing six startup late controls and a same-instance staged-copy rejection.

`selected-methods1.json` freezes **25 methods in eight families**: the five new
host methods plus Bootstrap2, MenuReturn2, MenuInput4, StartupInputs4, Graphics3,
MessageLoop3 and WinMainStartup2. This is a future validation selection, not a
pass count. No XCTest method ran in this phase. The same-input retry controls
are at the final hook; the 17 earlier failure positions are separate rollback
controls, not 17 independently completed retries.

Author inspection found an error in the first new packet projection: saved
`windowDefault` rows are `kind=queue/request.kind=windowDefault`, and clear rows
are `kind=front/event.kind=clear`. The corrected filters keep the original
request comparators. `draft1-input-wiring.swift` and `author-review1.json` retain
the draft and correction. No failed expected value was edited or excluded;
the correction preceded syntax parsing. This was author inspection, not
independent contract review.

## Verification and preservation

Preparation PID97801 completed with exit0, cloning all 1034 regular files from the
existing X5 baseline using APFS clonefile. Full bodies, modes, membership and
distinct regular inodes were verified. No build caches were imported. The new
candidate has 1036 files; all 385 existing fixtures and 102 runtime resources
remain unchanged. Root and baseline 1034-file trees, all 55 live source code pins,
the plan/producer/manifests and immutable instruction archive were checked again.

Swift frontend PID99133 parsed all seven changed files with exit0 in 0.262s and
empty output. Its full command/start/cwd, minimal environment and terminal status
are saved in `parse1.job.json`; both it and the preparation PID were then absent.
Parsing checks syntax only, not types, linking, packaging, ownership behavior or
source equivalence. A fresh compiled validation phase is required.

The seven-file text patch applied in a separate small task-owned directory and
reproduced every candidate changed file byte-for-byte. The 22-member changed-file
and metadata archive was checked for complete body, mode, mtime and membership:
SHA-256 `8643f9a5dd44e9c1c73ea3672f1dd4defe3af8616b60d2d9606303e03b1b7b02`.
It references the pinned full baseline and retained regular candidate; it does
not pretend to duplicate the entire 4.46GB payload. Publication, closure and
the finalizer's subsequent terminal receipt are separately pinned by the
[documentation receipt](../evidence/application-host-transaction-candidate-docs.json).

Finalization PID99726 completed with exit0 in 7.431s. The external phase closed
with 218,611,712 bytes observed free-space decrease within 256MiB, including
concurrent source growth. The original 40GiB external/6GiB internal reserves
remain unchanged. Candidate and external task are frozen; do not rebuild or
write new outputs there.

At 14:02:55–14:03:02 UTC the same original source PID59727/start/full command/cwd/job
were verified live: 1462 chunks, ten returned Objects and 358498342 stores.
No original code was newly executed for this candidate and no source process
was restarted or signaled. Whole Catalog53 return and comparison remain open.

## Next task and limits

Freeze a separate validation task, recheck current X5 space and source budget,
then compile the changed Core and dependent targets and run the declared 25
methods against exactly this candidate. Preserve fresh compiler diagnostics,
all package bytes, whole-parent comparisons, guards and failures. Prospective
12GiB build space from the plan is not a measured build size or a reopened
candidate allowance. Any correction requires a distinct candidate/record.

Independent review is unavailable and open. Actual platform reply preparation,
physical IO ordering/failure handling, input/time mapping, raster/audio/window,
Windows/device and clean-Mac acceptance remain open, as do registered safety
incidents and the full game objective. This increment is committed under the
iterative-commit rule; no candidate code has been promoted into the root runtime.
