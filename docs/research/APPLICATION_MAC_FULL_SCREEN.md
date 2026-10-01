# Standard macOS full screen for the game window

[Plan](APPLICATION_MAC_FULL_SCREEN_PLAN.md). User decision (2026-10-01): a
standard macOS full screen may be added separately from the original's
Alt+Enter. It is a Mac presentation feature (declared policy); the game takes
no part. The original is not executed.

## Result (2026-10-01)

The game window now supports macOS full screen: the green button,
View → Enter Full Screen (⌃⌘F), and the script command `fullscreen` for app
checks. While the window is in macOS full screen, its lease holds the
windowed geometry it had just before entering:

- `displayGeometry`, which the display backend uses to crop the primary, stays
  the game's 794×550 client;
- `clientRect` answers the held size, and `screenPoint` adds the held client
  origin;
- `display` accepts frames of the held size, and the view draws them aspect-fit
  on black, as the Alt+Enter popup does;
- mouse points map back through the fit;
- a capture is the presented 794×550 frame.

The game receives no message on entry or exit, so its 453ccc rectangle keeps
the windowed values. When macOS reports the exit, the hold is released.
Alt+Enter is unchanged: the Alt+Enter popup does not get the macOS toggle,
and Alt+Enter inside macOS full screen is the game's own recreation.

**Changes:**

- **`OriginalMacWindowBackend`:**
  - `WindowLease.held` and the `.fullScreenPrimary` behaviour.
  - Observers of will-enter and did-exit full screen.
  - `holdForMacFullScreen` (also called directly by the tests),
    `toggleMacFullScreen`, and `viewPNG` (the view as AppKit renders it).
  - Held answers in `displayGeometry`, `clientRect`/`screenPoint`, `display`,
    `clientPoint` and `snapshotPNG`.
- **App:**
  - A main menu with an empty app menu and View → Enter Full Screen (⌃⌘F).
    Before this the original runtime had no menu.
  - Script commands `fullscreen` and `captureview`.
  - `macFullScreen` events with the client size on entry and exit.

**Checks:**

- `OriginalMacWindowGeometryTests.testMacFullScreenHoldsTheWindowedClient`
  holds, then grows the window to twice the client and moves it. It checks:
  - the held `displayGeometry`, `clientRect` and `screenPoint`;
  - that a held-size frame is displayed and a screen-size one refused;
  - the 794×550 snapshot;
  - the mouse mapping, where the view's (200,100) is the client's (100,50);
  - that a second entry keeps the first hold;
  - that after release the live geometry and size check apply again.
- The Mac runtime, window, display, front-raster, observed-iteration,
  observed-graphics, menu-input, lifecycle, message-loop and window-input
  suites pass (56 tests).
- App probe: `fullscreen` at iteration 20 and again at 3000 in the main menu,
  with frame and view captures. Exit 0, no boundary, and the game ran on.
  **The real AppKit transition was not exercised:** during this run the
  display was asleep. A plain screenshot with no app running was black too,
  and AppKit reported no full-screen entry; the view stayed 794×550 points.
- After the final refactor (`viewPNG`) the window geometry and backend suites
  pass again (9 tests). The whole e2e set passes unchanged (vs with its checks,
  mission, demo, war, playback, tournament, altenter with its fault check,
  tournament-win, team-tournament, joystick).

**Open:** observe the transition on an awake display (green button and ⌃⌘F)
and check the scaled image and clicks in full screen. ⌃⌘F also reaches the
game as a Control key press, which the original would see from Ctrl as well.
EXE envelope not recalculated.
