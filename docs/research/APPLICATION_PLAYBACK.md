# Playback Recording in the app

2026-09-29. [Plan](APPLICATION_PLAYBACK_PLAN.md). Parent: [Demo](APPLICATION_DEMO.md)
(6c384fc). Author implementation and machine checks; independent review open.
The original was executed only in Unicorn oracles.

## P1 — the loader 43e620

`OriginalReplayFileInput.load(file:globals:)` ports 43e620 over supplied file
bytes: 44d030 = 1 and 450b74 = 0; the recording buffer (0x630e18) is
allocated first; a file that does not open → −1; fewer than 1000 bytes → 0;
a 4-byte length n, an n-byte payload read up to the end of the file (the
rest zero); the writer's key undone on the first min(n, strlen(44d7a0)) bytes
(byte − key + 0x30; the key is 1345 bytes); zlib 1.1.4 `uncompress` with
capacity 0x631200; anything but status 0 and exactly 0x630e18 bytes frees both
buffers → 0; success frees the payload and keeps the recording for 4588ac → 1.
Allocation, free and close order are reported for the caller.

zlib 1.1.4's inflate (and `uncompress`) is vendored unchanged from the same
pinned archive as the compressor (`upstream.json`), under the codec's private
symbol prefix. `ntsd_replay_codec_uncompress` repeats `uncompr.c`'s body and
also reports the bytes produced on failure.

**Overflow, reported.** For truncated or corrupted files the original's
inflate fills the capacity it was given (0x631200) although the allocation is
0x630e18 bytes: it writes 1000 bytes past its heap block, then returns 0. The
port returns the same 0 and reports `overflowBytes` (1000) instead of
modelling Windows heap memory it does not own.

**Oracle** `tools/oracle_replay_loader.py`: the real 43e620 with the EXE's own
zlib, the pinned MSVCP80 `ifstream` and MSVCR80 stdio; calloc/free recorded,
descriptor 3 `_read`/`_lseek`/`_lseeki64` answered from the supplied file,
writes past the recording allocation counted. Inputs: three recordings written
by the app (VS, War, Mission Stage 1) and declared variants (another or empty
key, truncated, one corrupted byte, shorter/longer length prefix, trailing
bytes), a missing file, a tiny file and a zero length — 27 cases, 9 loads.
[Evidence](../evidence/playback-loader.json).

**Comparison:** `OriginalReplayFileInputTests` rebuilds every variant from the
base recordings and matches all 27 cases: status, 44d030/450b74, the recording
bytes, allocation order and sizes, frees, the file close and overflow bytes.

**Codec, debug builds.** SwiftPM defines `DEBUG=1` for C in debug builds, which
enabled zlib's debug-only `deflate_state` fields (5936 instead of 5920 bytes)
and its Assert/Trace code; `OriginalReplayWriterTests` had been failing on that
in debug test builds. The codec's prefix header now undefines DEBUG, and the
compression, stream, writer and loader tests pass (4/4).

## P2 — the playback start 43dfa0 and its checks

`OriginalReplayPlayback.prepare` ports 43dfa0(0x451160, World+4, World+0x194,
catalog):
- saves the difficulty (byte), names and three strings to the backup area
  458588..4588a8 (the `savedPlayback` record that the round logic restores);
- loads difficulty, hidden-character flags (old values into the recording at
  +0x630bb8/bc), stage, mode, names, strings and arena from the recording;
- clears all activity and rebuilds 18 seats (first Object with the recorded
  ID → constructor, 350/0/300 position, then team, activity, frame, x/y/z,
  MP, 354, HP ×3, 33c/344/340);
- clears 450c04..450c28, releases every background's layers, loads the
  recorded arena unless 99, copies the music path, War tables, RNG index and
  table, 44d324..44d34c and 450b90; plays 44eed0 unless the mode is Mission
  (then the Mission globals reset);
- reconstructs every inactive Actor and copies teams from seats 10..17 to
  empty seats 0..7.

`OriginalReplayPlayback.start` ports the caller's checks: the data checksum
(+0x744 vs 44f620) and version (+0x748 vs 44d03c), each a MessageBoxA text
with 450b88/450b84 cleared and mode 6; otherwise the War settings in +0x8c0
(the last divisor is EBX = 100, set at 432355 by the mode confirmation before
any mode check) and menu 0. `loaderMessage` gives 43e620's two error texts.

**Oracle** `tools/oracle_replay_playback.py`: the real 43dfa0 after the
verified first loading (main CW027f, control CW037f), 4588ac pointing at the
decompressed app recordings (VS, War, Mission Stage 1) and declared variants
(absent Object IDs, arenas incl. 99, modes 0/1/4/5, seat flags, per-seat
fields, War/RNG fields); 40c0e0/40c030/4025b0 are recorded boundaries; writes
to globals, the backup area and the recording are tracked.

**Comparison** (`NTSDCatalogCheck --replay-playback`, `OriginalReplayPlaybackTests`):
both corpora of 84 real calls match with exact bytes and masks — main 1564
callee calls and 33597 constructors, control 1565 and 33593; 33936 records,
584894016 bytes/masks each. Coverage: 76 of 80 static leaders (padding
43e0d6/43e3d5; 43e1d2 and 43e35b need an empty catalog or no backgrounds).
The War decode is checked against the writer's packing
(`OriginalReplayPlaybackStartTests`, round trip and both rejection texts).

EXE envelope not recalculated.
