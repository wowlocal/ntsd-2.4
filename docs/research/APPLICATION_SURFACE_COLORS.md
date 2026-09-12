# Owned source colors for startup bitmap surfaces

This finite card connects the accepted original DIB decoder to the surfaces
created during startup, toward the native renderer and standalone game. It
recovers selection, copying and cleanup ownership from the complete saved
[request inventory](APPLICATION_BITMAP_SURFACE_INVENTORY.md). The finite Native
comparison and independent reviews passed; results are below.
The preceding inventory commit `e3f95c6` made progress; the full goal remains open.

## Evidence and comparison boundary

The reference remains the pinned original game EXE
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
its saved controlled Unicorn requests and original packaged RT_BITMAP bytes.
This card executes only a new data-only assignment tool and Native Swift tests.
It never executes Original, Unicorn, a historical producer or historical auditor.
The low-level handle relationships are needed to recover which bitmap supplies
each surface, which DC generation authorizes a copy, and what survives cleanup.
Numeric responses are controlled inputs, not observations of Windows objects.

The frozen plan, amendment, controls, independent reference and reviews live in
`build/research/application-surface-colors-native-20260912/`. The plan pins 104
inputs. Its 40 bitmap/front lifetimes use actual front indices 0...34 and 36...40;
standalone front 35 was outside this already selected composition. The reference
walks all 16,929 chronological requests/responses independently, then checks the
previous inventory's associations. It retains 995 surfaces, 992 copies, 993
memory-DC and 992 surface-DC generations. Three surfaces remain without a copy:
two supplied by unused positive CreateSurface responses and one after GetDC -1.
The 992 occurrences compose the same 200 distinct stage copies. The original
36 resource names retain their 28 distinct DIB payload identities and aliases.

The existing DIB reference supplies full RGB/mask bytes and 14,632 row checks.
Expected assignments, original response writes, private request bytes and masks
are preserved in the new fixture; they are used only for comparison. Core reads
its original packaged resources, its own known CreateSurface descriptor, request
arguments and declared numeric replies. The direct API test omits private
request backing and captured response writes from Native inputs. Whole caller
tests retain their complete original request/event/record/mask comparisons.

Reference1 stopped at a mistaken final assertion of contiguous front indices,
after ownership reconstruction. Reference2 corrected only that assertion and
then stopped when formatting a task-owned X5 path relative to the repository.
Reference3 corrected path display and published the same assignment algorithm.
Both failures and all three producers/jobs/logs are preserved. They are data-tool
errors, not source faults or changed expected cases. Independent review checks
all assignments, full requests/responses, row digests and input pins before Core.

## Native ownership

`OriginalSurfaceSourceColors` stores top-left RGB8 and one known flag per pixel.
New storage is unknown. A checked, one-to-one SRCCOPY replaces both the colors
and masks in the rectangle; a false source flag makes that destination unknown.
Known black remains distinct. Outside positions remain unchanged. Values survive
source image deletion, and subsequent mutation does not change retained snapshots.
Strict color lookup rejects unknown positions. Checked pixel and byte products,
positive extents, subtraction-based rectangle checks and a configurable default
16,777,216-pixel budget bound Native allocation; this is not a recovered game limit.

The production bitmap registry retains generations and active associations for
both DC roles. Cleanup retires an association, never erases its history or revives
an old generation when a token is reused. Simultaneously live conflicting roles
reject the operation. SelectObject 0 preserves the last successful selection;
a copy without one rejects. The supplemental -1 selection boundary rejects
atomically. Other handle-valued replies retain their UInt32 bit patterns.

GetDC exact zero requires a nonzero output for an owned surface; a negative
response grants no access. A positive output is recorded without granting the
recovered caller's exact-zero copy path. DeleteDC uses nonzero BOOL for cleanup;
surface ReleaseDC uses exact-zero HRESULT. Failed cleanup retains the lease and
prevents token reuse. StretchBlt uses nonzero BOOL, including -1, for copying.
Its supplemental zero-result policy invalidates the affected region after both
rectangles validate. This is conservative Native knowledge, not a measured
original device error effect.

Every Release retains its raw result and the surface's source colors. This
bookkeeping does not establish actual object destruction or reference counts.
MenuSession now records method(+8) in its staged bitmap owner before notifying
the observer. The independent comparator projects saved Release events strictly
before the current event cursor onto the immutable parent: event 3247 first
appears at cursor 3248. There are three distinct input events (results 0,0,-1),
also present in the 12 loading parents. They are not double-counted across menu
iterations. An observer failure discards the staged owner and effects together.

## Validation and publication

The frozen candidate adds three methods for the complete 40-lifetime set and
the 17 supplemental control groups, including the allocation/selection amendment.
The selected regressions retain all 48 primary routes (47 commits and one NULL
cursor rejection), 50 menu-input chains and 12 loading-prefix chains. Existing
late failures after a copied image's cleanup, after method(+8), and at the caller
handoff compare the whole prior state, including new colors and DC histories.
The direct lifetime test also covers the surface owners in the uncommitted
NULL-cursor route; that route is never counted as a successful whole return.

All 23 selected bundled release methods passed in 142.844s; the build took
308.06s. Native1 required no code, comparator or expected correction. Independent
code/comparator review reports no material blockers. All 372 old fixtures and
46 package files remain unchanged; the new fixture preserves every reference3
field and the exact frozen controls. The candidate has 878 regular Native files
and 373 fixtures. NTSDNative links; no window or device run is implied.

The Native archive has 878 members / 4094752847 payload bytes;
the evidence archive has 143 members / 593614700 payload bytes.
Every member name, byte, SHA and mode is verified. Evidence includes all 104
original plan pins, original DIB reference bytes, failed assignment producers,
successful reference, Native candidate, logs and reviews. Replaced Core/test
base versions remain bytewise in the evidence archive. X5 UUID and both storage
reserves are checked. Final docs and Git composition are checked separately
after archiving; commit verification records the actual tree and remote.

[Machine-readable acceptance](../evidence/application-surface-colors.json) pins
the results and boundaries. Completed sources and successful tests are not restarted.

## Open boundaries

This is lossless source-color ownership, not measured DirectDraw raster output.
The declared primary pixel-format response is 8-bit indexed; actual offscreen
conversion, palette realization and initial device pixels remain unknown.
Color key, downstream Blt, clipping, NULL-source behavior, text, backbuffer and
presentation need their own complete consumer contracts. The 146,289 original
DIB holes and 18 downstream NULL-source occurrences retain their stated limits.
No window, audio, actual Windows device, full loading/catalog, War gameplay,
complete match or clean-Mac result is claimed. All three safety incidents and
the full native-game goal remain open.
