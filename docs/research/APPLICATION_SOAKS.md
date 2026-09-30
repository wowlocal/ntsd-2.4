# Long runs in the app (soaks)

2026-09-29. Purpose: find the next obstacles to the rest of the game by
running modes far longer than `tools/app_e2e.py` does. Every run uses the
release app, `--original --mute-music --mute-sounds`, a temporary
`--overlay`, `--virtual-clock 123456789 8` (so runs are deterministic and
reproducible), `--script-clock gameplay` and `--exit-after-bodies N`; a stop
is the app's `boundary` event. The original is not executed.

## Demo (eight computers, random characters)

Script: `20 click 350 230; 60 click 402 218; 100 key 83; 125 key 83;
150 key 83; 175 key 83; 200 key 83; 225 key 74` (Demo from the main menu).

| Run | Result | Card |
| --- | --- | --- |
| 60,000 bodies | stop in match 7, body ≈12,620: cpoint Frame 1000 of `chars\ironsand.dat` | [frames outside the Object](APPLICATION_OUT_OF_OBJECT_FRAMES.md) |
| after it | stop in match 13, body ≈25,590: World links, held drink at frame 1000 | same card (weaponact) |
| after it | stop in match 17, body ≈32,500: undefined 8 bytes at offset 80 (wind.dat's frame-212 jump) | [unwritten header words](APPLICATION_OBJECT_HEADER_DEFAULTS.md) |
| after it | 60,000 bodies, 27 matches, no stop | — |
| 200,000 bodies | no stop: 95 matches, 1,282,772 character-AI calls | — |
| 100,000 bodies, `--virtual-clock 555555555 8` | no stop: 43 matches | — |
| 100,000 bodies, `--virtual-clock 987654321 8` | no stop: 43 matches | — |

The last three runs (different seeds, so different random characters and
arenas) cover 181 Demo matches — 400,000 bodies — without a stop.

Diagnosis used temporary stderr dumps (actor slot and fields, stage names)
that were removed before each commit; the committed error messages now name
the stage, Object and frame for the Frame lookups involved.

## War (Battle mode)

Script: the e2e War start (one human, one computer, War setup defaults,
Fight!) and then, every 14,000 steps, Jump on the Summary, Attack on the War
setup, Up, Up, Attack (Fight!). 60,000 bodies: 14 battles on changing arenas,
1,285,766 character-AI calls, no stop.

## Mission (Stage mode) with three computer allies

Script: Mission, player 1 Naruto, `1000 key 68; 1025 key 68; 1050 key 68;
1100 key 74` (three computers), six computer confirmations (`1250`..`1750
key 74`), `1900 key 87; 1925 key 87; 1960 key 74` (Fight!).

| Run | Result |
| --- | --- |
| no further input | no stop; from body ≈1,800 every fighter stands still for 28,000 bodies |
| Attack every 150 steps | 40,000 bodies, no stop; fighters move but the stage stays in its first area |
| Right held 60 steps + Attack every 150 | 40,000 bodies, no stop; static again from ≈4,500 |

These runs were not on Stage 1-1: the recorded Mission run (Stage 1-1,
[capture](../evidence/application-mission-capture.png)) is on Grassland with a
visible library dialogue box, while these ran on a canyon stage — most likely
the extra confirmations landed on the start menu's Randomize and changed the
stage. In all three a dark ninja between two crystal objects stands at the
centre and the computer allies do not engage it; with no boundary this is
gameplay for this input, not a port stop. Soaking later stages needs a script
that selects them deliberately (the Stage option is GDI text, drawn blank).

### Chosen stages

On the start menu the Stage row is one below Randomize, and each Attack there
moves to the next stage group (the value is GDI text, but the stage's own
"STAGE x-y" banner confirms it): 1 press → 2-1, 2 → 3-1, 3 → 4-1, 4 → 5-1,
5 → Survival. With three computer allies and the human walking right (Right
held 60 steps) and attacking every 150 steps, each ran 30,000 bodies:

| Stage | Result |
| --- | --- |
| 2-1 (its story dialogue drawn by the library) | no stop; the team lost, Summary "Lose (Dead)" |
| 3-1 | no stop |
| 4-1 (many shadow clones on screen) | no stop |
| 5-1 | no stop |
| Survival Stage | no stop |

## VS session: many recorded matches (2026-09-30)

Script: the e2e VS match (`tools/app_e2e_computer_vs.script`), Jump at the
Summary, the same selection again from step 9100, then Attack every 400
steps, which starts each next match from the selection. Every match writes
its replay file.

| Run | Result |
| --- | --- |
| 66 matches, 113,425 bodies | no stop, no failed replay write; logical heap 174.6 MB (+120,272 bytes per match after the first; [replay block reuse](APPLICATION_MATCH_END.md#independent-review-2026-09-30)) |
| 20 matches, footprint sampled every minute | the process grew linearly: 2.0 → 3.2 GB footprint, RSS +72 MB per minute (≈1 match per minute, ≈40 KB per gameplay body) |

Two unbounded logs caused the growth, found by counting them in a
temporary `menu` event field (removed):

1. **Display operation logs.** `OriginalMacDisplayBackend` appended every
   served front draw (≈130 per gameplay body: 714,587 after three matches),
   every window-graphics operation and every bitmap operation to arrays that
   only tests read. The backend now takes `keepsOperationLogs` (default
   true); the live app passes false and keeps only the counts
   (`frontOperationCount`, `operationCount`, `bitmapOperationCount`).
   RSS growth fell to ≈12 MB per minute.
2. **Retained iteration cursors.** `OriginalApplicationIterationDelivery`
   kept every earlier nonempty iteration cursor (≈9,000 per match) so that
   the resources its receipts retain stay alive
   ([iteration history](APPLICATION_ITERATION_HISTORY.md)). The message
   loop's queue and DefWindowProc answers retain no resources, so every
   gameplay tick's cursor was kept for nothing. Only cursors with a receipt
   that retains a resource are kept now; the purpose is unchanged.

With both: 10 matches, footprint 2.0 GB at every sample (to 0.1 GB) and RSS
+4–7 MB per minute, likely pages of mapped files being read in. Checks: a
new `OriginalApplicationIterationDeliveryTests` (resource-free cursors are
not kept, a resource-holding one and its resource are); the runtime menu
test now asserts the live display keeps counts and no logs. The observed
iteration, graphics, bitmap, window-geometry, runtime-menu, retained-history
and delivery suites pass (26 tests), as do the display, front-raster, bitmap
and Mac runtime suites (25) and the whole e2e set. The loading-audio
suite (4, including the whole-catalog Host test) passes on a release test
build with `-enable-testing` (separate scratch path
`build/swiftpm-test-release`): 3323.9 s, the whole-catalog test 3293.3 s. A
debug run of that test was stopped after 3 h, still in catalog loading.

Demo afterwards (the Demo script above, 50,000 bodies, 23 matches, footprint
sampled every minute for 27 minutes): no stop; footprint 2.0 GB at every
sample, RSS +4 MB per minute (4.20 → 4.31 GB), logical heap +≈120 KB per
match.

EXE envelope not recalculated.
