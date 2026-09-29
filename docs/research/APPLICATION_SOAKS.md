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

EXE envelope not recalculated.
