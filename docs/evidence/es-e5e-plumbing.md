# E5e survey: the coarse hooks (2026-10-20)

A read-only survey by a separate agent at `326362f7` (nothing built or run, no
fixture or content bytes read; "inf." marks inference, the rest is read code).
Recorded in substance; the loop's decisions on it are in the card's E5e note.
Paths are under `engine/Sources/NTSDCore/`.

**Finding.** No coarse point needs a new code hook: all five become profile
roles where only the comparison changes, with three small tables; the AI's
special-move hook (E5d-2) stays the only hook. Every pass involved already
holds `rules` as a `let` (`OriginalHitPass` `OriginalActorHits.swift:69`,
`OriginalContactPass` `OriginalWorldContacts.swift:101`, the commands' Body
`OriginalPostDrawCommands.swift:95`, `OriginalMissionStagePass` :46,
`OriginalWarBattlePass` :44, the lifecycle's Body
`OriginalPostDrawLifecycle.swift:135`), so no public pass signature changes.
This revises the E5 design's hook list as E5c-1b dropped the armour hook.

## 1. The ID-300 exemption

- **A7** (`OriginalHitDamage.swift:7–12`, after `put(d,0xb8,45)` at :6): on
  `h(d,0x6f4) == 300`, if the frame's +0x12c > 0 it reads the first body word
  (`memory.word(f(d,0x134))`, which can throw); above 1000: d+0x364 = 1,
  d+0x70 = word &− 1000, a+0xb4 = 3, d+0xb4 = −3. It returns true and
  `resolve` returns (`OriginalActorHits.swift:171`): the spark and the
  attacker's remaining contacts are skipped. No random draws. Hot: per contact
  every tick (`OriginalWorldHits.swift:41,101` ← `OriginalGameplayBody.swift:121`;
  the library path `OriginalLibActorHits.swift:22,37` shares it).
- **A51** (`OriginalPostDrawCommands.swift:192`, `recover`, per active slot):
  last in its chain (0x450bb8 == 2, mode 1, team 5, type 0, `h != 300`); a
  match zeroes HP and MP. Rarely reached.
- **A60** (`OriginalMissionStage.swift:423–424`): `difficulty == -1, id != 0x12c`
  (×1.5) and `== 2` (×0.75), on the stage spawn word before the pseudo-ID
  substitution. Cold.
- **Recommendation:** three separate `Int32` roles (different passes,
  behaviours and value domains, F9); the body-word convention, 45, ±3, the
  early return and both factors stay engine code.

## 2. Fusion

`OriginalWorldFusion.swift`, the contact pass's tail
(`OriginalWorldContacts.swift:294`), once per tick over slots 0..<20 unless
0x44d05c == 2.
- **A24 (:10, :14):** `[7,8].contains(h(a))` (one read), then HP > 0, state 2,
  +0x338 == 0 and (HP < 177 or 0x458428 == 1); the partner test
  `h(d) == 15 &- h(a)` re-reads `h(a)` for each other actor; no break after a
  fusion.
- **A25 (:26):** an inline first-match scan for 51, then the HP/max merge,
  frame 290, +0x328 = 1, +0x32c, +0x338 = 4500, +0x330/+0x334 = both IDs,
  +0x368, MP 500, the partner deactivated.
- **A26 (:40):** `h(a)==51 && +0x328==1 && (frame<9 || >260) && +0x338<=0`;
  restores through a full scan with no break (each +0x334 match reconstructs
  again and emits `.reconstruct`), then halves HP and max, frame 112, timer
  900. No random draws.
