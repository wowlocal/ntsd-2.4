# Application tick speed: the app runs at the original's pace

2026-09-28. [Plan](APPLICATION_TICK_SPEED_PLAN.md). Parent:
[VS with a computer player](APPLICATION_COMPUTER_VS.md) (94762ea). Author
implementation and machine checks; independent review open. The original was
not executed.

## Result

The computer-VS match (Naruto, Sasuke and a computer player; the `cpu12`
script) now runs at **30.3 ticks/s against the real clock**, the original's
own 33 ms pacing, through 1800 bodies (9.9 s per 300 bodies). The app works
≈8.5 ms per body. The parent ran ≈8 ticks/s (37 s per 300 bodies, 19 s of it
in `complete()`). [Capture at tick 1800](../evidence/application-tick-speed-capture.png).

Two causes, both outside the game logic:

1. **App Nap (dominant).** Once the window was not frontmost, macOS
   throttled the app's scheduled iterations and CPU (≈7 % CPU and ≈210 s per
   300 bodies in the virtual-clock runs; the same work takes 3.4 s
   unthrottled). Windows does not throttle a background game's Sleep loop;
   the app now holds a `userInitiated`/`latencyCritical` activity for its
   lifetime (declared host policy).
2. **Unused per-stage snapshots (≈30 % of the remaining work).** Every
   gameplay body built an owned snapshot at each of its 19 stages and every
   loaded cycle at its prologue and 6 checkpoints; each copied the 16 k-entry
   allocation dictionary and compared 400 Actor records
   (`OriginalApplicationMatchBindings.store`, 41 % of the throttled tick loop).
   The app never used them. `GameplaySession.advance` and
   `LoadedCycleSession.advance` take `checkpoints:` (default `true`, so tests
   and other callers are unchanged); the app passes `false` unless
   `--stage-checkpoints`. The final join with all its checks still decides
   each attempt. Unthrottled: 3.3–3.5 s → 2.3–2.6 s per 300 bodies.

## Reproducible runs

Real-clock runs differ from each other (the CRT seed is the startup
timeGetTime), and a faster app changes which iterations run a body. New app
option `--virtual-clock BASE STEP`: timeGetTime answers BASE + STEP ×
iterations started, the startup FILETIME and GetLocalTime use 2026-01-01
00:00 UTC and GetMessagePos answers (0,0). With STEP 8 the `cpu12` menu path
still selects one computer player (with STEP 6 the count pop-up opens after
the scripted keys). `--stage-checkpoints` runs the unchanged observation path.

## Checks

- **Same game:** with `--virtual-clock 123456789 8`, body captures at
  300/600/900/1200/1500 of the reference path (`--stage-checkpoints`), the new
  path, and both again with the App Nap exemption are byte-identical
  (3 fighters, character AI every tick, 1268 object inputs).
- **Time per 300 bodies (busy in `complete()` / wall):**

  | Run | Busy | Wall |
  | --- | --- | --- |
  | Parent binary, real clock | 19.1–19.7 s | 36.6–38.0 s |
  | Reference path, virtual clock, App Nap | 18.6–19.7 s | 210–227 s |
  | New path, virtual clock, App Nap | 10.3–11.0 s | 202–218 s |
  | Reference path, virtual clock, no App Nap | 3.3–3.5 s | 10.2–10.8 s |
  | New path, virtual clock, no App Nap | 2.3–2.6 s | 9.3–10.7 s |
  | New path, real clock, no App Nap | 2.4–2.6 s | 9.9 s |

  The first 300 bodies also contain the match launch (≈8 s).
- **Tests:** `OriginalApplicationGameplayProviderTests` (3), `…PausedGameplayTests`
  (2), `…LoadedCycleTests` (3) and `OriginalMacRuntimeLoadingTests` (2):
  10/10 in 26.9 min with 3 parallel workers. A serial run that also selected
  the Active*/Host/LoadedMenu/Projection suites was stopped after 64 min
  (≈20 min per test); its results were not observed.

## Remaining costs (profile of the new path, virtual clock)

Front replay on the display (1024 of 3285 samples of the loop: each front
operation is validated twice, per-pixel copies), Core Animation drawing of
the window image (545), request-exchange cursor copies in the menu step
(533), the replay packet write copying its record (387). They matter only for
heavier matches or slower Macs; none is needed for the original's pace here.

EXE envelope not recalculated.
