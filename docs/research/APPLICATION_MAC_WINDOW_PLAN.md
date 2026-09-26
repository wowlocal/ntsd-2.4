# Actual macOS window requests through whole startup — implementation plan

2026-09-26, HEADfc584bb; owner Codex, no independent reviewer available. Follow
WORKFLOW/TASK_TEMPLATE. Actual base is frozen2254-file observed-startup correction1,
manifest431bcfd835882159c1b9e992e4aaa6d661d692cff5b50eab4ce65356eb4f5755,
not root1034. Prior goal turn was progress: all25 comparisons and archives passed.

## Consumer, fidelity and finite scope

Connect real AppKit window operations to the validated whole-startup exchange and
same Host, required before first Naruto/Sasuke District match and full native game.
Implement the windowed native window boundary with owned class/cursor/window
identities and resource leases. This is a physical window service, not a DirectDraw
success stub, renderer, complete startup provider or playable result.

Serve recovered metric7/8/4, icon, cursor, registerClass, createWindow, updateWindow,
showWindow and destroyWindow requests. Preserve actual payload/byte-mask validation,
separate metric calls, UpdateWindow-before-HWND-publication and repeated ShowWindow.
All AppKit work runs on MainActor outside Core attempts. Window leases retain class/
cursor owners through response receipts and Host contexts; teardown closes only
owned windows on the main queue. Identities are Native monotonic UInt32 tokens,
not source private pointers. No expected state or unobserved storage is imported.

Native platform mapping is explicit: one game client unit is one AppKit point;
backing scale is observed separately, not claimed to equal Windows physical pixels.
Metrics derive from actual AppKit content/frame conversion for the native titled,
closable, miniaturizable window. CW_USEDEFAULT delegates placement to native center;
source window style10cb0000 is retained as metadata. Windows decoration/menu/zoom,
DPI/placement/focus/callback/pixel equivalence remains open; the mapping does not
redefine an original game rule. Unknown fullscreen cursor and fullscreen display
remain unsupported dependencies, not excluded final scope. Never synthesize a
DirectDraw/surface/clipper/format/pixel reply to pass this stage.

Static read-only pinned-EXE inspection found RT_ICON1 and RT_GROUP_ICON121, both
language1028; no requested group32512 and no RT_MENU/Marti. Preserve this index and
hashes. Native baseline icon lookup32512 returns missing, not a substitute icon121;
no class menu resource is invented. This is S evidence, not Windows execution or
proof of CreateWindow's missing-menu behavior. Windows original callbacks remain
unobserved and are not silently dispatched or declared equivalent to AppKit events.

A physical service needs an atomic start claim before IO: extend the common exchange
with beginService(permit), preserving existing claim/answer/fail semantics. Foreign,
duplicate and cancelled starts reject before side effects; late answers after
cancellation remain permitted. The observed coordinator forwards that operation.
Bind the Mac service to one coordinator. Prevalidate supported payloads before the
start claim. If a begun operation cannot be answered, retain its resources and
record an indeterminate outcome, never invent a Win32 success/failure number.

## Evidence and selected acceptance

Only original NTSD is game behavior: EXE
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c;
lib28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba;
VC80c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d.
Use WINDOW_INITIALIZATION/WINDOW_LIFECYCLE, WINMAIN_STARTUP, graphics owners, app
and prepared-backend preflights, observed-startup studies, archive1203–1235,
1278–1308 and1792–1831. Source401b00/window43bec0..43bdd0, whole43cf40..43d100.
No new original/emulator/capture/refused operation. Existing incidents remain open.
Host API references: Apple NSWindow frame/content geometry/main-thread ownership;
Microsoft LoadIconA, ShowWindow/CreateWindow semantics. Host documentation is not
an alternative game implementation. Pin SDK headers and static resource-index input.

Four new complete methods plus all25 unchanged prior methods, total29:
1. Whole startup with physical AppKit window requests and explicitly controlled
   remaining device/API responses, own produced HWND through later calls and full
   Host publication. Observe actual title/client/frame/backing/visibility/identity;
   never compare a changed real host sample to an old synthetic expected value.
2. Native window geometry, class/cursor/window ownership and lifetime, missing icon,
   distinct tokens, ignored source-style metadata and unsupported/invalid requests.
3. Foreign/duplicate/cancelled physical-service permits before IO, same-owner
   begin/answer/fail/cancel boundaries and retained late answers/resources.
4. Whole startup late failure/retry with exactly one physical create, retained
   replies/window through handoff/context lifetime, explicit owned destroy and no
   repeated physical work. Native rollback does not close a visible window.

The25 prior methods preserve original35case23/5/7,6325events119WAV650window replies,
280window cases4574requests, rollback and resource controls. New actual-window tests
establish Mac observations with other APIs declared controls; they do not establish
Windows callbacks or full device equivalence. No old test/comparator/expected/mask
changes. Author review is not independent review; keep its absence open.

## Files, storage, gates and stopping

Only candidate Package.swift, Core OriginalRequestExchange.swift and
OriginalApplicationObservedStartup.swift change. New NTSDMacPlatform target has
OriginalMacWindowBackend.swift and OriginalMacWindowStartupService.swift; add one
new test class. NTSDApp may link the new target but its launch behavior is not changed.
Runtime has no reference/EXE/DLL/browser/emulator dependency. Root Native and all
frozen producers/plans/fixtures remain unchanged. New candidate2257 files.

Task application-mac-window-20260926 under task-owned X5 parent
01a0dc49-738f-7972-8fb0-e98fb2f34408. Verify writable APFS UUID
3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548 and65GiB external/9GiB internal before clone.
Keep40/6GiB reserves plus17GiB source commitment. Implementation allowance4GiB,
stop3584MiB decrease,16GiB logical,7200s,metadata16MiB/root2MiB. T7 remains separately
authorized; APFS-dependent work stays on X5. Reuse clone/parse/patch/archive tools.
Check root1034/base2254/source55 and all old tests. Revalidate PID/start/command/cwd/
job before process action; never duplicate a live/completed process for silence.

First gate: concrete implementation, six Swift files parse,29 selected methods exist,
full regular candidate archive and patch roundtrip plus PAX metadata verified; commit.
Fresh build/package/all29 (including actual AppKit window operations), visual/device
and independent review are separate subsequent gates on this frozen candidate.
Unavailable WindowServer/visual inspection leaves those gates open. At most three
correction rounds before contract diagnosis; preserve every failure, no automatic
retry or weakened acceptance. Source59727 stays terminal34 Objects, not full137.
Root promotion, graphics resources/raster, other startup providers/aggregate audio,
synchronous callbacks/fullscreen provenance, initialized loading, Windows/clean-Mac/
full match/game remain required open work. EXE envelope not recalculated.
