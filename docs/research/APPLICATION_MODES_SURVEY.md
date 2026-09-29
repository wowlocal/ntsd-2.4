# Game modes other than VS: first stops in the app

2026-09-29. Parent: [all arenas](APPLICATION_ARENAS.md) (ddf98d1). Exploration
card (no code change); runs by Claude, independent review open. The original
was not executed. [Main menu and mode screens](../evidence/application-modes-survey-capture.png).

The main menu (after START and loading) lists VS Mode, Mission Mode,
Tournament, Team Tournament, War, Demo, Playback Recording and Quit; the
kunai cursor moves with Up/Down (keyboard, not the mouse position) and
Attack selects. Mode word 0x451160 = menu index (0 VS … 7 Quit), set by
`OriginalModeSelection`. Runs: release app, `--virtual-clock 123456789 8`,
`--mute-music`, temporary overlays, `--exit-after-capture` (a boundary exits
with its report); after the mode, player 1 joins and picks (Attack, Right,
Attack, Attack), Attack answers the computer-count question, Up Up Attack
chooses Fight!.

| Mode | First stop | Where |
| --- | --- | --- |
| 1 Mission Mode | Character Selection, computer count, a start menu with **Stage:**; match launches; first body: "Post-draw: original mode1 child is not recovered" (iteration 1167) | `OriginalPostDrawImpulses` (41f4ac..41f545 mode1/4 children unrecovered) |
| 2 Tournament | bracket "Settings" screen, alive through 3000 steps (needs its own inputs) | — |
| 3 Team Tournament | "2 on 2" bracket settings, alive through 3000 steps | — |
| 4 War | "Match selection: Other mode selection continuation" (iteration 795) | `OriginalMatchSelection` accepts modes 0..1 only |
| 5 Demo | same (iteration 229; Demo sets 0x450c2c = 1) | same |
| 6 Playback Recording | Host `unreturnedLoading` (iteration 251) | `OriginalApplicationHostSession` (loading must return) |
| 7 Quit | "Front operation postQuit" (iteration 276) | loaded-menu front switch; WM_QUIT/WinMain return not modeled |

Order of the next cards: Quit (PostQuitMessage, WM_QUIT through the message
loop, WinMain's return and the app's termination), then Mission Mode's mode1
post-draw child (EXE recovery with an oracle), War/Demo selection
continuations, Playback, and the Tournament inputs. EXE envelope not
recalculated.
