# E5a survey: ID-specific sites in `engine/Sources` (read-only)

Worktree `/Volumes/NTSD-Builds/tasks/engine-split/worktree`, branch `exp/engine-split`,
HEAD `40611c4d`. Surveyed 2026-10-19. No repository file changed, nothing built;
no original content (downloads/, Resources/, Fixtures/, TargetInputs DATs) read.
Paths are `engine/Sources/NTSDCore/<file>` unless stated. Line numbers are at `40611c4d`.

Scope notes:

- The object ID is the header word `+0x6f4` of the Object an Actor points to
  (`Actor+0x368` → catalog ordinal → `header.integer(at: 0x6f4)`); the type is
  `+0x6f8`. Accessors differ by file: `h(a,0x6f4)`, `id(a)`, `source(a)`,
  `sourceID`, `header(n).integer(at:0x6f4…)`. 171 raw `0x6f4/0x6f8` reads in 43
  files (41 Core, 2 Runtime); Runtime's are diagnostics only (no rules).
- `NTSDRuntime`, the host libraries, codecs and shims contain **no ID rules**.
  `OriginalRuntimeSession`/`OriginalMacRuntimeLoading` only report IDs and own
  the `.characterAI`/`.objectInput` dispatch closure (see §E).
- The card's `OriginalProjectile` (and the rest of Practice) is already game-side
  (`native/Sources/NTSDPractice`, E3a) and is out of scope here.
- "EXE" is the address cited in or right above the code (function range or the
  nearest `mark(0x…)`/comment). "Code" = the rule is a branch; "data" = a table.
- "Group" tags repeated ID lists (§F) — candidates for one profile table.
- Several IDs coincide with LF2 2.0a's well-known roster numbering (6 Louis/50
  LouisEX, 7+8→51 Firzen, 122 milk/123 beer, 999 broken weapon…). That is an
  **inference** from numbering only; telling LF2 rules from NTSD edits needs D1.

## Counts

| Category | Count |
| --- | --- |
| (a) object-ID rule sites | **100 rows** (≈125 branch points; A54 alone is 13 branches) in 27 files |
| — of which in the character AI (generic 4094b0 + 403a40 dispatch + routines) | 20 rows (A80–A99) + the 20-routine switch |
| (a′) EXE data tables holding IDs | 3: `OriginalWarTroops.fileWords` (0x44d350…, Swift literal), 0x44d324 hero table (initial.bin), `HitDamage.reflectable` (Swift `Set`); plus the fragment-count dictionary (A52) and gravity literals (A35) |
| (b) object-type rules (`+0x6f8`) | ≈150 lines in 32 files (summary §B) |
| (c) frame/state-number rules | ≈260 lines in 25 gameplay files (count only, §C) |
| (d) stage-ID rules | 15 rows; background-ID rules 11 rows; game-mode checks in gameplay code ≈35 lines (§D) |
| (e) AI dispatch | 1 `switch` over 20 IDs → 20 routines in `OriginalCharacterAISpecial.swift` (§E) |
| (f) lib.dll extension hooks (not IDs, NTSD-bundled DLL) | ≈8 sites (§G) |
| Layout constants that 2.8.3.3 changes (not IDs, for scale) | `400` pool literals: ≈120 lines in 39 files; frame stride/base literals (0x178/0x7a4/0x7ac/0x7d0): 41 |

## (a) Object-ID rule sites

### Hit resolution (42e100 family)

| # | file:line | EXE | IDs | Rule | Form | Group |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | OriginalActorHits.swift:191 | 42e100 (guard test) | attacker 214, 208 | ITR counts as guard-penetrating (besides effect 2x/3x) | code | armour |
| A2 | OriginalActorHits.swift:192 | 42e100 | defender 37 | auto-guard while `+0xb8` ≤ 15 unless penetrating | code | armour |
| A3 | OriginalActorHits.swift:193 | 42e100 | defender 6 | auto-guard while `+0xb8` ≤ 1 and (frame < 20 or state 5/4/7) | code | armour |
| A4 | OriginalActorHits.swift:194 | 42e100 | defender 52; attacker 214/208 | auto-guard ≤ 15 unless attacker 214/208 | code | armour |
| A5 | OriginalActorHits.swift:196 | 42e100 | attacker 124, 220, 221, 222 | defend (state 7) blocks these regardless of facing/dvx | code (array) | — |
| A6 | OriginalHitGuard.swift:10 | 42fdf2..43056e | defender 37, 6 | guard sound 17 instead of 1 | code | armour |
| A7 | OriginalHitDamage.swift:7–12 | 42e87d..42fdf2 | defender 300 | "ID300 whole-function return": no damage; first bdy word > 1000 → team 1, frame −1000, freeze ±3 | code | 300 |
| A8 | OriginalHitDamage.swift:44 | 42e87d.. (state 3000) | attacker 209; defender ∈ reflectable or 209@frame 40 | attacking ball keeps going instead of frame 10 | code + set | reflect |
| A9 | OriginalHitDamage.swift:90 | 42e87d.. | attacker 201 vs type 0 | attacker deactivated (World activity byte 0) | code | arrow |
| A10 | OriginalHitDamage.swift:91 | 42e87d.. | attacker 214 vs type 0 | attacker HP 0 | code | 214 |
| A11 | OriginalHitDamage.swift:121 | 42ef45 area (hitHorizontal) | held attacker 100 vs type 4/6 | vx × 2.5, sound 13, |vx| ≥ 10 | code | — |
| A12 | OriginalHitDamage.swift:135 | 42f70f..42fcaa | 200, 203, 205, 206, 207, 215, 216 | `static let reflectable: Set<Int32>` | **data** | reflect |
| A13 | OriginalHitDamage.swift:138 | 42f70f.. | 209 | `rebindReflection`: rebind to first Object 209, frames ← current | code | reflect |
| A14 | OriginalHitDamage.swift:149 | 42f70f.. | attacker 209 × reflectable | reflect: credit, rebind to attacker's Object, frames 40 | code | reflect |
| A15 | OriginalHitDamage.swift:154 | 42f70f.. | attacker 8 × reflectable | frame 30 + rebind to 209 | code | reflect |
| A16 | OriginalHitDamage.swift:158 | 42f70f.. | held attacker 213 × reflectable | rebind to 209 + owner credit | code | reflect |
| A17 | OriginalHitSpecial.swift:14 | 43056e..43187a (itr kind 7) | defender 120, 124 | holder `+0x98` = 101 | code | held101 |
| A18 | OriginalHitSpecial.swift:32 | 43056e.. (kind 2, type 1) | 120, 124 | holder `+0x98` = 101 | code | held101 |
| A19 | OriginalHitSpecial.swift:104 | 43056e.. (pullingHit) | 201, 202 | type 1/4/6 with these IDs ignore pull | code | arrow |

