# End of the District match in the app

2026-09-28. [Plan](APPLICATION_MATCH_END_PLAN.md). Author implementation and
exploratory app runs; independent review open. No original code executed in
this card (it composes accepted Core pieces with declared runtime policies).

## Result

The Naruto vs Sasuke match on District now runs to its end in
`NTSDNative --original`: fight → KO → original replay saved →
Summary screen → post-KO epilogue → Character Selection, and from there a new
match or the main menu. In the clean evidence run (release, scripted special
moves) the first match ended in a KO, its replay was written
(`recording\20260928_191130_VS.lfr`, 10881 bytes, same length-prefixed layout
as the replays shipped with the original), the Summary screen appeared, and a
second match was started at iteration 4307 and also finished (second replay);
no boundary before the 560 s watchdog. An earlier run with the same code (plus
a stderr-only diagnostic) returned to Character Selection and the main menu.
[Summary](../evidence/application-match-end-summary-capture.png),
[Character Selection](../evidence/application-match-end-selection-capture.png),
[main menu](../evidence/application-match-end-menu-capture.png),
[evidence](../evidence/application-match-end.json).

**Milestone status:** a full Naruto vs Sasuke match on District plays in the
native app from the main menu through KO, Summary and back. Still missing in
that match: GDI text (Summary numbers, names and counters are blank), music
output (silent), and special moves of computer-controlled characters.

## Changes

- Runtime gameplay providers: replay codec buffer (runtime heap), processor
  signature 0x600, `recording\` replay file buffered and applied to the user
  overlay after the Host commit (other paths refused and reported), music
  resume via the runtime COM emulation, declared unknown caller formatter
  locals per body.
- `pausedRendering` → gameplay session; `epilogue` → new
  `OriginalApplicationEpilogueSession` (no body, graphics unchanged, accepted
  dispatcher return).
- Catalog block registry/background/stage backing declared initialized zero in
  the runtime (`allocationDefined`, default false for verification). Found
  with a temporary stderr stack dump: after the match the AI reads the width
  of the "Random" background (index 100, catalog+0x4d819f0), never written by
  the loader; on Windows the 81 MB block is demand-zero pages.

## Checks

- `OriginalApplicationCatalogSessionTests` (3) and
  `OriginalMacRuntimeLoadingTests` (2): 5/5 in 543.3 s.
- App runs (release): round 1 stopped at the caller formatter; round 2 at
  "Selected input continuation" (the epilogue); round 3 at the undefined
  "Random" background width after a second match; rounds 4–5 ran without a
  boundary to the watchdog. All runs are time-seeded; scripts and events are in
  the evidence.

## Remaining

1. 403a40 special-move blocks for computer-controlled characters (ids 1, 2,
   4..11, 32, 34..36, 38, 39, 50..52), then VS with computer players.
2. GDI text raster (needs a font decision), music output, other arenas'
   packaged layers, shutdown paths, automated end-to-end test,
   device/Windows acceptance. EXE envelope not recalculated.
