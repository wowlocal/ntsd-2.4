# All arenas in the app

2026-09-29. [Plan](APPLICATION_ARENAS_PLAN.md). Parent: [packaged app](APPLICATION_PACKAGING.md)
(623845f). Author implementation and machine checks; independent review open.
The original was not executed.

## Result

Every background registered in `data/data.txt` (ids 0..16) and "Random" can
be chosen in the app's VS start menu; each match launches with its own
deferred layers and plays (computer player, 300 bodies, no boundary).
[Contact sheet at tick 300](../evidence/application-arenas-capture.png).

- `tools/package_match_arenas.py` (data only) packages every BMP of the 17
  registered background folders: 228 files, 63.3 MB, all 24- or 8-bit
  uncompressed, into `OriginalMatchArenas` in the earlier manifest format;
  verify mode re-checks without rewriting. District's 13 files are
  unchanged. The BMPs now go through LFS.
- `OriginalApplicationArenaInputs.manifestSHA256` pins the new manifest
  (`60652ed8…`). No game logic changed: CastleRoof, which stopped at an
  undeclared bitmap file before, and every other background needed only
  their files.

## Checks

- App (release, `--virtual-clock 123456789 8`, `--mute-music`, temporary
  overlays): per background, the computer-VS menu path with the Background
  option confirmed k+2 times, then Fight; all 18 runs reach 300 bodies; the
  17 captures of ids 0..16 are pairwise different (each background once);
  Random chose id 0 under this clock (capture byte-identical to District's).
- `tools/app_e2e.py`: pass (District match unchanged).
- `OriginalApplicationLoadedLaunchTests`: 2/2 in 808 s.

Menu text (the Background value) is still GDI text and blank. EXE envelope
not recalculated.
