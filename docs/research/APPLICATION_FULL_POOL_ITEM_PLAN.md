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

The requested-items path (4214d5, caller SP+34) is traced in the addendum
below; it stays a boundary.

## Addendum: the requested-items path (2026-09-30, corrected)

F8 in VS (helper 416f10 sets 450bb8 = 1; allowed when 451160 = 0 or with the
cheat on) and library stage requests (450bb8 = 3) run the requested-items
pass (4214d5..421799), which keeps its slot in the body's frame word SP+34
(−0x5d4). Its first attempt on a full pool reads the word's incoming value.

d26e412 declared a skip here, calling that value unknown. An independent
review showed it is not. At 41f2c7 every call writes −4 − World into the
word unconditionally, and then the lifecycle loop 41f550..4214cf overwrites it
per slot. The writers are:

- 80-step countdowns that end at 0 (41fdc9/41fe59, 4213c3/421497);
- a slot counter that ends at 400 (420e89);
- the catalog Object table pointer stepped by 4;
- −(rand(15)/2) at 41f82b, one of 0..−7;
- other register stores.

So the incoming value comes from the current call's own state. When it is 0
the original deterministically rebuilds slot 0, a player, as the item; a
skip would depart from known EXE behaviour. The skip was reverted and the
explicit boundary restored. Reaching it needs a pool filled by F8, which a
2,500-step F8 run in VS did not do. A faithful port needs the word modelled
through the lifecycle loop, with a declared policy only for its
address-derived values (−4 − World, Object-table pointers), which depend on
Windows heap addresses. That is a separate card.

## Checks

- A unit test: a full pool with no retained slot consumes the same draws and
  leaves World, Actors and globals unchanged by the spawn.
- The actor-hit and library actor-hit fixture suites pass unchanged.
- The War soak passes the stop; the whole e2e set passes.

EXE envelope not recalculated.
