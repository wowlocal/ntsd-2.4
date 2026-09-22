# Typed host Start and launch candidate

**2026-09-22: isolated implementation complete; syntax parse passed.** This
candidate adds host retention of the actual Start child and staged platform,
then the existing launch result, before one enclosing application publication.
It has not been typechecked, compiled or run. Independent review and Native
comparison remain open. Root Native is unchanged.

The [frozen plan](APPLICATION_HOST_MATCH_CANDIDATE_PLAN.md) implements the
[preflight contract](APPLICATION_HOST_MATCH_PREFLIGHT.md). Base HEAD is
`a8725aa28491256eaa9efc4307a22c1a8bd68b64`; actual baseline is the1037-file
round3 host candidate validated by the retained42-method result. The separate
initialized catalog branch was not merged. Reference EXE SHA-256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
This task reads original evidence and edits Swift; it does not execute the
original, historical producers/auditors, a device backend or any refused path.

[Publication](../evidence/application-host-match-candidate.json),
[reviewable patch](../evidence/application-host-match-candidate.patch),
[closure](../evidence/application-host-match-candidate-close.json) and
[documentation checks](../evidence/application-host-match-candidate-docs.json)
identify the exact tree, process records and archive. The external frozen task is
`build/research/application-host-match-candidate-20260922`.

## Implementation

Only HostSession changes in Core. Its private prepared slot is an enum with a
returned child/platform or a match-prelude child/platform. Both keep the original
pending prefix owner. `preparedMatchPrelude` exposes a value snapshot;
`preparedPlatformSnapshot` still returns an independent platform copy, and
`preparedLoadedMenu` is nil while Start is retained.

`prepareLoadedMenuUntilBoundary` runs the existing provider with the actual
LoadingContext and cloned pending platform. Both outcomes check exact loading
attempt identity and State aliases; returned children also need returned exit
and a dispatcher result. The final observer precedes retention. The old
return-only API uses this same private implementation under one in-flight guard.

`resumeMatchLaunch` accepts no replacement Start argument. It supplies its own
retained Start and cloned platform to the provider running MatchLaunchSession.
The returned child must carry the same attempt, valid aliases and returned exit/
result. After the final observer succeeds it replaces Start/platform with the
returned child/platform. A throw leaves the prior Start available for retry.

`finishLoadedMenu` accepts only the returned state, clones its platform and uses
the existing Bootstrap tail. Success installs Bootstrap/platform and publishes
one `.loaded` batch; a throw retains the completed child for a tail-only retry.
All new methods use the existing lock/in-flight guard. Missing/wrong stages,
repeated preparation/completion and callback mutation/handoff reentry reject.
The private ticket nonce, Bootstrap prefix checks, game child handlers, timers,
numerical semantics, resources and comparators are unchanged.

Providers remain restricted to independently staged platform state or local
value owners. This API does not perform host IO or establish physical delivery,
crash recovery, actual clocks, window/input/audio or a shipping backend.

## Test implementation and preserved comparisons

Four test paths change: a new LoadedTestDriver, the two existing character/
selection chain runners, and three new HostMatchLaunch methods. Total candidate
membership is1039. The new driver transports the same full parent comparisons
through either the original Bootstrap route or a host created by the existing
whole-input parent. It never installs a reconstructed Bootstrap into a host.
Host keys use the current controller settings and checked WndProc request/
response, followed by the actual pending loading context and input child.

The default character test and all later character helpers/controls retain exact
source text. The two old selection methods also retain exact source text.
Mechanical checks preserve the complete character comparison body (only its
test-parent variable changes), and the selection body apart from moving outer
commit/repeated-completion/onStart transport outside the preparation callback.
All phase checks, source/body/mask/RNG/resource/present/graphics assertions remain.
OnStart now runs after the full graphics comparison and host retention, avoiding
callback reentry. Launch comparison itself is unchanged.

The frozen53-method selection contains all50 existing preflight methods and:

- `testActualHostStartLaunchAndNextInputRetainWholeOwners`: both backings through
  startup/loading, cached returns,34 human and50 selection screens; retained
  Start, full launch comparison, outer publication and actual next input. The
  next gameplay input is inspected inside the host context with an explicit
  observer stop, not claimed as a completed tick or retained gameplay body.
- `testStartLaunchAndOuterTailFailuresRetainHostStages`: four preparation/Start
  failure points,17 launch/preparation-observer controls and three outer-tail
  controls. Full committed/retained State and platform checks, copy independence,
  retry and an earlier undrained loaded batch are included. The earlier batch's
  full comparison uses its own committed snapshot when eventually consumed.
- `testMatchPreludeRejectsDifferentTicketsAndReentry`: actual independently
  produced foreign and same-revision sibling Start/launch results, typed
  preparation rejection, launch-result rejection and reentry. After completion,
  consumed calls reject before a provider; a new pending loading rejects stale
  Start/return values, while launch without a retained Start rejects by stage.

All source expectations are immutable. Own application RNG/path projections,
installed-library state, full replay buffer, resource generations and operation/
graphics order remain in the existing comparators. Controlled sibling/foreign/
failure inputs are Native controls, not new original game-reachability evidence.
No test result is claimed by writing these methods.

An author draft used an early-chain literal for the late commit-failure clock.
Static inspection showed that after the longer menu chain it could be before the
current baseline and select Sleep. The final test uses the retained baseline+1000,
as the established normal outer completion does. The old draft and diagnosis are
preserved; no source literal or expected result changed. Host keyboard response
checks and explicit outcome-array typing were also added before the sole parse.
No runtime failure was observed in that draft because it was not executed.

## Checks, storage and next gate

Preparation PID53039 completed with exit0 in2.629s. APFS clones were regular,
distinct-inode files with all1037 baseline bodies/modes verified. Syntax parse
PID54978 completed with exit0 in0.101s, an empty diagnostic log and verified
process absence. It used the installed Swift frontend, minimal environment and
the five exact changed files. Parsing proves neither Swift type correctness nor
the declared runtime behavior.

Finalizer PID55198 completed with exit0 in7.413s. Root1034, prior candidate1037,
new candidate1039, all385 fixture/102 runtime-resource files and source55 pins
were verified by body/mode/membership. The44,304-byte patch round-trips onto the
baseline exactly. A24-member686,080-byte metadata/changed-file archive was read
back by complete member/body/mode/nanosecond-mtime; it includes preserved draft
files. This is a candidate archive gate, not a built-package verification.

The task froze within its1GiB allowance: observed external decrease236,072,960
bytes including concurrent source growth. Closure free space was161,269,678,080
external and66,567,090,176 internal, preserving40GiB/6GiB reserves. Live source
PID59727 was revalidated at17:43:07 UTC:2905 chunks,20 Objects,712,266,578 stores.
It remains the same original capture, not a whole-catalog result or a restarted job.

Next: a separate bounded fresh build, all53 selected methods, regular package
byte verification and archive readback. Freeze its resource contract first using
the prior whole-parent RSS/timeout observations; stop at the first nonpass and
retain any failure. The current42-method pass applies to the previous candidate,
not this changed host. Author inspection is not independent review. Root
promotion, whole source comparison, later typed gameplay outcomes, device/Windows/
clean-Mac/full-match acceptance and the complete game remain open. Existing
safety incidents, including the separate round-result/replay-writer path, remain
unresolved. The EXE envelope was not recalculated.
