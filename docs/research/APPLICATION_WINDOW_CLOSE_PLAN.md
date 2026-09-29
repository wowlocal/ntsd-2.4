# ESC and window close in the app — plan

2026-09-29. Task → contract → milestone: pressing ESC or closing the window
currently stops the app at a boundary ("Menu window message") or kills it
without the original's shutdown → the WndProc's quit path (MessageBoxA
answer, WM_CLOSE, WM_DESTROY, PostQuitMessage) → a complete game session that
ends the way the original does. The original is not executed by the app.

## Static reading (EXE 43b3d0, WndProc)

- Messages 2..0x1c dispatch through byte table 43bc58 / jump table 43bc44:
  WM_DESTROY (2) → 43b4ba, WM_MOVE (3) → 43b466, WM_SIZE (5) → 43b42e,
  WM_ACTIVATEAPP (0x1c) → 43b41e (OutputDebugStringA, then DefWindowProcA);
  every other message there, WM_CLOSE (0x10) included, → DefWindowProcA
  (43bc24). 0x21..0xff also → DefWindowProcA. 0x100..0x112 use 43bc88/43bc74:
  WM_SYSCOMMAND (0x112) → 43b519 returns 1 for SC_KEYMENU (0xf100), else
  DefWindowProcA.
- WM_DESTROY 43b4ba: 4019b0 (Release every sound buffer of both tables, then
  the DirectSound device 44eecc, zeroed), 401d30 (Release 44f04c, 44f048,
  44f044, 44f040, each zeroed), 43d2a0 (43d280 frees 4588a8 and 4588ac);
  then PostQuitMessage(0) unless 458434 ≠ 0 (set around a window
  recreation, 43b86a/43b8a0); returns 0.
- ESC (VK 27, 43b7xx, already ported and compared): MessageBoxA(hwnd,
  "Are you sure to quit?", "LF2", MB_YESNO); on IDYES the same three helpers
  (`OriginalMenuPresentation.releaseResources`) and PostMessageA(hwnd,
  WM_CLOSE, 0, 0); returns 0.
- In the app, `OriginalApplicationMenuSession` passes only `.windowDefault`
  WndProc requests to the platform, so ESC's MessageBoxA is a boundary; the
  Mac message service answers DefWindowProc for a fixed message list; the
  window close button terminates the process directly.

## Declared platform policy (Windows behaviour, not EXE)

MessageBoxA returns IDOK (1) for MB_OK and IDYES (6) / IDNO (7) for MB_YESNO,
from an alert with those buttons (scripted runs: a queued answer; none queued
is a boundary). PostMessageA appends to the queue and returns TRUE.
DefWindowProcA(WM_CLOSE) destroys the window: WM_DESTROY and WM_NCDESTROY
(0x82) are delivered as the next queued messages instead of synchronously
inside DefWindowProcA (the loop dispatches them before any game tick, so the
order of game effects is the same); activation messages sent during
DestroyWindow are not modelled (the WndProc only logs WM_ACTIVATEAPP).
DefWindowProcA(WM_SYSCOMMAND, SC_CLOSE) delivers WM_CLOSE likewise; the
window's close button produces that SC_CLOSE. PostQuitMessage(code) posts
WM_QUIT behind the queued messages. COM Release and free answer 0; Release
of a DirectShow interface reaches the music runtime, of a sound buffer stops
its voice.

## Stages

- **C1 — Core WndProc.** `OriginalWindowInput.receive` gains WM_DESTROY,
  WM_CLOSE, WM_NCDESTROY and WM_SYSCOMMAND, with a `postQuit` request.
  Oracle: `tools/oracle_window_close.py` (subclass of the accepted
  `oracle_window_input.py` harness, new corpus, the old one untouched) runs
  the real 43b3d0 for those messages: WM_DESTROY over empty/full sound
  tables, music present/absent, replay buffers present/absent, 458434 0/1 and
  several Release results; WM_CLOSE/WM_NCDESTROY/WM_SYSCOMMAND (SC_KEYMENU,
  SC_CLOSE, others) with several DefWindowProcA results. Native compares
  every request, ordered store, write mask, result and after-state.
- **C2 — session and runtime.** The menu session passes every WndProc
  request kind through its window channel; `OriginalMacRuntimeMessages`
  serves them under the policy above; the app routes the close button to
  SC_CLOSE, keeps running until WM_QUIT, and adds a script action
  `answer yes|no`.
- **C3 — checks.** App runs: ESC + No continues; ESC + Yes and the close
  button end with a `quit` event, code 0; e2e scenarios for both; existing
  window-input tests and the e2e set.

EXE envelope not recalculated.
