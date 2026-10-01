# Plan: the requested-items slot word on a full pool

2026-10-01. Parent: [full-pool item plan](APPLICATION_FULL_POOL_ITEM_PLAN.md)
(its addendum on the requested-items path). User decision (2026-10-01): full
F8 handling is a mandatory part of compatibility. The original is not executed.

## Question

F8 in VS (450bb8 = 1) and the library's stage requests (450bb8 = 3, through
the 4214d7 → 10001a9a hook, which only builds the candidate list and returns
to the EXE's spawn code) run the requested-items pass 4214d5..421799. For
each candidate it searches slots 50..399 and stores a free one in the body's
frame word SP+34 (frame −0x5d4) at 42157a. On a full pool it skips the store
and reads the word as the slot at 421651, 42166a and 42169b. Later candidates
reuse the previous candidate's slot, which the Core already does. Only the
first full attempt needs the word's incoming value, and the Core stops at a
boundary there.

## Static reading (flow-sensitive frame-word trace of 41bc90..422ab8)

41f2c7 writes −4 − World unconditionally; no branch enters 41f2cb..41f550
from outside, so every call reaches the lifecycle loop 41f550..4214cf with
that value. Inside the loop the writers are below. Values written and then
overwritten in the same step are not listed separately.

| Site (EXE) | Swift owner | Last value the step leaves |
| --- | --- | --- |
| 41f706..41f933, the five 0x270c particles | `OriginalPostDrawSlotPrefix` `particles` | per created particle: the raw result of draw 160, 161 or 162 (0..2, 0..2, 0..6); nothing when no slot is free |
| 4213b6..421497, frame 11xx/12xx early exit | `OriginalPostDrawOpoint` | 0 (an 80-step countdown) |
| 41fd2f/41fd47, opoint catalog search | `OriginalPostDrawOpoint` | when the catalog count > 0: the catalog base + 4·i (i = the match or the count), even when no slot is free |
| 41fd94, 41fdc9..41fe59, 41fedc, opoint child | `OriginalPostDrawOpoint` | 0, or the child's y when the parent faces left (byte +80 ≠ 0) |
| 4204f3..420537, weapon child | `weapon` | the new Actor's address |
| 420c7b..420c97, command search (ID 998) | `command` | when the count > 0: the catalog base + 4·i, even when no slot is free |
| 420ccf..420e89, command child | `command` | 400 (the slot counter of the following loop) |
| 420f89, death particle | `late` | the new Actor's address |
| 4211f6/421212, fire particle search (ID 999) | `late` | when the count > 0: the catalog base + 4·i |

lib.dll's code at 1000109d (installed at 41f5fc) does not touch the frame.
The Actor scheduler range has no writer.

**Oracle check.** The gameplay-commands corpora observe the word at 4214d5
after the original's own loop. With their controlled World at 0x22000020 it
is 0xddffffdc, which is −4 − World, as the reading predicts for a tick with no
writer.

## What the original does with each value

The Actor table entry is read at World + 0x194 + 4·word. World is the static
0x458b00. The EXE has no relocations (fixed base 0x400000) and is not
large-address-aware, so its user address space ends at 0x80000000.

- **0..399:** that slot is rebuilt as the item, a live object included (exact).
- **−4 − World (no writer this tick):** the entry address is 0xff2f6084, in
  the upper half of the address space, so the read faults. The original ends
  with an access violation; this is a source fault, not a policy.
- **Any other integer:** if the entry address is at or above 0x80000000, the
  same source fault. Otherwise the original reads memory the port does not
  hold as an Actor. For example, 400 reads World + 0x7d4, the catalog
  pointer, and rebuilds the catalog's Object table.
- **A catalog cursor or an Actor address:** these depend on Windows heap
  addresses, which the EXE does not fix.

## Declared policy (not the EXE)

For the last two cases, the app stops with a boundary that names the word's
origin and says that the original's result depends on memory the port does
not reproduce. It does not invent a slot, skip the item or continue.

## Implementation

1. `OriginalRequestSlotWord` (Core): `.value(Int32)`, `.catalogCursor(Int32)`,
   `.actor(Int)`; `initial(world:)` is −4 − World (default 0x458b00).
2. `OriginalPostDrawScratch.requestSlot` (nil = unknown, as for the existing
   fixture harnesses). The gameplay body sets `initial()` before the loop. The
   prefix, opoint and creation code update it at the sites above; the public
   prefix/opoint entry points keep their signatures.
3. `OriginalPostDrawCommands` takes the word instead of the bare retained
   slot. A found free slot stores `.value(slot)`. On a full pool:
   - nil keeps today's boundary;
   - 0..399 rebuilds;
   - an entry at or above 0x80000000 is a "Source fault" (the app's dialog
     then reads "The original game crashes here");
   - anything else is the declared stop.
   The hit pass's own item word (APPLICATION_FULL_POOL_ITEM_PLAN, frame
   [esp+4c]) is a different word and keeps its declared skip.

## Checks

- Unit tests for each writer kind on small pools: particles, opoint (both
  facings, a failed search), the early exit, weapon, command (success = 400,
  a full pool = cursor), death/fire particles.
- Commands tests for each outcome: a rebuilt slot 0, the −4 − World source
  fault, value 400 and a cursor as the declared stop, nil unchanged.
- The commands reference check feeds the oracle's observed word and compares
  it with `initial(world: 0x22000020)`.
- The existing post-draw, lifecycle, commands, library and gameplay-body
  suites pass unchanged, and so does the e2e set.

EXE envelope not recalculated.
