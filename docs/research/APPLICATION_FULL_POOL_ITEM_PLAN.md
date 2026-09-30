# Plan: an item drop when every object slot is taken

2026-09-30. Parent: [soaks](APPLICATION_SOAKS.md). The original is not executed.

## Finding

A War soak after the memory fixes stopped in its third battle with
`Item spawn needs retained caller slot provenance`
(`OriginalWorldHits.swift:57`). The hit pass's random item drop (41ef55..41f276,
inside the gameplay body 41bc90..422ab8) runs when fewer than four items are
active and 417170(146, 200) returns 0. It searches slots 50..<400 for a free one
(41ef7c..41ef90) and stores the result in the body's frame word [esp+4c] at
41ef94. When every slot is active, the loop exits at 41ef92 without storing.
After the draws 147..154, the spawn reads that word as the slot at 41f12f,
41f151 and 41f16a.

A flow-sensitive walk of the whole body (ESP depth per instruction, every
access to the same frame word) finds only two writes before 41ef94 in one
call, both conditional and neither a slot index:

- 41df2d stores an Object pointer (a transform path's catalog scan).
- 41e99b stores `−3 − World` (an address-derived constant for a slot sweep).

Otherwise the word holds stack left by calls between ticks: the main loop's
message and Host functions reuse that depth. On Windows the spawn therefore
indexes the Actor table with an arbitrary value. If it is not a slot number,
that is an access violation or a stray write; if it is one, a live object is
rebuilt as the item. The value is not recoverable; the Core keeps the
boundary for any caller that cannot supply it.

## Declared policy (not the EXE)

With no free slot and no retained slot supplied, the spawn is skipped after
all of its random draws (146, the 147 filter draws, 148/150, 149/151, 152,
153, 154), which the original makes before it reads the slot. Nothing is
reconstructed, activated or written. The RNG stream, the candidate scan and
every other part of the pass are unchanged. A supplied retained slot (the
oracle fixtures' controlled caller scratch) keeps its recovered behaviour.

The requested-items path (4214d5, caller SP+34) is traced separately in the
addendum below.

## Addendum: the requested-items path (2026-09-30)

F8 in VS (helper 416f10 sets 450bb8 = 1; allowed when 451160 = 0 or with
the cheat on) and library stage requests (450bb8 = 3) run the requested-items
pass (4214d5..421799), which keeps its slot in the body's frame word SP+34
(−0x5d4). Pressing F8 repeatedly can fill the pool, and then the first
attempt of a pass reads the incoming word. A flow-sensitive walk shows its
writers inside the lifecycle loop 41f550..4214cf are per-slot branches:
80-step countdowns that end at 0 (41fdc9/41fe59, 4213c3/421497), a slot
counter that ends at 400 (420e89), the catalog Object table pointer
(World+7d4) stepped by 4 (41f706/41f71e, 41fd2f/41fd47, 4211f6/421212 and
similar) and other register stores (41fedc, 420537, 420ccf, 420d61, 420f89).
The incoming value is the last such write across the 400 slots. It can be 0
(the original would then rebuild slot 0, a player, as the item), 400 (the
word after the Actor table) or an address (a fault). It is not modelled.

Declared policy, the same as for the random drop: while the pass has no known
slot (none found free and none created earlier in the same pass), an attempt
is skipped after its four coordinate draws. Once a slot is known, full-pool
attempts reuse it as recovered.

## Checks

- A unit test: a full pool with no retained slot consumes the same draws and
  leaves World, Actors and globals unchanged by the spawn.
- The actor-hit and library actor-hit fixture suites pass unchanged.
- The War soak passes the stop; the whole e2e set passes.

EXE envelope not recalculated.
