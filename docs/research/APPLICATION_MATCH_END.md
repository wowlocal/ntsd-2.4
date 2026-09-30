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

## Independent review (2026-09-30)

A review of loading, match end and pacing (c1567cb, 0a77527, 9d33d8d and
3ea0cd3) found no defect in replay file naming or contents, the return to
character selection, or tick timing (no drift; the original's catch-up and
dropped ticks are kept). It raised six issues, all fixed:

1. **Idle sleep.** The App Nap exemption used `userInitiated`, which also
   stops the Mac from idle-sleeping; the original never calls
   SetThreadExecutionState. It is now `userInitiatedAllowingIdleSystemSleep`
   with `latencyCritical`.
2. **Links after START.** `ShellExecuteA` on the mode screen, the panel links
   and Playback's folder was recorded as successful but not carried out. The
   loaded batch's `shell` operations now go to the front menu's handler when
   the batch commits (verb `open` or `explore`; anything else is a boundary),
   delayed by the screen's preceding `Sleep`.
3. **Sleep(300) after START.** The screens' own `Sleep(300)` was recorded but
   the next iteration waited only for the Host tail's `Sleep`. It now waits
   for every `Sleep` of the committed batch, summed.
4. **Failed replay write.** An error writing `recording\*.lfr` after the
   commit stopped the app. It is now reported (`failedReplayWrites` in the
   `menu` event) and the game goes on (declared policy: the original's failing
   `fopen`/`fwrite` leaves the game running; the file is lost).
5. **Heap addresses.** Each match reserved a new 0x630e18-byte recording and
   each KO a new 0x631200-byte writer buffer in the never-reused 1 GiB arena:
   13.1 MB per recorded match, about 66 matches in one session. Declared
   policy: the runtime heap reuses a replay block (recording, playback buffer,
   writer buffer) for a replay request of the same size once the Core memory
   the next call starts from marks it freed; live and unknown blocks are never
   reused. Core's own checks are unchanged: a claim still refuses a live
   range and the writer a live alias. Growth is now 120,272 bytes per match
   (15 arena bitmap wrappers of 0x1f50, which Core's adoption rule keeps new),
   about 7,500 matches from the 167 MB used after the first one.
6. **Sleep with a queued message.** An iteration that slept dropped its
   delay when a message was queued in the same iteration. The delay is now
   the iteration's `Sleep` whenever it slept.

**Checks:**

- Mode screen after START: three link clicks give three `shellOpen` events,
  each 300 ms after its click.
- VS with `recording` in the overlay as a file: the `menu` event lists the
  failed write, the match returns to selection and the app exits 0.
- Five VS matches in a row: the `menu` event's `heapBytes` is 166,772,512
  after the first match, then +120,272 per match (+13,104,624 before).
  The recording and writer addresses are the same in every match.
  The five replay files match the earlier binary's sizes (11044, 10268,
  10234, 10201, 10203 bytes).
- New heap test (live, freed, unknown and other-size blocks).
- Mac runtime tests (12) pass.
- The whole e2e set passes: vs with its quit, website, controls, online and
  recording checks, mission, demo, war, playback, tournament, team-tournament
  and joystick.

**Follow-up (2026-09-30).** A second review noted that Playback's ShellExecuteA
of a chosen `.txt` still ran inside the loaded-menu attempt, before its
Sleep(300), not at commit as item 2 says. It is now queued during the attempt
(cleared at each loaded-menu start), opened when the batch commits after that
batch's Sleep, and reported as a `playbackOpen` event. Playback with
`--playback-file notes.txt` gives `playbackDialog` then `playbackOpen` and
exits 0. The Mac runtime tests (12) pass.

EXE envelope not recalculated.
