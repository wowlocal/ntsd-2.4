# Production host transaction preflight

**Status, 2026-09-22:** bounded read-only analysis complete; implementation,
independent review and real host acceptance remain open. The next useful change
is an application transaction driver around the existing Bootstrap. Package data
and Core state already have owners. Queue/time, resource identities and device
responses still need explicit host providers; the XCTest adapter cannot ship.

The [frozen plan](APPLICATION_HOST_TRANSACTION_PREFLIGHT_PLAN.md) selects one
ordinary first-menu transaction, preceded by its own startup and committed resize.
It advances replacement of the practice entry, not completion of the game.
[Context and preservation receipt](../evidence/application-host-transaction-preflight-context.json)
pins the actual dirty inputs, consulted sources and saved comparison case.
[Verification](../evidence/application-host-transaction-preflight.json) records
publication checks separately. No original or Native code was executed, changed,
built or tested in this preflight; reading compressed saved JSON is data inspection.

## Exact boundary and evidence

The existing [Bootstrap comparison](APPLICATION_BOOTSTRAP.md) uses
`OriginalApplicationMenuReturnTests.Resources.c.cases[0]`, label
`body-front-settings-own-resource-0`, parent kind `body`, parent SHA
`b630e4a6d5a287d78436da71c6b6e88eda8441b74d1de170e50ca6ae9f4b63e7`.
Its envelope expands to 67,627,502 bytes with SHA
`5bff3c201a20820812d6859fb46f78f846774ec5cd16d2ba5400a1e663de2747`;
count and full payload hash were verified again. The saved case ends `iteration`
at `0x43d110`, SP `0x1000effc`, CW `0x037f`, baseline 123456822, counter 2.
These are expected observations, never new initial state or production constants.
The case's draw/present replies 0 and final clock 123456901 are controlled inputs.
It is an ordinary branch under declared replies, not an observation of a live
Windows desktop or macOS device.

`OriginalApplicationBootstrapTests.runMenu` constructs the parent through
`start`, then drives the saved resize and first due iteration with `step`.
It reads original package bytes and compares them to source snapshots; it does
not initialize the session from the expected menu return. The saved evidence and
prior accepted comparator establish the D boundary; this author inspection adds
no new D or W result. Original EXE/lib/CRT hashes are in the frozen plan. Relevant
archive constraints at lines 1942–1948 and 3337–3349 retain PE-derived World
storage, unknown private fields, whole rollback, presentation order and owners.

## Inputs and their actual producers

The following inventory refers to the current Core interfaces, not a suggested
set of invented success responses. Every provider must prepare an isolated view
before Core runs. Sharing immutable original bytes is allowed; mutable cursors,
allocation reservations and queues must not leak between attempts.

| Input boundary | Available owned producer | Still required from host |
| --- | --- | --- |
| `start(initial:)` | `OriginalApplicationStartupInputs.bundled(in:)` supplies the 0xc3a8 PE-backed record and masks. Strict `.app` resource lookup already exists. | Package failure handling and launch wiring. Do not substitute a reference wrapper or private stack backing. |
| Original files/bitmaps | `file`, `controlBytes`, `bitmaps` supply the declared files, CRLF-to-LF control projection and original DIBs. Missing and empty remain distinct. Startup package has 46 files; later runtime packages are separate. | Live writable settings/panel overlay, stream errors and persistence policy. General Windows text mode is not established by `controlBytes`. |
| Startup environment | `OriginalWinMainStartup` owns RNG, calendar/output/panel/input results and five WAV lifetimes after `start`. | Instance/show, milliseconds, critical-section bytes, COM, window replies, panel IO/backing/write/close, calendar allocation, FILETIME/TZ/name conversion, music, cursor, joystick and WAV platform controls. These are the exact members of `OriginalWinMainStartupPlatform`; their presence is not an implemented host. |
| First-menu settings | `MenuInputs.settings.bytes` can use package `controlBytes`; Core parses them. | FILE identity/presence, scratch address and close result. Saved `0x20001000` is a test identity, not a runtime allocator rule. |
| First-menu wrappers | Core constructs 24 front wrappers and the background from `frontAllocations` / `backgroundAllocation`, and adopts their current registry once. | Owned allocation identities and backing with declared provenance/lifetime. The test's 0x2000 spacing and A5 backing are controlled choices, not required native heap behavior. |
| Front/background image responses | `OriginalApplicationBitmapInputs` derives GetObject bytes from DIB metadata and descriptions from its own CreateSurface request. It rejects captured structure writes, retains image/surface/DC generations and source colors. | Result/output token controls for `frontResponses` and `backgroundResponses`, including image, surface and DC identities. Package metadata does not supply actual HRESULTs, leases or device conversion. |
| Prefix/body replies | `OriginalFrontScreenInput` and `OriginalFrontScreenBodyInput` carry the attempted prefix/body values. The session replaces the supplied prefix `drawTarget` with its own dispatcher `game.target`; the body receives that same owned target. | Prefix time, thread handle/ID, last error, fill/draw; body DC result/token, method/draw/shell result. Preserve scalar bits and array order; do not promote test defaults to runtime behavior. |
| Per-iteration replies | `Session.Responses` carries draw, presentation, sound, release, DC result/token. Bootstrap owns array positions for queue/window/surface/lifecycle packets during `step`. | Prepared queue/clock replies and modeled window/surface/lifecycle responses. Missing or unused Bootstrap responses reject a committed iteration. Actual callback reentrancy and host error preparation remain open. |
| Delivered input and pacing | The Core message loop owns a 28-byte MSG with masks, timer baseline and counter. WndProc changes current globals using delivered messages. | macOS event-to-message mapping, layout/focus/repeat/coordinates, retrieval writes, timestamp origin/wrap and pacing. No direct `FighterInput` or 60-FPS shortcut replaces this contract. |

