# Original music graph notifications

[OriginalGraphEvents](../../native/Sources/NTSDCore/OriginalGraphEvents.swift)
matches371 whole WndProc43b3d0 message400 callbacks through actual401e90 and
ret16. Four separate whole401c90 graph initializations also match; five callbacks
retain their own native initializer's output. These are375 calls, not375 WndProc
callbacks. Full17327744 storage bytes and defined masks,2358 requests and1588
ordered stores/6343 written bytes agree. The finite acceptance scope is
[GRAPH_EVENTS_PLAN](GRAPH_EVENTS_PLAN.md).

This recovers the event processing needed for original music looping. NTSDApp
still uses the practice engine. Audible looping, actual Windows queues, device
behavior and full application composition have not been verified here.

## Reference and controlled environment

The pinned original EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
bundled lib.dll SHA256 is
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
The [source harness](../../tools/oracle_graph_events.py) reproduces the complete
accepted installer case0 before executing the selected original functions in
Unicorn2.1.4. Original EXE/DLL image bytes remain immutable. CoCreateInstance,
QueryInterface, GetEvent, seek/free and DefWindowProc are declared adapters with
explicit response values and independent output writes. Their nonzero interface
tokens belong to this controlled harness. No Windows window, COM device, thread,
host-memory release or network operation is performed.

Low-level stack, memory and instruction observations are needed to recover the
aligned local frame, reversed physical parameter order, retained output words,
exact HRESULT branch and x87 seek bytes. Caller/helper execution covers137 EXE
starts:31 WndProc, all57 drain and all49 initializer starts; zero DLL starts after
the separate installer. The746 actual helper returns comprise371 drains,
371 callbacks and4 initializers. Saved EBX/EBP/ESI/EDI survive. Callback returns
useSP2000f014; initializer returns useSP2000f004.

Each source call starts with supplied CW023f/FPSW0/tagffff; drain entry, helper
returns, all211 seek checkpoints and exit retain those values. Original FLDZ
at401ecc and FSTPQ at401ed6 produce eight zero bytes for every seek. This is
controlled source numeric evidence, not native process-FPU or Windows/hardware
equivalence.

## Original behavior and provenance

Whole401c90 calls CoCreateInstance with original arguments
`[44a2a4,0,1,44a254,44f040]`. Its optional graph output writes independently of
the numeric status. A negative result returns-1 immediately, retaining any output
write. A nonnegative result requests control44f044, event44f048 and position44f04c
in that order, using the original three GUIDs. QueryInterface HRESULTs are
ignored; output pointers remain independent writes. The source then calls
event+34(global4546f4,400,0), event+38(0), clears only byte44ef04 and returns0.
Those two method statuses are ignored too.

The native initializer is shared with [MUSIC_PLAYBACK](MUSIC_PLAYBACK.md).
The new own chain starts with all four graph/interface words zero and obtains
their values from its own native creation/query responses. Five subsequent
notifications keep those native globals, checking each next before-state. The
window token73000001 remains a declared input. This is not a joined window/
graph/RenderFile/WinMain chain or evidence of a playing file. Three successful
initializers and one failed creation are compared; every initializer branch
outcome or absent QueryInterface output is not claimed.

401e90 saves EBP, aligns ESP down to64 bytes, then reserves64 bytes. In these
whole callbacks the resulting frame is2000ef80. GetEvent receives timeout0 and
three output pointers with this physical layout:

| Frame offset | Meaning | API output order |
| --- | --- | --- |
| +34 | Event code | First |
| +3c | Parameter1 | Second |
| +38 | Parameter2 | Third |

Each omitted output leaves its previous local word untouched. Supplied outputs
are applied even on the terminal result. Only exact0x80004004/E_ABORT stops the
loop; other negative values still process the local words. The source reads
code at401ebe. Code1 requests position+20 with binary64 positive zero, using the
same native seek operation as music stop. Numeric seek errors are ignored.
It then reads parameter2 at401edc, parameter1 at401ee8 and the live code again
at401eed before requesting event+30(code,parameter1,parameter2). That status is
also ignored. The next GetEvent follows. After termination the whole callback
passes its original four arguments to DefWindowProc and preserves its result.
Globals remain unchanged in all371 callbacks.

