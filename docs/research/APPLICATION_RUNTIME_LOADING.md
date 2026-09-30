# START → loading → mode menu in the app

2026-09-28. [Plan](APPLICATION_RUNTIME_LOADING_PLAN.md). Author implementation
and machine checks; independent review unavailable and open. No original code
executed.

## Result

In `NTSDNative --original`, clicking START (the saved case-47 point) loads the
whole original catalog (137 Objects, 669 images/829 surfaces, 400 sound
registrations), the 400-slot pool and the loaded menu in one attempt, then
returns through the Host tail and cached loaded cycles to the original mode
menu (VS Mode … Quit). Release build: 6.1 s for loading; the verified permit
path needs ≈45 min for the same 2072 audio requests.
[Capture](../evidence/application-runtime-loading-capture.png).

- Core: `OriginalRequestExchange.inlineCursor` and
  `OriginalApplicationObservedLoadingAudio.resumeInline` (additive; permit
  cursors unchanged).
- NTSDMacPlatform: `OriginalMacRuntimeLoading` (first loading, cached cycles,
  Host tails, committed-draw replay), heap `reserve`, 3 GiB runtime display
  budget. NTSDApp handles `.loading` and a scripted `--click-at`.

## Contracts found while connecting

1. **The front menu is mouse-driven.** Keyboard J on START does nothing; the
   saved case that reaches loading is WM_MOUSEMOVE (350,230) + WM_LBUTTONDOWN,
   and the button must stay down across a game tick.
2. **Surface budget.** 669 catalog images ≈228 M pixels; the verified backend's
   256 MB default stops loading after ~150 images. Runtime budget 3 GiB.
3. **Cached cycles.** After the first load every outer step returns `.loading`;
   each cycle runs the retained cycle input (two WSAAsyncSelect and two
   ioctlsocket requests, answered SOCKET_ERROR) and the loaded menu (≈0.25 s
   debug). Host tails may also Sleep.
4. **Draw replay.** Loaded-menu draws are committed effects, not permits. The
   committed prefix repeats the requesting iteration's staged effects (already
   performed) and, on the first load, ≈7178 progress-frame draws (353 s in a
   debug replay). Only draws after the input continuation are replayed (8 per
   commit); the loaded menu redraws the full frame.

## Checks

[Evidence](../evidence/application-runtime-loading.json).

- Inline cursor unit test: receipts recorded, retries reuse them, wrong reply
  family rejected, a failed service leaves the exchange indeterminate.
- Runtime START → loading test (debug): one attempt, exactly 2072 audio
  requests, 621 files, 12817 bitmap requests, 16105 allocations, 423 buffers;
  Host tail commits; 9 cached cycles return with 80 replayed draws (≈0.25 s
  each in debug). Earlier rounds (key-not-mouse, budget, tail Sleep, 353 s
  replay) are preserved in the evidence.
- 26/26 tests in 8 suites (754 s) for the changed exchange: exchange,
  startup, loading audio, three fast whole-caller methods, runtime startup/
  menu/iteration/loading. The loading suite re-ran on the final code (2/2).
- Release app: a held scripted click on START loads in 6.15 s and shows the
  mode menu. The first run's click (down+up in one burst) did not register.
- Launch/gameplay routing (`launch()`, `gameplay()`, `complete`) is compiled
  but not yet exercised; that is the next card.

## Remaining blockers toward the Naruto/Sasuke match

1. Mode → character → arena selection through cached cycles with live input,
   then `.matchPrelude`: runtime match launch (arena bitmaps, replay allocation,
   local time, music) and gameplay ticks are not connected.
2. GDI text, music output, loading progress frames, shutdown paths, device/
   Windows acceptance, full match and game. EXE envelope not recalculated.

## Independent review (2026-09-30)

A review of loading, match end and pacing found that the screens after START
(mode screen, panel links, Playback's folder) recorded their `ShellExecuteA`
and `Sleep(300)` but the app carried out neither. Both now run when the batch
commits, as on the front menu. Details and checks are in
[APPLICATION_MATCH_END.md](APPLICATION_MATCH_END.md#independent-review-2026-09-30).
