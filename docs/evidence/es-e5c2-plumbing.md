# E5c-2 items-family plumbing survey (read only)

Worktree `/Volumes/NTSD-Builds/tasks/engine-split/worktree`, branch `exp/engine-split`,
HEAD ff02e322 with E5c-1d staged (OriginalGameRules has Reflection, Armour,
Interaction, Impact). No files were changed, nothing was built, and no original
content bytes were read. Line numbers refer to this tree. (The E5a survey's numbers
came from 40611c4d; the item rows have not moved.)

## Sites now

| Row | Site | Literal form | Draws around it |
|---|---|---|---|
| A39 | OriginalWorldHits.swift:50 | `if id < 100 \|\| id >= 200 { continue }` | 146 before the loop; 148/150, 149/151, 152, 153 and 154 (count) after it |
| A40 | OriginalWorldHits.swift:51–53 | `[122,123].contains(id)` → `draw(147,2)` → `include == 0 \|\| [1,2,3,4].contains(mode)` | 147 for each drink that passes A39, drawn even in modes 1–4 (mode is read once at :46) |
| A41 | OriginalWorldHits.swift:95 | `h(index(slot),0x6f4) == 122` → `0x2fc = 200` | none after it |
| A42 | OriginalWorldCamera.swift:78 | `(id == 122 \|\| id == 123) && (team>0 \|\| mode 1 && stage/10==5)` | none |
| A43 | OriginalWorldLinks.swift:101 | `h(a,0x6f4) == 122 && i(a,0x2fc) > 0` | 136 (exhausted) after it, :112 |
| A44 | OriginalWorldLinks.swift:114 | `h(a,0x6f4) == 123 && …` (re-reads the header after the 122 block) | 137 after it, :118 |
| A48 | OriginalPostDrawCommands.swift:131 | `if id < 100 \|\| id >= 200 { continue }` (not taken on the library branch, :122–129) | 209–212 for each candidate after the loop |
| A49 | OriginalPostDrawCommands.swift:132 | `id == 122 && draw(208,2) == 0` (short-circuit: 208 is drawn only for 122) | 208 |
| A50 | OriginalPostDrawCommands.swift:157 | `h(index(slot),0x6f4) == 122` → 200 | none after it |
| A64 | OriginalMissionStage.swift:475 | `objects[ordinal].header…(0x6f4) == 0x7a` → 200 | 0x10f–0x118 before it, none after |

## 1. Entry, shape, and where `rules` comes from

All four entry points already take a local `let catalog = state.catalog` (a struct copy) before any `inout` access. Reading `catalog.rules` from that local adds no access to `state`, so there is no overlap and no new `swift_beginAccess`.

- **OriginalPostDrawCommands** is an enum of static functions with a private struct `Body` (:90).
  - Public `apply(state:retainedSpawnSlot:)` :12 → `apply(state:requestSlot:)` :20 → private `run` :33, which takes `let catalog` at :36.
  - Package `applyInPlace` :28 → `run`.
  - Internal explicit-provider `apply(world:…retainedSpawnSlot:…)` :51 → `apply(world:…requestSlot:…inPlace:)` :61, which calls itself on copies at :69. It builds `Body` at :80, and `Body.run`/`spawn` are mutating.
  - Change: add `let rules` to `Body`, add a required `rules:` to both internal overloads, and pass `rules: catalog.rules` at :40.
- **OriginalWorldCamera** is an enum.
  - Public `apply(state:)` :4 → package `applyInPlace(state:)` :18, which takes `let catalog = next.catalog` at :25.
  - That calls the internal static `bounds(world:actors:globals:mode:…header:frame:background:)` :44, which uses local nested functions (no struct pass).
  - Change: add a required `rules:` parameter to `bounds` and pass it at :27.
- **OriginalWorldLinks** is an enum.
  - Public `apply(state:)` :8 and package `applyInPlace` :16 → private `run` :21, which takes `let catalog` at :23.
  - That calls the internal static `apply(world:actors:globals:…inPlace:)` :39, which calls itself on copies at :47. It uses nested functions and takes the actors and globals out with `inPlaceTake` :52.
  - Change: add a required `rules:` parameter at :39, pass it through at :47, and pass `catalog.rules` at :25.
- **OriginalMissionStage** is an enum with a single public `apply(state:target:sse2:observe:)` :25, which takes `let catalog` at :27.
  - It builds the internal struct `OriginalMissionStagePass` at :30 with the memberwise init (this is the only construction). The pass holds `objects: catalog.objects` and not the catalog.
  - `run` → `spawn(_:_:_:)` :411 (mutating).
  - Change: add `let rules` to the pass and pass `rules: catalog.rules` at :30–32.
