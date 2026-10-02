# Replay cross-play between the Mac app and the original under CrossOver

2026-10-02. [Plan](CROSSOVER_REPLAY_CROSSPLAY_PLAN.md), [evidence](../evidence/crossover-replay-crossplay-20261002.json).
Parent: [GOAL_100](../GOAL_100.md) P1b.

## Result

Nine whole matches were played in both programs: five recorded by the Mac app
and four recorded by the original. In every match, every Summary row of every
player and the match time are equal. The scenes at the Summary (bodies, items,
positions) also look the same in the captures. This is the first check of
whole-match equivalence rather than of single functions.

At the time of the comparison the recordings could not be exchanged as they
are: each program rejected the other's files because the catalog checksums
differed (see below; now fixed). The comparison used copies in which only that
field was changed.

| Recording | Written by | Mode | Time | Result |
| --- | --- | --- | --- | --- |
| `20260101_010000_VS` | Mac app | VS, 3 players | 00:54 | equal |
| `20260101_010000_Battle` | Mac app | War | 01:19 | equal, including team totals 17/2640 and 5/6705 |
| `20260101_010000_Stage_1` | Mac app | Stage 1-1 | 00:45 | equal |
| `20260101_010000_1on1_Prelminar` | Mac app | 1 on 1 | 00:29 | equal |
| `20260101_010000_2on2_SemiFinal` | Mac app | 2 on 2, 4 players | 00:52 | equal |
| `20260927_093914_VS` | original (CrossOver, 2026-09-27) | VS | 00:47 | equal |
| `20260331_115445_Stage_1` | original (distribution) | Stage 1-1 | 00:37 | equal |
| `20260331_115533_Stage_1` | original (distribution) | Stage 1-1 | 00:58 | equal |
| `20260331_115752_Battle` | original (distribution) | War, 8 players | 01:16 | player rows equal; team totals see below |

Each original-side Summary is kept as a capture in
`docs/evidence/crossover-replay-crossplay-20261002/`; the evidence file lists
all values and the Mac captures.

**War team totals carry over between playbacks, in both programs.** For the
last recording the original showed Team 1 29/13043 and Team 2 18/18518. The
Mac app showed 12/10403 and 13/11813. The difference is exactly the earlier
War playback of the same original session (17/2640, 5/6705). The counters
451b64..451b70 are zeroed only by the War setup screen (438dab..438dbd;
`OriginalWarSetup`), and playback skips that screen in both programs. The Mac
run was a fresh session. A two-playback Mac session was not run, because
`--playback-file` answers one dialog.

## Catalog checksum: recordings are not interchangeable

Every recording stores the catalog checksum 44f620 at +0x744. Playback start
(4326c7) rejects a mismatch with "Recording file are recorded in a LF2 with some
data files (character or stage files) different from yours".

- **Original:** `0x1ec3356` (32 256 854). All four original recordings carry
  it, and `winedbg` read the same value from 0x44f620 in the running original.
- **Port:** `0x1e046b2` (31 475 378). All Mac recordings carry it. It is what
  the port's loader computes over the distribution files. The Unicorn catalog
  oracle (the EXE's own loader) gave the same value, and 31 461 560 with raw
  file reads.
- **Consequence:** the original rejects every Mac recording. The Mac app
  rejects every original recording, including the three that ship with the
  game (`crossplay-mac-playback/origvs-unpatched`).

What is excluded so far:

- **Data.** The app's catalog package equals the distribution byte for byte
  (1194 files; the four built-in bitmaps are EXE resources).
- **Writers.** Only the three loaders write 44f620: BG at 40c2a6, objects at
  40f1a6, registry at 4125c6. 41cb7a..41d267, 4326d8 and 43d989 only read it.
  lib.dll has no reference to it. The initial value is .bss zero.
- **Parsing.** An independent Python model of the outer-token sums matches the
  port exactly for all 137 objects.
- **Decryption.** 4148a0 opens the DAT with "r" and `data\temporary.txt` with
  "w", which is the port's text model.
- **Contents.** The decoded DAT text is plain ASCII (no NUL, 0x1A or high
  bytes). The only encrypted CRLF pairs are the trailing two bytes of 178 files.
  They account for the text/raw difference of 13 818, not for the gap.
- **Locale.** `setlocale` is not imported.

**Resolved 2026-10-02** ([catalog checksum](APPLICATION_CATALOG_CHECKSUM.md), on
main). With START set in memory and a `winedbg` breakpoint at the object
loader, the original turned out to be ahead by exactly 5239 (`<frame_end>`) per
object and 3749 (`layer_end`) per background. Its DAT decoder 4148a0 loses each
file's final character to VC80's `fscanf("%c")` lookahead, so the loader counts
the last token twice. The app now models this. A fresh Mac recording plays in
the original as it is, and the app plays the original's recordings, with equal
Summaries.

## Method

- **Game copy.** The original runs under CrossOver 26.3, bottle `NTSD24XP`, on
  an APFS clone of the verified copy. All 1595 files were re-verified against
  `game-copy1.json`.
- **Patched copies.** Made with `tools/lfr_checksum.py patch`. The decoded
  recording differs only at +0x744..+0x746; the file is recompressed and
  re-keyed.
- **Mac side.** The Mac recordings and their Summaries come from
  `tools/crossplay_replays.py` (virtual clock 123456789, the e2e scripts).
  Original recordings were played with `--playback-file` and body captures.
- **Driving the original.** Cua Driver 0.32.0 does it without the user, and
  `winedbg` reads and writes its memory (`tools/crossover_drive`):
  - window screenshots;
  - a background click to place the game's own cursor, then a foreground click
    at the same point;
  - menu keys held for 150 ms through `CGEvent.postToPid`, because Cua's
    instant key press is missed by the game's per-frame key state;
  - OK on the "Could not create a filter graph" music error that CrossOver
    raises at each music start.
- **Incident.** An early helper selected windows by title and sent two J
  presses and two clicks to the parallel agent's NTSDNative network-match
  client (2026-10-02 18:09:42–18:10:05 UTC, run `network-app-match-20261002/match2`).
  It is recorded there (`EXTERNAL-INPUT-INCIDENT-20261002T1809Z.md`). The
  helper now accepts only windows of `NTSD 2.4.exe`.

## Limits

- Wine is not Windows. Only gameplay outcomes are compared, never fonts,
  sound, timing or heap-dependent answers.
- Summary values were read from captures by eye; the evidence lists them.
  Tick-by-tick state was not compared.
- Every recording reaches its Summary in both programs. The 1on1 and 2on2
  recordings cover only the human's match of each tournament.

EXE envelope not recalculated.
