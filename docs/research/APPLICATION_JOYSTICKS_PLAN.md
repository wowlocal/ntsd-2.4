# Game controllers as the original's joysticks — plan

2026-09-30. Task → contract → milestone: CONTROL SETTINGS offers joystick
devices and players 3/4 default to joysticks 1/2, but the Mac runtime answers
every joystick as unplugged → the original's WinMM joystick contract served
from macOS game controllers → controller play as in the original. The
original is not executed.

## Static reading

- 43bf10 (ported, `OriginalInputStartup.initializeJoysticks`, research-compared
  through the capability path): joyGetNumDevs; then for IDs 0 and 1:
  joyGetPosEx(JOY_RETURNALL-ish flags 0x83, 52-byte JOYINFOEX); result 0xa7
  (JOYERR_UNPLUGGED) skips the device; otherwise present flag 453fd0/454000 = 1,
  id, joySetThreshold(id, 100), joySetCapture(hwnd, id, 25 ms, TRUE),
  joyGetDevCapsA(id, 404 bytes); wXmin/wXmax/wYmin/wYmax (JOYCAPS +36/+40/
  +44/+48) and their midpoints go to 453fd8.. / 454008...
- Input then arrives only as messages from the capture: MM_JOY1MOVE 0x3a0 /
  MM_JOY2MOVE 0x3a1 (lParam x | y<<16) → 43b3d0 splits the range into
  left/right/up/down bytes by quarters around the stored extents;
  MM_JOY1BUTTONDOWN/UP 0x3b5/0x3b7 and MM_JOY2BUTTONDOWN/UP 0x3b6/0x3b8
  (wParam low four button bits) → four button bytes per joystick. All ported
  in `OriginalWindowInput`; DefWindowProc follows them.
- The Mac startup service answers joyGetNumDevs 16 and joyGetPosEx 167 for
  both IDs; the runtime never posts MM_JOY messages and its DefWindowProc does
  not accept them.

## Declared policy (not the EXE)

- Devices: the first two macOS game controllers connected at launch are
  joysticks 0 and 1 (the original probes only at startup; later connections
  are not seen). Scripted runs declare them with `--joysticks N`.
- joyGetPosEx → JOYERR_NOERROR with centred output; joySetThreshold and
  joySetCapture → JOYERR_NOERROR; joyGetDevCapsA → JOYERR_NOERROR with
  X/Y ranges 0..65535 (other JOYCAPS fields zero).
- Position: the left thumbstick, or the d-pad when pressed, as X/Y in
  0..65535 (up is small Y, as Windows). A move message is posted when either
  axis changes by more than the threshold, at most every 25 ms, as the
  capture requests. Buttons: A, B, X, Y → joystick buttons 1..4, posted as
  button down/up messages with the JOY_BUTTONnCHG bit of the changed button.
- DefWindowProc for the six MM_JOY messages returns 0.

## Stages

- **J1** — the startup service's joystick answers for declared devices and the
  runtime's MM_JOY messages/DefWindowProc; script action `joy ID X Y BUTTONS`
  and `--joysticks N`; checks: runtime tests; an app run where player 3 joins
  and picks with joystick 1 (captures).
- **J2** — GameController input for interactive runs (connection at launch,
  thumbstick/d-pad/buttons sampled at the capture period).
- Checks: e2e joystick check; the whole e2e set.

EXE envelope not recalculated.
