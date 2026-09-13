# Retaining the outer iteration across loading

The [loaded-return plan](APPLICATION_LOADED_RETURN_PLAN.md) remains open.
Its first prerequisite preserves the suspended message-loop owner when the
native menu reaches loading. Input, retained music, fresh library menu and the
actual enclosing application return still need to be connected and compared.

Previously `OriginalApplicationMenuSession` returned `PendingLoading` by leaving
the staged loop with an internal error. It retained game state and operations
but lost the loop's tentative timer and MSG. Re-entering `step` after loading
would repeat PeekMessage, clock sampling and the game prefix.

`OriginalApplicationMessageLoop.PendingDispatch` now owns the loop's current
MSG bytes/masks, prior counter and prepared timer decision. `PendingLoading`
retains that value. The timer and ordinary uninterrupted loop use the same
prepare/finish code. Returning the dispatcher supplies its signed result;
`resume` runs only the required recovery, last time request, Sleep and counter
tail. The returned loop and value-semantic context become available together
after the final observer. This does not dispatch the accumulated backend log.

The enclosing application must retain the matching context and journal, reject
a stale or unrelated continuation, synchronize the full-record counter alias,
and publish an iteration once. A generic Swift value is not a single-use token.
That application-level commit is part of the remaining plan, not a claim made
by the generic continuation API.

## Comparison evidence

The candidate uses the unchanged original timer corpus: 2025 cases, 8163
events, 1215 due dispatches and 810 not-due decisions. Split executions compare
directly with saved source events and baselines; uninterrupted Native output
does not supply their expected values. Partial MSG writes, late tail exceptions
and retry are additional controlled Native checks. They are not original API
failures or new Windows observations.

The three existing own loading parents retain the loop ticket through the
actual `PendingLoading` API. Their final source dispatcher checkpoint is
`43e9a0`, event index 3266, timer baseline 123456923. The saved three clock replies
are 123456990 after a preceding baseline of 123456888. The timer targets are
1, 0 and 1; the game surface is separately `31003000`. MSG bytes/masks and
counter remain unchanged between dispatcher entry and the loading stop.

Inside the loading child, the source snapshot field named `baseline` is raw
ESI, already reused as World address `458b00`. The first new test mistakenly
treated that child register as the outer timer. Both author inspection and
independent review caught this before execution. Frozen candidate 1 preserves
the erroneous test; candidate 2 reads the saved dispatcher checkpoint and
retains the child register as a separate assertion. No source expected byte or
Core rule changed for this correction. The test supplies a declared return 1
and a later clock only to verify the retained ticket; it does not establish an
original whole loaded return.

The first Native run compiled candidate 2 and passed 15 methods. Its new split
matrix test failed: an `XCTAssertEqual` autoclosure intercepted the intentional
suspension before the test's outer `catch`, and an additional assertion counted
all four supplied clock responses instead of the source's consumed two, three
or four. The full failed run is retained (12963 failures, including 1215
unexpected suspension errors). Candidate 3 evaluates the throwing call before
the XCTest assertion and compares reads with saved time events. Its diagnostic
prints measured counts. Source expectations and all three Core files remain
unchanged; the earlier independent review's missed test errors are recorded.

Data-only checks verify both saved timer/message-loop transport envelopes and
all 305 message-loop blobs (6,886,823 decoded bytes). Their decoded JSON omits
the historical raw file's final newline, as declared by the unchanged envelope.
Existing fixtures and reference programs remain immutable.

## Remaining ownership work

The next implementation must bind current application World and Actor tokens
to the shared match model without substituting old constructor snapshots.
Saved playback comes from current `full[b588..<b8a8]`; its 800 bytes and masks
must survive together with the replay pointers in the following eight bytes.

The real WinMain owner already contains `output.music`; transferring only its
five WAV owners loses that music allocation. In the retained cached
`bgm\\main.wma` case, entering menu can resume the existing control rather than
reproduce an old standalone fresh graph sequence. Carry the actual owner and
compare the applicable saved music contract.

Arithmetic precision also needs explicit provenance: the own WinMain API does
not establish the earlier pre-WinMain 53-bit initializer. Historical 64-bit
reference defaults do not establish this application's context. The subsequent
menu must use the installed-library text/DC route and actual live draw owners.

Final candidate 3 passed all 16 bundled release tests in 64.236 seconds after
a 313.44-second build. The four new methods cover the split matrix, three own
loading parents, signed counter wrapping and seven late tail rejections with
a fresh retry. Twelve retained methods cover the original timer/message-loop
contracts, own menu input and resource delivery. `NTSDNative` linked; no window
or device was exercised. Native1 and Native2 are both terminal, with their
failure/success results kept distinct.

File/package preservation and the final independent review are recorded in
[the evidence](../evidence/application-loaded-return.json). All 381 old fixtures
remain immutable. Three frozen candidates retain the two earlier test versions;
the final Native archive and evidence archive are checked separately. Passing
this prerequisite does not accept the whole loaded-return card.

Full match, all content/modes/networking, actual
window/input/audio, Windows behavior and clean-Mac acceptance remain open.
