# Stage ENDING screen (menu 300, 437220)

2026-10-02. [GOAL_100](../GOAL_100.md) P0a: after the last Stage group the
stage logic writes menu 300 (`OriginalMissionStage.setTail`, compared in the
Mission corpus). Until now the port stopped there at "Other menu dispatcher".
The original is not executed for this card; 437220 runs only under Unicorn.

## What the screen does

429730's dispatcher calls `437220(target, &menu, unused)` on the World for
menu 300 (429e7a..429e91), then the common tail at 42e0d2. One call draws one
frame:

1. 451b2c = (451b2c + 1) mod 10, signed (`idiv`).
2. The page is 451b28. With 450c30 = 1 or 2 a page 1 becomes 2. Otherwise a
   page 0 becomes 1. So these two levels show frame 0 and skip frame 1; the
   others skip frame 0.
3. The page is drawn from the ENDING sheet (global 451190) with 43f010
   (color key 0), centred on (800, 520): x = (800 − w)/2, y = (520 − h)/2, each
   rounded toward zero. Frames are 402×66, 402×91, 402×156, 419×169, 419×65,
   and a 15×13 arrow (424b45..424c98).
4. Opening: while 451b24 < 13 it is incremented, and thirteen 794-wide black
   bands are filled through 415160 from y down, 13 apart, each
   13 − 451b24 high.
5. Then, with 451b20 = 0, the first seat (0..7) whose key byte +0xd1 is set
   while +0xca is clear sets 451b20 = 1. With 451b20 > 0 the bands are drawn
   451b20 high and 451b20 grows. At 13 the page advances, and 451b24 and
   451b20 are cleared.
6. While 451b2c < 5 on a fully open page, the arrow (frame 5) is drawn at the
   page's lower-right corner (x + w, y + h). It blinks with the counter.
7. When the page reaches 5, menu = 10, 451b28 = 451b24 = 0, 431c70 resets the
   input (in the port, `OriginalMatchPreparation.resetOriginalInput`), and
   457580 = 0.

## Port

- `OriginalStageEnding.advance(state:target:ending:observe:)` reproduces
  437220. It reports draws, fills and the input reset, and it runs the reset
  itself.
- `OriginalCharacterScreen` dispatches menu 300 to it, after the dispatcher's
  first test (mode 5 with 450c2c = 0). Draws go through the screen's draw
  closure (`.menu(451190)` with the frame), fills through
  `OriginalSurfaceFilling` on 455608, and the tail checkpoint is 42e0d2. The
  app reaches this through `OriginalMatchSelection`.
- The ENDING frame arrays are read from the static PE constants that
  424b45..424c98 store at startup (`OriginalStageEnding.endingSheet`). No
  other writer of those fields is known.

## Comparison

`tools/oracle_stage_ending.py` runs the real 437220 and 431c70 under Unicorn
2.1.4 on declared inputs:

- the EXE's own .data;
- the ENDING wrapper with the static frames;
- eight seat Actors with key bytes;
- the counters, over levels −1..3, pages 0..5, open/close/blink values,
  six key patterns and edge values;
- 431c70's targets and the Actors filled with 0xA5, so every reset write is
  visible.

43f010 and 415160 are recorded calls; memset is performed.

`OriginalStageEndingTests` compares all 581 cases: the ordered 7171 calls with
their arguments (draw object, frame, key 0, no mirroring, target), every one
of the 39 186 written global and Actor bytes, and that nothing else is
written.

`OriginalStageFinaleTests` drives the whole finale through the dispatcher. Each
of pages 1–4 opens over 13 frames, a seat's Attack closes it over 13 frames,
and after the last page the menu is 10 with the input reset. Levels 1/2 start
at frame 0 and skip frame 1.

## Limits

- The live app has not reached menu 300 in a run. That needs a cleared Stage 5
  or a recording of one; the connection goes through the same dispatcher and
  draw path as the tested screens.
- No Windows raster: the ENDING pixels come from the same resource bitmap path
  as the other menu sheets.
