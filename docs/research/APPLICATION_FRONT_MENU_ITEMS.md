# Front-menu items other than START

[Plan](APPLICATION_FRONT_MENU_ITEMS_PLAN.md). The original is not executed.

## F1 — OFFICIAL WEBSITE and ONLINE GAME (2026-09-29)

`OriginalApplicationMenuSession` accepts the main menu's `startup`, `message`,
`sleep` and `shell` events and its non-presenting return. WSAStartup is
answered by the session's existing declared network input (wVersion 0).
MessageBoxA, Sleep and ShellExecuteA are performed right after
`OriginalMainMenu.run` returns — their results are unused and no platform
call follows them inside the main menu — MessageBoxA and ShellExecuteA on the
window channel (a new request kind `shell`), Sleep on the queue as the loop's
own Sleep. `OriginalMacRuntimeMessages` accepts ownerless boxes (hwnd NULL)
and answers ShellExecuteA("open", file) with 42 after handing the file to the
app, which opens it in the default browser (scripted runs report a
`shellOpen` event instead).

**App:** OFFICIAL WEBSITE plays its sound, waits 300 ms and opens
`http://littlefighter.com`; the menu keeps running. ONLINE GAME shows the
original's two error boxes, "WSAStartup()" then "InitWinSock()" (caption
"Error"), and sets selector 1 — the network menu, which the session does not
wire yet: the next frame stops at "Menu continuation otherSelector" (F1b).

