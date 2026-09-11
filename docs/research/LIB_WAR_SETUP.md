# War troop setup and whole menu continuation

The finite setup study now has806 source/native comparisons:574 original setup
calls,192 separate cell-navigation calls and40 calls combining actions from
multiple human seats. There are805 enclosing422ab8 ret4 returns,801438b40 War
ret1c returns, four resource-parent returns and one boundary **before43a21f**.
The two supplements reproduce four parent calls from the original corpus;806
is a count of observations, not unique initial states. Raw and packaged acceptance pass. Machine-readable evidence is in
[lib-war-setup.json](../evidence/lib-war-setup.json).

## Behavior and reference boundary

This implements mode4/menu200..202/210 troop and participant setup, multipliers,
presets, popup controls, live Random choices, arena/difficulty/music settings,
frame drawing and enclosing output/sound order. It follows the frozen
[setup plan](LIB_WAR_SETUP_PLAN.md), [resource-parent correction](LIB_WAR_SETUP_INPUTS.md),
[44-cell supplement](LIB_WAR_CELL_COVERAGE_PLAN.md) and
[multiple-seat action supplement](LIB_WAR_MULTI_ACTION_PLAN.md).

The pinned EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`, lib.dll is
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`, and VC80 is
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Controlled Unicorn2.1.4/CW023f executes actual41bc90 followed by the declared
4229cc tail, installed original library and ordinary return paths. The harness
provides declared allocator/COM/GDI/music responses, C locale and original
DAT/head/small BMP/embedded DIB resources. This is no Windows/device execution,
played battle or full initialized application run.

Instruction, memory, stack/register, helper and resource-ownership observations
are needed to distinguish input priority, same-call transitions, live aliases,
sparse writes and output order. The standard original cookie/SEH sequence runs
normally. Private caller-stack records remain source-audited evidence; they are
not imported into Native or compared as a Windows private ABI.

## Recovered rules and finite coverage

The initial574-call capture edited seven distinct troop cells. Its full audit
correctly retains `coverage.complete=false`. A seat's simultaneous keys are
reduced to the first action by431b70: Right/Defense delivers Right only and
Attack/Jump/Defense delivers Attack only. The192-call supplement uses separate
Defense and Right press/release edges and dynamically edits all44 cells. The40
multi-human calls use seats0/1/2 for Attack/Jump/Defense, delivering all seven
nonempty masks on both active and reserve rows. No input-global flag or cursor
was injected to force these two coverage results.

Thirty declared popup selector/strength bridges cover five presets, three
strengths and both sides, with330 cell results and36 complete REP spans/2816
bytes. The574 chain also checks28 live Random lists, four frame phases, both
multipliers, popup apply/cancel/Jump, reroll and settings. Each Random list uses
previous choices from the same call. Menu201 rerolls then enters settings in
that call. Settings Attack finalizes troops and clears Attack before confirmation
sound; arena and difficulty actions retain their second sound. Preset copies
retain reserve-before-active order and Jump restores before later handling.

Each fresh chain reconstructs a World and400 Actors through actual constructors,
loads eleven menu bitmaps, then supplies the declared ready bridge before War
constructs BATTLEMODE/BATTLETROOPS. Four parents give1604 constructor returns and
eight owned War bitmaps. Native independently rebuilds137 Objects/101 Backgrounds
and their resource bindings. Unit-ID scans keep the last matching Object.
Native unit references use ordinal+1, with zero separate from Object0; source
pointer canonicalization happens only in copied comparison records.

The nine BATTLEMODE geometry stores preserve surrounding bytes and masks.
Frame effects define size/color while other backing stays unknown. Preset text
uses actual atlas-width offsets. `OriginalWarMenuMemory` retains owned resources;
`OriginalWarMenuContinuation.advanceWithWar` stages War, common output, RNG,
World/Actors/globals, library DC and events until the entire caller commits.
The earlier default dispatcher boundary remains available. This research API
has not been connected to the shipping application's game loop.

## Complete audit and native comparison

| Corpus | Calls | Outer returns | War returns | Checkpoints | Records | Record bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Setup |574|573|571|9354|10017974|26379972012|
| All cells |192|192|191|3091|3310381|8716961658|
| Multiple seats |40|40|39|659|705709|1857948282|
| Total |806|805|801|13104|14034064|36954881952|

The source audit reconstructs all recorded bytes/masks from declared inputs and
actual writes, checks every read/checkpoint/helper return and verifies original
instruction bytes. Totals include7391686 stores,7709930 instruction reads,
198818 API reads and185106 helper returns. The union has4003 executed original
instruction starts, excluding synthetic hooks and the unexecuted43a21f stop.
These counts do not establish every branch outcome. The6864 blob verifications
sum per-corpus checks; shared blobs are not claimed unique.

