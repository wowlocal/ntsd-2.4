# Native snake and Chidori needles

Baseline: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe`.
SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.

The default practice now supports Sasuke's strong attack (snake object 224) and
his first chakra technique, Chidori needles (object 440). Tab selects the local
fighter and camera subject; arrows/WASD, Space and J/K control that fighter.
I/O attack/defend for the other fighter. With Sasuke selected, enter K, then left
or right, then J to perform the original D→direction→A combo. The original
combo buffers and guard recovery govern when it starts; there is no shortcut
that bypasses the input recognizer. The technique costs 100 of the initial
500 chakra. R restores the practice, including chakra and RNG, while preserving
the selected fighter. Chakra regeneration is still pending.

This extends [COMBAT.md](COMBAT.md), [MOVEMENT.md](MOVEMENT.md) and the recovered
[frame loader](FRAME_LOADER.md). All definitions come from original DATs;
no game data or behavior from the rejected JS version is used.

Later [R01.1 research](research/TICK_PIPELINE.md) executes the surrounding original
dispatch/match routine on synthetic data and records [gaps](research/TICK_GAPS.md)
in this composed slice: item-spawn RNG, separate type-0/type-positive hit passes,
input/pause phases, linked objects and resource recovery. The accepted comparisons
below retain their bounded meaning; they are not whole-match equivalence.

## Source instructions and verified rules

| Rule | Original EXE source |
| --- | --- |
| Actor constructor | `0x4061d0` |
| Object header defaults | `0x40efe2..0x40f01a` |
| Combo frame transfer / affordability | `0x40e2d0..0x40e445` |
| Direction and combo reset after transfer attempt | `0x4128be`, `0x4129ae` |
| Frame velocity control | `0x414247..0x4143cb` |
| Type-3 motion, hitstop, gravity exclusion | `0x40e490`, `0x40e5aa`, `0x40e6ed`, `0x40edd9` |
| Contact collection / hit resolution | `0x419380`, `0x42e100` |
| State-3000 normal-hit reaction | `0x42f0a9..0x42f183` |
| Type-3 guard sound / state-3000 guard reaction | `0x42fe19..0x42fe85`, `0x430520..0x430569` |
| Bounds and selected-player camera | `0x41b5d0..0x41bc74` |
| Pending velocity pass | `0x4196f0` |
| Type-3 scheduling during hitstop | `0x40d960`, `0x40d973` |
| Spawn placement, allocation and fan | `0x41fc61..0x420e93` |
| Invalid-frame deletion | `0x4213a9..0x4214c6` |
| End-of-tick contact cleanup | `0x4219d6..0x4219f5` |

`tools/oracle_projectiles.py` executes these actual x86 routines/slices in the
original main-loop order. The original constructor, frame parser, collision,
hit, combo and spawn functions run in the reference harness. Swift computes
its states independently. The following behavior passed exact differential
comparison within the declared domain:

- Control and physics run across active actors before collision. Collision
  uses ascending unordered slot pairs, checks both directions and retains the
  original 400 signed-byte vrest entries. Owner/team fields are inherited;
  projectile damage and kills credit the owning fighter. Source auxiliary
  itr boxes, including the needles' y=80000 box, remain present.
- Objects allocate the first available slot from 50 through 399. Every active
  actor's vrest for that reused slot is cleared. The scheduler visits newly
  created objects in later slots in the **same tick**. One-frame voice objects
  play and disappear that tick. The draw pass ran earlier, so newly born shots
  first appear on the following tick. An object can have a final draw pose in
  the tick it expires.
- Spawn x/y use the parent's integer position, source centers and opoint
  offsets; z uses the parent's double position plus 1. The constructor's
  initial pending impulses are 0.1. They are cleared by the later pending pass,
  not by a guessed projectile initialization rule.
- The needles' opoint facing=50 creates five objects. Their spread is
  `n * 10 / (count - 1) - 5`, with the original conditional x-velocity offset,
  staggered rest values and mutual vrest=40. Up/down held at creation shifts
  the fan's z velocity by -2.5/+2.5; simultaneous up/down cancels that shift.
- Type 3 skips fighter gravity/landing. Depth is bounded to 449…526 on District.
  Hitstop suspends translation but **does not stop projectile animation**.
  Lifetime follows source next frames; next>=400 deletes the object.
- State 3000 enters frame 10 on normal or blocked hits and sets vx to zero.
  Normal hits also set vz from frame 10's **dvy** field, as the EXE does;
  blocked hits retain vz. Guard audio uses the projectile header: its default
  -1 produces no sound for these needles. It does not play the fighter guard WAV.
- Sasuke's hit_Fa=261 spends 100 MP only after the original affordability check
  succeeds (global `0x44d034` enabled). Failed attempts still reset that combo
  and apply its facing. Successful transfer clears all seven buffers. Repeated
  casts spend 500 MP, then produce no more needles. The encoded HP-cost branch
  is statically recovered but this technique has zero HP cost; other costs and
  technique transfers are not claimed as verified.

Type-3 x deletion outside [-300,1260] is a **static observation** at
`0x41b6ce..0x41b70a`, included in the native bounds routine. These source needles
expire too soon to exercise that outer boundary from normal fighter positions;
this is not counted as a dynamically verified edge case.

## Data and harness boundary

The new catalog consists of snake 224 frames 0…7, needles 440 frames 1…13 and
voice 203 frames 200/201/207/208/334. Sasuke additionally loads 246 and 261…266.
Snake states are 3002; needles use 3000/3006. These objects have no bdy and cannot
be reflected or destroyed by a fighter in this slice. Other object IDs, opoint
forms, techniques and interaction effects are rejected, with whole-tick rollback.

The parent combat harness supplies the two controlled opposing fighters,
District header values and original replay RNG. The new harness loads object
frame definitions in source order using original instructions, sets observed
header defaults and enables the original MP-spending flag. Replay-input flags
are temporarily changed for the camera call to select one local player, then
restored before the next input pass. This tests both camera subjects without
claiming original character-selection or Windows keyboard-device behavior.

CRT string/numeric/allocation/audio boundaries remain as documented in COMBAT.md.
CRT rand for unrendered hit-spark jitter still returns zero; gameplay RNG runs
unchanged. The harness excludes AI, full-match regeneration, drawing, sound
mixing, full-match setup and other per-mode scripts. Only selected original
post-scheduler/deletion/spawn slices are executed, not the entire Windows loop.

`ProjectileState.motion` reuses the existing fighter storage model. Its legacy
movement-render fields are neutral placeholders; **projectileDraws** separately
records the actual pre-scheduler frame, facing and integer coordinates. Actor
render poses retain their existing meaning. Each tick compares object slots,
IDs, owner/team, all retained motion/contact fields, all 400 vrest entries,
projectile draw poses, both fighters, HP/MP and MP spent, camera, RNG indices and
ordered sound events. Binary64 values compare exactly, without a tolerance.

## Reproduction and retained evidence

```bash
./run-native.sh --build
uv run tools/oracle_projectiles.py
swift test --package-path native
```

The oracle captures original states, builds/runs `NTSDCombatCheck`, and exports
accepted fixtures/evidence **only after** every comparison succeeds.
`--capture-only` leaves accepted evidence untouched.

The new corpus passes **16,685 ticks in 575 sequences**: **4,470 projectile ticks
in 51 cases**, plus all 12,215 earlier melee/movement ticks with the object
pipeline enabled. Cases include both directions and camera subjects, direct and
attack-selected snake spawning, multiple needle contacts, guard chip/break,
lethal hits, airborne/falling/invulnerable targets, depth boundaries, aimed fans,
insufficient MP, repeated casts and object-slot reuse. Offline XCTest retains
**2,010 ticks in 20 cases**, in addition to the previous fixtures. A separate
rollback test retains live needles and spent chakra across a rejected attack.
Hashes/counts are in [evidence/projectiles-oracle.json](evidence/projectiles-oracle.json).

## Native presentation and remaining work

The app draws the original snake/chidori sprite sheets at their original centers,
using the pre-scheduler poses. Original black transparency, nearest sampling and
WAV playback remain unchanged. The snake has no shadow (ID exclusion at
`0x41a690..0x41a770`); needles use the original shadow when y>-70. The original
render-mode shadow blinking and exact raster output are not newly verified.
The HP/MP panels, selection marker and footer are new practice UI, not the full
original HUD. Tab is a host practice control; it does not emulate a game combo.

Developer screenshots can advance the actual native simulation using a declared
oracle case, then freeze its draw state. They do not inject OS keyboard events:

```bash
./run-native.sh --screenshot build/snake.png --practice-preview snake
./run-native.sh --screenshot build/needles.png --practice-preview needles
```

Both previews were visually checked in the arm64 0.4.0 bundle: snake contact,
the five-shot needle fan and 400/500 MP display. Live AppKit checks confirmed
Tab selects Sasuke, R preserves that selection, and Escape pauses/resumes.
Eleven Swift tests and seven importer tests passed; the release bundle passed
ad-hoc signature verification and the no-Windows/browser/test-runtime inventory. The screenshot helper explicitly
renders the SpriteKit scene because AppKit cacheDisplay omits its Metal surface.
These images check native asset loading and placement, not pixel equivalence
with Windows. Normal gameplay still samples held AppKit keys on the original
33 ms clock. No artificial input latching or technique hotkey was added.

Still pending: Sasuke's running attack, aerial/dash attacks, rolls, grabs,
other techniques/projectiles/weapons, HP/MP regeneration, AI and full match
lifecycle, hit sparks, menus, modes, music, exact sound mix and end-to-end input
latency. The shipped app contains only native code, imported data and original
BMP/WAV assets; original EXE, replay, emulation harness and check executables stay
outside the bundle.
