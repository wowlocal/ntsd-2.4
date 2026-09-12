# War preparation: ordinary graphics API errors

Status: eight saved returned cases match Native; raw, bundled and required
regression checks pass. This card advances ordinary
resource contracts for complete preparation and the full native game in
[CONTINUE_GOAL](../CONTINUE_GOAL.md). It follows the accepted
[NULL allocation](LIB_WAR_NULLABLE_BITMAP.md) and
[partial surface](LIB_WAR_PARTIAL_SURFACES.md) cards; the full goal remains open.

## Game question and retained reference

When an ordinary graphics API operation fails while preparing an arena, which
later requests still occur and what state does the whole War caller retain?
Use exactly the eight saved returned s12..s19/call-00 observations from
[War resource errors](LIB_WAR_PREPARATION_ERRORS.md). Their historical reports,
jobs, input pins, complete raw records, masks and expected events are immutable.
All eight have one returned call. Nine other source faults remain separate.

Pinned reference EXE SHA
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`, lib.dll
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`, VC80
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Historical observations used Unicorn 2.1.4, CW023f, C locale, explicit flat
32-bit segments/FS and controlled allocation/Win32/COM results. The saved
request, memory and ownership records establish order and retained storage;
they do not establish actual Windows heap/device behavior.

This card reads those completed artifacts and runs Native only. It imports no
source producer and starts no original EXE, DLL, emulator or capture. Existing
safety incidents stay open; this work does not retry a blocked operation.

## Finite contract and Native changes

| Case | Declared response | Observable result within the first bitmap construction |
| --- | --- | --- |
| s12 | getDC#14 = -1 | Skip Stretch/ReleaseDC; remaining cleanup and colorKey continue |
| s13 | restore#14 = -1 | Ignore result and continue |
| s14 | createDC#14 = 0 | Still request SelectObject, Stretch and DeleteDC with DC0 |
| s15 | selectObject#14 = 0 | Ignore result and continue |
| s16 | stretch#14 = 0 | Continue ReleaseDC/DeleteDC/DeleteObject |
| s17 | releaseDC#14 = -1 | Continue cleanup |
| s18 | deleteDC#14 = 0 | Retain the DeleteDC request flag |
| s19 | deleteObject#14 = 0 | Retain the first image with deleted=false |

GetDC failure skips two requests only in the first constructor. The second
constructor then uses `stretch#14` and `releaseDC#14`; excluding these keys
from the whole case would be incorrect. All ordered requests and operands
remain compared through the whole caller, including later layers.

Each call retains five nonzero wrapper and surface records, bitmap marker 1,
`input.present=true` and the first 12 defined bytes. Dimensions come from pinned
raw BMPs: 384×383, 799×546, 799×47, 799×47 and 37×9. Remaining wrapper backing
stays unknown under its original mask. No expected after-state or private source
backing supplies Native game state.

The shared Core already contains these branches. The War adapter extends its
strict table of declared result inputs and requires every target key exactly
once. It forms the response before updating its platform records and comparing
the captured result. Failed GetDC has no output pointer. CreateDC0 creates a
controlled bookkeeping entry `dcs[0]`; DeleteDC marks that a request occurred,
regardless of its result. These flags do not mean a real DC existed or was
destroyed. DeleteObject's retained flag instead depends on its numeric result;
the first image remains recorded when that result is zero.

An observer hook runs immediately after the exact API response/event. The new
test checks its stopped event index against the saved whole caller, so the
targeted rollback cannot drift to a later constructor boundary. The existing
outer transaction checks all prior owner, recording, menu, RNG, music and
resource state after unwinding.

## Comparison, review and preservation

Eight independent Native chains each produce ten accepted bound-prefix calls
from their own state. These 80 executions overlap ten distinct reference cases;
they are not new original starts. Whole returned callers compare 10,550 ordered
front events, 598 preparation API requests, 128 numeric checkpoints, complete
records/masks, eight recording buffers and 40 new wrapper owners. Twenty-four
Native rollback trials cover the exact target API, recording and before outer
return in each scenario. They are separate from original API-failure matches
and from rejection of source faults.

