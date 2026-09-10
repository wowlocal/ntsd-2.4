# Startup calendar dependency

Recover the pinned VC80 `_time64`78182857 and `_localtime64`78182153 used by
WinMain43cfb4..43d078. The original first formats the present date, then adds
sign-extended wrapping32(period*86400) to its64-bit timestamp and formats the
expiry date before music402020 and cursor requests. The complete caller remains
the next composition; this dependency must recover real calendar/DST behavior.

Reference: original NTSD2.4 EXE and pinned MSVCR80.8.0.50727.6195, Unicorn2.1.4.
Execute complete time/calendar bodies, real tz initialization, integer helpers,
CRT environment lookup and private tm buffer ownership. Controlled OS FILETIME,
TIME_ZONE_INFORMATION and name-conversion responses, explicit C-locale PTD and
environment/allocator backing are research inputs, not Windows measurements.
Do not preload tzset's initialized flag or substitute expected tm outputs.
No network endpoint, original game file or control pointer is modified.

Finite acceptance:

1. Recover `_time64` actual 100ns epoch subtraction/division, optional output
   writes and subsecond boundaries. Include ordinary historical clock values;
   keep any unsigned wrap rather than assuming POSIX behavior.
2. Execute `_localtime64` and real `_gmtime64_s`, timezone initialization and
   DST transition helpers. Cover the epoch/first-three-days path, ordinary dates,
   month/year/leap/century boundaries,32-bit2038 boundary, supported upper date,
   positive/negative/fractional offsets, northern/southern/absolute transitions,
   exact transition seconds and repeated own calls with a retained tm allocation.
   Treat TZ environment parsing as a dependency if actual lookup selects it.
3. Observe every output byte/mask, ordered time/timezone/conversion/allocation
   request, complete owned tm storage and relevant original global/PTD writes,
   actual instruction starts and returns. Distinguish controlled ABI from native
   private CRT layout. Preserve exact source exceptions/invalid-parameter stops.
   Ordinary allocation failure may expose unknown stack storage: stop before
   following an unavailable pointer and retain that explicit unsupported boundary.
4. Implement shared native numeric/calendar state from original rules; subsequent
   calls use its own timezone/cache/buffer state. No source after-state import,
   host calendar substitution or successful match claim for source-only stops.
   Late observer errors must roll back the complete native operation; external
   effects remain staged until the encompassing startup caller commits.
5. Compare an isolated committed native export excluding six foreign transform
   files. Preserve all231 accepted fixtures and10 vendor hashes. Publish immutable
   new fixtures only after raw acceptance; independently verify source/packed
   bytes/JSON/SHA/masks, then run packaged checks and confirm jobs terminal.

Earlier CRT/NLS/environment initialization, host timezone acquisition, whole
WinMain/music/cursor/input connection, application/device/Windows/latency/audio,
full original game content and clean-Mac acceptance remain open. Static export
lookup uses the DLL's actual image base78130000; an initial read-only inspection
added RVAs to78100000 and displayed unrelated functions, before any new execution.

Final boundary inventory found that the broad corpus downsampled several exact
DST neighbors. Preserve its already published immutable fixture. Add a second
corpus with every start/end boundary at seconds-2/-1/0/+1/+2 for nine years
and all11 declared DST configurations, retaining own June baseline/cache
producers. Require explicit0->1/1->0 source changes and whole native matches
before finite acceptance. Whole WinMain composition remains next.

Both immutable corpora now pass:10844 whole returns and3 separate rejections;
all5 raw/packaged tests pass, including the198 precise transition boundaries.
The finite dependency is accepted in [CALENDAR_TIME](CALENDAR_TIME.md).
