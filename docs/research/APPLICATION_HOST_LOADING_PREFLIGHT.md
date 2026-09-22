# Host loading continuation contract

**2026-09-22: bounded code and saved-evidence analysis complete.** The next
implementation can connect the validated host's actual pending loading to the
existing loaded-menu commit. Two host integration gaps must be covered: exact
pending-attempt identity and exhaustion of the loading prefix's reply packets.
Neither is a new original-game rule. They are static findings, not reproduced
Native failures. Independent review remains open.

The [frozen plan](APPLICATION_HOST_LOADING_PREFLIGHT_PLAN.md) follows
[host validation](APPLICATION_HOST_TRANSACTION_VALIDATION.md). This advances
startup-to-loaded-menu ownership toward the first interactive match.
[Context](../evidence/application-host-loading-preflight-context.json),
[fixture inspection](../evidence/application-host-loading-preflight-fixtures.json),
[scalar observations and supplemental pins](../evidence/application-host-loading-preflight-observations.json)
and [verification](../evidence/application-host-loading-preflight.json) identify
actual inputs and checks. Base HEAD is
`12d80fcb4da9eb68088e7be97aa61113519474c5`; the input is its separately pinned
dirty root and validated host candidate, not HEAD alone. No implementation,
original execution, Native test/build, device IO or historical audit ran here.

## Actual owner chain

`HostSession.step` clones the committed platform before preparing input. At
`.loading`, it retains the exact `Session.PendingLoading`, immutable input packet
and tentative platform. The committed Bootstrap/platform and published batches
remain unchanged. The private pending owner blocks another outer step.

For first loading, the existing chain is:

1. `PendingLoading.makeLoadingSession()` and `prepareCommon` retain the original
   ticket, target, globals/masks, common WAVs, prefix operations and graphics.
2. `OriginalApplicationCatalogSession` consumes that `PendingCatalog` and actual
   startup sounds/music, then produces `PendingPool` using original package data
   and explicit provider replies. No reference snapshot supplies live state.
3. `OriginalApplicationPoolSession` constructs its Actors/interface and produces
   `PendingInput`. `OriginalApplicationInputSession` retains that parent and runs
   the input/round decision, yielding `PendingContinuation` with the same loading
   entry, match, input context, music, commands and journals.
4. `OriginalApplicationLoadedMenuSession` consumes that actual input child.
   Its returned result retains current State, match, music, menu/background
   owners, graphics and the original loading ticket. A Start/prelude boundary
   remains a different outcome; it must not be labeled a returned menu.
5. `Bootstrap.finishLoadedMenu` delegates to the originating MenuSession and
   installs its returned owner. The caller must also install the staged host
   platform and publish the resulting batch as one host transaction.

The chain is already exercised by `OriginalApplicationLoadedMenuTests` and the
Bootstrap parent in `OriginalApplicationLoadedCycleTests`. Their historical
43/51-method results establish their declared Native composition scope, not a
new whole-original application trace or actual host backend. In particular, the
full Native catalog uses declared clocks and mapped resource replies; the
initialized whole Catalog53 source is still an independent open comparison.

After the first loaded commit, `Session.loadedOwners` contains current match,
music, menu resources and backgrounds beside live State/loop. On another actual
World2 suspension, `Bootstrap.makeLoadedCycle(pending:)` uses these current
owners. `OriginalApplicationMatchBindings` refreshes records from current State
while retaining mutable frames, arenas, release history and arithmetic precision.
It does not rerun common sounds/catalog/pool/UI or republish their old journal.
`OriginalApplicationInputSession.PendingContinuation` explicitly substitutes the
new loading ticket for the historical pool entry in this path.

## Final commit and two integration gaps

Core rejects foreign Session UUIDs, stale revisions, consumed results and
unreturned menu outcomes before the outer tail. It validates State aliases,
resumes the retained `Loop.PendingDispatch`, appends final time/Sleep operations,
merges the counter alias and runs the final observer. Only then does it install
State, loop, incremented revision, loaded owners and the value-owned environment.
Earlier startup data stays historical. The loaded operation journal already
contains the pending prefix and child work; graphics is an overlapping view.
Publishing either prefix separately or an additional ordinary iteration batch
would duplicate work.

**Exact attempt.** `PendingLoading` currently records only a fileprivate Session
UUID and revision. Copying the committed Session preserves both. Two separate
`step` calls on such copies can create different pending tickets at the same
revision. The existing foreign/stale tests do not distinguish those siblings.
The host exposes a value snapshot, so its extension must retain and check an
opaque identity for the exact suspension, carried unchanged through children.
A private per-suspension UUID or identity token may serve this ownership purpose;
it is not a game resource, timer, source address or game RNG input. Copies of the
same ticket must remain valid, while a different same-revision ticket is rejected
before any outer callback. Core's existing owner/revision checks remain required.

**Prefix packet exhaustion.** Bootstrap checks queue/window/surface/lifecycle
array consumption only in its ordinary `beforeCommit` hook. Loading suspends
before that hook, so the corresponding exhaustion check is absent on that result.
Extend the common packet check to the loading return before the host retains it.
The input packet covers the executed prefix only; the final timer/Sleep replies
belong to the later continuation and must be acquired through that callback.
Do not silently discard unused entries or reuse an earlier clock as the tail.
Missing responses remain errors. A failed check leaves committed Core/platform
and any previous batches intact.

