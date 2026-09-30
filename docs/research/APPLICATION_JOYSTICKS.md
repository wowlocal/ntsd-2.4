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

EXE envelope not recalculated.
