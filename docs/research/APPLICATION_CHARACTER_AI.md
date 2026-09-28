# Character AI 4094b0 in Native and the app

2026-09-28. [Plan](APPLICATION_CHARACTER_AI_PLAN.md). Author implementation and
machine checks; independent review open. The original was executed only in the
Unicorn oracle.

## Result

`OriginalCharacterAI.apply(slot:mode:state:sse2:observe:)` (NTSDCore) ports
4094b0 with its helpers 4034f0, 408cb0 and 4061a0, and the special-move
selector 403a40 for its entry roll, the naruto_clone (id 33) block and the
fall-through. Owners whose 403a40 block is not recovered (ids 1, 2, 4..11, 32,
34..36, 38, 39, 50..52) stop explicitly when that block is reached; everything
else they do (idle, walking, items) runs. The app's cycle serves character AI.

*Update:* the remaining 403a40 blocks were ported afterwards; see
[special moves](APPLICATION_SPECIAL_MOVES.md). The fixtures were re-captured there.

- **Comparison:** two corpora of 3770 real 4094b0 calls each after the
  verified first loading: CW027f with the legacy float conversion, and CW037f
  over the control loading with the SSE2 conversion flag. Owners: naruto_clone
  (≈1380 calls), 20 ids without a 403a40 block and, in idle cases only, owners
  with unrecovered blocks; modes 0..4. Native matches every RNG call (tag,
  range, result), the nine written globals, the World and every Actor
  byte/mask: 7510/7800 draws, 1515540 records and 1773981040 bytes/masks per
  corpus; no reads of undefined bytes. The earlier rounds (1320 and 2770
  cases, replaced after coverage review) also matched on their first run.
  [Evidence](../evidence/application-character-ai.json).
- **Tests:** `OriginalCharacterAITests` (both corpora) and
  `OriginalMacRuntimeLoadingTests`: 4/4 in 339.6 s.
- **Coverage:** 925 executed blocks. Unexecuted in scope: paths only owners
  1, 2 and 34 reach (the heal-ball choice for 2/34, their dash/defend blocks in
  4034f0, the 0xd8/0xd9 command in 408cb0; deferred with their special moves),
  the milk pickup in state 1004 (no such frames in the DAT), the catalog-pointer
  x test (never reached under the pointer rule), one padding block, three
  rare RNG outcomes and a walk-point reset that needs off-arena coordinates.
- **App (exploration, release):** the special-move fight that stopped at the
  clone now plays on. In two runs Naruto's shadow clones fight Sasuke
  (2465 and 6285 character-AI requests, 0 and 519 object-input requests) until
  Sasuke is knocked out; the next stop is the end-of-match replay save
  (`Gameplay replay codec allocation`) at iterations 3694 and 4915.
  [KO capture](../evidence/application-character-ai-ko-capture.png).

## Decode notes

- The AI presses the Actor's buttons (current +0xcd..d3, previous +0xc6..cc);
  a special move is requested through command bytes +0xd6..d9 (value 3).
- Difficulty: level 0 when G450c2c=1 or, in mode 1, for a team-5-free Actor in
  slots below 20 or with an Object id below 30; else max(G450c30,0).
  G44f61c/618/614/610 = 3/5/15/20×level; G44f604 is the arena width.
- Targets: the nearest standing enemy or approaching projectile (state 3000),
  else a near lying/blinking enemy; a remembered target (+0x360) is kept with
  probability 29/30; items (ids 1xx, 213; states 1004/2004) and same-team
  healing balls (id 200 frames 50..59) can replace it.
- Mode 1 treats only team 5 as the enemy of other teams.
- With no target and Actor+0x404 set, the EXE compares the Actor's z with an
  Object pointer read through the catalog pointer (World+0x7d4 as Actor 400).
  Native decides "far", which any mapped Win32 address guarantees, and stops
  explicitly if |z| ≥ 0x8000.

## Remaining toward the milestone

1. End of match: replay codec buffer, processor signature, replay file
   output, music resume; then result screen and return.
2. 403a40 blocks for computer-controlled characters (Naruto 2, Sasuke 11, …).
3. GDI text, music, other arenas, shutdown, device/Windows acceptance. EXE
   envelope not recalculated.
