# RT tier 2 — cheap idle iterations and a direct gameplay tick

Study: [CORE_REALTIME](CORE_REALTIME.md); budget:
[CORE_REALTIME_BUDGET](CORE_REALTIME_BUDGET.md); background: [M2](CORE_REALTIME_M2.md),
[R3](CORE_REALTIME_R3.md), [DATAFLOW](CORE_REALTIME_DATAFLOW.md),
[COPIES](CORE_REALTIME_COPIES.md). A static design by a read-only planner on
2026-10-06 at e4b89f0 (nothing built or run); estimates from the phone's
compute per tick and the Mac's full-stack sample, to be measured per step.

Abbreviations (NTSDCore): HS HostSession, OI ObservedIteration, EX
RequestExchange, BS Bootstrap, MS MenuSession, ML MessageLoop, TM Timer, OSR
StateRecord, MB MatchBindings, LC LoadedCycleSession, GS GameplaySession, LMS
LoadedMenuSession, GB GameplayBody; NTSDRuntime: RM MacRuntimeMenu, MSG
MacRuntimeMessages, RS RuntimeSession, RL MacRuntimeLoading.

## Where it stands

Phone, virtual clock (phase 4g): main thread 30.4–30.6 ms per tick = the
loaded cycle (`RL.complete`) 22.3 ms + 4.12 message-loop iterations × 1.51 ms
+ ~2 ms; render thread 22.0 ms. Mac: the loaded cycle splits into the
gameplay session 52% (its body 44%, `store` 7%), `finish`/`replay` 28%, the
loaded cycle's advance 15%; an idle step is ~83% Host-attempt machinery
(message-loop work ~37%, exchange cursor ~18%, release ~18%, memmove ~14%,
array growth ~14%, record writes ~12%).

## A. Cheap idle message-loop iterations

An idle iteration (queue empty, timer not due) reads the host checks,
copies the platform and prepares inputs, copies application/session/state,
validates the replay alias, peeks (answer 0, no writes), reads the speed
word `full+0x2c`, takes `time` twice and `Sleep(min(r,5))`, writes the
counter (+1, reset after 60) to `full[0xb580..<0xb584]`, keeps the timer
baseline unchanged, increments `revision` and the Host `sequence`, and
publishes `.iteration(.continued, [.sleep(n)] or [])`. Nothing touches
`memory`, `loadedOwners`, `startup`, the graphics owner, `pending` or
`prepared`.

**The 14% memmove** is the copy-on-write of `MenuSession.State.full` (0xc3a8
bytes plus mask, ~100 KB) on the counter write (MS:85 → OSR:182-200), twice
per iteration:
1. MS:764-766 builds a merged `coherent` copy only for a `beforeCommit`
   observer, which production never attaches (and MS:804-807 does the same in
   `finishLoadedMenu`, once per tick).
2. MS:768, the committed state, whose old buffer the Host keeps for rollback;
   avoidable only with `full` in parts (B1) or an in-place commit after the
   point of no return (A1).

The array growth is mostly `IterationDelivery.response` copying the cursor
out of the platform for every inline receipt; the release share is the
dropped copies.

### Steps

- **A0** (no fast path): build `coherent` only when a `beforeCommit` observer
  is supplied, in MS.step and MS.finishLoadedMenu; `requireConsumed()` stays
  unconditional (same error, same order). ~0.3–0.5 ms per tick.
- **A1** (idle kernel): `MS.idleIteration(queue:)` runs the real `ML.step` on a
  copy of the loop with a provider that serves only peek, time and sleep and
  bails out (`NotIdle`) on anything else; `commitIdle` writes the loop, the
  counter merge (non-throwing, extent already checked) and `revision`;
  `HS.stepIdle` runs inside `attempt` in HS:212-216's order, bails out unless
  startup is set, `initialization` is nil and the prepared response arrays
  are empty, then commits in place after the DeliveryContext copy and
  `beforePublication`; `OI.resumeIdleFirst` tries it inside one attempt and
  otherwise runs the normal `host.step` with a fresh cursor over the same
  receipts (prepare once per resume); RM uses it when `servesQueueInline &&
  servesIdleDirectly` (a flag; false keeps the reference path for tests).
  ~1.0–1.1 ms per idle iteration, ~3–3.5 ms per tick under the virtual clock,
  ~5 ms in real play at an 8 ms tick.
- **A2**: `IterationDelivery.response` mutates the cursor in place; reserve
  receipt capacity. ~0.1 ms.

### Invariants (A)

1. The kernel commits only when the full path would (peek 0 with no writes,
   timer not due, no initialization, empty arrays, aliases valid, revision
   below max).
2. It issues the full path's exact request prefix (same values, order and
   provider chain; the same ML/TM code).
