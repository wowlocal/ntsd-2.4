# The title menu with a game controller

Requested by the user on 2026-10-16, playing on a Steam Deck
([STEAM_DECK](../STEAM_DECK.md)): "why joystick is not working in the first
menu?", then "следующим шагом реши проблему с работой джойстика в первом
меню. да понимаю что это отхождение от оригинала". Branch
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

So the title is the one screen a controller cannot pass. On the Deck the
touchscreen or the trackpad could; on Apple TV nothing could.

## The departure

`OriginalRuntimeTitleGamepad` (NTSDRuntime), called from
`OriginalMacRuntimeMessages.joystick` after the MM_JOY messages are posted,
so every host that samples controllers (AppKit, iPad, Apple TV, Android, SDL
on Linux and Windows, the browser) gets it at once:

- While the title shows, up or down on the stick or d-pad (the WinMM words
  past ±16384 from the centre, back under ±8192) moves the game's mouse to the
  next or previous item's centre (x 398), wrapping at the ends; a held
  direction repeats after 400 ms, then every 180 ms. The original's hover
  highlight and cursor sprite follow.
- The item a move starts from, or a press acts on, is the one under the last
  WM_MOUSEMOVE point the game was sent (client coordinates, the host's own
  mouse and touch included; button messages do not move the game's cursor),
  else the item last moved to, else START.
- Button 1 (A) presses the left button on that item (a move, then
  WM_LBUTTONDOWN). WM_LBUTTONUP follows once button 1 is up and 150 ms of
  the game clock have passed since GetMessage delivered the press — or 2 s
  after it, even with button 1 still down (a controller lost while held). It is checked at every sample and every PeekMessage, so a menu frame
  always sees the press, as touch holds its taps. The release is posted even
  when the press has left the title.
- The title shows when the session has not started loading, World+0
  (458b00) is 0 and the selector 44d064 is 0 (`titleMenuBase()`); START sets
  World+0 to 1 and the other items set the selector, so the title never
  matches after it is left. The state is read only when a sample asks for a
  move or a press, and the clock only then, while a press is pending or while
  a direction held on the title waits to repeat.
- The MM_JOY messages are posted exactly as before, and every other screen
  reads the joysticks only as the original does. `--original-title-menu`
  leaves the departure out.

Not covered: the screens behind CONTROL SETTINGS, RECORDING INFO and ONLINE
GAME still need a mouse (and keys for text), as does the Siri Remote, which
sends keys, on the title.

## Review (2026-10-16)

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

## Checks

| Date | Check | Result |
| --- | --- | --- |
| 2026-10-16 | First version: `OriginalMacRuntimeMenuTests` (debug, 12 tests) with the new `testTitleGamepadMovesBetweenItemsAndClicks` | pass |
| 2026-10-16 | First version: `app_e2e.py --scenario title-joystick --record`: the joystick scenario with the title's START and the mode menu's VS taken by joystick 1 (down, down, up, button 1; player 3's button 1). Loaded, match launched at iteration 1476 like the joystick scenario, gameplay, a capture of the VS match (player 3 against the computer) | recorded `tools/app_e2e_title_joystick_reference.json` |
| 2026-10-16 | First version: `app_e2e.py`, all 11 scenarios with the vs run's quit, website, controls, online and recording checks and the new `--original-title-menu` check (the same title input leaves the title showing) | all pass; the 10 existing references equal |
| 2026-10-16 | After the review: the test rewritten — the desktop point ignored, the hold from delivery (none before it, up at 150 ms), a second joystick's press waiting, a real move setting the start, the 2 s release, the release after the title has gone, nothing but MM_JOY off the title; with the joystick, queue and front-menu tests (4) | pass |
| 2026-10-16 | Second review (read-only) of the fixes: no high or medium defect; button messages moved the start point (the pad's own WM_LBUTTONUP after a trackpad move) — fixed, `lastMouse` now follows WM_MOUSEMOVE only; card wording corrected. Left as is: samples taken while an AppKit modal dialog runs still queue title moves and clicks, which act after it closes | fixed |
| 2026-10-16 | Tests added: a release after a real move keeps the start on START; off the title the title state is read only on edges (8 reads for 2 joysticks × 4 edges) and every clock read is a posted message's time; all 13 `OriginalMacRuntimeMenuTests` | pass |
| 2026-10-16 | Final code: `app_e2e.py --build`, all 11 scenarios with the vs run's checks and the `--original-title-menu` check (also run after the first review's fixes) | all pass; the 10 existing references and `title-joystick` equal |

Open: a hand check on the Steam Deck (the user), and on hosts with a real controller (AppKit, iPad, Apple TV, Android, the browser), which use the same path.
