# Resumable whole-startup observations — implementation candidate

The candidate implements one ordered external request exchange across whole WinMain,
including window requests and16 nonwindow response families. The same Host retains
fulfilled replies/resources across retries and finishes the exchange only after the
last fallible publication copy. Production prepared mode is retained. Real macOS
clock acquisition is available outside Core; it has not yet been executed by this
candidate's whole-caller test. This is implementation with syntax checks, not a
validated live startup or a playable game.

[Finite plan](APPLICATION_OBSERVED_STARTUP_PLAN.md). Base e55e473 and the actual
2249-file frozen prepared-startup candidate; root1034 and pending catalog work stay
unchanged. Seven changed/new Swift files parse; four new complete methods and21
unchanged regressions are selected for the next fresh validation task.

## Contract and implementation

OriginalRequestExchange shares the existing owner/cursor/permit/lifetime algorithm.
Window's public alias preserves its old response acceptance. The startup enum adds
17 typed families, checking family only after permit ownership and before appending
an answer. It does not invent extra payload validity; recovered child validation and
numeric error behavior remain authoritative. Cancelled outstanding operations may
still record their actual answer; unknown outcomes stay indeterminate, not HRESULTs.

OriginalApplicationObservedStartup preserves the existing coordinator's same-Host,
publication and inspection lock order. A single receipt cursor avoids independently
finishing separate window/nonwindow journals. PreparedStartupPlatform copies it by
value and routes the existing throwing providers through it. Its prepared fallback
is lazy; missing/mismatched old prepared inputs retain their existing contracts.
Prepared-consumption validation remains specific to the old arrays and is not a
substitute for unified receipt consumption. Panel attempted writes/closes journal
only obtained replies. File bytes/constants still come from immutable preparation.

OriginalMacStartupClock uses actual Darwin clock_gettime outside Core. Milliseconds
floor nanoseconds and wrap at32bits; realtime converts seconds/nanoseconds to100ns
FILETIME using integer arithmetic and explicit range errors. System errors preserve
errno. The original calendar implementation and game numeric rules are unchanged.
Microsoft documents FILETIME's1601 UTC epoch and timeGetTime's32bit wrap; Apple
CLOCK_MONOTONIC_RAW is the host observation boundary. macOS origin/precision and
sleep behavior are not claimed to reproduce measured WinMM. API references and
SDK pin are retained in plan/review; these are host-boundary references, not another
game implementation.

## Comparison selection and review

The new whole-caller test retains all35 source cases and their unchanged auditing
bodies:23 complete/5 stops/7 provenance outcomes,6325events/119WAV/650 window replies.
Only the production provider supplies Core values. A separate external control
service projects the existing declared API/spec inputs, not saved after-state.
The source audit observes actual Native calls/stores and remains test-only.

Additional new methods cover six late failures plus publication-copy failure,
preparation rollback, same-owner retries, independent copies and receipt-resource
lifetimes; all17 typed families with cross-family rejection; and integer clock
boundaries plus actual Mac clock reads at whole-caller permits and late retry.
These methods are implemented and selected, not yet compiled or executed. The live
clock case deliberately uses Native without comparing current time to an old source
clock; all other device replies remain declared controls. The21 retained methods
include the current11 and all10 old exchange/window/WinMain checks.

Author static review found the generic owner control flow identical after excluding
the declared response-family guard; coordinator control flow is identical after the
cursor/protocol substitutions. This is supporting code review only. Independent
contract/numeric review is unavailable and remains open. No comparator/old test,
source expectation, mask or game algorithm changed. Syntax is a separate gate from
fresh compilation, complete comparisons, package verification and physical devices.

## Preservation, delivery and remaining gates

Implementation artifacts are under
build/research/application-observed-startup-20260926 on task-owned X5. Final publication
records exact candidate/preservation/patch-roundtrip/APFS and PAX archive checks.
Root1034, base2249, source55, all old tests and resources are protected. No original,
emulator, capture, Windows or affected refused operation is executed. Existing
incidents stay open; source59727 remains terminal at34 Objects, not full137.

NEXT: fresh build, package verification and all25 complete methods on this exact
frozen candidate, including the live Mac clock control. Retain all failures and
separate host observations from original-source matches. Then integrate concrete
window/resource/backend acquisition; nonthrowing sound/environment/panel constants
and aggregate WAV remain explicit outstanding live-boundary work. Independent review,
root promotion, synchronous callbacks, actual input/audio, initialized loading,
Windows/clean-Mac, full match and complete game remain open. EXE envelope not
recalculated. NTSDApp still uses Practice; full goal remains active.

## Verified implementation closure

Preparation64933, syntax74740 and finalizer77836 are terminal0 and absent. All7
Swift files parsed. Candidate2254 regular files,59 directories; full archive bodies,
modes,nsmtimes,membership and distinct clone inodes verified. Seven-file patch
roundtrip passed; root1034/base2249/source55/all old tests and fixtures unchanged.
Metadata archive48members/2,099,200bytes verified. Candidate manifest SHA256
`c47909457f499bd3253f9b74d1806269e8b3226e791da2ed21b18fdba78124f5`; artifact manifest SHA256
`33762f8abec5accb6e9d2568a32336cd0779a8e338872a40907e1b41706b9829`.
[Publication](../evidence/application-observed-startup.json),
[closure](../evidence/application-observed-startup-close.json),
[patch](../evidence/application-observed-startup.patch). Fresh compilation/all25
comparisons, actual Mac clock test and independent review remain open.
