# GDI text in the app

[Plan](APPLICATION_GDI_TEXT_PLAN.md). The original is not executed.

## Result (2026-10-01)

The app now draws the original's GDI text. Examples:

- CONTROL SETTINGS: key names, "Keypad: 4", "Button: 1" and the player
  numbers in the name fields ([capture](../evidence/application-gdi-text-controls.png));
- the Summary: Kill/Attack/HP Lost/MP Usage/Picking numbers in their column
  colours, the match time, and "Recording file '…' saved!"
  ([capture](../evidence/application-gdi-text-summary.png));
- the Stage HUD: "Man: 1 HP: 123", "STAGE 1-1"
  ([capture](../evidence/application-gdi-text-stage.png));
- the start-menu values ("Background: Random", "Difficulty: Difficult",
  "Music: Random (Press Left/Right to change)") and the other strings the Core
  sends as TextOut.

**Font: a temporary deviation (user decision 2026-10-01).** Neither the EXE
nor lib.dll creates a font, so the original draws with the DirectDraw
surface DC's default SYSTEM_FONT. That is a Windows raster font that is not
in the distribution and cannot be redistributed. The app draws the macOS
system font, bold, at a 13 px em in the 16 px cell, baseline at +13, without
smoothing. Position (TA_TOP|TA_LEFT at the TextOut point), colour (the exact
COLORREF as XRGB) and background (TRANSPARENT for the library routine,
OPAQUE extent box in the SetBkColor colour for the EXE's own 401290) follow
the original. Glyph shapes and advance widths differ from SYSTEM_FONT, so
centred strings can sit a few pixels off. Only ASCII is drawn; any other
byte is a boundary until a code page is declared.

**Changes:**

- **`OriginalMacDisplayBackend`.** One surface DC at a time. GetDC returns DD_OK
  and the declared handle `textDCHandle`. SetBkMode, SetBkColor and
  SetTextColor return the previous value (from OPAQUE, white and black).
  TextOutA draws and returns TRUE; ReleaseDC returns DD_OK. While the DC is
  held, a Blt or fill on that surface is a boundary.
- **Core, `OriginalApplicationMenuSession`.** With a front provider, the
  GetDC and GDI calls of the EXE's own routine outside the body stage go to
  the provider in order. The device's GetDC answer must equal the prepared
  reply that 401290 decided on; otherwise it is a boundary. Without a provider
  nothing changes.
- **Core, the graphics owner and the menu-graphics reply check.** Both accept
  SetBkColor, which only the EXE's own routine emits.
- **Inputs.** The front menu, loaded menus and gameplay give the Core GetDC
  success with the declared handle.
- **Loaded and gameplay replay.** The committed text calls replay in order with
  the blits and fills.
- **Demo music.** The residue placeholder (4025d0's ECX) is unchanged and
  marked temporary: with a successful GetDC its source would be ReleaseDC,
  equally unknown.

**Checks:**

- A new `OriginalMacFrontRasterTests.testSurfaceTextDrawsBothRoutinesWithTheDeclaredFont`
  covers both routines. In the transparent case only mask pixels change, to the
  converted colour, and nothing rises above the cell. In the opaque case the
  box is in the SetBkColor colour. It also covers results and the boundaries
  (a second DC, a Blt while held, a foreign handle, non-ASCII).
- Two existing raster tests changed. One no longer asserts that the backend
  refuses GetDC: its declared negative-GetDC Core comparison is unchanged, and
  the backend is not asked. The other lists a malformed GetDC as invalid in
  place of a valid one. The raster suite (6) passes.
- The observed-iteration, observed-graphics, runtime-menu, graphics,
  text-response, library-text, menu-input, network-menu and screen-body suites
  pass (30 tests).
- E2E: all nine scenarios were re-recorded. Every reference field except the
  capture hashes is unchanged: milestones, progress counts, overlay files,
  exit codes and boundaries. Changed captures:

  | Scenario | Changed |
  | --- | --- |
  | vs | 2 of 7 |
  | mission | 6 of 6 |
  | demo | 4 of 4 |
  | war | 11 of 11 |
  | playback | 3 of 8 |
  | tournament | 6 of 8 |
  | tournament-win | 3 of 10 |
  | team-tournament | 3 of 8 |
  | joystick | 0 of 1 |

  The old vs reference had no `resources` list, which is not compared. The
  changed captures were inspected: they show the new text (War settings:
  "Background: Random", "Difficulty: Difficult", "Music: Random", unit counts,
  "Defense: x1.0").

## Addendum: code-page survey (2026-10-01)

Which bytes ≥ 0x80 can reach TextOutA, where the app's ASCII-only text is a
boundary?

- **Shipped data.** The game's own decoder (`tools/import_ntsd.decode_dat`)
  decodes all 191 DAT and TXT files of the distribution:
  - all 62 `name:` values are ASCII;
  - the only non-ASCII bytes inside any file are the UTF-16 byte-order mark of
    `movelist @ credits.txt`, which the game does not read;
  - 356 high bytes follow each file's last `<frame_end>`/`layer_end`. These
    are trailing bytes after the data, not text.
- **The EXE's and lib.dll's own strings.** No string in their .rdata/.data
  sections contains a high byte. The 13 apparent hits are binary64 constants
  stored next to ASCII strings ("Waiting for opponent...", "Man: %3d
  HP: %4d …").
- **Dynamic text.** Numbers, dates and recording names are formatted from
  ASCII. Typed names are ASCII too: the app posts WM_CHAR only for 0x20..0x7e
  and control characters (an existing declared policy). A non-ASCII typed
  character produces no WM_CHAR.

So no shipped content and no input the app accepts reaches the ASCII
boundary. The remaining way is a user-supplied `control.txt` whose names hold
high bytes, for example one copied from a non-English Windows install. There
the original would draw them in that system's ANSI code page, which the game
does not record. The boundary stays until such a file is reported; then a
code page can be declared for it.

EXE envelope not recalculated.