The existing test supplies `frontResponses` / `backgroundResponses` by projecting
saved event replies to result/output only. Its queue arrays come from saved loop
events; its startup `Parent.Adapter` consumes corpus responses for window, music,
cursor, joystick and WAV calls. Calendar allocation backing is located in a
saved allocation record. These sources are valid declared comparison inputs;
none is a production provider. Startup assets themselves already reside in
ordinary runtime packages and should be reused.

`PeekMessage` is a non-removing query; nonzero leads to `GetMessage`. Only exact
zero GetMessage quits, and a message iteration skips the timer. Retrieval writes
own MSG bytes; missing bytes stay unknown. The Core timer already implements
the recovered unsigned/signed arithmetic and wrapping counters. A future host
must feed it observations, not reproduce those decisions independently.

## State, commit and delivery

1. `Bootstrap.start` creates a separate `platform.stagedCopy`, owns all startup
   work and calls its final hook. Only success installs startup, Session and
   staged platform together, returning `Started`. Different object identity is
   necessary but insufficient: mutable storage independence must also be tested.
2. The resize is its own successful `step` and remains committed if the later
   first-menu call fails. Each call preserves the canonical full record, live
   resource registry, replay/global aliases, counter, RNG and masks.
3. An ordinary first menu completes through `Bootstrap.step` returning
   `Session.Outcome.committed`. **It does not call `finishLoadedMenu`.** Only then
   may the driver publish the corresponding batch and staged host state.
4. A later `.loading(PendingLoading)` leaves the actual Session unchanged. Retain
   that exact ticket, its staged effects/graphics and tentative host inputs for
   the child chain. Do not deliver its clear/draws or rerun the queue/dispatch
   prefix to manufacture a replacement ticket. Failure retains the previous
   committed startup/resize/menu; a valid pending attempt may be retried.
5. The later `finishLoadedMenu` accepts a returned child from the same Session
   owner/revision, runs the outer clock/sleep tail, then installs state, loop,
   loaded owners and caller environment together. Stale/foreign/reused tickets
   reject. For a subsequent loaded cycle, `makeLoadedCycle` reads current owned
   state and retains catalog/Actor/interface/music owners; it does not reconstruct
   them from the startup snapshot. These are continuation constraints, not part
   of the first-menu implementation selected here.

Observers and `beforeCommit` are validation hooks and may throw. They must not
draw, play, write files, drain a live event queue or mutate a shared allocator.
Copying a generic environment value does not prove that reference members are
independent. The driver must explicitly own those mutable parts.

The effect list and graphics list are two views of overlapping work.
`OriginalApplicationGraphics.consume` resolves surface/lifecycle/bitmap/blit/fill/
release/present/GDI operations while returning no graphics command for other
effects. Startup operations also distinguish input acquisition, owned memory and
platform work. Delivering both complete lists would duplicate graphics; delivering
all graphics before all sound would lose the original cross-domain order. The
first driver should retain each complete ordered batch, with resolved graphics
as metadata, until a separately verified consumer maps terminal operations in
order. A file-input observation is not another open and a PCM copy is not another
device write. Preserve resource generations and color/mask snapshots on commands
even when the current owner is subsequently released.

Successful in-process publication can be checked once per committed transaction.
It does not establish exactly-once physical IO: a backend could fail after some
commands have taken effect. No post-commit device rollback or automatic replay
policy is recovered here. In addition, deferred delivery cannot justify making up
the successful API replies that Core needed earlier. A real host preparation and
failure contract is a separate prerequisite for a usable backend.

