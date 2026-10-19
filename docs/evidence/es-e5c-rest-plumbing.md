# E5c survey of the remaining role rows (read only)

Worktree `/Volumes/NTSD-Builds/tasks/engine-split/worktree`, branch `exp/engine-split`,
HEAD `2cc8a957` with E5c-2c staged (`OriginalMissionStagePass.rules`, `Items.scarceRequestedItem`).
Surveyed 2026-10-19. No repository file changed, nothing built or run, and no fixture
or content bytes read. Coverage notes come from test code and test metadata only
(`ids`, case counts, family names).

Paths are `engine/Sources/NTSDCore/<file>` unless stated. Line numbers are those of the
staged tree, which matches the working tree for code. One exception: in
`OriginalMissionStage.swift`, HEAD is one line lower from :47 on (the staged
`let rules` sits at :46).

## 0. Decisions needed (recorded here, not decided)

| # | Finding | Recommendation |
|---|---|---|
| F1 | **Five ID literals are missing from the E5a table:**<br>• N1 `OriginalPostDrawSlotPrefix.swift:156` `find(ordinal == 4 ? 218 : 217)` (state-9996 pieces, 41f734)<br>• N2 `OriginalPostDrawLifecycle.swift:249` `find(998)` (the fighter's command 100/102/104 effect, 420c7b)<br>• N3 `:277` `find(999)` (death sparks, frames 120–135)<br>• N4 `:301` `find(999)` (fire, frame 140; 4211f6)<br>• N5 `OriginalMatchSelection.swift:183` `decade < 5` (the stage-set digit or "Survival", a D-like row)<br>A53 `:197` `find(999)` is listed and belongs to the weapon-break hook. | Add N1–N5 to the mapping table as roles (§2).<br>The engine's `OriginalRequestSlotWordTests` builds Objects 999 (:58, :62, :71), 998 (:86) and 217 (:132). Once N1–N4 are roles, `EngineTestRules` must give those roles 217/218/998/999 (synthetic values the tests choose), or those tests change outcome. |
| F2 | The stage half of D14 is still a literal: `OriginalWorldCamera.swift:79` `mode == 1 && g(0x450b94)/10 == 5`. E5c-2b moved only the ID half (A42). | Use the survival role (`bounds` already has `rules`). |
| F3 | **The design says D1–D14 move, "decades" and "menu cycles" included.** But D11's wrap `== 60` is D15's capacity (`OriginalStageLoader.swift:43` `(0..<60)`), which the design keeps as engine layout. D7's next-set formula `(q &* 5 &+ 5) &* 2` and D1/D5/D12/D13's `/10` and `%10` are the same decade arithmetic. | **Option B (recommended):** the decade (10) and the 60-record table stay engine layout with D15. D1, D5, D11, D12, D13 and D7's formula stay engine code. Only the stage predicates and D8's map move (§3).<br>**Option A** (the design as written): `stagesPerSet` 10 and a wrap of 60 as profile numbers. This is exact (Int32 `/` and `%` by a value of 10 equal the literals; precondition ≥ 2). It then contradicts D15 staying in the engine. |
| F4 | **The fusion hook's "five files" (design).** A27 (`OriginalMatchRound.swift:179–222`) has no literal: it restores the IDs saved in +0x330/+0x334, so it is generic. A28 (`OriginalActorInput.swift:137–139`, source 6 → hit_ja 300 while HP > 177 and 0x458428 == 0) is the 6↔50 transformation (with A31/A32), not 7+8 fusion. A29 (`OriginalPostDrawSlotPrefix.swift:210`) and A30 (`OriginalMissionStage.swift:157–158`) test {51, 52} and read no fusion field (+0x328…+0x338). | The fusion hook covers `OriginalWorldFusion.swift` only (A24–A26). A28–A30 become roles. 177, frame 300, combo 8 and 0x458428 stay engine code (the E5c-1b precedent). |
| F5 | The thrown gravities in A35 (0.16999999999999998, 0.425, 1.1333333333333333, default 0.5666666666666667). | Keep the values in engine code and let the profile name the three Objects (the E5c-1b precedent). The E5a recommendation had a profile table instead. Both are exact: `constant(Double)` wraps the same bits. |
| F6 | **Two identical header reads collapse into one:**<br>• A45 `OriginalWorldDrawing.swift:98` `h(0x6f4) != 223 && h(0x6f4) != 224`<br>• A57 `OriginalPostDrawOpoint.swift:192` `source(child) == 5 \|\| source(child) == 52`<br>A set membership test reads once. The header closures are pure (a catalog lookup, no events) and nothing is written in between. So the second read cannot throw after the first succeeds, and it returns the same value. | Accept, and record it in the note and the review table. The alternative is two `Int32` roles per rule, which keeps both reads. |
| F7 | A46 `id < 30 \|\| id >= 50 \|\| id == 38`. The E5c-0 and E5c-2a notes expected the `OriginalIDRange` form. | One finite `OriginalIDSet` of the 19 unlabelled IDs {30–37, 39–49}, with the site testing `!contains`. This is exact and one role. The alternative is range 30..<50 plus `Int32` 38: two roles for one rule. |
| F8 | **Which lists are shared:**<br>• D2/D3/D10/D14: `s/10 == 5`<br>• D4/D6/D9/N5: `s < 50`<br>• A78/A79: `/10 == 5`, identical in the survey but not on the design's share list<br>• A45/A55: {223, 224}, different rules | Share `survivalStages`, `numberedStages` and `bracketFavourites` (one question each, as `itemRange` was in E5c-2a, recorded there). Give A45 and A55 separate roles (the A19/A23 precedent). |
| F9 | Several roles get equal NTSD values: 120 (A33, A35), 101 (A34, A35), 50 (A31, A32), 999 (A36, N3, N4), 998 (A38, N2). | One role per mechanism, as the design requires. |
| F10 | **Public signatures change, unlike E5c-1/2:**<br>• `OriginalActorPhysics.apply(object:)` :8<br>• `OriginalActorScheduler.apply(object:)` :11<br>• `OriginalMatchPrelude.apply` :28, :36<br>• `OriginalModeLabel.draw` :4, `drawInPlace` :19<br>• `OriginalGameplayOutput` :8, :41, :59 (public) and :26 (package)<br>• A28's chain: `OriginalActorInput` :7, `OriginalActorControl` :12, `OriginalLibActorControl` :5 | Required `rules:` with no default (none of them is a runtime path without a catalog). List each in the public-surface review. |
| F11 | Each new family touches all 11 `OriginalGameRules(` constructions:<br>• `native/Sources/NTSDProfile/NTSDProfile.swift:7`<br>• `NTSDProfileReflectionTests` :11, :15<br>• `NTSDProfileInteractionTests` :13<br>• `NTSDProfileArmourTests` :14<br>• `NTSDProfileImpactTests` :16, :44<br>• `NTSDProfileItemsTests` :14, :78, :168<br>• `engine/Tests/NTSDEngineTests/EngineTestRules.swift:9` | Optional, test-only: one helper in `NTSDCoreTests` that copies `NTSDProfile.rules` and replaces one family. Each new family would then cost three edits. |

## 1. Rows, sites and how `rules` reaches them

### Rows that already reach `rules`

The menu functions copy the state (`var candidate = state`; `OriginalMatchPreparation.catalog` is a `let`, `OriginalMatchPreparation.swift:49`) or are methods on it.

| Row | Site | Literal at HEAD (staged) | Function | `rules` from |
|---|---|---|---|---|
| A30 | OriginalMissionStage.swift:157–158 | `if id == 0x33 { weight &+= 1 }; if id == 0x34 { weight &+= 2 }` | `OriginalMissionStagePass.run` | `self.rules` (:46, set at :31) |
| D1–D7 | OriginalMissionStage.swift:142, 162, 179, 270–271, 303, 368, 403–408 | §3 | `run`, `hud`, `setTail` | `self.rules` |
| D14 | OriginalWorldCamera.swift:79 | `g(0x450b94)/10 == 5` | `bounds` (:44) | the `rules:` parameter (E5c-2b) |
| A32 | OriginalMatchRound.swift:175–176 | `sourceID(roundObject(actor)) == 50 && global(0x458428) == 0` … `firstObject(6)` | `restoreRoundActors` (:158, mutating) | `catalog.rules` (self) |
| D13 | OriginalMatchRound.swift:148 | `(stageIndex/10) &* 10` | `runMatchRound` (:81) | `catalog.rules` (only under Option A) |
| A70 | OriginalCharacterScreen.swift:129–130 | `group = id/10; (group != 3 && group != 5) \|\| word(0x458428) == 1` | `advanceCommon` → `eligible` (:125) | `candidate.catalog.rules` (:62) |
| A71 | OriginalComputerSelection.swift:90–91 | `(group == 3 \|\| group == 5) && word(0x458428) != 1` | `advance` → `roster` | `candidate` (:9) |
| A72 / A73 | OriginalTournamentSetup.swift:76–77 / OriginalTeamTournamentSetup.swift:76–77 | as A70 | `advance` → `roster` | `candidate` (:11 in both) |
| A74 | OriginalMatchContinuation.swift:35 | `object.integer(at: 0x6f4) < 30` | `randomRosterCandidates` (:30)<br>Callers: ComputerSelection:102, MatchContinuation:102, :195, MatchSelection:137 | `catalog.rules` (self) |
| A75 / A76 | OriginalTournamentSetup.swift:93 / OriginalTeamTournamentSetup.swift:93 | `type == 0 && id < 30` | `randomize` | `candidate` |
| A77 | OriginalWarSetup.swift:277 | `type == 0 && id < 30` | `advance` | `candidate` (:34) |
| A78 | OriginalTournamentBracket.swift:103–108 | `a,b = id/10`; `a==5 && b != 5` / `b==5 && a != 5` / draw(`a==5 ? 0xfb : 0xfa`) | `advance` | `candidate` (:15) |
| A79 | OriginalTeamTournamentBracket.swift:103 | `members.map { id/10 == 5 }` | `advance` | `candidate` (:15) |
| D11 | OriginalMatchContinuation.swift:178–179 | `s &+ 10; == 60 ? 0` | `consumeContinuation` (:51) | self (only under Option A) |
| D12 / N5 | OriginalMatchSelection.swift:177–178 / :183 | `stage/10; stage%10 != 0 → decade &* 10` / `decade < 5 ? digit : "Survival"` | `continueSelection` (:48) | `candidate` (:55) |

### Rows whose plumbing is a pass struct field (no test calls change)

| Row | Site | Literal | Pass | Edit |
|---|---|---|---|---|
| A58 | OriginalObjectInput.swift:140 | `find(0xe1)` | `OriginalObjectInputPass.burst`; the struct is at :42 | `let rules` plus `catalog.rules` in its one construction (:32–34, `catalog` local at :28). The only callers are the public `apply`/`applyInPlace` (ObjectInputReference, `OriginalMacRuntimeLoading.swift:367`). |
| A59 | OriginalObjectInput.swift:158 | `find(0xdb)` | `escort` | same |
| A65 | OriginalWarBattle.swift:105–106 | `(UInt32(bitPattern: id &- 30) <= 9 && id != 38) \|\| id == 122 \|\| id == 123` | `OriginalWarBattlePass.run` (:97) | `let rules` plus construction :32. The only caller is `apply(state:)`. |

### Rows that need a `rules:` parameter on a chain

| Row | Site | Literal | Chain (`rules` source → site) |
|---|---|---|---|
| A33 | OriginalActorPhysics.swift:74 | `type == 4 \|\| id == 120` | `OriginalWorldPhysics.run` :27 `catalog` → internal `apply(world:)` :37 (copying call :45) → `OriginalActorPhysics.apply(header:)` call :77 → internal :15 (Body :22, :28) → `Body.run` :66 → site |
| A34 | OriginalActorPhysics.swift:75 | `id == 101` | same |
| A35 | OriginalActorPhysics.swift:91 | `id == 124 ? 0.16999999999999998 : id == 120 ? 0.425 : id == 101 ? 1.1333333333333333 : 0.5666666666666667` | same (state 1002) |
| A36 | OriginalActorPhysics.swift:162 | `id == 999 && y > -epsilon` | `run` → `objectLanding` (:98, :159) |
| A37 | OriginalWorldPhysics.swift:89 | `(30...36).contains(header(object(a)).integer(at: 0x6f4))` → +0x318 = 140 (picture offset) | the internal `apply(world:)` loop |
| A38 | OriginalWorldPhysics.swift:92 | `find(998)` (after the free-slot scan) | same |
| A45 | OriginalWorldDrawing.swift:98 | `… && h(0x6f4) != 223 && h(0x6f4) != 224 && …` | `applyInPlace` :26 `catalog` → `draw(world:)` :41 |
| A46 | OriginalWorldDrawing.swift:132–133 | `id < 30 \|\| id >= 50 \|\| id == 38` → "Com" with font 0x44fd80 | same |
| A29 | OriginalPostDrawSlotPrefix.swift:209–210 | `source == 51 \|\| source == 52 { hp /= 2 }` | `OriginalPostDrawLifecycle.run` :65 `catalog` → internal `apply(world:)` :83 (copying call :93, Body :114, :128) → `Body.run` → the slot prefix call :332 → `OriginalPostDrawSlotPrefix.apply(world:)` overloads :59 → :70 → :82 (copying call :92, Body :102, :115) → `run` :214 → `resources` (:194). The public entries :15 and :37 pass `catalog.rules` (:18, :40). |
| A31 | OriginalPostDrawSlotPrefix.swift:217–218 | `type == 0 && state == 9995` → `find(50)` | same → `run` |
| N1 | OriginalPostDrawSlotPrefix.swift:156 | `find(ordinal == 4 ? 218 : 217)` | same → `particles` (:153) |
| A47 | OriginalActorScheduler.swift:147–149 | `sourceID / 10 == 3 && sourceID != 38` (modes 1/4, special team) | the slot prefix's `run` :245 → `OriginalActorScheduler.apply(header:)` :26 (copying call :34, Body :40) → `run` :84. The public :11 needs `rules:`. |
| A55 | OriginalPostDrawOpoint.swift:160–161 | `childState, childSource` both read; `[3000,1002,3006].contains(childState) && childSource != 223 && childSource != 224` | Lifecycle `Body.run` :337 → `OriginalPostDrawOpoint.apply(world:)` :40 (via :30 → :35, copying call :50, Body :60) → `run` :101. The public :12 passes `catalog.rules` (:14). |
| A56 | OriginalPostDrawOpoint.swift:164 | `source(child) == 211` (re-read) | same |
| A57 | OriginalPostDrawOpoint.swift:192 | `source(child) == 5 \|\| source(child) == 52` | same |
| N2–N4 | OriginalPostDrawLifecycle.swift:249, 277, 301 | `find(998)`, `find(999)`, `find(999)` | Lifecycle `Body` (`command` :243, `late` :274) |
| A28 | OriginalActorInput.swift:137–139 | `index == 8 && sourceID == 6 && target == 300 && HP > 177 && 0x458428 == 0` | `OriginalWorldControl.run` :21 `catalog` → `apply(world:)` :38 → `OriginalActorControl.apply(header:)` :24 (call at WorldControl :69) → `OriginalActorInput.apply(sourceID:)` :22 (ActorControl :39) → `recognizeCombos` :103. The public `ActorInput` :7, `ActorControl` :12 and `LibActorControl` :5 need `rules:`. |
| D8, D9 | OriginalMatchPrelude.swift:48 and :68–69 | `[0:1,10:2,20:3,30:4,40:5,50:6][stage]`; `group = s/10; group < 5 ? "_Stage_\(group+1)" : "_Survival"` | `apply(globals:…)` :28/:36 takes only globals, so it needs `rules:`. Callers have an `OriginalMatchPreparation`:<br>• `OriginalApplicationMatchLaunchSession.swift:71` (`model.catalog.rules`; `model` is declared at `OriginalApplicationLoadedMenuSession.swift:176`)<br>• `native/Sources/NTSDReferenceChecks/MatchLaunchReference.swift:375` and `MatchPreludeReference.swift:62` (`state.catalog.rules`) |
| D10 | OriginalModeLabel.swift:47 | `staged…(0x450b94)/10 == 5` (mode 1) | The `OriginalModeLabel.draw`/`drawInPlace` :4/:19 and `OriginalGameplayOutput` :8, :26, :41, :59 entry points carry only world, globals and memory, so all need `rules:`. Callers:<br>• `OriginalGameplayBody.swift:261`, `OriginalPausedGameplay.swift:87` (`next.catalog.rules`, read into a local first)<br>• `GameplayReturnReference.swift:84, :93` |

### Rows that need no role

- **A66** (`OriginalWarBattle.swift:108`, :132–136) and **A68** (`OriginalWarSetup.swift:131–137`): every ID comes from the 0x44d350 table in globals, so there is no ID literal. The 2×11 and the 11 units are table layout (`OriginalWarTroops.swift:14` checks `word(0x44d37c)==11`).
- **A69** was removed in E5b. `OriginalWarTroops.swift` (118 lines) has no `fileWords`, `native/Tests/NTSDCoreTests/NTSDInitialRecordData.swift:5–6` records its removal, and see the ledger at `ENGINE_SPLIT.md:772`.
- **A100** (`OriginalActorControl.swift:162–164`, `kind%100 == 1`, `kind == 101`): 101 is the hold-kind code that A17/A18 write. It is an engine state value, not an Object ID.

### Test calls that must pass `rules:` (explicit providers)

Every call below passes NTSD's rules; files that do not yet import `NTSDProfile` need it.

**Physics** (8 calls)
- `OriginalActorPhysicsTests` :97, :102, :104
- `OriginalWorldPhysicsTests` :20, :28, :57, :84, :168

**Drawing** (1 call): `OriginalWorldDrawingTests` :104

**Lifecycle and opoint** (8 native calls, 1 engine call)
- `OriginalPostDrawLifecycleTests` :109, :164, :179, :197, :202
- `OriginalPostDrawOpointTests` :102, :148, :161
- engine `OriginalRequestSlotWordTests` :22

**Slot prefix and scheduler** (11 native calls, 1 engine call)
- `OriginalPostDrawSlotPrefixTests` :106, :139, :169, :183, :188
- `OriginalLibTransformTests` :169
- `OriginalActorSchedulerTests` :85, :121, :143, :173, :199
- engine `OriginalRequestSlotWordTests` :138

**A28** (16 calls)
- `OriginalActorInputTests` :72, :77, :78, :103, :110
- `OriginalActorControlTests` :130, :141, :163, :205
- `OriginalLibActorControlTests` :82, :112
- `OriginalWorldControlTests` :20, :29, :53, :91, :193

**D10** (8 calls)
- `OriginalGameplayOutputTests` :63, :77, :98
- `OriginalModeLabelTests` :60, :83, :99, :126, :128

**No test-call changes:** the menus, mission stage, War battle and object input.

`tools/` holds none of these files. Its frozen `loading_*_candidate` copy of `OriginalApplicationLoadedMenuSession.swift` calls `MatchSelection.advanceWithLibrary`, whose signature does not change.

## 2. Proposed families and roles

Every role below is one rule. Shared roles are marked (F8).

| Family | Role | Type | NTSD value | Rows | Site form |
|---|---|---|---|---|---|
| Physics | `forwardDrift` | Int32 | 120 | A33 | `type == 4 \|\| id == r` |
| | `backwardDrift` | Int32 | 101 | A34 | `id == r` |
| | `lightThrow`, `floatingThrow`, `heavyThrow` | Int32 ×3 | 124, 120, 101 | A35 | same chain order; the gravities stay engine code (F5) |
| | `restingPiece` | Int32 | 999 | A36 | `id == r && y > -epsilon` |
| | `revivalPicture` | OriginalIDRange | 30..<37 | A37 | `r.contains(header…)` |
| | `revivalEffect` | Int32 | 998 | A38 | `find(r)` |
| Drawing | `shadowless` | OriginalIDSet | {223, 224} | A45 | `!r.contains(h(0x6f4))` (F6) |
| | `unlabelledComputers` | OriginalIDSet | {30–37, 39–49} | A46 | `!r.contains(id)` (F7) |
| Effects | `fixedDepthChildren` | OriginalIDSet | {223, 224} | A55 | `!r.contains(childSource)` |
| | `quarterDepthChild` | Int32 | 211 | A56 | `source(child) == r` |
| | `weakChildren` | OriginalIDSet | {5, 52} | A57 | `r.contains(source(child))` (F6) |
| | `pieces`, `lastPiece` | Int32 ×2 | 217, 218 | N1 | `find(ordinal == 4 ? r2 : r1)` |
| | `commandEffect` | Int32 | 998 | N2 | `find(r)` |
| | `deathSparks`, `fireSparks` | Int32 ×2 | 999, 999 | N3, N4 | `find(r)` |
| | `burstChild`, `escortChild` | Int32 ×2 | 225, 219 | A58, A59 | `find(r)` |
| Lifecycle | `halfHPRegen` | OriginalIDSet | {51, 52} | A29 | `r.contains(source)` (one read already) |
| | `state9995Form` | Int32 | 50 | A31 | `find(r)` |
| | `noLyingDelay` | OriginalIDSet | {30–37, 39} | A47 | `r.contains(sourceID)` |
| | `roundRevertFrom`, `roundRevertTo` | Int32 ×2 | 50, 6 | A32 | `== r1 && global(0x458428) == 0`, then `firstObject(r2)` |
| | `guardedTransformer` | Int32 | 6 | A28 (if F4 → roles) | `sourceID == r` |
| Roster | `hiddenRoster` | OriginalIDSet | {30–39, 50–59} | A70–A73 (shared ×4) | `!r.contains(id) \|\| word(0x458428) == 1` and its dual |
| | `randomCandidates` | OriginalIDRange | Int32.min..<30 | A74–A77 (shared ×4) | `r.contains(id)` |
| | `bracketFavourites` | OriginalIDSet | {50–59} | A78, A79 (shared) | `fa = r.contains(idA)` … stream `fa ? 0xfb : 0xfa` |
| Modes | `survivalStages` | OriginalIDRange | 50..<60 | D2, D3, D10, D14 (shared, F8) | `r.contains(s)` |
| | `numberedStages` | OriginalIDRange | Int32.min..<50 | D4 (`!`), D6, D9, N5 (shared) | `r.contains(s)` |
| | `finalStageSet` | OriginalIDRange | 40..<50 | D7 | `r.contains(s)`; the formula `(q &* 5 &+ 5) &* 2` stays |
| | `stageBackgrounds` | `[Int32: Int32]` (or a small engine map type) | [0:1, 10:2, 20:3, 30:4, 40:5, 50:6] | D8 | `r[stage]` |
| | `stageWeightPlus1`, `stageWeightPlus2` | Int32 ×2 | 51, 52 | A30 | two independent ifs, as now |
| | `warTroops` | OriginalIDSet | {30–37, 39, 122, 123} | A65 | `r.contains(id)` |

Every set literal lies in 0..<65536, as `OriginalIDSet`'s precondition requires. The family grouping changes only initializer churn, not behaviour.

**Exactness for every Int32.** Swift's Int32 `/` truncates toward zero. `Int32.min/10` does not trap; only `/ -1` does. So for every x:

| Original test | Exact replacement | Why |
|---|---|---|
| `x/10 == 3` | x ∈ [30, 39] | For x < 0, x/10 ≤ 0. So −39…−30 give −3, not 3. |
| `x/10 == 5` | [50, 59] | same |
| `x/10 == 4` | [40, 49] | same |
| `x/10 >= 5` | x ≥ 50 | x = 49 gives 4 and x = 50 gives 5; negative x gives ≤ 0 |
| `x/10 < 5` | x < 50 | same |
| `UInt32(bitPattern: x &- 30) <= 9` | [30, 39] | x < 30 is negative or wraps near Int32.min, giving ≥ 0x7fffffe2; x ≥ 40 gives ≥ 10 without wrapping |
| `(30...36).contains(x)` | `30 <= x && x < 37` | 37 is representable |
| `x < 30` | `Int32.min <= x && x < 30` | |
| `x < 0x32` | `Int32.min <= x && x < 50` | |

Note: x ≥ 50 cannot be a half-open range, because Int32.max is not representable as an upper bound. So D4 uses `!numberedStages.contains(s)`, which is exact. The set roles are the enumerations of these predicates:
- A70–A73: {30–39} ∪ {50–59}
- A47: {30–39} ∖ {38}
- A46: the complement of {30–37, 39–49}
- A65: {30–39} ∖ {38} ∪ {122, 123}
- A78/A79: {50–59}

`OriginalIDSet.contains` is exact for any Int32 (E5c-0).

## 3. The stage rules D1–D14 (Option B recommended, F3)

| Row | Site | Literal | Option B | Option A |
|---|---|---|---|---|
| D1 | MissionStage:142 | `p == -1, tenths(s).1 == 0` → 0x44d34c = −1 | engine (the set's first stage; the hero-table cursor belongs with A61's E5e hook) | `% stagesPerSet` |
| D2 | :162 | `tenths(s).0 == 5` → 0x450ba0 = 1 | `survivalStages` | survival set number 5 |
| D3 | :179 | same → revive to HP 5 at x 100 (values stay engine) | `survivalStages` | same |
| D4 | :270–271 | `q >= 5` → one bitmap, else digits q/r + 0x1b | `!numberedStages.contains(s)`; the digits stay | — |
| D5 | :303 | `tenths(s).1 == 9 ? true : try nextStage(s) == -1` | engine (keep the short-circuit: `nextStage` throws past the table) | `stagesPerSet − 1` |
| D6 | :368–369 | `s < 0x32` "STAGE q+1-r+1", else "Survival Stage: n" | `numberedStages` | — |
| D7 | :403–408 | `q == 4` → menu 0x12c / 0x15e; else `(q &* 5 &+ 5) &* 2` | `finalStageSet`; the formula stays. Keep the single `g(0x450b94)` read: `let s = try g(…), q = tenths(s).0`. | `(q &+ 1) &* k` (equal mod 2³²) |
| D8 | Prelude:48 | dictionary literal | `stageBackgrounds` (content: background ordinals) | same |
| D9 | Prelude:68–69 | `group < 5 ? "_Stage_\(group+1)" : "_Survival"` | `numberedStages`; the strings stay | — |
| D10 | ModeLabel:47 | `/10 == 5` | `survivalStages` | — |
| D11 | Continuation:178–179 | `+10`, `== 60 → 0` | engine (decade step and D15's capacity) | `stagesPerSet`, `stageCount` |
| D12 | Selection:177–178 | round down to the decade | engine | `k` |
| N5 | Selection:183 | `decade < 5` digit vs "Survival" | `numberedStages` | — |
| D13 | MatchRound:148 | `(s/10) &* 10` | engine | `k` |
| D14 | Camera:79 | `/10 == 5` | `survivalStages` | — |

All label strings stay engine constants (the E5 design's policy for EXE strings until D1/E7). D15 and B1–B11 stay engine layout.

## 4. Coverage

These notes come from test code and metadata, not bytes.

| Rows | Corpora (test : metadata) | Cheap synthetic reach |
|---|---|---|
| A33–A36 | `original-actor-physics-catalog` (+53): 46,089 cases over all 137 ordinals (`OriginalActorPhysicsTests.swift:45`) | internal `apply(actor:header:…frame:rules:)` with a synthetic header (+0x6f4/+0x6f8) and frame state 1002; check +0x58 and +0x48 |
| A37, A38 | `original-world-physics`: ids [30, 31, 998, 999], 515 cases (`OriginalWorldPhysicsTests.swift:134`) | `apply(world:…)` (:84 pattern): state 14, HP ≤ 0, +0x314 > 0 |
| A45, A46 | `original-world-drawing`: ids [2, 122, 123, 10] (:47). A45 is only ever negative and A46 only `< 30`. | `draw(world:)` (:104 pattern): shadow `draw` event, "Com" text events |
| A47 | `original-actor-scheduler`, 6,084 cases; the IDs are not in the metadata | internal `apply(header:…)` (:121 pattern): prior frame state 14, mode 1, team 5 |
| A29, A31, N1 | `original-postdraw-slot-prefix`: ids [2, 50, 217, 218] (:62). Reaches A31 and N1, not A29. | `apply(world:)` (:169–188 pattern) |
| A55–A57 | `original-postdraw-opoint`: ids [2, 211, 223, 224] (:62). Reaches A55 and A56, not A57. | `apply(world:)` (:148 pattern) |
| N2–N4 | `original-postdraw-lifecycle`: ids [100, 999, 998, 50] (:62); engine `OriginalRequestSlotWordTests` | the existing engine pools (`pool(id:)`) |
| A58, A59 | `original-object-input`: hit_Fa keys include 5 and 8, 137 Objects (`OriginalObjectInputTests.swift:15–16`) | `@testable` `OriginalObjectInputPass(…)` with frame hit_Fa 8/5 |
| A28 | `original-actor-input`: a per-case `sourceID` (default 2); whether 6 occurs is not visible | `recognizeCombos` directly (`OriginalActorInputTests.swift:72`) |
| A32, D13 | `original-match-round`: 2,074 cases | `beginMatchRound` on a synthetic state |
| A65 | `original-war-battle`: 1,410 cases, 137 Objects | `@testable` `OriginalWarBattlePass` |
| A70–A79 | All on the loaded 137-Object catalog:<br>• character-screen and menu fixtures<br>• `original-match-continuation`: 222 cases, 1,998 random calls<br>• lib tournament setup 373 / bracket 250<br>• team tournament setup 373 / bracket 377<br>• lib War setup<br>• `OriginalWarSetupNativeTests` reaches War Random "candidates" (:79) | A synthetic catalog (the `OriginalWarSetupNativeTests.catalog()` pattern: data.txt with chosen IDs and `rules:`), then:<br>• `randomRosterCandidates()` (@testable) for A74<br>• `OriginalCharacterScreen.advance` (the `OriginalStageFinaleTests` driving pattern) for A70<br>• the War candidates event for A77 |
| D2–D7, A30 | `original-mission-stage` (+control). Families: start, phase, banner, end, bound, set, pressure, survival, refill (`OriginalMissionStageTests.swift:18`) | Direct `OriginalMissionStagePass` (the `NTSDProfileItemsTests.swift:227` precedent): `hud()` for D6, `setTail(3)` with wipe 20 for D7 |
| D8, D9 | `original-match-prelude` (+ramp): 50 cases | `apply(globals:localTime:rules:)` on 0xc3a8 synthetic globals |
| D10 | `original-mode-label` | `draw(mode: 1, …)` with stage 55: `labelWrite` events |
| D14 | the camera corpus: ids [2, 122, 123, 10] | `bounds` directly (E5c-2b test) |

## 5. Order that must not change

**Physics and drawing**
- ActorPhysics :71: `type` and `id` are read once. A33 tests `type == 4` first. A35's chain order is 124, 120, 101, default.
- WorldPhysics :89 re-reads the Object after the revival writes. A38 scans for a free slot before `find`.
- WorldDrawing :98: A45 stays inside the lazy `&&` chain after the two `f()` state tests. A46 reads the ID only in its `else if`.

**Post-draw**
- Scheduler :148: the ID is read only in the mode 1/4 special branch.
- Slot prefix: `put(0x70, 0)` runs after A31's `find` whether it matched or not. N1's `find` comes after the free-slot guard, and a miss keeps the retained index.
- Opoint: A56 re-reads `source(child)`.
- Lifecycle: N2 evaluates `free()` and `find(998)` together, and the cursor still updates without a free slot. N4 runs a guard, then `find`, then the cursor write in each iteration.

**Gameplay and menus**
- A32: 0x458428 is read only on an ID match.
- A70–A73: 0x458428 is read only for hidden IDs.
- A74: type, then ID, then `selected`. A75–A77: `selected` (the loop's `where`), then type, then ID.
- A78: both IDs are read before any comparison, and the stream label follows the first ID's test.
- A65: the ID is read only for sides 1–2 in seats ≥ 20.
- D5 keeps its short-circuit. D14 reads the stage global only in mode 1 with team ≤ 0.

**Exclusivity.** Copy `rules` into a local before every call that passes `&world`/`&actors`/`&globals` of the same state. That covers the lifecycle :332/:337, slot prefix :245 and gameplay body :261, matching the existing `frames = frame` copies. Pass `rules` as a function parameter into the per-actor and per-slot `Body.run` (ActorPhysics, Scheduler, SlotPrefix, Opoint). A guaranteed parameter needs no retain; a `Body` field would add one per actor per tick. All `rules` reads come from `let` storage, so the `swift_beginAccess` count (3,276) should not change.

## 6. Increments

These follow the card's order: E5c-2's remaining rows first, then the hot passes. Every increment runs the E5 gate set:
- the mlgate set from clean builds
- WASI vs
- every `*Check` built
- the named suites
- `swift_beginAccess` count 3,276
- the engine's tests
- a review agent
- the phone and Mac A/B with rule-5 follow-up (hot passes marked ★)

| ID | Rows / family | Plumbing edits | Test calls changed | Tests to add | Suites in the gate |
|---|---|---|---|---|---|
| **E5c-2d** | A70–A79 / **Roster** (new) | 0 parameters; 10 sites in 9 files (`let rules = candidate.catalog.rules` per function) | 0 + 11 constructions | Synthetic catalog: A74 candidates under NTSD and under a moved range; A70 cursor skip with 0x458428 0/1; A77 War candidates event | CharacterScreen, MatchSelection, MatchContinuation, ComputerSelection paths, Lib(Team)Tournament Setup/Bracket, LibWarSetup, WarSetupNative, StageFinale, LibMenuContinuation |
| E5c-2e | D2, D3, D4, D6, D7, D14, A30, A65, (N5) / **Modes** (new) | 0 (mission, camera, menus) + 1 field (War pass :32, :44) | 0 + 11 | Mission pass `hud`/`setTail`; camera survival; War troop count | MissionStage ×2, WorldCamera, GameplayCamera, StageFinale, WarBattle, MatchSelection |
| E5c-2f | D8, D9 / Modes | 2 public signatures, 3 callers | 0 | Prelude direct (mode 1, stages 10/49/50/55) | MatchPrelude, MatchContinuation, MatchLaunch, ApplicationHostMatchLaunch |
| E5c-2g ★ | D10 / Modes | 6 signatures + 2 internal calls + 4 callers | 8 + 2 imports | Label with stage 55 under NTSD and moved profiles | ModeLabel, GameplayOutput, GameplayReturn, PausedGameplay, ApplicationPausedGameplay, GameplayBody |
| E5c-1e ★ | A33–A38 / **Physics** (new) | ~12 engine edits, incl. the public `ActorPhysics.apply(object:)` | 8 + 2 imports + 11 | Per row: synthetic physics and revival cases | ActorPhysics ×4, WorldPhysics, ApplicationActivePhysics, MatchLaunch, GameplayBody |
| E5c-1f ★ | A45, A46 / **Drawing** (new; F6, F7 first) | 2 | 1 + 1 import + 11 | Shadow present or absent; "Com" label | WorldDrawing, GameplayDrawing, ApplicationActiveGraphics |
| E5c-1g ★ | A55–A57, N2–N4 / **Effects** (new; F1 first) | ~14 (lifecycle `Body` field, opoint ×3 entries) | 8 + 1 engine + 2 imports + 11; `EngineTestRules` values 998/999 | Opoint child vz and HP; lifecycle finds under moved IDs | PostDrawLifecycle, PostDrawOpoint, GameplayLifecycle, ApplicationActiveLifecycle, engine RequestSlotWord |
| E5c-1h ★ | A29, A31, A47, A32, N1 / **Lifecycle** (new) + Effects | ~16 (slot prefix ×5 entries, scheduler ×2 incl. public :11) | 11 + 1 engine + 3 imports + 11 | Regeneration; 9995; lying delay; round revert | PostDrawSlotPrefix, ActorScheduler, LibTransform, MatchRound, GameplayLifecycle |
| E5c-1i ★ | A58, A59 / Effects | 3 (field, construction, 2 sites) | 0 | `@testable` pass with hit_Fa 8/5 | ObjectInput ×2 |
| E5c-1j ★ | A28 / Lifecycle (after F4) | ~14 incl. 3 public signatures | 16 + 4 imports | `recognizeCombos` with 6 and frame 300 | ActorInput, ActorControl(+catalog), LibActorControl, WorldControl |

## 7. Recommendation

**Start with E5c-2d (Roster).** It needs no parameter plumbing: every site already holds the catalog through `candidate` or `self`. It needs no public signature change and is not a hot pass. Its sharing is the design's own (roster ×4, Random ×4); only the bracket pair (A78/A79) needs the recording E5c-2a gave `itemRange`.

`randomCandidates` takes the `OriginalIDRange` form the E5c-2a note reserved for open-ended tests. Synthetic tests are cheap with the `OriginalWarSetupNativeTests` catalog pattern, and the loaded-catalog menu corpora cover it under NTSD's profile.

Settle F1, F3, F4 and F6/F7 before E5c-1f, E5c-1g, E5c-2e and E5c-1j.
