# Object input child 406ba0 in Native and the app

2026-09-28. [Plan](APPLICATION_OBJECT_INPUT_PLAN.md). Author implementation and
machine checks; independent review open. The original was executed only in the
Unicorn oracle (no Windows, no game window).

## Result

`OriginalObjectInput.apply(slot:state:observe:)` (NTSDCore) implements
406ba0 for every hit_Fa value that the original DAT gives non-character
Objects: 1, 3, 4, 5, 7, 8, 10, 12 and 14 (248 frames). The app's cached cycle
now serves `objectInput` requests with it; `characterAI` stays an explicit
boundary.

- **Comparison:** two corpora of 880 real 406ba0 calls each after the verified
  first loading (reproduced byte for byte in each VM): CW027f (startup
  precision) and CW037f over the control loading. Native matches every RNG call
  (tag, range, result), constructor slot, the globals, the World and every
  Actor byte/mask: 384/383 RNG draws, 215/218 constructor calls, 353760
  records and 414085760 bytes/masks per corpus. The oracle found no reads of
  undefined World/Actor bytes. [Evidence](../evidence/application-object-input.json).
- **Tests:** `OriginalObjectInputTests` (both corpora) and
  `OriginalMacRuntimeLoadingTests` (changed dispatch file): 4/4 in 298.7 s.
- **Coverage:** 308/309 executed body blocks. Of 403 static blocks, the
  unexecuted ones belong to the unused values 11, 13, 2 and 6/9, plus four
  blocks unreachable with the original data: Objects 225/219 or the own id
  missing from the catalog (three) and a hit_Fa-14 frame below 10 (none exist).
- **App (exploration, release):** three scripted District fights (time-seeded
  game RNG). Each served exactly one object-input request through the Native
  routine. The fight with special moves then stopped at the next boundary,
  character AI for a Naruto shadow clone (id 33, slot 56, iteration 2266); the
  two without specials ran 4755 and 4715 gameplay ticks (≈2.5 min of play)
  with items and NPCs and no boundary. Whether the earlier stop (id 219 at
  hit_Fa 5) is passed in the app was not reproduced; the corpus covers it.
  [Capture](../evidence/application-object-input-capture.png).

## Decode notes

- hit_Fa 5 spawns Object 219 for each living character on the *same* team,
  aimed by `(T.x − x)/50`; hit_Fa 4 then holds position near the target and,
  inside a 60×80×20 window, stops at frame 60 and sets the target's +0xe4 to 100.
- hit_Fa 7 spawns a copy of its own Object at frame 40 every call (a trail),
  then steers twice as hard along x and rises (+0.4 up to vy 4).
- Target search (1, 3, 12, 14): keeps a living enemy character that is not
  lying (state 14) and has |Actor+8| ≤ 2, else the nearest by |dx|+|dz|
  outside the team and the owner's team; no target sets the Object's HP to 0.
- All steering is x87 at the match precision; comparisons use the unrounded
  extended sums (for example `y + 40 < target.y`).
- 4/7 read the target without a search; a target of −1 would make the EXE read
  World+0x190 as an Actor pointer. Native stops there explicitly.

## Findings while checking

1. Unicorn leaves x87 registers tagged valid after reset (tag word 0xd555);
   QEMU ignores tags for overflow. The oracle declares an empty tag word before
   each call and requires it empty again with the same TOP afterwards.
2. The game RNG table (0x44ff90) is still zero after the first loading; it is
   filled at match start. Native `OriginalRandom` rejects a zero table, so the
   first round's corpora (which matched in a diagnostic run that skipped that
   check) were replaced: the accepted corpora declare a table built as 422ac0
   does (VC80 `rand()%255+1` from a declared seed).

## Remaining toward the milestone

1. **Character AI 4094b0** (≈2470 instructions plus the 408cb0 helper) for
   type-0 Objects in slots 10..399: clones, summons, computer players.
2. KO/result/return, automated match test, GDI text (font decision), music,
   other arenas, shutdown, device/Windows acceptance. EXE envelope not
   recalculated.
