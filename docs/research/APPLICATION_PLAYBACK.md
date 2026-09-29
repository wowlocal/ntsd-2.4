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

## P3 — the playback branch in the app

`OriginalModeScreen` takes an optional playback composition: where it stopped
before 43249c it now runs the branch and continues its own tail (4328db), as
the original does. `OriginalApplicationLoadedMenuSession` composes 43249c..
4328cc: 431c70 input reset, Sleep(300), GetOpenFileNameA, 43d280 on 4588ac, a
`.txt` choice through ShellExecuteA, the loader, 43dfa0 with this session's
arena-layer surfaces and music owner, and the checks; messages go to
MessageBoxA. The recording buffer is a runtime heap allocation owned by the
presentation memory at 4588ac; the backups become the session's saved-playback
record (stored at 0xb588 of the full state).

The Mac runtime provides those services: `--playback-file PATH` answers the
dialog once; interactive runs show an open panel on the overlay's
`recording` folder (`*.lfr`, `*.txt`), an alert titled "Error" for
MessageBoxA (Windows' caption for NULL) and the system opener for `.txt`;
scripted runs record alerts and never show panels. The app reports
`playbackDialog` and `playbackAlert` events.

**App:** main menu → Playback Recording with the VS recording: the recording
loads, the match is rebuilt and the checks pass (menu 0); the next tick stopped
at 41bd24's playback prologue (then unported; see P4). A damaged file shows "Loading error!  Recording file may be
corrupted!!", a missing file "File path error! …", and a cancelled dialog
returns to the mode screen with Playback Recording highlighted.

## P4 — playing a recording

**Prologue 41bd24..41bdce.** While a recording plays (450b84), each tick's
prologue in `OriginalInitialLoading.begin` now runs the playback controls
instead of refusing: F6 (key byte 0x75 'd') toggles 44d030 (the time/mode
information) and resets its key byte to 'u'; Left/Right take the playback
camera (450b74) from the following camera (x 450bc4, speed 450bc8) and steer
it by ±5; Down gives it back; while taken, its x 450b7c advances by the speed
450b78, which decays to 6/7 (signed 32-bit, x86 division). The camera step
itself was already in `OriginalWorldCamera`.

Oracle: `tools/oracle_playback_prologue.py` runs the real span over the pinned
EXE image in Unicorn 2.1.4 (it touches only globals and restores ESI from its
frame): 600 cases over the key bytes ('d', 'u', 0, other), 44d030, the camera
words (including wrap-prone values) and 450b84 = 0; 49 blocks. Every stored
word, key byte and write span matches (`OriginalPlaybackPrologueTests`,
[evidence](../evidence/playback-prologue.json)).

**Runtime.** The playback indicator (41bc90 → 423a70 frame 24 at 67,534, the
key help bar) draws to root SP+0x68, stored at 41bce4 from 41bc90's own
argument — the body's draw target, now passed as the gameplay Caller's
`indicatorTarget`. The shared hotkey bodies 416c70..416fad (416cd0 is F4's quit)
report `.action`, `.restorePlayback` and
`.inputReset` notices whose effects Core performs; the Mac runtime answers them
without platform work. Their sound requests (416c70/416ca0) remain an
unserved boundary. Scripted runs that reach a boundary now exit (code 1)
instead of showing a modal alert.

**Comparison.** `tools/compare_playback_gameplay.py` records the e2e
computer-VS match on the release app, then plays that recording back through
Playback Recording and quits it with F4. Body captures 300, 600, 900, 1200
and 1500 are pixel-identical above window row 500; the only differing pixels
(window y 510..548) are the playback indicator — the key help bar and the
"00:50 / 00:54 … VS mode (Difficult)" information. Once the match is
decided and its timer 450bdc reaches 101, the result code
(`OriginalResultRecording`) clears 450b84; the indicator goes and body 1800
(the Summary) is identical in full. F4 then runs 416cd0 (mode 6, the saved
settings restored from 458588.., menu 10): the main menu returns with
Playback Recording highlighted (gameplay body 2121, no boundary, no new
recording written). [Evidence](../evidence/playback-gameplay.json); both runs
are Native — this checks playback against the recorded match, while the
routines it runs were each compared with the original before.

**E2E.** `tools/app_e2e.py --scenario playback` replays the VS scenario's
recording (carried by the loader fixture, SHA-256 2e98755f…) and quits with
F4; its reference (`tools/app_e2e_playback_reference.json`) holds the
dialog answer, the menu return, seven body captures and the final main-menu
capture. The existing vs, mission, demo and war scenarios still pass. The
recording's track (`bgm\boss1.wma`) keeps playing on the main menu after F4:
neither 416cd0 nor the mode screen plays music; this path's music is not
compared with the original separately.

**Tests:** `OriginalPlaybackPrologueTests` 1/1; with the initial-loading,
replay (file input/output, initialization, tick, playback, writer,
compression), playback-information, input-control, gameplay body/control,
initialized-gameplay, loaded-menu, Mac runtime-loading, display-backend and
front-raster suites: 40/40 pass.

EXE envelope not recalculated.
