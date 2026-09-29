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
equal) and two reruns matched exactly — as with the earlier tournament
mismatch, the window snapshot, not the game, varies. The harness now keeps
each scenario's captures in `build/research/e2e/<scenario>/` for diagnosis.

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

Remaining: F1b — wire `OriginalNetworkMenu` (selectors 1–3, ported) with a
declared no-network client, so ONLINE GAME reaches its menu and Back;
F2 CONTROL SETTINGS (selector 6); F3 RECORDING INFO (selector 7).

EXE envelope not recalculated.
