# Game controllers as the original's joysticks

[Plan](APPLICATION_JOYSTICKS_PLAN.md). The original is not executed.

## Result (2026-09-30)

Core was already complete: `OriginalInputStartup.initializeJoysticks` (43bf10)
and the MM_JOY handling in `OriginalWindowInput` are ported. The work is on
the Mac side, under the declared policy in the plan:

- `OriginalMacRuntimeStartupService` takes the number of joysticks connected
  at startup (`Environment.joysticks`). For those IDs joyGetPosEx returns
  JOYERR_NOERROR with a centred stick, joySetThreshold and joySetCapture
  return JOYERR_NOERROR, and joyGetDevCapsA returns JOYERR_NOERROR with X/Y
  ranges 0..65535 and four buttons; other IDs stay JOYERR_UNPLUGGED.
- `OriginalMacRuntimeMessages.joystick(id, x, y, buttons)` posts
  joySetCapture's messages: MM_JOY1MOVE/MM_JOY2MOVE when an axis moved by
  more than the threshold of 100, MM_JOYnBUTTONDOWN/UP with the changed
  buttons' JOY_BUTTONnCHG bits, lParam x | y<<16. DefWindowProc answers the
  six MM_JOY messages with 0.
- The app treats the first two extended game controllers connected at launch
  as joysticks 0 and 1 and samples them every 25 ms (the capture period): the
  left thumbstick, or the d-pad when pressed, as X/Y (up is small Y), A/B/X/Y
  as buttons 1..4. Scripted runs declare devices with `--joysticks N` and
  inject samples with the script action `joy ID X Y BUTTONS`.

**App:** with `--joysticks 2`, a VS match is played with joystick 1 alone:
player 3 (whose default device is joystick 1) joins on button 1, a stick move
right changes the character, confirmations, the computer count and the start
menu are all joystick taps, and the fight runs with stick and button input.

**Checks:** a runtime test covers the startup answers (numbers, ranges,
unplugged IDs, a capture request for an absent ID rejected) and the message
rules (threshold, button down/up bits, lParam, the third joystick ignored,
DefWindowProc); the runtime-menu suite passes (5). `tools/app_e2e.py` gains a
`joystick` scenario with its recorded reference (match launch, gameplay and an
in-match capture); re-running it matches the reference. The whole e2e set
passes (vs with its checks, mission, demo, war, playback, tournament,
team-tournament, joystick).

Not tested: a physical controller (none attached here); the GameController
mapping is compiled and linked but has only been exercised through the same
runtime entry point the scripted samples use.

## Independent review (2026-09-30)

A review of the CONTROL SETTINGS port and wiring and of this card found no
defect in the ported screen or in the MM_JOY semantics (wParam current buttons
| JOY_BUTTONnCHG, lParam x | y<<16, moves relative to the last posted position
past the threshold, JOYINFOEX/JOYCAPSA offsets). It raised four issues, all
fixed:

- **Caps Lock.** macOS reports one flagsChanged per Caps Lock toggle and none
  on release; the app's modifier handling made VK_CAPITAL stay down while Caps
  Lock was on, so CONTROL SETTINGS' key capture would bind CapsLock (0x14, the
  lowest pressed VK) and nothing else. Each Caps Lock event is now a whole
  press (down, then up), as a physical press is on Windows.
- **Controllers at launch.** Already-connected controllers are enumerated
  asynchronously; interactive runs now give GameController up to 0.5 s to
  report one before the single startup probe.
- **Undeclared IDs.** `joystick()` now ignores IDs at or above the number
  43bf10 captured (`capturedJoysticks`), so a script cannot drive a joystick
  that was answered as unplugged.
- **Run-loop mode.** The 25 ms sampling timer runs in the common modes and so
  continues while a window is dragged or a menu tracks.

The runtime tests (5), the joystick and vs e2e scenarios and an interactive
launch pass; the Caps Lock and discovery changes act only on real input and
are otherwise untested here.

EXE envelope not recalculated.
