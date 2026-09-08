# NTSD 2.4 — native macOS port

The target is a native macOS game preserving the original Windows NTSD behavior.
Only the pristine Windows distribution is the behavioral reference. The previous
JavaScript approach is not used. See [PLAN.md](PLAN.md) for the implementation
stages and [original-engine evidence](docs/ORIGINAL_ENGINE.md) for verified findings.
The [research map](docs/RESEARCH_MAP.md) tracks mechanisms, dependencies, analysis,
native implementation and verification separately. Its active task is
[R02.1: complete tick state and initialization](docs/research/R02.1.md).
[R01.1 findings](docs/research/TICK_PIPELINE.md) establish the original dispatch
path and expose gaps in the composed native/reference slice, including item RNG
and resource recovery. The new control-flow traces do not prove full native fidelity.
[R02.1 state findings](docs/research/STATE_LAYOUT.md) add byte-checked native
Actor/World constructors and raw snapshots preserving unknown fields. Full match
initialization and integration with the game loop remain pending.
The [loading-time pool](docs/research/BOOTSTRAP.md) now also matches the EXE for
all 400 slots. Its eight staging actors are separate from selected-player spawning.
The [complete catalog loader](docs/research/LOADED_CATALOG.md) now executes the
original parent with real Object/BG/Stage/bitmap/sound children and matches native
Swift for all 137 source objects, 17 backgrounds and 25 stages / 138 phases.
The comparison retains all 101 BG and 60 Stage slots, whole Object/Frame bytes
and masks, 829 bitmap wrappers, raw Frame allocations, shared checksum and sounds
after each child call. It covers text and raw file contracts plus interleaved
children with repeated IDs, using the pinned VC80 scanf at explicit file/device
boundaries. The old [parent-only study](docs/research/CATALOG_REGISTRY.md) and
[individual Object](docs/research/RAW_FRAME_STORAGE.md),
[BG](docs/research/BACKGROUND_LOADER.md) and [Stage](docs/research/STAGE_LOADER.md)
corpora keep their separate verification scopes.
The [common match preparation](docs/research/MATCH_PREPARATION.md) now continues
from that loaded catalog through World/400 Actor: 50 chained scenarios match
native Swift, including RNG, placement, arena lifecycle and input reset. Menu/RNG
input provenance, the mode prelude and the remaining start
sequence are still open. [Recording initialization](docs/research/REPLAY_INITIALIZATION.md)
now follows that preparation: 50 complete buffers match, including source IDs,
inactive slots, settings, strings, allocation/free order and the RNG counter reset.
Replay playback/file IO, full gameplay, Windows startup and visual/audio
output remain open. Practice still uses its prior import; the new state is not yet a complete
match or wired into the wider tick reference.

**Current status:** native Naruto/Sasuke practice on District, now with Sasuke’s
snake strong attack and Chidori needles (100 chakra), alongside movement, melee,
guard, damage and recovery. Tab selects the controlled fighter. AI, other
techniques and full game modes remain pending. See [combat evidence](docs/COMBAT.md)
and [projectile evidence and limits](docs/PROJECTILES.md).

## Run the native application

Requires macOS 14+, Xcode command-line tools, Python 3 and restored Git LFS assets.

```bash
./tools/fetch-assets.sh          # only if original assets are still LFS pointers
./run-native.sh --build
./run-native.sh
```

The build produces **`build/NTSD Native.app`** for the host architecture (verified
on Apple Silicon). It bundles original BMP/WAV assets and imported data. No browser
engine, Windows executable, Wine, CrossOver or emulator is present in the app.
Rebuild with `--build` after source or data changes.

| Key | Action |
| --- | --- |
| Arrows / WASD | Walk and turn; up/down change depth |
| Double-tap left/right (or A/D) | Run; press the opposite direction to stop |
| Space | Jump; dash while running |
| Tab | Select Naruto / Sasuke; camera follows the selected fighter |
| J / K | Selected fighter: attack / defend |
| I / O | Other fighter: attack / defend (no AI) |
| K, then left/right, then J | Sasuke: Chidori needles, 100 chakra |
| Esc | Pause / resume |
| R | Reset practice |
| M | Mute / unmute |

