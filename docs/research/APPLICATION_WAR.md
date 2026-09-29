# War mode in the app

2026-09-29. [Plan](APPLICATION_WAR_PLAN.md). Parent: [Mission](APPLICATION_MISSION.md)
(efcdedc). Author implementation and machine checks; independent review open.
The original was executed only in Unicorn oracles.

## W1 — character screen, mode 4

`OriginalMatchSelection.continueSelection` and `OriginalComputerSelection` now
accept mode 4 with the rules read from the character screen inside 41bc90:

- the last computer's excluded team is computed in modes 0 **and 4** (42c3ef);
- every team frame keeps a computer off the excluded team and, in War, on
  teams 1..2 (42c511: +1 mod 5 until allowed);
- Left repeats −1 (wrap to 4) over the same rule (42c8c4..42c911); Right has
  no War filter in its frame (a computer on team 2 moves to 3, corrected to 1
  on the next frame);
- mode 4 leaves before the settings screen (42cb8c → 42e0b6); the next call
  moves the menu to 200 (War setup).

Mode 2/3 differences (42c066, 42c3b3, 42c91b: Tournament forces team 0 and
confirms) remain explicit boundaries.

**Oracle:** `tools/oracle_war_selection.py` reuses the accepted retained
selection harness from the fresh `initialize-mode-4` parent: two humans with
War team edges (Left over 0/4/3, Right over 3/4/0), ready and countdown, the
count popup with wraps, three computers (characters, Random, cancel/back, team
edges including Right to 3 and the next-frame correction), the last computer's
exclusion (control: all others on team 2, so it is held on team 1), the random
fill 0xd9 and the call that sets 4512c8 = 3. 226 calls (main 116, control 110),
35229 events, 51 s. [Evidence](../evidence/application-war-selection.json).

**Comparison:** `OriginalLibSelectionStageTests.testWarComputerSelectionWithLibraryText`
runs all 226 calls through `OriginalCharacterMenuContinuation` and matches
every event, checkpoint, caller local, globals, World, 400 Actors and retained
allocation (497.5 s from the installed fixture). The only projection added:
the original keeps its World cursor local (World+0x1b4) through 42e0b6/42e0d2
in War because the settings block that clears it is skipped; the test maps it
to the semantic offset as it already did at 42cb86. The VS corpus (252 calls)
still passes (579.0 s).

## W2 — War setup and War start in the app

The loaded menu session connects the recovered War setup (menus 200..219,
`OriginalWarSetup.advanceWithSurfaceLoading`) and War start 43a21f..43a769
(`OriginalWarPreparation.prepare`) to the app:

- War bitmaps: `BATTLEMODE`/`BATTLETROOPS` are packaged from the EXE's
  RT_BITMAP resources by `tools/package_war_menu.py` (method checked against
  the bundled CHARMENU) into `Resources/OriginalWarMenu` and loaded with the
  menu DIBs (`OriginalApplicationMenuInputs.bundledWithWar`); the .app copies
  them (`package_assets.py`).
- War memory (`OriginalWarMenuMemory`) is retained in the menu state; new War
  wrappers are adopted as owned allocations with their live surfaces; War
  draws use the War memory's bitmaps (BATTLEMODE geometry is rewritten by
  the setup).
- War start runs inside the menu call with the session's owners: arena layer
  construction/release (staged and applied after the preparation, which owns
  the presentation memory during its call), music resume, GetLocalTime and the
  recording calloc (new `localTime`/`allocateReplay` providers); the arena
  images join the loaded menu's bitmap inputs; the recording pointer 4588a8 is
  written back into the full state.

**App (release, virtual clock):** main menu → War → one human (Naruto) →
one computer (the last computer is held on team 2) → War setup
([capture](../evidence/application-war-setup-capture.png)) → Attack → settings
with Fight! selected ([capture](../evidence/application-war-settings-capture.png))
→ Fight!: War start completes and the first gameplay body stops at the War
post-draw child: "Post-draw: original mode4 child is not recovered" (W3).
GDI text (names, counts) is still not rasterized (open font decision).
`tools/app_e2e.py` (VS, Mission, Quit) still passes.

## W3 — War battle logic 43a860

`OriginalWarBattle.apply(state:observe:)` (NTSDCore) ports 43a860(World;
unused), called by the post-draw 41f4ce when mode 451160 is 4:

