# The hit pass's item word on a full pool

[Plan](APPLICATION_HIT_ITEM_SLOT_PLAN.md). The original is not executed.

## Result (2026-10-01)

The hit pass's random item drop reads the body's frame word [esp+4c] as its
slot when the pool is full. The one writer that can precede it in the same
call is now modelled: a reserve respawn in `OriginalWorldPhysics` (41e99b,
+30c ≥ 2) stores −3 − World. With World the static 0x458b00, the original then
reads its Actor table at 0xff2f6088. That address is outside the user address
space of the fixed-base, non-large-address-aware EXE, so the read faults. When
a respawn and a full-pool drop fall in the same tick, the app now stops there
as a "Source fault" (the original's access violation), after the drop's
draws, instead of skipping the item.

The round's 41df2d store (an Object address) runs only when the round timer
is at least 350, and that call continues to the epilogue, so it never
precedes the drop. When no respawn happened, the word is what the Windows
calls between ticks left at that depth, and the declared skip after the draws
stays. A supplied numeric slot (the oracle harnesses' controlled word) keeps
its rebuild.

**Changes:**

- `OriginalRequestSlotWord.respawn(world:)` and `entry(_:world:)`.
- A `respawned` callback in `OriginalWorldPhysics` at the +30c decrement.
- An `itemSlot` word in `OriginalWorldHits`, `OriginalLibWorldHits` and the
  shared `advance`.
- `OriginalGameplayBody` carries the word from physics to the hit pass within
  the call. The existing entry points and their defaults are unchanged.

**Checks:**

- `OriginalWorldPhysicsTests.testRespawnReportsTheHitWordStore`: a respawn
  with one ally completes, reports once and decrements +30c. The test also
  checks the −3 − World value and its entry 0xff2f6088.
- `OriginalActorHitsTests` (the whole-pool corpus): for every full-pool case
  that already checks the declared skip, the respawn word now gives the
  Source fault after the same draws. The two counts must be equal.
- In the release test build (`-enable-testing`), 38 tests pass with no
  failures. They cover:
  - actor and library hits, world and gameplay physics, gameplay hits and the
    gameplay body;
  - the gameplay commands, lifecycle, HUD and active-gameplay chains;
  - the requested-slot word and post-draw commands.

  The hit corpus compares 7845 whole pools, with one full-pool case per
  corpus; that case skips without a word and faults after a respawn.
- The whole e2e set passes unchanged: vs with its checks, mission, demo, war,
  playback, tournament, altenter with its fault check, tournament-win,
  team-tournament, joystick. The vs checks' online path runs with the
  deferred work's uncommitted `--no-network` option.
- These ran on a working tree that also holds the user-deferred, uncommitted
  network changes (NETWORK_PLAY.md). Those act only after ONLINE GAME, which
  no check here uses, and they are not part of this card or its commit.

EXE envelope not recalculated.
