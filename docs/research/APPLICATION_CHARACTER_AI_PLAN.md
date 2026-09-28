# Character AI 4094b0 for the runtime match

2026-09-28. Parent: [object input](APPLICATION_OBJECT_INPUT.md) (855e206).
Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md).

**Consumer and criterion:** the app's cached cycle serves `characterAI`
requests of `OriginalLocalInput` (type-0 Objects in slots 10..399) with a
Native implementation. **Proven blocker (parent card):** a scripted District
fight stops at character AI for a Naruto shadow clone (id 33, slot 56).
**Round:** 1. **Executor/reviewer:** Claude; independent review open.

## Static extent (no original code executed)

- 4094b0(World, slot, mode), ret 8: ≈2470 instructions. Button emulation on
  the Actor's current/previous button bytes (cd..d3 / c6..cc): walk-to-point
  (Actor+0x3fc/0x400), difficulty globals 44f604..44f61c, ally/health flags,
  enemy and projectile target search, item pickup (ids 1xx, 122, 123, 200,
  213), danger avoidance (211 state 18, 212 frames 150..170), approach, z
  alignment, defend/jump/attack decisions; 22 RNG calls; float→int through
  4450d0.
- 4034f0 (≈360, ret 0x1c) and 408cb0 (≈550, ret 0x18): attack and weapon
  helpers.
- 403a40 (≈2720, ret 0x1c): special-move selector, a chain of blocks keyed on
  the AI's own Object id (2, 1, 4..11, 32..36, 38, 39, 50..52) that set command
  bytes 0xd6..0xd9 and return 1, else fall through to "return 0".

## Scope of this card

Full Native port of 4094b0, 4034f0 and 408cb0. In 403a40: the entry roll, the
id-33 (naruto_clone) block with the shared tails it reaches, and the default
path for ids without a block. Blocks for the other ids stay explicit Native
boundaries (`outsideVerifiedDomain`), as do reads the EXE makes through the
catalog pointer (World+0x7d4 read as an Actor when no target exists and
Actor+0x404 is set) unless they are shown to be decided by any mapped pointer.

## Checks and limits

1. Unicorn corpus (extension of `oracle_object_input.py` machinery): verified
   first loading reproduced, a declared match-start RNG table, then direct
   calls of 4094b0 for real type-0 Objects (id 33 and ids without a
   403a40 block) on real frames, with declared allies/enemies, projectiles
   (state 3000), items (1004/2004 and ids above), lying targets, walk-to-point,
   difficulty/mode globals, CW027f and a CW037f control. Same oracle asserts as
   the object-input card.
2. Native comparison per case: RNG calls, globals (only RNG and 44f604..44f61c
   may change; anything else is reported), World and every Actor byte/mask.
3. Block coverage of 4094b0/4034f0/408cb0 and the in-scope 403a40 blocks.
4. App: scripted fight with shadow clones past the current stop.
Each run ≤ 3600 s. EXE envelope not recalculated.