Losing window focus pauses practice and clears held keys. Original BMP/WAVs,
frame timing and recovered movement/combat rules are used. The HP/MP panels are
practice UI; original menus and the full HUD are pending. Spawn positions are
controlled; attack randomness starts from a fixed RNG state in a supplied
Windows replay. R restores this state and chakra. An unsupported technique pauses practice
with a reset prompt, including aerial attacks and Sasuke’s running attack.
Chakra regeneration remains pending. See [the supported domain](docs/PROJECTILES.md).

The earlier Naruto movement scene is available with `./run-native.sh --movement`.
The source inspector remains available with `./run-native.sh --inspect`. It shows
all objects and raw source frame occurrences, including duplicates, original
sprites, body/interaction boxes and individual frame audio. Its arrow buttons
browse data rather than advance the gameplay simulation.

## Verification

```bash
python3 tools/test_import.py
swift test --package-path native
./run-native.sh --verify-data
uv run tools/oracle_dat.py
uv run tools/oracle_frames.py
uv run tools/oracle_frames.py --corpus
uv run tools/oracle_movement.py
uv run tools/oracle_presentation.py
uv run tools/oracle_combat.py
uv run tools/oracle_projectiles.py
uv run tools/oracle_catalog.py
uv run tools/oracle_loaded_catalog.py
uv run tools/oracle_loaded_catalog.py --raw-zero
uv run tools/oracle_loaded_catalog.py --interleaved
uv run tools/oracle_loaded_catalog.py --accept
uv run tools/oracle_objects.py --suite
swift test --package-path native
```

The oracle tools need `uv` and execute bounded original EXE routines in a
development-only CPU harness. Movement matches **8,506 original x86 ticks in
58 sequences**, including camera and pre-scheduler render frames. Offline tests
retain 3,770 movement ticks, 36 timer samples and 120 District draw lists.
The extended combat corpus matches **12,215 ticks in 524 sequences**: both actors,
hit counters, HP, input combos, render poses and ordered sound events, plus
**6,500 original RNG calls**. Offline tests retain 3,709 melee ticks.
Accepted counts and hashes are in [combat evidence](docs/evidence/combat-oracle.json).
The object-enabled pipeline matches **16,685 ticks in 575 sequences**, including
all earlier combat/movement cases and **4,470 new projectile ticks**. Offline
tests retain another 2,010 ticks; see [projectile evidence](docs/evidence/projectiles-oracle.json).
These comparisons do not establish whole-match or end-to-end latency equivalence.

The recovered frame-section loader matches 15,044 original definitions and
12 edge cases; 349 groups remain outside that isolated domain. A separate
[whole-object corpus](docs/research/OBJECT_LOADER.md) checks three source files
and one synthetic stream, including kunai's unclosed itr across a frame boundary.
See [frame-loader evidence](docs/FRAME_LOADER.md). The CPU harness and all
native check executables are absent from the `.app`.

Generated imports and full differential corpora live under `build/`; original
game files remain read-only inputs. The next work follows the research map:
connect loaded catalog and match state, a wider oracle, then generic transitions
and object creation. Characters are source-data cases for shared engine rules;
ID-specific behavior is retained only where the original EXE establishes it.

## Existing Windows game through CrossOver

The original launcher is retained for the existing known-good setup. It launches
the Windows game and is separate from the native development tools.

1. Install prerequisites:
   - CrossOver
   - Git LFS (`brew install git-lfs`)
2. In this repo:
   - `git lfs install`
   - `git lfs pull --include="downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/**"`
3. Launch:
   - `./run-ntsd24.sh`

Default launcher config:
- Bottle: `NTSD24XP`
- Game dir: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a`
- EXE: `NTSD 2.4.exe`

## Why LFS Matters

Game assets are stored with Git LFS. If LFS objects are not checked out, files like `NTSD 2.4.exe` become small text pointer files and Wine/CrossOver can fail with:

`winewrapper.exe:error: cannot start ... NTSD 2.4.exe (error 11)`

`run-ntsd24.sh` now detects this and tries to auto-restore required files via `git lfs checkout` and `git lfs pull`.

## Manual Recovery (if needed)

From repo root:

```bash
git lfs pull --include="downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/**"
git lfs checkout -- "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a"
./run-ntsd24.sh
```

## Detailed Troubleshooting

See [NTSD24_CROSSOVER_ERRORS_AND_SOLUTIONS.md](./NTSD24_CROSSOVER_ERRORS_AND_SOLUTIONS.md).
