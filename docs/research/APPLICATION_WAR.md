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

## W3 — War battle logic 43a860 (in progress)

Static reading: see the plan; port `OriginalWarBattle`, oracle
`tools/oracle_war_battle.py`, reference `WarBattleReference`
(`NTSDCatalogCheck --war-battle`).

EXE envelope not recalculated.
