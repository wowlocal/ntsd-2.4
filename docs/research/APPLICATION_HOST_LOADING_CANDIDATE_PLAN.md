# Host loading candidate — frozen implementation plan, 2026-09-22

Follow [WORKFLOW](WORKFLOW.md), the current handoff and the
[completed loading preflight](APPLICATION_HOST_LOADING_PREFLIGHT.md). Implement
the host's first returned loaded menu and subsequent cached returns on the actual
retained Bootstrap/platform. This removes its loading stop toward the first
interactive match. Full game, actual devices and later typed child outcomes stay
open. Base HEAD `6bef0d1bf4e068274dc8f6d90b2b29e879420eea`.

Actual inputs are the validated1036-file host candidate, its25-method selection,
root1034 live-pinned inputs and saved loaded-menu/cycle/initialized regressions.
Reference EXE SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
DLL/CRT/resources remain pinned by the preceding preflight. Existing source
corpora supply expectations; do not edit them, masks, fixtures or resources.
No original execution, historical capture/auditor rerun, device IO, refused
operation, root promotion or dependency installation is part of this phase.

## Finite implementation

Clone the validated candidate into the fresh task below. Add opaque per-suspension
identity to PendingLoading, preserving existing UUID/revision checks and all game
RNG/numeric state. Require all prefix packet replies consumed on both ordinary
commit and loading suspension. Host preparation gets the exact pending entry,
actual startup or current loaded-cycle owners and an independently cloned pending
platform. It stores a real returned child privately, with no publication. Final
completion clones this prepared platform, resumes only the actual outer tail and
commits Bootstrap/platform plus one loaded batch. Failure retains the prepared
child for retry; earlier batches and committed owners remain untouched.

Use existing whole-parent composers and comparators. Test-only factoring may
expose the actual host after all input-parent checks, and share the existing
catalog/pool/input construction and final-commit comparison. Never initialize the
host from an expected snapshot or attach a fresh host to an already reconstructed
Bootstrap. Keep source request/state/mask/owner/graphics projections unchanged.

Write four new methods in OriginalApplicationHostLoadingTests:

1. testOwnFreshLoadingAndThreeCachedCyclesUseHostHandoff: both existing bitmap
   backings, full first child and three cached returns, then the retained next
   input boundary without fabricated completion.
2. testPreparedChildAndPlatformSurviveLateFailuresAndRetry: preparation failure,
   current-platform copy independence, time/Sleep/final-hook failures, retry of
   the same prepared child, no repeated prefix/menu, reentry and one-time handoff.
3. testDifferentSameRevisionTicketsAndRepeatedCompletionAreRejected: exact-ticket
   copies valid; different same-revision, foreign, stale and already consumed
   results rejected before outer callbacks, retaining existing Core controls.
4. testLoadingPrefixRequiresExactlyItsPreparedReplies: extra queue/window/surface/
   lifecycle and missing replies reject without pending publication or host-state
   leakage; correct prefix remains accepted. Controls are Native-only boundaries.

Freeze42 methods: these4, all25 previous host methods, all5 LoadedMenu methods,
all3 LoadedCycle methods and all5 InitializedMenu/InitializedLoading methods.
These retain full catalog/pool parent comparisons in the loaded composers.
Do not count overlapping cases as additional source coverage. No fourth input
child or Start/prelude host completion is claimed; those need later typed retention.

## Storage, process and validation boundary

Task `/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/application-host-loading-candidate-20260922`,
alias `build/research/application-host-loading-candidate-20260922`. Verify mounted
APFS UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`; retain40GiB external/6GiB internal
reserves and the concurrent source's17GiB gross budget. This candidate phase has
a1GiB observed-decrease allowance including source growth, stop at896MiB with
128MiB for closure metadata. Require at least58GiB external and7GiB internal at
start. APFS clone regular files only, verify all bodies/modes/membership and
distinct inodes; no build caches. Do not delete evidence or lower reserves.

Reuse existing pin/clone/job/verification procedures. Record preparation and
syntax command PID/start/full command/cwd/terminal status. Parse changed Swift
with the installed toolchain and a minimal environment; timeout300s. This phase
does not typecheck/link or run XCTest. Fresh Core/dependent compilation and all42
methods need a separate bounded validation task; never reuse the old binary as
evidence for changed Core. Preserve drafts/failures before corrections; at most
three identified rounds before revisiting the contract.

Root mutable paths: this plan, APPLICATION_HOST_LOADING_CANDIDATE.md,
docs/evidence/application-host-loading-candidate*, task preparation/publication
helpers and own CURRENT_WORK/RESEARCH_MAP paragraphs. Swift edits belong only to
the new candidate. Baseline candidate, root Native, source producers, closed tasks,
instruction archive and expected bytes remain protected. Revalidate live source
PID/start/command/cwd/job; never restart or signal it for silence.

Owner is root author; independent review is unavailable and remains open. Verify
the reviewable patch round-trip, changed-file/metadata archive, full candidate,
root1034/source55 pins, regular resources, plan and helpers before closure.
Freeze the external task and commit only this coherent candidate increment with
the42-method selection and explicit syntax-only status. Existing hooks remain
enabled. Existing safety incidents and full-game/device gates remain open.
