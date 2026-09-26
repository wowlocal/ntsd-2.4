# Native windowed display resources and physical clear — implementation plan

2026-09-26, HEADc16da9d. Previous goal turn was progress: physical AppKit window
implementation and all29 comparisons/build/package/archives passed. Baseline is
the actual frozen2257-file candidate, manifest
f1bdd040998f5d4254277c31d92474206c9d43dccb05ae536643d090279bf92f.
Preparation64247/build64879/queue75740/finalizer81466 terminal0/absent revalidated.
Use WORKFLOW/TASK_TEMPLATE; author only, independent reviewer unavailable.

## Consumer, reference and finite result

Implement concrete Native display/backing allocations and clipping/clear for the
same observed startup Host and real window. This removes the next physical drawing
dependency toward the first Naruto/Sasuke District match and full standalone game.
No browser/EXE/DLL/emulator/reference-fixture runtime dependency is introduced.

Use only retained original NTSD evidence: EXE
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c;
lib28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba;
VC80c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d.
Read WINDOW_INITIALIZATION, APPLICATION_DISPATCH, APPLICATION_GRAPHICS_OWNERS,
APPLICATION_SURFACE_COLORS, current window/observed startup studies and archive
1203–1234,1278–1308,1948–1994,2194–2221. Whole43bec0/43bdd0/401110/4011d0,
401250..401281 and WinMain43cf40..43d100 are retained source boundaries.
Read source records/Native only; no original/emulator/capture/refused operation.

Correct the prior NEXT's ambiguity without changing its history: windowed WinMain
creates primary/backbuffer/clipper but does not invoke clearSetup. It must remain
so. Verify physical allocation through full startup, and clear separately through
the existing whole OriginalSurfaceClearing helper; retain its420-case regression.
Do not insert a clear, present, format query or callback into the recovered caller.

Serve directDrawCreate, cooperativeLevel(windowed8), primary/back createSurface,
createClipper, clipperWindow, setClipper, release, pixelFormat and colorfill blt.
Validate only declared relevant structure fields through masks; preserve all raw
request bytes. Reuse beginService before physical mutation, retaining outcomes and
resources across late rollback. Unsupported format/mode/blit/callback boundaries
throw; a missing host outcome is indeterminate, never invented HRESULT failure.
Debug and remaining nonwindow APIs stay explicitly controlled in new caller tests.

## Native host policy and ownership

All AppKit work on MainActor, outside Core. Share one monotonic nonzero UInt32 token
allocator across window/display owners; no reserved ranges or private source ABI.
Native owns display sessions, separately allocated primary/back buffers and clipper
leases. A successful output requires the actual owner/allocation/binding. Leases
survive through receipts and copied contexts. Logical release and retained diagnostic
objects are distinct; clipper association holds its own reference after the caller's
release. Releasing a primary drops that association; no global pointer is cleared
unless the recovered caller does it. Native counts are not measured Windows COM.

Host storage format is explicitly XRGB8888, little-endian32 with RGB masks
00ff0000/0000ff00/000000ff, no alpha, sRGB image delivery. This describes Native
allocated backing, not recovered Windows/offscreen conversion or the old synthetic
8-bit response. No palette/color-key/font conversion is inferred. Primary storage
uses the actual window screen's logical-point extent; backbuffer uses the request's
dimensions. One game unit remains one point; screen-to-client conversion is sampled
from AppKit. These are declared host policies, not Windows DPI/monitor observations.

Fresh backing is semantically unknown until explicitly written, even if allocation
returns zero bytes. Preserve a known mask; reject image/readback of unknown pixels.
Full backbuffer clear writes every pixel. Primary clear applies the attached native
window's client clip; never writes the user's desktop. Draw the known crop in that
window with no interpolation; keep source clipping/presentation rectangles unchanged.
Only full-target COLORFILL|WAIT is supported here. General blit/presentation/text/
palettes/fullscreen/synchronous callbacks remain required open work.

Use bounded failable native allocations with an explicit256MiB backend budget;
budget/OOM/geometry errors are native boundaries, not original resource outcomes
or game limits. Keep original common algorithms/expected/masks unchanged. API
documentation (Microsoft DDSURFACEDESC/DDPIXELFORMAT/Blt/SetClipper and Apple
CGImage/NSView) defines host mapping vocabulary; it is not a second game reference.
SetClipper documentation is modern Surface7 guidance, not measured old-interface
Windows reference-count evidence. Record the actual selected SDK declarations.

## Cases, files and gates

Four new complete methods plus all29 unchanged prior methods and the unchanged
OriginalApplicationDispatchPrefixTests/testWholeSurfaceClearRequestsAndReturns,
total34. New methods cover: complete startup producing real resources/Host bindings;
full clear/known masks/raw colors and AppKit view readback after clipping; invalid,
unknown, unsupported, foreign/duplicate/cancelled requests and bounded allocation;
late publication retry/no repeated allocations plus context/clipper/release lifetime.
Actual macOS buffer/view observations stay separate from old source matches.

Modify only candidate OriginalMacWindowBackend for shared tokens and host image/
geometry delivery. Add OriginalMacResourceIdentityPool, OriginalMacDisplayBackend,
OriginalMacDisplayStartupService and one new test class: five Swift files total,
2261 candidate files. No Package/Core/old-test/runtime-resource change. NTSDApp still
Practice. Reuse existing clone/parse/patch/archive/monitor/queue/package procedures.

Task application-mac-display-20260926 in X5 parent
01a0dc49-738f-7972-8fb0-e98fb2f34408. Verify writable APFS UUID
3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548,65GiB external/9GiB internal before clone;
retain40/6GiB plus17GiB source commitment. Implementation4GiB allowance,3584MiB
stop decrease,16GiB logical,7200s,metadata16MiB/root2MiB. T7 remains authorized;
pinned APFS work stays on X5. Protect root1034/base2257/source55 and all old tests.
First gate: implementation, five-file parse,34 methods found, full regular archive
and patch roundtrip/PAX verification, commit. Fresh build/package/all34 and actual
AppKit checks are a separate bounded gate. At most three correction rounds before
contract diagnosis; preserve every failure. Revalidate process identity before action.

Independent review/root promotion/general graphics conversion/presentation/Windows/
visual/input/audio/loading/clean-Mac/full match/game remain open. Source59727 stays
terminal34 Objects, not137; safety register unchanged. EXE envelope not recalculated.