**Checks:** `tools/app_e2e.py` gains a website check (one `shellOpen` of the
URL, exit 0) run with the vs scenario; `OriginalMacRuntimeMenuTests` cover
the ownerless box and ShellExecuteA answers; the main-menu, network-menu,
bootstrap, host-session, observed-iteration and menu-input suites pass (17).
The e2e set passes except one intermittent Mission mismatch: only the body-1800
capture hash differed (every counter, iteration and the music state were
equal) and two reruns matched exactly. The harness now keeps each
scenario's captures in `build/research/e2e/<scenario>/`; the next mismatch
(tournament's main-menu capture) showed the game's cursor at the real
pointer's position: AppKit mouse events reached scripted runs. Scripted runs
now take keyboard and mouse input from their script only (the app ignores
real events when `--script` is given); the whole set then passed on the
release app and on the rebuilt packaged app.

**F2 static reading (selector 6, 4289c4..4290f3):** title and panel bitmaps;
a help link (46..540 × 475..498: sound, Sleep(300), ShellExecuteA "open"
`http://www.littlefighter.com/control_index.html`); key capture for the
selected cell 4511e0 (keyboard device: the first VK 0..0xf9 whose byte is
'd' → 44fb70[cell]; joystick: the first of four buttons at 453fc4+device·48 →
44fb7c[cell]); name editing for player 4511c8 (VK → character 422f60, at most
10 characters, backspace, return); per player (x 0xc2 + 0x8b·p, names at
44fcc0 + 11·p): device cycling (44fb70[p·20] + 1) mod 3, name text (colour
0xff4619 when selected, else white; 401290), seven rows (y 0x11b + 0x16·r)
of key names (422b00) or joystick axes/buttons (text 449750 / sprintf
449744 of 44fb7c+1), device icons 451180/451174/451164/451184/451194;
Cancel (0x244, 0x1b9, frame 12: sound 455614, 423480, selector 0, 44d780 =
−1, 423910) and OK (0x198, 0x1b9, frame 13: sound 455610, 423230 settings
write, selector 0, 44d780 = −1, 423910).

## F2 — CONTROL SETTINGS: port and comparison (2026-09-29)

`OriginalFrontControlSettings` (Core) ports 4289c4..4290ee: the shared
recovered helpers run inside it (401290 text, 401a30 sound, 422b00 key
names, 422f60 key characters with GetKeyState, sprintf "Button: %d",
423910/43ef50 background release) and report their events; bitmap drawing,
GetKeyState, the 423480 reload and the 423230 writer are the caller's, Sleep
and ShellExecuteA are events. `OriginalSettingsLoading.loadAndContinueStartup`
takes `flagClearValue: nil` for a caller without the startup flag store.

Oracle `tools/oracle_front_control_settings.py` extends the accepted front-menu
completion harness (a fresh prologue, 4275bc with 44d064 = 6 through the
original selector dispatch, presentation and the real return; GetKeyState a
declared boundary; 423480's file boundaries with its own caller frame):
106 cases — idle and hovers, device cycling, names, 56 key cells over keyboard
and joystick devices, key and button capture, name editing (Caps Lock, digits,
space, backspace, return, the 10-character limit, a non-character key), the
help link, OK over the writer's outcomes and Cancel over two read chunkings;
plus the control variant (reverse resources, ramp backing).
`FrontControlSettingsReference` replays the completion parent and then every
case: all 29,076 events (872 draws, 3,392 text outputs, 435 formats, 17 sound
requests, 8 settings writes, 8 reloads with 432 file events, the help link)
and the presentation and return snapshots (globals, World, CRT, pointers,
bitmap ownership) match — both corpora
([evidence](../evidence/front-control-settings.json),
[control](../evidence/front-control-settings-control.json)). A corpus with one
altered text coordinate fails at that case.

Recovered behaviour worth noting: a click on OK or Cancel is handled once per
player (the check sits in the player loop), so it writes (or re-reads) the
settings four times and plays its sound four times; the help link has no
click reset; joysticks cannot rebind the four direction rows; name editing
ignores Return and keys past ten characters without consuming them.

## F2b — CONTROL SETTINGS in the app (2026-09-29)

The session's alternate runs `OriginalFrontControlSettings` for selector 6 and
returns to presentation. Per-iteration inputs (`Responses`): data\control.txt
as 423480 reads it and GetKeyState(VK_CAPITAL). The 423230 writer's output is
an effect (`settingsFile`); the reload reads the current file; Sleep and
ShellExecuteA (the help link) run when the screen returns. The front
background, released on OK/Cancel, is reloaded on the next frame as the
original does: the prelude asks the queue for timeGetTime only when 4511ac is
0 (to choose MENU_BACK%d), takes a 0x1f50 allocation the runtime offers, builds
the bitmap through the observed bitmap provider and adopts it.

Declared policy (Windows text mode and file system, not the EXE): the game
directory is the overlay; data\control.txt is read from the overlay when the
player has saved settings, else from the package, CRLF → LF; OK writes the
overlay's copy with LF → CRLF. Scripted runs answer GetKeyState with Caps Lock
off; interactive runs report the real toggle.

**App:** CONTROL SETTINGS opens with the original bitmaps (devices: keyboard,
keyboard, joystick 1, joystick 2 from control.txt; names and key labels are
GDI text, still blank); selecting player 1's "up", pressing Q and OK writes a
control.txt equal to the packaged file with that one key changed (87 → 81), in
CRLF form, and returns to the front menu with a new background. After a
relaunch on that overlay, Q moves the mode-menu cursor up and W no longer
does. `tools/app_e2e.py`'s vs scenario now also runs this controls check; the
whole e2e set passes (vs with the quit, website and controls checks, mission,
demo, war, playback, tournament, team-tournament). The bootstrap, host-session,
observed-iteration, menu-input, front-screen, front-menu, settings-loading,
CONTROL SETTINGS and Mac runtime-menu suites pass (34).

## F1b — the network menu in the app (2026-09-29)

When the front loop returns its actual 427ca7 continuation with selector 1–3,
the session runs `OriginalNetworkMenu` and then the real presentation: the
42873e tail, or the 4287de epilogue (no presentation), as the accepted
reference composes them; the iteration then returns like the other menu paths.
The presentation code is shared with the loop's completion. The 51 hostname
bytes at World+7d8 are session state (unknown until 1→3 writes them); the
0x400 caller-local bytes are fresh each call except the bytes this call's
body wrote. timeGetTime comes from the queue, GetKeyState(VK_CAPITAL) from the
iteration's responses, the fill's DDBLTFX backing is the prelude's.

Declared policy (no network play; Winsock as after the failed WSAStartup, not
the EXE): socket() returns INVALID_SOCKET; closesocket, WSACleanup, connect,
send, recv and sendto return SOCKET_ERROR; any other Winsock request (host
lookups, inet_addr, htons — unreachable once socket() fails) is a boundary.
MessageBoxA, Sleep and ShellExecuteA run after the body returns, before the
presentation, on the window channel and the queue as in F1.

**App:** ONLINE GAME shows the two startup boxes, then the network screen
(Waiting for Opponent / Connect to Opponent / cancel, the LF2 forum banner).
The banner opens `http://lf2.net/forum`. Connect shows the address prompt;
typing and Enter draw Connecting, and the next frame shows the original
"socket()" box (caption "Client Error") and returns without presenting;
cancel goes back. Waiting shows the timer-driven dot animation until cancel.
The network screen's cancel releases the background, runs 402d70 (listener 0:
closesocket, clear, WSACleanup) and returns to the main menu, whose background
is reloaded. The typed address and the IP text are GDI text, still blank.

**Checks:** `tools/app_e2e.py`'s vs scenario gains an online check (boxes
"WSAStartup()", "InitWinSock()", "socket()"; opened the forum, then
OFFICIAL WEBSITE from the main menu; exit 0, no boundary). The whole e2e set
passes (vs with the quit, website, controls and online checks, mission, demo,
war, playback, tournament, team-tournament). The bootstrap, host-session,
menu-input, observed-iteration, observed-startup, Mac runtime-menu and
runtime-startup suites pass (29). The network-menu, client and exit sources
are unchanged, so their accepted comparisons were not rerun.

