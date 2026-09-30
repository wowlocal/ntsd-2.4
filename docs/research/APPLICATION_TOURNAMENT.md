# Tournament and Team Tournament in the app

2026-09-29. [Plan](APPLICATION_TOURNAMENT_PLAN.md) stages T1–T3. The original
was not executed; every routine the app runs here was ported and compared
before ([setup](LIB_TOURNAMENT_SETUP.md), [bracket](LIB_TOURNAMENT_BRACKET.md),
[preparation](LIB_TOURNAMENT_PREPARATION.md),
[arena release](LIB_TOURNAMENT_ARENA_RELEASE.md) and the Team Tournament
counterparts). This card connects them to the running app.

## T1 — wiring

`OriginalApplicationLoadedMenuSession` now passes `tournamentStage` and
`teamTournamentStage` to `OriginalMatchSelection.advanceWithLibrary`. Each runs
the bracket (`OriginalTournamentBracket` 26..29 / `OriginalTeamTournamentBracket`
126..129) with the session's music owner (`resumeMatch`), the character-screen
draw path, front events and checkpoints, and a `prepare` continuation
(`bracketStart`) that calls 434349 `OriginalTournamentPreparation` or 436747
`OriginalTeamTournamentPreparation`.

The arena handling that War start used is now one helper, `stagedArena`: arena
wrappers from `.arena(n)` allocations, releases checked against their live
owners, adoption and release applied after the preparation (which owns the
memory during its call). War start and both tournament starts use it; local
time and the recording allocation come from the session's providers
(`localTime`, `allocateRecording`). The tournament preparations have no null
arena allocation in their contract, so a zero address is a boundary.
Preparation events are accepted by kind (`preparationEvent`); the computer
join sound (0x45560c: `soundRequest`/`soundMethod`) goes to the front like
other menu sounds; any other kind stays a boundary.

## T2 — Tournament

Main menu → Tournament; fighter 1: Right (first character), Attack, Right
(Human), Attack; fighters 2–8: Attack, Attack (Random, Computer). "Shuffle the
order?": Yes (menu 23) shuffles and returns to the same question; No (24)
randomizes and opens the settings (Fight!, Reset All, Randomize, Background,
Difficulty, Exit — [capture](../evidence/application-tournament-settings-capture.png)).
Fight! starts the bracket: the first pairing is highlighted, the human presses
Attack to take a device, Right + Attack answer Yes to "Is the setting ok?",
and the preparation starts the match (recording
`recording\20260101_010000_1on1_Prelminar.lfr` — the original's spelling).
The match plays to the Summary (1832 gameplay bodies); Attack returns to the
bracket (menu 28), which records the winner and decides the computer
pairings itself, up to the Winner screen
([capture](../evidence/application-tournament-winner-capture.png)); Attack
returns to the main menu with Tournament highlighted (`bgm\main.wma`).

## T3 — Team Tournament

The same inputs after Team Tournament: teams of two ("2 on 2"), Team 1 is
the human with a computer partner. The human's match is a 2-on-2 fight
([capture](../evidence/application-team-tournament-battle-capture.png),
recording `…_2on2_SemiFinal.lfr`, 1856 bodies); the bracket decides the rest,
shows the winning team ([capture](../evidence/application-team-tournament-winner-capture.png))
and Attack returns to the main menu with Team Tournament highlighted.

## Checks

`tools/app_e2e.py` gains `tournament` and `team-tournament` scenarios
(references `tools/app_e2e_tournament_reference.json`,
`tools/app_e2e_team_tournament_reference.json`: milestones, body captures,
winner and main-menu captures, overlay files). The whole e2e set passes on
the release app: vs (with the Quit check), mission, demo, war (after the
`stagedArena` change), playback, tournament and team-tournament.
`OriginalApplicationLoadedMenuTests` and the Tournament / Team Tournament setup
suites pass (9/9). The settings capture comes from a probe run with the same
setup inputs.
[Evidence](../evidence/application-tournament.json).

Known gaps, unchanged: GDI text (Background/Difficulty values, Summary
numbers, names) is empty; the hotkey sounds 416c70/416ca0 are unserved.

## Independent review (2026-09-30)

A review against the EXE (434349..4347c5, 436747..436afd and the seat scan
434366..4343b2) found no defect in the wiring. Neither preparation calls a
music routine, so leaving out `resumeMusic` is right. After 434349 the EXE
falls through to 4347c5 with 44d020 = 0, as the port's `prepare → true`
does. The computer-join sounds reach the front, and a null arena allocation
is a boundary. The Winner-screen music stop it noted was already fixed in
446da3f. Two test issues:

- **Second human match untested.** In both scenarios the human lost round 1,
  so `stagedArena`'s release (the previous arena and the old recording, freed
  before a second human match) never ran. New scenario `tournament-win`: the
  human attacks through the Preliminary and wins. Attack on the Summary, then
  at the bracket Attack on "Please choose your control device" and Yes start
  the Semi-final. The human loses it
  ([capture](../evidence/application-tournament-win-semifinal-capture.png)),
  and Attack returns to the bracket. There is no boundary: two `menu` events
  (1104 and 2520 bodies) and the files `…_1on1_Prelminar.lfr` and
  `…_1on1_SemiFinal.lfr`. The second match added 120,240 bytes of heap
  addresses (the replay blocks were reused). Recorded, then re-run: pass.
- **Time zone.** The replay file names follow the Mac's time zone; the e2e
  runs now pin UTC+1 ([APPLICATION_E2E.md](APPLICATION_E2E.md)).

EXE envelope not recalculated.
