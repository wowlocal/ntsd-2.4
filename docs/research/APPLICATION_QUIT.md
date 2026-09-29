# Quit from the main menu ends the app

2026-09-29. [Plan](APPLICATION_QUIT_PLAN.md). Parent: [modes survey](APPLICATION_MODES_SURVEY.md)
(ef592b4). Author implementation and machine checks; independent review open.
The original was not executed.

## Result

Choosing Quit in the loaded main menu ends the app as the original does:
the mode selection (index 7) releases the sound device and calls
PostQuitMessage(0); after that batch commits, the runtime posts WM_QUIT
behind the queued messages; the next message-loop iteration's GetMessage
returns 0, 43d100's loop returns `.quit(0)`, and the app reports a `quit`
event and exits with code 0 (WinMain's return; OS-owned objects need no
explicit release on macOS). [Menu before Quit](../evidence/application-quit-capture.png).

- Core: `OriginalApplicationLoadedMenuSession` records `postQuit` (one
  argument, void API) as a front operation instead of stopping.
- Runtime: `OriginalMacRuntimeLoading.finish` collects the codes of
  committed PostQuitMessage calls; the app posts WM_QUIT (0x12, wParam =
  code) after the iteration, and ends on a committed `.quit`.
- `tools/app_e2e.py` also runs this path (Down ×7, Attack) and requires one
  `quit` event with code 0 and exit status 0.

## Checks

- App (release, virtual clock, temporary overlay): `quit` at iteration 276,
  exit 0, no boundary.
- `tools/app_e2e.py`: pass (match reference and Quit).
- `OriginalApplicationLoadedMenuTests` (5), `OriginalMacRuntimeLoadingTests`
  (2), `OriginalMacRuntimeMenuTests` (3): 10/10 in 7.7 min, 3 workers.

Out of scope: the front menu's own exit, ESC ("Are you sure to quit?") and
the window close button. EXE envelope not recalculated.
