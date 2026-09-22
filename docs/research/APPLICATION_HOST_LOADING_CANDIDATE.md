# Host loading continuation candidate

**2026-09-22: implemented in an isolated candidate; all six changed Swift files
pass syntax parsing. Compilation, the42 selected tests and independent review
remain open.** This connects host loading preparation and the final outer commit;
it does not install a device backend or replace the practice app.

The [frozen plan](APPLICATION_HOST_LOADING_CANDIDATE_PLAN.md) implements the
[loading preflight](APPLICATION_HOST_LOADING_PREFLIGHT.md) on the previously
[validated host](APPLICATION_HOST_TRANSACTION_VALIDATION.md).
[Publication](../evidence/application-host-loading-candidate.json),
[reviewable patch](../evidence/application-host-loading-candidate.patch),
[external closure](../evidence/application-host-loading-candidate-close.json)
and [documentation receipt](../evidence/application-host-loading-candidate-docs.json)
identify the exact inputs, products and gates. Base HEAD is
`6bef0d1bf4e068274dc8f6d90b2b29e879420eea`; actual input is the pinned1036-file
host tree, including its dirty baseline, not that Git revision alone.

## Implementation

Each `Session.PendingLoading` now owns an opaque per-suspension UUID, copied
unchanged through existing child values. An internal comparison checks this
identity together with the existing Session UUID/revision. It distinguishes two
attempts from copies of the same committed Session. It is transfer metadata,
not a game resource identity, clock, source address or game RNG input.

Bootstrap uses the same response-exhaustion check on an ordinary commit and a
loading suspension. An extra queue/window/surface/lifecycle reply or missing
required reply leaves the caller unchanged. This checks the prefix packet only;
the final tail remains a separate lazy callback. Existing game handlers and
timer/numeric operations are unchanged.

`HostSession.prepareLoadedMenu` exposes the actual pending entry, startup owner
and, when present, a loaded cycle made from current committed owners. It clones
the pending platform before invoking explicit child providers. The returned
child must carry the exact retained ticket and an actual returned-menu outcome.
Aliases are validated before storing the child/platform privately. Preparation
publishes nothing and leaves the committed snapshot unchanged.

`finishLoadedMenu` accepts no replacement child. It clones the prepared platform
and delegates to `Bootstrap.finishLoadedMenu`, which resumes only the original
outer timer/Sleep/counter tail. After the final observer succeeds, the host
installs Bootstrap/platform, clears pending/prepared storage and publishes one
`Batch.Contents.loaded(LoadedCommit)`. That journal already contains prefix,
loading/input/menu and outer work. Graphics remains another view of those same
effects. A failed tail keeps the actual prepared child and platform for retry;
it does not require redoing the prefix, catalog or menu.

The existing lock/reentry guard covers preparation and completion. Missing,
already prepared, consumed and different-attempt states have explicit boundaries.
Inspection exposes value child snapshots and independently copied platform
snapshots. Providers must mutate only the staged platform or local value owners;
the generic Core environment assignment is not a deep copy of arbitrary class
members. No observer performs physical IO. Real provider independence and device
failure behavior remain separate contracts.

Three Core files change: HostSession, Bootstrap and MenuSession. Three test files
change: a new HostLoadingTests file and optional/factored helpers in MenuInputTests
and LoadedCycleTests. Package.swift,385 fixtures and102 runtime resources remain
unchanged. Root Native is untouched.

## Written comparison and regression coverage

The new test parent runs saved input case47 through the actual host and completes
all old whole-parent checks before continuing. It never attaches a new host to an
expected after-state or reconstructed Bootstrap. The existing common/catalog/pool/
input composer can now consume that actual retained entry. Its original checks
remain in the helper. The original three cycle test bodies and the moved complete
final-state comparison body were verified byte-identical.

Four new methods are written to cover:

- Fresh loading/menu and three cached returned cycles for both bitmap backings,
  using existing resource and independent graphics comparisons, followed by the
  explicit next-selection input boundary without claiming a fourth return.
