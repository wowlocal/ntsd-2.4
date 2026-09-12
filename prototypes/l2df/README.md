# NTSD / L2DF Native Practice

A native macOS two-player Practice scene using L2DF `wip-test`
`a20a16f2e8c9e889e33b3d762c94dc49498d0f83`, native LÖVE 11.5
(macOS bundle 11.5a), unchanged NTSD resources, and recovered NTSD components.
The supported two-fighter/projectile sequences are compared with retained
original evidence. This is **not a complete NTSD port or original match**.

## Launch

From this worktree:

```sh
./prototypes/l2df/launch.command
```

App: `build/l2df-prototype/presentation-20260912/native-01/NTSD L2DF Native.app`.
It contains the runtime, engine, owned compatibility modules and selected game
resources. It does not need Python, the original distribution, Windows, Wine,
a browser or an installed LÖVE. The task build directory resolves to X5; the
app's framework symlinks are internal. Downloaded LÖVE is unsigned and this app
is not notarized. No OS protections or global installations were changed.

| Player | Move | Attack | Jump | Defend |
| --- | --- | --- | --- | --- |
| Naruto | W A S D | F | G | H |
| Sasuke | Arrow keys | J | K | L |

Sasuke's needles: **L, then left/right, then J**. These are three sequential
button presses. The original buffers/history recognize the move, check frame
availability and HP/MP, and charge **100 chakra** on a successful transfer.
Five needles use the original Opoint fan, owner/team, aim and rest values.
Up/down held at spawning aims the fan. R restarts, Esc pauses, M mutes, Q quits.
Focus loss pauses. The second player is local; there is no AI.

A move outside the supported Practice set pauses with a restart notice. Its
entire attempted tick is rolled back, including input history, RNG, HP/MP and
live projectiles. Full Naruto/Sasuke input-frame availability is separate from
the smaller executable catalog, so an available unsupported technique is not
silently turned into an ordinary attack. Insufficient MP follows the original
failed-transfer path. Regeneration is excluded from the compared Practice set.

## Reproduce

Existing source/runtime downloads remain in `build/l2df-prototype/{source,runtime}`.
Preparation verifies all 850 pinned upstream Git blobs and original EXE identity,
then copies selected DAT/BMP/WAV bytes into a **new** task-owned directory. It
projects only declared DAT/header/replay RNG inputs from the pinned retained
fixture. Expected states and fixture cases do not enter the game archive.
Full input-frame sections come directly from the original Naruto/Sasuke DAT.
Original BMP transparency is applied to owned LÖVE image buffers.

```sh
python3 prototypes/l2df/prepare.py \
  --baseline '/Users/michael/Developer/ntsd-2.4/downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a' \
  --reference-input '/Users/michael/Developer/ntsd-2.4/native/Tests/NTSDCoreTests/Fixtures/original-projectiles.json' \
  --build-name chidori-compat-20260912/my-new-build
python3 prototypes/l2df/package.py \
  --build-name chidori-compat-20260912/my-new-build \
  --name 'NTSD L2DF Native.app'
```

Preparation refuses existing output directories; packaging refuses existing
apps. Never rebuild a directory while its process runs. Old candidate app,
`build/game`, archives and logs are preserved. Archive verification compares
every ZIP member with its prepared file and rejects external framework links.

## Run checks with logs

```sh
python3 prototypes/l2df/run.py \
  --build-name presentation-20260912/native-01 \
  --app 'build/l2df-prototype/presentation-20260912/native-01/NTSD L2DF Native.app' \
  --smoke --label my-new-smoke
```

The 330-tick smoke exercises movement, melee, a jump, sequential needles,
HP/MP, and audio. It records full `world.jsonl` states and `inputs.jsonl` masks,
CSV, events, resource/code pins, PID/start/cwd/command, screenshots and terminal
status. Each run gets a unique label and a 90-second limit. The synthetic
keyboard callbacks pass through L2DF Input/Controller; they do not establish
physical keyboard or acoustic device behavior. Omit `--smoke` for interactive
logging; F12 then captures a PNG through LÖVE.

`--case-input path.json` additionally accepts an external **input-only** object
with `label, initial, inputs, localPlayer` during smoke. It copies the input into
the unique log directory. This enables exact whole-state comparison of the
actual GUI route with a retained case, without packaging expected states.
For a declared unsupported-move case, add `--ui-reset-check` to capture the
notice, invoke the same R callback, check reset state/input/RNG and execute a
neutral continuation. `boundary-state.json` preserves the attempted tick's
before/after snapshots; `reset-state.json` records recovery. This is a callback
test, not an OS-generated keyboard observation.
The independent reference tools are in `tests/reference/`; they never execute
original EXE/DLL files. The parent-maintained study records their acceptance.

## Architecture and limits

L2DF owns the native host, event traversal, Object/Transform, Frames storage,
Render/resource handling, Controller and SoundManager. The scene's SourceHost
component runs `compat.world`: generic ActorInput, fighter/projectile motion,
collision/guard/damage, pending velocity, dynamic slot allocation and scheduling.
A subclass selects the recorded pre-schedule pose through L2DF Frames/Render.
The candidate's automatic States/Physix/Collision/Attributes are not active in
this mode. The earlier feasibility app remains available separately.

The executable domain is retained two-fighter Practice: Naruto (2), Sasuke (11),
voice (203), snake (224) and needles (440), with the recovered subset of frames.
Full source DATs are used for visuals/input availability; that is not a claim
of full loader storage/overflow/alias fidelity. Duplicate numerical fields are
retained by the compatibility frame projection. Kunai's malformed import stays
outside this phase. Auxiliary y=80000 boxes remain in the collision projection.

The recovered no-message timer now drives each native update/render/present,
with fresh UInt32 clock reads, strict elapsed>33-ms, the 100-ms lag cap and the
original Sleep decision. L2DF's separate accumulator is bypassed. Native event
polling and pause/focus clock resets remain host adapters. The camera is applied
to fighters, shadows and projectiles in a 794×550 game viewport; District layers
retain individual counters and parallax. A separate 54-pixel instruction panel
and the scene use the same resize/letterbox transform.

`timer.jsonl` records actual host clock/dispatch/Sleep observations;
`presentation.jsonl` records background requests and camera-relative Object.data
poses before Transform/Render, not final raster calls. The timer passes 2,025
retained decisions, the earlier clock passes 36 samples, and District passes
120 draw lists. Packaged 70-tick original-case and 330-tick smoke checks pass.

Full-match RNG initialization/regeneration, all techniques/content, AI, menus,
saves, replays and networking remain open. The network manager is unregistered.
Physical keyboard, audible output, exact pixels/device timing, Windows, Intel,
automated resize/focus acceptance and a clean second Mac remain unverified.

See [Chidori compatibility study](../../docs/research/L2DF_CHIDORI_COMPATIBILITY.md),
[timer/camera integration](../../docs/research/L2DF_PRESENTATION.md),
[the full-game goal](../../docs/research/L2DF_FULL_GAME_GOAL.md),
[its evidence](../../docs/evidence/l2df-chidori-compatibility.json), and the
[earlier feasibility report](../../docs/research/L2DF_NATIVE_PROTOTYPE.md).
