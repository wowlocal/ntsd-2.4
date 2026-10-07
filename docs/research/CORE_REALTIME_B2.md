# RT B2 — in-place nested passes under the first transactional copy

Study: [CORE_REALTIME](CORE_REALTIME.md); context: [TIER2](CORE_REALTIME_TIER2.md)
section B. A static plan by a read-only planner on 2026-10-07 (nothing built
or run). Abbreviations: HS HostSession, LC LoadedCycleSession, GS
GameplaySession, GB GameplayBody, LMC LoadedMatchCycle, PDL
PostDrawLifecycle, PSP PostDrawSlotPrefix, PDO PostDrawOpoint, RL
MacRuntimeLoading.

## Key finding

The outermost transactional copy at each level costs no extra buffer copy:
its source (`entry.match`, `owners.match`, `entry.state.memory`) is already
shared with what the Host keeps for retry, so the first write copies anyway.
The waste is in the second and deeper copies, each re-copying what its
caller already made unique (the 0xb440-byte globals and mask, the 400-entry
actors array, an actor record). No public contract of LC, GS, GB, LMC or
LoadedMatchEntry changes; only calls beneath those copies move to in-place
variants.

## Discard proof (summary)

A gameplay tick's loaded cycle runs in HS `prepareLoadedUntilBoundary`
(HS:342, `prepared` set only at 378, `pending` kept on throw) and the
gameplay body in HS `resumeGameplay` (HS:404; `prepared` unchanged on
throw). Below them: LC `advance` (locals, commit at 63), LMC `run` (commit
27), LoadedMatchEntry `run` (commit 34, sub-steps at 21–32), GS `advance`
(commit 205), GB `apply` (commit 261), PDL (commit 85), the per-slot prefix
(PSP:91–94) and opoint (PDO:49–52), the scheduler (PSP:228–235). Every level
drops its locals on throw; no catch-and-continue exists in the chain. The
transactional forms stay for the tests, reference checks and other
production callers that pin them (InputSession:102, InitialMatchEntry:31,
the post-draw, scheduler, control, physics, links, contacts and commands
suites, the ActiveGameplay and LoadedCycle application tests, the replay,
input, round, menu-cycle, body, lifecycle, AI and object-input references).

## Mechanism

An allocation-free placeholder `OriginalStateRecord.vacant` and a
`take(_:leaving:)` helper; each `XInPlace` variant moves the caller's fields
into the pass (uniquely held), runs the unchanged body and writes them back
in a `defer` (on throw the caller holds that call's partial writes, which it
discards); each existing function becomes copy → in-place → assign (same
errors, order and rollback as today). `finishReplayInput`: `runReplayInput`
is already the in-place body; likewise `runMatchRound` and
`runInputControl`.

## Invariants

1. Same return values, events, event order and final values on success.
2. In-place variants only where the caller drops its value on throw, never
   inside a catch-and-continue or `try?`.
3. Every taken field is written back on every path.
4. No closure passed into a pass reads the caller's taken storage.
5. Mutation only through value-typed fields (the Host's retained copies stay
   protected by copy-on-write).
6. The transactional wrappers behave exactly as today.

## Tests

Per variant, injected throws at the k-th observer event, `header`/`frame`
call or a corrupted byte, wrapper vs in-place on whole-match fixtures (same
error and events; the wrapper's inputs unchanged; equal outputs without a
throw); application-level stops at each lifecycle/hits/contacts event,
checkpoint stage, entry checkpoint and replay/round event with the retained
state unchanged and a retry equal to the uninjected run; a copy probe
(`storageIdentity` of the candidate globals constant through a phase); all
existing gates.

## Estimates (A12, 1% ≈ 0.23 ms)

Post-draw prefix/opoint/scheduler ~0.55–0.8 ms; `finishReplayInput`
~0.2–0.35 ms (only its globals copy goes); the rest of the entry chain
~0.2–0.3 ms; GB's other passes ~0.25–0.7 ms. ~1–2 ms on paper; past steps
delivered a third to a half of static estimates.

## Pieces

P0 the placeholder and helper; P1 post-draw prefix, opoint, scheduler and
lifecycle in place; P2 the loaded entry chain; P3 CharacterAI and
ObjectInput (RL dispatch children); P4 GB's passes family by family, ordered
by a fresh profile; P5 (optional) LC/GS-level variants. Each piece: its
tests, the scenarios, a phone profile, a ledger row; an independent review
of the discard proof per switched site, the `defer` write-back, closures not
reading taken storage, exclusivity at the scheduler call, wrapper error
order and `package` visibility.
