# Plan: replay cross-play between the Mac app and the original under CrossOver

2026-10-02. Parent: [GOAL_100](../GOAL_100.md) P1b (long-horizon equivalence).
Task → missing result → milestone: whole matches equal to the original, not
only compared functions → no whole-match check exists today → play the same
recording in both programs and compare the outcome.

## Declared necessity and limits

Per CONTINUE_GOAL, running the original outside Unicorn needs a declared
necessity. This check needs it because a recording replays a whole match
through the original's own playback, which is the only way to compare
thousands of ticks of the shipped game against the port without building a
new oracle. Earlier work used the same environment:
[CrossOver setup](CROSSOVER_REFERENCE_SETUP.md) and
[launch](CROSSOVER_REFERENCE_LAUNCH.md) (bottle `NTSD24XP`, CrossOver 26.3,
verified game copy, existing `Run NTSD24XP.command`).

- **Wine is not Windows.** Simulation is the EXE's own x86 code and depends on
  neither, but DirectX, GDI, sound and the heap are Wine's. Only gameplay
  outcomes are compared here, never fonts, audio or timing.
- **x87 under Rosetta is an assumption.** The game's arithmetic runs on
  Rosetta's x87 emulation. If outcomes differ, the first question is whether
  the emulation or the port is responsible. An unexplained difference is a
  lead, not a verdict.
- **Observation needs the user.** The agent cannot see Wine's window. The user
  watches the playback and takes screenshots, or allows `screencapture` while
  the display is on.

## Inputs (Mac side, prepared)

`tools/crossplay_replays.py` runs the e2e scenarios exactly as
`tools/app_e2e.py` does (virtual clock 123456789, the same scripts). It keeps
each scenario's overlay and writes a manifest: every saved `recording\*.lfr`
with its SHA-256, the app's events (milestones, `replayFiles`) and the
Summary-time captures. The set lives on task-owned X5 storage
(`goal-100-20261002/crossplay-set`); its manifest is copied into the evidence
when the run happens.

## Procedure

1. **Game copy for cross-play.** An APFS clone (`cp -c`) of the verified copy
   `crossover-reference-20260926/game/NTSD 2.4_2.0a` into the task directory.
   Re-verify all 1,595 files against `game-copy1.json`. The reference copy is
   never written.
2. **Mac → original.**
   - Copy each `.lfr` into the clone's `recording\` folder.
   - Launch the original with the existing wrapper and `GAME_DIR`/`EXE_PATH`
     pointing to the clone.
   - Main menu → RECORDING INFO / Playback → choose the file → watch to the
     Summary.
   - The user screenshots the Summary and, if possible, the KO moment.
3. **Original → Mac.**
   - The user plays one VS match and one Stage stage in the original, with
     recording on.
   - Copy those `.lfr` files into the Mac app's overlay and play them back
     there (`--original`, the Playback path that e2e `playback` uses).
   - Capture the Summary.
4. **Byte check of recordings (zlib, GOAL_100 P2).** Where the user can repeat
   the same scripted input in both programs, compare the `.lfr` bytes. If the
   inputs cannot be made identical, only the decoded content is compared.

## Comparison

For each recording, both sides must agree on:

- the winner or the result line;
- every Summary row (Kill, Attack, HP Lost, MP Usage, Picking) for each
  player;
- the match time;
- for Stage, the stage reached and its result.

A screenshot pair is kept per recording. Visual differences from the
temporary GDI font are expected and are not counted.

## Result recording

A result card `CROSSOVER_REPLAY_CROSSPLAY.md` and evidence JSON, holding:

- the recordings and their hashes;
- both programs' observed Summaries;
- the screenshots;
- equal / different per field;
- for every difference, its diagnosis (port, emulation, or unknown).

## Gate

Every recording in the set plays to the end in both programs with equal
outcomes, or each difference is diagnosed and either fixed in the port or
attributed with evidence. This gate does not establish Windows behaviour or
clean-Mac acceptance.

EXE envelope not recalculated.