Required regressions retain the War 256-call matrix, 22-call preflight, nullable
three calls, partial-surface six calls and their rollbacks, BitmapSurfaceLoading
and CharacterMenuSurface. Raw comparisons, lossless transport, bundled tests,
independent review and full package/archive/Git equality are separate gates.

The first frozen Native candidate passed without a correction: raw comparison
50.264s after a 282.44s release build. The same candidate passed all ten bundled
methods in 317.460s after a 0.35s build with every `NTSD_` raw override removed.
Bundled graphics comparison took 50.344s; retained nullable 19.017s, partial
38.946s, preflight 16.823s and matrix 186.274s. This is eleven method executions
and ten unique methods, not eleven independent contracts. Both executions of
the new test account for sixteen returned-case comparisons, 48 rollback trials
and 160 overlapping Native prefix calls. No Core game rule or expected byte
changed for acceptance. Existing trailing-closure compiler warnings remain.

Exact stopped front-event counts for s12..s19 are respectively
817, 812, 813, 814, 818, 819, 820 and 821. These stop after the selected API
response/event in the first constructor; recording and before-return stops are
additional trials. All eight full calls then return when no Native observer
error is injected. No source fault is counted as a successful return.

Eight self-contained fixtures, 38,259,024 packed bytes, reproduce all
285,544,780 raw bytes and their JSON/SHA. The transport verification checks
5,744 blob entries totaling 271,216,816 bytes, with 722 distinct blobs totaling
33,904,150 bytes, and all eighty prefix proof links. All 342 old fixtures and
45 source/evidence input pins remain unchanged; the current package contains
350 fixtures and 793 regular Native files. Every file matches the frozen
candidate, staged Git blob and complete Native archive. Of the candidate files,
782 were verified APFS clones and eleven were copied changed/new files.

The Native archive is 3,936,737,280 bytes. The separate evidence archive contains
78 members / 287,993,085 member bytes in 288,133,120 archive bytes; every member
and its bytes were independently read back and matched. Historical source-fault
archives remain separate and unchanged. Both Native jobs and both new archive
jobs are terminal. The immutable `review1.json` records the independent
contract/code review before tests; its pending gates describe that earlier
phase. Completed gates and exact pins are in
[the acceptance evidence](../evidence/lib-war-graphics-errors.json).

The frozen plan and initial versions are in
`build/research/lib-war-preparation/war-graphics-errors-native-20260912/`.
The plan pins 45 source/evidence inputs and 342 prior fixtures. Limits are
20GiB of new task storage, the original 6GiB internal reserve, three Native
correction rounds and 1800s per initial test job. Large files stay in task-owned
X5 UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`; shipping fixtures stay regular and
self-contained. Unchanged prior candidate files may be APFS-cloned into the
new candidate only after matching their immutable manifest and current bytes;
every resulting file is verified, and the prior candidate remains unchanged.

Root owns adapter/test/publication changes; `catalog_test_completion` owns only
the new packager and eight fixtures; `war_contract_review` independently reviews
the contract and code without running the original or Native.

## Open dependencies

The two normally returned s10/s11 cases still need owned provenance for private
dimensions. Remaining music/replay cases and nine separate source-fault
rejection/rollback trials are not accepted here. Existing reference archives,
failure records and incidents remain preserved.

The next read-only review identifies nine saved returned controls/music cases:
s00/s01/s20/s21/s23/s24/s25/s26/s27, each call-00. It is readiness evidence, not
Native acceptance. Inputs come from `resourceFailureInput.music`; s01 uses
prefix 0011..0020 while the others use 0000..0009. The next card must retain
the separate message-event bridge and compare its globals after music stores.
s27's opaque allocation has explicit producer provenance and an unknown mask;
it does not establish real Windows conversion behavior. The review and its pins
are in `next-music-errors-review.json` and embedded in the acceptance evidence.

Whole War gameplay, own full catalog/startup/library/outer loop/application,
complete matches, all content/network and Windows/device/clean-Mac checks remain
part of the full goal. A linked binary or these controlled comparisons do not
establish a playable, validated native game.
