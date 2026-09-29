# Mission Mode in the app: plan

2026-09-29. Parent: [modes survey](APPLICATION_MODES_SURVEY.md), [Quit](APPLICATION_QUIT.md)
(68fcf6e). Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md).
Written before implementation; decode in progress. **Executor/reviewer:**
Claude; independent review open.

**Consumer and criterion:** Mission Mode (mode 1) plays in the app: the
stage's phases spawn their enemies, clear, show their banners and advance,
the stage ends as the original does. **Proven blocker (survey):** the first
Mission body stops at "Post-draw: original mode1 child is not recovered":
41f4ac calls `437860(target, 0x44d020)` on the World when 451160 == 1 (and
mode 4, War, calls `43a860(target)`).

## Static reading so far (437860..4388ac, ret 8)

- Clears 0x190 words at 4514e0 (per-seat "listed in a spawn" flags); stage
  work only while 450ba8 < 3.
- Stage `s` = 450b94, phase `p` = 44fb6c; records at catalog + s·0x149b08 +
  p·0x34c0: phase count +0x7d0, bound +0x7d8 (450bb0 = bound − 0x31a,
  450bb4 = bound), music path +0x7dc (402020 when non-empty), next phase
  +0x3c90 (−1 = sequential), phase bound +0x3c98.
- Phase start (p = −1 or phase cleared with 451b34 = 1): player weight =
  active type-0 Objects, +1 for id 0x33 and +2 for id 0x34; with difficulty
  450c30 = −1 it is scaled by a double and ftol; stage s/10 == 5 refills HP
  (+0x2fc, max +0x300), +0x308 = 500, +0x10 and +0x58 of the 400 Actors.
- 60 spawn slots per phase (0xe0 bytes from +0x810; id +0xac… −1 = unused):
  amount = ftol(weight·ratio(+0xd0))·(+0xb8), capped at 40, else +0xb8 and 1;
  each spawn calls 437400(slot, index).
- Per frame: seats listed in slots mark 4514e0; a listed live team-5
  type-0 Actor sets 451b30; two passes respawn/advance slot counters
  (+0xd8 "reserve", +0/+4 counts) calling 437400; 451b34 = 1 when no
  team-5 enemy remains.
- Clear/banner timer 450b9c (0xa9 at a phase clear, 0x118 at the stage
  end): 43f010 draws stage/phase digits from bitmap 451178 (or 451168 for
  s/10 ≥ 5) at y 0x12b; every 10 frames the "GO" flash plays m_ok (401a30,
  455610) while < 200; 450bac marks the last phase; 450ba4 continues.
- Stage end: when s%10 == 9 or the next stage record (+0x14a2d8) is −1,
  450bdc counts: at 1 music stops (402100) and m_??? (401a30, 455618)
  plays; below 90 the end banner (43f010, 0xd7/0x12a/0x25); 450ba8 = 1.
  Otherwise, when every live player's x (+0x10) passed the phase bound,
  450ba4 = 1 and a 12-column wipe runs (415160 at x 0x87..0x235 step 0x2b,
  heights from 450ba4) up to 11, then 436fc0 prepares the next stage;
  values 11..20 wipe back.
- HUD (GDI text, blank in the app): "Stage %d-%d" (s/10+1, s%10+1) at
  (0x168,0x6e) c8c8c8, or for s ≥ 50 a survival line blinking via 450ba0;
  players' and enemies' HP sums and counts at x 0x0a (ff7878) and 0x285
  (ff00ff); +0x30c (lives) sign flips by alive state.
- The function continues past the first `ret 8` (4388ac) to 43899d: the
  450ba8 ≥ 3 branch.
- Callees: 415160, 43f010, 401290, 401a30, 4389a0, 417170, 4450d0, 4061d0,
  43ee50, 438ad0, 437400, 431c70, 43d2c0, 436fc0, 431b70, 40c0e0, 40c030,
  4025b0, 402130, 402100, 402020 — most already recovered in Core
  (ADDRESS_BOOK); 437400, 4389a0, 438ad0 are new.

## Helpers (static)

- **437400(slot, index)**, ret 8: first seat 20..399 neither active nor in
  4514e0, else slot[index] = −1. HP = slot +0xb4, scaled by a double for
  difficulty −1 or 2 (not for id 300). Id 1000: next of a 10-entry table at
  44d324 (index 44d34c; at 10 or −1 fifty RNG swaps, tags 0x10f/0x110);
  id 3000: 30 + RNG(2, 0x111); id 3001: RNG(7, 0x112) = 0 → id 32 with 4×HP,
  else 30 + RNG(2, 0x113). The catalog Object with that id (none → −1) is
  bound to the seat after 4061d0; z = arena zTop + RNG(zBottom − zTop,
  0x114); x = slot +0xb0 + RNG(300, 0x115), or (x = −1000) RNG(2, 0x116):
  bound + 150 + RNG(300, 0x117) or −150 − RNG(300, 0x118); lives/+0x314/
  +0x310 from +0xbc/+0xc0/+0xc4; HP/max/+0x304 = HP, MP 500, +0x354 = seat;
  type ∉ {0,5}: state 0, team 0, y −300; else state 20, facing by bound,
  frame +0xc8, team 5, y +0xcc; id 0x7a: HP 200; slot +0 += 1.
- **436fc0** (next stage, ret): stage += 1; 450b9c = 0x46; 450ba8, 450bac,
  450bc8, 450bc4 = 0; 44fb6c, 44f880 = −1; each active type-0 Actor: x =
  50 + RNG(30, 0x10d), max HP += (difficulty+2)·50 capped at +0x304, HP =
  max, MP 500, frame adjustments (to be read).
- The 450ba8 ≥ 3 tail (to 43899d): the set wipe to 20, then the next set
  (stage = (s/10+1)·10, 450b98 = 1, 450bdc = 350) or, after set 4, the
  ending menu 300.

**Oracle boundaries:** 43f010, 415160, 401290 (+ sprintf format), 401a30,
402020, 402100 and 4061d0's allocations are already accepted elsewhere; the
harness records their calls (arguments, return, stack cleanup) instead of
executing device code, and Native must produce the same call sequence.

## Steps

1. Finish the static decode (437860 tail 438311..4388ac, 437400, 4389a0,
   438ad0); list every global/World/Actor/catalog word read and written.
2. Oracle (Unicorn, `InitialLoading` parent as for the character AI):
   families from the real catalog's stage records — phase starts, spawns,
   enemy counts, clears, banner timer values, stage end, survival, player
   ids 0x33/0x34, difficulties — calling 437860 on its own; two corpora
   (legacy/SSE2 conversion).
3. Port `OriginalMissionStage` to Core; accept the corpora byte for byte.
4. Compose it at `OriginalPostDrawImpulses` for mode 1 with the gameplay
   body's providers (text, bitmaps, sound, music, object creation).
5. App: Mission Mode stage 1 in the release app to its first new boundary
   or its end; captures and events.

EXE envelope not recalculated.

## Amendments during the round

- Written global and stage bytes are tracked (strict masks); stimuli write the
  catalog through the tracked host path. The first value-only corpus lacked
  both and served only as early feedback.
- Coverage families added after the first corpus: player frames 16..18,
  owners and +0x98 for the next-stage cleanup, a missing slot id, x = −1000,
  goto phases, a phase music path, equal phase bounds, banner timers 102/202,
  the set wipe at 20, survival stages 50–59 and a declared synthetic survival
  stage (its phase-1 bound defined after the strict check found it read).
- The app run reached lib.dll's Actor+0x7b4 transform write; its declared
  runtime-heap destination is part of this card (see the result).
