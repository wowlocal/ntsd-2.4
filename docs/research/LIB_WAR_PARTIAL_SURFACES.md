# War preparation: retained partial surfaces

Status: accepted for the six retained returned calls below, 2026-09-12.
[Acceptance and exact pins](../evidence/lib-war-partial-surfaces.json).
This card advances ordinary resource handling for full preparation and the native
game in [CONTINUE_GOAL](../CONTINUE_GOAL.md).
It follows the accepted [nullable allocation contract](LIB_WAR_NULLABLE_BITMAP.md).
The full game, complete matches and own application remain open.

## Game behavior and reference boundary

Recover the state left by a first or last arena bitmap whose image is missing,
whose CreateSurface call fails, or whose SetColorKey call fails. All six original
whole War callers return with five wrapper owners. A missing usable surface does
not mean that no wrapper was allocated.

Read only the completed s04..s09/call-00 records from
[War resource errors](LIB_WAR_PREPARATION_ERRORS.md). Their six following
call-01 source faults at 40c118 stay separate; this card neither executes nor
continues those source paths. The prior audit, inventory, raw cases, masks,
failure sidecars and producer plans remain immutable.

The reference hashes are EXE
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`, lib.dll
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba` and VC80
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Historical observations used Unicorn 2.1.4, CW023f, C locale, explicit flat
32-bit segments/FS and declared allocation/Win32/COM responses. They do not
establish Windows heap, actual device destruction or host behavior.
This card reads those saved outputs and executes Native only. It imports no
source producer and starts no EXE, DLL, emulator or capture.

## Finite contract

| Cases | Declared input | Failed wrapper | Retained platform state |
| --- | --- | --- | --- |
| s04/s05 | missingLoaderIndices 13/17 | marker 0; width/height remain unknown; four defined bytes | Both image attempts return 0; no image or surface for this wrapper |
| s06/s07 | createSurface#14/#18 = -1 | marker 0; known dimensions; 12 defined bytes | Image stays recorded without DeleteObject; no new surface |
| s08/s09 | colorKey#14/#18 = -1 | marker 0; known dimensions; 12 defined bytes | Image is deleted; surface record retains the Release request flag |

The first/last dimensions are 384×383 and 37×9, derived from pinned original
BMP files. The failed colorKey still has `input.present=true`: this field means
the loader returned a nonzero surface before the constructor requested Release
and cleared its marker. Release result 17 and the retained `released=true` flag
record the controlled request, not actual COM destruction.

Core already implements these branches in `OriginalBitmapSurfaceLoading` and
`OriginalBitmapConstructor`. The War adapter now uses explicit declared failure
inputs and checks that every intended target was reached. Missing-loader indices
count prior non-NULL constructors from owned context, not image API requests:
one loader tries two images. Other response identities retain their declared
platform bindings; GetObject and surface-description bytes are produced from
owned raw BMP metadata and current Native requests.

The comparator preserves marker 0, known/unknown masks and absent surface
bindings. A colorKey failure retains its binding and Release-request record.
Five actual wrapper records remain live in each returned call. Owner indices
remain distinct from reference address tokens; no source after-state, stack
backing or platform after-state supplies Native game storage.

## Native checks and preservation

Each of six chains first executes ten accepted bound-preflight calls in Native,
producing its own retained World, Actors, library, menu and resource state.
These 60 prefix executions overlap ten distinct prior reference cases and are
not new original starts. Six full returned callers compare 7,884 ordered front
events, 96 numeric checkpoints, records/masks, full recording buffers and
bitmap/image/surface/DC ownership through the existing whole War comparator.

Eighteen Native observer-error trials target the actual failed constructor,
recording and before outer return in each scenario. The constructor trial runs
after its message/debug/Release effects, including the last-layer case after
four earlier constructors. The enclosing transaction must retain all prior
state and roll back every current-call owner/effect. These are Native rollback
trials, separate from original API failures and subsequent source faults.

