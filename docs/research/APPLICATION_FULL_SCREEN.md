# Alt+Enter as the original

[Plan](APPLICATION_FULL_SCREEN_PLAN.md) (with the 2026-10-01 decision and the
declared Windows answers). The original is not executed.

## Result (2026-10-01)

Alt (Option) + Enter toggles the game between its window and full screen the
way the original does: the game's own WM_SYSKEYUP handler (43b83f) releases
its display, destroys its window and recreates both. In full screen the game
image fills the main display scaled with its aspect kept
([menu](../evidence/application-full-screen-menu.png), downscaled screen
capture; [fight](../evidence/application-full-screen-fight.png), the presented
game frame). A second Alt+Enter returns to the 794×550 window.

What happens in the toggle, all from the recovered code:

- 401a80 releases the target, the primary and the DirectDraw object, then
  DestroyWindow.
- DestroyWindow's synchronous WM_DESTROY (43b4ba) releases the DirectSound
  device, the music graph and both recording buffers. PostQuitMessage is
  skipped (458434 = 1). WM_NCDESTROY follows.
- 43bdd0 recreates the window and DirectDraw. In full screen that is the
  WS_POPUP/WS_EX_TOPMOST window at screen size, level 0x11,
  SetDisplayMode(794, 550, 8), a flip chain (2, then 1, then the fake
  flipper) and present mode 2 (Flip). Windowed, it is the usual window and
  clipper.

Consequences, as on Windows:

- **Sound effects stop for the rest of the session.** The device is not
  recreated (the performed-sound count stays fixed).
- **Music.** The graph is recreated by the game itself at the next track start
  (a new graph token at the following match). The plan's reading that
  nothing re-creates the music is corrected here.
- **Recording.** A toggle frees both recording buffers. The next match
  allocates a new one, so a toggle in the menus is harmless and the match
  records normally.
- **A toggle during a recorded match (or a playback) crashes the original.**
  43db40/43dc50 test only 450b80/450b84, not the freed pointer, and write
  tick·10+0x2b38 through a null base, which is the never-mapped null page and
  an access violation. The app stops at that point. The error is labelled a
  "Source fault" and the stop dialog says "The original game crashes here",
  so it reads as the original's crash, not as a missing feature.

Declared Windows answers (plan, "Decision and declared answers"):

- SetDisplayMode(794, 550, 8) succeeds.
- Surfaces stay XRGB.
- Sprites of the released DirectDraw object are drawn to the new target.
- RegisterClassA of the existing class returns 0.
- The screen metrics are the main display in points.
- Option is Alt; Alt+F4 sends SC_CLOSE; Alt released alone sends SC_KEYMENU,
  which the game swallows. No default beep is played.

**Changes:**

- **Core.** The menu session routes WM_SYSKEYUP to `OriginalWindowLifecycle`.
  Its recreation delivers the nested WM_DESTROY and WM_NCDESTROY through a new
  `deliver` callback, which the session answers on the window channel as on
  the quit path. Without that callback nothing changes, so the earlier corpora
  are unaffected. The replay tick names a null buffer pointer as a source
  fault.
- **Messages.** Option is VK_MENU. System keys post WM_SYSKEYDOWN/UP with
  bit 29, and TranslateMessage makes WM_SYSCHAR. DefWindowProc sends
  SC_CLOSE or SC_KEYMENU as above. The window is replaceable, and
  DefWindowProc on a former window returns 0.
- **Window backend.** The popup is a borderless window over the main display,
  above the menu bar and hidden when another app is active. It shows the
  frame scaled, and mouse points are mapped back to game coordinates. Also
  added: re-registration with an undefined hCursor, and SM_CXSCREEN and
  SM_CYSCREEN.
- **Display backend.** Level 0x11, the display mode, the flip chain,
  GetAttachedSurface and Flip with DirectDraw's memory rotation, plus Blt
  from the released object's surfaces.
- **App.** Input, close handling, mouse points and captures follow the new
  window. A capture of the full-screen window is the presented 794×550 game
  frame, so it does not depend on the display. Script keys with several Mac
  keys per VK use the lowest key code, so runs repeat.

**Checks:**

- New tests:
  - `OriginalMacRuntimeMenuTests.testSystemKeysFollowWindows`: the message
    and lParam sequence of Alt+Enter, Alt alone and Alt+F4, keys without
    Alt, and former windows.
  - `OriginalMacFrontRasterTests.testFullScreenFlipChainSwapsAndDrawsReleasedObjectSurfaces`.
  - `OriginalWindowLifecycleTests.testAltEnterDeliversNestedDestroyBeforeRecreation`:
    the order, and the state the nested handler sees and writes.
  - The key-map test now counts the Option pair.
- New e2e scenario `altenter`, recorded and then re-run: pass. Alt+Enter at
  the VS selection, the match in full screen to the Summary (the same 11,044-
  byte replay as the windowed run), Jump, Alt+Enter back, and a capture of the
  window. Its fault check (Alt+Enter in the middle of the fight) requires
  exit 1 at one Source-fault boundary naming 4588a8.
- The Mac runtime, window, display, front-raster, observed-iteration,
  observed-graphics, menu-input, lifecycle, message-loop and window-input
  suites pass (55 tests).
- The whole e2e set passes (vs with its checks, mission, demo, war, playback,
  tournament, altenter with its fault check, tournament-win, team-tournament,
  joystick). The other references are unchanged.

Not done: a standard macOS full screen without the game's involvement (the
user's optional addition), Windows observations of the declared answers, and
the default beep. EXE envelope not recalculated.
