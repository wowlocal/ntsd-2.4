# Front-menu items other than START — plan

2026-09-29. Task → contract → milestone: in the app every front-menu item but
START stops at a boundary → the rest of the ported main menu 42xxxx
(`OriginalMainMenu`) plus the unported selector screens → the whole game
reachable from its first screen. The original is not executed by the app.

## Static reading

- `OriginalMainMenu` (ported, compared) handles the clicks: row 2 ONLINE GAME
  sets selector 44d064 = 1 and runs 402b60 (WSAStartup, gethostname,
  gethostbyname, socket, bind, listen; each failure shows MessageBoxA(NULL,
  "<call>()", "Error", MB_OK) and returns without presenting the frame);
  row 3 CONTROL SETTINGS sets selector 6; row 4 RECORDING INFO selector 7;
  row 5 OFFICIAL WEBSITE plays its sound, Sleep(300) and
  ShellExecuteA(NULL, "open", "http://littlefighter.com", NULL, NULL,
  SW_SHOWNORMAL).
- The session feeds the main menu a declared network input with WSAStartup's
  wVersion 0, so ONLINE GAME ends at "WSAStartup()"; but it rejects the
  `startup`, `message`, `sleep` and `shell` event kinds and the main menu's
  `returnWithoutPresentation` ("Menu operation …", "Main menu return").
- The front loop's alternate 4275cb dispatches the selector (EAX): −3, −1, 0
  are ported; 1–3 are the network menu (`OriginalNetworkMenu`, 427ca7..);
  4 at 428808; 6 (CONTROL SETTINGS) at 4289c4..4290f3 — player names, device
  cycling (44fb70.., mod 3), key capture into the control tables, save; 7
  (RECORDING INFO) from 4290f3. These screens draw most of their content as
  GDI text, which the renderer still leaves empty (pending font decision).

## Declared policy

Network play is not provided: WSAStartup reports wVersion 0 (the existing
declared input), so the original's own "WSAStartup()" error is shown and the
menu stays. MessageBoxA as in APPLICATION_WINDOW_CLOSE_PLAN.md (hwnd NULL
allowed). Sleep(300) is a real wait. ShellExecuteA "open" of the URL opens
the default browser in interactive runs; scripted runs record it; the result
is 42 (> 32, success).

## Stages

- **F1 — OFFICIAL WEBSITE and ONLINE GAME.** Session accepts the four event
  kinds (window channel for MessageBoxA and ShellExecuteA — a new `shell`
  request kind — the queue channel for Sleep) and a non-presenting return.
  Checks: app runs of both items (no boundary; the error box; the URL request),
  the e2e set.
- **F2 — CONTROL SETTINGS (selector 6).** Static reading of 4289c4..4290f3
  and its callees, oracle on the front-screen harness, port, app wiring.
- **F3 — RECORDING INFO (selector 7).** Likewise.

EXE envelope not recalculated.
