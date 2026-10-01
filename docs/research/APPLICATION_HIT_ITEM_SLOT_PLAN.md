# Plan: the hit pass's item word on a full pool

2026-10-01. Parent: [full-pool item plan](APPLICATION_FULL_POOL_ITEM_PLAN.md)
(its 2026-10-01 note) and [the requested-items word](APPLICATION_REQUESTED_ITEMS_SLOT.md).
CURRENT_WORK names this the next autonomous task after the user deferred
network play. Independence: no file here is touched by the uncommitted network
changes, and nothing executes the original. Task → missing result → milestone:
the random item drop on a full pool → whether the original crashes there →
the rest of the game (War, Stage with reserves). The original is not executed.

## Static reading

The hit pass's random drop (41ef55..41f276) stores a free slot in the body's
frame word [esp+4c] (frame −0x5bc) at 41ef94. On a full pool it reads the
word unwritten (41f12f, 41f151, 41f16a). The frame-word trace of 41bc90..422ab8
lists two earlier writers in the same call:

- **41df2d** (`OriginalMatchRound.restoreRoundActors`, the +328 > −1 branch,
  last Object's heap address). That restore runs only when the round timer is
  at least 350, and the call then continues to the round epilogue, not the
  gameplay passes. So 41df2d never precedes the hit drop in the same call and
  does not decide its outcome.
- **41e99b** (`OriginalWorldPhysics`, reserve respawn when +30c ≥ 2, after
  the decrement at 41e982) stores −3 − World with World the static 0x458b00.
  Read as a slot, it sends the Actor-table read to 0x458b00 + 0x194 +
  4·(−3 − 0x458b00) = 0xff2f6088, in the upper half of the address space of a
  fixed-base, non-large-address-aware EXE. That is an access violation.

The trace's depth conflicts (41cc25..41d70e) are artifacts of callee-cleaned
calls (MessageBoxA at 41d708, 43f3c6, 43df00) that the tracer treats as
caller-cleaned. The code there touches only globals, so it adds no writer.
When neither writer runs, the word holds what the Windows calls between ticks
left at that depth, which nothing determines.

## Outcome (exact where the EXE fixes it)

On a full pool, for the hit pass and its library variant:

- −3 − World: "Source fault", the original's access violation (exact).
- An unknown word: the existing declared skip after the draws (unchanged).
- A supplied numeric slot (the oracle harnesses' controlled word): unchanged.

## Implementation

1. `OriginalRequestSlotWord.respawn(world:)` = −3 − World and `entry(_:)`.
2. `OriginalWorldPhysics`: a reserve respawn sets the word to −3 − World
   (inout; the existing entry points are unchanged).
3. `OriginalWorldHits` and `OriginalLibWorldHits` take the word. `.value` keeps
   the current retained-slot path, except an entry address at or above
   0x80000000, which is the source fault; any other word is the declared skip.
4. `OriginalGameplayBody` carries physics → hits within the call.

## Checks

- Unit tests:
  - a physics respawn gives −3 − World;
  - hits on a full pool: −3 − World is a Source fault after the draws, nil
    keeps the skip, and a numeric slot keeps its rebuild.
- The world-physics, world-hits, library-hits and gameplay-body
  suites pass unchanged (release test build). The e2e set passes.
- These checks run on a working tree that also holds the user-deferred,
  uncommitted network changes. Those act only after ONLINE GAME, which no
  check here uses, and they are not part of this card.

EXE envelope not recalculated.
