# Window lifecycle and display-mode recreation

Status: declared lifecycle corpus accepted in raw and packaged comparisons.
Results and remaining boundaries: [WINDOW_LIFECYCLE](WINDOW_LIFECYCLE.md).
Parents: [WINDOW_INPUT](WINDOW_INPUT.md),
[WINDOW_INITIALIZATION](WINDOW_INITIALIZATION.md),
[MENU_PRESENTATION](MENU_PRESENTATION.md).

Recover whole original43b3d0 calls for window move3, size5, activation1c,
cursor20, system-key-up105, system-command112, palette30f/311 and destroy2.
Alt+Enter must include actual401ae0/401a80 destruction, whole43bdd0 display
creation and all accepted window/DirectDraw/surface/clipper/clear children.
Other message values whose static dispatch reaches DefWindowProc directly get
representative controls. Do not substitute an accepted43bec0 wrapper for43bdd0:
the wrapper adds an instance store and an extra ShowWindow.

The pinned NTSD EXE SHA256
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c and bundled lib.dll
28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba execute with
Unicorn2.1.4 after the complete accepted installer parent. Win32/COM results,
rectangle outputs, opaque helper-entry scratch and resource ownership are
explicit controlled inputs. Source instructions/stores recover ordering and
retained fields; no real Windows window, surface, device, heap or network is
operated. No original control/security pointer is deliberately corrupted.

Finite acceptance:
1. Whole callback returns cover each listed message, both relevant flag values,
   ignored numeric failures, original result/DefWindowProc behavior and exact
   move rectangle order. Preserve source bytes/masks and request/store order.
2. Whole Alt+Enter covers both directions, disabled toggle, non-Enter default,
   absent/present display resources, and failures/retries throughout actual
   recreation. State458434 is set before destruction, clears after ShowWindow;
   retain the original0/1-vs-negative error propagation. Include real401a80
   release/clear order and ignored DestroyWindow errors, with no fake success.
3. Rebuild fresh window-initialization results natively and carry their own
   state/resources through ordinary move, minimize/restore, fullscreen changes,
   cursor/palette and final destruction callbacks. Do not inject expected
   after-state. Callback sequences are declared harness stimuli; actual Windows
   delivery/reentrancy is not inferred.
4. Destroy2 composes accepted sound/music/replay cleanup and PostQuitMessage
   only when458434==0. Reuse native shared children, preserve old callers/tests,
   compare allocation lifetime and full late rollback for missing ownership,
   helper backing and observer errors.
5. Palette30f null checks and external/internal311 window cases execute with
   valid owned surface tokens when dereferenced. External311 with a null primary
   is a static possible fault; do not manufacture it. Its ordinary Windows
   delivery/reachability remains open; native unavailable storage is rejected.
6. Capture atomically; all completed cases/raw bytes stay immutable. Compare raw
   native output before packing; verify full raw/packed JSON/bytes/SHA, prior
   fixture/vendor pins and isolated native export excluding foreign transforms.

WM400 DirectShow's401e90 event loop and WM401 Winsock's402ec0 handshake are
separate required dependencies. The latter is not default-message behavior.
Input100/101,200..205 and joystick messages retain WINDOW_INPUT's contract.
Actual synchronous callbacks during Create/Update/DestroyWindow, Windows NLS/
CRT/WinMain provenance, macOS event translation and device ownership remain
open. This controlled lifecycle must not be presented as actual Windows API
behavior, a complete WndProc/app, a full match or completion of the full goal.