- **OriginalWorldHits (A39–A41)** lives in `extension OriginalHitPass { mutating func advance }`. The pass already stores `let rules` (OriginalActorHits.swift:69) from both `makePass` overloads (:30, :51). Only the site edits are needed.
  - Note that `OriginalLibWorldHits.applyInPlace` (OriginalLibActorHits.swift:64–70) reaches the same `advance`, so the bundled-library runtime path is covered by the same edit.

## 2. Callers

Public, package and runtime entry points (none need changes; they take the catalog from `state`):

- OriginalGameplayBody.swift:
  - links :108
  - hits :119, and lib hits :116
  - cpoints :122, which calls links a second time at OriginalWorldCPoints.swift:49
  - camera :134
  - mission :148 (inside the `mission` closure; OriginalPostDrawImpulses calls it in mode 1)
  - post-draw commands :233
- NTSDReferenceChecks (all public `apply(state:)`):
  - GameplayCommandsReference:35
  - MatchPreparationReference:263
  - GameplayCameraReference:58, :67
  - MatchLaunchReference:535 (links), :576, :587, :600 (hits)
  - MissionStageReference:121 (OriginalMissionStageTests reaches the pass through this)

Explicit-provider calls that need `rules:` (all in tests):

| Entry | Call sites | Count |
|---|---|---|
| PostDraw `apply(world:)` | OriginalPostDrawCommandsTests :105, :157, :172, :183, :198, :219 | 6 |
| | OriginalLibStageCommandsTests :108, :160, :175, :186, :206, :225, :248, :262 | 8 |
| | engine/Tests/NTSDEngineTests/OriginalRequestSlotWordTests:156 | 1 |
| Camera `bounds` | OriginalWorldCameraTests:113 | 1 |
| Links `apply(world:)` | OriginalWorldLinksTests :87, :113, :121 | 3 |
| | OriginalWorldCPointsTests:114 | 1 |
| Mission | (none) | 0 |
| **Total** | | **20** |

- The five native test files need `import NTSDProfile`. The tests currently import only NTSDCore and NTSDReferenceChecks.
- **Engine test issue.** `OriginalRequestSlotWordTests` (`pool(id: 100)`, requested items) depends on A48's range including 100. NTSDEngineTests cannot import NTSDProfile, so it needs its own `OriginalGameRules` value. This would be the first one in engine tests, built with every family (empty sets or `.max`) and the item range 100..<200.
- Engine edits:
  - PostDraw: :40, :51/:57, :61/:69, :80 and `Body`.
  - Camera: :27 and :44.
  - Links: :25, :39 and :47.
  - Mission: :30 and the pass declaration.
- No public or package signature changes.
- `tools/` has no copies of these files.
- A new `items` family adds `items:` to the 7 `OriginalGameRules(` constructions: NTSDProfile.swift:7, NTSDProfileReflectionTests:11 and :15, Interaction:13, Armour:14, Impact:16 and :44. Roles added to the family later only change `Items.init` calls.

## 3. Hot path

