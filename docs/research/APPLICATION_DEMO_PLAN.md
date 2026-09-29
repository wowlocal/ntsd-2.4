# Demo mode in the app — plan

2026-09-29. Parent: [War](APPLICATION_WAR.md) (4651853). The modes survey's
Demo run stops at iteration 229 with "Match selection: Other mode selection
continuation": selecting Demo sets menu 2 and 450c2c = 1, and the ported
selection continuation accepts only modes 0/1/4 with 450c2c = 0.

Static reading:

- 429e5e: mode 5 with 450c2c = 0 goes to menu 10; with 450c2c = 1 the
  character screen runs its normal path (menu 2 → 4512c8 = 3), so the first
  call reaches computer selection and the settings screen with no humans.
- 42ba84: the computer loop uses a signed `jle` on 44d070, so the −100
  sentinel draws none (the port rejected counts outside 0..8).
- 42cf6c → 42d789 (no confirmation) → 42d795: the Demo start (450c2c = 1) —
  already recovered and compared in [MATCH_CONTINUATION](MATCH_CONTINUATION.md),
  but only with music off (44d010 = 0) and bitmap-input arena layers.
- 4025d0 (only caller 42d7a1) reads its track from its own `push ecx` slot:
  ECX at entry, the residue of the preceding text call (lib.dll's 401290
  replacement, ending in DirectDraw GetDC/ReleaseDC). 0 → RNG tag 2 over 8
  (+1); 1..8 → copy a bgm path into 44eed0; other values keep 44eed0; then
  4025b0 plays 44eed0 if non-empty. Music off returns at once.
- The Demo ends when, 144..350 bodies after a match is decided (450bdc), one
  of seats 0..7 presses Attack or Jump (41e1a0..41e1ca: 450c2c = 0), after
  which 44d020 = 2 leads back through 429e5e to menu 10.

Stages:

1. Oracle `tools/oracle_demo_music.py` (EXE image only): 4025d0 over music
   on/off, tracks 0 (RNG states), 1..8, other values and prior paths; port
   `OriginalMusicPlayback.selectDemoTrack`; test.
2. Core: allow (mode 5, 450c2c = 1) in the selection continuation and mode 5
   in computer selection with counts ≤ 0 drawing none; `continueMenu` takes
   `OriginalDemoStartProviders` (4025d0's ECX, 4025b0 play, arena layers with
   surfaces) and keeps its earlier contract without them.
3. App: the loaded menu session supplies the providers; the runtime declares
   the ECX residue (policy below). App run, e2e `demo` scenario.

Declared runtime policy: the ECX residue is unknown on Windows; the app uses a
value outside 0..8 (E_FAIL, its own GetDC result), so the configured track
plays and no RNG draw is taken. A Windows check would settle it.

EXE envelope not recalculated.
