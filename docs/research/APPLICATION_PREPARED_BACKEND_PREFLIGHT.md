# Prepared backend: request boundaries before app delivery

Static preflight completed on 2026-09-26 against the retained-context candidate
`ab4c0eb67b1c6b25abd4690124e116465dad709db807acd1bd2636c41350f430`.
The [finite plan](APPLICATION_PREPARED_BACKEND_PREFLIGHT_PLAN.md) and
[publication](../evidence/application-prepared-backend-preflight.json) pin the
consulted sources. The concurrent 82-method comparison remains a separate gate.
No original, Native, device or Windows execution was performed by this preflight.
Author inspection is not independent review; the EXE envelope was not recalculated.

The retained Host batches solve the lifetime of data handed to a delayed consumer.
They do not supply actual device replies or establish a usable application backend.
The existing [app inventory](APPLICATION_HOST_APP_PREFLIGHT.md) remains the complete
provider inventory; this study resolves the next architectural dependency rather
than counting that inventory again. NTSDApp still runs the practice implementation.

## Request, response and publication

Line anchors and exact file hashes for this table are in `observations1.json`
inside the task archive. These are facts about the current Native interfaces;
the linked studies separately identify their controlled original comparisons.

| Boundary | Current consumer and ordering | Consequence for a real backend |
| --- | --- | --- |
| Startup transaction | `OriginalApplicationStartupPlatform` requires independent mutable cursors, allocations and queues, and prohibits host IO during the Core transaction. The bridge calls the provider, records its response, then returns that response to WinMain. | A response already consumed by Core cannot be recovered by subsequently draining the committed operation list. The platform domain tag alone is not a delivery policy. |
| Window initialization | `OriginalWindowInitialization` requests metrics, registration/window creation, DirectDraw/surfaces/clipper and output in source order. Signed replies and returned tokens choose later requests. `OriginalWinMainStartup.run` invokes this whole child before panel, calendar, music, input and five WAVs. | An actual device must answer before the next dependent request; fabricated successful tokens would select unproven behavior. Preserve ignored results and original failure propagation too. |
| Startup audio and files | The bridge supplies aggregate sound/WAV controls before helpers run. Its WAV observation records later events with that retained platform input. File input and owned PCM-copy events are separately classified. | Aggregate controls are not yet a per-call live audio interface. Reopening recorded input files or replaying Core PCM allocation/copy as a second device operation would duplicate work. PCM bytes and masks belong to retained owners, not to the copy event arguments. |
| Host publication | `start`, a committed `step`, and `finishLoadedMenu` construct a per-commit DeliveryContext before installing state/platform and publishing. Pending loading keeps private child state until the enclosing return. | This establishes Native publication and owner retention. It does not undo an already visible window, played sample, queue removal or file write. |
| Catalog progress | Catalog controls sample clocks during parsing. The full loading helper can request Sleep, drawing, presentation and a one-message tail inside each progress call. Object parsing also calls the message helper outside that animated tail. | Deferring all physical work until the whole catalog and enclosing iteration finish cannot by itself establish these intermediate interactions. This is an inference from call order, not a measured Windows presentation/timing result. |
| Initialized loading gaps | Catalog `message` currently accepts only empty `PeekMessageA`; other replies reject. Its fill backing and fill callbacks throw. The front adapter does not accept the loading link/Shell path. Plain animated drawing is already composed. | Nonempty loading dispatch and hover/click behavior remain explicit dependencies. Do not label all animated loading unsupported or silently supply empty messages on a live event queue. |
| Ordinary event loop | The recovered loop owns MSG storage/masks, Peek/Get decisions, exact-zero quit, dispatch order and the timer. Each requested time is a fresh observation; message iterations skip the timer. | A host must supply queue writes and clock samples at the requested boundary. Event mapping, repeat/focus/coordinates and real pacing remain device contracts, not a direct FighterInput or fixed-frame replacement. |
| Cancellation and retry | Current rollback discards tentative Native owners and prepared provider positions. A later physical delivery failure has no recovered undo or automatic-replay contract. | Retain explicit fulfilled-request receipts and pending requests in any future exchange. Never replay already performed IO merely because a later Core attempt failed; physical partial completion must remain distinct from Native rollback. |

## Original evidence and remaining unknowns

