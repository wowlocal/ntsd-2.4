# On-screen touch controls (Android, iPhone, iPad)

Requested by the user on 2026-10-19, forwarding StormPixels' Discord proposal
and files (2026-10-18): on-screen controls for the Android version (direction
buttons, attack / jump / defend, F1–F9) with a small settings panel to move
and resize the buttons, change their keys and their opacity. The user added:
"думаю имеет смысл on screen контролы показывать на айфонах тоже, если не
подключена клава/геймпад" and "и на айпаде тоже если клавиатуры/геймпада нет".

## Scope and fidelity

The original always had a keyboard: these controls are a **declared host
addition**, not original behaviour. They press the same keys a keyboard would
(USB HID usages through `OriginalHIDKeys`, then `host.key`), so the game's
own CONTROL SETTINGS decide what each button does; nothing in Core, the
runtime session or the presented frame changes. Hosts draw the overlay over
the frame on screen only (`snapshotPNG`/`viewPNG` and frame captures read the
game's frame). While a keyboard or gamepad is connected nothing is drawn and
every touch is the mouse exactly as before. Scripted checks (`--script`) keep
them off unless `--touch-controls on`.

## The proposal

`ntsd-onscreen-controls-proposal.zip` (12.71 KB, SHA-256
`be9b00cf8dc87be4bbd635116120799fcd9fe9cf2cb4660d7cc0422a0d97a542`), from
StormPixels by DM, "use it however you like … No credit needed":
`NTSDAndroidControls.swift` (model, layout, 5×7 font, drawing into the
surface buffer, settings panel, a touch router), a patch to
`NTSDAndroidHost.swift`, three edits to `NTSDAndroidApp.swift` and a README.
Run by its author on an Android 9 phone (video in the Discord message).
Read in full before use: no network, files or processes beyond its own
`files/controls.txt`.

Kept: the buttons and their default places, the settings panel and key
grid, the opacity groups, the file format, the 5×7 glyphs, multi-finger
routing (overlapping buttons hold together, sliding between buttons, the
first finger on empty screen is the mouse), letting go on focus loss.

Changed in integration:

1. **Shared**: model, layout, settings, routing and rasterizing moved to
   `NTSDRuntime/OriginalTouchControls.swift` (Foundation only), used by the
   Android and iOS hosts; host code is the platform glue.
2. **Hidden while a keyboard or gamepad is connected** (the user's rule). Android:
   InputDevice through JNI — an external device (`isExternal`, API 29;
   without it, not virtual) with SOURCE_GAMEPAD or an alphabetic keyboard —
   asked at launch, on a configuration change, on focus, for an event from a
   device not seen then, and for a touch while hidden (a phone's own nodes,
   such as the emulator's built-in alphabetic keyboard or a fingerprint
   sensor's uinput device, are not external). iOS: GameController
   (`GCKeyboard.coalesced`, extended gamepads) with its connect/disconnect
   notifications (asked again on the next turn), and a hardware key press
   until a keyboard disconnects. `--touch-controls on|off` forces them.
   Each change is reported: `androidTouchControls` (connected, the devices
   that hide them, shown) and `iosTouchControls` (keyboard, key pressed,
   gamepads, shown).
3. **Off the game thread**: the proposal redrew the whole surface on the main
   (game) thread for every press and re-rasterized every shape on every
   frame. Now each change yields an immutable `Picture`; on Android the
   presenter thread rasterizes it once at the buffer's exact size and blends
   the kept overlay (only its 32-pixel tiles that hold pixels) into each
   frame; the main thread only swaps the picture under its own lock and asks
   the presenter to redraw the last frame. iOS renders it into its own layer
   (up to 2 px per point) on change; Core Animation composites it.
4. **Default keys are Player 1's of the original**: the proposal's arrows,
   A (attack), J (jump), D (defend) do not match the shipped
   `data/control.txt` (line 1 `0 87 83 65 68 74 75 76 3 2 1`: Player 1 is
   W, S, A, D with J attack, K jump, L defend; the arrows are Player 2's,
   with keypad 4/5/6) — with them the pad moved Player 2, "attack" (A) was
   Player 1's left, "jump" (J) Player 1's attack and "defend" (D) Player 1's
   right. Found in the simulator: the mode menu ignored the "A" button. The
   action buttons are marked by role (A, J, D, as the move lists write
   `D>A`), not by their key; the settings show the key.
5. **Esc** joins the F grid (5×2: F1–F9, ESC, below the F button): iOS has no
   Back key. Below the button, not beside it, so it clears the show/hide
   button on 4:3 iPads (review round 1).
6. **iPhone safe area**: on iOS the canvas is the view inset by the left and
   right safe-area insets, so no button meets the Dynamic Island (seen by the
   user on the left button, 2026-10-19); iPads have none, so they are
   unchanged. Android's canvas is the drawn buffer as before (the A12's notch
   is a device check).
7. **Size by the screen's physical size, places by the corners** (the user,
   2026-10-19, on the iPad screenshot: "не слишком большие контролы для
   айпада? … пальцам будет неудобно"). The proposal's unit was a ninth of
   the screen height in any units, so a button was ~76 pt (13 mm) on an
   iPhone but ~194 pt (37 mm) on a 13-inch iPad, and Android tablets alike.
   The unit is now capped at 48 points (iOS) or dp (Android, converted to the
   drawn buffer's pixels): a button is at most ~82 pt/dp across, about 13 mm
   on a phone and 16 mm on an iPad; phones below the cap are unchanged. The
   proposal's places were fractions of the screen, which spread a smaller
   pad over an iPad's corner: the default places are now fixed distances in
   units from the bottom corners — on the A12's 1223×550 buffer the
   proposal's places within 0.6 px. Only a moved button keeps fractions
   (written as `x=… y=…`); a file of the proposal's, which wrote its default
   fractions for every button, reads them back as places by the corner.
   Button letters scale with the button where twice the text scale rounds
   down (capped units, bigger buttons).
8. Smaller: a dragged button keeps the finger's offset (it jumped to centre
   under the finger); the show/hide toggle persists (`show on|off`); smoothed
   circle edges, no double-blended corners; the F button does nothing while
   the settings are open; iOS takes several fingers (`isMultipleTouchEnabled`);
   two buttons may share a key (pressed once, released when the last lets
   go); focus loss releases the keys but leaves a finger that is the mouse
   alone (as before); a lost lift (same finger id again, or Android's first
   finger down) lifts the stale finger; letter, digit and space buttons pass
   the typed character as a hardware key does; iOS rasterizes the overlay off
   the main thread (at most ~3 M pixels); the Android presenter redraws for a
   change only if no game frame comes within 34 ms; a moved button dropped by
   a focus loss or a keyboard arriving keeps its new place in the file; on
   iOS only a key going down counts as a keyboard, and the devices are asked
   again when the app becomes active and for a touch while hidden; on
   Android only touch-screen events go through the controls (a mouse or
   touchpad is the touch mouse by its first pointer, as before); the reports
   name devices by kind and USB vendor:product (Android) or category (iOS),
   not by their names, which may be the owner's.

## Design

- Canvas: Android, the drawn buffer's pixels (the frame fitted to the
  surface's aspect, e.g. 1223×550 on the A12); iOS, the view's points. One
  layout unit is a ninth of the canvas height; button centres are fractions.
- `began/moved/ended(id,x,y)` per finger; each finger keeps what it grabbed
  (buttons, F grid, a menu/settings button, a button being dragged, or the
  mouse) until it lifts. Keys follow the fingers on buttons and the grid,
  pressed/released in the controls' order. Callbacks: `key(usage,down)`,
  `mouse(phase,x,y)` (canvas point; the host maps to the client point),
  `changed()` once per call.
- Overlay: premultiplied R,G,B,A, tiles listing the painted 32-pixel squares.

## Checks

`tools/crossplatform/touch_controls_check.swift` (macOS, the shared file
alone; how to run in its header): the settings file, places and the cap,
keys and the mouse through fingers, the overlay's tiles and premultiplied
pixels with render/blend times, and 3,000 seeded random interleavings with
balanced keys and mouse.

Simulators and the emulator inject one finger at a time (an XCUITest driver
built from the scratch area tapped and held in the iOS simulators; `adb
shell input` on Android), so several fingers at once are covered by the
check tool only.

## Open

- **Devices** (T3): the Galaxy A12 — a played match with the buttons, the
  presenter's cost on its slow cores, a USB/Bluetooth gamepad or keyboard
  hiding them, the notch (Android's canvas is not inset) and several
  fingers; a real iPhone/iPad — GCKeyboard and gamepads connecting and
  leaving, several fingers. In the simulator the Mac's keyboard is reported
  as connected (with a device of category "Gamepad"), so the controls hide
  there unless forced (`--touch-controls on`); on the emulator its built-in
  alphabetic keyboard is not external and the controls show.
- A keyboard Android does not call external (a pogo-pin tablet cover, DeX)
  does not hide them (review round 2): to decide with such a device.
- Diagonals need overlapping buttons (enlarged or moved together), as in the
  proposal; a joined d-pad would be a design change.
- iPadOS 26 may show the app in a window: the controls follow the view, the
  game's told screen is still the screen's (as before).

## Plan

| ID | Step | Status |
| --- | --- | --- |
| T0 | Read and review the proposal; shared module; Android and iOS integration; standalone checks | **done** |
| T1 | iOS simulator: build, scripted scenarios unchanged, controls drawn and working by touch on iPhone and iPad | **done** |
| T2 | Android: toolchain on the second Mac, APK build, emulator: scripted scenario unchanged, controls by touch | **done** |
| T3 | Devices: the A12 (touch, a match with the buttons, the presenter's cost, the hidden state with a gamepad or keyboard), a real iPhone/iPad (touch, GCKeyboard on connect/disconnect) | needs the devices |
| T4 | Independent review (two read-only rounds: 13 findings, then 6 minor, fixed or recorded above); merge into `main` (the user's call) | review done; merge open |

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-19 | T0–T2 | The proposal read and integrated as a shared module for Android, iPhone and iPad; hidden while a keyboard or gamepad is connected; Player 1's original keys; safe area; unit capped at 48 pt/dp with places by the corners; two independent reviews. Check tool ALL PASS (balance 0/3000); vs equal on the iPhone and iPad simulators and through the Android app in the emulator; by touch in the iPhone simulator a VS match was started and played; the F grid, settings and toggle checked on iPhone, iPad and Android | [evidence](../evidence/touch-controls-t0-t2-20261019.json) | this commit |