- **Camera:** once per tick. The ID test runs once per active actor whose type is not 0 or 3, and `rules` is a guaranteed parameter (no retain).
- **Links:** twice per tick (the first pass and cpoints' second 417f80). The ID test runs only for held items whose holder is in state 17.
- **Post-draw commands:** `Body` is built once per tick, so one retain. `spawn` runs only when `0x450bb8 == 1` (requested items).
- **Mission stage:** once per mode-1 tick. The pass already copies world, actors, globals and stages, so one more retain is noise. A64 runs once per stage spawn.
- **Hits:** no change. The candidate loop (137 objects) runs only when the 1-in-200 drop roll succeeds.
- Since E5c-1a every copy is one reference. No phone-measurable cost is expected, but the rule-5 A/B still applies to the hot passes (camera, links, hits).

## 4. A64

- `objects` is `catalog.objects`, copied into `OriginalMissionStagePass.objects` at :31 from `let catalog = state.catalog` :27. The pass does not have the catalog or its rules today.
- The site reads `objects[ordinal].header` directly, not through a closure.
- Fix: add `let rules` (filled from `catalog.rules`) and change only `== 0x7a` to `== rules.<hp200 role>`.

## 5. Test reachability

All of these sites are reachable cheaply with synthetic records. Corpus coverage under NTSD's profile already exists for most rows:
- Camera, links and cpoints corpora: ids [2,122,123,10]; 4,742, 3,018 and 2,681 cases.
- Post-draw commands and lib-stage corpora: ids [100,122,123,300]; 3,898 cases.
- Hit corpora: ids [2,7,8,51]; they never produce a candidate.

| Rows | How to reach | What to assert |
|---|---|---|
| A39–A41 | Build `OriginalHitPass` directly (as E5c-1d) and call `advance`. Needs globals 0xb440 with a 3000-byte non-zero RNG table at 0x2f90, with index and counter chosen so draw(146,200) = 0; one actor; a background closure. | Candidates (`+0x368`), the presence of stream-147 events, and `0x2fc == 200`. If a moved range leaves no candidate, `draw(154,0)` throws "Original hit RNG division by zero", which is also observable. |
| A42 | `OriginalWorldCamera.bounds` directly: a type-1 actor with id 122, team > 0, x = 5. | Clamped to 10 under NTSD; left at 5 under a moved profile. No draws. |
| A43/A44 | Links `apply(world:)`: holder in frame state 17, a held item with +0x98 = −1, +0xa0 = owner, holder +0x9c = slot. | Item HP −1 (122) or −2 (123); holder MP +3 (123). Exhaustion adds stream 136/137 (needs the RNG table). |
| A48–A50 | Internal `apply(world:)` with `0x450bb8 = 1` (as OriginalRequestSlotWordTests already does). | `.reconstruct` count, the stream-208 event (122 only), and HP 200. |
| A64 | `@testable` `OriginalMissionStagePass(...)` and `spawn(0, 0x40, 0)`. `OriginalLoadedObject` memberwise init is already used in tests. Needs a small stage record (around 0x110 bytes is enough), an RNG table, and seat 20 free. | HP 200 against the stage HP. |

I did not check whether the mission corpus spawns 122, because that would mean reading the fixtures.

Order must not change:
- A39 before A40.
- The 147 draw before the mode test.
- A49's short-circuit (the draw happens only on an ID match).
- A44's second header read.
- The kind branch before A64.

## 6. Recommendation

**Types and roles.** Add a fifth family, `Items`:

| Role | Type | Rows | NTSD value |
|---|---|---|---|
| `itemRange` | `OriginalIDRange` (public Int32 `lowerBound`/`upperBound`, half-open; `contains` = `!(id < lo \|\| id >= hi)`, exact for every Int32) | A39 and A48 | 100..<200 |
| `scarceDropItems` | `OriginalIDSet` | A40 | {122, 123} |
| `keptOnScreen` | `OriginalIDSet` | A42 | {122, 123} |
| `scarceRequestedItem` | `Int32` | A49 | 122 |
| `fullHPSpawn` | `Int32` | A41, A50 and A64 (the design's "122 → HP 200 ×3") | 122 |
| `hpDrink` | `Int32` | A43 | 122 |
| `mpDrink` | `Int32` | A44 | 123 |

- **`itemRange` type.** `OriginalIDRange` is the form the E5c-0 note left open for A46 and A80. I advise against an `OriginalIDSet` of 100 literals.
- **`itemRange` shared by A39 and A48.** The survey's §(f) lists these two lists as identical. Both test whether an Object is an item for a spawn. The reviewed design's share list leaves out "items ×2", so the card has to record this decision.
  - The fallback is two roles filled from one profile constant, with no runtime difference.
- **A40 and A42 are separate roles.** They have the same list but are different rules (the A19/A23 precedent).
- **A49 is a single-ID equality** and is not the same rule as A40.
- **These stay engine literals:**
  - 200 (as with the E5c-1b thresholds).
  - The mode tests `[1,2,3,4]`, `mode == 1 && stage/10 == 5` and `0x450bb8` (E5c-2's D rows).
  - 136/137/147/208, which are stream labels.

**Increments:**
- **E5c-2a:** the `Items` family with `itemRange`, `scarceDropItems` and `fullHPSpawn`, applied at A39–A41 in the hit pass.
  - No plumbing.
  - 7 construction edits.
  - Synthetic `advance` tests.
- **E5c-2b:** camera and links plumbing (2 engine files; 5 test sites and 3 imports) plus A42–A44 (`keptOnScreen`, `hpDrink`, `mpDrink`).
- **E5c-2c:** post-draw commands and mission-stage plumbing (2 engine files; 15 test sites including the engine test's own rules value, plus 2 imports) plus A48–A50 and A64 (`scarceRequestedItem`; reuses `itemRange` and `fullHPSpawn`).
  - This could be split if the engine-test rules value needs its own review.

**Gates for each increment:**
- The E5 set.
- An unchanged `swift_beginAccess` count.
- The camera, links, cpoints, post-draw, lib-stage, mission and hits corpora.
