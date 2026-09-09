# Bundled-library preparation and command 3

The native preparation caller now preserves the bundled library's requested
Object ID and feeds it directly into the whole post-draw command consumer.
The library also changes a player's initial X coordinate by overwriting a
live register. Both effects are required for compatibility with the original
bundled game. The native implementation executes Swift game rules; it does
not load the DLL, emulate x86, or patch executable memory at runtime.

This study compares controlled whole callers and their explicit connection.
It does **not** continue an initialized application through the intervening
gameplay tick. Earlier pristine-EXE fixtures remain immutable unloaded-library
controls. See [LIB_RUNTIME](LIB_RUNTIME.md) for the actual application entry,
pinned artifacts, other library hooks and the remaining application join.

## Source artifacts and boundaries

The source is the accepted NTSD distribution: EXE SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
and6144-byte lib.dll SHA256
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
A development-only Unicorn2.1.4 VM executes original instructions at CW027f.
Windows APIs, constructor memset, bitmap loading and the existing controlled
music/device responses remain the declared boundaries of the parent studies.
No actual Windows or device behavior is inferred from these observations.

The established source VM uses10000000 for its stack, so the research loader
maps the DLL at36000000. It independently applies all76 PE HIGHLOW relocations
and binds the DLL imports. These are explicit loader effects. The actual DLL
entry then executes104 instruction starts, makes its two4000/20000-byte
allocation requests and installs its own13 patches/62 bytes through26
VirtualProtect and13 RtlMoveMemory requests. Expected patch bytes are never
substituted for this execution. The verifier checks every relocation and
compares all installed destinations to the accepted preferred-base installer.
This is neither a full Windows relocation test nor a native DLL installer.

The new [loader](../../tools/lib_runtime_loader.py) is shared research tooling.
The [command producer](../../tools/oracle_lib_stage_commands.py) retains the
four-Object/400-Actor boundary of [POSTDRAW_COMMANDS](POSTDRAW_COMMANDS.md).
The [preparation producer](../../tools/oracle_lib_match_preparation.py) restores
the complete pinned loaded catalog, executes original World/bootstrap, then
runs each whole42d1ff..42d6ed preparation and whole4214d5..421a15 consumer.
A fresh declared command ABI supplies EBX=World and unknown scratch backing
between those callers. It supplies no expected game state, requested ID or
retained spawn slot. This explicit connection does not execute the intervening
control, drawing and lifecycle stages and must not be called a full tick.

## Preparation behavior

[OriginalLibStageCommands](../../native/Sources/NTSDCore/OriginalLibStageCommands.swift)
owns the signed requested ID corresponding to459ff8, outside the existing
loaded-match global record. Its initial value is a required boundary input.
Both controlled source/native chains begin with12345678hex and retain their
own subsequent output. That value is not a recovered startup default.

[OriginalMatchPreparation](../../native/Sources/NTSDCore/OriginalMatchPreparation.swift)
adds `prepareUsingBundledLibrary`, preserving the same full caller and atomic
commit as pristine `prepare`. Three installed hooks change that caller:

| Hook | Original library effect |
| --- | --- |
|42d30b /10001b2e|For status>10, copy the chosen BG's signed word+0xc into459ff8 before RNG stream0xdb. Later original code replaces ECX with the random result, so X remains random+width/4.|
|42d473 /10001b48|For status1...10, copy the same word after RNG stream0xdd has returned. The hook overwrites ECX, which held that result: X becomes BG+0xc+width/4, with wrapped32-bit addition. The RNG call still occurs.|
|42d5ce /10001b1b|Retain the original450c1c write and write **only byte**450bb8=3. The upper three bytes of that command word survive.|

BG+0xc is the first `perspective:` field parsed by the original BG loader.
Mode1's later type0 stage positioning still overrides X through its existing
RNG stream0xdf; the library does not replace that remaining caller behavior.
No positive selected status means no new requested-ID write. A later command
can therefore consume the preceding preparation's retained ID.

For example, the controlled District width is960. With perspective122 and
status1, original/native X is362 despite consuming the X RNG call. With
status11, X still uses that random result. With input command word12345678hex,
preparation produces12345603hex; the full-word command3 test then fails.
The explicit empty-selection case retains ID100 from its preceding producer
and its consumer constructs the matching catalog object.

The loader never initializes BG99+0xc. The two source chains each record seven
actual reads of its untouched a5 catalog-allocation bytes. Its four mask bytes
remain zero throughout every snapshot. Native defaults to an explicit
`undefinedBytes(offset:0xc,count:4)` rejection and rolls back. The optional
`uninitializedPerspective` resolver permits a caller with declared backing to
supply that value; the research comparison independently rebuilds the entire
catalog over the pinned a5 allocation, verifies those own bytes and undefined
mask, and supplies only that BG99 word. It never copies expected after-state.
Actual application's BG99 allocator contents/provenance remain open. The70
comparisons include this explicit backing contract; they are not70 comparisons
of an unrestricted default native domain. Two separate native-only missing-
backing trials reject and roll back; they are not source faults or successful
source matches.

## Whole command behavior

[OriginalPostDrawCommands](../../native/Sources/NTSDCore/OriginalPostDrawCommands.swift)
accepts the optional owned library state. Absent that state, its accepted
pristine behavior remains unchanged. The installed4214d7 hook handles:

- Full command word1: retain the original100..<200 ID filter and the special
  ID122 stream208/range2 draw.
- Full command word3: scan the catalog in original order, read each header ID
  first, then compare the live requested ID. Accept every exact match, including
  duplicate and signed IDs. There is no100..<200 filter or ID122 selection draw.
- Other words: continue the ordinary resource, recovery and cleanup loop.

