# Host ownership across Start and match launch

**2026-09-22: bounded read-only preflight complete.** The next candidate can
extend the validated host from returned menus to the existing typed Start and
launch children. The missing part is host retention and staged platform ownership;
the child implementation already continues Start through the true outer return.
This is static analysis, not a newly reproduced failure or Native comparison.
Independent review remains open.

The [frozen plan](APPLICATION_HOST_MATCH_PREFLIGHT_PLAN.md) follows the
[42-method loading result](APPLICATION_HOST_LOADING_REGRESSIONS.md). Actual input
is its unchanged round3 candidate1037, not HEAD alone or the separate initialized
catalog candidate. Base HEAD is `c65662191bf7a587e059b88f619057d7ab561c40`.
[Context and pins](../evidence/application-host-match-preflight-context.json),
[saved fixture inspection](../evidence/application-host-match-preflight-fixtures.json),
[contract and exact method selection](../evidence/application-host-match-preflight-observations.json),
[read diagnostics](../evidence/application-host-match-preflight-diagnostics.json)
and [verification](../evidence/application-host-match-preflight.json) retain the
inputs and checks. No original execution, Native build/test, device IO or
historical producer/auditor ran. The EXE envelope was not recalculated.

## Actual continuation and ownership

The current `OriginalApplicationHostSession` keeps the actual loading ticket,
prefix packet and independently staged platform. Its `Prepared` stores only a
`LoadedMenu.PendingReturn`. `prepareLoadedMenu` checks exact attempt identity,
returned exit/result and state aliases, then retains the child/platform without
publication. `finishLoadedMenu` clones that platform for the outer timer/Sleep
tail and installs Bootstrap/platform/one complete loaded batch only on success.
The already verified prefix exhaustion and ticket nonce must survive unchanged.

`LoadedMenu.advanceUntilBoundary` also has a second, supported child outcome.
After the current selection body reaches `0x42cf8a`, it retains:

- The same input continuation and loading ticket, including the suspended loop.
- Full current State and match, library command/text state, menu/background
  owners, music allocations, scratch record and selection semantic locals.
- Confirmation and the cumulative operations/graphics already produced.

That `PendingMatchPrelude` is an unreturned Start. The held clear, presentation,
preparation and outer tail have not run. The return-only `advance` intentionally
rejects this outcome transactionally; its error is not a completed menu or a
shipping continuation mechanism. The host currently cannot retain the typed
outcome through its public preparation method.

`OriginalApplicationMatchLaunchSession(pending:)` is the next consumer. It
validates aliases and requires the installed-library owner. Its `Menu.Attempt`
initializes State/match/music/menu resources/backgrounds/local/journals from the
retained Start snapshot. The original input chain supplies stable identity and
resource provenance; it does not reset the live match to the earlier input state.
Existing live allocations, file buffers and sound/music storage are reserved
before new arena/replay identities are claimed.

The child runs prelude, installed-library preparation, enabled music, inactive
Actor/input-reset tail, replay initialization, remaining menu, presentation and
held clear. It returns an ordinary `PendingReturn` carrying the same loading
attempt. Its environment/session assignment occurs only after the final child
observer succeeds. This value-copy transaction alone does not deep-copy a class
platform: the host must clone the platform before invoking it.

`Bootstrap.finishLoadedMenu` delegates to the actual MenuSession. That owner
checks Session UUID/revision, returned outcome and aliases; it resumes the
ticket's retained loop preparation, records time/Sleep, merges the counter alias
and calls the last observer before replacing State/loop/loaded owners. Core's
owner/revision check does not distinguish sibling tickets at the same revision;
the host's existing `isSameAttempt` check is required on both new outcomes and
the launch result. No new identity is a game RNG draw, clock or resource token.

## Evidence and boundaries

Four complete raw-DEFLATE outer envelopes passed their declared size and SHA
checks:34,579,061 decoded bytes. Inner blobs were not separately reinflated in
this preflight. The existing comparators retain their whole-record/blob checks;
this inventory is not a rerun of them.

Each selection corpus has50 cases,49 returned children and one pending Start
at index49. That last case has15 body checkpoints, ends at`0x42cf8a`, has no
returned record and retains locals32/40/52/56=0,60=3. Both launch corpora have
eight sections: prelude, preparation, music, preparation-tail, recording,
menu-continuation, returned and gameplay-entry. Their declared local time is
2026-09-09 12:34:56.789, day-of-week3; it is a controlled input, not host time.

Historical [character](APPLICATION_LOADED_CHARACTER.md),
[selection](APPLICATION_LOADED_SELECTION.md) and
[launch](APPLICATION_LOADED_LAUNCH.md) comparisons establish the finite child
composition. They do not establish the proposed host extension on current files.
The selected application path preserves its own RNG table: inactive ordinals
36/37/32/41/18/31 and `bgm\stage5.wma` differ from the pristine source's
24/38/39/32/22/36 and `bgm\boss2.wma`. The independent projection and original
event order remain required; neither snapshot supplies Native state.

The installed application launch checks its own four RNG draws177/53/189/18,
human X240/240 and Z503/468, all18 replay participants/234 array words,3001 RNG
bytes and the full6,491,672-byte recording buffer. It retains library requested
Object ID as unknown until the actual setter establishes it. Source execution
and device/resource replies keep the declared boundaries in
[MATCH_LAUNCH](MATCH_LAUNCH.md), [MATCH_PRELUDE](MATCH_PRELUDE.md),
[LIB_STAGE_COMMANDS](LIB_STAGE_COMMANDS.md),
[MUSIC_PLAYBACK](MUSIC_PLAYBACK.md) and
[REPLAY_INITIALIZATION](REPLAY_INITIALIZATION.md).

