# Application message loop and own startup continuation

Recover43d100..43d21f/ret16 after the accepted continuous WinMain startup.
The pinned original NTSD2.4 EXE/VC80/resources and Unicorn2.1.4 are the reference
artifacts/environment. Actual instructions establish message-vs-timer order,
shared28-byte MSG backing, signed GetMessage behavior,458580 counter wrap and
ESI baseline/return lifetime. Declared Win32 queue/clock/COM responses do not
measure Windows delivery, reentrancy or device timing. No network access,
original-file changes, protection/control corruption or fault continuation.

Finite acceptance:

1. Decode and byte-check the entire loop/epilogue; execute controls for empty
   and nonempty queues, GetMessage positive/zero/negative, retained MSG after
   an ordinary error, signed counter boundaries and live platform changes.
   Preserve PeekMessage removeFlag0, exact request order, no timer while handling
   a message, and no counter increment on the GetMessage-zero exit.
2. Compose the shared native timer. Clock reads remain fresh, baseline persists
   through messages,33/3ms and signed capped Sleep retain the accepted rules.
   Controlled dispatcher/recovery returns remain clearly declared boundaries;
   they do not claim execution of the whole43e9a0 body or game tick.
3. Deliver selected keyboard/mouse/joystick/lifecycle messages into actual
   original43b3d0 and existing native callbacks, preserving own changed globals,
   timer target and loop counter. Known queue bytes come from declared API writes;
   unknown MSG fields remain masked and rejected when needed natively. Do not
   import original stack bytes to resolve a failed first GetMessage.
4. Continue fresh accepted startup chains on the same CPU/stack without resetting
   SP/registers/globals or seeding a second clock. Reproduce the entire parent.
   Own message-only chains may reach the actual WinMain epilogue; a due own game
   dispatch must stop at the real43e9a0 entry, retaining that dependency, rather
   than injecting a successful result to obtain an application-return claim.
5. Compare full declared globals/outer counter/message bytes and masks, ordered
   requests/stores, callback returns and baseline at every iteration. Native late
   failures preserve state. Keep opaque platform fields separate from game-owned
   values, and source/native rejected cases separate from successful matches.
6. Preserve235 old fixtures/10 vendor hashes, source snapshots and atomic parts.
   Isolate native builds from six foreign transform files. Run raw/packaged
   acceptance with affected timer/startup/input controls; independently verify
   full bytes/JSON/SHA/instruction provenance/terminal jobs before committing.

Earlier CRT/NLS/full dispatcher/worker, full WndProc routing/reentrancy, unknown
private storage, library transforms and the actual application/window/input/
audio/latency/Windows/full matches/all content/clean-Mac goal remain required.

Controlled acceptance is recorded in [APPLICATION_MESSAGE_LOOP](APPLICATION_MESSAGE_LOOP.md):
63 returns at declared platform/body boundaries and1 own required-dispatch stop.
The actual full dispatcher/application and earlier CRT/Windows dependencies stay
open; these counts do not redefine completion of the full game goal.