## F3 — RECORDING INFO: port and comparison (2026-09-29)

Static reading in the plan (F3). RECORDING INFO edits the recording author
name (44fd18), a four-line info (44f900) and an email (44f890) — the three
strings control.txt ends with — and the recording flag 450be4; OK saves the
settings and opens page 8 (the LF2 "challenge" link and OK), Cancel re-reads
them. The fields are drawn with the bitmap font 423a70, not GDI text.

`OriginalFrontRecordingInfo` (Core) ports both selectors, composing the
recovered helpers (423a70 `OriginalBitmapFont` .fourPass, 422f60 key
characters with GetKeyState, 401a30 sound, 423910/43ef50 release); bitmap
drawing, the font's Blt results, GetKeyState, the 423480 reload and the
423230 writer are the caller's, Sleep and ShellExecuteA events.

Oracle `tools/oracle_front_recording_info.py` subclasses the accepted CONTROL
SETTINGS harness with the selector as a parameter (44d064 = 7 or 8 through the
original dispatch; 423a70/423940 on the same CPU; the same declared
boundaries): 129 cases — idle with the flag off and on, every region's edges
and outside neighbours, field selection and clearing (each field's edges,
gaps, a held-only frame), typing into each field (Caps Lock on/off, a digit,
space, '.', F1, Return into empty and non-empty fields (twice each), Backspace into empty
and non-empty fields, four keys in one frame), a 63- and 64-character name,
a full four-line info, a 70-character info line, a key with no field, the flag
toggled both ways, the folder and help buttons, OK over the writer's outcomes,
Cancel over two read chunkings; page 8's idle, edges, link and OK (17 cases);
plus the control variant. `FrontRecordingInfoReference` replays the completion
parent and every case: all 181,119 events (18,108 draws and Blts, 16 key
states, 2 settings writes, 2 reloads with 108 file events, 3 links) and the
presentation and return snapshots match in both corpora
([evidence](../evidence/front-recording-info.json),
[control](../evidence/front-recording-info-control.json)) on the first native
run. The native font's own `fontPass`/`stringWrite` observations are skipped
by the reference; the terminators they describe are in the snapshots. A
corpus with one altered draw coordinate fails at that case's event.

Recovered behaviour worth noting: fields have no length check (the font's
terminator truncates them to 64 columns per line, 1 or 4 lines, in the same
frame); Return appends '\n' to any non-empty field, but in the one-line name
and email the same frame's font terminator removes it again; OK saves before
its sound and keeps the background for page 8; Cancel re-reads before its
sound.

## F3b — RECORDING INFO in the app (2026-09-29)

The session's alternate runs selectors 6, 7 and 8 through one branch with the
same per-iteration inputs (data\control.txt for the 423480 reload,
GetKeyState(VK_CAPITAL), the 423230 writer's output as an effect, Sleep and
ShellExecuteA after the screen returns); the font's Blt answers are the ones
its blit events emitted. The runtime's ShellExecuteA answer now passes the
verb: "open" of a URL as before, and "explore" of a game-directory folder.

Declared policy (Windows shell, not the EXE): "explore" of "recording" opens
the overlay's `recording` folder in Finder, creating it as the shipped game
has it; scripted runs only report `shellOpen` with the verb. The result stays
42.

**App:** RECORDING INFO shows the original page with its bitmap-font fields
("<No name>", "<No info>", "<No email>"), the recording check box and the
links. Selecting the name, nine Backspaces and "naruto" edit it with the
cursor shown; the check box turns recording off; the folder, help and OK
buttons work; OK writes control.txt equal to the packaged file with those two
lines changed ("0" and "naruto", CRLF) and opens page 8 (LF2 Mission
Challenge), whose link opens the challenge page and whose OK returns to the
main menu with its background reloaded.

**Checks:** `tools/app_e2e.py`'s vs scenario gains this recording check
(the file byte for byte and the four `shellOpen` requests in order). The
whole e2e set passes (vs with the quit, website, controls, online and
recording checks, mission, demo, war, playback, tournament, team-tournament).
The bootstrap, host-session, menu-input, observed-iteration,
observed-startup, Mac runtime-menu (now with the "explore" answer) and
runtime-startup suites and the RECORDING INFO comparison pass (31).

Remaining: the 402b60 network startup and network play stay declared absent,
and with them selector 4 (428808), which the client sets at 428730 only after
a successful connection. Every other front-menu item now runs in the app.

EXE envelope not recalculated.
