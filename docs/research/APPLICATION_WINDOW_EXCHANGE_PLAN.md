# Window request exchange — isolated implementation

2026-09-26; base HEAD77a476f. Previous goal turn made progress: all82 retained
context comparisons, package/preservation gates and complete archives closed.
Queue5193/finalizer98639 are terminal0 and absent; their task stays frozen.
Read WORKFLOW/CURRENT_WORK, the prepared-backend preflight, WINDOW_INITIALIZATION,
WINMAIN_STARTUP, Host transaction/context studies and archive1203–1235/1792–1831.
The original window/WinMain rules and all earlier provenance limits remain binding.

## Game result, evidence and scope

An actual native startup cannot invent a device reply before the window exists.
Implement the first request/response ownership boundary needed by that startup:
a pure Core cursor can suspend on a missing window response; after the Core
attempt unwinds, an external coordinator claims and answers that exact request.
The same recovered whole window and WinMain algorithms consume the answers.
This advances application startup toward the complete Naruto/Sasuke District match;
it is neither a physical backend nor acceptance of the full game.

Reference: original NTSD distribution; EXE SHA256
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c,
lib28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba,
VC80c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d.
Use existing immutable280 whole-window controls and35 WinMain cases:23 successful
parents,5 original stops,7 separate unknown-provenance Native rejections. No new
original/emulator/capture/auditor, affected refused operation or device execution.
The new exchange protocol is a Native design, not a recovered Windows API rule.
Independent review is unavailable and stays open; no model change/delegation.

## Contract before edits

- One exchange owns an append-only journal of actual requested structures/masks,
  numeric responses and optional opaque resource-retention references. Core never
  calls methods on retained resources. A reference is a lifetime owner, not an
  assertion about real Windows allocation, device success or physical rollback.
- A snapshot is immutable and produces independent value cursors. Cursor reads
  validate the entire actual request against the corresponding retained request
  before returning its recorded response. No expected after-state is an input.
- At the end of the answered prefix, the cursor throws an unforgeable request
  ticket containing owner identity, journal revision, ordinal and actual request.
  It does not call a backend or modify the exchange. A suspended cursor cannot
  continue. Native calculation may be retried from its actual pre-attempt state
  with the same prepared nonwindow observations and a fresh cursor; fulfilled
  requests replay only their values, never external IO or committed observations.
- Outside the Core transaction, claim accepts only this owner's current ticket
  and yields one permit. A second claim while a permit exists rejects. Answer or
  explicit indeterminate failure accepts only that active permit. Stale, foreign,
  duplicate and out-of-order tickets/permits reject without erasing prior records.
- Answer appends the exact response even if the next Core attempt rejects its
  missing provenance. No successful zero/token is synthesized and no response is
  overwritten to repair an already served request. Indeterminate physical failure
  records the request, diagnostic and retention references without a numeric reply,
  blocks further service and has no automatic retry.
- Cancellation stops new service and preserves prior receipts. If a permit was
  already issued, its eventual answer/failure is still recorded once; cancellation
  does not undo or erase that work. Old snapshots remain immutable values, but
  their tickets cannot obtain new service from a cancelled/finished exchange.
- Completion validates an unsuspended, fully consumed current cursor and no
  outstanding permit, then closes new service. It is a caller-declared protocol
  completion: only the actual whole caller's return establishes game completion.
  Copies/snapshots retain resource references after cancellation or owner death.
- No host IO in stagedCopy, Core observers or transactions. The actual production
  startup provider, physical resource mapping/callbacks and nonwindow request
  boundaries remain dependencies. The existing transaction contract is unchanged.

Add one Core type and one test file. Two existing test helpers may expose their
corpus/rollback utilities and an optional cursor (default nil, copied by value);
all existing test method bodies/comparators stay exact. The optional cursor runs
inside the actual WinMain platform.window consumer after its existing request
comparison; completed responses come only from the exchange. Shared production
window/WinMain algorithms, Host code and every fixture/resource stay unchanged.

## Finite cases and comparison

Five new XCTest methods, with the complete corpus inside each applicable method:

1. All280 windows: suspend at every request and answer outside the attempted Core
   call. Compare full requests/structures/masks, final globals/writes, results,
   helper backing consumption and resource outputs/releases. Exactly4574 requests
   are served once; any repeated calculations consume only immutable receipts.
2. All35 actual WinMain parents through the same cursor: compare all existing
   events, stores, stages, calendar/panel/music/joystick/five WAV owners; retain
   the exact23/5/7 outcomes and required rollback/provenance-prefix checks. Every
   window request is suspended before first fulfillment; other replies stay the
   existing explicitly prepared inputs. No private CRT backing is imported.
3. The six existing late startup failure sites, then retry the same answered
   window prefix using fresh independent provider cursors. Preserve complete
   before-state and compare successful whole startup without re-serving windows.
4. Protocol controls: mismatched request without cursor consumption; independent
   copies; foreign/stale/duplicate tickets and permits; concurrent claims;
   incomplete/suspended/stale completion; cancellation before/after claim; late
   answer after cancellation; explicit indeterminate failure and no automatic retry.
5. Strong resource retention across receipts, cursor/snapshot copies, cancellation,
   completed/failed exchange and exchange destruction; release only after the last
   Native owner is gone. This tests memory ownership, not device shutdown semantics.

Required fresh validation selects these five plus the three unchanged whole-window
methods and two unchanged whole-WinMain methods (10 total). The old82 method bodies
are preserved and their completed baseline results remain separately pinned; this
additive cursor and optional test-only hookup do not change Host/game algorithms.
Do not claim a new82-method run on this candidate. A later Host/backend integration
must select its relevant whole Host/gameplay regressions before editing.

## Bounds, ownership and delivery

Actual base is the complete2242-file candidate in the closed
application-host-delivery-context-validation-20260926 task; manifest SHA256
ab4c0eb67b1c6b25abd4690124e116465dad709db807acd1bd2636c41350f430.
Root1034/dirty work is protected, not the candidate. Clone its regular files using
the existing verified APFS procedure into task/alias application-window-exchange-
20260926 under /Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408/.
Verify writable APFS UUID3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548 and free space first:
require65GiB external/9GiB internal; retain40/6GiB plus17GiB source commitment.
Physical allowance4GiB, stop observed decrease3584MiB; logical16GiB; metadata16MiB;
root additions2MiB; elapsed7200s. No large build in this phase. T7 remains authorized
but is not used for APFS-dependent candidate/archive cloning.

Mutable only this task/alias, the four declared candidate Swift files, one root
preparation adapter, plan/result/evidence and own navigation additions. Preserve
author drafts before corrections. Parse all changed Swift sources once after
inspection; parsing is not typechecking or a comparison pass. Then verify exact
old inputs/methods and candidate membership, four-file patch roundtrip and complete
regular candidate/PAX metadata archives. Commit this checked implementation before
the separately bounded fresh build/10-method validation. Maximum three correction
rounds; diagnose any failure, retain the old candidate and never rerun automatically.

No root Native promotion. Source59727 remains terminal at its34-Object publication
cap, not a full137 return. Incidents, independent review, loading messages/fills,
audio aggregation, real input/window/audio/Windows/clean-Mac, complete match/game
remain open. EXE envelope not recalculated. Revalidate process identity/cwd/job
before actions; neither quiet logs nor observation timeouts authorize a restart.
