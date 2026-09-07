# Native melee practice: Naruto and Sasuke

Baseline: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe`.
SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.

This document records the original melee milestone and its retained evidence.
The default app now also supports Sasuke's snake and Chidori needles, MP spending
and player selection. Read [PROJECTILES.md](PROJECTILES.md) for that extension,
its additional x86 comparisons and current controls. The older melee-only API
and fixture remain regression tests. This is still bounded practice, not a
complete match; no rules come from the rejected JavaScript implementation.

Read [MOVEMENT.md](MOVEMENT.md) and [FRAME_LOADER.md](FRAME_LOADER.md) for the
movement, timer, background and frame-loader foundations. The earlier movement
scene remains accessible with `--movement`; the raw resource inspector uses
`--inspect`.

## Reference boundary

`tools/oracle_combat.py` extends the development-only x86 harness with two actors
and executes these original instructions:

| Stage | Address | Scope |
| --- | --- | --- |
| Actor initialization | `0x4061d0` | Constructor, followed by declared practice initial conditions |
| Normalized input | `0x4198f0` | Two replay-format input slots |
| Controls | `0x413080` | Original routine, including seven buffers and combo recognition |
| Physics | `0x40e490` | Motion, hitstop, airborne fall phases, ground bounce and landing |
| Initial depth bounds | `0x417f80` | Original pass before collision |
| Contact collection | `0x419380` | Two unarmed type-0 actors on opposing teams |
| Rectangle intersection | `0x4171c0`, `0x417400` | Actual source itr/bdy rectangles, including auxiliary bodies |
| Hit resolution | `0x42e100` | Normal kind-0/effect-0 or effect-1 hits, guard, kind 6, passive kind 4 |
| Bounds/camera | `0x41b5d0..0x41bc74` | District, Naruto is the local camera player |
| Pending hit velocity | `0x4196f0` | Accumulated impulses after hitstop |
| Frame scheduling | `0x40d960` | Both fighters, then newly spawned voice objects |
| Post-scheduler recovery | `0x41fb0b..0x41fc61` | Dead standing / grounded falling cases |
| Voice object spawning | `0x41fc61..0x420e93` | Original allocation/placement of object 203 |
| Gameplay RNG | `0x417170` | Original table and counter updates |

The main-loop call order comes from the call sites documented in MOVEMENT.md.
The harness runs these routines/slices in that order. It does **not** execute a
complete match loop, Windows input device, DirectDraw or DirectSound.

Frame constructors, section parser and postprocessing run in the original x86
instructions. The previously documented CRT string/numeric/allocation boundary
is retained. Numeric character/background header fields are supplied at observed
structure offsets; whole-file header parsing is not newly claimed here.
The supported fighter definitions are loaded in source order: movement frames,
60–74, 85, 95, 110–114, 180–191 and 220–231, plus Sasuke 240–242 when present.
Missing definitions are not fabricated. Repeated frames and all source boxes
are preserved by the recovered loader.

The two controlled actors start at x=450/485, y=0, z=490, facing each other, with
500 HP/MP and zero velocities/pending impulses. Individual tests declare their
own initial frame, position, facing or health. This is a test/practice spawn,
not a reconstruction of match setup or character selection.

## Original random state

`tools/original_replay.py` imports only the RNG table and initial index from the
supplied `recording/20260331_115445_Stage_1.lfr`. Its SHA-256 is
`9555710ff6b79e624d6f97a5d2373ae7b4d46135d5e9f45940b787f4e1663630`.

- `0x43e766..0x43e7d3` subtracts the EXE's key at VA `0x44d7a0` from a prefix
  of the compressed replay. The key is 1,345 bytes. The original inefficient
  repeated strlen loop is executed in the oracle with a larger instruction cap.
- Inflation is an explicit Python zlib boundary, not an execution of the original
  decompression routine. The decoded baseline length is `0x630e18`.
- `0x43e3c5..0x43e3f8` restores the index at decoded offset `0x8c4` and the
  3,000 nonzero bytes at `0x8c8`. Original instructions and the importer agree
  on every byte and the initial index, 11. Counter reset is observed at
  `0x43e5fd`; the controlled practice starts at counter 0.
- `0x417170` increments counter modulo 1,234 and index modulo 3,000, then
  returns `(table[index] + counter) % range`. Nonpositive ranges return 0
  without advancing state. The native implementation matches 6,500 calls,
  including both wraparounds and nonpositive ranges.

The same seed is restored on R. It reproduces a fixed practice sequence;
new-match RNG initialization and replay playback remain unimplemented.
No host random generator substitutes for gameplay RNG.

The oracle replaces CRT `rand` at IAT `0x447198` with a return of 0 for the
hit-spark placement jitter at `0x431a42`/`0x431a86`. Those visual coordinates
are excluded from comparison and the native renderer does not yet draw sparks.
This boundary is separate from the gameplay RNG routine, which runs unchanged.

## Verified behavior and useful details

- The input comparison covers the seven edge buffers, defense cooldown and nine
  combo progress bytes (`0x412800..0x413077`, invalidation at `0x40e170`).
  Recognizing a combo does not imply its technique is implemented.
- Ordinary attack selection uses the original RNG. Standing/walking controls
  process attack, jump and defend sequentially; later applicable branches can
  replace the selected frame.
- Collision snapshots both frames before resolving either direction. Touching
  rectangle edges do not overlap. Default depth width is 15 with a strict
  comparison. Equal-distance contact selection can consume gameplay RNG even
  for multiple body rectangles belonging to the same opponent.
- Damage updates HP, recoverable HP, damage statistics and kills. Guard checks
  source frame state, facing and bdefend. Successful guard takes integer injury/10;
  its accumulated defense damage can switch the reaction to the broken-guard
  frame. These are original rules, not a configurable new damage model.
- Hitstop approaches zero before motion resumes. Accumulated hit velocity is
  applied after drawing and before frame scheduling, scaled by `2/(hitCount+1)`.
  Rest/vrest and recovery invulnerability prevent repeat hits where prescribed.
- Falling animation thresholds are -8, **1**, 8. The middle threshold comes
  from the original x87 stack at `0x40e6de..0x40e6eb`; substituting 0 failed
  comparison. Ground bounce/lying transitions use `0x40eb18..0x40ec4e`.
- Camera look-ahead is omitted for a lying local player (`0x41b939`). If the
  local player is dead, `0x41ba8d..0x41bb76` instead averages living type-0
  actors, or uses 800 when none remain. The same smoothing then applies.
- The render pose stores frame, facing and integer x/y/z **before** scheduling
  and the post-scheduler recovery script. Rendering the final state would show
  a changed pose too early.
- Invisible voice object 203 frames 200, 201, 207, 208 are born after fighter
  scheduling, occupy later slots, produce their sound and expire in the same
  tick. Their sound events follow both fighters' frame sounds.
- Built-in WAV indices are recovered from `0x41bec8..0x41bf86`: 0→001,
  1→002, 2→006, 6→016, 7→017, 11→032, 12→033, under `data/`.

## Reproduce and retain the evidence

```bash
./run-native.sh --build
uv run tools/oracle_combat.py
swift test --package-path native
```

The oracle generates original x86 states first, then invokes the independent
Swift checker. It updates the checked-in fixture and evidence only after exact
comparison succeeds. `--capture-only` does not update accepted fixtures/evidence.

The corpus covers ordinary attacks by both fighters, guarding, rear guard,
mutual attacks, held input, chained punches, heavy hits, airborne targets,
lethal hits on either fighter, lying/dead-player camera behavior, guard chip,
depth boundaries, mirrored hits near arena edges and
432 combinations of actual attack/body frames, facing and separation. It also
re-runs all 8,506 prior movement ticks through the two-fighter pipeline.

Each tick compares both actors' coordinates and binary64 velocities, frames,
wait/phase, input and combo buffers, hitstop, fall/guard counters, rest/vrest,
HP/red HP/MP, hit statistics, pending impulses, render poses, camera, gameplay
RNG indices and the ordered sound events. Equality is exact, with no epsilon.
The comparison passed **12,215 ticks in 524 sequences**, plus **6,500 RNG calls**.
Offline XCTest retains **3,709 melee ticks in 466 sequences** and all RNG samples.
The accepted counts and source/fixture hashes are in
[evidence/combat-oracle.json](evidence/combat-oracle.json). The full corpus stays
under `build/original/`; offline XCTest retains the melee cases and RNG samples.
A separate test rejects a technique after the first actor has consumed RNG and
verifies rollback of both actors, sounds, RNG and next-tick input edges.

## Native host and remaining work

Tab selects the controlled fighter. Arrows/WASD, Space and J/K control that
fighter; I/O attack/defend for the other. The opponent has no AI. Esc pauses,
R resets and M mutes; losing focus clears both sets of held keys. The 33 ms
original clock governs simulation. HP/MP panels and the practice footer are new
host UI; original menus/full HUD are pending.

The packaged arm64 app was visually checked with original District layers,
both characters, portraits and health bars. AppKit pause/reset and key codes
were checked. The UI automation tool sends letter down/up events only a few
microseconds apart, shorter than a simulation tick; these impulses do not
establish held-key combat behavior or end-to-end latency. No input latching was
added to change the recovered sampled-input semantics for that tool.

Unsupported branches stop the practice, discard the entire attempted tick and
show “Приём пока недоступен · R — заново”. This includes aerial/dash attacks,
rolls, combo techniques other than Sasuke’s Chidori needles, and objects beyond
the verified voices/snake/needles. Sasuke’s running attack still continues into
an unported frame. Original definitions are not edited to hide
these branches. Naruto's strong melee attack is within the recovered slice.

Still pending: other projectiles, grabs/thrown-body damage, chakra recovery,
other interaction/effect kinds, hit-spark rendering, AI, match/spawn/death
lifecycle, HP/MP regeneration, full HUD/menus, music and other modes. SpriteKit
only presents original bitmaps; exact raster output, stereo mix and latency
have not been compared to a complete original game running on Windows.
Intel and a clean second Mac have not been tested. The x86 harness, Python,
reference EXE/replays and native check executables are absent from the `.app`.

The spawning/first-technique milestone is recorded in [PROJECTILES.md](PROJECTILES.md).
The current sequence is maintained in [RESEARCH_MAP.md](RESEARCH_MAP.md), starting
with the complete tick boundary and shared mechanisms. Remaining attacks and rolls
stay open; unsupported mechanics remain explicit until verified.
