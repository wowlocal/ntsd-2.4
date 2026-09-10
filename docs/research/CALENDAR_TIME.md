# Original startup calendar dependency

[OriginalCalendarTime](../../native/Sources/NTSDCore/OriginalCalendarTime.swift)
implements the VC80 time/calendar dependency used by WinMain43cfb4..43d078.
**10844 complete original returns match native across two immutable corpora:
20 `_time64` calls and10824 `_localtime64` calls. Three further original stops
are explicit native rejections with rollback, not successful whole matches.**
The main9755-return corpus and1089-return transition supplement follow the study
defined in [CALENDAR_TIME_PLAN](CALENDAR_TIME_PLAN.md).

The native implementation owns its calendar results, timezone state, names,
transition caches and retained allocations. It does not call a host calendar,
load a CRT/DLL, or import a source after-state. The whole WinMain date-format,
music and cursor caller remains the next composition.

## Reference and boundaries

Pinned original NTSD EXE SHA256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Pinned MSVCR80.8.0.50727.6195 SHA256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Unicorn2.1.4 executes actual `_time64`78182857, `_localtime64`78182153,
`_localtime64_s`78181e8e, `_gmtime64_s`781819dd, lazy timezone initialization,
environment parsing and daylight transition helpers. All execution here is
research tooling, not Windows or native device evidence.

The same CPU first executes the earlier controlled `_initptd`, with an explicit
C locale and absent optional FLS extension. Each case supplies an empty or ASCII
TZ environment array, allocator backing and OS FILETIME/TIME_ZONE_INFORMATION
responses. Narrow timezone-name conversion is explicitly bound to successful
ASCII bytes. These are not measured host environment, timezone, codepage, Windows
registry or allocation-pressure results. No initialized-tz flag or expected tm
result is preloaded. The actual timezone initializer reads the supplied
environment or requests the supplied OS structure itself.

No original game file, external network endpoint or protection/control pointer
is changed. The three exceptional cases stop before the identified unavailable
continuation; no Watson call or subsequent invalid pointer dereference executes.
The supplied CW037f, saved EBX/EBP/ESI/EDI and FS:0 sentinelffffffff survive every
whole call. EntrySP1000f000 and returnedSP1000f004 describe the controlled source
ABI, not the native private CRT stack or processwide FPU flags.

## Clock and calendar rules

`_time64` subtracts116444736000000000 from the supplied unsigned100ns FILETIME,
wrapping64 bits, then divides unsigned by10000000. Subsecond ticks disappear.
It optionally writes both result words. Pre-1970 FILETIME therefore produces
a large positive quotient after unsigned wrap; it does not become a negative
POSIX timestamp. Both optional-output branches and exact neighboring ticks are
compared. Extreme numeric clock inputs are controlled boundaries, not Windows
clock reachability claims.

The calendar first obtains or reuses a36-byte thread tm allocation, then fills
all nine fields with-1 before validating time. Negative seconds returnNULL with
errno22 and all-1 fields. Successful calls retain an earlier errno. The upper
accepted input is32535244799, corresponding to3001-01-01 07:59:59 before zone
adjustment. The additional hours reflect the actual constant; this is not a
generic calendar-year3000 cutoff invented by native.

For inputs greater than259200, the original subtracts the standard timezone
offset, converts that timestamp to Gregorian fields, tests DST using those
fields, then optionally subtracts dstbias and converts again. For the first
three days it converts the original UTC value first, tests DST on that result,
then normalizes seconds/minutes/hours and the limited day/year carry itself.
The epoch can consequently yield December1969 local fields even though direct
negative timestamp conversion is rejected. Native preserves both paths.

Each successful conversion compares all36 tm bytes/masks, including weekday,
year-day and isdst, not only the six date fields consumed by WinMain. The corpus
includes every year1971..3000 around January/March boundaries, selected month,
leap/century/2038 boundaries, epoch/259200 neighbors and exact DST transition
seconds. This is not exhaustive coverage of every timestamp or branch outcome.

## Timezone ownership and DST