- **Outside, ID-free:** A27 (`OriginalMatchRound.swift:180–195`, the round
  restore's defuse, re-reads guarding aliasing) and route 8
  (`OriginalActorInput.swift:147–148`: +0x328 == 1 sets +0x338 = 0) fix the
  fusion record's layout.
- **Recommendation:** roles `fusers` {7, 8}, `fusionPartnerSum` 15, `fusedForm`
  51 (A25 and A26 share it: one Object, one mechanism). The sum form stays
  exact for every value (a reloaded 51 gives 15 − 51 = −36); a pair table
  would not. A hook would expose about 12 contact-pass primitives and still
  could not change the layout A27 and route 8 use. Inf.: 7+8→51 matches LF2's
  numbering; likely an LF2 rule NTSD kept.

## 3. Mission pseudo-IDs

`OriginalMissionStage.swift:425–439`, in `spawn` (:412), once per spawn in
mode 1 (cold), from the `mission` closure (`OriginalGameplayBody.swift:147,210`).
- **A61 (1000):** when the cursor 0x44d34c is 10 or −1, 50 swaps of the
  ten-word hero table at 0x44d324 (streams 0x10f/0x110, range 10), then the
  entry, the cursor advanced; reset to −1 at a set's first phase (:142). The
  table is record data the game supplies.
- **A62 (3000):** `draw(0x111,2) &+ 0x1e`.
- **A63 (3001):** `draw(0x112,7) == 0` → 0x20 with `hp &*= 4`; else
  `draw(0x113,2) &+ 0x1e`.
- Then a first-match catalog scan (:440–443); a miss writes −1 to the slot.
- **Recommendation:** split: `Int32` roles `heroSpawn` 1000, `troopSpawn` 3000,
  `troopOrBossSpawn` 3001, `bossTroop` 32, `troopBase` 30 and `troopChoices` 2
  (the draw's range, shared by A62 and A63). The shuffle, the ten-word layout,
  the reset, 1-in-7, ×4 and the stream labels stay engine code.

## 4. War life (A67)

`OriginalWarBattle.swift:203–216`, per reserve spawn in mode 4 (cold); `unit`
is a War-table word, not a header. Side 0 with type 0: +0x318 = 0x8c, then
0x72 for unit 37. Life: 36→250; 37, 35, 32→200; 39, 33→150; 34→100; 31,
30→50; 122→200; else 500; written to +0x300, +0x2fc and +0x304 for every unit
(so the design's "122 writes three fields" is generic). `at43` implies unit 37
and the assignments are on disjoint values: life is a pure function of `unit`
(to be checked mechanically).
- **Recommendation:** data: `warUnitLife: [Int32: Int32]` (the 500 default
  kept in the engine) and `warLeftMark` [37: 0x72]; both +0x318 stores kept.

## 5. Weapon break

`weapon(parent)`, `OriginalPostDrawLifecycle.swift:191–244`, on
`.weaponCreation` (:345). Cold.
- **A52 (:195):** a dictionary literal built on every call, looked up with
  `[Int(originalID)] ?? 0`. Pure data.
- **A53 (:200):** `find(999)` per fragment after `free()`; a miss keeps
  `scratch.weaponObject` from earlier calls, and with none ever, it throws
  "Weapon Object index provenance".
- **A54 (:210–240):** 14 tests, each re-reading `source(parent)` (the child's
  construction can rebind the parent); streams 168–196, ranges 20/8/4/18,
  frame bases, ordinal tiers; the generic draws 166, 167 and the x-speed draw
  170 (:213) sit between the second test and the rest.
- **Recommendation:** A52 a `weaponFragments` table (counts ≥ 0, checked when
  the profile is built); A53 its own role (apart from A36, N3, N4); A54
  per-branch roles (two sets, eleven single IDs and {217, 218}) with the
  shapes engine code (E5c-1e, E5d-1a precedent). A table form would need three
  action kinds, one used once (101's base drawn from stream 177 before 178);
  deferred to D1 or 2.8.3.3.
- **Engine tests:** `engine/Tests/NTSDEngineTests/OriginalRequestSlotWordTests.swift:97`
  breaks Object 100 and expects `.actor(54)`: `engineTests` must carry
  [100: 5] (the F1 pattern).

## 6. Increments

Each: the three constructions (profile, `engineTests`, `with`), synthetic
tests under NTSD's profile and a moved one, a review with the mapping table,
clean builds, 3,278 accesses, the mlgate set and the WASI vs.

| Step | Sites | New tests | gate3 additions |
| --- | --- | --- | --- |
| E5e-1 | A7, A51, A60 | `damageHit` with a body word of 1005 (frame 5, team 1, ±3, returns true); `recover` with 0x450bb8 = 2; mission `spawn` at difficulty −1 and 2 | `OriginalActorHitsTests` (IDs 2, 7, 8, 51: never 300), `OriginalLibActorHitsTests`, `OriginalGameplayHitsTests`, the commands trio, `OriginalMissionStageTests`; phone A/B (hot) |
| E5e-2 | A61–A63 | `spawn` with 1000 (50 swaps, cursor), 3000, 3001 down both branches | mission stage, `NTSDProfileModesTests` |
| E5e-3 | A67 | War `spawn` for each unit, side and type | `OriginalWarBattleTests` (1,410 cases), the `OriginalLibWar*` suites |
| E5e-4 | A24–A26 | `fusion()` directly: a fuse, the HP-177 gate, a defuse with `.reconstruct`; moved IDs | the four contacts suites, `OriginalMatchRoundTests`, `OriginalActorInputTests`; phone A/B |
| E5e-5 | A52–A54 | each ID's break (draw order, frames, speeds); 999 missing | the lifecycle trio, the engine tests |

## 7. Risks

- Tables replacing chains: A67's equivalence depends on `at43` implying unit
  37 (check over all `Int32`, as E5c-2e); `Int32`-keyed tables avoid `Int(...)`
  conversions; duplicate keys trap when the profile is built.
- First match against no break: keep A25's and the pseudo-ID scan's `break`,
  A26's and A27's no-break restore scans.
- Throwing reads stay: A7's heap read only on a match, A51's header read last,
  A24's `h(a)` re-read per other actor, A54's 14 re-reads.
- Random draws: labels and ranges unchanged (range 2 appears in the events).
- Exclusivity: every new read a static `let` read. Performance: A7 per
  contact and A24 every tick load through the shared storage instead of an
  immediate; the phone A/B decides. wasm32: no new `Int(UInt32)` conversions.

## 8. For the user

Nothing blocks E5e. D1 would show whether fusion and the 300 rule are LF2
2.0a's (inf.: yes) and whether another game needs different shapes (reopening
tables or hooks); D2 is unaffected.
