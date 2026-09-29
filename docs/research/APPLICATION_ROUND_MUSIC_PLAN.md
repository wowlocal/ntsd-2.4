# Round music stop in the app — plan

2026-09-29. Found by [sound effects](APPLICATION_SOUND_EFFECTS.md): the
round's DirectShow music calls reach no one. The original is not executed.

## Static reading

`OriginalMatchRound` (ported and compared before) stops the music through
`OriginalMusicPlayback.stop`: IMediaControl::Stop (control 0x24) and a
binary64 zero put_CurrentPosition (position 0x20), when the round timer
450bdc reaches 80 —

- mode 1 (Mission): the players are defeated and the stage counter 450ba8 is
  ≤ 0 (then 44d02c = 1 and the round sound 45561c plays);
- other modes: a match is decided and the mode is not 0, 2, 3, 4 or 5.

Core answers these calls itself (result 0, ignored as by the original) and
records them as `.roundMethod` operations in the committed batch; the Mac
runtime drops them. `OriginalMacRuntimeMusic.answer` already implements
Stop and put_CurrentPosition for the graph the output presents.

## Stage

- **R1.** At commit, answer round and control methods whose token is a music
  interface with `OriginalMacRuntimeMusic.answer` (their results stay ignored,
  as Core already declared them); the output then follows the stopped graph.
  Check: the Mission e2e (the idle player is knocked out) — its reference
  changes where the music state is recorded after timer 80, and only there;
  the other scenarios stay unchanged.

EXE envelope not recalculated.
