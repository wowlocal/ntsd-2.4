# Original startup date, music and cursor caller

[OriginalStartupOutput](../../native/Sources/NTSDCore/OriginalStartupOutput.swift)
composes actual WinMain43cfb4..43d078: the clock, two local calendar calls and
date formats, whole music402020 and cursor requests. **49 whole original
callers match native; nine original stops are separately rejected with full
rollback.** Acceptance follows [STARTUP_OUTPUT_PLAN](STARTUP_OUTPUT_PLAN.md).

The source corpus has58 calls in51 scenarios:49 reach43d078, six stop before a
NULL calendar read and three stop at the CRT invalid-parameter request. The nine
stops are separate native rejection contracts, not successful whole matches.
The stopped43d078 is not a WinMain return.

## Reference and controlled entry

The pinned original EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
MSVCR80.8.0.50727.6195 is
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Unicorn2.1.4 runs the original caller, calendar/CRT instructions and every
invoked music helper on one CPU and stack. In particular, both date formats and
`%s\graph.log` execute actual sprintf7817775d on that same CPU. No separate CRT
formatter supplies their output, and no expected calendar result is injected.

FILETIME, timezone, successful ASCII name conversion, C-locale PTD/environment,
allocator backing, COM/file/conversion and cursor responses are declared
research inputs. The earlier whole CRT/window/panel connection is not executed
by this corpus. Initial globals reconstruct from original PE sections, followed
by explicit stimuli. The PE contains period-99, music enabled1 and volume100;
period4 comes from the preceding information/defaults producer and is an
explicit caller input here. The current-directory string and window token are
also declared inputs, not recovered host or earlier WinMain outputs.

All13 installed lib.dll patch sites are disjoint with this caller and its whole
music helper ranges. Original CRT code is unaffected by those EXE patches. This
establishes the scoped byte identity, not completion of other library hooks or
whole library-enabled application startup. No original file, external network,
control pointer or protection structure is changed by the study. EXE/DLL and
Unicorn remain development tooling, absent from the native shipping runtime.

## Date and operation order

The caller invokes `_time64(0)` once, retains the returned64-bit value and uses it
for both dates. After the first `_localtime64`, it reads its own tm fields and
formats `%04d/%02d/%02d/%02d/%02d/%02d` into451d48, including the terminating NUL.
The year adds1900 and month adds1 with the original32-bit arithmetic. Widths
are minimum widths; native formats the six integer operands itself, without a
host printf, Foundation calendar or source expected bytes. Other buffer bytes
remain untouched.

Next it reads signed44d788, multiplies by86400 with32-bit wrap, sign-extends that
product and adds it to the retained64-bit timestamp. It does not multiply the
period in64 bits. The second calendar result supplies the same format at458350.
The corpus includes signed wrap thresholds and extremes, negative periods,
epoch/259200/2038/leap/year boundaries, northern/southern/half-hour DST, ASCII TZ
and failed timezone acquisition. Wrapping can make the second timestamp
negative even with a positive period; the original then returns NULL.

Both formats precede whole402020 with pinned447744 `bgm\main.wma`. Shared
[OriginalMusicPlayback](MUSIC_PLAYBACK.md) preserves release/query/render/volume/
resume behavior and ignored HRESULTs. The source executes all actual invoked
401d30/401c90/401da0/401f30 children and graph-log formatting. Enabled music is
the main case; a disabled control is separate. Create/render/query/get-volume,
conversion and wide allocation failures remain explicit inputs. No device
failure is replaced with success or used to bypass the helper.

The final requests are LoadCursorA(0,7f00) and SetCursor with the exact returned
token, including zero. SetCursor's returned previous token is retained in the
native result. Source entrySP1000f004 becomes1000effc: this segment pushes EBX
and EBP and has not restored them yet. Those source registers become the actual
localtime/sprintf addresses. ESI/EDI and CW037f remain; this is source metadata,
not native C ABI or processwide FPU equivalence.

## Allocation-failure provenance and stopped boundaries

The first clock call returns ECX0. Actual78181971 `push ecx` reserves the tm
helper's scratch word at1000efe4. With the supplied ordinary allocation failure,
781819ad reads that own zero and the helper and `_localtime64` actually return
NULL with errno12. The source stops before43cfd3 reads through that NULL. It does
not execute a mapped-page-zero surrogate result, a subsequent fault or Watson.

