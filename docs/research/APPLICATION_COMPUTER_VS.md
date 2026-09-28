# VS with a computer player in the app

2026-09-28. Parent: [special moves](APPLICATION_SPECIAL_MOVES.md) (5986808).
Exploratory app runs; independent review open. No original code executed.

## Result

A VS match with one computer player now starts and runs in
`NTSDNative --original`: VS Mode → Naruto/Sasuke → "How many computer
players?" 1 → the computer's character (random) → start menu → District →
Fight!. The computer character fights both players with the ported AI (one
character-AI request per tick) and knocked out Naruto and Sasuke by tick 1800
in the recorded run. [Capture](../evidence/application-computer-vs-capture.png),
[evidence](../evidence/application-computer-vs.json).

## Findings

1. **Menu path.** After the count is confirmed a pop-up for the computer's
   character needs two confirmations (≈100 iterations apart); the start menu
   then opens on "Randomize" (each further press re-rolls the computer).
2. **Script clock.** Scripted actions counted committed message-loop
   iterations. These stop while gameplay ticks run with no queued input, so a
   script could stall mid-fight (earlier "hangs" were this; the game kept
   running). The app now accepts `--script-clock committed|all|gameplay`
   (`gameplay`: committed until the first tick, then every iteration),
   reports `progress` every 300 ticks (busy/wait time, AI counts), and takes
   `--body-captures DIR` and `--exit-after-bodies N`.
3. **Speed.** With three fighters the app runs ≈8 ticks/s after the first
   300 (≈62 ms per tick inside `complete()`, Sleep requests stay 5 ms). A
   sample attributes most of it to application plumbing (gameplay session
   setup, loaded-cycle session, committed-draw replay), not game logic (game
   body ≈5 %, AI ≈1 %). One hotspot is fixed here:
   `OriginalWaveOwnership.addressedRegions` re-compared every runtime sound
   buffer on each tick (up to ≈0.4 s/tick); a successful check is now cached
   per immutable owner (failures are never cached).

## Checks

Ownership-related suites and the runtime loading suite re-run for the cache:
`OriginalLoadingAudioTests` (3), `OriginalApplicationLoadingPrefixTests` (2), three fast
`OriginalMacLoadingAudioTests` methods and `OriginalMacRuntimeLoadingTests` (2):
10/10 in 614.2 s. The 45-minute whole-caller audio test was not repeated.

## Remaining

Performance of the application plumbing (target: the original's ~30 ticks/s
with several fighters), match end with computers, GDI text, music, other
arenas, automated end-to-end test, device/Windows acceptance. EXE envelope not
recalculated.
