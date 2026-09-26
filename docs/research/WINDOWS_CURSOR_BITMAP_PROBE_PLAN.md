# Windows cursor bitmap observation preparation

2026-09-26, base ab504f5. Parent: [first-menu raster contract](APPLICATION_FIRST_MENU_RASTER_CONTRACT.md),
[DIB pixels](APPLICATION_DIB_PIXELS.md), [surface loading](BITMAP_SURFACE_LOADING.md).
Read archive1968–2025,3706–3725,3889–3916 and WORKFLOW. The previous goal turn
made progress: verified ISO and actual Windows installer boot. Windows EULA
approval remains pending; this independent build does not accept it or run a guest.

The first native menu needs the original LF2_CURSOR bitmap. Its11x19 RLE8 resource
has108 written and101 unwritten positions, with three written-pixel differences
under macOS ImageIO. A bounded Windows loader observation is needed before those
gaps can be resolved. This probe prepares that observation without inventing
pixels; it is not a substitute for the original game/display comparison.

Reference EXE: downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe,
SHA2563f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c.
LF2_CURSOR RT_BITMAP payload SHA256
9382aac33a46878e4d94f1aea332fbd06a1508a21ee38b46be5149b9bbff39b8.
The original loader's resource fallback uses LoadImageA(type0,size0/0,flags0x2000).
Probe maps a task-owned EXE copy only as data/image resources (flags0x60), with no
EXE entry point, DLL entry point, patch, foreign-process memory or device hook.
This differs from the game's own GetModuleHandle; it stays explicit in provenance.

## Finite operation

Prepare freestanding x86 and ARM64 PE collectors using local clang/lld and the
existing NLS build/PE-inspection conventions. Reuse the PE inspector with an
explicit optional kernel32-import set; its existing NLS default is unchanged.
Do not create a general execution framework. Native game source/fixtures remain
unchanged. Independent review is unavailable; author checks are not independent.

Future Windows execution, separately authorized after OS setup, loads the fixed
reference.exe from a new capture directory and queries only LF2_CURSOR. Resource
Find/Load/Lock/Size APIs retain the exact embedded bytes. Three sequential fresh
LoadImageA bitmap lifetimes record GetObjectW's DIBSECTION, owned bitmap storage
before/after palette query, GetDIBColorTable output and cleanup replies. Read only
the allocation returned by successful GetObjectW after strict11x19/8bpp/plane1/
positive-stride and bounded-size checks. This is documented DIBSECTION bitmap
storage, not the game's private heap ABI. A failed query records the failure and
does not dereference an unproven pointer. No writes to bitmap storage occur.

Record full pointer-width fields, response/error values, collector process/OS/
machine/module provenance, destination seeds and complete returned buffers.
Pixel storage snapshots establish observed values only; they are not write masks,
deterministic initialization guarantees, DirectDraw color-key behavior or accepted
Native expected output. Palette queries temporarily select only the owned bitmap
into an owned memory DC, restore its previous object and release own resources.
All repeated outcomes remain; differences are not excluded. No GDI font/device
or complete first frame is claimed. Network/admin/permission changes are absent.

## Checks and bounds

Build twice in fresh task directories and compare kit bytes/PE imports, flags,
architecture, no writable executable section and no CRT. Inspect both retained
NLS PEs through the unchanged default import contract; do not rerun their capture.
Run only the newly compiled collector under synthetic API self-tests on each
architecture: complete/short write, module/resource/bitmap/query failure,
invalid descriptor boundary, failed selection/palette/cleanup, existing output,
failed/zero write, flush/close failure. Exact finite cases are frozen before that
test run; all artificial bytes are labelled synthetic, never Windows/source data.
Retain terminal failure and full output, then at most three diagnosed corrections.
Verify the future runner/capture validator against produced synthetic envelopes
without accepting them as actual Windows observations.

Task-owned X5 windows-cursor-bitmap-probe-20260926:1GiB ceiling,128MiB metadata,
600s per build/test/pack, retain40GiB plus17GiB source commitment and64GiB VM growth.
No large root build. New files limited to probe/build/test/runner/validator tools,
this plan/result/evidence, own navigation blocks and the optional inspector
parameter. All prior sources, plans, masks, fixtures and AGENTS archive remain
unchanged. The changed root inspector gets separately preserved old/new pins.

Complete preparation requires reproducible PE/kit bytes, bounded meaningful
self-tests, exact input/source preservation and verified package archive. Actual
Windows execution, loader equivalence, original full-game/device observations,
independent review and Native implementation remain separate open gates. Commit
the checked increment before another independent task. The Ghostty/IoT and other
existing refusals remain open; no affected operation is retried.

Primary API contracts: [LoadLibraryEx](https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-loadlibraryexw),
[LoadImage](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadimagea),
[GetObject](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-getobjectw),
[DIBSECTION](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-dibsection),
[GetDIBColorTable](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-getdibcolortable).
