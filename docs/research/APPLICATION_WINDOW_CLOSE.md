# ESC and window close in the app

2026-09-29. [Plan](APPLICATION_WINDOW_CLOSE_PLAN.md) stages C1–C3. Before
this card ESC stopped the app at a boundary ("Menu window message") and the
close button killed the process without the original's shutdown. The
original was executed only in the Unicorn oracle below.

## C1 — the WndProc quit path

`OriginalWindowInput.receive` now also handles WM_DESTROY (43b4ba: the
release helpers shared with ESC's IDYES branch — sound buffers and device,
the four DirectShow interfaces, both replay buffers — then PostQuitMessage(0)
unless 458434 is set; returns 0), WM_CLOSE and WM_NCDESTROY (DefWindowProcA)
and WM_SYSCOMMAND (43b519: SC_KEYMENU returns 1, others DefWindowProcA). The
new request kind `postQuit` carries PostQuitMessage.

Oracle `tools/oracle_window_close.py` runs the real 43b3d0 on the accepted
window-input harness (a subclass; PostQuitMessage added as a recorded
boundary) — 74 calls: WM_DESTROY over sound tables 0/1/2/400+80 entries,
music present/absent, 458434 0/1, three Release results, four replay-buffer
combinations and an already-released state; WM_CLOSE, WM_NCDESTROY and five
WM_SYSCOMMAND values with three DefWindowProcA results. The new corpus
(`original-window-close.json`, SHA-256 6a5bcb04…) matches Native in every
request (5,984 Release, 100 free, 29 PostQuitMessage, 18 DefWindowProcA),
248 ordered stores, write masks, results and after-states
(`OriginalWindowInputTests.testQuitPathMessagesMatchTheOriginal`;
[evidence](../evidence/window-close.json)). The accepted 4,369-callback
window-input corpus is unchanged and still passes.

## C2 — session and runtime

`OriginalApplicationMenuSession` passes every WndProc request kind to the
platform on its window channel (before: DefWindowProcA only).
`OriginalMacRuntimeMessages` answers them under the plan's declared Windows
behaviour: MessageBoxA through the app (IDOK; IDYES/IDNO), Release (music
interfaces to the music runtime, sound buffers stop their voices, the
DirectSound device), free, PostMessageA (queued, TRUE), PostQuitMessage
(WM_QUIT queued), DefWindowProcA(WM_SYSCOMMAND, SC_CLOSE) → WM_CLOSE next,
DefWindowProcA(WM_CLOSE) → the window is destroyed: queued input dropped,
WM_DESTROY and WM_NCDESTROY next, later input ignored; WM_NCDESTROY hides the
window. The app shows MessageBoxA as an alert with Yes/No (or OK) buttons —
scripted runs take `answer yes|no|ok` script actions and stop at a boundary
without one — routes the close button to WM_SYSCOMMAND(SC_CLOSE) (after a
boundary stop it closes the app directly), and stays alive until WM_QUIT
instead of ending with its last window. Events: `messageBox`,
`windowDestroyed`, `quit`.

## C3 — checks

- App (release, virtual clock): ESC → No continues, before and after START;
  ESC → Yes ends with `quit` code 0 (iterations 25 / 155); the close button
  likewise (24 / 154). After No the mode menu shows its controls panel — the
  same frame as after any other unmapped key (Q), i.e. the ported menu's
  response to a key press, not part of the quit path.
- `tools/app_e2e.py`'s quit check now covers the main-menu Quit, ESC (No then
  Yes) and the close button; all three pass. The e2e set passes (vs with the
  quit checks, mission, demo, war, playback, team-tournament); tournament
  differed once in its milestones while a unit-test run loaded the machine and
  passed when rerun alone. The differing field was not captured (the report
  truncates); a likely cause, not verified, is a real-time music track end
  (a finished track posts the graph notification) in this long scenario
  under load. The tournament script presses neither ESC nor the close button.
- `OriginalMacRuntimeMenuTests.testQuitPathAnswersFollowTheDeclaredWindowsBehaviour`
  and the updated queue test pass; bootstrap, host-session, observed-iteration
  (its default-message test now checks the recovered WM_SYSCOMMAND),
  menu-input, window-input and window-lifecycle suites pass.

Not modelled (declared): the activation messages DestroyWindow sends (the
WndProc only logs WM_ACTIVATEAPP), WM_DESTROY delivered synchronously inside
DefWindowProcA (here the next queued message, before any game tick).

EXE envelope not recalculated.
