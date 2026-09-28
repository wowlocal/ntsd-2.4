# Application tick speed: plan

2026-09-28. Parent: [VS with a computer player](APPLICATION_COMPUTER_VS.md)
(94762ea). Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md).
Written before the change; the policies below were fixed before the recorded
runs. **Executor/reviewer:** Claude; independent review open.

**Consumer and criterion:** the release app plays the computer-VS script
(`cpu12`, gameplay clock) faster, with the same game: every body capture of
the run (ticks 300..1800) stays byte-identical to the same run of the parent
binary. Target: the original's pace (Sleep 5 per body; ≈30 ticks/s or more
with three fighters).

**Proven blocker (profile, 15 s of `sample` during the match, parent build):**
`OriginalApplicationMatchBindings.store` is 1707 of 4181 samples of the
tick loop (41 %), `_ArrayBuffer._consumeAndCreateNew` 1874 and dictionary
deinit 622 inside it. Every body builds an owned snapshot at each of its 19
stages (`GameplaySession.advance` → `.gameplayCheckpoint`) and the loaded
cycle one per prologue/checkpoint (7); each store copies the 16 k-entry
allocation dictionary and compares 400 Actor records. The app ignores all of
them. Speed also falls during the match (first 300 ticks ≈25/s, later ≈8/s).

## Finite changes

1. `OriginalApplicationGameplaySession.advance(…, checkpoints: Bool = true)`
   and `OriginalApplicationLoadedCycleSession.advance(…, checkpoints: Bool = true)`:
   with `false` no per-stage snapshot is built and the checkpoint/prologue
   observers are not called. The final join (`bindings.store` of the whole
   result, with its alias, actor-conflict and extent checks) is unchanged and
   still decides the attempt. Defaults keep every existing caller and test.
2. The app passes `checkpoints: false` in `runCycle()` and `gameplay()`.
3. Then re-profile; further changes only for measured hotspots, each one
   observation-free or value-preserving, recorded here before the run.

## Declared difference

Without checkpoints an inconsistency that exists only between two stages of
one body (e.g. an Actor allocation changed and restored) is no longer seen;
the attempt still fails on any inconsistency in the final state, before any
commit. The app never consumed these snapshots.

## Checks

1. Core suites that use checkpoints (gameplay provider/projection/paused,
   active notices/recording, loaded menu) and the runtime loading suite.
2. App (release): the `cpu12` script with `--body-captures` at 300..1800 for
   the parent binary and the new one; captures compared byte for byte; ticks/s
   and busy time from the progress events.

EXE envelope not recalculated. Out of scope: GDI text, music output.

## Amendments during the round

- The first capture comparison (parent binary, two real-clock runs) failed
  for both runs alike: the CRT seed is the startup timeGetTime. Added before
  the recorded comparison: `--virtual-clock BASE STEP` (timeGetTime from the
  iteration count, fixed startup date, GetMessagePos (0,0)) and
  `--stage-checkpoints` (the unchanged path as the reference). STEP 8 chosen
  after menu captures showed STEP 6 opening the computer-count pop-up after
  the scripted keys.
- The virtual-clock runs showed ≈7 % CPU and ≈210 s per 300 bodies: App Nap.
  Added a process activity (declared host policy); captures re-compared.
