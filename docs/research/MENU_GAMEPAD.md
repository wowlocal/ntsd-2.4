# The front screens with a game controller

Requested by the user on 2026-10-16, playing on a Steam Deck
([STEAM_DECK](../STEAM_DECK.md)): "why joystick is not working in the first
menu?", then "следующим шагом реши проблему с работой джойстика в первом
меню. да понимаю что это отхождение от оригинала". After the title version
(52042b56) they found "we still have issues controlling screens on that menu
(buttons in control settings and online game are not working". Branch
`exp/menu-gamepad` from `main` 94581233.

## The original

- **The title** (START, ONLINE GAME, CONTROL SETTINGS, RECORDING INFO,
  OFFICAL WEBSITE) reads only the mouse: WM_MOUSEMOVE stores the cursor at
  4546f0/453cdc and the left button at 457580; the menu body highlights the
  item under the cursor and clicks it on the press edge (44d060 == 0,
  457580 == 1) ([MAIN_MENU](MAIN_MENU.md), `OriginalMainMenu.swift:155-176`).
  Item rows, relative to [453da4]+202, for x 276…520: 15–39, 45–70, 77–102,
  107–132, 137–162. No player key or joystick byte is read there; the
  original's joysticks do nothing on it.
- **From the mode menu on** the game reads the players' devices (local input
  419a60, [LOCAL_INPUT](LOCAL_INPUT.md)): the mode menu moves on up/down and
  confirms on attack of any seat ([MODE_SELECTION](MODE_SELECTION.md)).
  `control.txt` gives joystick 1 to player 3 and joystick 2 to player 4, so a
  single controller already works there as player 3.
- CONTROL SETTINGS, RECORDING INFO and the network menu are mouse screens
  with typed text ([APPLICATION_FRONT_MENU_ITEMS](APPLICATION_FRONT_MENU_ITEMS.md),
  [NETWORK_MENU](NETWORK_MENU.md)).

So the front screens are the ones a controller cannot work. On the Deck the
touchscreen or the trackpad could; on Apple TV nothing could. Their click
targets, from the recovered code (`OriginalMainMenu`,
`OriginalFrontControlSettings`, `OriginalNetworkMenu`,
`OriginalFrontRecordingInfo`, `OriginalFrontScreenAlternate`), all act on the
left button's press edge; no front screen reads the right button. The only
joystick read before loading is CONTROL SETTINGS' capture: while a cell of a
joystick player is selected (4511e0 > 0), the first of that joystick's four
buttons that is *held* (453fc4 + 48·device) is bound to it, from the frame
after the click.

## The departure

`OriginalRuntimeMenuGamepad` (NTSDRuntime), called from
`OriginalMacRuntimeMessages.joystick` before the MM_JOY messages are posted,
so every host that samples controllers (AppKit, iPad, Apple TV, Android, SDL
on Linux and Windows, the browser) gets it at once:

