# War mode in the app — plan

2026-09-29. Parent: [Mission](APPLICATION_MISSION.md) (efcdedc),
[modes survey](APPLICATION_MODES_SURVEY.md). The survey's War run (mode 4)
stops in the character screen at "Match selection: Other mode selection
continuation": `OriginalMatchSelection.continueSelection` and
`OriginalComputerSelection` accept modes 0–1 only, and the app passes no
`warStage`. Already recovered but not connected: War setup menus 200..202/210
([LIB_WAR_SETUP](LIB_WAR_SETUP.md), 806 comparisons) and War start preparation
43a21f..43a769 ([LIB_WAR_PREPARATION_MATRIX](LIB_WAR_PREPARATION_MATRIX.md)).
Still unported: the War post-draw child 43a860 (a boundary in
`OriginalPostDrawImpulses`).

The original runs only inside Unicorn oracles. Stages W1–W4 are each committed
after they pass their own checks.

## W1 — character screen, mode 4

Static reading of the character screen inside 41bc90 (mode pointer at
[esp+0x1c]) gives these mode-4 differences after the human seats:

- Popup 42b296..42b959: the lower bound is 1 when fewer than two groups exist
  and mode ≠ 1 (same as VS); no mode-4 branch.
- Computer selection 42b964..42cb86:
  - 42c3e1/42c3ef: the team excluded for the last computer is computed in
    modes 0 **and 4**.
  - 42c511..42c54b: on every frame of the team step, while the team equals the
    excluded one, or (mode 4 and the team is 0 or > 2), team = (team+1) mod 5.
  - 42c84a (Right): +1 mod 5, one more +1 if it hits the excluded team; no
    mode-4 filter in that frame (the next frame's loop above corrects it).
  - 42c892..42c911 (Left): −1 with wrap to 4, repeated while the team equals
    the excluded one or (mode 4 and the team is 0 or > 2).
  - 42c91b: mode 2 forces team 0 and confirms (not part of W1; mode 2/3 stay
    boundaries).
  - Cancel and 451220 paths: mode 4 behaves like mode 0.
- Settings 42cb86: `cmp [mode],4; je 42e0b6` — mode 4 skips the settings screen
  and leaves through the common tail; on the next call 42a0b9 moves the menu to
  200 (already ported), which enters War setup.

**Oracle:** `tools/oracle_war_selection.py` reuses the accepted retained
selection harness (`oracle_lib_selection_stage.Selection`, fresh
`initialize-mode-4` parent, installed lib.dll, CW023f) with a mode-4 chain:
join two humans, characters, mode-4 team edges (Right/Left over the forbidden
teams), ready and countdown, the popup (wraps, count 3), three computers with
character edges, Right to team 3 and the next-frame correction, Left over
forbidden teams, cancel back to the character, the last computer's excluded
team, the final random fill (0xd9), and the frame that sets 4512c8 = 3 and
leaves through 42e0b6. Main and control chains (control: different team
choices so the last computer excludes a team).

**Native:** allow mode 4 in `continueSelection` and `OriginalComputerSelection`
with the rules above; mode 4 skips the settings block. Mode 2/3 remain explicit
boundaries.

**Comparison:** `OriginalLibSelectionStageTests` gains a corpus parameter
(case count and final assertions from the corpus), and runs the War chain with
the same full per-case comparison (events, globals, World, 400 Actors,
checkpoints, retained allocations).

## W2 — app wiring to the War start

Connect `warStage` in `OriginalApplicationLoadedMenuSession` through
`OriginalWarSetup.advanceWithSurfaceLoading` with the app's allocation,
bitmap-loading, draw and War-memory owners, and `prepare` through
`OriginalWarPreparation.prepare` (local time, arena bitmap construction/release,
music resume, replay allocation). Then find how the original enters gameplay
after War start (menu 0 after 43a21f) and hand that to the host's gameplay
session. Check: an app run from the main menu to the first War gameplay frame.

## W3 — War post-draw child 43a860

About 760 instructions; callees 401290 (surface text), 4061d0, 417170 (RNG),
423a70 (bitmap font), 4450b2; globals 451c80..451c8c, 44d37c; table 449e1c.
Same path as Mission: static reading, a direct-call oracle after the verified
first loading, a port with recorded callee calls, strict corpora, composition
in the gameplay body.

## W4 — full War in the app

An app run of a War match to its end and back to the menu; e2e scenario.

EXE envelope not recalculated.
