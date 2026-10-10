# Core real-time, tier 3 H2: one fused loaded Host attempt per tick (design)

A read-only design (2026-10-10, nothing built), recorded before deciding the
order of the remaining work. [Tier-3 plan](CORE_REALTIME_TIER3.md), row H2.

## Verdict

Sound without a user decision, but worth about **0.15 ms per tick (range
0.1–0.2)**, not the plan's 0.3–0.5. Only the platform copies and the Host's
per-attempt overhead can go. The State, Bootstrap and menu-session copies each
hold a value that must survive a failure; merging them is what the user
decisions Q1/Q2 would allow.

## One loaded gameplay tick today

| # | Attempt | Copies | On success | Left after a throw |
|---|---|---|---|---|
| 0 | due tick `step` | platform, Bootstrap `next` | `pending` = (loading, inputs, candidate) | unchanged |
| 1 | `prepareLoadedUntilBoundary` | c1 = copy of the pending platform; the loaded cycle's State (S2); a throwaway gameplay session | `prepared = .gameplayInput(Ready, c1)` | `pending` |
| 2 | `resumeGameplay` | c2 = copy of c1; the gameplay session again; the body's attempt and State copies (S3) | `prepared = .returned(PendingReturn, c2)` | `.gameplayInput(Ready, c1)` |
| 3 | `finishLoadedMenu` | c3 = copy of c2, Bootstrap `next`, the menu session, the staged State (S4); the context shares c3 (L5a) | application, platform = c3, `prepared`/`pending` cleared, a batch | `.returned(PendingReturn, c2)` and `pending` |

Observed by `OriginalApplicationHostGameplayTests` (phase-1, body and tail
failures and retries), `HostLoadingTests`, `HostMatchLaunchTests` and
`HostDeliveryContextTests` (copy failures in the tail; only the shipping
platform is shared).

## The fused attempt

`advanceLoadedTick(cycle:body:perform:observesCommit:)` in one `attempt {}`:
phase 1 (prepareBoundary's body), phase 2 (the body, its validation,
`prepared = .returned`), phase 3 (the Bootstrap finish, the context, the
commit). Each phase's candidate comes from `retained(_:)` (the same object for
the shipping platform, a copy with today's failures for test platforms), and
`prepared` is assigned at every boundary, so every field, mid-attempt getter
and retained stage equals today's. Callbacks receive no platform, which keeps
the sharing sound (as L5a). A `.matchPrelude` returns after phase 1. The
three existing methods stay for retries; the fused one refuses a Host that
already holds a prepared stage.

Goes: three platform copies per tick (~1%), two attempt entries, re-bindings
and impossible checks (~0.15%), one gameplay-session build (~0.05%).
Stays (needs Q1/Q2): S2 (retained on a body failure), S3 (in the batch's
`LoadedCommit.menu`), S4 (committed), Bootstrap `next`.

## Tests it needs

A two-Host oracle (old three phases vs fused) over the neutral, active and
paused sequences with failures injected in every phase and at copies 1–4,
comparing the error and every observable Host field after each step, then
retries through the old phases compared with `checkFinished`; the Host,
loaded-cycle, loaded-menu, paused, active-output, projection and runtime
suites; a Mac A/B (B3a removed work and still measured slower on the Mac); an
independent review.

## Decision

Deferred behind H3 (a fast lane for the due tick's step, about 1.0 ms of cost
today, also no user decision), which has the larger pool for similar effort.
