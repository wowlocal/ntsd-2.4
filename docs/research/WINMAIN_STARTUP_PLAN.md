# Continuous WinMain startup to the first message loop

Recover the whole original43cf40..43d100 startup prefix on one CPU/stack:
startup tick and actual srand, critical-section/COM requests, whole window and
DirectDraw initialization, information/content/panel/defaults, both dates/music/
cursor, input initialization and all five original menu WAV loads. Stop before
the first message-loop setup at43d100; this is not a WinMain return.

Reference: pinned original NTSD2.4 EXE, bundled lib.dll patch inventory, VC80 CRT,
original adinfo/resource bitmap/menu WAV bytes. Unicorn2.1.4 is research tooling.
The earlier full CRT/NLS/load-order chain remains a declared WinMain entry;
Windows NLS is still open and its rejected download must not be retried. No
Windows, actual device/window or application wiring claim follows automatically.
No original file/network/control-pointer/protection mutation is required.

Low-level execution is needed to recover the uninterrupted global/stack lifetime,
original call/return order, shared PTD/random/calendar state and platform/resource
ownership. Do not reset SP/registers, clear scratch, re-seed RNG or import parent
expected globals at child boundaries. Observe source stores and reads; recover
native game-owned producers while retaining unknown private ABI storage as
unknown. Preserve complete raw source structures, even where native compares
only fields whose provenance is declared or owned. Distinguish these masks from
claims of exact private-stack bytes or actual OS consumption.

Finite acceptance:

1. Start at43cf40 with explicit four WinMain arguments and loader-derived game
   globals. Bind actual srand in the same CRT/PTD as later scanf/sprintf/calendar.
   Preserve timeGetTime->seed,458420 reset, InitializeCriticalSection(4554a4),
   CoInitialize(0), actual43bec0 arguments and its misleading numeric return1.
   Critical-section output bytes and COM/platform responses are declared inputs.
2. Continue every startup child without changing its prior globals, stack or
   registers. First use pinned adinfo.txt and its actual missing ad0 content,
   preserving defaults and own period4. Include valid controlled content/bitmap,
   settings periods, windowed/fullscreen/fallback failures and late ordinary
   calendar/input/audio failures. Keep unrelated data/control corruption outside
   scope. All13 library patches must be disjoint or explicitly executed.
3. Carry actual window/DirectDraw tokens into subsequent panel/music/joystick/
   sound requests and exact resulting settings into date arithmetic. Native owns
   all data it computes; no expected child result or unknown source stack word is
   an input. Trace window/helper and joystick capability backing across earlier
   calls. Any newly required unknown value remains an explicit open/rejected
   boundary, not a zero-filled successful match.
4. Compare full global bytes/masks and order at every platform event, semantic
   CRT random/calendar state and all owned allocations/PCM/masks. Preserve full
   source after-states and helper returns separately from stopped/native-rejected
   contracts. Exercise own retained state and rollback after late children,
   including the fifth WAV; stage external effects until the startup commits.
5. Preserve234 prior fixtures and10 vendor hashes. Retain frozen source versions,
   atomic intermediate cases and terminal logs. Isolate native builds from the
   six foreign transform files; compare raw then lossless packaged fixtures with
   affected window/panel/output/input controls. Verify bytes/JSON/SHA/PCs/stores,
   all owned process terminations and exact staged files before milestone commit.

Actual CRT/NLS/Windows/host/platform acquisition, synchronous window callbacks,
worker/message-loop/menu/dispatcher/application join, library transforms,
window/input/audio/latency, full matches/all original content and clean-Mac
acceptance remain required beyond this controlled startup prefix. Progress here
must not be presented as completion of the full game goal.

Acceptance result: [WINMAIN_STARTUP](WINMAIN_STARTUP.md) records23 whole native
chains,5 original-stop and7 unknown-provenance native rejections. Those rejected
paths remain open compatibility dependencies. The finite controlled study is
verified; the full WinMain/application and game goal are not complete.