The Native whole comparator retains independently produced state across every
call. It compares complete World/400-Actor records, globals, owned bitmap bytes/
masks and ordered public events at each corresponding checkpoint. Source-only
private stack and address bookkeeping stay in the independent source audit.
Both supplement parents reproduce the earlier source cases; only the control
parent's `firstCase` annotation moves from412 to0 in comparison metadata.

Seven raw release tests pass374.882s: setup264.001s, cells88.034s, multiple seats
22.347s and four dependency tests0.501s. The dependency corpus has192 operations/
3560 ordered scalar stores and896 frame helpers/4984 fills. Its earlier132
operations and574 frame-call records remain byte/deep-equal. The final comparator
was compiled through normal `swift test -c release list`; a build-only attempt
without testing support failed separately and is retained.

Eighteen source-coupled late rollback trials pass: eight in setup and five per
supplement. They cover the second resource, text, frame, present and outer
before-return; setup also covers preset, second Random and finalization. Two
independent dependency rollback tests cover late ordered writes/frame output.
Prior Native-only six inner/eight outer failures remain separate evidence.
Six retained packaged dispatcher tests pass185.895s/build15.44s, preserving373
Team Tournament setup,373 Tournament setup and252 selection calls and rollback.
No game rule or original expected byte changed during the806-case acceptance.

Final packaged acceptance: **seven release tests pass473.097s/build0.31s**
from Bundle resources with all `NTSD_*` raw overrides removed. Setup takes
362.424s, cells89.776s and multiple seats20.423s. NTSDNative links;
this does not exercise an app window, audio device or user input.

## Immutable transport and preservation

All three raw corpora and their806 atomic cases remain unchanged. Independent
transport verification reconstructs and compares every raw byte, complete JSON,
metadata, audit, per-case envelopes and blob hashes. Zlib framing packages
research observations only; it does not implement a game codec or execute a DLL.

| Corpus | Raw bytes | Raw SHA256 | Packed files/bytes |
| --- | ---: | --- | ---: |
| Setup |3456631996|`9b7e923c7f43ef328c4e7760ae5633589d83ce2bcbef430258f8d8f53a40b1aa`|13 /410287566|
| All cells |1138424571|`d2f17f5a4b32cc950227de4c1061430d34242fb7b6a883c79a43d02a38547f57`|5 /135899256|
| Multiple seats |247848404|`fba1f47a4f7770405cd139fbc2ee2bfbd86f0c059f0658e29d56c2fe8bd8f36c`|2 /29856345|

The derived dependency transport adds114747 bytes, giving21 new fixtures/
576157914 bytes. All295 old fixtures are unchanged,316 current fixtures are
pinned, and the tested isolated package has745 files. Twenty-three unrelated
pending files remain protected. Complete pins and jobs live under
`build/research/lib-war`, with the canonical symlink to the restored X5 unchanged.
The6GiB research-storage reserve is retained. All745 prospective Git/package
files match, and the2609867037-byte archive verifies every745 member; SHA256
`fc69cb06ec49702cf544a0bda76d3b1972cec0a8e4ebf0b7923f6f3cb5137cfb`. All source and Swift jobs are terminal; the historical
interrupted Swift result remains unknown as recorded below.

Historical failures and unfinished snapshots are preserved in
[setup status](LIB_WAR_SETUP_STATUS.md) and
[Native work history](LIB_WAR_SETUP_NATIVE_PENDING.md). X5 disappeared after
source2 completed; exact UUID/raw/574 parts/387 inputs were verified when it
returned. Interrupted Swift30285's actual result remains unknown. The first
restoration helper used a nonexistent diskutil key. Audit1 applied PE phase0
before the explicit control phase3 input; its correction changes audit ordering
only. Audit2 exposed the real seven-cell coverage gap. All failed reports,
timestamps, sessions, frozen tool revisions and source bytes remain retained.
The supplements close the identified gaps without replacing574 observations.
Completed source jobs were never restarted for silence or storage loss.

## Remaining boundaries

Ready teams other than1/2 have unresolved retained label-X provenance. Missing
live resources, unknown width backing and empty Random lists explicitly reject
with rollback. The static NULL geometry write is unsupported; it was not a newly
executed source fault and is not counted as a native match. The static short-row
cursor5 rule uses the final cell; that specific path is not separately established
dynamically by these806 calls. Ready bridges and popup bridges also do not prove
earlier mode4 character/CPU-selection reachability or played fights.

Next is the entire preparation beginning43a21f, then War gameplay43a860.
[Preparation evidence](LIB_WAR_PREPARATION_STATIC.md) currently covers330 decoded
starts/1359 pinned bytes only. Own catalog/library/outer-loop/app integration,
full Naruto/Sasuke match, all game content/network, Windows execution,
window/input/audio and clean-Mac verification remain open. Catalog5 is terminal
at the unchanged6GiB reserve after28 complete Objects; never restart it.
The full native-game goal remains active and incomplete.
