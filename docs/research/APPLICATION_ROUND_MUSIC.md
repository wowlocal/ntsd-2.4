# Round music stop in the app

2026-09-29. [Plan](APPLICATION_ROUND_MUSIC_PLAN.md) stage R1. The original was
not executed.

`OriginalMacRuntimeLoading.answerRoundMusic` answers, when a loaded batch
commits, its round and control methods whose token is a music interface
(`OriginalMacRuntimeMusic.interface`) with `OriginalMacRuntimeMusic.answer`:
the round's IMediaControl::Stop (0x24) and zero put_CurrentPosition (0x20).
Their results stay the ones Core declared (0, ignored as by the original);
the music output follows the stopped graph on the next presentation. The
sound-effect extraction already skips these tokens
([sound effects](APPLICATION_SOUND_EFFECTS.md)).

**Mission e2e:** the idle player is knocked out on Stage 1-1; at round timer
80 the music now stops, as the original's round code orders. The reference
(`tools/app_e2e_mission_reference.json`) changes in exactly two fields —
`musicPlaying` at gameplay bodies 1500 and 1800 becomes `false` — while every
capture, count and milestone is unchanged. The whole e2e set passes with that
reference (vs with the Quit check, mission, demo, war, playback, tournament,
team-tournament); `OriginalMacRuntimeLoadingTests` 2/2.

EXE envelope not recalculated.
