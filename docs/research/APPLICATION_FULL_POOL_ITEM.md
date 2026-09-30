# An item drop when every object slot is taken

[Plan](APPLICATION_FULL_POOL_ITEM_PLAN.md). The original is not executed.

## Result (2026-09-30)

A War soak stopped in its third battle at the hit pass's random item drop
(41ef55..41f276) with every slot 50..<400 active. On Windows the spawn then
uses the gameplay body's frame word [esp+4c], which the free-slot search at
41ef7c..41ef92 left unwritten. A flow-sensitive walk of all of 41bc90..422ab8
found only two earlier writes to that word in one call, 41df2d (an Object
pointer) and 41e99b (−3 − World). Both are conditional and neither is a slot
number; otherwise the word holds stack from calls between ticks. The Windows
value is unknown, and the original most likely faults or rebuilds a live
object as the item.

Declared policy, as planned: without a free slot or a supplied retained
slot, `OriginalWorldHits` skips the spawn after all of its draws (146, the
147 filter draws, 148/150, 149/151, 152, 153, 154). Nothing is rebuilt,
activated or written, and the rest of the pass is unchanged. A supplied
retained slot keeps the recovered behaviour.

**Requested items (corrected).** d26e412 applied the same skip to the
requested-items pass (F8, library requests). An independent review found
that its slot word is not unknown. 41f2c7 writes −4 − World on every call,
and the lifecycle loop then overwrites it (countdowns ending at 0, a counter
ending at 400, Object-table pointers, −(rand(15)/2)). A value of 0 makes the
original rebuild slot 0. The skip was reverted and the explicit boundary
restored; see the plan's addendum.

**Checks:**

- `OriginalActorHitsTests` now also runs every whole-pass case that supplies a
  retained slot without one. When the pool is full (one case in each of the
  two corpora), the draws match the original's up to its `reconstruct` and
  nothing is rebuilt; otherwise the run is the original's. Both corpora (7845
  cases each) still match the original byte for byte. `OriginalLibActorHitsTests`
  and `OriginalGameplayHitsTests` pass (7 tests in all).
- The same War soak now runs 50,000 bodies, 14 battles, with no stop (logical
  heap 168.4 MB at the end).
- A VS match with F8 pressed every 20 steps for 2,500 steps plays with no
  stop; it did not reach a requested-items pass that starts on a full pool.
- The whole e2e set passes.

EXE envelope not recalculated.
