# RT phase 4 — per-tick copies of large values

Study: [CORE_REALTIME](CORE_REALTIME.md). Companion to
[CORE_REALTIME_DATAFLOW](CORE_REALTIME_DATAFLOW.md) (per-cycle data flow, Host
retry contract, R1–R6). A static reading of 86d5e5d plus the uncommitted 2c/2d
edits by a read-only analyst on 2026-10-06; counts are estimates from stored
fields, not measurements. Abbreviations as in DATAFLOW, plus OI =
ObservedIteration, ML = MessageLoop, PP = PreparedStartupPlatform.

## Why it matters

After phase 2d the Galaxy A12's main thread is 70% of the samples; reference
counting is 23% of it (swift_retain 12.3%, swift_release 10.9%) plus ~5% of
atomics. A Mac sample attributes reference counting by copied type:
OriginalStateRecord 3.4%, MenuSession 3.0%, Bootstrap 2.0%, FrontScreenEvent
1.4%, MenuPresentationMemory.Allocation 0.8%, HostSession.Batch 0.8%,
Graphics.Command 0.8%, MatchPreparation 0.6%, PendingContinuation 0.5%; by
site: `HostSession.step`'s attempt closure 4.8%, `PostDrawLifecycle.Body.run`
2.1%, `MatchBindings.store` 1.9%.

## The multipliers

- **`HS.step` runs 3–5 times per gameplay tick.** An unrecorded platform
  request throws `RequestNeeded` and unwinds the whole Host/Core attempt
  (OI:104-155). A gameplay tick asks for PeekMessage (ML:88) and one to three
  timeGetTime calls (ML:99, Timer:19-20), so two to four discarded runs repeat
  every Phase A copy.
- **Loaded-session data is copied ~40 times per tick.** `PoolSession.PendingInput`
  (built once, PoolSession:117, all `let`) holds about 250 retained
  references (PendingPool ≈180 with three more States and a catalog,
  InitialLoading ≈25, a State); MenuSession ≈330 and Bootstrap ≈350 are mostly
  that. About 10k of the ≈17k retains per tick in owner copies are its contents.

| Type | ≈refs | Mostly |
|---|---:|---|
| OriginalStateRecord | 2 (5 paged) | bytes, mask |
| MS.State | 40 | graphics (7 dictionaries), bitmapInputs, war, memory, transforms |
| OriginalMatchPreparation | 35 | catalog ≈14 (all `let`), background loader ≈6 |
| PendingLoading | 45 | State |
| PoolSession.PendingInput | ≈250 | PendingPool ≈180, InitialLoading ≈25, State |
| MenuSession | 330 | loaded owners ≈290 |
| Bootstrap | 350 | session, startup ≈20 |
| PendingContinuation / PendingReturn | 380 / 460 | PendingInput + PendingLoading + state + match |
| Platform `stagedCopy` | object + 45 | prepared (~27 arrays), inputs |

Required copies (the Host keeps the phase input until commit): one platform
copy and one `next` per attempt, the first write of the globals in each phase
(A–D), the outputs. Incidental ones: MenuSession copied only to pass `.state`
(HS:214), nested `var next = self` inside the Host's own tentative copy
(BS:90, MS:217, ML:74), Pending/Prepared rebinding (HS:305-307, 356-357,
376-377), `var cycle = context.cycle` (RL:326), a GameplaySession built only
to validate (HS:321), GS:66 copying the PendingPool to rebuild a constant set,
a State copy for a production no-op hook (MS:804), Batch/payload copies
(HS:134, RL:468). The DeliveryContext's platform `stagedCopy` is pinned by
copy-failure tests (HostDeliveryContextTests:159,180,242).

## Mechanisms (ranked)

1. **M1 — box the immutable loaded-session data** (largest, low risk). Move
   `PendingInput`'s `let` fields and `derived` into one `final class` storage
   with same-named read accessors (hot reads must borrow, not copy); then
   `PendingLoading`, `OriginalLoadedCatalog`, PP's `inputs`/`prepared`, and the
   built-once PendingContinuation/PendingReturn. Immutable data, none of them
   Equatable: results identical. Risks: Sendable, Mirror-based dumps, getters
   that copy. MenuSession ≈330 → ≈85 refs, Bootstrap ≈350 → ≈105; ~10k
   retain/release pairs per tick.
2. **M2 — serve the message loop's queue requests inline** (removes 2–4 runs
   per tick, medium risk): an opt-in inline server for `.queue` requests in
   `OI.resume` through `OriginalRequestExchange.inlineCursor` (already used at
   RL:228), suspending for any other request kind; the same requests, order,
   replies and records; check re-entrancy and the menu counters.
3. **M3 — drop the nested copies within one attempt** (the reference-count
   part of R5, low risk): pass `next.session!.state`, internal in-place
   variants of BS/MS/ML step and finish for the Host's tentative copy only,
   switch on `self.pending`/`self.prepared` in place, `consume` at LC:63, GS:201
   and in `publish`, cache GS:66's set in `PendingInput.Derived`. ~6k pairs per
   tick before M1, ~1.5k after.
4. **M4 — consume graphics in place per emitted draw** (LMS:207-211,
   MS:221-227): `state.graphics!.consume(...)` instead of copy-mutate-store;
   `consume` already copies itself before mutating, so throw points and
   results are unchanged. 14–21 reference-count operations per draw.
5. **M5 — skip the menu loop's work on gameplay ticks** (MS:412-756, when the
   world's +0 reads exactly 2): saves ~96 KB of allocation, copy and compare
   and a State copy per tick; needs a unit test comparing both paths.

Not covered: `PostDrawLifecycle.Body.run` (2.1%) and `bindings.store`'s
per-actor lookups (×400, twice per tick), next to R3.
