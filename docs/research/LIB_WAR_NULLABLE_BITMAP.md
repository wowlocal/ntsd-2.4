# War preparation: nullable bitmap ownership

Status: accepted for the three retained returned calls below, 2026-09-12.
[Acceptance and exact pins](../evidence/lib-war-nullable-bitmap.json).
This independent card under [CONTINUE_GOAL](../CONTINUE_GOAL.md) advances complete
preparation and the first full Naruto/Sasuke match. The full game goal remains open.

## Game question and retained reference

When an ordinary allocation cannot create an arena bitmap wrapper, does Start
continue, which later layers remain owned, and what does the next Start release?
Use exactly the saved returned s02/call-00, s02/call-01 and s03/call-00 from
[War resource errors](LIB_WAR_PREPARATION_ERRORS.md). The separately pinned
s03/call-01 source fault remains outside these three successful comparisons.

Reference EXE SHA `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
DLL SHA `28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`,
VC80 SHA `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Historical observations came from Unicorn 2.1.4, CW023f, C locale, declared
32-bit segments/FS and allocation/COM responses; they are not Windows heap or
device behavior. This card only reads those completed artifacts and runs Native.
No original executable, source producer, emulator or capture is started.

The prior source audit and inventory remain immutable. Allocation/API records
identify the difference between attempted allocation and a live owner. Full
saved records, masks and chronological observations establish the cross-call
ownership boundary; there is no reason to re-execute the original to recover it.

## Finite contract and implementation

| Case | Allocation requests / owners | Observable outcome |
| --- | --- | --- |
| s02/call-00 | 5 / 4 | First request returns NULL; four later layers load; whole caller returns |
| s02/call-01 | 0 new / 4 retained | Controlled next Start99 returns with no bitmap Release/free; all four owners survive |
| s03/call-00 | 5 / 4 | Last request returns NULL; four preceding layers remain live; whole caller returns |

The layer loader at 40c030 stores NULL and continues after a failed allocation.
NULL creates no wrapper owner, and skips constructor/image requests for that
layer. It does not mean a wrapper exists with a missing surface; that is a
separate open contract. The first-layer sentinel in 40c0e0 already explains s02's
next-call behavior and must not be changed to clear the remaining pointers.

Native bitmap references index actual owned records. Source request ordinals
continue advancing after NULL. For an original Native bitmap count C, s02's
five references become `[0,C+1,C+2,C+3,C+4]`; no empty owner occupies the failed
request's position. The source address tokens retain their declared request
ordinal spacing and do not define Native memory layout.

`OriginalBackgroundSurfaceLayers` accepts an optional construction result;
nil writes a known zero and continues. `OriginalWarPreparation` exposes that
boundary to its enclosing transaction. Existing normal constructors remain
valid callers. The graphics adapter gets NULL from the separately declared
`resourceFailureInput.graphics.nullAllocationOrdinal` and checks it against the
retained allocation event. It compares request counts and actual owner counts
separately, including release lookup and BG pointer normalization.

Each chain first runs the ten accepted bound-preflight calls in Native, producing
its own retained state. Twenty such Native calls overlap ten distinct reference
cases; they are not new original startup executions. The saved prefix-proof
digests link all three error files to those same ten packaged cases.
No source after-state supplies the new Native chain's state or owners.

## Checks, ownership and limits

Root implements the Core/comparator/test changes; `war_contract_review` performs
independent read-only contract and code review. `catalog_test_completion` owns
only the new packaging tool and three fixtures. Initial changes, all input pins,
333 protected fixtures and the finite task boundary are in
`build/research/lib-war-preparation/war-nullable-native-20260912/plan.json`.
Initial Core/test versions are retained under that directory's `before/`.

Acceptance compares all three whole callers: game records and masks, ordered
events, numeric intermediates, generated recordings, bitmap storage and retained
owners. All 48 saved numeric checkpoints remain compared, even though these cases
do not have the success matrix's `matrixOrdinal`. Eleven observer-error trials
cover after NULL, after participants/later owners, after recording and before
outer return, plus late second-Start rollback with the four prior owners intact.
These observer failures are Native rollback tests, not original API failures.

Raw comparisons, exact transport, bundled Native tests, review and archive/Git
verification are separate gates. Retain the 256-case matrix, 22-case preflight,
shared bitmap/background tests and Tournament/Team callers affected by the
common layer-loader signature. Initial limit: three Native correction rounds
before diagnosing the remaining contract, 1800s per initial Native test job,
20GiB new task storage and the unchanged 6GiB internal reserve. Use task-owned
X5 with UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`.

The packager preserves all 107,025,680 original bytes in three existing-format
DEFLATE envelopes totalling 14,446,508 bytes. All 2,225 blob entries/840 distinct
blobs and 30 prefix-proof digest links verify. `package-verification1.json` and
its producer remain unchanged; `package-verification2.json` adds the explicit
bound-index proof check. These are transport checks, not Native acceptance.

## Native result and preservation

The raw comparison passed in 19.231s after a 277.58s release build. The same
candidate then passed all 17 bundled regression methods in 510.590s, build 0.32s,
with all `NTSD_*` raw overrides removed. The new bundled comparison took 18.945s;
the retained 22-call preflight took 16.700s and the 256-call matrix 187.341s.
Team Tournament, Tournament, retained arena release and shared bitmap/background
tests passed through the changed layer API. Both jobs are terminal, exit 0.

Per run, all three whole returned callers compare 3,838 ordered front events,
48 numeric checkpoints and retained ownership; all 11 coupled rollback trials
pass. The raw/bundled runs repeat the same three cases and 11 trials. There are
18 test-method executions and 17 unique methods, not 18 distinct tests or six
new source cases. The per-case diagnostic prints cumulative allocation requests:
s02/call-01 retains five prior requests but makes zero new graphics requests.

The first Native candidate passed without code or expected-data corrections.
Independent contract review found no remaining material code blockers. The
777-file tested Native package matches the working files, every staged Native
Git blob and the complete 3,869,726,720-byte Native archive. All 333 prior fixtures
remain unchanged; the package contains 336 regular fixtures. Eight protected
source/evidence inputs are unchanged.

A separate 129,198,080-byte evidence archive verifies all 45 member files and
129,111,328 content bytes, including the three returned raw cases, the separate
s03 fault and sidecar, source metadata, initial versions, reviews and terminal
test records. The prior full source corpus remains preserved in its own study.
Archive checks do not establish Windows/device behavior. Exact SHA-256 values,
commands, timings and archive manifests are in the acceptance JSON and the
task directory. Internal free space was 9,417,273,344 bytes at evidence archiving;
the original 6GiB reserve remains in force.

## Remaining scope

The initial source fault after four releases in s03/call-01 remains separate.
Other partial-surface, graphics/music/replay errors, private-dimension provenance,
whole War gameplay, full own catalog/startup/loop/application, complete matches,
all content/network and Windows/device/clean-Mac verification remain open.
Existing safety incidents remain open; neither this Native work nor this goal
authorizes retries or clears the prior refusals.
The next independent Native card uses the six saved returned partial-surface
cases s04..s09/call-00. Their wrappers exist even when no usable surface remains;
their subsequent source faults stay separate. See [CURRENT_WORK](CURRENT_WORK.md).