- **Screens and targets** (`OriginalRuntimeMenuGamepad.screen(selector:word:)`,
  read only before loading with World+0 at 458b00 equal to 0, by the
  selector 44d064; `menuScreen()` in the session):
  - 0, the title: START … OFFICAL WEBSITE (rows relative to [453da4]+202,
    x 276…520).
  - 6, CONTROL SETTINGS: per player (x 194+139·p, 105 wide) the name field
    (y 156…173), the device box (182…272; a click cycles keyboard → joystick
    1 → joystick 2) and the key cells a click can select (y 280+22·r…298+22·r;
    a joystick's four direction rows cannot be set, so they are left out);
    OK (405…560 × 441…465), first when the cursor is on no target, and
    Cancel (582…737).
  - 1, the network menu: Waiting for Opponent, Connect to Opponent, Back
    (x 260…547; y 274…300, 305…330, 336…361); 2 and 4: Cancel / Back
    (322…472 × 361…386); 3, the address: OK (239…389) and Cancel (411…561),
    y 357…382.
  - 7, RECORDING INFO: the name, info and email fields, the recording
    checkbox, OK (first) and Cancel; 8, its notice: OK.
  - −3, the update panel (Enable, Disable and, folded, the description, at
    its y: 96, or the panel's moving top 4511f4) and −1, the waiting
    screen's Cancel.
  - Left to the mouse: links to web pages and folders (the title's bottom
    right, the help links, the forum banner, the recording folder), the
    title's Update button and the bottom-left exit hotspot (it quits without
    a question).
- **Moves.** Up, down, left or right on the stick or d-pad (the WinMM words
  past ±16384 from the centre, back under ±8192; the axis pushed further
  wins a diagonal) moves the game's mouse to a target's centre: among the
  targets that way, the nearest in the same row or column band, else within
  45°, else at least 16 px that way, by the distance along plus twice the
  distance across; with none, it wraps to the farthest the other way (band,
  then 45°). A held direction repeats after 400 ms, then every 180 ms. The
  original's hover highlights and cursor sprite follow. The start is the
  target under the last WM_MOUSEMOVE point the game was sent (client
  coordinates, the host's own mouse and touch included), else the one last
  moved to on that screen, else the screen's first.
- **Presses.** Button 1 (A) presses the left button on that target (a move,
  then WM_LBUTTONDOWN). WM_LBUTTONUP follows once button 1 is up and 150 ms
  of the game clock have passed since GetMessage delivered the press — or
  2 s after it, even with button 1 still down (a controller lost while
  held); checked at every sample and every PeekMessage, so a menu frame
  always sees the press, as touch holds its taps. The release is posted even
  when the screen has gone.
- **Button 1 is the menu's while it is a click.** From that press until
  button 1 is up, the joystick's MM_JOY messages do not show button 1, so a
  CONTROL SETTINGS cell does not bind the click's own button and the mode
  menu after START does not see it as a confirmation. While a joystick
  player's cell waits for a button, that joystick's buttons are the game's
  (MM_JOY as the original, no click), so any of A, B, X, Y can be bound;
  the other joystick still clicks.
- Every other screen, the mode menu included, reads the joysticks only as
  the original does; without joystick input on these screens nothing
  differs (the screen is read only on a direction or button edge, the clock
  only then, while a press is pending or while a direction held on a menu
  screen waits to repeat). `--original-menu-input` leaves the departure out.

Not covered: text — the player names, the network address and the
recording info — still needs keys (on the Deck, Steam's on-screen keyboard);
the Siri Remote, which sends keys, on these screens.

## The title version (52042b56)

The first step covered the title only (`OriginalRuntimeTitleGamepad`, flag
`--original-title-menu`), with the same moves, presses and release rules;
the general version replaced it. Its reviews:

An independent read-only review of the first version found nothing changed
for runs without joystick input on the title (no clock call, message or
PeekMessage answer differs; after loading the title check fails first) and
the title detection correct (World+0 is the slice at 458b00; the snapshot is
the committed state; a pending release still reaches the loaded phase's
PeekMessage). Its five findings, all fixed:

1. The starting item came from the host's point, which is MSG.pt in desktop
   coordinates: in a window away from the desktop origin A could click
   another item (OFFICAL WEBSITE opening the browser). Now the last mouse
   point sent to the game, in client coordinates.
2. The remembered item overrode the real mouse or touch. Now the item under
   the last mouse point comes first.
3. The hold counted from posting the press, so a queue not served for 150 ms
   (a modal dialog) could hand the game the press and the release with no
   frame between. Now it counts from GetMessage's delivery.
4. A press held by a lost controller never ended, blocking later presses.
   Now the left button goes up after 2 s at the latest.
5. Repeats were shared by the joysticks and read the state at every sample
   while a direction was held. Now each joystick repeats on its own, armed
   only by a move on the title.

Kept: a button already down at the first sample counts as a press, as the
MM_JOY messages count it.

### Checks of the title version

| Date | Check | Result |
| --- | --- | --- |
| 2026-10-16 | First version: `OriginalMacRuntimeMenuTests` (debug, 12 tests) with the new `testTitleGamepadMovesBetweenItemsAndClicks` | pass |
| 2026-10-16 | First version: `app_e2e.py --scenario title-joystick --record`: the joystick scenario with the title's START and the mode menu's VS taken by joystick 1 (down, down, up, button 1; player 3's button 1). Loaded, match launched at iteration 1476 like the joystick scenario, gameplay, a capture of the VS match (player 3 against the computer) | recorded `tools/app_e2e_title_joystick_reference.json` |
| 2026-10-16 | First version: `app_e2e.py`, all 11 scenarios with the vs run's quit, website, controls, online and recording checks and the new `--original-title-menu` check (the same title input leaves the title showing) | all pass; the 10 existing references equal |
| 2026-10-16 | After the review: the test rewritten — the desktop point ignored, the hold from delivery (none before it, up at 150 ms), a second joystick's press waiting, a real move setting the start, the 2 s release, the release after the title has gone, nothing but MM_JOY off the title; with the joystick, queue and front-menu tests (4) | pass |
| 2026-10-16 | Second review (read-only) of the fixes: no high or medium defect; button messages moved the start point (the pad's own WM_LBUTTONUP after a trackpad move) — fixed, `lastMouse` now follows WM_MOUSEMOVE only; card wording corrected. Left as is: samples taken while an AppKit modal dialog runs still queue title moves and clicks, which act after it closes | fixed |
| 2026-10-16 | Tests added: a release after a real move keeps the start on START; off the title the title state is read only on edges (8 reads for 2 joysticks × 4 edges) and every clock read is a posted message's time; all 13 `OriginalMacRuntimeMenuTests` | pass |
| 2026-10-16 | Final code: `app_e2e.py --build`, all 11 scenarios with the vs run's checks and the `--original-title-menu` check (also run after the first review's fixes) | all pass; the 10 existing references and `title-joystick` equal |
| 2026-10-16 | The Linux x86_64 package of 52042b56 installed on the Deck with `steamdeck_install.py` and started through Steam in Game Mode: X11 under gamescope, Steam's virtual pad opened, the title on screen | started |

The user answered "good. push to master", then stopped the push: the other
screens did not work with the controller. 965cbd8b, which recorded a merge
into `main`, was wrong — nothing was pushed to `main` then.

## Checks of the general version

| Date | Check | Result |
| --- | --- | --- |
| 2026-10-16 | General version: `OriginalMacRuntimeMenuTests` — the title test moved over (button 1 hidden from MM_JOY while it clicks, a second joystick's press the game's), off-menu reads, and `testMenuGamepadScreensMovesAndCapture`: CONTROL SETTINGS' 30 targets for keyboard, keyboard, joystick 1, joystick 2, their rectangles, nine moves (bands, 45°, the 16 px tier, both wraps), the capture's joystick for players 3 and 4 and none for a keyboard cell, every other screen's targets, and in the messages a capture press passed to MM_JOY while the other joystick clicks OK with button 1 hidden (6 tests with the joystick, queue and front-menu ones) | pass |
| 2026-10-16 | `title-joystick` re-recorded although button 1 no longer reaches MM_JOY on the title: the reference came out byte-identical (match at iteration 1476, the same capture). The new checks run with it: `--original-menu-input` keeps the title; CONTROL SETTINGS by joystick alone (player 2's up → its device box → player 1's → A → down ×4 → OK → A) saves `control.txt` equal to the packaged one with player 1's device 0 → 1; ONLINE GAME by joystick alone (Connect → Cancel on the address screen → Back → START) loads with no message box or link opened | pass |
| 2026-10-16 | `title-joystick` compared 4 times: the first compare right after recording differed in the match capture's hash only (iteration 2600, `b8b9d39…` against `9668805…`; every other milestone equal), the next three matched. The intermittent capture class seen before (APPLICATION_FRONT_MENU_ITEMS: a Mission capture) | 3 of 4 equal |
| 2026-10-16 | `joystick` (the existing reference; its joystick input is all after loading) | equal |

Per the user ("не нужно полный e2e для изменения исключительно меню"), the
whole e2e set was not rerun for the general version.

Open: a hand check with a real controller (the Deck; AppKit, iPad, Apple TV,
Android, the browser use the same path).
