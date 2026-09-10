# Application message loop after own startup

`OriginalApplicationMessageLoop` now compares the whole
`43d100..43d21f/ret16` loop decision and selected actual WndProc callbacks.
There are63 loop returns at declared platform/body boundaries and one separate
own stop at required43e9a0. **This is not64 whole application or game matches.**
The full game dispatcher, surface-recovery body and Windows message delivery
remain outside this comparison.

The [finite plan](APPLICATION_MESSAGE_LOOP_PLAN.md) follows
[WINMAIN_STARTUP](WINMAIN_STARTUP.md). Every one of64 fresh source chains first
executes that entire accepted startup on the same Unicorn2.1.4 CPU and stack.
Its complete174-event ordinary parent reproduces unchanged, including original
EXE/VC80 instructions, all original resource bytes, globals, allocations, seed,
calendar and WAVs. The corpus stores that identical parent once; it was not
injected into any source continuation. Native independently runs the shared
startup composer again for each case, using its own outputs for the loop.

## Reference and boundary

The reference is the pinned original NTSD2.4 EXE/VC80, original adinfo/DIB/WAVs,
and declared research Win32/COM/queue responses. Actual loop instructions
recover message priority, MSG lifetime, fresh clock sampling, the counter's
signed wrap behavior, and return/register ownership. Actual selected43b3d0
callbacks recover the effects of delivered keyboard, mouse, joystick and size
messages on the subsequent native loop. Neither research API bridges nor
synthetic clock/queue responses establish actual Windows or macOS delivery.

No original file, network destination, protection/control storage or source
instruction is modified. API bindings use the research harness. The13 bundled
library patch spans are disjoint from all executed new loop/callback instruction
bytes; later library-enabled dispatcher/gameplay routing remains required.
Earlier full CRT/NLS/loader initialization is the same declared WinMain entry
boundary as the parent. This study does not silently complete that dependency.

## Queue, timer and MSG ownership

At43d100 the caller loads PeekMessage into EBP and Sleep into EBX, retaining its
startup ESI baseline and EDI clock function. MSG is the28-byte caller record at
1000f01c. The retained startup stack-store trace has no writes to this range.
Native starts with unknown MSG storage; its bytes are not imported from the
source's declared a5 stack. Queue API output writes establish native ownership.

Every iteration requests PeekMessage with HWND0, minimum0, maximum0 and remove
flag0. Any nonzero result calls GetMessage(HWND0,min0,max0). GetMessage uses an
**exact zero test**: negative results still request TranslateMessage and
DispatchMessage, ignoring both numeric returns. A message iteration never calls
the timer. A zero GetMessage result reads MSG.wParam and returns before incrementing
the loop counter. Return bits such asffffffff/80000000 are preserved.

The ordinary failed-GetMessage controls retain the MSG already written by the
preceding successful PeekMessage. Thus a failed first GetMessage does not require
importing unknown stack bytes in these supplied queue contracts. Native preserves
that own prior message and its mask. Successful retrieval writes all28 bytes in
this corpus. Partial arbitrary OS outputs are not claimed covered. A separate
native-only missing-output trial rejects the unreadable wParam at offset8/count4
and rolls back, without labeling it an original source fault.

Only empty PeekMessage enters the shared
[OriginalApplicationTimer](APPLICATION_TIMER.md). It uses the startup seed as
its own baseline, with fresh time reads, the original33/3ms decision, unsigned
lateness,100ms clamp and signed capped Sleep. Minimize/restore callbacks set the
live451dac word to0/1; later dispatch requests use those own values. Message
processing preserves the active baseline regardless of callback return sign.

Nine controlled timer sequences declare18 dispatcher results and six surface-
recovery calls; they do not execute either body. One further **own** due sequence
stops at the actual first43e9a0 entry without supplying a result. Before the
call ESI advances123456789->123456822, the live target is1, counter remains1
from the preceding resize callback, and SP is1000eff4 with the real argument and
return address pending. Native rejects this required operation and rolls back
that iteration while retaining the previously committed callback. The source
partial baseline/register state is preserved separately from native rollback.
The newer [own dispatcher continuation](APPLICATION_DISPATCH_ENTRY.md) now executes this
required entry and a minimize companion through the first front-resource
allocation boundary4450ac, still without a dispatcher result.

The new corpus requests Sleep4/5. Its4ms control supplies a backward second
clock sample; this is an explicit numeric stimulus, not measured monotonic OS
behavior. The retained2025-case timer corpus still separately verifies1/2/3/5ms
requests, thresholds and wrap cases. No wall-clock pacing or latency claim
follows from either corpus.

## Counter and actual return

After a non-quit message or completed timer branch,43d1ef increments458580 with
32-bit wrap and stores the incremented word. It then compares that result as
signed: only values greater than60 are replaced by0 in a second store. Therefore
60 becomes0 after first storing61, ffffffff becomes0 in one store, and7fffffff
becomes80000000 without reset. The corpus exercises nine boundary words and a
retained63-message chain that crosses the normal reset with its own state.

The counter is an outer application word at458580, just beyond the old bounded
match-global record. Its initial value is independently bound to PE backing;
controls explicitly stimulate this word. Native owns it in the loop state,
without extending a match record or importing a future after-snapshot. The
complete EXE static xref inventory has only this loop's read and two stores;
that inventory does not constitute arbitrary-memory alias proof.