Required regressions are the War 256-call matrix, 22-call preflight, three
nullable calls with their rollback trials, BitmapSurfaceLoading and
CharacterMenuSurface. Raw and bundled comparisons, independent review,
transport verification, package/Git equality and full archive verification
are separate acceptance gates.

The frozen plan and initial versions are in
`build/research/lib-war-preparation/war-partial-surfaces-native-20260912/`.
Its plan pins 46 source/evidence inputs and 336 previous fixtures, with a
20GiB task limit, original 6GiB internal reserve, three correction rounds and
1800s initial Native job limit. Large task data stays on X5 UUID
`3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`; bundled fixtures are regular local files.
Root owns the adapter/test/publication; `catalog_test_completion` owns only the
new packager and six fixtures; `war_contract_review` independently reviews the
contract and code without source or Native execution.

## Result and delivery

The first frozen Native candidate passed the raw comparison in 38.681s after
a 281.93s release build. Nine bundled regression methods then passed in 268.324s,
build 0.32s, with every `NTSD_*` raw override removed. The new bundled comparison
took 39.395s, retained nullable cases 19.035s, preflight 16.672s and matrix 186.892s.
BitmapSurfaceLoading and CharacterMenuSurface passed through their existing
match/boundary contracts. Both jobs are terminal, exit 0; no Core correction or
expected-data change was needed.

Each new run checks six returned whole callers, 7,884 events, 96 numeric points,
30 wrapper owners and 18 coupled rollback trials. Raw/bundled repeat the same
six cases: 12 returned-case executions, 36 rollback executions and 120 prefix
executions overlapping ten distinct accepted prefix cases. There are ten
test-method executions and nine unique methods, not ten independent new tests.

Six lossless envelopes preserve all 214,090,551 raw bytes in 28,695,020 bytes.
All 4,306 blob entries/896 distinct blobs and 60 prefix digest links verify.
The six following faults and their sidecars are outside the successful fixtures:
a separate 22,997,769-byte archive preserves 12 files/125,329,982 content bytes,
with bytes, hashes, modes and mtimes checked. All 4,378 sidecar blob entries equal
the verified fault-call blobs. This is preservation, not Native fault acceptance.

All 336 prior fixtures and 46 source/evidence pins remain unchanged. The complete
784-file Native candidate, working package and staged Git blobs are identical;
342 fixtures are regular, self-contained files. Every Native archive member
matches the tested candidate: 3,898,449,920 archive bytes, 3,897,033,402 content
bytes. The separate 216,207,360-byte evidence archive verifies 64 members and
216,090,454 content bytes, including complete returned raw cases, metadata,
initial versions, terminal jobs/logs and the fault archive proof. It does not
duplicate the 12 separately archived fault/sidecar files.

Independent review found no material contract/code blockers. Exact commands,
timings, SHA-256 values and archive manifests are in the acceptance JSON and
task directory. Internal free space was 9,362,165,760 bytes at evidence archiving;
the original 6GiB reserve remains in force. No window/device or Windows claim
follows from the linked Native binary or these controlled comparisons.

## Open dependencies

The six next-Start source faults are preserved separately, including the
distinction between first-layer fault and four prior Release/free pairs for the
last-layer fault. Native rejection of those paths has not been accepted here.
s10/s11 remain normal source returns with unknown private-dimension provenance;
expected values cannot supply that missing Native provenance.

Remaining graphics/music/replay errors, nine separate source-fault rollback
trials, whole War gameplay, own catalog/startup/loop/application, full matches,
all content/network and Windows/device/clean-Mac verification stay open.
Existing safety incidents remain open. This independent saved-data/Native work
does not repeat a blocked operation or authorize its resumption.
The next independent Native card is eight saved returned graphics API-error
cases s12..s19/call-00; its input and ownership differences are recorded in
`next-graphics-errors-review.json` under the task directory and [CURRENT_WORK](CURRENT_WORK.md).
