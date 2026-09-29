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
- **F3 — RECORDING INFO (selectors 7 and 8).** Static reading (4290f3..4295e9,
  4295e9..42972c): title 4511a0 frame 1 (0x9b, 0x37), panel 4511a4 frame 0
  (0x2c, 0x93). A click (44d060 0, 457580 1) at x 0xd2..0x2da selects the
  edited field 4511c4 by y — 0xcf..0xe1 name 44fd18, 0xe8..0x12e info 44f900,
  0x135..0x147 email 44f890 — and any other click clears it. With a field
  selected, keys 0..0xf9 flagged 'd' go through 422f60: Return becomes '\n'
  (skipped while the field is empty), Backspace removes the last byte, other
  characters append; no length check (the fields are truncated only by
  423a70's in-place terminator). The three fields are drawn by 423a70 (x 0xd5,
  y 0xd1/0xea/0x137, 64 columns, 1/4/1 lines, style and cursor = selected).
  The recording flag 450be4 draws frame 6 at (0x11f, 0x185) when set; hover
  0x11f..0x132 × 0x186..0x199 draws frame 5 and a click toggles it (1 − v).
  "recording" folder button 0x185..0x2dc × 0x184..0x19a (frame 7): sound,
  Sleep(300), ShellExecuteA(NULL, "explore", "recording", NULL, NULL, 1). Help
  0x2c..0x1e3 × 0x1cd..0x1e4 (frame 2, else 1): sound, Sleep(300), "open"
  `http://www.littlefighter.com/record`. Cancel 0x193..0x22e × 0x1a0..0x1b8
  (frame 12): 423480 reload, sound 455614, selector 0, 44d780 −1, 423910.
  OK 0xe7..0x182 × 0x1a0..0x1b8 (frame 13): 423230 write, sound 455610,
  selector 8 (background kept). Selector 8: title frame 1 (0x9b, 0x4b), panel
  frame 3 (0x2c, 0xa7); link 0x60..0x27f × 0x15c..0x174 (frame 4): sound,
  Sleep(300) through ESI (the Sleep import loaded at 4275c5), "open"
  `http://www.littlefighter.com/challenge`; OK 0x13e..0x1d8 × 0x17e..0x196
  (frame 13): sound 455610, selector 0, 44d780 −1, 423910.
  F3a oracle: the F2 harness entered with 44d064 = 7 or 8; 423a70/423940 and
  the other callees on the same CPU; the same declared boundaries. Cases: idle
  (flag 0/1), every region's edges and outside neighbours, field selection and
  clearing, typing into each field (Caps Lock on/off, digits, space, Return in
  empty and non-empty fields, Backspace in empty and non-empty fields, a key
  with no character, several keys in one frame, a name at the 64-column
  limit, a full four-line info), the flag toggle both ways, the folder and
  help buttons, Cancel over two read chunkings, OK over the writer's outcomes;
  selector 8's idle, hovers, link and OK. Native `OriginalFrontRecordingInfo`
  composing the ported helpers (`OriginalBitmapFont` .fourPass), a reference
  check and tests. F3b: the session's alternate for 7 and 8; declared policy
  for "explore" of "recording" (open the overlay's recording folder; scripted
  runs report it); app and e2e checks.

EXE envelope not recalculated.
