# Mission Mode stage logic in Native and the app

2026-09-29. [Plan](APPLICATION_MISSION_PLAN.md). Parent: [Quit](APPLICATION_QUIT.md)
(68fcf6e). Author implementation and machine checks; independent review open.
The original was executed only in the Unicorn oracle.

## Result

`OriginalMissionStage.apply(state:target:sse2:observe:)` (NTSDCore) ports the
Mission Mode stage logic 437860 with its helpers 437400 (one phase spawn) and
436fc0 (next stage): phase starts with weighted spawns, per-frame enemy
tracking and the two respawn passes, phase advance, the banner timer with the
"GO" flash, bound and wipe to the next stage, the stage-set end and the next
set or the ending menu, and the HUD lines. Stage records are the catalog's
(7d0 + s·149b08) and are now mutable match state (`OriginalMatchPreparation.stages`),
as the original writes its spawn-slot runtime words there.
The already accepted callees (43f010 bitmap draw, 415160 fill, 401290 surface
text, 401a30 sound, 402020/402100 music) are reported as calls with their EXE
return addresses; the VC80 sprintf output is written to 451418.

The gameplay body composes it at the post-draw mode1 child: bitmap draws and
fills through its surface/blit/fill providers, text through the surface-text
renderer, sounds through the queued-sound request, the stage-set music stop
through a new music request provider (gameplay session → runtime music).
Phase music (402020) stays an explicit boundary: `data/stage.dat` has no
`music:` entries. Mode 4 (War) remains unsupported.

**App (release, virtual clock):** Mission Mode starts Stage 1-1 on Grassland;
the "STAGE 1-1" banner, spawned enemies and the library's story dialogue play
([capture](../evidence/application-mission-capture.png)); with an idle player
the enemy knocks Naruto out and the Summary shows "Lose (Dead)" (3000 bodies,
no boundary). The first attempt stopped after ≈260 AI ticks at the bundled
library's transform write through Actor+0x7b4 ("Library transform +7b4:
Unavailable destination backing", [LIB_TRANSFORMS](LIB_TRANSFORMS.md)).

## Declared runtime policy: lib.dll's Actor+0x7b4 write

The library transform (states 4000..4999) stores through Actor+0x7b4, beyond
the 0x420-byte Actor. A static scan finds that single store in lib.dll
(10001112) and no reader of Actor+0x7b4, +0x38c/+0x390/+0x394 or +0x2b4 in
the DLL or the EXE (the EXE's `+0x7b4` operands index Object frame 0), so
the destination decides ownership only. In the app's runtime heap the 400
Actors are consecutive 0x420-byte blocks (checked from their address tokens
before use): Actor i's write lands in Actor i+1 at +0x394, Actor 399's in a
declared record for the following block. `OriginalApplicationGameplaySession`
takes this backing from the caller when the application state has none
(`transformBacking:`); verification paths keep the empty default and still
reject the write. Windows' own heap layout is not claimed.

## Checks

- **Oracle** `tools/oracle_mission_stage.py`: 437860 called directly after the
  verified first loading (main CW027f, control CW037f over the control
  loading) on the catalog's 25 real stages (sets 0–4, 10–14 … 40–44; no
  survival stages), with families start, phase, banner, end, bound, set,
  pressure, survival (stages 50–59 without records) and refill (a declared
  synthetic survival stage for the HP refill). Callees are recorded
  boundaries; sprintf runs the pinned VC80 DLL. Written global and stage bytes
  are tracked, so initialization masks compare exactly.
- **Comparison:** both corpora of 2960 real 437860 calls match Native with
  exact bytes and initialization masks on every global, stage record, World
  and Actor: main 91550 RNG draws, 27371 callee calls, 16008 constructors,
  9362941936 bytes/masks; control 103095 draws, 27062 calls, 15719
  constructors. (Before the synthetic stage's phase-1 bound was declared, the
  first strict run already matched its first 2881 cases and stopped at an
  undefined read in that stage — a stimulus gap, not a port difference.)
- A first, value-only corpus (2760 cases, before the added families) matched
  on the first comparison: 74853 RNG draws, 25382 callee calls, 14355
  constructors, every global/stage/World/Actor value.
- **Coverage:** 400 (main) and 395 (control) of 405 static block leaders of
  437860/437400/436fc0. Not executed: two padding leaders, two negative-value
  sign corrections (43828c, 4387e1) that valid timers never reach, the
  survival banner 4381eb (stage ≥ 50 with a running timer: no such stage
  data), 437109 (a player frame 16..18 at the next stage) and the jump into
  43896c (set 4 with 450b88 set and a menu other than 10).
- Tests: `OriginalMissionStageTests` 2/2 in 624.7 s; the suites of the
  changed composition (library transform, world impulses, active body,
  gameplay provider, paused gameplay, runtime loading) 16/16 in 55.7 min;
  `OriginalMacMusicOutputTests` 6/6. `tools/app_e2e.py` gains a `mission`
  scenario (reference recorded and reproduced) and the VS reference still
  passes.

EXE envelope not recalculated.
