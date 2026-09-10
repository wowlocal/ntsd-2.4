# Whole startup date, music and cursor caller

Recover actual WinMain43cfb4..43d078 after STARTUP_PANEL and before INPUT_STARTUP.
Run `_time64(0)`, both `_localtime64` calls, both original VC80 sprintf formats,
whole402020 music and its children, LoadCursorA(0,7f00), then SetCursor. The
caller keeps the first timestamp, adds sign-extended wrapping32(period*86400),
and consumes its own two calendar results. The string at447744 is the pinned
music path. Do not disable music or substitute calendar/format success.

Reference: pinned original EXE/MSVCR80 on one Unicorn2.1.4 CPU/stack. Earlier
CRT/WinMain/window/panel state is a declared controlled entry, not a recovered
whole application. FILETIME/timezone/ASCII conversion, COM, allocator/file/cursor
responses are explicit research boundaries. Original instructions establish
operation order, full globals/write masks, live allocations and retained stack/
register provenance. No external network or original game-file mutation occurs.
All bundled DLL patch sites must be checked for disjointness with this caller
and its whole helpers. No DLL/Unicorn/EXE belongs in the native shipping runtime.

Finite acceptance:

1. Execute the full caller with original period4/path and enabled music, then
   controlled periods around signed multiplication wrap, negative periods,
   epoch/year/leap/2038 boundaries and northern/southern/fractional DST dates.
   Compare both date strings, all global bytes/masks and actual input timestamps.
2. Preserve real music/helper/format returns and ordered platform requests,
   own interface/wide-buffer generations and ordinary create/render/query/
   conversion/allocation failures within the existing music contract. Test
   repeated whole callers using their own retained calendar/music state.
3. Record actual caller SP/register transitions. In particular, dynamically
   test whether `_time64(0)`'s ECX0 is the own producer of the tm helper's
   reserved `push ecx` word on allocation failure. Only propagate established
   own provenance; do not import an expected stack value. Keep original null
   calendar reads and invalid-parameter requests as explicit stopped boundaries,
   not whole native matches. Do not follow an unavailable pointer or invoke Watson.
4. Compose shared native calendar and music APIs. Add optional write observation
   for whole global masks without changing old helper behavior. Whole native
   exceptions after date/music/cursor operations roll back all globals, calendar,
   interface and allocation state; buffer external effects until startup commits.
5. Preserve all233 accepted fixtures/expected bytes and10 codec vendor hashes.
   Isolate native builds from the six foreign transform files. Compare raw output
   with retained calendar/startup-panel/music controls, publish lossless fixtures
   only after acceptance, independently verify bytes/JSON/SHA/stores/coverage,
   run packaged tests and confirm every owned process terminal before commit.

The earlier complete panel-to-caller/CRT/window connection, following input and
full WinMain/dispatcher/application connection, actual host timezone/Windows NLS,
library transforms, window/input/audio/latency, full matches/all original content
and clean-Mac acceptance remain open beyond this controlled caller.
