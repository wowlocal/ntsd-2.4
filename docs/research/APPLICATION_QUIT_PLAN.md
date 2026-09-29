# Quit from the main menu: plan

2026-09-29. Parent: [modes survey](APPLICATION_MODES_SURVEY.md) (ef592b4).
Rules: [WORKFLOW](WORKFLOW.md). Written before the change.
**Executor/reviewer:** Claude; independent review open.

**Consumer and criterion:** choosing Quit in the loaded main menu ends the
app the way the original ends: the mode selection releases the sound device
and calls PostQuitMessage(0) (word 0x458434 zero); the next message-loop
iteration's GetMessage returns 0 with WM_QUIT; 43d100's loop returns wParam
and WinMain ends. **Proven blocker:** "Front operation postQuit" in
`OriginalApplicationLoadedMenuSession` (iteration 276 of the survey run).

## Finite changes

1. Core: the loaded menu's front switch records `postQuit` (exactly one
   argument, the exit code) as a front operation with no result (void API).
2. Runtime (declared): after the loaded batch commits, each recorded
   PostQuitMessage posts WM_QUIT (0x12, wParam = code, lParam 0) behind the
   messages already queued; `OriginalMacRuntimeMessages.answer(.get)` already
   returns 0 for WM_QUIT.
3. App: a committed iteration whose loop result is `.quit(code)` emits a
   `quit` event and terminates the process with that code (the original's
   WinMain return; OS-owned objects need no explicit release on macOS).

## Checks

Menu and loaded-menu suites; an app run (virtual clock, temporary overlay):
Down ×7, Attack → `quit` event, exit code 0, WM_QUIT delivered, no boundary;
`tools/app_e2e.py` pass. EXE envelope not recalculated. Out of scope: the
front menu's own exit, ESC/WM_CLOSE and window-close paths.