The real ret16 leaves SP1000f04c and restores caller EBX11223344, EBP22334455,
ESI33445566 and EDI44556677. Those saved register values are declared caller
inputs. EAX is the actual MSG.wParam read at43d214. The native timer retains its
last active baseline; the post-return ESI belongs to the caller and is no longer
that timer value. These two observations are checked separately.

## Callbacks and transaction

DispatchMessage uses a declared Win32 bridge that invokes the actual43b3d0 with
the four currently owned MSG words. Original code runs and returns through
ret16 before the bridge returns to WinMain. This is controlled callback delivery,
not a Windows queue measurement or a substituted WndProc result.

The131 callbacks cover18 message codes: key down/up, mouse movement/buttons,
joystick notifications, minimize/restore, cursor/system-command and default.
Their complete globals, outer storage, return bits and request order agree with
existing native input/lifecycle routines. The106 DefWindowProc and11
InvalidateRect results remain declared OS boundaries. No synchronous nested
callback from those APIs is claimed. A supplied quit message reaches the
epilogue directly; this does not prove the complete window-close/WM_DESTROY
cleanup/CRT-shutdown sequence. Text-enabled input, destruction/recreation,
graph/network notifications and other WndProc paths keep their separate accepted
contracts and open initialized routing requirements.

The native step stages a value-semantic caller context together with MSG,
counter and timer. Five late failures at GetMessage, after a callback, Sleep,
a counter store and final callback preserve the whole prior native context and
loop state. The explicit required-dispatch stop similarly rolls back only the
current iteration. Platform implementations must buffer external effects until
commit; already submitted host output cannot be undone by copying Swift state.
An additional own-input trial commits a real key press, then fails after the
actual native key-release callback has changed its staged globals. The press,
prior MSG, counter and baseline survive; the release does not commit. The shared
startup test adapter only gains internal visibility for reuse; its existing
tests and fixture bytes remain unchanged.

## Verification and artifacts

All100 byte-checked loop instruction starts execute, including the previously
uncompared queue/counter/epilogue. There are357 actual EXE starts in the new
loop/callback stage and zero CRT starts there; the complete parent executes its
own CRT. These counts exclude API bridges, declared dispatcher/recovery bodies
and the required-entry stop. They are not every branch outcome or OS coverage.

Across216 source iteration records,152 continue,63 quit and one stops at required
dispatch. Native compares215 complete iterations plus that explicit prefix,
131 whole callbacks and896 ordered events. The source includes216 PeekMessage,
194 GetMessage,131 each Translate/DispatchMessage,80 clock requests,19 dispatcher
requests including the unresolved one, six recovery calls and two sleeps.
Independent reconstruction checks full globals,2132 outer bytes,28 MSG bytes
and masks,76 global stores,165 outer stores,4016 original stack stores and509
adapter stack writes. All305 blobs and64 atomic parts verify, alongside the
entire unchanged parent and235 prior fixture pins/10 codec vendor hashes.

The first source invocation failed before CPU creation by indexing a generator;
its frozen source/log is retained. A later timer stimulus supplied only three
of the four fresh clock samples required by its clamp path. Its failure prefix
and52 completed atomic cases were preserved. Adding the missing declared sample
produced the complete64 cases, with all prior completed expected records intact.
The final source adds560 EAX snapshots only; every preceding expected value,
store, instruction and blob remains unchanged. No live process was restarted
because its log was quiet.

The first native compile succeeded in199.55s. Its63 failing assertions all
conflated active timer baseline with the saved ESI restored by ret16; the
independent verifier initially made the same assertion. The comparison now uses
the actual last pre-epilogue event baseline and independently checks restored
registers. No native algorithm or original expected byte was changed. Corrected
raw8 release tests passed3.800s/build57.05s, including retained timer, whole
WinMain startup and input tests. The first packaged8 tests passed3.748s/build0.26s. The additional actual
key-release rollback test passed0.072s/build55.37s against raw data; final9
packaged release tests passed3.774s/build0.24s without raw overrides. All owned
source and SwiftPM jobs are terminal; NTSDNative linked.

Raw4331171 bytes SHA256
`f6ce8dff0efb9561521aa06a864cf0042fcc09e0fddb3ef64ee01fc6856e6cf9`;
packed2536603 bytes SHA256
`b88ca033aaf17df68694d61d2c570890f7b8b620a96ceb22f43ef9a8d0133ebd`.
The new fixture preserves235 prior pins,236 current. Complete raw/packed bytes,
JSON, hashes and blobs are independently checked. The isolated native export
contains594 committed files plus the new loop, test and fixture,597 total;
only the existing startup test adapter is overlaid for reuse. Six foreign
transform files remain unchanged and excluded.

[Source](../../tools/oracle_application_message_loop.py),
[verifier](../../tools/verify_application_message_loop.py),
[packer](../../tools/accept_application_message_loop.py),
[evidence](../evidence/application-message-loop.json),
[native loop](../../native/Sources/NTSDCore/OriginalApplicationMessageLoop.swift),
[tests](../../native/Tests/NTSDCoreTests/OriginalApplicationMessageLoopTests.swift).
Jobs and review evidence: `build/research/application-message-loop-work.json`.

CUA inventory again returned `Native apps: Error: Sky Computer Use native pipe
startup failed`; no window/input action executed. That transport failure did
not stop or restart any source/native job. The separately refused Windows
download was not retried. Earlier CRT/NLS, full dispatcher/worker/recovery,
window callback routing/reentrancy, library transforms, actual renderer/audio/
input/timing/application, full matches/all original content and clean-Mac
acceptance remain open. The Practice app still uses its existing engine and
the full game goal remains active.