## Selected implementation and finite checks

**Next task: implement a testable application transaction driver for startup,
resize and one first-menu return, with explicit prepared input providers and a
committed-batch handoff.** It owns one Bootstrap, the staged startup platform,
attempted queue/allocation state, retained pending ticket and ordered committed
batches. It serializes attempts and rejects reentry while one is in progress;
the API must not expose an in-progress observer as a delivery callback. A loading
outcome is retained without dispatching children in this first driver. No new
timer, input, allocator, raster or audio rule is needed for this narrow owner.

Freeze a separate Native candidate with the actual root dirty files before edits;
root's 1034 live source pins must remain unchanged. Proposed production location
is a Core host-driver type, so existing XCTest comparison composers can exercise
it without importing AppKit. The practice entry remains an integration dependency
until actual providers exist; an injected test provider does not make it a game.
This proposal is an implementation boundary, not a finished implementation plan
or independent contract acceptance.

The implementation plan should fix these six acceptance groups and use current
whole-parent comparators, with expected bytes/replies confined to tests:

1. Drive the selected case from package-backed initial state through startup,
   committed resize and first-menu return using the new owner. Compare every
   prior whole-parent state/mask/owner/event/operation/graphics observation,
   including timer/counter and RNG. No final state is supplied to the driver.
2. Exercise the existing six startup late controls and 17 first-menu late
   controls through the driver. Prove no tentative batch, queue consumption or
   allocator cursor escapes; earlier resize/startup commits remain identical.
   Retry the same prepared attempt and compare the complete successful result.
3. Verify independent mutable startup copies and host reservations, duplicate
   publication prevention, immutable batch lifetime, observer failure and reentry
   rejection. Label these host-owner controls, not original game case coverage.
4. Reach one existing MenuInput activation through ordinary delivered messages,
   retain its exact pending ticket and publish no tentative operations. Reject
   advancing another outer iteration while pending. Do not claim child completion
   or loaded-menu acceptance from this bounded test.
5. Retain all existing 48 Bootstrap primary attempts, 50 MenuInput chains and
   relevant startup-input/graphics-owner regressions on unchanged Core semantics.
   Pin exact method selection before execution. Later loaded-cycle code is a
   protected dependency, not permission to rebuild the whole catalog in this task.
6. Verify candidate/package/archive identity and absence of research dependencies
   in the production target; compare complete ordered batches, without introducing
   a second operation classifier or weakening masks. Independent review remains a
   separate gate if no reviewer is available.

## Open boundaries and handoff

This preflight does not choose macOS key maps, a wall-clock origin, real allocator
backing, critical-section bytes, thread/reentrancy behavior, calendar/codepage/TZ
responses, save/file-error behavior, COM/device success, cursor/joystick behavior,
surface palette/format/color key/clipper/font/DPI/raster, or audio mix/latency.
The existing source-color unknowns remain unknown. Earlier CRT/loader environment,
actual Windows/device comparison, app input/window/audio and clean-Mac acceptance
remain open. All registered safety incidents remain independent open paths.

Analysis is complete in this declared scope. Native implementation/validation and
independent review were not performed. Existing Native, fixtures, archived
instructions and 55 live producer pins were preserved. A read-only JSON shape
inspection failed once (`AttributeError: 'list' object has no attribute 'get'`);
its exact error and limited diagnosis are in the context receipt. A later bounded
read also requested nonexistent `OriginalFrontScreen.swift`; no such file was
created. The actual supplied type and its call site are established by the pinned
Bootstrap/MenuSession files. Author inspection corrected the draft inventory's
prefix target: it is produced by Core, not the host. These author checks are not
independent review. Bounded reads made no source or Native changes.

At 13:34:56 UTC the existing Catalog53 PID59727/start/command/cwd/job were verified:
1274 chunks, eight returned Objects, 312464419 stores. The same capture continues;
this analysis neither restarts it nor accepts the unpublished whole-catalog return.
Source monitoring and the separately frozen driver task are the next independent
actions. During publication, repository commit `5b7e63d` added the user's iterative
commit rule. The [context amendment](../evidence/application-host-transaction-preflight-amendment.json)
preserves the first verification failure on WORKFLOW, its old/new hashes and the
instruction diff. The old bytes remain verified in Git. The frozen plan and live
source manifest retain their original HEAD; the source's HEAD check is only in
launch preflight. Publication will commit this increment and its own navigation
hunks under the new rule, preserving unrelated pending work. That commit records
analysis, not independent review or runtime acceptance.