[Window initialization](WINDOW_INITIALIZATION.md) compares 280 controlled whole
calls, 4,574 requests and 1,182 structures. The original calls UpdateWindow before
publishing the HWND global in the windowed child. The wrapper still calls
ShowWindow and returns 1 after an internal 0 result. Fullscreen fallback can
return 0 and still select display mode 2. Negative device replies, ignored
GetPixelFormat/SetClipper results, output identities, retained descriptors and
unknown field masks must all survive the adapter. These are not observations of
actual Windows callbacks, raster formats, class registration or driver resources.

[Continuous WinMain](WINMAIN_STARTUP.md) has 23 successful whole Native chains,
five original stops and seven distinct unknown-provenance Native rejections.
The window child is therefore already connected to a real whole Native caller;
there is no justification for accepting a window-only test as application startup.
Unknown fullscreen cursor backing and the other provenance rejections remain
open. No private CRT/stack bytes may be imported to make them succeed.

The archive's lines 3428–3455 describe the earlier fixed-clock initial-loading
scope. Its statement that animated loading is unsupported is superseded, for the
controlled helper, by [LIB_LOADING](LIB_LOADING.md): 318 whole calls and six linked
calls include animated output and 43d230. The old fixed-clock fixtures and their
limits remain unchanged. This newer evidence does **not** establish initialized
catalog dispatch: its DispatchMessage boundary does not execute a WndProc.
The [ordinary loop](APPLICATION_MESSAGE_LOOP.md) does execute selected WndProc
callbacks, but outside the catalog. Combining the two studies is not a whole
initialized-loading comparison. Callback writes must reach the actual live
catalog state and survive the enclosing helper's final assignment; current
empty-message rejection avoids claiming that this composition already works.

The [full Native catalog](APPLICATION_CATALOG_FULL_NATIVE.md) uses declared clocks
`123457000+20*n` and empty messages. Its complete owned-data comparisons remain
valid under those controls, while the original full 137-Object application return
is still unaccepted. Source 59727's terminal 34-Object publication, transport and
provenance work are separate dependencies. No source was restarted here.

## Selected next implementation contract

Implement a **resumable window request/reply owner consumed by the existing
whole WinMain startup path**, before connecting actual window operations.
This is a proposed Native design, not a newly recovered original rule. It is the
first dependent device exchange in startup and has finite whole-child and
whole-parent evidence, including ordinary resource failures. It directly removes
the need for preinvented window responses when the application is connected.
The other startup providers remain explicit dependencies; completing this owner
alone will not make startup or the game ready for users.

The implementation plan must preserve one common window algorithm and its exact
request order, structures/masks, signed replies and resource identities. A missing
reply suspends at that request and publishes no invented response. Submitted
replies belong to one owner/request generation; stale, foreign, duplicate and
out-of-order replies reject. Previously fulfilled replies and their resource
receipts survive suspension and cancellation. The adapter must not perform host
IO from `stagedCopy`, observers, or inside the existing Core transaction. Actual
device work is served outside that transaction; its irreversible outcome is
recorded separately from tentative Native state. It must not silently weaken the
existing Host contract or claim that a subsequent Core rollback undoes device IO.

Finite acceptance is the unchanged 280 whole-window corpus through the exchange,
with exact full request/state/mask/resource comparisons; the 23 successful whole
WinMain parents through the same consumer; preservation of the distinct original
stops and seven provenance rejections; and Native exchange controls for suspension
at every request, wrong replies, late cancellation and retained owners. Existing
late rollback controls remain required. No completed source capture is needed.
Before editing, select and pin the whole-caller methods and specify the independent
comparison of request receipts. An implementation that only exercises an isolated
queue helper or always-success window is insufficient.

The first real window backend still requires a separately declared mapping and
native-window checks; synchronous callbacks and unknown fullscreen provenance stay
explicit. Startup audio's aggregate controls, later loading messages/fills, physical
partial delivery, graphics format/GDI details and actual input/audio/Windows/
clean-Mac checks remain open. The full Naruto/Sasuke District match and complete
game remain the goal. Independent contract review is unavailable in this session.

## Verification and handoff

The publication verifies all 23 consulted Native files and 15 study documents,
the candidate manifest and protected instruction/refusal-register pins. The small
PAX archive preserves every selected member's name, bytes, mode and nanosecond
mtime. No candidate, expected value, old plan, live producer or root Native file
was changed. The current comparison's first next action remains observation of
the same queue, then its terminal saved-result and archive gates; this preflight
does not accept those unfinished gates or replace that queue.
