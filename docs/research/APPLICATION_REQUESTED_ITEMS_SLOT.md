# The requested-items slot word on a full pool

[Plan](APPLICATION_REQUESTED_ITEMS_SLOT_PLAN.md), with the writer table and
the address reasoning. User decision (2026-10-01): full F8 handling is
mandatory. The original is not executed.

## Result (2026-10-01)

F8 in VS and the library's stage requests no longer stop at the
"Retained caller slot provenance" boundary on a full pool. The Core carries
the body's frame word SP+34 from 41f2c7 through the lifecycle loop's writers.
The requested-items pass then does with it what the original does:

- **A slot number 0..399:** that slot is rebuilt as the item, a live player
  slot included. The word gets one in three ways:
  - the 0x270c particles leave their last draw (0..6);
  - the opoint and the frame 11xx/12xx exit leave 0, or the child's y when
    the parent faces left;
  - a free slot found by an earlier candidate in the same pass.
- **−4 − World (no writer in this tick, the usual case on a full pool):** the
  Actor-table read at 0xff2f6084 is outside the user address space of the
  fixed-base, non-large-address-aware EXE. The original crashes with an access
  violation there. The app stops with a "Source fault" boundary, and its
  dialog reads "The original game crashes here".
- **Declared stop (plan, "Declared policy"):**
  - 400, left by a command child, which reads World+0x7d4, the catalog
    pointer;
  - a catalog table cursor, left by any failed opoint, command or fire search;
  - a weapon or death particle's Actor address.

  The original's result for these depends on Windows heap addresses, and the
  app stops with a message naming the word's origin.

**Oracle agreement.** The commands corpus observed the word at 4214d5 after
the original's own loop. Its value, 0xddffffdc, is −4 − World for that
corpus's controlled World (0x22000020). The lifecycle reference now seeds the
model with `initial(world:)`, and the commands reference requires the
modelled word to equal the observed one.

**Changes:**

- **Core:**
  - `OriginalRequestSlotWord` (`.value`, `.catalogCursor`, `.actor`;
    `initial(world:)`).
  - `OriginalPostDrawScratch.requestSlot`.
  - The writers in `OriginalPostDrawSlotPrefix` (particles),
    `OriginalPostDrawOpoint` (search, child, early exit) and
    `OriginalPostDrawLifecycle` (weapon, command, death and fire particles).
    The prefix and opoint gain internal overloads, so their existing entry
    points and tests are unchanged.
  - `OriginalPostDrawCommands` takes the word and classifies a full-pool
    read; the `Int32?` entry points remain for the oracle harnesses.
  - `OriginalGameplayBody` starts each call with `initial()` and hands the
    loop's result to the commands pass.
  - The hit pass's own item word (a different frame word) keeps its declared
    skip.
- **Reference checks:** the lifecycle → commands chain described above.

**Checks:**

- `OriginalRequestSlotWordTests` (9 tests): the initial value for both
  Worlds, every writer kind on small pools (full and free, both facings), and
  each full-pool outcome with its message, plus a found free slot replacing
  the word.
- In the release test build (`-enable-testing`), 50 tests pass with no
  failures. They cover the post-draw prefix, opoint, lifecycle and commands
  suites; library stage commands, transforms and actor hits; world hits; the
  Actor scheduler; the gameplay body; the gameplay lifecycle, commands, HUD
  and active-gameplay chains, including the new oracle comparison; and the
  new tests. An earlier debug run was stopped as too slow.
- In the app, three F8 presses in a VS fight with a free pool spawn items
  normally ("F8: 3 time(s)"), with no boundary.
- The whole e2e set passes unchanged (vs with its checks, mission, demo, war,
  playback, tournament, altenter with its fault check, tournament-win,
  team-tournament, joystick).

Not done: an app run that fills the pool and presses F8 (filling 350 slots
through play has not been reached; the outcomes are covered by the unit tests
above), and Windows observations of the declared stops. EXE envelope not
recalculated.
