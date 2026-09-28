# Special-move selector 403a40 for every character

2026-09-28. Parent: [end of the District match](APPLICATION_MATCH_END.md)
(0a77527) and [character AI](APPLICATION_CHARACTER_AI.md). Author
implementation and machine checks; independent review open. Planned in
CURRENT_WORK as the next task after the milestone: computer-controlled
characters stopped at an explicit boundary whenever their own-id block in
403a40 was reached.

## Result

`OriginalCharacterAIPass.special` now covers all 20 own-id blocks of 403a40
(ids 1, 2, 4..11, 32..36, 38, 39, 50..52; others fall through to 0). The
blocks live in `OriginalCharacterAISpecial.swift`; the former
`unrecoveredSpecialMoveIDs` boundary is removed.

- **Comparison:** the character-AI corpora were re-captured with a new
  `special` family (4000 calls: every character with a selector block as
  owner, level 0 so the entry roll always enters the selector, thresholds for
  distance, chakra, health, target state, frame windows, target height and
  teammates). Two corpora of 7770 real 4094b0 calls (CW027f legacy; CW037f
  SSE2) match Native on the first comparison: 36176/36317 RNG draws, 3123540
  records and 3656189040 bytes/masks per corpus, no undefined reads.
  `OriginalCharacterAITests`: 2/2 in 314.1 s.
  [Evidence](../evidence/application-special-moves.json).
- **Coverage:** 1643 executed blocks overall; 403a40 543/580, 4034f0 79/79.
  Unexecuted selector blocks are specific combinations: Sakura's second roll
  with both fighters airborne and her jump branch, Pein's attack at target
  frames 263/264, the left-side heal walk and its facing tests, Naruto's
  third range test, a few rolls of Sai, Shino, Rock Lee, Chiyo, Sasuke,
  Deidara, Tayuya, Sasuke CS2 and Kyubi. In 4094b0/408cb0 the heal-ball choice
  and the 0xd8/0xd9 weapon command for owners 2/34 (not stimulated), plus the
  previously classified unreachable blocks.

## Decode notes

- Every block rolls the game RNG with its own tag, tests distance, chakra
  (+0x308), health and target state, then either stores 3 in one command byte
  (+0xd4..+0xdc) and returns 1, presses buttons, or falls through to 0.
  Compiler-merged tails ("store 3, return 1") are shared across blocks.
- Quirks kept as in the EXE: Sasuke/Deidara return 1 without a command when
  facing left at a target on the left; Tayuya returns 1 after scanning slots
  0..99 for a wounded teammate even when none qualifies; Kyubi's claw branch
  returns 1 even when the target is not on the right; Hsasori's jump press,
  Rock Lee's z steering and Deidara's 0xdb/0xda stores do not end the call.
- Naruto and Kidomaru share the heal-a-teammate walk (slots 0..19, wounded
  below max−90/140 or 3/5, within a third of the nearest-enemy distance).

## Remaining

VS with computer players in the app (menu path not yet scripted), GDI text,
music output, other arenas, automated end-to-end test, device/Windows
acceptance. EXE envelope not recalculated.
