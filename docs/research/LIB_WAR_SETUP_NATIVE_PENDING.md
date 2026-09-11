# War Native implementation — not accepted

This continues the frozen [War plan](LIB_WAR_SETUP_PLAN.md), its
[input correction](LIB_WAR_SETUP_INPUTS.md), and the
[storage interruption](LIB_WAR_SETUP_STATUS.md). The game behavior is the
438b40 troop/participant/settings menu, both frame helpers, ordinary439ecd
ret1c and the separate BEFORE43a21f Start boundary. Battle preparation and
43a860 gameplay are not implemented by this change.

The reference is the pinned NTSD EXE
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
lib.dll `28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`
and the completed574-call Unicorn2.1.4/CW023f capture2. Its bytes are on the
currently unavailable X5. No original call was repeated during this work.
Local `static-war4.py/.json/.txt` reads and verifies PE instruction bytes with
llvm-objdump. Its2120 decoded starts include both frame helpers, alignment
and the preparation region; this is static evidence, not executed coverage.
Low-level inspection is necessary to recover same-call branch transitions,
argument destinations, sparse ownership writes, text and sound order.

`OriginalWarSetup` now composes the pending numeric/frame dependencies with
the entire menu renderer, input handling, live Random choices and settings.
`OriginalWarMenuMemory` retains the two43ee50 bitmaps. Initialization scans
all loaded Objects for each unit ID; the last match wins. Unit globals use
ordinal+1, with zero kept distinct from Object0. No missing Object or ready
participant binding is obtained from an expected snapshot. Literal file data
is initialized explicitly once; this caller never resets retained source inputs.

The nine BATTLEMODE geometry stores preserve all other bytes and masks.
Preset text uses the actual atlas width offsets; bitmap drawing stays at the
owned draw adapter boundary. Frame effects define only size and color, leaving
the other92 backing bytes unknown. Ready labels accept the declared team1/2
domain; another team's retained X remains an explicit unresolved dependency.
Missing live resources, unknown width backing and an empty Random list throw
with rollback. The NULL geometry write is a statically identified unsupported
boundary, not a newly executed source fault or a successful native match.

The implementation retains the short-row cursor value while using its last
cell, popup Jump's restore-then-continue behavior, reserve-before-active copies,
and each preceding Random choice in the next list. Menu201 rerolls and enters
settings in the same call. Settings Attack finalizes troops and clears Attack
before the confirmation sound; arena and difficulty actions retain their second
sound. Start returns `.warMatchPreparation` before43a21f.

Three existing dispatcher files now accept a War continuation. The default
preserves the earlier `.selectionStage` boundary. `advanceWithWar` connects
fresh/cached menu resources, War and common returned output with one staged
environment; its War owner commits only after the outer call succeeds.
Earlier mode4 CPU selection and full original output comparison remain open.
The Native-only outer rollback check is recorded below; the source-coupled
outer check still awaits X5. No game/app runtime route is claimed here.

The small local package contains exact accepted Git cd80865 Core/codec plus
the pending War files and three dispatcher edits. Full code compiles. The first
compile failed on three missing `try` annotations in a guard; adding those
annotations changed no game rules. The retained independent frame rollback
test passed in that package. No existing upstream warning was changed.

`OriginalWarSetupNativeTests` builds a declared24-Object/101-background catalog
through the normal Native loader. Drawing and bitmap results are controlled
dependency responses, not device operations. One test completes an ordinary
menu return, checks two owned resources and last-ID binding, then rejects six
late dependencies: second resource, twentieth format, frame fill, preset return,
second Random candidate list and BEFORE43a21f finalization. Every rejection
checks unchanged World/Actors/globals, owned resources, library text and buffered
events. Release test passed0.059s/build75.04s; session30903/Swift35838 terminal0.
The preceding trial failed before the second Random point because its synthetic
RNG table contained zero; that table was corrected to the existing nonzero
input contract. The failure log remains. No original expectation was changed.

All source-facing comparison tests remain pending. These Native-only checks
establish transactional behavior, not equivalence for574 calls, Windows output,
the full outer return, pixel rendering, input latency, audio or a played battle.
After X5 returns, verify the exact volume and preserved source2 raw/parts before
running the full audit and executing the whole comparator. Keep the accepted
milestone at cd80865 until that acceptance succeeds.

The whole `OriginalLibWarSetupTests` comparator and
`OriginalWarSetupSurfaceAdapter` are now written and compile against accepted
Git cd80865 Core/codec/reference checks. A before-resource observer exposes the
actual staged globals before each allocation; it changes no game operation.
The adapter compares the original numeric API responses with Native DIB-derived
image metadata and owned descriptors. Source Object pointers in the11 unit
slots are canonicalized only in copied comparison records, using the independently
loaded catalog's ordinals. Both bitmap backings, masks and ownership are compared
at every War checkpoint, including the point before sparse geometry writes.
Private caller-stack bytes remain in the separate source audit; they are not
imported into Native or claimed as native ABI equivalence.

The3.46GB corpus is read one immutable atomic case at a time, retaining Native
state across each primary/control chain. `tools/index_lib_war_setup.py` requires
the successful complete source audit, exact raw size/SHA and all574 part hashes.
It only creates an index; it does not change source bytes. The comparator accepts
that index through `NTSD_LIB_WAR_SETUP_INDEX`, verifies its audit/part hashes and
rebuilds the accepted137-Object/101-background catalog once. Source-coupled checks
declare573 returns,571 War returns, two constructor parents, one BEFORE43a21f,
and eight late rollback trials: second resource, text, frame, preset, second
Random result, finalization, present and outer before-return. These checks have
**not run**.
Packaging the new corpus also remains open.

The isolated package compiled the comparator and reran the Native-only six-trial
menu check successfully:0.061s/build152.06s, session68465/Swift39213 terminal0.
No correction to game behavior or original expectations was needed. A separate
synthetic9,437,389-byte tooling probe verifies JSON decoding across the8MiB read
boundary and rejects truncated input. This is not a full corpus audit. Its
report is `local-war-stream-reader1.json` in the interruption directory.

Six retained packaged tests pass185.895s/build15.44s against the same pending
dispatcher:373 Team Tournament setup calls,373 Tournament setup calls and252
selection calls, plus each suite's late rollback checks. Session37523/Swift39833
is terminal0. All263 small-package inputs are pinned; accepted tests, fixtures
and reference code come from Git cd80865. These retained matches establish no
new War match. The20 pending owned files are preserved as an unfinished snapshot;
the frozen source plan/input correction/producer and all295 accepted fixtures
remain unchanged. All study processes are terminal. The full-game goal stays open.

`OriginalWarOuterRollbackTests` now checks the complete native outer call using
the same small DAT catalog and declared image/API responses. One chain creates
all11 menu plus two War resources; a retained call selects eight live Random
fighters. Each chain rejects four later dependencies: waiting bitmap output,
overlay text, present and the final before-return observer. All eight failures
restore World/Actors/globals, resources, RNG, library DC and buffered events.
Both nominal calls complete; the final DC comes from the later output helper.
These are controlled Native ownership checks, not Windows/device/network calls
or source matches. No game code or expected artifact changed. The two Native
tests pass0.113s/build15.74s, including the retained six inner rollback trials;
session4456/Swift42072 is terminal0. The package has264 pinned inputs.

[Static preparation evidence](LIB_WAR_PREPARATION_STATIC.md) now identifies the
next330 starts/1359 bytes, actual `_Battle` filename suffix, CPU destination
seat+10, streams123/125/127 and retained caller-word producers. It executes no
source and does not resolve the setup corpus dependency.
