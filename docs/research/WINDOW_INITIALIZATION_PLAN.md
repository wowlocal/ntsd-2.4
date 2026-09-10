# Whole game window and DirectDraw initialization

Status:280 controlled whole returns accepted; initialized app/device join open. Parent [LIB_RUNTIME](LIB_RUNTIME.md).
The incomplete [CRT startup](CRT_STARTUP_PLAN.md) remains open at Windows NLS;
this independent controlled entry does not bypass that dependency in an own chain.

Recover the original game's whole43bec0 wrapper,43bdd0 window/display selection,
401b00/401bf0 window helpers,401000 DirectDraw setup,401090/401110 surface creation,
4011d0 clipper setup,401300 full-screen fallback and43e8e0/401250 initial clearing.
These establish the native application's window, surface ownership, display mode
and startup error/order behavior. Do not infer failure propagation from names.

Reference: pinned NTSD 2.4.exe SHA256
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c and bundled lib.dll
SHA256 28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba. Reproduce
its complete accepted installer before controlled calls. Original instructions
execute on Unicorn2.1.4 with declared module/window/COM tokens, Windows metrics,
API results and per-helper entry scratch backing. Actual Windows callbacks,
DirectDraw/device allocations and raster output are separate, not emulated facts.
No native runtime DLL, executable patching, Windows API or CPU interpreter.

Acceptance:
1. Execute whole43bec0 returns for windowed/fullscreen choices, all observed
   failure/retry branches, positive/negative HRESULTs, ignored API failures,
   live globals, dimensions/metrics wrapping and unused command-show argument.
   Start with normal paths and one failure at each requested operation; extend
   only for newly observed branch/lifetime dependencies. Retain every completed
   case atomically and never restart a live source job for silence.
2. Compare complete controlled globals before/after and masks, ordered requests,
   returned handles, release order, structure bytes/helper write masks and whole
   return ABI. Recover real arguments, reused descriptor fields and aliases;
   immutable original output is the expected result.
3. Native code supplies its own staged globals and takes explicit declared API
   responses. Opaque scratch comes from a declared helper-entry provider, never
   from expected structure output. Keep unknown fullscreen cursor/DDSURFACEDESC/
   pixel/fill backing explicit. This does not recover an initialized WinMain
   stack or make unknown bytes safe to consume in a native app.
4. Exercise missing scratch/output provenance and a late observer rejection for
   full native rollback. Preserve numeric error behavior of original calls;
   native-only rejection is not a successful original match. No deliberately
   corrupted callback/security/control-pointer stimuli.
5. Verify original instruction bytes, original installer equality, all native
   results, full raw/packed JSON/bytes/SHA and previous fixture pins. Build/test
   from an isolated committed export excluding unfinished concurrent transforms.

Preliminary STATIC findings to test:43bdd0 uses0/1, while43bec0 checks its return
for negative and then ShowWindow(...,5); the actual command-show parameter is
unused.401bf0 leaves WNDCLASS.hCursor unwritten.43e8e0 returns0/1, so the negative
retry branch in401300 may be unreachable. These are not execution claims yet.
The finite source corpus and native acceptance report must state actual coverage.
Full CRT/NLS/MSVCP80, WinMain composition, actual window/device/Windows behavior,
full library-enabled match/content and clean-Mac acceptance remain open.

Acceptance and limitations: [WINDOW_INITIALIZATION](WINDOW_INITIALIZATION.md).
The complete corpus is terminal and must not be restarted.
