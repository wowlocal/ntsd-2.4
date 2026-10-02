# RLE holes in the startup bitmaps

2026-10-02. The user saw a black box under the "Com" label in the native app
(screenshot from a match). The original under CrossOver draws the same label
with no box. The original is not executed for this fix; the CrossOver
observation comes from the replay cross-play trial
([plan](CROSSOVER_REPLAY_CROSSPLAY_PLAN.md)).

## Cause

The labels are not GDI text. "Com", "P1", the life counter and the Summary
names are drawn with the bitmap fonts `WORDS0`..`WORDS5`, embedded RLE8
resources of the EXE (globals 44faf4, 44f888, 44fcbc, 44fb68, 44faf8, 44fd80;
`OriginalWorldDrawing`, `OriginalResultLayout`). Each glyph sits in a black
(palette index 0) cell, and each Blt uses the source color key [0, 0].

An RLE8 stream does not write every pixel. End-of-line, delta and end-of-bitmap
escapes leave "holes": 20,800 to 21,187 pixels in each `WORDS` bitmap and 101
in `LF2_CURSOR`. No other RLE bitmap in the distribution has holes (the only
RLE file, `sprite/sys/nckakuzu_water.bmp`, has none). Every bitmap with holes
has palette entry 0 = black.

The accepted decoder (`OriginalDIBPixels`, [DIB inputs](APPLICATION_CATALOG_DIB_INPUTS.md))
keeps holes unknown, because the source does not fix their value. The app then
copied unknown pixels through the keyed Blt and presented them as black
(`presentUnknownAsBlack`). The glyph rectangles include hole rows, so a black
box appeared under and around the text.

## Windows answer

The original loads these bitmaps with `LoadImageA(..., LR_CREATEDIBSECTION)`
(0x2000 for resources, 0x2010 for files; `OriginalBitmapSurfaceLoading`), selects
them into a memory DC and StretchBlts them onto the surface. A DIB section
starts zero-filled and the RLE stream never writes its holes, so a hole reads
as palette index 0. Here that is black, which the [0, 0] key removes.

Observed under CrossOver (Wine, not Windows): the original's "Com", "P1" and
Summary labels have no box (cross-play captures of 2026-10-02,
`goal-100-20261002/cua-trial1`). This agrees with the zero-filled DIB section.
Windows itself was not observed; the answer stays declared.

## Change

- `OriginalDIBPixels.paletteZero`: palette entry 0 of an RLE8 DIB, as RGB. This
  is a source fact; holes stay unknown in the decoder.
- `OriginalMacDisplayBackend(rleHolesReadPaletteZero:)`: a declared live-app
  policy. The bitmap StretchBlt writes palette entry 0 at a hole as a known
  pixel. The default stays off, so the comparison tests keep holes unknown.
- `OriginalMacRuntimeStartup` turns the policy on for the app.
- Test: `OriginalMacBitmapBackendTests.testRLEHoleReadsPaletteZeroUnderTheLivePolicy`
  uses a blue palette entry 0, to tell it from black. Without the policy the
  hole stays unknown; with it, the hole is known and has the palette 0 color.

## Result

The box is gone ([before](../evidence/application-rle-holes-before.png),
[after](../evidence/application-rle-holes-after.png); War e2e capture, body
3000). The same change removes the black pixels around the cursor
(`LF2_CURSOR`).

Before/after check ([evidence](../evidence/application-rle-holes.json)):

- Two release builds of the same tree were compared; the only difference is
  the policy flag in `OriginalMacRuntimeStartup`.
- All ten e2e scenarios ran with both builds. The quit, website, controls,
  online and recording sub-checks were not run: they take no captures, and the
  online check opens sockets next to the parallel network runs.
- The baseline matches every existing reference.
- The two builds differ only in capture hashes. Progress, milestones, bodies,
  AI calls, inputs, music, overlay files and exit codes are equal.
- 64 of 70 captures changed. In every changed capture, every changed pixel
  was black in the baseline: the change only replaces boxes with what lies
  behind them.
- The 64 capture hashes in `tools/app_e2e_*_reference.json` are updated. No
  other reference field changed.

Tests: `OriginalMacBitmapBackendTests` (5), `OriginalMacDisplayBackendTests`
(4), `OriginalDIBPixelsTests` (3) and `OriginalCatalogDIBPixelsTests` (3)
pass.

Open: Windows itself was not observed. Comparison controls keep holes unknown.
