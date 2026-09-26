# Windows menu text observation preparation

2026-09-26, base e1567bf. Parent: APPLICATION_FIRST_MENU_RASTER_CONTRACT and
WINDOW_INITIALIZATION/LIB_RUNTIME. Read WORKFLOW/TASK_TEMPLATE and archive
1968–2025,3889–3920. Host screen is locked; Windows EULA is already approved.
No UI unlock/restart or original EXE/DLL execution belongs to this preparation.

Question: which font/DC attributes and pixels does Windows GDI produce for the
three original first-menu TextOutA requests on a windowed DirectDraw back surface?
This is a required observation dependency for the first native menu and ultimately
the complete Naruto/Sasuke District match. Existing records supply exact request
order, coordinates, byte strings, transparent mode1 and COLORREF0xd07750. Actual
font/device format remains unknown. Only the pinned original distribution is the
behavioral reference; Microsoft API/header documentation supplies public ABI.
EXE SHA2563f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c.

Prepare one bounded x86 Windows collector (the original game is x86), its existing
style builder/runner and validator, plus finite synthetic tests. No Windows or
original code runs on this Mac. Compile only the new collector; Windows ARM64
translation and actual virtual-device provenance will be recorded separately.

Future collector owns a fresh window, DirectDraw interface, primary and794×550
back surface. SetCooperativeLevel8; primary descriptor size108/flags1/caps0x200;
reuse descriptor with flags7,width794,height550,caps0x40. Unspecified descriptor
bytes are deliberately zero from this collector's own storage, NOT recovered
original stack backing. Own class/default window procedure, window placement,
absence of original callbacks/clipper/history are controlled differences. No
exclusive/fullscreen mode, font selection, display-setting or security changes.

Fill the owned back surface with original raw0x10206c, record device pixel format
and bounded readonly Lock snapshots before and after the three exact text requests.
Only valid successful owned-surface descriptors permit reads; stride/dimensions/
format/size are bounded, no foreign-process memory is read. Unlock precedes any
new GDI operation. Each GetDC records selected font/GetObjectW LOGFONTW,
GetTextMetricsW/GetTextFaceW, charset, alignment, mapping/device capabilities and
text extents, then SetBkMode1/SetTextColor/TextOutA/ReleaseDC. Metadata queries are
observer operations; this is API replay, not original execution. The blank fill
is not the first menu's bitmap background, so samples do not establish final menu
pixels or identical antialiasing over its images. Failed API/cleanup/IO and unknown
metadata remain distinct outcomes. Pixel snapshots are not write masks.

Use public original IDirectDraw/IDirectDrawSurface vtables, not Surface7's changed
Unlock signature. Pin official Microsoft ddraw.h ABI evidence. Reuse existing
PE inspector and byte/test primitives; do not modify historical collectors.
One capture, two bounded snapshots, three text acquisitions;60s observation by
future runner, record live process on timeout without kill/retry. Output≤32MiB,
X5 task≤1GiB/metadata128MiB, builds/tests≤600s each. Preserve40GiB reserve plus17GiB
source commitment and64GiB prospective VM growth; internal reserve6GiB. Build
on verified APFS X5, no T7 IO needed. Retain exact scripts, first-menu input and
errors. After terminal failures allow at most three separately preserved diagnosed
corrections. No historic source capture, auditor or Native regression is rerun.

Checks: two fresh byte-identical PE/kits; architecture/import/section inspection;
finite synthetic module/function/window/DD/surface/DC/font/lock/cleanup/IO failure
and normal cases using new instructions only. Verify bounds, original text inputs,
ABI arguments, lifetime ordering, output parse/validation and known synthetic bytes
independently. Verify packaging membership/bytes and archive modes/ns mtimes.
Native assets, historical fixtures/masks/expected, old producers and AGENTS archive
stay immutable. Modified paths: new menu-text tools, this plan/result/evidence and
own navigation blocks. Independent reviewer unavailable; author checks are not
independent acceptance. Actual Windows execution, source-context equivalence,
full-frame comparison, Native raster/root promotion, complete game and all prior
safety incidents remain open. Commit the checked increment before another task.
