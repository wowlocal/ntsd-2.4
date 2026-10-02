# Catalog checksum: the decoder's lost final character

2026-10-02. Found by the [replay cross-play](CROSSOVER_REPLAY_CROSSPLAY.md)
(on `work/goal-100`): the original rejected every recording of the Mac app,
and the app rejected every recording of the original.

## Finding

Every recording stores the catalog checksum 44f620 at +0x744. Playback start
(4326c7) rejects a mismatch with "data files ... different from yours".

| Program | 44f620 |
| --- | --- |
| Original (its recordings; read live with `winedbg` under CrossOver) | `0x1ec3356` = 32 256 854 |
| Port before this change | `0x1e046b2` = 31 475 378 |

The values were compared in the running original. The method:

1. A diagnostic clone of the game copy with one byte changed: .data 44d010 =
   0, the music flag, which the EXE only reads. The music error box therefore
   never blocks the main thread. The EXE in the verified copy is untouched.
2. START is clicked by writing the menu's cursor and click words (4546f0,
   453cdc, 457580) with `winedbg`. No window input is needed.
3. A `winedbg` breakpoint at the object loader (40ef70) gives the running
   checksum before each of the 137 objects. It is compared with the port's
   running checksum per child (`OriginalLoadedCatalog` onChild).

The two agree before the first object (2654). After that the original is
ahead by exactly 5239 per object; 5239 is the outer-token sum of
`<frame_end>`. The remaining gap, 63 733, is 17 × 3749, and 3749 is the sum of
`layer_end`, the last token of each background file. In total:

31 475 378 + 137 × 5239 + 17 × 3749 = 32 256 854.

So the original counts the last structural token of every DAT once more.

## Cause

4148a0 decodes a DAT into `data\temporary.txt`:

1. `fopen(path, "r")`, then 123 header characters through `fscanf("%c")`.
2. A loop: `fscanf("%c")`, then `feof`; if not at end, subtract the key and
   `fprintf("%c")` the result.

The temporary file was copied from the paused original right after 4148a0
returned, for the first three objects. Each copy equals the port's decoded
text except that it is one byte shorter: the final source character is
missing. VC80's `fscanf("%c")` reads one character ahead and pushes it back.
At the last character that lookahead meets end of file, so `feof` is already
true and the loop ends before decoding the character it has just read.

Every catalog DAT ends with an unencrypted CRLF. Read in text mode, that
becomes one LF, which decodes to a garbage byte. The port kept that byte as a
one-character token (sum 0). The original drops it, so its loader meets end of
file after `<frame_end>\r\n`, `fscanf("%s")` assigns nothing, and the loop adds
the unchanged token again.

The six DATs without the CRLF tail are not in `data.txt`. Their files cannot
tell "the last character is always dropped" from "only with a CRLF tail";
the lookahead explains both.

The Windows recordings in the distribution (2026-03-31) carry the same
checksum as CrossOver (Wine) recorded and computed. Real VC80 and Wine's
msvcr80 agree here.

## Change

- `OriginalLoadingFiles(translation:scanfLookahead:)` and
  `OriginalDATDecoder.decode(…, scanfLookahead:)`: with the lookahead the
  decoder stops before the source's final character. In the file session this
  is the lookahead read itself (`scannerAccess`) followed by the end-of-file
  test.
- `OriginalApplicationCatalogSession.Resources.scanfLookahead` is a declared
  runtime policy. `OriginalMacRuntimeLoading` turns it on. The default stays
  off: the earlier catalog corpora declared the decoder without the
  lookahead, and their comparisons are unchanged.
- e2e `playback` now plays a recording the original wrote
  (`downloads/NTSD_2.4_2.0a/…/20260331_012329_VS.lfr`). The earlier Mac
  recording carries the old checksum and is rejected, as in the original.

## Tests

`OriginalCatalogChecksumTests` loads the app's own catalog package through
the owned file session the app uses:

- with the lookahead, 44f620 = `0x1ec3356`;
- without it, the earlier 31 475 378;
- the decoder and the file session drop exactly the final character.

## Result

Recordings are now interchangeable in both directions without changing a
byte ([evidence](../evidence/application-catalog-checksum.json)):

- **Mac → original.** A VS recorded by the fixed app carries `0x1ec3356`. It
  differs from the pre-fix recording only at +0x744..+0x746. The original
  under CrossOver accepted it as it is and reached the same Summary (P1
  1/985/780/275/0, P2 0/30/960/0/0, Com 1/1270/545/1165/6, 00:54).
- **Original → Mac.** The e2e `playback` scenario plays the original's
  `20260331_012329_VS.lfr`. The app reaches the same Summary as the original
  (P1 1/630/725/305/0 Win, Com 0/725/630/250/3 Lose, 00:59).

e2e with the fixed build:

- vs, mission, war, tournament, altenter, tournament-win and team-tournament
  differ only in the saved recordings: their hashes, and in the tournaments
  the `replayFiles` sizes (±1–3 compressed bytes). Those fields are updated.
- demo and joystick are unchanged.
- playback was re-recorded for the new input.

The catalog corpora suites are unchanged, because their default is the
declared decoder: `OriginalApplicationCatalogSessionTests`,
`OriginalApplicationCatalogFullTests`, `OriginalLoadedCatalogFilesTests`,
`OriginalLoadedCatalogTests` and `OriginalCatalogPrecisionTests`, all in the
release test build.

Open:

- Windows itself was not observed, only Wine and the Windows-made
  recordings' checksum.
- The catalog corpora still compare the decoder without the lookahead.
  Regenerating them with the observed decoder is a separate task.
