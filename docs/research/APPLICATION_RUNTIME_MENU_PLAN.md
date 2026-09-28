# Live front menu: whole-iteration permits and runtime input

2026-09-28. Parent: [runtime WinMain](APPLICATION_RUNTIME_STARTUP.md) (743380c).
Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md).

**Consumer in native/ and integration criterion:** after runtime startup,
NTSDApp advances the recovered front menu iteration by iteration on the real
window with live keyboard/mouse and clock input, until the first loading request
or an explicit unsupported device boundary, and can capture its window.
**Proven blocker (from the parent card):** `Host.step` takes message-loop and
window-default replies only as prepared arrays; no permit form exists.
**Reason for new runs:** new Core delivery path and runtime code. **Round:** 1.
**Executor / reviewer:** Claude (author); independent review unavailable, open.
**Reference:** EXE SHA-256 `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.

## Finite changes

Core (additive; default behavior of every existing caller unchanged):

1. `OriginalApplicationBootstrap.step` and `OriginalApplicationHostSession.step`
   accept optional queue and window-default providers; mixing a provider with a
   nonempty prepared array is rejected, as for lifecycle/surface today.
2. `OriginalApplicationIterationRequest` (graphics window/bitmap/front, queue,
   window-default) with one exchange, a value delivery on the platform and
   `OriginalApplicationObservedIteration`, modeled on the existing graphics
   iteration driver: all external requests of one Host iteration in original order.
   `OriginalApplicationPreparedStartupPlatform` gains `iterationDelivery`.
3. WndProc default messages. Static decode of the pinned EXE (S level, no
   execution): at 43b4fd messages 0x100..0x112 index byte table 43bc88 into jump
   table 43bc74; 0x102–0x104 and 0x106–0x111 select entry 4 = 43bc24, which
   pushes the original lParam/wParam/message/HWND, calls DefWindowProcA and
   returns its result with no global writes. `OriginalWindowInput.receive`
   routes exactly these messages to its existing window-default request.
   The head/default instructions are already executed by the verified input
   corpus; the new message values are static evidence only (review open).

NTSDMacPlatform runtime:

4. Runtime messages: a thread queue fed from NSEvent key/mouse events on the
   original window. PeekMessage(PM_NOREMOVE)/GetMessage write the 28-byte MSG
   (HWND, message, wParam, lParam, time, cursor point); TranslateMessage posts
   WM_CHAR for character keys and returns nonzero for key messages;
   DispatchMessage returns the Core result; timeGetTime from the monotonic clock;
   Sleep(ms) is recorded and schedules the next iteration. Keys map macOS key
   codes to Windows VK codes and set-1 scan codes in lParam (repeat bit 30).
   DefWindowProcA returns 0 for the delivered key/char/mouse messages.
   MessageBoxA (Esc) shows a Yes/No alert (IDYES 6 / IDNO 7).
5. First-menu inputs from runtime sources: `control.txt` bytes (overlay, else
   package), file/scratch identities from the runtime heap, close 0; prefix
   clock sample, worker thread handle/ID identities (worker body not run: no
   network), lastError 0; 25 wrapper allocations from the runtime heap; bitmap
   resources from the package.
6. Display policy for the live app only: fresh surfaces start known black
   (runtime option; default stays unknown); GetDC for text returns a declared
   failure (text omitted) until a GDI text contract exists.
7. App: after startup, iterate on a main-thread timer honoring Sleep; stop at
   `.loading` or a boundary; `--capture-after N path` saves the window view.

## Checks and limits

- Differential (no new expected values): the new driver, answering queue and
  window-default permits from the saved first-menu packets and graphics with
  the existing profile replies, commits the same effects/graphics/session as
  `OriginalApplicationObservedGraphicsTests.prepared` for the dispatch iteration,
  after the pre-dispatch packets.
- WndProc default: every message in the decoded default set returns the
  DefWindowProc reply with unchanged globals; 0x100/0x101/mouse paths unchanged.
- Runtime messages unit tests (key map, MSG bytes, WM_CHAR, peek/get order).
- Runtime startup + menu iterations with an empty queue, then a key press/
  release, reaching committed iterations on real services; the captured window
  is inspected.
- Regressions (changed dependencies): ObservedGraphics, ObservedBitmap,
  ObservedLifecycle, HostSession, MenuInput, WindowInput-related tests and the
  new runtime startup tests. Debug build in `build/swiftpm-app`; each test run
  ≤ 1800s. Three correction rounds, then diagnosis.
Out of scope: loading/catalog/pool/loaded menu providers, GDI text raster,
music output, Windows/device acceptance, full match/game. EXE envelope not
recalculated.
