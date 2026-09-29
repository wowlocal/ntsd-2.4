# Playback Recording in the app — plan

2026-09-29. Parent: [Demo](APPLICATION_DEMO.md) (6c384fc). Selecting Playback
Recording (mode 6) makes the mode screen return `.playback` (stop before
43249c); the Host has no continuation for it ("unreturnedLoading").

## Static reading

43249c (inside the menu function): 431c70 (input reset), Sleep(300), zeroed
OPENFILENAMEA (0x58 bytes) with filter "LF2 recording files (*.lfr)\0*.lfr;
*.txt", initial directory `<_getcwd()>\recording`, flags 0x1804, then
GetOpenFileNameA. Cancel → back to the menu. Otherwise `_chdir` back to the
saved directory, 43d280(4588ac) frees a previous playback buffer, and:

- a name ending in `.txt` (case-insensitive) → ShellExecuteA(open) and back;
- otherwise 43e620(path):
  - 44d030 = 1, 450b74 = 0; calloc(1, 0x630e18);
  - `ifstream(path, binary)`: not open → −1; seekg/tellg size < 1000 → 0;
  - read a 4-byte length n, calloc(1, n), read n bytes, close;
  - undo the writer's key on the first min(n, strlen(44d7a0)) bytes
    (byte − key + 0x30);
  - 43f4d0 = zlib 1.1.4 `uncompress` into the buffer with capacity 0x631200;
    anything but result 0 and length 0x630e18 frees both → 0;
  - success: 4588ac = buffer, free the payload → 1.
- 0 / −1 → MessageBoxA (449c80 / 449c30) and back.
- 1 → 43dfa0(mode, World+4, World+0x194, catalog) prepares the match from the
  recording; version checks (+0x744 vs 44f620, +0x748 vs 44d03c) show a
  formatted MessageBoxA and clear 450b88/450b84, mode 6; otherwise the War
  settings are decoded from +0x8c0 (displays, strengths, multipliers) and the
  menu goes to 0 (playback match).

## Stages

- **P1 — loader 43e620.** Vendor zlib 1.1.4's inflate (same pinned archive as
  the compressor) into NTSDReplayCodec; port the loader over supplied file
  bytes. Oracle: the real 43e620 with MSVCP80 ifstream/MSVCR80 and the EXE's
  own zlib, over recordings written by the app plus declared variants (missing,
  short, truncated, corrupted, other key, wrong size). Compare result, buffer
  bytes, globals and frees.
- **P2 — playback start 43dfa0 and the checks/decoding above.** Static reading,
  a direct-call oracle after the verified first loading, port, corpora.
- **P3 — app.** GetOpenFileNameA through an open panel on the recording folder
  (a script action supplies a path for automated runs), MessageBoxA as an
  alert, `.txt` through the system's default opener; Host continuation for the
  playback outcome.
- **P4 — playback gameplay.** Record a VS match in the app, play it back, and
  compare the replayed match with the recorded one.

EXE envelope not recalculated.
