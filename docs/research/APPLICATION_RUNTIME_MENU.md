# Live front menu — the app shows and drives the original menu

2026-09-28. [Plan](APPLICATION_RUNTIME_MENU_PLAN.md). Author implementation and
machine checks; independent review unavailable and open. No original code
executed; one static read of the pinned EXE.

## Result

After runtime WinMain, `NTSDNative --original` advances the recovered front
menu one whole Host iteration at a time on the real window, with every
external request served as a permit and no corpus reply. Captured window:
the original background, logo, menu entries (START, ONLINE GAME, CONTROL
SETTINGS, RECORDING INFO, OFFICAL WEBSITE), "Update off" and the cursor sprite.
Keyboard input reaches the recovered WndProc through PeekMessage/GetMessage/
TranslateMessage/DispatchMessage.

Core (additive; existing callers unchanged):

- `OriginalApplicationBootstrap.step` / `OriginalApplicationHostSession.step`:
  optional queue and window-default providers; mixing with prepared arrays is
  rejected.
- `OriginalApplicationObservedIteration.swift`: one ordered journal for menu
  graphics, message-loop queue and WndProc window requests; platform delivery.
- `OriginalWindowInput`: messages 0x102–0x104 and 0x106–0x111 return
  DefWindowProcA without stores, from a static decode of the EXE tables
  ([evidence](../evidence/wndproc-default-messages.json), S level).

NTSDMacPlatform: `OriginalMacRuntimeMessages` (queue, MSG layout, US key map
to VK/scan codes, TranslateMessage → WM_CHAR, coalesced mouse moves),
`OriginalMacRuntimeMenu` (runtime first-menu inputs and permit routing),
service overloads for the new permits, a window input hook/PNG snapshot and two
runtime-only display options. NTSDApp schedules iterations honoring the game's
Sleep and reports the first boundary.

## Contracts found while connecting

Each was diagnosed from the recovered code, EXE bytes or saved source records:

1. **Zero-area Blt.** For frame −1 the draw helper falls through and reads
   untouched wrapper words (+0x0C and negative-frame offsets). Saved runs used
   0xA5 backing, so the second draw was skipped; zero-filled runtime storage
   (as fresh Windows heap pages) yields a zero-area Blt. The runtime answers it
   with `DDERR_INVALIDRECT` without pixels — declared, unobserved on Windows;
   callers ignore the result. The verified backend is unchanged.
2. **WM_SIZE/WM_MOVE.** The present rectangle at 0x453ccc is computed by the
   WndProc's WM_MOVE handler. Windows sends WM_SIZE and WM_MOVE synchronously
   during CreateWindowEx; the startup model does not execute them. The saved
   corpus bridged this by queueing WM_SIZE; the runtime queues WM_SIZE then
   WM_MOVE first. The lifecycle DefWindowProc for WM_MOVE returns 0.
3. **Unknown pixels.** Presentation rejected unknown back-buffer pixels (DIB
   RLE holes stay unknown in the verified decoder). Runtime-only options: fresh
   surfaces start known black and presentation shows unknown pixels as black.
   The game does not read presented pixels; comparison tests keep defaults.
4. **Text.** GetDC answers E_FAIL, so recovered code omits GDI text. A GDI font
   raster contract is still missing.

## Checks

[Evidence](../evidence/application-runtime-menu.json),
[window capture](../evidence/application-runtime-menu-capture.png).

- Differential: the new driver, answering queue/window-default permits from the
  saved first-menu packets and graphics with the existing normal profile,
  commits the same session, effects, graphics and loop result as the prepared
  `Application.step` for every first-menu iteration, with and without a late
  publication failure and retry. Mixing prepared arrays with permits is rejected.
- WndProc default set: returns the DefWindowProc reply with unchanged globals;
  0x105/0x112 stay with their lifecycle handlers.
- Runtime queue/key-map unit test; runtime startup plus live menu: first-menu
  load (`LoadGameArt: Art loaded.`), committed iterations with an empty queue,
  then a key press delivers WM_KEYDOWN, WM_CHAR, WM_KEYUP after the bridge.
- 51/51 tests in 13 suites pass (698s), including graphics/bitmap/host-session/
  menu-input/window-input/lifecycle/display/front-raster/geometry/window and the
  runtime startup suites. Earlier runtime-menu rounds are preserved in the
  evidence as the diagnoses above.
- App: `--original --capture-after 60 … --exit-after-capture` exits 0 after 60
  committed iterations (1484 permits, 174 declared GetDC failures, 116 empty
  Blts). The capture shows the original menu.

These are Native/Mac executions with declared runtime policies; the capture is
not a Windows comparison. Permit drivers re-run an attempt per permit: cheap for
menu iterations, but the verified loading caller needs 2072 permits over the
whole catalog (≈45 min), so loading needs a cheaper delivery before it is live.

## Remaining blockers toward the Naruto/Sasuke match

1. Loading: the first `.loading` request needs runtime common/catalog/pool/
   loaded-menu providers (allocation, bitmap surfaces, file IO, time, message),
   now supplied only by saved corpora in the passing whole caller.
2. GDI text raster, music output (WMA), ESC/MessageBox and WM_CLOSE shutdown
   paths, device/Windows acceptance, full match and game.
EXE envelope not recalculated.
