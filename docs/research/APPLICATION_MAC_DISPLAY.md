# Native display resources and physical clear — implementation candidate

The isolated candidate adds owned display, primary/backbuffer and clipper resources
to the same observed-startup exchange and actual AppKit window. It implements masked
request validation, bounded backing allocation, explicit native resource references,
full color fill and clipped image delivery. Five Swift files parse; fresh compilation
and the selected34 methods have not run. This is a concrete graphics dependency
toward the first Naruto/Sasuke District match, not an accepted renderer or full game.

[Finite plan](APPLICATION_MAC_DISPLAY_PLAN.md). Base c16da9d and the actual2257-file
validated window candidate. Root1034 and pending catalog work remain protected.
There is no new original game, emulator, capture, auditor or refused operation.

## Recovered caller and native boundary

Windowed401110/4011d0 creates primary/backbuffer, creates and binds the clipper,
releases its caller reference and shows the window. It does not run clearSetup.
The old NEXT's phrase "startup clear" is clarified here: this implementation keeps
windowed whole WinMain unchanged; separate physical clear tests invoke the recovered
whole401250 helper. The unchanged420-case clear regression remains required.

The service accepts directDrawCreate, cooperativeLevel8, primary/back createSurface,
createClipper, clipperWindow, setClipper, release, pixelFormat and full COLORFILL|WAIT.
Only size/flags/caps and flagged dimensions, or fill size/color, are read through
their defined masks. Raw request structures stay exact; ignored private fields do
not become known zero. Unsupported modes, formats, operations and owner/geometry
failures remain explicit Native boundaries. They are not successful matches to
source faults and do not fabricate HRESULT errors.

beginService still precedes physical mutation outside Core. Replies retain actual
resources across retry and late publication failure; an unknown begun outcome is
recorded as indeterminate. Nonwindow APIs and window debug output remain declared
controls in the new whole-caller test. Every29 prior method stays unchanged.

## Ownership, backing and physical output

OriginalMacResourceIdentityPool gives windows and display resources one monotonic
nonzero token space without pointer values, reserved ranges or reuse. Display owners
retain the native window; surfaces own separate backing and their display owner.
Clipper association retains a reference after the source caller's release. Primary
release drops its association, and surface release frees its backing while retained
receipts can still inspect the retired identity. Invalid released associations reject
before reuse. Native counts are not measured Windows COM reference counts.

Native backing is explicitly little-endian XRGB8888, with RGB masks00ff0000/
0000ff00/000000ff and no alpha. CGImage uses the corresponding32-bit layout and
sRGB image delivery. This is the implemented host format, not the original device's
observed format, an imported8-bit response or a claim about palette conversion.
Primary extent comes from the actual window screen in logical points; backbuffer
extent comes from the original request. The existing one-unit/one-point host policy
is retained. Window movement to another screen or unsupported clipping geometry
rejects; it does not silently remap source rectangles.

Backing allocation is failable and bounded by an explicit256MiB native budget,
including per-pixel known bytes. Zero-filled allocation bytes remain semantically
unknown until written. Clear writes all backbuffer pixels. A primary clear writes
only the attached native window's client clip, then supplies an immutable known crop
to the window view. Other desktop positions remain unknown; no desktop pixels are
read or changed. Source null destination rectangles are retained, with clipping
applied by the physical backend rather than inserted into Core requests.

Image construction rejects unknown pixels. Copies retain their own bytes across
later mutation. The window view draws with interpolation disabled; a separate capture
method renders the AppKit view into an NSBitmapImageRep for physical checks. It is
not a screenshot of the monitor or Windows pixel comparison. No implicit clear,
present, format query or callback was added to windowed WinMain.

Microsoft's [DDSURFACEDESC](https://learn.microsoft.com/en-us/windows/win32/api/ddraw/ns-ddraw-ddsurfacedesc)
and [DDPIXELFORMAT](https://learn.microsoft.com/en-us/windows/win32/api/ddraw/ns-ddraw-ddpixelformat)
document descriptor fields. [Blt](https://learn.microsoft.com/en-us/windows/win32/api/ddraw/nf-ddraw-idirectdrawsurface7-blt)
documents null-target extent and color fill; [SetClipper](https://learn.microsoft.com/en-us/windows/win32/api/ddraw/nf-ddraw-idirectdrawsurface7-setclipper)
documents association references. These modern Surface7 descriptions guide the
declared Native mapping, not a measured old-interface Windows contract. Apple's
[bitmap byte order](https://developer.apple.com/documentation/coregraphics/cgbitmapinfo)
and installed SDK declarations describe host image delivery. Original NTSD remains
the only game-rule reference.

## Checks and remaining gates

Four new methods cover whole startup with owned resources; masks/full raw fill colors
and AppKit view readback; protocol/unknown/unsupported/allocation-budget boundaries;
and late retry, releases and context lifetimes. Add the unchanged420-case clear
method to the29 prior methods: total34. They are implemented and selected, not run.
Author inspection is not independent review. Automatic visible-window teardown,
partial/offscreen clipping and multi-screen movement still need additional contracts.

The first five-file parse passed. Author cleanup then added explicit destruction
of protocol-test windows; the old parsed draft and first syntax results remain
preserved. A second five-file parse passed. An earlier unused test setup and a
constructor spelling were corrected before parsing, with the unparsed draft kept.
No failed comparison or expected value was changed.

Artifacts are under build/research/application-mac-display-20260926 on task-owned
X5. Preparation94155 and final parse11049 are terminal0/absent. Implementation
closure separately verifies2261 candidate files, root1034/base2257/source55,
old tests/fixtures/resources, five-file patch roundtrip and regular/PAX archives.

NEXT: fresh build/package/all34 on the frozen candidate, checking5MacPlatform
sources/279tests plus unchanged Core/Reference/resources. Actual allocation, clear
and AppKit readback must pass before their behavior is accepted. Independent review,
general blit/presentation, palette/color-key/font/format conversion, callbacks,
fullscreen, remaining providers/audio, loading/root promotion/Windows/visual/input/
clean-Mac/full match/full game remain open. NTSDApp still Practice; source59727 stays
terminal34 Objects, not137. Safety incidents remain open. EXE envelope not recalculated.

## Verified implementation closure

Finalizer14412 terminal0/absent. All2261 candidate files/60 directories, five-file
patch roundtrip and61-member PAX metadata archive verified, including full bodies,
modes,nsmtimes,membership and distinct clone inodes. Root1034/base2257/source55 and
all old tests/resources remain unchanged. Candidate manifest SHA256
`c6077a1eeaec431860dc58930ac8eed593faba350870bc597cf256383bc5905f`.
[Publication](../evidence/application-mac-display.json),
[closure](../evidence/application-mac-display-close.json),
[patch](../evidence/application-mac-display.patch). Fresh build/all34/actual AppKit
readback and independent review remain open.
