# RT A3 — idle message-loop iterations at ≤0.2 ms

Study: [CORE_REALTIME](CORE_REALTIME.md); context: [TIER2](CORE_REALTIME_TIER2.md)
section A (the A1 kernel and its invariants 1–8), [M2](CORE_REALTIME_M2.md).
A static plan by a read-only planner on 2026-10-07 at 74a3583 plus the B1 3b
edits (nothing built or run). F = fact with a code citation, I = inference.
Abbreviations as in TIER2; PSP = PreparedStartupPlatform.

## Where it stands

Phone (b62edc7): ~1.1 ms of main-thread CPU per idle iteration, about three
per tick under the virtual clock. The path (F): `RM.step` builds a new Driver
each step (an ObservedIteration, an exchange with its own lock and identity, a
recursive lock, two escaping inline closures; RM:137-158), then
`OI.resumeIdleFirst` → `HS.stepIdle` → `MS.idleIteration` → the real ML/TM code.

What production reads of an idle iteration (F, RS/RM): the requests (values,
order, count: peek → 0, time, time, `Sleep(min(r,5))` when r > 0), the RM/MSG
counters (`messages.sleeps` sets the next delay, `requests` and `lastRequest`
reach events), the committed application (counter +1 with its reset,
`full[0xb580..<0xb584]`, `revision`) and sequence, and the effects list. The
exchange's receipts, the committed platform's cursor, the DeliveryContext and
the Batch object are read only by tests (I); the plan keeps them equal anyway.

## Mechanisms

- **L1** generic specialization: HS and OI are generic classes used across
  modules with one platform (PSP); without cross-module optimization they
  run unspecialized (the profile's `initializeWithCopy` for Batch/Contents,
  generic metadata). Concrete entry points or the compiler's cross-module
  optimization; no behaviour change. ~0.05–0.15 ms.
- **L2** `takeCommitted` moves the batch (`remove(at: 0)` instead of a
  copying `removeFirst()`, to be checked). ~0.08–0.12 ms.
- **L3** the kernel's loop context is `state.full` instead of two whole
  State copies. ~0.03–0.06 ms.
- **L4** the idle lane: a static `OI.resumeIdleDirect` around `stepIdle` with a
  non-escaping serve callback (the inline server's `.queue` branch factored
  out: request bound, counters, `messages.answer`, the exchange's accepts
  check and error), no Driver/exchange/claim/locks; commits through
  `stepIdle` with an already consumed cursor (`EX.consumedCursor(receipts:)`);
  a bail-out seeds the Driver's exchange with the lane's receipts
  (`EX.record`) and runs today's fallback. ~0.35–0.45 ms.
- **L5** platform copies: (a) in the PSP lane the DeliveryContext shares the
  committed candidate (PSP's `stagedCopy` cannot throw; no Host path changes
  a committed platform in place); (b) PSP's immutable inputs in one shared
  object (as 4a). ~0.05–0.1 ms.
- **L6** a lazy idle batch: `idleTail = (sequence, committed)` turned into
  today's Batch before any later Host call or drain that needs it; the
  runtime drains contents only. ~0.1–0.2 ms.
- **L6b** (user decision): idle commits keep the previous committed platform
  (tests would see different `platformSnapshot` values).

Projection: ~1.1 → ~0.35 ms after L1–L5 → ~0.15–0.25 ms after L6. Outside the
timed region, `RS.iterate` also runs two `Date()`, `presentMusic` and
`asyncAfter` per iteration (to be measured).

## Invariants (in addition to TIER2 A1–A8)

9. The lane serves exactly the A1 kernel's request prefix through the same
   counting and bound code; a declined request is neither served nor counted.
10. On bail-out the seeded exchange equals the kernel's (receipts, open, no
    permit); `prepare` runs once per first resume of each step.
11. The consumed cursor, shared platform and lazy batch equal today's values;
    a lazy batch is materialized before the application or platform changes.
12. With `maximumRequests ≤ 0` the lane is never entered.

Tests: a Core two-Host oracle (lane vs `resume`, compared after every step:
outcome or error, sequence, batch incl. context loop, `full` bytes and masks
and the context's iteration delivery, snapshots, served-request log,
counters) over TIER2 A's case list plus peek/time with writes and
interleaved drains; the runtime side-by-side test in three modes; unit tests
for `EX.record` and `consumedCursor`; the existing Host, delivery-context,
iteration-delivery, menu-input, observed-startup and runtime-loading suites.

## Pieces

| # | Piece | Idle iteration (phone) | Review |
| --- | --- | --- | --- |
| P0 | split idle and whole-step time (RS, `android_speed.py`); a Mac microbenchmark; DWARF phone profiles | 1.1 ms measured | none |
| P1 | L1 + L2 | 0.85–0.95 ms | light |
| P2 | L3 + L5b | 0.75–0.85 ms | light |
| P3 | L4 + the oracle | 0.35–0.45 ms | independent (architecture) |
| P4 | L5a + L6 | 0.15–0.25 ms | independent (sharing, lazy publication) |
| P5 | if needed: L6b (user) and the RS-side overhead | ≤ 0.2 ms | user + review |

Risks: the lane duplicates OI control flow (limited by reusing `stepIdle`,
`idleIteration` and the fallback); L5a and L6 rest on "a committed platform
is never changed in place" (to be written down and checked on every Host
path); specialization grows code and Android build time; profile shares are
proportions from frame-pointer call graphs, so P0 confirms them first.