- Failed child preparation and time/Sleep/final-hook failures, with independent
  platform copies, prior queued keyboard batch retained, same prepared-child
  retry, rejected reentry and one-time loaded handoff.
- Different same-revision tickets produced by an actual sibling Core attempt,
  a different host, stale/consumed results, valid exact-ticket copies and rejected
  completion without a prepared child. Existing Core foreign/stale controls stay
  selected as regressions.
- Six prefix-packet controls: extra queue/window/surface/lifecycle replies and
  missing queue/surface replies, followed by the normal unchanged source comparison.

The fixed selection has42 methods: four new,25 retained host/startup/menu/input
methods, five LoadedMenu, three LoadedCycle and five InitializedMenu/Loading
methods. None ran in this candidate phase. The new tests describe intended
coverage; a parsed test body is not evidence that these cases execute or pass.
Overlapping source cases are not additional coverage. The initialized regressions
were added because Bootstrap/ticket handling changed; the previous25-method run
did not include them.

## Verification and preservation

Preparation PID17143 completed with exit0 in2.643s. All1036 baseline files were
APFS-cloned as regular distinct inodes and checked by body, mode and membership.
The new candidate contains1037 files. Candidate/root/baseline manifests, the55
live source code pins and14 protected context inputs were rechecked. No old build
cache was imported and no original program was executed for this phase.

Installed Swift frontend PID18895 parsed the six changed files with exit0 in
0.055s and empty output. Its complete command, minimal environment, input hashes,
start/cwd/identity, timeout and terminal receipt are retained in the task. This
checks syntax only; names, types, linking and runtime behavior remain unverified.
Both preparation and parse PIDs were absent before finalization.

The40,163-byte patch applied to a separate small copy and reproduced every
changed file byte-for-byte: SHA-256
`297e932e0182e99605bf2836a57f3cf9e83b759c358d5e12b9ba9009dee8ef8c`.
Git's whitespace check flags the patch's two single-space blank context lines;
the exact warning is retained in the documentation receipt. Those are unified
diff context markers, not trailing whitespace added to Swift. Preserve the patch.
The22-member changed-file/metadata archive was read back completely, including
bodies, modes, exact PAX mtimes and membership:716,800 bytes, SHA-256
`b2164e2ca36f9d3b35244da190ccbeedfab1b6591068c2cbdcf5bcf47f2f9fd0`.
It references the pinned full baseline and retained candidate; it does not claim
to duplicate all4.46GB of unchanged payload. Root helpers and plans are preserved
in the task. A missing earlier inline-finalizer file discovered during a read-only
lookup is documented; the previous candidate was never reopened or rerun.

Finalizer PID19435 completed with exit0 in7.464s. The task closed at15:29:37 UTC
with272,220,160 bytes observed free-space decrease within1GiB, including concurrent
source growth. Original40GiB external/6GiB internal reserves remain unchanged.
The task and candidate are frozen. Publication/closure and the finalizer's
subsequent terminal receipt are separately pinned by the documentation receipt.

The same original source PID59727/start/full command/cwd/job was verified live at
15:29:37 UTC:2039 chunks,14 returned Objects and500022617 stores. It was neither
restarted nor signaled. Whole Catalog53 return/comparison remains open.

## Next gate

Create a separate bounded validation task, recheck X5/source budgets, clone this
exact candidate, compile Core and dependent targets with release testability,
verify package bytes and run all42 declared methods. Preserve every diagnostic,
guard or mismatch before any separately identified correction. Do not rebuild
inside this frozen task or use the old executable to validate changed Core.

Root promotion, independent ownership/comparator review, later typed input and
Start/prelude retention, live clock/input/resource providers, physical IO ordering
and failure recovery, callback reentrancy, raster/audio/window, Windows/device and
clean-Mac acceptance remain open. Injecting a stop at the fourth input boundary
is not a shipping continuation strategy. Existing safety incidents and the first
complete match/full game objective remain open. The candidate is committed under
WORKFLOW's iterative-commit rule with its syntax-only status explicit.
