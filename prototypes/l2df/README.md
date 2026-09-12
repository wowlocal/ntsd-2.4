# NTSD / L2DF macOS prototype

A local two-player feasibility prototype using real L2DF `wip-test` at
`a20a16f2e8c9e889e33b3d762c94dc49498d0f83`, official native LÖVE 11.5
(macOS bundle 11.5a), and unchanged NTSD DAT/BMP/WAV inputs. It is playable,
but its mechanics are those of the candidate. It is **not an accepted NTSD port**.

## Run the prepared app

From this worktree:

```sh
./prototypes/l2df/launch.command
```

The standalone bundle is `build/l2df-prototype/NTSD L2DF Prototype.app`.
It contains its own runtime, engine and resources. The build directory is a
symlink to the allocated X5 folder; the `.app` itself has no external symlinks
or dependencies on Python, the baseline folder, Windows, Wine, a browser, or
an installed LÖVE. For inspection, run its `Contents/MacOS/love` executable.
The original LÖVE download is unsigned; this prototype is not notarized.
No OS protection, global installation or model setting was changed.

| Player | Move | Attack | Jump | Defend |
| --- | --- | --- | --- | --- |
| Naruto | W A S D | F | G | H |
| Sasuke | Arrow keys | J | K | L |

For Sasuke's needles, press **J + L + the direction he faces together** while
standing. This is the candidate's simultaneous input rule; NTSD's sequential
D→direction→A input does not work here. R restarts, Esc pauses, M mutes, Q quits.
Focus loss pauses the interactive scene. F12 saves a screenshot when launched
with the diagnostic runner below. The opponent is another local player, not AI.

## Inspect / reproduce the checks

```sh
python3 prototypes/l2df/run.py \
  --app 'build/l2df-prototype/NTSD L2DF Prototype.app' \
  --smoke --label my-unique-smoke
```

Each label must be new: prior runs are retained. The runner pins its inputs,
records PID/start/cwd/command, preserves stdout/errors and limits a smoke to
90 seconds. The app runs 600 candidate ticks with synthetic keyboard callbacks,
records both players' positions/frames/HP/MP, actual audio play state and dynamic
objects, captures PNGs, then exits. These inputs are not physical keyboard input
or Windows observations. Omit `--smoke` for interactive use with logs.

The accepted candidate run is `logs/packaged-smoke-01`: native launch, movement,
a jump, melee damage, one Chidori projectile and audio sources playing.
`logs/smoke-01` retains the initial missing Sync initialization error;
`smoke-02` retains the black-background and insufficient projectile check.
Those failures were not erased or counted as complete acceptance.

## Prepare and package again

The original resource directory is read-only. Existing pinned downloads and full
upstream source are in `build/l2df-prototype/{downloads,source}`. Sources:

- [Pinned L2DF archive](https://codeload.github.com/atom-tm/l2df-engine/tar.gz/a20a16f2e8c9e889e33b3d762c94dc49498d0f83)
- [Official LÖVE 11.5 macOS ZIP](https://github.com/love2d/love/releases/download/11.5/love-11.5-macos.zip)

The study's retained GitHub tree is checked against every upstream archive blob;
this local preparer reads that existing evidence path. It copies 111 original
resources and vendors engine files without modifying their bytes. Sprite black
color-key transparency is applied to owned image buffers in LÖVE; source BMPs
remain unchanged. Native runtime files are already in `runtime/love.app`.

```sh
python3 prototypes/l2df/prepare.py --baseline \
  '/Users/michael/Developer/ntsd-2.4/downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a'
python3 prototypes/l2df/package.py --name 'NTSD L2DF Prototype candidate2.app'
```

Use a new package name; the packaging script refuses to overwrite existing apps.
Do not edit or rebuild the game while its directory-mode process is running.
The fused app uses its immutable `.love` archive. Package verification compares
every ZIP member with the prepared file and rejects external framework symlinks.

## Compatibility limits

The finite catalog is Naruto (2), Sasuke (11), charge/voice (203), snake (224),
and Chidori (440). All 819 source frame definitions are parsed (818 unique IDs).
This count does not validate numerical or loader fidelity: L2DF still replaces
Naruto's repeated frame 123 instead of retaining omitted numerical fields.
Kunai is excluded because its malformed frame import remains incompatible.

Known discrepancies include a single Chidori object instead of NTSD's five,
no 100-MP charge for that technique, simultaneous rather than sequential combos,
and candidate timing/physics/damage/recovery/RNG rules. Most Naruto techniques
refer to objects outside this catalog and are logged as unsupported. Menus,
AI, saves/replays, networking, all content and a complete original match are
not implemented by this scene. Networking is not registered or connected.
Physical keyboard, audible device output, Windows visual/timing comparisons,
Intel and a clean second Mac remain unverified.

See [the complete report](../../docs/research/L2DF_NATIVE_PROTOTYPE.md) and
[compact evidence](../../docs/evidence/l2df-native-prototype.json).
