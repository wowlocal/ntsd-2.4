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