3. A bail-out leaves only receipts and RM counters for requests it served,
   exactly what a discarded attempt left before M2; nothing is served twice.
4. Provider errors are identical; Core errors never escape the kernel (the
   full path raises them at the same point).
5. Host checks in HS order; one `prepare` per resume.
6. Committed values equal the full path's (loop, `full` changed only at
   0xb580..<0xb584, revision, platform, Committed, sequence, DeliveryContext,
   finished exchange).
7. Commit order: context copy, `beforePublication`, then the in-place
   mutation, which cannot fail; earlier holders keep their values through
   copy-on-write; only struct/array fields are mutated.
8. RM and RS bookkeeping unchanged.

Tests: a Core oracle of two Hosts (`resumeIdleFirst` vs `resume`) compared
after every step (outcome, batch, snapshot, delivery state, exchange; kernel
commits > 0) over sleep/no-sleep, counter reset, speed flag, due ≤100 and
>100, a queued message, WM_QUIT, broken alias, undefined `+0x2c`, a failing
clock at each request, small request bounds, pending loading, stale sequence,
non-empty arrays, `settings == nil` and an undrained earlier batch; a runtime
side-by-side with the flag on and off through menus, a key press and
gameplay; the card's gates.

## B. A direct gameplay tick

Orchestration around the body: three Host attempts per tick; `bindings.read`
(globals slice ~92 KB with mask, world slice and 400 seats); two `store`s
(copy of `full`, globals replace and compare, 400 seats, 400 actor-pair
checks; ~1.6 ms each); nested candidate copies (~600 KB per tick, R5); a
throwaway `GameplaySession` validation (HS:321) then a second construction in
RL; `soundBuffers` rebuilt per tick (GS:73-79); the per-event front/emit
chain (committed output: stays, could dispatch by enum); P3's copies and the
`coherent`/merge copies of `full` (A0 and parts remove them); the batch
drain and `replay`.

**What cannot be bypassed:** one copy per phase of each record a later phase
writes (the Host keeps each phase's state for retry; only an undo journal,
R6, removes it — a user decision); the session form inside the committed
batch (public outputs compared by the drivers; the message loop reads and
writes globals every iteration); every boundary check in today's order; the
due iteration as its own Host step (RS work and `steps += 1` run between
it and the cycle); the body, loop tail, operations and graphics commands.

### Steps

- **B1 = R3 stages 3–4** (largest): `full` in parts at 0xb440, 0xb580,
  0xb588, 0xb8a8, 0xb8b0, 0xbb00, 0xc2d8 (slices and replaces at a part's
  extent O(1); crossing a boundary takes the logical slow path; errors keep
  logical offsets); the globals part is the same buffer as
  `loadedOwners.match.globals` between ticks; a world pair cache; hot sites use
  part-aware access instead of `.bytes`. ~2.5–3.5 ms.
- **B2 = R5/M3**: internal in-place variants of the loaded match cycle and
  entry, the body and the inner `World*.apply`, used only from LC/GS (their
  values are dropped on throw). ~0.5–1 ms.
- **B3**: one loaded attempt per tick (`HS.advanceLoadedTick`) fusing
  prepareBoundary, resumeGameplay and finishLoadedMenu, leaving exactly the
  phased path's retained stage on each failure and passing the validated
  GameplaySession on. ~0.2–0.5 ms.
- **R3 stage 2** (replay slot tier): ~0.1–0.3 ms, independent.
- **Replay**: check first whether `finish`/`replay` is on-CPU on the phone
  (`replay` starts with a render flush, which the Mac sampler counts while
  blocked); if so, one render submission per batch (same order, same flush
  points). ~0.5–1.5 ms.

Invariants (B): logical values equal today's at every retention and commit
point; parts behave exactly as flat records (same errors at logical offsets,
logical equality, the same assembled bytes); read, store and
`validateAliases` give today's first error with nothing assigned before a
throw; the fused attempt gives the same batch and Host state on success and
the same retained stage and error on failure; in-place mutation only where
the caller discards its value on throw; the batch shape unchanged; no
production tick takes the slow assembly path.

Tests: parts against a flat-record model (random operations across
boundaries); the read/store oracle with parts and the world pair; M3
transactional vs in-place with injected throws; fused vs phased with the
loaded test driver over the neutral, active and paused sequences and the
stop lists; a copy probe; the card's gates.

## Order and tally

A0 → A1 → A2, then B1 → B2 → B3, with R3 stage 2 and replay batching where
convenient. Projected main thread ≈ 30.7 − 3.5 (A) − 4 (B) ≈ 23 ms; the 16 ms
tier also needs the body (~10 ms: mask-free hot fields), the per-event emit
chain, and the replay if it is on-CPU.
