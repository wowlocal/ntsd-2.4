# Bundled-library patch overlap with the active controls

Five of the thirteen installed patch sites overlap pristine instruction
inventories in both accepted48-call active controls. This demonstrates that
the library-enabled comparison needs new execution evidence even for this
short trajectory. It does not establish which DLL branches will run or how
the resulting game state will differ.

This is a read-only compatibility audit of the pinned original distribution,
the accepted library-installation fixture and the two pristine active fixtures.
The installation was observed on Unicorn2.1.4; this audit performs no new game
execution. It decodes original EXE instruction bytes with local llvm-objdump
and intersects their complete byte intervals with the installer's actual copy
ranges. Checking intervals is necessary because several copies replace only
part of an original instruction. No original file, VM, game state or accepted
expected value is modified.

The EXE SHA256 remains
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
bundled lib.dll SHA256 remains
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
The three fixture identities and complete restored raw hashes are embedded in
[the report](../evidence/active-lib-impact.json). All four accepted attach
controls produce the same thirteen code-copy ranges and62 replacement bytes.

## Observed intersections

The counts below are the number of complete calls whose retained instruction
inventory overlaps a patch. They are **not dynamic instruction invocation
counts**. The two control variants give the same intersections.

| Patch / DLL target | Captured pristine stage | Calls with overlap, each variant |
| --- | --- | ---: |
|41408b /10001125|control|48|
|4176ac /10001807|contacts|11|
|41f5fc /1000109d|post-draw lifecycle|48|
|4214d7 /10001a9a|post-draw commands|48|
|401290 /10001298|post-draw impulses and final output|48 in each stage|

The contact patch overlaps calls18,19,20,22,23,24,25,29,35,36,37. The original
instructions at4176ac and4176af compare kind8 and branch. Their appearance does
not establish a hit or damage; the accepted pristine trajectory retains HP500.
The41408b site appears in the captured **control** stage, despite the broader
physics/frame description in the initial static DLL survey.

The401290 replacement is relevant to two separately captured stages per call.
Its isolated native text comparison in [LIB_RUNTIME](LIB_RUNTIME.md) does not
yet connect retained library state through these enclosing callers.

No overlap appears in these active-call inventories for430c8c movement,
42fcb1 damage,4177b9 team filtering,424352/424357 loading, or preparation
42d30b/42d473/42d5ce. The initial loading and preparation occur before the48
active calls, and the input schedule is bounded. None of those missing
intersections establishes that its hook is irrelevant to the game.

## Instruction boundaries and verification

The five bytes at41408b overlap an eight-byte original comparison; the five
at4214d7 overlap a seven-byte comparison. At424352 the first patch overlaps
two push instructions, while its companion424357 two-byte patch lies inside
the five-byte push that starts at424354. An address-only match would lose the
relationship between that companion patch and its original instruction.
The report retains original/installed copy bytes and all overlapping decoded
instructions for every site, including sites absent from the active series.

The broad per-call address inventory includes inherited hook boundaries and
stage stops, so it remains labelled as an inventory. Stage-specific results
separately remove each declared unexecuted stop. None of these thirteen ranges
overlaps an excluded stage stop. These exclusions do not turn the broad
inventory into complete per-instruction execution coverage.

[audit_active_lib_impact.py](../../tools/audit_active_lib_impact.py) verifies
all source and fixture hashes, checks installer before-bytes against the pinned
EXE, and byte-checks each decoded interval. Unknown candidate instruction
heads fail the audit instead of silently disappearing. It writes a derived
report; it does not create or change a native acceptance fixture.

An independent Capstone5.0.7 check verifies the same original instruction bytes
and lengths, and recomputes all1248 patch/call intersections and stage results
from the two complete fixtures. The evidence is retained in
`build/research/active-lib-impact-verification.json`. The llvm and independent
checks complete with exit0. Native gameplay tests are not repeated for this
read-only audit; the active raw and packaged comparisons remain the separate
evidence described in [ACTIVE_GAMEPLAY_CAPTURE](ACTIVE_GAMEPLAY_CAPTURE.md).

The next library-enabled join must execute installation before its real
preparation and consumers. Installing patches only after importing the old
pristine initialized state would be a different controlled experiment, not
proof of the application's startup. Preserve independent native ownership of
new459ff8 state and the preparation-to-command3 order. Full CRT startup,
library gameplay branches, application integration, full match/content,
Windows/device and clean-Mac checks remain open.
