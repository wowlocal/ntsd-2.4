# Startup menu-information reading

[OriginalMenuInfoReading](../../native/Sources/NTSDCore/OriginalMenuInfoReading.swift)
implements whole43c4a0..43c685/ret, called by WinMain at43cf94. **194 complete
reader calls match; two more source returns read unknown local bytes and are
explicit native rejections with rollback.** Sixteen additional own
reader/cache-writer/reader chains match32 reads and16 actual cache writes.
This is the finite dependency described in [MENU_INFO_READING_PLAN](MENU_INFO_READING_PLAN.md).
It does not connect the whole WinMain caller or the Practice application.

## Reference and execution boundary

The reference is the pinned original EXE SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`
and VC80 DLL SHA256
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Unicorn2.1.4 executes the real reader, cookie check, fscanf78175f0b,
sscanf78177dc4 and sprintf7817775d. Fopen/fclose, C locale/PTD/thread/locks,
and translated `_read` bytes are declared boundaries. No source file is changed.

Low-level execution recovers which old values survive a failed conversion,
local access order, exact date widths and partial writes. Controlled ordinary
read/close errors are supplied; there is no memory corruption, protection
bypass, external network request or actual Windows filesystem/device execution.
The whole studied EXE bodies are disjoint from all13 bundled-library patches.
This source does not run the DLL installer or resume the blocked CRT/NLS chain.

The main corpus executes all132 reader starts plus all3 cookie-check starts,
and1130 actual CRT starts. The roundtrips execute165EXE/1427CRT starts; their
reader subset omits two failure stores. Combined union is167EXE/1441CRT, including
all32 cache-writer starts. These are actual instruction starts, not proof of all
branch outcomes, every input or native private CRT ABI equivalence.
Every reader has entrySP1000f000, returnSP1000f004, preserved EBX/EBP/ESI/EDI and
suppliedCW037f. Native processwide FPU/Windows behavior is not inferred.

## File, local storage and markers

The reader opens `data\adinfo.txt` with mode `r`. The pinned file contains exactly
`now 0 4 <end>\r\n`; those bytes are preserved. Successful opens supply a declared
32-byte buffered FILE with flags9, descriptorffffffff, bufferINPUT20002000 and
capacity10000hex. Actual fscanf runs against `_read` chunks1/7/4096; close is a
controlled response. Negative `_read` sets errno5 and ends the supplied prefix.
This is after platform text translation, not a model of Windows file opening.

The184 local bytes begin at entrySP-bc and end before the cookie. Their initial
contents are unknown, under separate A5/ramp source controls. Offsets are:

| Offset | Use |
| --- | --- |
| 0 | Failure flag, initialized0 before fopen |
| 4,8,c,10,14,18 | Six temporary date fields |
| 1c | End token |
| 50 | Index token |
| 84 | Period token |

The three token spans are52 bytes apart; this is observed address spacing, not
proof of the original C declarations. `%s` has no field width. The study uses
fitting tokens; it does not truncate strings or establish arbitrary long-token
compatibility. The native record preserves shared storage and rejects reads or
writes beyond recovered backing. The global date token starts4527b0.

After successful fopen, source clears exactly one byte at local1c,84,50 and
then global4527b0, in that order. It scans `%s %s %s %s` into date/index/period/end,
then closes, regardless of the number of assignments. Numeric fclose results
are ignored. Full and partial tokens, embedded NUL and EOF/IO-error prefixes
are retained; already written globals are not reset on an ordinary failure.

The end comparison reads `<end>\0` byte by byte and stops at the first mismatch.
A missing file sets the failure flag but still performs this local comparison
before checking that flag. In both missing-file controls the first local1c byte
is unknown. Source returns0 using its mapped private backing; native throws
undefinedBytes(offset28,count1) and rolls back. This is an unknown-provenance
read, not a memory fault or a successful native whole match. Both source after
states, including their later repeated failure stores, remain immutable.

## Date and retained numbers

Exact `now\0` and `dont_update\0` bypass the date scan. Other tokens use
`%04d/%02d/%02d/%02d/%02d/%02d`: these are **maximum input widths4/2/2/2/2/2**,
with a literal slash between fields. Signed conversion consumes its sign within
the width. No calendar range validation follows; for example99 in a two-digit
field is allowed. Trailing characters after the sixth conversion are ignored.

Before scanning, local date words are set to-99 in order18,14,10,4,8,c. The scanf
argument order is the same list: year,month,day,hour,minute,second. The reader
rejects if any retained field is-99; it does not directly test scanf's return.
Partial scans preserve the remaining sentinels. Native uses the existing integer
scanner on each width-limited field, without changing the shared scanner.

After an accepted date, index and period are scanned separately with `%d` into
44d784 and44d788. **Neither destination is initialized to-99 first.** A failed
conversion therefore keeps its preceding own value. Signed32 wrap, leading
signs and trailing nonnumeric characters retain the original conversion rules.

Both paths are formatted next, even when a converted/retained value is-99:
`data\ad%d.txt` at453c68, then `sprite\sys\ad%d.bmp` at453d40. The index is
reread before each format. Only afterward does the helper test index and period
against-99 and return boolean success. Old bytes beyond each new NUL survive.
An invalid date/end returns before these formats. The82 true and112 ordinary
false returns are all194 complete matches; the other two source false returns
have the separate unknown-read rejection contract.

## Own writer and second reader

Sixteen further chains start from fresh controlled globals, execute this reader,
then the existing [cache writer](MENU_INFO_WRITING.md)43c710, then a fresh reader.
The between-call global ABI is declared: the first executing CPU's own global
bytes pass to the writer's controlled CPU, and its own output passes back.
Native follows the same connection with its own state; it never imports a
preceding expected after-state or expected output file as the next input.

The writer executes actual VC80 sprintf/fprintf/fclose with a7-byte user buffer.
Full, short and failed descriptor writes use the existing behavior: even after
a failed flush, the triggering byte remains for close. The next input consists
only of prefixes accepted by the controlled descriptor response. Across16
chains there are51 descriptor requests and240 accepted bytes. Seven second
readers return1 and nine return0 after partial output; all32 reader calls and
16 writer returns match, including complete writer FILE/buffer state and masks.
This is not an actual disk write or an automatically transactional WinMain.
The encompassing caller must stage state and buffer external effects.

## Comparison and acceptance

The main196 source calls contain1052 request/CRT events,662 actual CRT returns,
5482 global and3600 local CPU stores, including1592 parent stores. Native matches
all1052 events (two are fopen events before the unknown boundary), full global
bytes/write masks, exact parent-store order and all defined local bytes/masks.
Unknown raw local bytes are preserved in source but are neither imported nor
claimed to match. A late native observer error at the second path format checks
rollback of both globals and locals.

The32 additional reader calls add190 events/126 CRT returns; the16 writers add
147 events. The independent verifier reconstructs every reader global/local
snapshot from original stores. It checks full raw/packed bytes, JSON, SHA,
393 main and158 roundtrip blobs, actual code bytes,13-patch disjointness,
all228 unchanged old fixtures and10 unchanged codec vendor files. Shared blob
hashes are not counted as distinct allocations. There are230 current fixtures.

First raw2 tests passed0.158s/build195.51s. The complete raw7 tests passed2.269s/
build51.67s, including both existing content and both existing writer tests.
Packaged7 tests passed2.242s/build0.26s without raw overrides. The isolated export
contains577 committed base files plus two new native files and two fixtures,
581 files total; all six foreign transform files remain untouched/excluded.
Source and owned SwiftPM jobs are terminal. NTSDNative linked; no window was
opened and no new runtime startup/input/audio behavior was verified this stage.

The verifier's first invocation unnecessarily imported Unicorn just for a hash
constant and failed in system Python. The read-only verifier now uses the pinned
constant directly; no source/native/expected bytes changed. Native reader rules
and the two original corpora required no correction to pass comparison.

Raw main5955061/packed1465387 bytes; roundtrip1446631/434011 bytes. Transport
compression only stores research fixtures; no EXE/DLL/Unicorn runs in the native
shipping runtime. Jobs, pins and corrections are in
`build/research/menu-info-reading-work.json`.

[Main source](../../tools/oracle_menu_info_reading.py),
[own roundtrip source](../../tools/oracle_menu_info_roundtrip.py),
[verifier](../../tools/verify_menu_info_reading.py),
[packer](../../tools/accept_menu_info_reading.py),
[tests](../../native/Tests/NTSDCoreTests/OriginalMenuInfoReadingTests.swift),
[main evidence](../evidence/menu-info-reading.json),
[roundtrip evidence](../evidence/menu-info-roundtrip.json).

Next is whole43cf94..43cfb4: own reader -> content43c780 -> panel43cc60 with
actual failure-selected defaults43c690. Then date/time/music/input and the
remaining full WinMain/dispatcher/application joins. Earlier stack provenance,
CRT/NLS, library transforms, Windows/device/input/latency/audio, full matches,
all original content and clean-Mac acceptance remain open.