### Contacts and fusion (419380 / 417400 / 4064d0)

| # | file:line | EXE | IDs | Rule | Form | Group |
| --- | --- | --- | --- | --- | --- | --- |
| A20 | OriginalWorldContacts.swift:177 | 417400 | attacker 200,203,205,206,207,215,216 vs defender 209 | skip ITR unless kind 9 | code (inline array = A12's list) | reflect |
| A21 | OriginalWorldContacts.swift:195 | 417400 | defender 212 (attacker 212 frame%10 5/0) | bypasses the same-team filter | code | 212 |
| A22 | OriginalWorldContacts.swift:213 | 417400 (kind 5) | 212 | same exception for held-owner team test | code | 212 |
| A23 | OriginalWorldContacts.swift:225 | 417400, mode 1 | attacker 201, 202 | count as character for bdy kind ≥ 1000 | code | arrow, (d) |
| A24 | OriginalWorldFusion.swift:10–23 | 4064d0..406a1f | 7, 8 (partner `15 − id`) | fuse when HP < 177 or 0x458428 == 1, distance/state gates | code | fusion |
| A25 | OriginalWorldFusion.swift:26–37 | 4064d0.. | 51 | replacement Object 51, frame 290, timer 4500, ids saved in 0x330/0x334 | code | fusion |
| A26 | OriginalWorldFusion.swift:40–62 | 4064d0.. | 51 | defuse: restore 0x330/0x334 Objects, halve HP, frame 112 | code | fusion |
| A27 | OriginalMatchRound.swift:177–200 | 41ddf2..41e0e1 | (fusion record 0x328/0x330/0x334) | round-restore defuse | code (no literal) | fusion |
| A28 | OriginalActorInput.swift:137–139 | 412fdd..41300f | source 6, combo 8 target frame 300, HP > 177, 0x458428 == 0 | combo suppressed | code | 50/fusion |
| A29 | OriginalPostDrawSlotPrefix.swift:209–210 | 41f550..41fb0b | 51, 52 | MP regeneration uses HP/2 | code | fusion |
| A30 | OriginalMissionStage.swift:156–157 | 437860 | 0x33 (51), 0x34 (52) | stage spawn weight +1 / +2 | code | fusion |

### Transform, physics, World passes

| # | file:line | EXE | IDs | Rule | Form | Group |
| --- | --- | --- | --- | --- | --- | --- |
| A31 | OriginalPostDrawSlotPrefix.swift:217–218 | 41f550..41fb0b | 50 (state 9995) | type 0 becomes first Object 50 | code | 50 |
| A32 | OriginalMatchRound.swift:175–176 | 41ddf2..41e0e1 | 50 → 6 | reverted at round restore unless 0x458428 == 1 | code | 50 |
| A33 | OriginalActorPhysics.swift:74 | 40e490..40ef6a | 120 (or type 4) | x += 0.2·vx | code | held101 |
| A34 | OriginalActorPhysics.swift:75 | 40e490.. | 101 | x −= 0.2·vx | code | — |
| A35 | OriginalActorPhysics.swift:91 | 40e490.. (state 1002) | 124, 120, 101 | thrown gravity 0.16999999999999998 / 0.425 / 1.1333333333333333, else 0.5666666666666667 | code (literal chain) | held101 |
| A36 | OriginalActorPhysics.swift:162 | 40e490.. | 999 | non-weapon landing → frame 101 | code | 998/999 |
| A37 | OriginalWorldPhysics.swift:89 | 41e634..41eed1 | 30…36 | revive: `+0x318` = 140 | code (range) | 30s |
| A38 | OriginalWorldPhysics.swift:92 | 41e634.. (41e929) | 998 | revive spawns first Object 998 | code | 998/999 |
| A39 | OriginalWorldHits.swift:50 | 41eefb..41f2ac (41ef92) | 100…199 | random item candidates | code (range) | items |
| A40 | OriginalWorldHits.swift:51–53 | 41eefb.. | 122, 123 | coin flip (stream 147); excluded in modes 1–4 | code | drinks, (d) |
| A41 | OriginalWorldHits.swift:95 | 41eefb.. | 122 | spawned HP 200 | code | 122hp |
| A42 | OriginalWorldCamera.swift:78 | 41b5d0..41bc87 | 122, 123 | clamp to [10, w−10] if team > 0 or (mode 1 and stage/10 == 5); else despawn off-screen | code | drinks, (d) |
| A43 | OriginalWorldLinks.swift:101–113 | 417f80..4187a3 | 122 | held while holder state 17: HP/MP schedule, exhausted → stream 136 | code | drinks |
| A44 | OriginalWorldLinks.swift:114–119 | 417f80.. | 123 | MP +3 (≤500), clamp 150 for `+0x2f4` owners, stream 137 | code | drinks |
| A45 | OriginalWorldDrawing.swift:98 | 41a5a0..41ae50 | 223, 224 | no shadow | code | noShadow |
| A46 | OriginalWorldDrawing.swift:133 | 41a5a0.. | id < 30, ≥ 50, == 38 | "Com" label for team-5 type-0 in slots ≥ 20 | code (range) | 30s |
| A47 | OriginalActorScheduler.swift:147–149 | 40d960..40de20 | id/10 == 3 && id ≠ 38 | no lying delay (state 15) for special team in modes 1/4 | code | 30s, (d) |
| A48 | OriginalPostDrawCommands.swift:131 | 4214d5..421a15 (421651) | 100…199 | requested-items candidates | code (range) | items |
| A49 | OriginalPostDrawCommands.swift:132 | 4214d5.. | 122 only | coin flip (stream 208) — **not** 123 (cf. A40) | code | drinks |
| A50 | OriginalPostDrawCommands.swift:157 | 4214d5.. | 122 | HP 200 | code | 122hp |
| A51 | OriginalPostDrawCommands.swift:191 | 4214d5.. | ≠ 300 (mode 1, team 5, type 0) | kill command spares 300 | code | 300, (d) |
| A52 | OriginalPostDrawLifecycle.swift:192 | 41f550..4214d5 (break block, 420537) | 101:7, 218:7, 100:5, 213:5, 217:5, 201:3, 150:13, 151:15, 120:3, 124:3, 121:4, 122:9, 123:9 | fragments per broken weapon | **data** (dictionary literal) | break |
| A53 | OriginalPostDrawLifecycle.swift:197 | same | 999 | fragment Object | code | 998/999 |
| A54 | OriginalPostDrawLifecycle.swift:207–237 | same | {150,151,213}, {100,201,101,120,121,122,123,124,217,218}, 150, 100, 213, 101, 151, 120, 124, 121, 122, 123, {217,218} | per-ID fragment vy/frame draws (streams 168–196); each check reloads the parent | code (13 branches) | break |
| A55 | OriginalPostDrawOpoint.swift:161 | 41fb0b..4203b4 | 223, 224 | opoint child (state 3000/1002/3006) takes vz from up/down except these | code | noShadow |
| A56 | OriginalPostDrawOpoint.swift:164 | 41fb0b.. | 211 | child vz × 0.25 | code | 211/212 |
| A57 | OriginalPostDrawOpoint.swift:192 | 41fb0b.. | 5, 52 | opoint child HP/max 10, MP 5 | code | — |
| A58 | OriginalObjectInput.swift:140 | 407232..40768e (hit_Fa 8) | spawns 0xe1 (225) | split into ≥ 3 aimed Objects | code | — |
| A59 | OriginalObjectInput.swift:158 | 407ad5..407d3b (hit_Fa 5) | spawns 0xdb (219) | one per living ally | code | — |
| A100 | OriginalActorControl.swift:163–164 | 413080..4143cb | hold kind 101 (set by A17/A18) | light-weapon variant: frame 45 / stream 0x83 | code (derived) | held101 |

### Modes' gameplay logic (Stage 437860, War 43a860)

| # | file:line | EXE | IDs | Rule | Form | Group |
| --- | --- | --- | --- | --- | --- | --- |
| A60 | OriginalMissionStage.swift:422–423 | 437400 | 0x12c (300) | difficulty HP ×1.5/×0.75 skipped | code | 300 |
| A61 | OriginalMissionStage.swift:424–434 | 437400 | pseudo-ID 0x3e8 (1000) | next of a shuffled 10-entry hero table at 0x44d324 (cursor 0x44d34c; initial.bin data; 50 swaps streams 0x10f/0x110) | code + **data (globals)** | — |
| A62 | OriginalMissionStage.swift:435–436 | 437400 | pseudo-ID 0xbb8 (3000) | id = 30 + rand(2) | code | 30s |
| A63 | OriginalMissionStage.swift:437–439 | 437400 | pseudo-ID 0xbb9 (3001) | 1/7: id 32 with HP × 4, else 30 + rand(2) | code | 30s |
| A64 | OriginalMissionStage.swift:475 | 437400 | 0x7a (122) | HP 200 | code | 122hp |
| A65 | OriginalWarBattle.swift:106 | 43a910 | 30…39 except 38, 122, 123 | counted as War troops | code | war, 30s |
| A66 | OriginalWarBattle.swift:108, 132–136 | 43a910 / 43a9f7 | table 0x44d350 (11 unit IDs) | unit index ↔ Object ID (first match) | **data (globals)** | war |
| A67 | OriginalWarBattle.swift:203–216 | 43abe2..43ac75 | 0x1e…0x27 (30–39), 0x7a | per-unit life 50/100/150/200/250; side-0 `+0x318` 0x8c, 0x72 for 37 | code | war |
| A68 | OriginalWarSetup.swift:133–136 | 438bbb..438d2a | table 0x44d350 | bind units to ordinals (**last** match wins) | data | war |
| A69 | OriginalWarTroops.swift:128–140 | 438b40; data 44d350..44d777 | 30,31,33,34,39,32,35,36,37,122,123 + preset rows | `fileWords`: EXE-copied initialized data in a Swift literal | **data** | war |

### Roster and menus

| # | file:line | EXE | IDs | Rule | Form | Group |
| --- | --- | --- | --- | --- | --- | --- |
| A70 | OriginalCharacterScreen.swift:128–130 | 42b290..42e0d2 | id/10 ∈ {3, 5} | hidden unless 0x458428 == 1 | code | roster |
| A71 | OriginalComputerSelection.swift:89–91 | 42ba84..42cb86 | same | same | code | roster |
| A72 | OriginalTournamentSetup.swift:75–77 | 433xxx (mark 0x433550) | same | same | code | roster |
| A73 | OriginalTeamTournamentSetup.swift:75–77 | 435xxx (mark 0x4356d8) | same | same | code | roster |
| A74 | OriginalMatchContinuation.swift:30–36 | 42b660/42ca80/42d840/42dfd0 | type 0, id < 30, ordinal ≠ 0 | random roster candidates | code | random |
| A75 | OriginalTournamentSetup.swift:91–93 | 433550 | same (ordinals from 1) | Random | code | random |
| A76 | OriginalTeamTournamentSetup.swift:91–93 | 4356d8 | same | same | code | random |
| A77 | OriginalWarSetup.swift:275–277 | 43986a..4399c3 | same | same | code | random |
| A78 | OriginalTournamentBracket.swift:103–108 | 433bc9..433c22 | id/10 == 5 | group 5 beats non-group-5; else draw (streams 0xfa/0xfb) | code | roster |
| A79 | OriginalTeamTournamentBracket.swift:103–107 | 435d59..435dbc | id/10 == 5 | same per team (streams 0x105/0x106) | code | roster |

### Character AI, generic part (4094b0) and dispatch (403a40)

| # | file:line | EXE | IDs | Rule | Form | Group |
| --- | --- | --- | --- | --- | --- | --- |
| A80 | OriginalCharacterAI.swift:166 | 409928..409ff0 | own id < 30 | Stage-mode allies (slot < 20 or id < 30) play at level 0 | code | 30s, (d) |
| A81 | OriginalCharacterAI.swift:254–263 | 40a43b..40a90a | 200 (frame group 6 enemy / 5 own); own 2, 34 | chase/heal-ball decision | code | 200, healers |
| A82 | OriginalCharacterAI.swift:280 | 40a43b.. | 211 (state 18), 212 (frames 150–170) | dodge | code | 211/212 |
| A83 | OriginalCharacterAI.swift:293–295 | 40a43b.. | id/100 == 1 or 213; 122, 123 | item-pickup target filter | code | items, drinks |
| A84 | OriginalCharacterAI.swift:299–307 | 40a43b.. | 200 (group 5) | go to heal ball | code | 200 |
| A85 | OriginalCharacterAI.swift:309 | 40a43b.. | 122 (state 1004) | hurt AI fetches it | code | drinks |
| A86 | OriginalCharacterAI.swift:327 | 40b7b5..40b846 | own 7 (frames 255–261), 9 (280–290), 32 (240–245) | press defend when idle | code | — |
| A87 | OriginalCharacterAI.swift:351 | 40a925..40b7b0 | held 122, 123 | drink | code | drinks |
| A88 | OriginalCharacterAI.swift:368 | 40a925.. | target 200 | walk onto it | code | 200 |
| A89 | OriginalCharacterAI.swift:385, 433 | 40adaa..40b0c7 / 40b0fc..40b78f | own 4, 5, 31 | ranged "band" (keep distance, long strike) — same list twice | code | ranged |
| A90 | OriginalCharacterAI.swift:444 | 40b0fc.. | own 36 | joins the ranged strike | code | ranged |
| A91 | OriginalCharacterAI.swift:493 | 40b987..40bba3 | 122, 123 | approach even when far | code | drinks |
| A92 | OriginalCharacterAI.swift:514–535 | 403a40 | 1,2,4,5,6,7,8,9,10,11,32,33,34,35,36,38,39,50,51,52 | special-move dispatch (§E) | code (switch) | AI |
| A93 | OriginalCharacterAI.swift:553–563 | 408cb0 | held 100,101,120,121,124; 124 extra roll | melee weapon use | code | items |
| A94 | OriginalCharacterAI.swift:564 | 408cb0 | held 150, 151 | throw | code | — |
| A95 | OriginalCharacterAI.swift:568–603 | 408cb0 | held 122, 123; own 2, 34 at :600 | drink/flee path; healers set 0xd8/0xd9 | code | drinks, healers |
| A96 | OriginalCharacterAI.swift:613–621 | 4034f0 | own 2,4,6,9,10,11,8,7,33,34 | defend + dash counters | code (`Set`) | dash |
| A97 | OriginalCharacterAI.swift:622–627 | 4034f0 | own 1 | defend/dash with z 7 | code | — |
| A98 | OriginalCharacterAI.swift:620, 639 | 4034f0 | own 34 (`jumpID`) | dash jumps on a coin flip | code | healers |
| A99 | OriginalCharacterAISpecial.swift:26 | 403a7e..403e83 | target 2, 9, 10, 11, 33, 34 | naruto2's "strong target" ranges | code | — |

Other ordinal/ID-adjacent rules: ordinal 0 never a Random candidate (A74–A77);
`OriginalCatalogRegistry.swift:132` object capacity < 500 and `:150` backgrounds < 99.

## (b) Object-type rules (engine-side, brief)

≈150 lines in 32 files. Heaviest: HitDamage 20, HitSpecial 18, WorldContacts 16,
ActorPhysics 15, MissionStage 9, ActorHits 8, CharacterAI 6. Mechanisms: type 0
gets AI dispatch (`OriginalLocalInput.swift:120`), hit pass 1 (`WorldHits:41`),
guard/damage statistics, depth clamp (`WorldLinks:83`, `WorldCamera:60–73`),
respawn/revive, HUD/label and team counts; types 1/2/4/6 are pick-up-able items
(hold kinds `+0x98`, durability `+0x31c`, item count `WorldHits:38`, landings
`ActorPhysics:161–193`, gravity 1.1333/0.85/1.7); type 3 is the attack/ball
(projectile hit `HitDamage:92`, ±300 despawn `WorldCamera:68–70`, z drift from
frame `+0x2c` `ActorPhysics:78`, catalog hit sound); type 5 spawns like a
character (`WarBattle:222`, `MissionStage:466`). The lib.dll ITR-kind categories
(`WorldContacts:104–111`) also test types. These are generic DAT mechanics and
stay in the engine.

## (c) Frame/state-number rules (count only)

≈260 lines in 25 gameplay files (CharacterAI 46, ActorControl 43,
CharacterAISpecial 31, HitDamage 20, ActorScheduler 19, ActorPhysics 16,
WorldContacts 15, …). Values: states 0–20, 100, 110–112, 180–191, 200–245, 290,
300/301, 400/401 teleport, 500/501 transform, 1000–1004, 1100–1299 (opoint
`/100 == 11/12`), 1700, 2000/2004, 3000–3006, 4000–4999 (lib), 8000–8999,
9995–9998. Generic engine mechanics. Note that the AI routines' frame windows
(e.g. A86, lee7 255–261/267–283, sakura1 260–289) are per-character data, not
generic states.

## (d) Stage, background and mode rules

### Stage ID (global 0x450b94; decade = set, 50 = survival)

| # | file:line | EXE | Rule | Form |
| --- | --- | --- | --- | --- |
| D1 | OriginalMissionStage.swift:141 | 437860 | s%10 == 0 at phase −1 → hero-table cursor 0x44d34c = −1 | code |
| D2 | OriginalMissionStage.swift:161 | 437860 | s/10 == 5 → survival blink flag 0x450ba0 = 1 | code |
| D3 | OriginalMissionStage.swift:178–185 | 437860 | s/10 == 5 → revive dead players to HP 5 at x 100 | code |
| D4 | OriginalMissionStage.swift:269–276 | 437860 | q ≥ 5 one bitmap, else "stage q-r" digits | code |
| D5 | OriginalMissionStage.swift:302 | 438311 | s%10 == 9 ends the set | code |
| D6 | OriginalMissionStage.swift:367–381 | 438614..4388ac | s < 0x32 "STAGE q-r" else "Survival Stage: n" | code |
| D7 | OriginalMissionStage.swift:402–407 | 4388af..43899d | q == 4 → menu 0x12c/0x15e; else next set `(q·5+5)·2` | code |
| D8 | OriginalMatchPrelude.swift:48 | 42cf8a..42d1ff | stage 0,10,20,30,40,50 → background 1…6 | **data** (dictionary literal) |
| D9 | OriginalMatchPrelude.swift:68–69 | 42cf8a.. | replay name `_Stage_n` (group < 5) / `_Survival` | code |
| D10 | OriginalModeLabel.swift:47 | 41b130 | stage/10 == 5 → "Survival Stage" label | code |
| D11 | OriginalMatchContinuation.swift:178–179 | 42d704..42e0d2 | menu cycles stage +10, 60 → 0 | code |
| D12 | OriginalMatchSelection.swift:177–178 | 42cb86 | round stage down to its decade | code |
| D13 | OriginalMatchRound.swift:147–149 | 41dxxx match round | stage index to decade on continue | code |
| D14 | OriginalWorldCamera.swift:78 | 41b5d0 | survival keeps 122/123 on screen (with A42) | code |
| D15 | OriginalStageLoader.swift:43 | stage loader | stage IDs 0…59 (60 records) | capacity |

### Background ID (global 0x44d024; 100 = Random, 99 = built-in slot)

| # | file:line | EXE | Rule | Form |
| --- | --- | --- | --- | --- |
| B1 | OriginalMatchPreparation.swift:172–177 | 42d1ff..42d6ed | Random: draw(count−2); count−3 → 99; 99 accepted | code |
| B2 | OriginalWarPreparation.swift:49–52 | 43a2b6..43a305 | same | code |
| B3 | OriginalTournamentPreparation.swift:72–73 | 43451d | same | code |
| B4 | OriginalTeamTournamentPreparation.swift:53–54 | 436864 | same | code |
| B5 | OriginalMatchContinuation.swift:181–188 | 42d704..42e0d2 | menu cycle 100 → 99 → 0 → … → count → 100 | code |
| B6 | OriginalTournamentSetup.swift:212, 230–235 | 433660 | same cycle | code |
| B7 | OriginalTeamTournamentSetup.swift:228, 246–251 | 4355cb area | same | code |
| B8 | OriginalWarSetup.swift:337, 353, 357–363 | 439xxx | same | code |
| B9 | OriginalMatchSelection.swift:175 | 42cb86 | 0x44d028 → 100 | code |
| B10 | OriginalModeSelection.swift:62–65 | 4328f8 | initial 100 or 0 | code |
| B11 | OriginalCatalogRegistry.swift:150 | 41275c | ≤ 98 registered ("collision with built-in backgrounds") | capacity |

### Game mode (global 0x451160: 0 VS, 1 Stage, 2 1on1, 3 2on2, 4 Battle, 5 Demo, 6 end/playback)

≈35 checks in gameplay code: WorldContacts:224; WorldHits:53; ActorScheduler:147;
PostDrawImpulses:37–38 (mode 1 → MissionStage, 4 → WarBattle); PostDrawCommands:191,195;
WorldCamera:78; CharacterAI:107,113,166,172,190,208,209,389,458; MatchRound:91,99,104,107,125,144,147;
ResultLayout:99,133,145,159; PostHUDNotices:148; InputControl:218,228,240;
WarPreparation:105. They are structural (which modes exist) and stay engine-side
unless a mode check is fused with an ID (A23, A40, A42, A47, A51, A80).

## (e) The AI dispatch

Call graph (one tick):

```
OriginalLocalInput.localInputInPlace (419a60 tail, OriginalLocalInput.swift:113–127)
  for slot 10..<400 active: type 0 → .characterAI(slot, mode); else (frame hit_Fa>0) → .objectInput
  → dispatch closure (supplied by the caller):
     NTSDRuntime OriginalMacRuntimeLoading.swift:362–369  (the app; per tick)
     NTSDReferenceChecks CharacterAIReference / LocalInputReference (checks)
OriginalCharacterAI.applyInPlace (4094b0) → OriginalCharacterAIPass.run
  A scripted run (mode 1, 0x450bac) | B walk to point | setup 409928 → search 409ff4
  → shift → items 40a43b → idle 40b7b5 | fight 40a925:
       tState 3000 / 0x404 / item 40b987 / flee 40b84b / target 200
       → special(s,t,slot,l)  ← 403a40       (OriginalCharacterAI.swift:511–537)
       → approach 40adaa → weapon 408cb0 → tactics 40b0fc → attackHelper 4034f0
```

`special` (403a40): **entry roll first** — `draw(0x3c, g(0x44f618)+1) > 0` → return
false — for every AI, whatever its ID; then `switch own` (own = `+0x6f4` of the
AI's Object) → one routine; `default: return false`. A routine returning true
ends the AI call (`fight` returns); false continues to approach/weapon/tactics.
The EXE is an if-chain laid out as 2,1,4,5,6,7,8,11,10,9,32,33,34,50,35,36,38,39,52,51
(403a7e…40618b, end 4061a0); the comment "false continues the chain, which no
later block matches" is what makes the Swift `switch` equivalent.

| ID | Routine | EXE | Extra inputs |
| --- | --- | --- | --- |
| 1 | sakura1 | 403e83..4041e4 | l |
| 2 | naruto2 | 403a7e..403e83 (+healAlly 403ca1..) | slot, l; target-ID list A99 |
| 4 | sai4 | 4041e4..404361 | — |
| 5 | shino5 | 404361..4044ed | — |
| 6 | hsasori6 | 4044ed..4045fc | (state read) |
| 7 | lee7 | 4045fc..40498d | l |
| 8 | chiyo8 | 40498d..404c05 | l |
| 9 | itachi9 | 40513a..405311 | l |
| 10 | deidara10 | 404dae..40513a | slot, l |
| 11 | sasuke11 | 404c05..404dae | l; frame field +0x2c |
| 32 | hunter32 | 405311..405498 | l |
| 33 | clone33 | 405498..405550 | l |
| 34 | kidomaru34 | 405550..405761 (+healAlly 4055fa..) | slot, l |
| 35 | sakon35 | 405913..40598d | — |
| 36 | tayuya36 | 40598d..405abc | — |
| 38 | sasukeCS38 | 405abc..405c1d | — |
| 39 | sand39 | 405c1d..405d0d | — |
| 50 | pein50 | 405761..405913 | — |
| 51 | sasori51 | 405fc2..40618b | (type(t)) |
| 52 | kyubi52 | 405d0d..405fc2 | l |

Shared by the routines (all `extension OriginalCharacterAIPass`):
- Special-file helpers: `command` (byte 0xd4..0xdc = 3, return true), `aimed`
  (0xd8 right / 0xd9 left), `wounded(margin:)`, `dx`, `dz`, `facingToward`,
  `healAlly` (naruto2 + kidomaru34), `lunge` (sasuke11 + deidara10),
  `dash(reach:mp:)` (sasuke11 + deidara10; distinct from the generic `dash`),
  `frameField` (sasuke11).
- Pass primitives: `draw(stream,range)` (shared game RNG 0x450bcc/0x450c34 +
  `.random` event; streams 0x3d…0x81, one per call site), `i`, `g`, `press`,
  `release`, `byte`, `id`, `type`, `state`, `active`, `index`, `ftol` (x87/SSE2
  ftol), `facing`, `abs`, `error`.
- Reads: Actor `+0x10/0x14/0x18/0x70/0x80/0x98/0x2fc/0x300/0x308/0x364`, frame
  `+8` and `+0x2c`; globals 0x44f604 (arena width), 0x44f608, 0x44f618 (level·5,
  entry roll). `Locals` read-only fields: `nearest38`, `ball30`, `aligned34`, `tState`.
- Writes: Actor button bytes 0xcd–0xd3 (and the released copies), command bytes
  0xd4–0xdc; RNG index/counter; the event list. No World/Object writes.

Boundary a profile needs: a hook at 403a40 *after* the entry roll —
`(inout context, s, t, slot, Locals) throws -> Bool` — with a context that
exposes exactly the primitives above (same RNG object and event list, same
lazy reads that may throw). The generic AI also carries per-character data
(A80–A98: ranged band {4,5,31}+36, healers {2,34}, dash set, defend frame
windows, item lists), which belong to the same profile as tables. The per-tick
dispatch closure (`.characterAI`) already sits in Runtime, so the outer AI need
not move.

## (f) Repeated ID lists — candidates for one profile table

| Group | Members | Sites | Same semantics? |
| --- | --- | --- | --- |
| reflect | 200,203,205,206,207,215,216 (+209 reflector) | A8, A12–A16 (HitDamage), A20 (WorldContacts inline copy) | yes for the list; 209/8/213 are separate roles |
| drinks | 122, 123 | A40, A42, A43, A44, A49, A52/54, A65, A83, A85, A87, A91, A95, (fileWords) | **no**: A49 coin-flips 122 only, A40 both; A43/A44 differ per ID |
| 122hp | 122 → HP 200 | A41, A50, A64, A67 (0x7a life 200) | yes (4 files) |
| items | 100…199 (+213 for AI) | A39, A48, A83, A93 | A39/A48 identical; AI adds 213 |
| held101 | 120, 124 (→ hold kind 101), 101 | A17, A18, A33, A35, A100 | related, not one list (A33 is 120 only) |
| armour | 37, 6, 52; penetrators 214, 208 | A1–A4, A6 | per-ID thresholds differ |
| fusion | 7+8 → 51; 51/52 | A24–A30 | one mechanism across 5 files; 177 and 0x458428 repeat |
| 50 | 9995 → 50; 50 → 6 at round end | A28, A31, A32 | one mechanism |
| 30s | 30…39 ∖ {38}; < 30; 30…36 | A37, A46, A47, A62, A63, A65, A67, A80 | **no**: three different ranges |
| roster | id/10 ∈ {3,5} hidden unless 0x458428 | A70–A73 | identical ×4 |
| random | type 0, id < 30, ordinal ≥ 1 | A74–A77 | identical ×4 |
| group5 | id/10 == 5 wins brackets | A78, A79 | identical ×2 |
| noShadow | 223, 224 | A45, A55 | identical ×2 |
| 998/999 | 998 revive effect, 999 fragment/landing | A36, A38, A53 | separate roles |
| 211/212 | 211, 212 | A21, A22, A56, A82 | different rules |
| war | 0x44d350 unit table | A65–A69 | one table (already data) |
| 300 | 300 | A7, A51, A60 | one role ("criminal"-like exemption) |
| healers / ranged / dash (AI) | {2,34} / {4,5,31}+36 / {2,4,6,9,10,11,8,7,33,34} | A81, A95, A98 / A89, A90 / A96 | each repeats within CharacterAI |

## (g) lib.dll extension hooks (NTSD-bundled DLL; not object IDs)

Gated by `bundledLibrary` / `library != nil`: WorldContacts:104–111 (ITR kinds
8, 36, 80–89, 800–825 by defender type), :200 (state-20 team inversion);
LibActorHits:79 (effect ≥ 6000 → frame), :101–128 (movement kinds 8/80–89/800–825,
target 777); PostDrawSlotPrefix:225 (states 4000–4999 transform); PostDrawCommands:122–129
and MatchPreparation:204–212 (requested Object ID from the background's `+0xc`);
LibActorControl (state 85/86 hook); LibTransformBacking; LibSurfaceText; LibLoadingProgress.
These are NTSD-distribution behaviour and a natural part of the NTSD profile
(or an engine "extension" switch), separate from the ID tables.

Other game identity still in Core: replay version check (OriginalReplayPlayback.swift:165–171,
version word 0x44d03c, 0x1e → "v2.0", "LF2" in the rejection texts).

## 2.8.3.3 comparison (read only)

`git diff --stat 40611c4d exp/ntsd-2.8.3.3 -- native/Sources/NTSDCore` is not
informative (Core moved to `engine/`; every file shows as added, 1753 files incl.
resources). Against the merge base `ab4e65b4`, the 2.8.3.3 branch (9 commits,
head `19116511`) changes Core by **three new files only**
(`NTSD2833FileBytes`, `NTSD2833ObjectStorage`, `NTSD2833TokenStream`) and Runtime
in two files (content origin). **None of the ID-site files differs; no ID rule
has been recovered for 2.8.3.3 yet.** So the profile's actual variation in rules
is not yet observable in code. What the branch's evidence does show
(`NTSD_2_8_3_3_ENGINE_DIFF.md`, `NTSD_2_8_3_3_FRAME_OBJECT.md`, static, not executed play):

- The special-AI fragment 403a40..4061a0 exists in 2.8.3.3; same-address
  instructions at 0x4045c0 (inside hsasori6's range) and 0x404cd0 (inside
  sasuke11's) differ only by the frame stride 0x178 → 0x1b0. Inference: the ID
  6 and 11 blocks persist; the if-chain itself was not compared.
- Header ID/type stay at `+0x6f4/+0x6f8` (constructor 44c6b0); filename 0x7a8,
  ordinal 0x7ac; frame base 0x830, stride 0x1b0, < 1000 frames; live pool 400 → 1000
  (camera loop bound 0x41b8d7, World table 0x194 → 0x3ec); globals +0x50000
  (RNG 0x49ff90/0x4a0bcc/0x4a0c34); object capacity 1000.
- Content: 330 registered objects (158 type 0) vs 137; 24 backgrounds vs 17;
  Genma IDs 901–907 hidden via a DAT `hidden: 1` field. Inference: roster rules
  (A70–A79, `id < 30`, `id/10` groups) and ID ranges (100…199, 30…39) are where
  2.8.3.3 is most likely to differ; unverified.

So the variation 2.8.3.3 forces first is **layout** (capacities, strides,
offsets, global base), which a rules profile does not cover.

## Recommendation (for the E5 design; to be reviewed)

1. **Two profile parts.** (i) `rules`: the 100 ID sites + AI; (ii) `layout`:
   pool size, frame capacity/stride/base, global base and record extents —
   2.8.3.3 needs (ii) before any (i) difference is even observable. Keep them separate.
2. **Rules = data first, hooks only for bespoke code.** Engine-defined concrete
   value types (no generics over the game type): named roles per *rule* (not per
   object kind, since same-looking lists differ: A40 vs A49, the 30s ranges),
   compiled once at catalog load into a per-ordinal bitmask array
   (`flags[objectOrdinal] & .reflectable`). Header IDs are immutable for a
   loaded catalog, so an ordinal flag equals a live `+0x6f4` compare — but the
   site must still read the Actor's *current* `+0x368` at the same point.
   Numeric parameters (gravity A35, fragment table A52/A54, war life A67,
   guard thresholds A1–A4, AI lists A81–A98) as plain tables with exact literals.
3. **Code hooks** (closures or one protocol held as `let` outside the mutated
   pass) only at coarse points: AI special (403a40 after the entry roll), fusion
   (4064d0), mission pseudo-IDs (437400), war unit life (43abe2), weapon break
   (A52–A54), the 300 exemption, armour test. ≈8 hooks, each called per pass or
   per AI call, not per pair.
4. **Granularity:** dedupe only identical lists (reflect ×2 files, roster ×4,
   random ×4, group5 ×2, noShadow ×2, 122hp ×4, items ×2); keep one role per
   distinct rule otherwise. Until D1, the whole set is "NTSD profile"; the
   engine default is "no special IDs".

Risks to bit-exactness:
- **Order and laziness:** ID tests gate reads that can throw (frame binding),
  RNG draws (A40 stream 147, A49 208, A54 168–196, AI 0x3c–0x81) and re-reads
  after writes (A54 "each check reloads the parent", A24 "no early break …
  reloading the new ID"). A table must not hoist, cache or reorder these.
- **Lookup semantics:** `find` = first matching ordinal (A13, A25, A38, A53,
  A31), War binding = last match (A68); objectCount from the registry, not
  `objects.count`. An ID→ordinal dictionary would change duplicates.
- **Hot paths:** `OriginalContactPass.pair` (O(400²·itr·bdy); A20 runs per body
  box), `OriginalHitPass.resolve`, `ActorPhysics` per actor, drawing per actor.
  An existential/witness call per check there is the measurable risk on the A12;
  per-ordinal flags are one load. AI and per-pass hooks are cheap by comparison.
- **Cross-module optimization:** Core and Runtime build with
  `-cross-module-optimization`; a profile type defined in the game package
  cannot be specialized into engine passes unless Runtime becomes generic. Keep
  profile *types* in the engine and only *values* in the game; clean builds per
  gate (stale-CMO memory).
- **Exclusivity:** hooks taking `inout` pass state while the pass stores the
  profile → overlapping access (compile error, or a runtime trap for class
  storage; silent under the opt-in `-enforce-exclusivity=unchecked`). Pass the
  profile as a separate borrowed parameter or `let` reference.
- **Literals:** keep `Double` bit patterns (0.16999999999999998, 1.1333333333333333),
  `Int32` wrap (`&-`, `UInt32(bitPattern: id &- 30) <= 9`) and signed `/10`.
- **Events:** RNG stream labels and event order are part of the gates; hooks must
  append to the same event list in the same order.
