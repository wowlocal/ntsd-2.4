# Library transform ownership and retained slot-prefix comparison

This completes the pending Native implementation from
[the frozen plan](LIB_TRANSFORM_PLAN.md) using already published NTSD results.
The game question is how library states `4000..<4999` change the selected Object
and affect the remainder of the same post-draw slot prefix, including aliases,
activity, particles, resource updates and scheduling. It advances the shared
library-enabled gameplay handler; the initialized whole loop remains open.

The reference is the original EXE SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`
and bundled DLL SHA-256
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
The saved development harness used Unicorn, declared API responses and x87
control word `027f`. This completion reads and packages its immutable results;
it executes only Native tests. No EXE/DLL or source producer is rerun, and no
previous safety incident is cleared by this independent work.

## Contract and owned storage

The library branch finds the first catalog ID equal to `state-4000`. A match
changes Actor `+368`; it retains the current frame and `+318`, unlike the
`8000..<9000` branch. The following write at Actor `+7b4` contains the declared
Actor pointer token on a match, the catalog count on a positive-count miss,
or zero when count is nonpositive. The existing common prefix then continues.

An Actor owns `0x420` bytes. The source harness separates allocations by `0x500`;
its `+7b4` write reaches another record at `+2b4`, or declared external backing
for the last allocation. These are controlled storage observations, not a
Windows heap layout or a native allocation rule. The low-level trace is needed
to identify that write and its same-call consumers without silently enlarging
the Actor or substituting a different field.

`OriginalLibTransformBacking` therefore accepts explicit destinations in owned
Actor or external records, with separate Actor identity tokens. Bindings derive
from declared allocation inputs, never source after-state. Missing destinations,
missing required tokens and invalid extents reject. Alias resolution uses the
actual Actor identity. The common `OriginalPostDrawSlotPrefix` stages World,
Actors, globals, retained index and backing together; a late observer error
publishes none of those partial changes. Callers must also stage external effects.

## Retained evidence and comparison

| Saved corpus | Returned cases | Ordered events | Recorded extended writes | Observed instruction starts |
| --- | ---: | ---: | ---: | ---: |
| `lib-transforms.json` | 1,688 | 2,827 | 371 | 744 |
| `lib-transform-boundaries.json` | 72 | 653 | 68 | 568 |

The main corpus retains all 897 pristine prefix cases, field-for-field equal after
removing only the newly recorded tail/write fields. It adds library state,
lookup/count/duplicate-ID, retained-frame and same-call continuation cases.
The boundary corpus contains 60 alias and 12 activity cases. These are separate
declared inputs, not proof that every state is naturally game-reachable.
Instruction counts are unions within each corpus and are not branch coverage.

The Native comparator checks each returned terminal boundary, all normalized
World/400-Actor bytes and defined masks, globals, retained index, ordered events,
and external backing bytes/masks. Expected backing masks derive from the saved
write records; they never initialize Native state. The 439 extended-write records
remain intact, but this completion does not claim a per-store Native trace audit
of every recorded before/value pair. Observed instruction sets are checked as
corpus metadata, not compared to the Swift instruction stream.

Four separately saved cases end in `UC_ERR_WRITE_UNMAPPED` at DLL `36001112` when
the final Actor has no mapped destination. Native explicitly rejects the same
unavailable backing and rolls back the entire call. Those four rejections are
not source/native matches. Five more rollback trials cover missing destination,
missing Actor token, invalid external index, short destination extent and a late
observer. Three retained miss/count cases also compare without Actor tokens.

## Publication and verification

`tools/package_lib_transform_references.py` reads only saved captures. It checks
the fixed raw SHA, summaries, input metadata, case/event/write counts, four fault
records and the pristine prefix, then packages both complete raw JSON files into
the existing `{count, sha256, deflate}` test format. Two regular bundled fixtures
total 92,173 bytes and recover exactly 1,730,370 raw bytes. No original expected
value, mask, producer, source report or pristine fixture is edited.

The pre-completion pending files and their hashes are retained under
`build/research/pending-completion-20260912/initial-pending/`. The parent directory's
`plan.json` pins the initial 22 files and all 325 pre-existing fixtures. The transport report
is `transform-package-verification.json` in that same task directory.

Release comparison and shared scheduler/loader/War regressions passed from a
manifest-pinned copy on task-owned X5, without raw fixture overrides: 40 tests,
288.070 seconds, build 328.90 seconds. The four transform tests took 1.879 seconds.
After adding the separate catalog negative-close fixture, all four file tests
passed in 0.549 seconds, build 142.49 seconds; no Core or transform file changed.
That is 44 test executions and 41 unique tests across both runs. Jobs, commands,
preservation and full archive checks are in the shared
[completion evidence](../evidence/pending-native-completion-2026-09-12.json).
A separate reviewer checked the storage contract, comparator, retained data and
rejection semantics without running original code.

The first test-file patch request was rejected before editing because it tried
to delete and add the same path in one patch; a normal update retained the old
version in the initial backup. This did not change source bytes or Native rules.
Historical reports with `nativeCompared=false`, the earlier 1,688-case Native
log, the published boundary faults and original work notes remain unchanged.
The boundary corpus has published terminal results but no separately recovered
producer exit-code record; this document does not invent one.

## Open boundaries

The 29-row DAT survey is static presence evidence, not natural gameplay
reachability. Native uses declared ownership, not an inferred Windows heap.
The full library-enabled initialized loop, application integration, real
Windows/device behavior and a complete match/game remain open. The separate
War resource-error Native contracts remain queued in [CURRENT_WORK](CURRENT_WORK.md).