- counts live troops (seats ≥ 20, side 344 = 1/2, unit IDs 30..39 except 38,
  122, 123) per side and unit type into the 2×11 caller array, and living
  characters (type 0, HP > 0) with their HP per team 364;
- for each side (s = 0, then s = count) and unit type with a reserve (44d6a8)
  and fewer alive than the on-screen limit (44d700): the first free seat
  20..399, the first Object with the unit ID, the Actor constructor 4061d0,
  position (x −100/50 on side 1, arena width +100/−50 on side 2, z from RNG
  417170 tag 0x128 over the arena's z range), HP by unit ID (36: 250; 37/35/32:
  200; 39/33: 150; 34: 100; 31/30: 50; 122: 200; else 500; side-1 characters
  also 318 = 140, 114 for unit 37), side/team, and one reserve taken;
- sums the reserves of the first count−2 unit types per side and sets the
  battle-over flag 451b7c unless both sides have reserves or both have living
  characters;
- reports the two status lines ("Man: %3d     HP: %4d     Reserve: %3d     Die: %3d",
  VC80 sprintf into its stack, 401290 at (10,110) and (450,110)) and builds the
  preset/strength/defense labels in 451c80 (451bb8 for "Defense: %d.%d") for
  the bitmap font 423a70 (style 1 at x 10, style 2 right-aligned at 0x311).

A unit count of 0 does not terminate in the original (the side loop never
advances); the port refuses it, as it refuses counts beyond the 2×11 caller
array.

**Oracle** `tools/oracle_war_battle.py`: 43a860 called directly after the
verified first loading (main CW027f; control CW037f over the control loading)
with families spawn 500, count 250 (unit counts −1..11), kinds 250 (other
Objects' IDs, including type 1..6 and absent IDs), full 60 (no free seat), over
150, labels 200 (display −2..7, strengths −1..3, multipliers incl. 0, −150,
1234). Callees 401290/423a70 are recorded boundaries; sprintf runs the pinned
VC80 DLL (two new whitelisted formats); RNG, constructor and cookie check
execute. Coverage: 171 of 173 static leaders; the two others are alignment
padding (43a90d, 43aa09).

**Comparison** (`NTSDCatalogCheck --war-battle`, `OriginalWarBattleTests`):
both corpora of 1410 real calls match on the first comparison with exact bytes
and initialization masks on globals, World and all 400 Actors: main 10885 RNG
draws/constructors and 10766 callee calls, control 10995/10765; 566820
records, 663478320 bytes/masks each. Stack text pointers are not compared;
the text bytes are.

## W4 — War in the app

The gameplay body composes 43a860 at the post-draw mode-4 child: status lines
through the surface-text renderer, labels through `OriginalBitmapFont` from
their bytes (a label never exceeds one 64-column line, so the font's
terminator store is the existing NUL).

**Blt rule (Mac display backend).** The first War battle stopped on a troop
sprite frame whose source rectangle lies outside its 800×484 sheet
([560,538)–(639,559)). DirectDraw's Blt/fill rejects such a rectangle with
DDERR_INVALIDRECT and changes no pixels; the backend now answers blits and
fills with an empty or out-of-surface rectangle that way (presentation to the
primary is unchanged), extending the existing zero-area policy. Core records
declared success for gameplay draws and the recovered callers ignore the
result; the runtime counts these as `rejectedDraws`.

**App:** main menu → War → Naruto + one computer → War setup → Fight!: the
troops fight ([capture](../evidence/application-war-battle-capture.png)),
the battle ends with the Summary ([capture](../evidence/application-war-summary-capture.png)),
the War recording `recording\20260101_010000_Battle.lfr` (10180 bytes) is
saved, and Jump returns to the War settings. `tools/app_e2e.py` gains a `war`
scenario (reference recorded and reproduced); VS, Mission and Quit still pass.
The status lines stay invisible until GDI text is rasterized (open font
decision).

**Tests:** `OriginalWarBattleTests` 2/2 and `OriginalWorldImpulsesTests` 3/3
(parallel), `OriginalMacFrontRasterTests` 5/5 (the fill-rejection contract is
updated), `tools/app_e2e.py --scenario all` (VS, Mission, War, Quit) pass.

EXE envelope not recalculated.