A zero requested ID exits after the first header read when catalog count is
positive. Count<=0 reads no header. Missing first-header backing therefore
still rejects in the positive-count zero-ID case. No candidate is invented.

The original caller freezes candidate order before construction, searches free
slots50..<400 and preserves retained SP34 when the pool is full. It still takes
all four coordinate draws209...212 before dereferencing that retained slot.
Construction aliases, ID122 HP200, integer conversions, state1700, healing,
music HRESULT handling and byteEB cleanup remain the parent caller's rules.
The consumer does not clear command3 or modify459ff8. The later HUD caller's
flag reset remains separate. This is not a recovered complete native stack.

All4330 controlled whole source calls match full World/400-Actor bytes and
masks, complete ordinary-global SHA256, ordered events, continuation421a15 and
retained SP34. The3898 original probes rerun through the installed library and
reproduce **every** previous complete result unchanged. Their requested-ID
input is explicitly zero. A further432 cases exercise library selection,
duplicate IDs, signed extremes, command gates, aliases and full/free pools.
The corpus includes6361 events:4924 RNG,1187 constructors and250 music resumes;
9923 helper returns and1258 actual requested-ID reads. Coverage is544 original
EXE+29 DLL instruction starts, excluding stop/API boundaries. Instruction-start
coverage does not prove all branch outcomes or arbitrary catalog sizes.

Five native tests also check late constructor/music rollback, unavailable
retained-slot failure after four coordinate draws, and the zero-ID header-read
order. Observers can receive effects before a later failure: enclosing callers
must buffer external events until the whole operation commits.

## Whole preparation and own consumer comparisons

Two independent chains use a5 and ramp Actor/World backing, while each restores
the same pinned complete catalog allocation. Each has35 preparations and35
consumers: the25 historical declared menu scenarios plus ten library boundaries.
All137 source Objects, seventeen loaded backgrounds, special BG99, signed
status boundaries, mode0/1/2, restart and RNG wrap paths remain represented.
The extra cases vary perspective, flag upper bytes and retained empty selection.
They are controlled inputs, not proof of natural UI reachability for every ID.

Native independently rebuilds the complete catalog, bootstraps its own state,
then compares every before/after/consumer World,400 Actors,101 BG records,
globals, masks, bitmap storage and ordered resource/RNG/construction observations.
Across both chains:107732 records/160959136 bytes with masks,26942 preparation
constructors,756 preparation RNG calls,1096 new bitmaps and1066 releases. The
consumers add40 events:32 coordinate RNG calls and8 constructions. Source checks
64 consumer helper returns and3130 accesses to the retained requested word.
Each chain contains3677 independently hash-verified storage blobs.

The joined source inventory has1094 observed starts. Three are declared
adapters:43ed10 bitmap load,4450a0 memset and4450ac allocation. Excluding them
leaves1053 EXE+38 DLL actual instruction starts across bootstrap/preparation/
commands and their observed children. This is separate from the broader
controlled command inventory and the104 DLL installer starts. Stops are excluded.

Four native-only trials check rollback: one late reset-input observer and one
missing BG99 backing in each chain. They preserve full World/Actors/globals,
backgrounds, bitmaps/release ownership, frame allocations and requested ID.
Default prepared state never receives source snapshot bytes to recover from
those failures.

## Validation and publication

Reproduction uses [accept_lib_stage_commands.py](../../tools/accept_lib_stage_commands.py)
and independent [verify_lib_stage_commands.py](../../tools/verify_lib_stage_commands.py).
Only after native acceptance are the three new complete lossless fixtures
published. All200 prior fixture pins remain unchanged, including the separately
committed48-call pristine active controls and library text/install evidence.
The new corpus raw bytes are3817166,15545023 and15629721; transport deflation
preserves every JSON field and storage blob and is unrelated to game replay
compression. Ten vendored codec files remain hash-verified and untouched.

Initial raw validation: command5 tests passed3.398s after174.73s build;
preparation1 test passed6.793s without rebuilding. The expanded11-test native
acceptance passed19.351s/build171.39s, including the four preparation rollback
trials and the retained50-case pristine preparation/3898-command tests. Its
first packaging step then failed because the host Python's `zlib.compress`
lacks the `wbits` argument; no fixture had been written. The compressor-object
transport fix and repeat acceptance passed11 tests/19.367s without rebuilding.

Final packaged11 release tests passed19.391s/build171.40s with both raw-directory
overrides absent. NTSDNative linked; no app window or device was tested. All
three source jobs and owned SwiftPM jobs are terminal. The three published
fixtures total5155811 bytes and reproduce all34991910 raw bytes (including
the transport newline), full JSON, SHA256 and7354 preparation storage blobs.
Independent verification preserves200 old pins/203 current at publication and
all10 vendor hashes. Python compilation,137 local Markdown links and owned-file
diff checks pass. The isolated package verifies514 committed native files from
5a28b0a plus nine exact overlays; concurrent actor-control work is excluded.

The two initial installer trials reached a synthetic return marker at a mapped
page edge and failed during fetch before any command case ran. Moving the
unexecuted marker inside its mapped page resolved that harness boundary. The
first preparation join trial omitted the declared EBX=World command argument;
the second identified the actual undefined BG99 perspective reads described
above. Each failed process was terminal before its preserved source/log was
superseded. No accepted corpus or expected result was edited, and no live
process was restarted for silence. Both completed source chains and the
controlled command corpus remain the original captured bytes.

Remaining library movement, physics, transformation, hit filters/damage and
loading-label hooks, transparent-text routing, the full initialized application
join, full match/content, app/window, Windows/device and clean-Mac checks remain
open. Neither this connection nor the earlier pristine active controls establish
the complete native game.
