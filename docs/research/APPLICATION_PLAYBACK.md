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

EXE envelope not recalculated.
