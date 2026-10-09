# Core real-time, tier 3 H3: a lane for the due tick (design)

A read-only design (2026-10-10, nothing built). [Tier-3 plan](CORE_REALTIME_TIER3.md), row H3;
sibling of [H2](CORE_REALTIME_H2.md).

## Verdict

Sound without a user decision, worth about **0.15 ms per tick (0.1–0.2; L5a's
telemetry would allow up to ~0.25)**. Only the shipping platform reaches the
lane (the only observed-iteration platform; its staged copy cannot fail), so
the platform copy it drops cannot be observed.

## The due tick today

The runtime's step builds a Driver and calls `resumeIdleFirst`. The idle
attempt copies the platform, prepares, runs `idleIteration` (alias check, loop
copy, the loop's peek/time/time served directly), finds the timer due and
returns nil. The replies are recorded, a second cursor is made, and the whole
`step` starts over: the attempt checks again, a second platform copy (it
becomes `pending.platform`), `next = application`, ~16 provider wrappers, two
session copies, the loop's staged State, the alias check again, the
peek/time/time **replayed** from receipts, then the dispatch: alias merge,
`DispatchEntry.advance` (key scan, the back-buffer clear served inline),
emit/consume, slices and owner copies, the World-2 check returning loading,
`combined`, `pending` set, `finishPublication`.

Duplicated by the bail-out: one platform copy, the attempt checks, alias
validation, the loop prefix and its replay, the second cursor; the Host,
Bootstrap and menu-step layers run only because the step starts over.

## The lane

The idle attempt carries on into the dispatch when its loop reaches the game
dispatch of a loading World: `idleIteration(queue:surface:)` returns `.idle` or
`.loading(PendingLoading)`, running `step`'s own World-2 arm through two helpers
factored out of `step` (so both share one body); Core errors and other Worlds
return nil and `step` raises them itself. The Host's `stepIdle(…, surface:)`
(gated on the shipping platform as `retained` is) repeats today's loading arm:
`beforePublication`, then `pending`. The Driver's idle cursor answers queue
requests directly until the first claim; any other accepted request is claimed
after recording the earlier replies (a new mixed `directCursor` that holds the
exchange weakly). A runtime flag keeps the reference path.

Equivalence: the same closures serve the same requests once, in the same order,
with the same bounds and counters; the exchange receipts (peek, time, time, the
clear) are recorded before the claim, so the claim's revision and ordinal are
unchanged; `pending` gets the same owner, revision, State, target,
continuation, effects, commands and inputs; application, platform, sequence and
batches are untouched. Every failure point either runs unchanged code or
returns nil so the fallback replays the served requests and raises the same
error.

Goes: the second platform copy, the second attempt and cursor, the replay, the
three layers' prologues (about half of the 2.35% the whole step costs after the
idle bail-out). Stays: the dispatch, the clear, consume, `combined`,
PendingLoading, `finish`.

## Tests it needs

A menu-session oracle (lane vs `step` with scripted replies: not due, due,
catch-up, World 1/2, first load, undefined words, a failure at each request, a
refused clear; comparing outcome or error, the request log and every field of
`pending`, and resuming the continuation); a two-Host runtime oracle like
`testIdleKernelMatchesTheWholeStep` through a match (lane on vs off, clock
failures, request bounds 3–6, a failing clear, a throwing
`beforePublication`); a mixed-cursor unit test; the runtime, Host and
observed-iteration suites; an independent review.

## Increments

H3a (plumbing, no behaviour change): the mixed cursor and the shared surface
closure. H3b (the lane): the menu-session lane and helpers, the Host's loading
arm, the runtime flag.

## Decision

Recorded; like H2, its ~0.15 ms is near what the phone resolves and needs a
large oracle. Both stay candidates after cheaper steps of similar size.
