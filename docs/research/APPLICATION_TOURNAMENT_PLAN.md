# Tournament and Team Tournament in the app — plan

2026-09-29. Parents: [Tournament setup](LIB_TOURNAMENT_SETUP.md),
[bracket](LIB_TOURNAMENT_BRACKET.md), [preparation](LIB_TOURNAMENT_PREPARATION.md),
[arena release](LIB_TOURNAMENT_ARENA_RELEASE.md), the Team Tournament
counterparts, and [War in the app](APPLICATION_WAR.md) (the same wiring shape).
The original is not executed by this card.

## Static reading (already recovered and compared)

- Mode 2 enters menu 20 (`OriginalModeSelection`); mode 3 menu 120. The
  shared character-screen dispatcher runs `OriginalTournamentSetup`
  (menus 20..25) and `OriginalTeamTournamentSetup` (120..125).
- Menu 22 "Shuffle the order?": Yes (23) shuffles 11 frames and returns to 22
  with Yes highlighted; No (24) randomizes and opens the settings (25).
  Settings option 0 (Start, 4338c3) calls the bracket continuation with
  `initialize = true`; menus ≥ 26 call it with `initialize = false`.
- The bracket (`OriginalTournamentBracket`, 26..29; team: 126..129) calls its
  `prepare` continuation — 434349 `OriginalTournamentPreparation` / 436747
  `OriginalTeamTournamentPreparation` — and returns `.returned`; without
  `prepare` it stops at `.tournamentMatchPreparation`.
- After a match `OriginalMatchRound` sets menu 28 (mode 2) or 128 (mode 3):
  the bracket's winner output, through the same continuation.
- The app (`OriginalApplicationLoadedMenuSession`) passes no bracket
  continuation: `OriginalTournamentBracket.unavailable` returns
  `.tournamentPrelude` for Start, which the session refuses ("Character
  continuation tournamentPrelude"), and throws for menus ≥ 26.

## Stages

- **T1 — wiring.** Pass `tournamentStage`/`teamTournamentStage` closures to
  `OriginalMatchSelection.advanceWithLibrary` that run the bracket with this
  session's music owner (`resumeMatch`) and a `prepare` composing the
  preparation like `warStart`: local time and recording allocation from the
  session's providers, arena wrappers from `.arena(n)` allocations (a null
  allocation is a boundary: the preparation's contract has no null path),
  releases of the previous arena staged and applied after the call.
  Preparation events are accepted by kind; anything else stays a boundary.
- **T2 — Tournament in the app.** Player 1 plus seven computers: setup,
  No at the shuffle question, Start; the first match plays; Summary returns
  to the bracket (28) and the tournament continues to its end. e2e scenario
  `tournament`.
- **T3 — Team Tournament in the app.** The same for mode 3; e2e scenario
  `team-tournament`.

Checks: existing Tournament/Team Tournament library suites and the loaded
menu tests; the e2e set. Unknowns stay boundaries. EXE envelope not
recalculated.
