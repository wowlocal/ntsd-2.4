# RT M2 — serving the message loop's queue requests inside the attempt

Study: [CORE_REALTIME](CORE_REALTIME.md); copy map:
[CORE_REALTIME_COPIES](CORE_REALTIME_COPIES.md). A static design by a
read-only planner on 2026-10-06 (nothing built or run); counts to be confirmed
by measurement before and after.

## Today

`OriginalMacRuntimeMenu.step` (RM:126-200) builds a `Driver` and loops
`driver.resume`. `OriginalApplicationObservedIteration.resume` (OI:94-158)
takes a permit cursor over the exchange's receipts (OI:104), installs it in the
staged platform (OI:111) and runs `HostSession.step` (HS:211-246: platform
copy, prepare, `var next = application`, commit at HS:239). An unrecorded
request throws `RequestNeeded` from the cursor (RequestExchange:73-78), the
whole attempt unwinds, OI claims a permit, RM counts it (`requests`,
`lastRequest`, RM:131) and serves it (`.queue` through
`messages.serve(permit,on:driver)`, RM:149, Messages:244-254), and the next
`resume` replays the receipts.

A gameplay tick asks, in order: `peek` (ML:88, empty queue), `time` (Timer:19)
and `time` (Timer:20, a third past 100 ms), then the dispatch entry's surface
`blt` (DispatchEntry:55-58 → MS:410 → `.graphics(.window(blt))`, served by
`front.serve`, RM:148), then world+0 == 2 returns `.loading` (FrontMenuLoop:22).
That is 4–5 requests, so **5–6 runs of the attempt per tick**. Production
passes no observers (RM:129), so the discarded runs have no visible effect;
the "captured" event reports `permits`, `textRequests` and `emptyBlits`
(RS:318-319) and the boundary event `lastRequest` (RS:672); app_e2e does not
compare `permits`.

## Design

- **Exchange:** `Cursor.inline` returns `Receipt?` (nil suspends as a permit
  cursor does); a new `inlineCursor(accepting:serve:)` checks `accepts` before
  claiming (a claim cannot be undone) and hands the server the exchange, not
  the driver; the existing `inlineCursor(_:)` keeps its behaviour.
- **OI:** `resume(…, inline: Inline? = nil)` with `Inline { accepts; serve }`.
  The cursor is stored in the candidate platform (committed, kept in
  `pending`, copied into DeliveryContexts, kept in `iterationDelivery.earlier`
  while its receipts hold resources), so the server is reached through a gate
  object that the attempt disarms on exit; stored cursors then suspend and do
  not keep the runtime alive.
- **Re-entrancy:** the server uses only the exchange (its own lock is free
  during `serve`); it must not call the driver or Host APIs (they throw
  `reentrantAttempt`) or touch the candidate platform.
- **Messages:** `serve` splits into a private core with begin/answer/fail
  closures and two entry points (`on driver:` and `on exchange:`), as the front
  service already does.
- **RM:** the inline server accepts `.queue` while `served + 1 <
  maximumRequests`, counts `requests`/`lastRequest` as the permit arm does and
  serves through the exchange; the permit arm is unchanged; the max-th request
  still goes through the permit path, so the request bound is reproduced.
- **Not `.windowDefault`:** it carries MessageBoxA, Release, ShellExecuteA and
  WM_NCDESTROY (host callbacks while the Host attempt is in flight) and never
  occurs on a gameplay tick.
- **M2b (separate):** also serve the window `blt` inline (one run per tick).
  It matches the dispatch entry's back-buffer clear in every iteration,
  ArtSetup's clear on the first iteration and the Alt+Enter configure step's
  clear; all take the permit arm's generic graphics service with no counter of
  their own, and their target is always the back buffer (word 0x455608, a
  backbuffer surface), so the work moved into the attempt is a render-queue
  flush and a fill: nothing is presented. Reviewed separately: OK.

## Why results stay identical

The attempt is a deterministic function of the committed state, the prepare
inputs and the receipts. The single inline run's prefix up to request k equals
today's run k, so it issues the same request at the same ordinal; it is served
by the same code with the same runtime state (discarded runs have no runtime
side effects). Receipts, replies, order, committed state and batches are the
same; counters advance once per served request in the same order. A failing
inline serve records the same failure on the exchange (indeterminate) and the
same error reaches RM and the session's boundary event; retries replay inline
receipts without serving again. Only timing differs: real-clock samples come
closer together (virtual-clock runs are identical), and the prepare inputs,
including the Mac's live Caps Lock state, are sampled once per resume instead
of once per discarded run. One deliberate deviation: a negative
`maximumRequests`, which crashed the old `0..<maximumRequests` loop, now throws
`requestBound` (no caller passes one).

## Review (2026-10-06)

Independent read-only review: correct; no case found where the inline path
differs from the permit path (bounds for every value, cursor bookkeeping, the
gate on every exit, locking, errors, observers). Its test findings were acted
on: the side-by-side test now proves requests were served inline (fewer
prepares through a counting Caps Lock callback), compares a per-step digest
of the committed globals, the bounds 0, 1 and 2, and a failing clock in both
modes. Gameplay ticks are covered by the 10 scenarios, whose references were
recorded with permit service.

## Tests and plan

Pinned today by ObservedIterationTests:99, MacRuntimeLoadingTests:187/:217,
IterationDeliveryTests, MacRuntimeMenuTests:47/84/132/181/226 and the
re-entrancy tests (HostSessionTests:58, WindowStartupTests:225). New: exchange
`accepting` tests (accepted kinds served, declined kinds suspend at the right
ordinal, a failing serve equals the permit path's failure, a disarmed gate
suspends and releases the server), OI side-by-side (receipts, batch, status
equal; fewer resumes; no re-serve on late-failure retry), RM side-by-side
(counters, delivered messages, sleeps, clock calls, batches, frames over menu,
START and gameplay cycles), failure (a throwing clock, small request bounds).
Plan: count runs per tick first, then M2a with its tests, the card's gates and
an independent review, then M2b.
