# Alt+Enter full screen — plan

2026-09-30. Task → contract → milestone: the original toggles full screen on
Alt+Enter, releasing and recreating its window and DirectDraw objects; the Mac
app never produces that message → the ported lifecycle composed with a Mac
display service that can rebuild the window in either mode → the game's own
full-screen switch. The original is not executed.

## Static reading

- WndProc 43b3d0's key-message table (43bc74/43bc88): 0x100 → 43b531 (key
  flags), 0x101 → 43b833, 0x105 WM_SYSKEYUP → 43b83f, 0x112 → 43b519; 0x104
  WM_SYSKEYDOWN falls to DefWindowProc.
- 43b83f: only wParam VK_RETURN: OutputDebugStringA("Alt enter...\n"); if
  44d794 ≠ 0: 458434 = 1, 458430 = !458430, 401ae0 (401a80 DirectDraw release,
  DestroyWindow), 43bdd0 (recreate), ShowWindow(hwnd, SW_SHOW), 458434 = 0.
  WM_DESTROY during it does not post WM_QUIT (458434 ≠ 0, already ported).
- 43bdd0: 458430 selects 401bf0 (full screen: IDC_ARROW, RegisterClassA with
  the same WndProc, CreateWindowExA(WS_EX_TOPMOST, …, WS_POPUP, 0, 0,
  GetSystemMetrics(SM_CXSCREEN/SM_CYSCREEN))) or 401b00 (windowed 794×550),
  then 401000 DirectDraw with the full-screen flag and 401300 surfaces.
- Core already has all of it, compared: `OriginalWindowLifecycle` case 0x105
  (`OriginalDisplayDestruction.destroy`, `OriginalWindowInitialization.configure`
  with its full-screen `fullConfigure` branch, 458348 = 2).
- Missing: the Mac runtime posts only WM_KEYDOWN/WM_KEYUP (no Alt, no
  WM_SYSKEY*); the session sends only WM_SIZE/WM_MOVE to the lifecycle; the
  runtime's lifecycle path answers only WM_MOVE's DefWindowProc.

## Declared policy (not the EXE)

Option is Alt (VK_MENU): with Option held, key transitions arrive as
WM_SYSKEYDOWN/WM_SYSKEYUP with the context bit, as Windows sends them.
DefWindowProc for them follows Windows where it matters (Alt+F4 → SC_CLOSE,
Alt alone → SC_KEYMENU) and does nothing else. Full screen on the Mac is the
window in macOS full screen showing the game's 794×550 image scaled to fit
(aspect kept); the full-screen display requests (screen metrics, exclusive
cooperative level, display mode, the flip chain) get declared answers.

## Stages

- **FS1** — system keys in the runtime queue (VK_MENU, WM_SYSKEY*) and their
  DefWindowProc answers; checks: runtime-menu tests, the e2e set.
- **FS2** — the session routes WM_SYSKEYUP to `OriginalWindowLifecycle`; the
  runtime serves `OriginalDisplayDestruction` and a full reconfiguration
  (windowed and full screen) against the Mac window/display backends.
- **FS3** — presentation in full screen (present mode 2, Flip) and the
  NSWindow full-screen transition; app checks both directions, e2e set.

- **Not a dependency (corrected 2026-09-30):** 401a80 releases only the target
  surface 455608, the primary 455634 and the DirectDraw object 457578; the
  sprite surfaces are never released or reloaded (their own references keep
  them valid across the recreation). The loop's surface recovery 43e890 is
  43e860 (IDirectDrawSurface::Restore of primary and target; ≥ 0 or
  DDERR_WRONGMODE is success) and otherwise the same recreation as Alt+Enter;
  it runs only when the dispatcher reports a lost surface, which the Mac
  surfaces never do (declared). An earlier draft of this plan assumed the
  sprites had to be reloaded; the static reading above replaces it.
- Also: `OriginalMacWindowBackend` validates only the windowed CreateWindowEx
  (style 0x10cb0000, metrics 7/8/4); the popup (WS_POPUP, WS_EX_TOPMOST,
  metrics 0/1) and the exclusive DirectDraw requests are new backend work.
- DestroyWindow during the recreation delivers WM_DESTROY to 43b3d0. Its
  handler runs the shared release helpers, ported as
  `OriginalMenuPresentation.releaseResources`: the DirectSound device, the
  DirectShow music graph and the two replay-recording buffers are released,
  then PostQuitMessage is skipped (458434 ≠ 0). Nothing re-creates them, so in
  the original a toggle leaves the game running without sound effects, music
  or recording buffers. `OriginalDisplayDestruction` emits DestroyWindow as a
  platform request and, like `OriginalWindowLifecycle`, deliberately does not
  model the nested WM_DESTROY/WM_NCDESTROY (or the creation-time WM_SIZE/
  WM_MOVE) Windows delivers synchronously; FS2 needs that nested delivery in
  Core, with the enclosing state and rollback.

**User decision needed before FS1/FS2:** reproduce Alt+Enter faithfully (the
game's own window/DirectDraw recreation, including its loss of sound, music
and recording buffers), or offer macOS full screen for the window without the
game's involvement (the image scaled, nothing released), or both.

Status: scoped; implementation waits for that decision.

EXE envelope not recalculated.
