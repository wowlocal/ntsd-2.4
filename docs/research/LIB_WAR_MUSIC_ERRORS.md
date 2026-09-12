# War preparation: retained music resource errors

Status: nine saved returned cases match Native; raw, bundled and required
regression checks pass. This card advances ordinary
resource-error contracts toward complete preparation and the full native game
in [CONTINUE_GOAL](../CONTINUE_GOAL.md). It follows
[graphics API errors](LIB_WAR_GRAPHICS_ERRORS.md); the full goal remains open.

## Game question and reference

When music graph creation, an interface query, wide-path allocation, conversion
or RenderFile fails, does the whole War caller still prepare participants,
retain arena resources and create its recording? Which music owners, globals,
later requests and error messages survive?

Use exactly nine saved returned call-00 observations from
[War resource errors](LIB_WAR_PREPARATION_ERRORS.md): normal controls s00/s01
and music errors s20/s21/s23/s24/s25/s26/s27. Nine source memory faults remain
separate. The normally returned s10/s11 private dimensions are not accepted here.

Pinned EXE SHA
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`, lib.dll
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`, VC80
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Historical observations used Unicorn 2.1.4, CW023f, C locale, flat 32-bit
segments/explicit FS and controlled API results. These saved API, allocation,
memory and event records recover order and lifetimes; they do not establish
actual Windows COM ownership, codecs, heap or device behavior.

This card reads saved artifacts and executes Native only. It imports no source
producer, runs no original EXE/DLL/emulator, and repeats no capture or historical
audit. Three safety incidents and their exact-trigger uncertainty stay open.

## Contract and Native ownership

| Case | Declared result | Retained behavior | Targeted Native rollback callback |
| --- | --- | --- | --- |
| s00 | Nominal primary | Five arena wrappers, one wide owner | Render own buffer |
| s01 | Nominal control | Fifteen arena wrappers, one wide owner | Render own buffer |
| s20 | Create -1/output0 | Message; skip allocation/Render | Initialization-error message |
| s21 | Control query -1/output0 | Continue other queries/Render; no cache/Run | Next event query |
| s23 | Position query -1/output0 | Continue notify and later work | Event notify +34 |
| s24 | Audio query -1/output0 | Skip get/set/audio Release; retain cache/Run | Final control Run |
| s25 | Allocation NULL | Still convert and Render NULL; no wide owner | Render NULL |
| s26 | Render -1 | CloseHandle, message, volume, cache/Run continue | Render-error message |
| s27 | Conversion0/no writes | Render own opaque backing; unknown masks remain | Render opaque buffer |

The test adapter builds responses from `resourceFailureInput.music` and frozen
producer defaults. Numeric results and optional output words are independent;
nil output differs from explicit zero. `spec.music` is absent from these nine
cases. Expected responses supply comparison only. The previous nominal whole
War preparation adapter now uses the same independent response builder.

The allocation contract in `tools/oracle_lib_war_preparation.py:124–136`
declares token 2c020020, 30 bytes of a5 backing for primary or a byte ramp for
control, with defined=false and live=true. Native creates its own record from
that declaration. In s27 conversion none/result0 writes nothing; Render passes
the owned opaque bytes without UTF-16 decoding. In s25 allocation supplies
pointer0/bytes=nil, conversion returns0/bytes=[] and Render receives NULL with
no string. Neither branch establishes a real Windows conversion implementation.

Messages in s20/s26 belong to the final preparationGraphics event and whole
preparationBitmap event, between bodyMusic events 7/8 and 20/21 respectively.
They must not consume a bodyMusic index. The runner compares each complete
46,144-byte message globals snapshot against its own shadow, initialized from
Native globals at resumeMusic entry and changed only by music store callbacks.
The Core addition forwards an optional store observer through resumeMatch to
the existing play implementation; it changes no game rule. On success the
shadow equals returned Native globals, including masks. The source message
blob has no separate mask; whole checkpoints/after records retain mask checks.

## Finite comparison and verification plan

Nine independent Native chains perform ninety prefix calls. Source proof IDs
are local 0..9 in every chain; s01 links to accepted bound cases 11..20, while
the other eight link to 0..9. These overlap twenty distinct saved references,
not ninety new original starts. Each parent constructs its own World/Actors
and catalog resources using the existing accepted comparator.

Compare nine complete returns, 12,028 ordered front events, 144 numeric
checkpoints, 221 bodyMusic events, two messages, 827 graphics API requests
including those messages, 55 new wrapper owners and seven wide owners/210 bytes.
Full records, masks, recordings, music state and owners remain compared by the
whole War transaction. Twenty-seven Native observer-error trials add one exact
callback per case plus recording and beforeReturn stops. The exact stopped
front-event counts are 926, 1096, 915, 916, 918, 930, 926, 928 and 926.
Reaching the selected callback follows processing of the target result; it
does not mean the callback's own returned response has already been applied.