The next gameplay input is an acceptance observation of the returned owners:
phase1, ten zero command bytes, recording checksum1000 and tick1 before`41e339`.
It is not a completed gameplay tick. Host retention of that different input-body
outcome remains a later extension; this task must not turn a thrown observer
into a claimed gameplay return.

## Concrete next candidate

Use a new isolated copy of actual candidate1037. Extend the existing host only;
preserve the old return-only API and its42 regression methods. No root promotion,
new game rule, source fixture or comparator relaxation is needed.

1. Replace the private returned-only preparation slot with mutually exclusive
   typed states for returned child/platform and Start child/platform. Keep the
   pending prefix owner throughout. Add a value inspection accessor for retained
   Start; platform inspection must still return an independent copy. The existing
   returned-child accessor is nil while Start is pending.
2. Add `prepareLoadedMenuUntilBoundary` using the existing LoadingContext and
   staged prefix platform. Its provider returns `LoadedMenu.Outcome`. Both arms
   validate the exact ticket and aliases before the final preparation observer;
   the returned arm also requires returned exit/non-nil dispatcher result. Store
   exactly that outcome/platform, publishing nothing. The old return-only method
   remains available; shared internals must not accidentally trigger reentry.
3. Add `resumeMatchLaunch` using only the privately retained Start and a deep
   clone of its platform. Pass that actual child to the existing MatchLaunch
   constructor/advance through explicit providers. Do not accept a replacement
   Start argument. Validate the resulting returned child's exact ticket, aliases
   and exit/result, then the final preparation observer. Success replaces the
   Start slot with the returned child/platform. Failure preserves Start/platform
   so another launch attempt does not replay character/selection/input work.
4. Keep the existing outer completion path for the returned child. A failed time,
   Sleep or final observer preserves that completed child/platform, so retry does
   not rerun prelude, resource loading, music or replay initialization. Only outer
   success clears pending and publishes one full `.loaded` batch. Never publish
   the prefix, Start, launch or overlapping graphics view separately.

All methods remain under the existing lock/in-flight guard. Reject preparation
over either prepared state, launch without Start or after successful launch,
finish with only Start, repeated completion and mutating/handoff callback
reentry before provider IO. Earlier queued batches and committed snapshots must
survive every failure. Callbacks may change only their independent platform or
local value owners; captured mutable providers and actual IO are outside this
preparation contract. Public child values are inspection/results, not permission
to replace the host's retained owner.

## Finite acceptance selection

The observation receipt lists50 exact existing methods: all42 host/loading
methods, both owned-character, both owned-selection, both owned-launch and both
direct whole-launch methods. Add three new host methods (53 proposed total):

| New method | Required observations |
| --- | --- |
| `testActualHostStartLaunchAndNextInputRetainWholeOwners` | Both backings through actual host startup/loading, three cached returns,34 human screens and50 selection screens; retain Start; launch and finish once; inspect next actual gameplay input through the current host context |
| `testStartLaunchAndOuterTailFailuresRetainHostStages` | Preparation/Start observer failure; launch local time, sound, last bitmap allocation/create/color-key, music, reset-input, replay allocation/recording, presentation/clock/held-clear and final observer controls; then time/Sleep/outer commit failure with successful retry of each retained stage |
| `testMatchPreludeRejectsDifferentTicketsAndReentry` | Actual different same-revision, foreign, stale/consumed ticket controls for both typed preparation and launch result; stage misuse and callback reentry; earlier queued batch survives; platform snapshots are independent |

Use the current host from `HostLoadingTests.atLoading`, which first completes
the whole source-parent comparison. Acquire subsequent keys through current
controller configuration and Host.step. Factor the existing character/selection
runner only enough to use host ownership while keeping every current whole-body,
write-footprint, mask, RNG/event, present, journal, graphics and outer-return
assertion. Never inject a Bootstrap snapshot or manufactured Start as the natural
parent. Existing deliberately controlled repeat-launch tests remain controls.

Successful launch must reuse `LoadedLaunchTests.compare` and its full current
resource/replay/state checks. Check both the retained platform and committed
platform after injected failures, callback counts showing that completed stages
were not replayed, and full `LoadedCycleTests.checkFinished` after outer commit.
Use Boolean presence assertions for these large retained children; earlier
XCTest reflection/time/RSS failures remain immutable.

Before execution, freeze candidate inputs, exact methods, build/package/archive
commands and resource bounds. The previous8GiB guards demonstrate that a whole
parent can exceed that limit; choose and justify limits from the retained Q/R
observations, not silent retries. Fresh compilation of changed Core/dependents,
Native comparisons, package verification and archive verification are separate
gates. The proposed53 methods have not run in this preflight.

## Preservation and remaining work

Seventy initial consulted pins identify the actual inputs. Sixteen consulted
candidate Swift files equal the root baseline; seven are changed/additional host
integration files and were read from the candidate. Root1034, candidate1037 and
source55 were checked, with a final preservation receipt. A guessed closure
filename failed during read-only context assembly after the initial preservation
checks; the exact error is retained and the actual `external-close1.json` resolved.
No original or Native operation was attempted by that error.

Author inspection is not independent review. Whole initialized Catalog53 source
comparison, root promotion, generic retained gameplay/input outcomes, backend
effect delivery/failure recovery, real window/input/audio, Windows, clean-Mac and
the complete game remain open. Replay initialization here does not retry or close
the blocked round-result/replay-writer dependency. The same live source process
continues without restart. Next task: the isolated typed host candidate above.