The generic Core environment copy does not deep-copy reference members.
Host Platform is a class: clone it using the existing `stagedCopy` contract before
each preparation and final-tail attempt. All mutable provider cursors, allocation
reservations and response state must reside in this independent platform or local
value-owned work. Existing Core `var candidate = environment` cannot substitute
for that host clone. Real IO and captured shared mutable providers remain outside
the permitted preparation/observer contract.

## Saved observations and numeric boundary

Three complete packed envelopes passed declared length and SHA verification,
totaling134,093,766 decoded bytes. No expected data was edited. Case47
`activate-parent-0` in the 50-case/47-parent input corpus reaches loading at
`0x41bc90`, SP`0x1000ea6c`, counter7. The final prefix calls Peek followed by three
time requests returning123456990. Its prior baseline is123456888; the retained
timer preparation applies the recovered lag reset and interval33 to obtain
123456923. The saved dispatch checkpoint independently records that value.

At the later loading stop the fixture's field named `baseline` is4557568
(`0x458b00`): the producer records the current ESI register there. This field
must not replace the suspended timer's prepared baseline. The original loop
continuation already retains the correct private timer state; no new clock rule
is inferred. Cases48/49 retain the same loading boundary with their declared
different replies. The fixture inspection preserves their raw field labels.

The menu-startup envelope ends at resource boundary`0x429e5a`:15 checkpoints,
11 allocations and11 final wrappers. The existing loaded-menu comparator checks
these full bytes/masks and independent graphics projection; the application
parent additionally needs its current background allocation. The menu-cycle
envelope has three returned cases and one retained next-selection boundary.
Their declared phase0/1/0/1 cadence is already compared by the loaded-cycle tests.
These corpora retain their controlled API/outer-ABI/keyboard boundaries.

The loaded-menu test's final reply123457923 and earlier Sleep(5) control are
declared Native stimuli, not a new Windows timing observation. Preserve lazy
menu-return time separately from background/panel and final outer time. An actual
host clock acquisition contract is still needed before app integration.

## Concrete next implementation

Use a new isolated candidate based on the validated1036-file host tree. Extend
the current host owner; do not introduce another execution framework:

- Add exact suspension identity and enforce complete prefix packet consumption
  on `.loading`. Keep existing owner/revision and ordinary-commit checks.
- Add a preparation method using the retained ticket, actual startup/current
  loaded owner and an independent copy of the pending platform. Invoke existing
  loading or loaded-cycle children through explicit provider callbacks. Validate
  the returned ticket, then retain the real `PendingReturn` and platform privately.
  This preparation publishes nothing and leaves the committed snapshot unchanged.
- Add final completion that consumes only this retained child, clones its staged
  platform, calls `Bootstrap.finishLoadedMenu`, and atomically installs Bootstrap,
  platform and one `Batch.Contents.loaded(LoadedCommit)`. Clear pending only on
  success. Tail failure preserves the prepared child for retry without rerunning
  the prefix, catalog, menu or prior effect handoffs. Reject repeated preparation,
  completion without a child and mutation/handoff reentry under the existing guard.

Use the existing same-parent construction and comparisons. The finite acceptance
groups are: first loading/menu return with both bitmap backings; three cached
loaded returns and the next selected input boundary without invented completion;
preparation failure with unchanged pending platform; time/Sleep/final-observer
failures followed by a successful retry of the same prepared child; foreign,
stale, consumed and different same-revision tickets rejected before outer IO;
and extra/missing prefix replies rejected without publication. Include copy
independence, unchanged prior batches, exact one-time loaded handoff, full
state/mask/owner/journal/graphics comparisons and existing late-child controls.
Do not accept an injected stop as a completed fourth loaded cycle.
The fourth input child and later Start/prelude paths still need typed host
retention in a subsequent extension; throwing and replaying them is not a shipping
continuation strategy.

Retain the existing25 host validation methods and loaded-menu/cycle regressions.
Because Bootstrap and ticket handling change, also include the five current
InitializedMenu/InitializedLoading methods; they were absent from the previous
25-method selection. Freeze exact method names and limits before execution.
Fresh compilation of changed Core/dependents, package verification and archive
verification are separate gates. Any new mismatch/failure remains immutable.

## Preservation and remaining gates

The context pins57 consulted files plus the1034-file root manifest and55 live
source pins; supplemental pins cover timer/producer inspection and initialized
tests. An initial filename-inventory assertion failed before writing context:
the exact output is preserved, and actual names were resolved by file search.
No original operation was attempted by that inventory failure.

Independent review of the proposed ownership changes remains unavailable.
Existing incidents, initialized whole-catalog comparison, other child outcomes,
live input/clock/resource providers, physical effect delivery/failure recovery,
callback reentrancy, raster/audio/window, Windows/device and clean-Mac acceptance
remain open. Root Native and closed tasks stay unchanged; the same Catalog53
process continues. The complete game goal is not redefined by this finite join.