Initialization occurs once in each retained state. Empty or absent TZ selects
the OS response. A failed GetTimeZoneInformation retains the original default
timezone28800/daylight1/dstbias-3600 and uses the CRT's fallback transitions.
Successful OS initialization computes bias*60, adds StandardBias only when the
standard transition month is nonzero, and enables DST only when the daylight
month and DaylightBias are both nonzero. Its dstbias is the signed wrapping
minute difference from StandardBias, multiplied by60.

Relative transitions use month/week/weekday; week5 means the last occurrence.
Absolute transition fields select their supplied month/day; the calendar year's
transition cache is still recomputed for the year being converted. Northern,
southern, half-hour DST, nonzero StandardBias and500ms transition controls are
included. End-of-DST milliseconds add dstbias and normalize at most one day,
exactly as the original helper. Both boundaries and all six cached words compare.

Nonempty ASCII TZ is read by the real CRT environment lookup and copied to a
separate owned allocation. The parser uses three name bytes, optional signed
hours/minutes/seconds and a following three-byte daylight name. The daylight
flag is the signed first byte of that suffix, not a normalized boolean:
`PST8PDT` retains80. Its DST bias remains the existing-3600. The fallback rules
change at year2007 from April/October to March/November. The corpus supplies
`UTC0`, `PST8PDT`, `ABC-5:30:45XYZ`, `GMT+3`, `EST5EDT` and an empty TZ control.
Arbitrary environment strings, encodings and host acquisition remain open.

Every subsequent call uses the native implementation's own tm allocation,
environment-copy allocation, timezone/names and transition cache. Native never
reads source expected globals to choose its result. Both64-byte name buffers
and all retained allocation bytes/masks compare, including untouched backing.
The source allocated24 buffers; one belongs solely to a rejected upper-range
call. Their private addresses are controlled ownership tokens, not macOS pointers.

## Precise transition supplement

The final input inventory found that downsampling in the broad corpus omitted
some exact neighboring seconds for half-hour, absolute,500ms and nonzero
StandardBias transitions. The main fixture remains byte-for-byte unchanged.
A separate [transition corpus](../evidence/calendar-transitions.json) closes
that gap with1089 additional whole source/native calls:99 own June baselines
and five seconds around each of198 start/end boundaries. All11 declared DST
configurations run years1970/2000/2006/2007/2024/2026/2100/2400/3000.

Each baseline executes the original calendar to produce its own transition
cache. The source harness derives public timestamp inputs from that cache,
then executes the original again at the nearest seconds-2/-1/0/+1/+2. Each
start produces isdst0/0/1/1/1 and each end1/1/0/0/0. Native independently
executes its own baseline and all five calls; it receives timestamp inputs,
not expected transition/date outputs. The verifier recomputes the timestamp
selection and checks every original isdst result and all stores.

These11 sequences add706 blobs,41066 original stores,35 adapter writes and
7310 source helper returns. Their1565 CRT starts are a subset of the main1843 starts; the supplement adds
precise branch-outcome evidence without increasing that instruction inventory.
No new native calendar rule was introduced to close the gap.

## Explicit stops and rollback

| Original controlled operation | Original boundary | Native contract |
| --- | --- | --- |
| Southern zone at32535244799 | Adjusted GMT input exceeds range; actual invalid-parameter request78138a70 | Reject and roll back whole native call |
| Input32535244800 | Actual invalid-parameter request78138a70 after tm fill/errno22 | Reject and roll back whole native call |
| First36-byte allocation fails | Stop before781819ad reloads its retained scratch word | Reject unavailable return provenance and roll back |

The allocation case has errno12. Its retained source word is78132da8. At helper
entry78181971, `push ecx` reserves that word; this is not evidence of unwritten
physical memory. The volatile register's value belongs to this controlled CRT
context and has no recovered native WinMain producer. It is not imported or
followed as a successful tm pointer. The source stops before loading it; a later
memory fault is not claimed. Actual WinMain register provenance stays open.

Two native late-observer trials verify rollback during initial name conversion
and after a subsequent calendar conversion using an already owned tm buffer.
All globals, allocations, names, cache and errno restore. External effects must
remain staged until the complete encompassing startup operation commits.

