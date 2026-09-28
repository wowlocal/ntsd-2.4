# Naruto vs Sasuke on District starts in the app

2026-09-28. Continues [START → loading](APPLICATION_RUNTIME_LOADING.md) (c1567cb).
Exploratory integration driven by window captures; author checks only,
independent review open. No original code executed.

## Result

In the release `NTSDNative --original`, scripted input (the same clicks and
keys a player uses) goes from the front menu through VS Mode, the controls
panel, character selection (P1 Naruto, P2 Sasuke), the countdown, "How many
computer players?" (0), the start menu (Background → District, Fight!) to the
retained match launch and gameplay bodies. The capture shows the District
arena, the HUD with both portraits and HP/chakra bars, both fighters, NPCs and
a ground item. [Selection](../evidence/application-runtime-selection-capture.png),
[match](../evidence/application-runtime-match-capture.png),
[evidence with the full script and runs](../evidence/application-runtime-match.json).

Code: `OriginalMacRuntimeLoading.launch()` (arena layers from the packaged
District images, 6.5 MB recording at a runtime heap address, macOS local time,
runtime music), `gameplay()` (zero DDBLTFX fill backing), `runCycle()` now uses
`prepareLoadedUntilBoundary` and retains gameplay input, and `complete(first:)`
routes returned/launch/gameplay outcomes. NTSDApp gained `--script` for timed
clicks, keys and captures.

## Findings

- Roster order follows `data/data.txt` after the random "?" entry; the
  Background option cycles 100 (random) → 99 → 0 (District) on confirm.
- A random background chose CastleRoof and stopped at an undeclared bitmap
  file: only District's deferred arena layers are packaged (run preserved).
- GDI text (key names, player/ninja/team fields, computer count, background
  and difficulty values) is omitted under the GetDC-failure policy; the
  "VS mode (Difficult)" label is drawn, so not all text uses GDI.

## Live fighting (addendum, same day)

Gameplay runs at ≈30 bodies per second in release. Holding D walks Naruto
right with the camera scrolling; J attacks and throws. Two scripted fights
stopped at the same Core boundary, the unrecovered AI/object input child of
`OriginalLocalInput.localInput`; the diagnostic run names object id 219
(`chars\jan_chaseh.dat`, type 3) at frame 51, whose frame field +0x30 is
positive (a chasing object). One run with a different time-seeded RNG did not
reach it. [Fight capture](../evidence/application-runtime-fight-capture.png).

## Remaining blockers toward the milestone

1. **AI/object input child** (characterAI for type-0 objects, objectInput for
   frames with positive +0x30): required once such objects appear; needs
   contract recovery from the EXE before implementation.
2. A complete round/KO, result screen and return; an automated test of this
   path (≈1300 iterations to reach gameplay).
3. GDI text raster (needs a font decision), music output, other arenas'
   layers, shutdown paths, device/Windows acceptance. EXE envelope not
   recalculated.