The frozen plan, initial files, regression supplement and job records live in
`build/research/lib-war-preparation/war-music-errors-native-20260912/`.
The plan protects 57 source/evidence inputs and 350 existing fixtures. Limits
are 20GiB new task storage, the existing 6GiB internal reserve, three correction
rounds, 1800s for initial/War test jobs and 2400s for shared regressions. Large
files use task-owned X5 UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`; shipping
fixtures remain regular self-contained files. Unchanged prior candidate files
may be APFS-cloned only after matching their manifests/current bytes; all new
candidate bytes are verified and the prior candidate remains unchanged.

Required regressions: War preflight22/matrix256/nullable3/partial6/graphics8,
MusicPlayback, GraphEvents, CharacterMenuMusicSurface, MatchLaunch and both
Tournament/TeamTournament bracket suites. The regression supplement records
21 unique bundled methods. Raw comparison, lossless raw/JSON/blob transport,
bundled tests, independent review, complete Native archive and Git equality
are separate acceptance gates. Packaging alone is not Native acceptance.

Root owns Core/adapter/test/publication; catalog_test_completion owns the new
packager and nine fixtures; war_contract_review independently reviews contract
and code without source or Native execution.

## Accepted result and preservation

The first frozen Native candidate passed without a correction. Raw comparison
passed in 56.435s after a 281.27s release build. Six bundled War methods passed
in 370.173s after a 0.34s build; the new music comparison took 56.316s, retained
graphics 50.373s, nullable 18.941s, partial 38.860s, preflight 16.807s and the
256-call matrix 188.877s. A separate run passed all fifteen shared methods in
224.595s after a 0.14s build. Every `NTSD_` raw override was removed for both
bundled runs. All three jobs are terminal with exit0.

There are 21 unique bundled methods across those two runs, 594.768s total;
including the raw run gives 22 method executions. The new test executes nine
whole returned cases and 27 rollbacks per run, eighteen case comparisons and
54 rollback trials across raw/bundled. Its 180 Native prefix executions overlap
twenty saved references. The Core observer forwarding changes no game rule;
no expected byte, mask or original resource changed for acceptance. Existing
trailing-closure compiler warnings remain.

Nine self-contained fixtures, 43,240,464 packed bytes, reproduce every
321,911,802 raw byte and the complete JSON/SHA. Transport verifies 6,503 blob
entries / 305,288,594 bytes, 1,103 distinct blobs / 55,563,532 bytes, and all
ninety prefix links. All 350 old fixtures and 57 source/evidence pins remain
unchanged. The current package has 359 fixtures and 804 Native files, each
matching the frozen candidate, staged Git blob and complete Native archive.
The candidate uses 791 verified APFS clones and thirteen changed/new copies.

The Native archive is 3,980,011,520 bytes. The separate evidence archive has
96 members / 324,728,212 member bytes in 324,904,960 archive bytes. Every member
was read back and hash-checked. Before this archive ran, independent review
found that metadata additions could overwrite planned input hashes in the
verification map. The corrected gate independently rechecks all 57 original
plan pins after all metadata merges; the unused draft and review are retained. No
actual input change or Native mismatch was observed. Prior source-fault
archives and all three safety incidents remain separate and unchanged.

The immutable pre-test review's pending gates describe its earlier phase.
Terminal results, current acceptance gates, archive review and exact pins are
in [the machine evidence](../evidence/lib-war-music-errors.json). This card
brings accepted returned calls in the resource-error corpus to 26 of 28;
it does not accept the two remaining normal returns or the nine source faults.

## Open dependencies

s10/s11 still need an owned Native retention/join for private dimensions.
The next read-only review locates the saved producers in accepted bound0001:
the last BATTLETROOPS loader's descriptor bytes [72..<80] and its copy's
GetDC output/result. Their bytes and masks survive bound0002..0009 without
intervening writes. The menu and preparation caller depths differ by 0x28;
a global last-GetDC value would incorrectly overwrite the needed older slot.
The review in `next-boundaries-review.json` proposes retaining separate owned
producer/consumer fields and including them in rollback. It is readiness
evidence, not acceptance of those two returns or permission to import a stack.

Nine original source faults need separate Native rejection/rollback contracts; a rejected fault
is not a successful returned match. Existing failures, expected bytes, masks,
frozen producers and safety incidents stay unchanged.

Whole War gameplay, own full catalog/startup/library/outer loop/application,
complete matches, all content/network and Windows/device/clean-Mac acceptance
remain part of the full goal. These controlled tests do not prove a playable,
validated native game or actual audio output.
