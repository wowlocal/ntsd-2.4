# Demo mode in the app

2026-09-29. [Plan](APPLICATION_DEMO_PLAN.md). Parent: [War](APPLICATION_WAR.md)
(4651853). Author implementation and machine checks; independent review open.
The original was executed only in a Unicorn oracle.

## Result

- `OriginalMusicPlayback.selectDemoTrack` ports 4025d0 (to its jump to
  4025b0). The oracle `tools/oracle_demo_music.py` runs the real function over
  the pinned EXE image: 102 cases (music off/on/other nonzero; tracks 0 with
  RNG states, 1..8, 9, −1, −8, 100, large values; empty and set prior paths),
  151 executed blocks. `OriginalDemoMusicTests` matches every case: RNG draw
  (tag 2, range 8), all 32 bytes at 44eed0, RNG words and the 402020 play.
  [Evidence](../evidence/demo-music.json).
- `OriginalMatchSelection` accepts the Demo (mode 5 with 450c2c = 1);
  `OriginalComputerSelection` accepts mode 5 and draws no computers for a
  count ≤ 0 (42ba84's signed test; the −100 sentinel).
- `continueMenu` takes optional `OriginalDemoStartProviders`: 4025d0's ECX,
  the 4025b0 play, arena layers constructed/released with surfaces. Without
  them the recovered contract stays (music off, bitmap-input layers).
- The loaded menu session supplies the providers (arena wrappers adopted with
  their surfaces, owners appended as for War start); the Demo start's fill,
  reconstruct and layer events are routed.

**Declared runtime policy — 4025d0's ECX.** 4025d0 has one caller (42d7a1) and
no pushed argument; its `push ecx` slot holds ECX left by the preceding text
call, whose last instruction before returning is DirectDraw's GetDC (failure)
or ReleaseDC inside lib.dll's 401290 replacement (10001298..10001309). That
register is unknown on Windows. The runtime declares a value outside 0..8
(`OriginalMacRuntimeLoading.demoMusicResidue`, the E_FAIL of its own GetDC):
the configured track in 44eed0 plays and no RNG draw is taken. With a residue
of 0 the original would draw RNG tag 2 before the arena and characters and
change the Demo's content; a Windows check would settle the value.

**App (release, virtual clock):** main menu → Demo: eight computers fight
with the DEMO label ([capture](../evidence/application-demo-capture.png));
the first match plays `bgm\stage1.wma`, then the next Demo match starts on
another arena with `bgm\stage5.wma` (no recording). Jump pressed in the
closing window of a match (144..350 bodies after it is decided) ends the Demo
and returns to the main menu ([capture](../evidence/application-demo-exit-capture.png)).
`tools/app_e2e.py` gains a `demo` scenario (reference recorded and reproduced).

**Tests:** `OriginalDemoMusicTests` 1/1, `OriginalMatchContinuationTests` 1/1
(continuation corpus with all team patterns, unchanged contract without
providers), `OriginalLibSelectionStageTests` VS and War 2/2 (parallel);
`tools/app_e2e.py --scenario all` (VS, Mission, Demo, War, Quit) pass.

EXE envelope not recalculated.
