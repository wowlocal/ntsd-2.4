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
- **F2 — CONTROL SETTINGS (selector 6).** Static reading in
  APPLICATION_FRONT_MENU_ITEMS.md. Every callee is already ported and
  compared: 422b00 key name (`OriginalKeyName`), 422f60 key character with
  GetKeyState(VK_CAPITAL) (`OriginalMenuCharacter`), 423480 settings reload
  (`OriginalSettingsLoading`), 423230 settings write (`OriginalSettingsWriting`),
  423910/43ef50 background release (`OriginalMenuPresentation`), 401290 text,
  401a30 sound, 43f010/43ef70 bitmap drawing, VC80 sprintf.
  Control table (from the code): player p's words at 44fb70 + 80·p — word 0
  the device (keyboard 0, else a joystick whose four button bytes are at
  453fc4 + 48·device), cells 1 + 20·p + row for the seven rows; keyboard keys
  in 44fb70[cell], joystick buttons in 44fb7c[cell].
  Oracle: a subclass of `oracle_front_screen_alternate.py`'s harness that
  enters 4275cb with EAX = 6 and runs through the dispatch chain to
  presentation 42873e; the callees execute on the same CPU; GetKeyState,
  Sleep, ShellExecuteA, fopen/fclose/_read (reload), the writer's FILE and
  free stay declared boundaries. Cases: hover and click of every region
  (help link, four device cells, four names, 28 key cells, OK, Cancel);
  device cycling; name editing (letters with Caps Lock on/off, backspace,
  return, the 10-character limit, non-letter keys); key capture (keyboard
  VKs, none pressed, joystick buttons 0–3, none); OK over the writer's
  outcomes; Cancel over reload outcomes (present, absent); null bitmaps.
  Native: `OriginalFrontControlSettings` composing the ported helpers, a
  reference check over the corpus, then the session's alternate for
  selector 6.
- **F1b — the network menu (selectors 1–3).** `OriginalNetworkMenu` is ported
  and compared ([NETWORK_MENU](NETWORK_MENU.md)); its accepted composition is
  the front loop's actual 427ca7 continuation (`otherSelector`), the menu body,
  then the real presentation (42873e tail) or epilogue (4287de, a return without
  presentation). The session follows that composition after
  `OriginalFrontMenuLoop.run` returns `otherSelector` with selector 1–3, then
  returns as the other menu paths do. Owned storage: the 51 hostname bytes at
  World+7d8 (unknown until 1→3 writes them) persist in the session state; the
  caller-local 0x400 bytes (callerSP+14) are fresh each call apart from the
  bytes this call's body wrote (as the reference joins them). Inputs: timeGetTime
  on the queue, GetKeyState(VK_CAPITAL) from the iteration's responses, the
  DDBLTFX backing as the prelude's. Declared policy (no network play, Winsock
  as after a failed WSAStartup — not the EXE): socket() INVALID_SOCKET,
  closesocket/WSACleanup/connect/send/recv/sendto SOCKET_ERROR, host lookups
  NULL; MessageBoxA, Sleep and ShellExecuteA (forum link) run after the body
  returns, as in F1. Expected app behaviour, from the ported code: choice
  screen; host waits with its dot animation until Back; client edits the
  hostname, Enter draws Connecting, the next frame shows the original
  "socket()" / "Client Error" box and returns without presentation; Cancel
  releases the background, runs 402d70 (listener 0: closesocket, clear,
  cleanup) and returns to the main menu. Checks: app run through every
  action (no boundary; the box order WSAStartup(), InitWinSock(), socket());
  e2e `online_check`; the network-menu, front-menu and runtime suites.
- **F3 — RECORDING INFO (selector 7).** Likewise.

EXE envelope not recalculated.
