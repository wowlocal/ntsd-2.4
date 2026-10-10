# RT R3/R4 — the match model authoritative across ticks

Study: [CORE_REALTIME](CORE_REALTIME.md); background:
[CORE_REALTIME_DATAFLOW](CORE_REALTIME_DATAFLOW.md) (R3, R4),
[CORE_REALTIME_COPIES](CORE_REALTIME_COPIES.md). A static design by a read-only
planner on 2026-10-06 at b22545a; costs are estimates, to be measured per stage.

## Where it stands

Phone after M2b/1f: ~16.9 ticks per second; main thread 66% of samples, render
thread 32%; reference counting ~23% of the main thread. `MatchBindings.read`
and `store` convert 400 world seats, 400 actors and the globals between
`MenuSession.State` (`full` plus `memory.allocations`) and the match model on
every tick (store 7.3% and read 2.7% of the main thread).

In production nothing but the bindings and the loaded menu attempt's range
list (LMS:191) reads actor records from `memory`; the three places that
iterate `memory.allocations` (CatalogSession:163, PoolSession:168, LMS:191) only
build range lists queried with `contains(where:)`, so iteration order is not
observable; observers need the session form only when they access it.

## Invariants at every commit and retention point

- **I1** the same logical state: `full` (bytes and mask), `memory.allocations`
  as a dictionary, `replayPointers` and every other field equal today's; the
  match is identical.
- **I2** tiers never share a key; an actor tier exists only with its bindings'
  identity and holds exactly 400 records of 0x420 bytes whose +0x368 is defined
  and in range (checked when installed); its tokens are in no other tier.
- **I3** `validateAliases` holds.
- **I4** read, store and `validateAliases` throw the same error for the first
  failing (index, check) in today's order; nothing is assigned before a throw.
- **I5** `application`, `pending`, `prepared` and their platforms are values a
  failed attempt never changes; caches are memos used after an equality check.
- **I6** production gameplay ticks never materialize the session form (a debug
  counter shows zero).

## Stages

1. **Actor tier (R3 core; largest gain, medium risk).** A new
   `OriginalAllocationTable` (`general` dictionary plus an optional actor tier
   owned by the bindings' `ActorPairs` identity) with a dictionary-shaped API
   so the ~80 `allocations[...]` call sites compile unchanged; reading an actor
   token materializes one record, changing an actor entry first moves the tier
   back into `general` (today's form). `read` takes the tier's model records;
   `store` keeps today's per-index checks with fast paths (owned tier implies
   exists/live/size; the same records buffer implies no conflict; +0x368 by a
   pair hit or one read) and installs `match.actors` as the tier. Saves three
   400-actor loops, two copies of the ~500-entry dictionary and ~16 actor
   conversions per tick (~15–20k retain/release). Tests: a model-based table
   test against a Dictionary, and an oracle test keeping today's read/store in
   the test target and comparing results and exact errors under single and
   multiple faults; existing InputTests, HostGameplayTests, LoadedCycleTests,
   GameplayProjectionTests, Active*/Paused, MacRuntimeLoadingTests.
2. **Replay slot tier and two-level pages (R4; small gain, low risk).** Paged
   records in their own tier, written through one `_modify`; two-level page
   lists so a first write after a rollback copy duplicates ~48 references.
3. **`full` in parts (moderate gain, medium risk).** A third record
   representation of flat parts at the State's boundaries (0xb440, 0xb580,
   0xb588, 0xb8a8, 0xb8b0, 0xbb00, 0xc2d8): slices and replaces at a part's
   extent become O(1); reads and writes across a boundary take a slow path;
   errors keep logical offsets. Saves ~700–900 KB of copying and comparing per
   tick (this covers M5) and ~10 large allocations; the globals part of `full`
   is the same buffer as `match.globals` between ticks.
4. **World pair and trims (small gain, low risk).** A world-seat pair cache
   like ActorPairs; one lock per call; `byteCount` in shape checks. The
   literal deferred store of R3 only if the profile after stage 3 still shows
   the loaded cycle's store above ~0.5%.

## Estimate and what remains

Stages 1–4: about 10–13 points of samples (15–20% of the main thread), roughly
20–21 ticks per second if the main thread is the limit. Reaching 30 also needs
R5/M3 (nested candidate copies of globals and actors inside the model, ~600 KB
per tick), work in the gameplay body, and above ~25 ticks per second the
render thread. Every stage is a storage-model change and gets an independent
review; riskiest points: the table diverging from today's dictionary,
fast paths changing which error is thrown first (only the oracle test with
multiple faults pins it), materializing on a hot path (speed only), a tier
meeting bindings from another session (owner identity check), boundary
handling in the parts representation, retry and rollback.

## As built: stage 1 (2026-10-06)

`OriginalAllocationTable` (`native/Sources/NTSDCore/OriginalAllocationTable.swift`):
a `general` dictionary plus an optional `ActorTier` owned by the bindings'
`ActorShape` (tokens, index, Object tokens, the pair memo). Reads of an actor
token build its logical entry from the tier; any change to an actor entry
dissolves the tier first; equality compares logical entries (fast when both
tables hold the same shape). `read` returns the tier's records; `store`
keeps today's checks in today's order with shortcuts (the state's tier
implies exists/live/size; equal tiers in context and state imply no
conflict) and installs `match.actors`; a debug assertion checks the tier
invariant. Probe over a computer-vs run: 7 fresh installs, 4,684 re-installs,
0 dissolves, 1,200 materializations (three whole-table iterations). Phone
16.87 → 19.09/19.26 ticks per second. Oracle and table tests in
`OriginalAllocationTableTests`. Evidence:
[rt-r3s1-actor-tier](../evidence/rt-r3s1-actor-tier-20261006.json).
