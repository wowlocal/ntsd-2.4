# NTSD 2.4 — native macOS port

The target is a native macOS game preserving the original Windows NTSD behavior.
Only the pristine Windows distribution is the behavioral reference. The previous
JavaScript approach is not used. See [PLAN.md](PLAN.md) for the implementation
stages and [original-engine evidence](docs/ORIGINAL_ENGINE.md) for verified findings.

**Current status:** a native movement practice slice is playable: Naruto on the
original District arena, with walking, turning, double-tap running, stopping,
jumping/dashing and landing. Combat, opponents and game modes are still pending.
[Movement evidence and limits](docs/MOVEMENT.md) describe the exact scope.

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
| Esc | Pause / resume |
| R | Reset practice |
| M | Mute / unmute |

Losing window focus pauses movement and clears held keys. The original graphics,
frame timing, movement and camera rules are used; original menus and combat are
not implemented. The practice spawn is a controlled starting point, not match RNG.

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
swift test --package-path native
```

The oracle tools need `uv` and execute bounded original EXE routines in a
development-only CPU harness. Movement matches **8,506 original x86 ticks in
58 sequences**, including camera and pre-scheduler render frames. Offline tests
retain 3,770 movement ticks, 36 timer samples and 120 District draw lists.
These comparisons do not establish whole-match or end-to-end latency equivalence.

The recovered frame-section loader matches 15,044 original definitions and
12 edge cases; 349 groups and whole-file loading remain outside its verified
domain. See [frame-loader evidence](docs/FRAME_LOADER.md). The CPU harness and both
native check executables are absent from the `.app`.

Generated imports and full differential corpora live under `build/`; original
game files remain read-only inputs. Next is the first verified melee exchange.

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
