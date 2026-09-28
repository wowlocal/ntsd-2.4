# Constant-cost iterations: retained delivery history

2026-09-29. Parent: [music output](APPLICATION_MUSIC.md) (798a66e), whose idle
menu run showed iterations slowing (41→145 s per 5000). Rules:
[WORKFLOW](WORKFLOW.md). Written before the change.
**Executor/reviewer:** Claude; independent review open.

**Proven blocker (two 10 s samples of an idle menu, early vs ≈18000
iterations):** copying `OriginalRequestExchange.Cursor` 393 → 2251 samples,
destroying iteration deliveries 143 → 1166. `OriginalApplicationIterationDelivery`
(and the bitmap, menu-graphics and lifecycle deliveries) keep every earlier
nonempty cursor in an array so their receipt resources stay alive; the
platform is copied for every attempt, so each iteration copies and destroys
the whole history.

**Change:** one `OriginalRetainedHistory<Element>` — an append-only persistent
list (immutable shared nodes, count stored, iterative release of long
chains) — replaces the four arrays. Retention and value semantics are
unchanged: every earlier cursor stays alive as long as any copy holds it; a
copy's later appends are not visible to other copies; `retainedIterationCount`
is unchanged.

**Criterion and checks:** unit test of the history (count, copy independence,
release of a 10⁶-node chain); the delivery suites that assert
`retainedIterationCount` (observed graphics/bitmap) and the iteration/menu
runtime suites; an idle real-clock menu run with flat time per 5000
iterations; the computer-VS virtual-clock captures stay byte-identical.
EXE envelope not recalculated.