This resolves the first caller's previously open provenance in
[CALENDAR_TIME](CALENDAR_TIME.md). The standalone calendar corpus remains
unchanged: its different retained ECX is not a native-owned WinMain producer and
still rejects `unknownAllocatorReturn`. The shared native calendar accepts an
optional proven zero failure return; unknown or nonzero values retain the old
rejection. Startup supplies zero from its own `_time64(0)` contract. The second
calendar uses the first call's own retained tm allocation and does not need an
invented failure word.

The six NULL-read stops comprise that allocation failure, four period-wrap
cases with negative expiry and epoch/period-1. The three invalid-parameter stops
are a valid first date whose expiry exceeds the CRT maximum, an already excessive
first timestamp and unsigned clock wrap from the tick immediately before epoch.
All stop before the unavailable continuation. They are not nine reproduced
memory faults or nine whole native matches.

Own repeated callers retain calendar/timezone caches, interface globals and
wide-path allocations from previous native outputs. A three-call sequence plays,
resumes its cached track, then replaces it and retains both wide buffers. API
interface values are controlled ownership tokens, not Windows/macOS pointers or
measured COM allocations. Late native trials cover the first and second date,
after music at LoadCursor/SetCursor, and after both cursor requests. Globals,
calendar allocations/caches/errno and music allocations commit only after the
whole caller succeeds. External callbacks must stage effects until the enclosing
startup commits.

## Evidence and validation

The source executes all64 caller instruction starts,371 actual EXE and2021 CRT
starts in total. Its static caller/music/calendar inventory contains1734 starts,
1314 executed. This is not all branch outcomes. It records790 calendar helper
returns and216 music helper returns; private helper ABI metadata is source-only.

There are145 actual sprintf returns:104 date and41 graph-log formats. Across
whole and stopped prefixes,1414 ordered events include963 music events,58 clocks,
52 calendar allocations,47 timezone requests,92 name conversions,104 date
outputs and98 cursor requests. There are51 retained calendar allocations and40
wide music buffers. Whole-return counts must remain separate from those totals.

The independent verifier reconstructs complete globals/masks, CRT data/PTD and
owned buffer bytes/masks:2658 original global stores plus165 adapter writes,
4041 CRT stores plus288 adapter writes. It retains101126 original stack stores
and231 stack adapter writes for source provenance; private CRT stack bytes are
not imported into native. All122 blobs and51 atomic case parts verify, along
with all233 prior fixtures and10 vendored codec hashes. Source raw8576099 bytes
have SHA256`559c6d9111a9c70e9f84f378d20911862b58e4217592b5466fd828a5a51aacf7`.

The two-case initial probe and full source capture both completed on their first
attempt. The first native build failed on inferred array element type and the
required typed-read argument; only those Swift type annotations changed before
the next build. Raw9 release tests passed40.683s/build191.05s, including both
retained music chains, calendar corpora and startup panel. An added comparison
of globals before every event passed2 tests0.163s/build52.52s; no source or native
game rule changed. Final packaged9 tests passed40.055s/build0.26s without raw
overrides. Whole globals and masks match; stopped prefixes also compare globals
between their events before native rollback.

The new fixture is1543267 bytes with SHA256
`1adc149af14ba96ef691516a306c6fc820c70f0869b12f5e06f83953ce3cf4b4`.
All233 prior pins remain unchanged,234 current. Complete raw/packed bytes, JSON,
SHA and every blob verify independently. The isolated native export contains
588 committed files, two added Swift files and one fixture,591 total; it also
overlays only the two modified shared calendar/music sources. Six foreign
transform files remain excluded and unchanged. All owned source/native jobs
are terminal. NTSDNative linked; these APIs are not wired into the Practice app.
Jobs and foreign-file hashes are in `build/research/startup-output-work.json`.

CUA inventory returned `Native apps: Error: Sky Computer Use native pipe startup
failed`. No app/window/input action executed; owned source/build PIDs were
revalidated independently. This is a transport failure, not a safety refusal.

[Source](../../tools/oracle_startup_output.py),
[verifier](../../tools/verify_startup_output.py),
[packer](../../tools/accept_startup_output.py),
[evidence](../evidence/startup-output.json),
[tests](../../native/Tests/NTSDCoreTests/OriginalStartupOutputTests.swift).

The preceding complete panel/CRT/window connection, following input caller,
whole WinMain/dispatcher/application join, Windows NLS, actual host timezone,
library transforms, window/input/audio/latency, full matches/all original content
and clean-Mac acceptance remain open. The app still uses its practice engine.