The64-byte initial backing is an explicit stack-pattern input for each source
call, reconstructed independently from its declared seed. These bytes do not
establish initialized application stack provenance. Native requires only the
words actually read; an empty E_ABORT accepts a wholly undefined local record
without reading or changing it. Controlled COM callbacks do not mutate interface
globals or frame words other than their declared outputs. Actual reentrancy,
concurrent interface changes and arbitrary COM side effects are outside this
comparison and remain open for the application join.

## Finite corpus and failure boundary

The375 calls comprise six empty/terminal-output cases;336 single-event cases
from6 statuses,7 codes and8 output subsets;16 multi-event cases with1/2/17/64
events and4 ignored method statuses;8 retained-parameter sequences;3 controlled
initializers; and1 own initializer followed by5 callbacks. Some subsets produce
identical inputs; these are call counts, not unique inputs or all branch outcomes.
Every source queue ends explicitly in E_ABORT. There is no invented queue cap,
successful empty reply, infinite source queue or manufactured null-COM fault.

The2358 requests are1064 GetEvent,693 FreeEventParams,211 seeks,371 defaults,
4 creations,9 queries and3 each notify/flags. There are1572 local API stores,
13 interface API stores and3 CPU cache-byte clears. The2772 actual local CPU
reads, all stores, complete before/after bytes and write masks are independently
reconstructed by [verify_graph_events.py](../../tools/verify_graph_events.py).

Native-only checks reject required unknown local words, missing event/position
interfaces, provider exhaustion after one completed free, late DefWindowProc,
and late initializer event+38 failure. Full staged globals or locals roll back.
External effects must be buffered until the encompassing operation commits.
These adapter failures are not source crashes or successful source-fault matches.
Reachability of absent interfaces and nonterminating device behavior remains open.

## Acceptance and remaining work

The first8-call probe completed before full capture. Preparation of the later
own initializer was refined to begin with zero graph slots; all first8 cases and
their blobs reproduce exactly in the complete corpus. All375 atomic records and
79 base64/SHA blobs verify. No original memory fault, security/control mutation,
safety refusal or source restart occurred.

Initial raw acceptance passed12 release tests in41.330s/build178.31s, including
retained music/input/lifecycle checks. A finite-plan review then added one
native-only test covering two missing-interface rollback trials. Updated5 graph
tests passed0.326s/build45.77s. No source or native game rule changed for that
extension. Final packaged13 tests passed40.526s/build0.26s without a raw override;
the5 graph tests took0.296s. NTSDNative linked; no app window was exercised.

An agent sequencing error started a packaged test before the fixture was copied
into the isolated export. All5 new tests failed at missing resource lookup before
comparison;8 retained tests passed. An artifact check also failed on the missing
final export-pin file. Both logs/statuses are preserved. The process was allowed
to terminate, then the fixture was copied and final pins written before the
successful rerun. No source, native rule or expected result was changed to fix it.

One new fixture preserves213 previous pins, making214. Raw2917279 bytes have
SHA256 `5dd6ed995ad47956f476059e13578239e4e7ff8f58e9cb7d18fbaee7ff6b1c81`;
packed132963 bytes have SHA256
`0807a5b72802f72b52e45df8168499680a27b70d4e38d2a39a9a6b508d08d0d2`.
Full raw/packed JSON, bytes, SHA, all atomic records/blobs,10 codec vendor files
and549 isolated native files verify. The export excludes unfinished foreign
transforms. All owned source/SwiftPM jobs are terminal. Evidence is
[graph-events.json](../evidence/graph-events.json); commands, statuses and failed
attempts are retained in `build/research/graph-events-work.json`. Deflation only
packs the research fixture; no EXE/DLL/emulator enters native runtime.

Together with immutable WINDOW_INPUT and WINDOW_LIFECYCLE corpora,568/576 static
WndProc starts have executed. The eight remaining are six Winsock caller starts
43b98f..43b99a and two negative43bdd0 debug starts43b88a/43b88f. This union is not
every branch outcome or a complete native WndProc router. The later
[NETWORK_NOTIFICATION](NETWORK_NOTIFICATION.md) separately compares401/402ec0
and brings that inventory to574/576; the original graph corpus is unchanged.
Initialized delivery during APIs, CRT/NLS/WinMain, lib transforms/routing, macOS
renderer/audio/input/timing, full matches/content/network/replays and actual
Windows/device/clean-Mac acceptance remain open. The full game goal is not complete.
