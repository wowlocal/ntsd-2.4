# Window request exchange candidate

An isolated additive Core implementation now supplies a request/reply boundary
for the existing whole window and WinMain callers. Four changed Swift files pass
syntax parsing. Typechecking, the ten selected comparison methods and independent
review remain open; this is not a working device backend or a new game acceptance.
The [plan](APPLICATION_WINDOW_EXCHANGE_PLAN.md) fixes the contract and cases.
The [publication](../evidence/application-window-exchange.json) identifies the
exact candidate, patch, preservation checks and archives.

## Why this step

The [prepared backend preflight](APPLICATION_PREPARED_BACKEND_PREFLIGHT.md) found
that retained Host batches cannot supply replies already consumed by startup.
The first dependent device boundary is the window child. The new
`OriginalWindowRequestExchange` supplies immutable response snapshots and value
cursors to that existing `platform.window` call. It does not duplicate the window
algorithm, infer successful replies or perform host IO from a transaction.
The application can eventually serve each returned request outside Core, retain
its actual result and retry Native calculation using the same prepared inputs.

The existing [whole window](WINDOW_INITIALIZATION.md) and
[WinMain](WINMAIN_STARTUP.md) contracts remain unchanged. Their original NTSD EXE
is SHA256 `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
the lib/CRT pins are in the plan. Signed replies, output tokens, ignored statuses,
failure propagation, field masks and unknown fullscreen cursor provenance stay
with those shared handlers. No source capture, emulator, historical auditor,
Windows call or device operation was run for this candidate.

## Implementation and ownership

A cursor owns an immutable receipt prefix and its own position. It checks the
entire actual request, including unknown backing bytes and defined masks, before
returning a saved response. At the end of that prefix it throws a request ticket
and becomes suspended. The ticket contains private owner identity/revision and
the actual request. Neither this operation nor copying a cursor touches the
coordinator or a device. Unknown request bytes stay unknown; equality does not
promote their masks to known.

After the attempted Core call unwinds, the coordinator can claim the current
ticket once. A mutex serializes claims and terminal replies; a private permit
identity binds the response to the outstanding request. Answer appends an exact
response plus optional opaque resource-retention references. Core never invokes
those resources. Their retention is a Native lifetime contract, not a promise
about physical device ownership, destruction or Windows handles.

Cancellation prevents new service and keeps all receipts. An already issued
permit can still report its actual answer or failure exactly once. A physical
outcome reported as indeterminate retains its diagnostic and resources, provides
no fabricated numeric result and blocks further service. Completion checks the
current fully consumed, unsuspended cursor with no outstanding permit. It must
follow an actual whole-caller return; it does not independently establish that
an arbitrary caller executed a window operation successfully.

Old snapshots remain immutable after cancellation/completion and can still retain
their resources after the exchange dies. Old tickets cannot acquire new service.
The coordinator must preserve the actual pre-attempt state and prepared nonwindow
observations across a retry; this API does not prove that obligation for arbitrary
providers. Retry replays Native calculation and prepared values, never physical
IO. The real startup provider and Host suspension/publication integration remain
separate work, with the existing no-IO transaction contract intact.

## Finite comparison implementation

Five new methods are written, not yet executed:

- All280 original whole windows, suspending before each of4574 first requests;
  full requests, result/state/write masks, helper backings and resource/release
  records compare after the same shared algorithm returns.
- All35 WinMain cases through the existing full event/store/owner comparator,
  retaining23 whole successes,5 distinct original stops and7 provenance rejections.
  Fresh copied providers keep their own cursor positions during each suspension.
- Six late startup failure sites and successful retries from the same answered
  window journal, with whole startup ownership comparison and no new service.
- Protocol cases for wrong requests/owners/revisions, duplicate or stale permits,
  competing claims, incomplete completion, cancellation and indeterminate outcomes.
  Changes to strings, unknown bytes or masks reject without advancing the cursor.
- Resource lifetime across cursor/snapshot copies, completion, a late answer after
  cancellation, indeterminate failure and exchange destruction.

Only two existing test helpers change: corpus/rollback access and an optional
cursor with default nil, copied by value. The original window comparison runs
before the adapter asks that cursor for its answer. Every old test method body
and comparator is preserved. Shared production window, WinMain and Host sources,
all385 fixtures and1301 Core resources remain byte-exact.

The selected fresh validation is these five methods plus the three existing
whole-window methods and two existing WinMain methods: ten in total. The completed
82-method baseline is preserved separately; it is not a current-candidate result.
No expected after-state becomes a runtime input. The comparator independently
checks the original requests/bytes/owners; the new protocol controls are explicitly
Native-only and do not claim original reachability for arbitrary API misuse.

## Preservation and continuation

The candidate contains2244 regular Native files cloned from the closed2242-file
retained-context validation, including its actual dirty-baseline inputs. Root1034,
prior2242 and source55 are protected. The first four-file author draft is retained;
before parsing, author inspection added explicit stale-permit and structure/mask
controls. That inspection is not independent review. A verified four-file patch
and complete regular candidate/PAX metadata archives accompany the publication.
X5 reserves remain40GiB external/6GiB internal plus17GiB source commitment.

NEXT: separately bounded fresh build, exact package/source inventory checks and
all ten complete methods on this pinned candidate. Diagnose any failure from its
saved result; preserve this candidate and create a separately identified correction
when necessary. Parsing alone proves neither type correctness nor comparison.
Root promotion, independent review, real window/input/audio, loading message/fill
integration, full137 source/transport, Windows/clean-Mac, full match and complete
game remain open. Source59727 stays terminal at its34-Object publication boundary;
no original or refused operation was restarted. EXE envelope was not recalculated.
