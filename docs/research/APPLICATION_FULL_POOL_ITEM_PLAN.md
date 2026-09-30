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

The requested-items path (4214d5, global 450bb8 = 1, caller SP+34) is not
changed. Its frame word is shared with loop counters earlier in the same
tick, so it needs its own trace; it stays a boundary.

## Checks

- A unit test: a full pool with no retained slot consumes the same draws and
  leaves World, Actors and globals unchanged by the spawn.
- The actor-hit and library actor-hit fixture suites pass unchanged.
- The War soak passes the stop; the whole e2e set passes.

EXE envelope not recalculated.