## Evidence and verification

40 cases contain9758 source invocations. The9755 whole returns include9718
nonnull localtime results,17NULL/errno22 localtime returns and20 clocks. Native
compares82 ordered requests across the whole and rejected-prefix contracts:
25allocations,13timezone,24name conversions and20clock requests. Two allocation
requests belong to rejected prefixes; source-only after-states are not whole
native matches.

Source1843 actual CRT instruction starts and55803 observed helper returns are
retained; no EXE instructions execute in this dependency. Within the declared
1292-start static calendar inventory,1141 execute and151 do not. Time23/23 and
localtime16/16 wrapper starts execute. These counts are instruction starts,
not all branch outcomes. Private CRT helper return metadata is source evidence,
not a claim that native has the same helper ABI.

The independent verifier reconstructs every recorded data/PTD/allocation/output
write:313439 original stores and80 adapter writes. Its initial data image comes
from the pinned PE plus the identified controlled `_initptd` reference increments
and environment pointer.44 adapter writes address private stack outputs. These
bytes are retained separately from native storage. All7916 blobs and each of40
atomic source parts verify. Full private CRT data/PTD reconstruction is source
evidence; native comparisons cover the declared semantic state and allocations.

The first probe exposed a Python bytearray/ctypes boundary error during name
conversion. It was corrected to pass bytes; the frozen source and terminal log
remain. Two subsequent four-call probes completed. The first broad
capture retained19 atomic cases, then observed `_time64` already at STOP without
a terminal code-hook callback. The final capture also reads terminal registers
after emulation returns, recording10 such unexecuted boundary observations.
It was started only after the earlier job was confirmed terminal. All earlier
parts/source/logs remain; final expected bytes were never edited.

Raw4 release tests passed3.288s/build193.27s, including retained STARTUP_PANEL.
Native numeric/calendar rules passed on their first comparison. The final
test additionally asserts exact9755/3/40 counts already printed by that run.
Packaged4 release tests passed2.819s/build51.56s without raw overrides. Exact
jobs and final owned-file review are in `build/research/calendar-time-work.json`.

The supplemental raw comparison passed5 tests3.386s/build51.40s; final packaged
5 tests passed2.822s/build0.25s with both corpora and retained STARTUP_PANEL.
Together they compare10844 whole returns and3 separate rejected stops, with
118 requests across whole and rejected prefixes.

The main lossless fixture is4473165 bytes from134473385 raw bytes; the precise
transition fixture is1172064 from17675299. All231 prior fixtures remain unchanged,
233 current; the intermediate232-pin set is retained. Complete raw/packed bytes/
JSON/SHA and all7916+706 blobs verify independently, along with10 codec vendor
hashes. The isolated native export has584 committed files plus two new Swift
files and two fixtures,588 total; six foreign transform files are excluded and
unchanged. All owned
source/native jobs are terminal. NTSDNative linked; calendar startup is not yet
wired into the Practice application. Transport deflation only packs research evidence.
The native shipping runtime does not use this DLL, Unicorn or fixture decoder.

CUA inventory returned `Native apps: Error: Sky Computer Use native pipe startup
failed`. No app/window/input action executed; source and native PIDs were checked
terminal independently. This is a transport failure, not a safety refusal.

[Main source](../../tools/oracle_calendar_time.py),
[precise transition source](../../tools/oracle_calendar_transitions.py),
[verifier](../../tools/verify_calendar_time.py),
[packer](../../tools/accept_calendar_time.py),
[tests](../../native/Tests/NTSDCoreTests/OriginalCalendarTimeTests.swift),
[evidence](../evidence/calendar-time.json).

Next is whole43cfb4..43d078: own clock/calendar results, both real formatted
date strings, wrapping period arithmetic, existing music402020 and cursor
requests. Earlier WinMain/CRT/NLS/environment initialization, actual Windows/
host timezone acquisition, library transforms, application input/audio/latency,
full matches/all original content and clean-Mac acceptance remain open.
