# Constant-cost iterations: retained delivery history

2026-09-29. [Plan](APPLICATION_ITERATION_HISTORY_PLAN.md). Parent:
[music output](APPLICATION_MUSIC.md) (798a66e). Author implementation and
machine checks; independent review open. The original was not executed.

## Result

Menu iterations now cost the same after 30000 iterations as at the start:
15.1 s per 2000 idle real-clock iterations throughout (≈7.5 ms each, of which
the game's own Sleep is 5 ms). Before, the same run went 16.2 → 24.7 s per
2000 by iteration 18000, and 41 → 145 s per 5000 over 35000.

Cause: the iteration, bitmap, menu-graphics and lifecycle deliveries keep
every earlier nonempty request cursor so their receipt resources stay alive,
in an array; the platform is copied for every attempt, so each iteration
copied and destroyed the whole history (`Cursor` copies 393 → 2251 samples,
delivery destruction 143 → 1166 in 10 s samples early vs late).
`OriginalRetainedHistory<Element>` — an append-only persistent list with
shared immutable nodes, a stored count and iterative release of long chains —
replaces the four arrays. Retention, copy independence and
`retainedIterationCount` are unchanged.

## Checks

- `OriginalRetainedHistoryTests` (3: copies share earlier elements and append
  independently; elements live while any copy holds them; a 10⁶-node history
  releases without recursion), `OriginalMacRuntimeMenuTests` (3) and
  `OriginalMacMusicOutputTests` (6): 12/12. Delivery suites (observed
  graphics/bitmap/iteration/startup, including the `retainedIterationCount`
  assertions): 17/17 in 4.7 min with 3 parallel workers.
- App: idle menu as above; the computer-VS virtual-clock body captures
  300..1500 stay byte-identical to the tick-speed reference, busy ≈2.5 s per
  300 bodies as before. [Evidence](../evidence/application-iteration-history.json).

## Resource-free iterations (2026-09-30)

A long VS session showed the iteration history growing by ≈9,000 cursors
per match: every gameplay tick is a nonempty message-loop iteration, and all
were kept. Their queue and DefWindowProc receipts retain no resources, so
`OriginalApplicationIterationDelivery` now keeps an earlier cursor only when
one of its receipts retains a resource (`Cursor.retainsResources`). The
bitmap, menu-graphics and lifecycle deliveries are unchanged. Measurements
are in [APPLICATION_SOAKS.md](APPLICATION_SOAKS.md#vs-session-many-recorded-matches-2026-09-30).

EXE envelope not recalculated.
