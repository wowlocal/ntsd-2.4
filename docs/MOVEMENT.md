# First native movement slice

Baseline: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe`.
SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.

The `--movement` native application mode contains a controllable, unarmed Naruto on
District: standing, walking, turning, double-tap running, stopping, jumping,
running jumps/dashes, turning in flight and landing. This is a movement practice
slice, not a complete match. No behavior comes from the discarded JS project,
F.LF, another engine or SpriteKit physics.

## Evidence and execution boundary

`tools/oracle_movement.py` loads the original PE and executes its instructions:

| Routine | Original address | Boundary |
| --- | --- | --- |
| Actor constructor | `0x4061d0` | Original instructions; CRT memset replaced by zero fill |
| Normalized input reader | `0x4198f0` | Original replay bit layout, one enabled slot |
| Input/control | `0x413080` | Entire original routine, arrows/jump only |
| Physics | `0x40e490` | Entire original routine, type 0/id 2, unarmed, no hitstop |
| Arena bounds and camera | `0x41b5d0` to `0x41bc74` | All bounds and camera instructions, stop before drawing |
| Frame scheduler | `0x40d960` | Entire original routine |

The main-loop call sites establish the sequence: control `0x41e35f`, physics
`0x41e652`, initial Z bounds `0x41eed3`, collision collection `0x41eef6`, hit
resolution `0x41ef42`, bounds/camera/background `0x41f491`, actor drawing
`0x41f4a7`, then frame scheduling `0x41fb06`. Collision/hit routines have no targets
in the tested domain (these movement frames have no itr records). The harness
executes the final bounds pass and does not simulate enemies, pickups, stage
scripts, AI, HP/MP recovery, object spawning or the surrounding match lifecycle.
These call-site/branch observations are static evidence, not a full-loop capture.

Frame records are constructed and parsed by the original instructions through
`OriginalFrames`; its `fscanf`, `sprintf`, `malloc` boundary is described in
[FRAME_LOADER.md](FRAME_LOADER.md). Only Naruto frames 0–3, 5–11 and 210–219 are
loaded, in source order. The same sections pass through the native recovered
loader. All are inside its supported domain. Raw DAT motion parameter strings
are converted to binary64 and supplied at the header offsets observed in
`0x40f799–0x40fa5a`; the actual MSVCR80 `%lf` header loader is not executed.

The actor constructor initializes velocity to 0.1. Practice explicitly starts at
`x=480, y=0, z=490` with zero velocities, a neutral frame and clear inputs/counters.
This is a controlled initial condition shared by both implementations, **not** a
claim to reproduce match spawn selection/RNG. Edge fixtures vary initial x/z.
The original normalized reader uses a replay slot; the bounds/camera pass uses
one living local-player slot to select the original local camera look-ahead.

Original sound entry points `0x416fb0` and `0x417090` are intercepted at the audio
boundary. The test records source paths/built-in IDs in call order; it does not
emulate DirectSound. Built-in sound 7 is `data/017.wav`, loaded at
`0x41bf31–0x41bf3b` from the string at `0x449518`. The app plays the original WAVs
through AVFoundation. Original stereo gain/pan, sound aggregation, output-device
latency and WMA music are not yet reproduced or differentially verified.

## Verified results

`uv run tools/oracle_movement.py` generates the reference first, then builds and
runs the independent Swift checker. It exits unsuccessfully on a mismatch and
refreshes fixtures/evidence only after the comparison succeeds.

- **8,506 ticks in 58 sequences**: idle, held directions, diagonals, opposing
  directions, double taps with 0–11 release ticks in both directions, expired
  taps, turning, stopping, stationary/directional jumps, held jump, dashes,
  turning during dashes, repeated jump taps and all four arena edges.
- Eight deterministic varied-input sequences extend the comparison. Their
  Python RNG generates test stimulus only; it is not used as native game RNG.
- Every tick compares integer and floating coordinates, velocities, animation
  phase, signed double-tap counter, frame/previous frame/wait, facing, the five
  input buffers, camera position/velocity, pre-scheduler render frame/facing,
  and sound calls. Numerical equality is exact, with no epsilon tolerance.
- **3,770 ticks in 50 sequences** are checked in for ordinary offline XCTest.
  The complete regenerated corpus lives under `build/original/`.
- [Machine-readable evidence](evidence/movement-oracle.json) includes input
  version, addresses and fixture hashes.

`tools/oracle_presentation.py` separately executes the normal timer branch
`0x43d157–0x43d1df` with a deterministic `timeGetTime` return value and a counting
callback replacing game dispatch. **36 samples** cover the strict 33 ms boundary,
100 ms lag cap, catch-up and UInt32 rollover. Repeated Windows loop iterations
with the same supplied time are compared with one native catch-up batch.

The same tool supplies District's numerical layer headers at the original
loader's offsets and executes the entire background routine `0x41a250`. Only the
bitmap draw boundary at `0x43f010` is intercepted. **120 complete draw lists**
compare layer identity/order, integer x/y and transparency, covering both NPC
animation loops and varying camera positions. Original cc is the divisor, not
cc + 1; c1/c2 are inclusive. This verifies drawing decisions, not DirectDraw pixel
output or the original background header parser.

## Rules useful for the next milestone

- Timer: strict `elapsed > 33`, baseline advances by 33; lag greater than 100
  resets baseline to `now - 100`. This is not an assumed 30 Hz simulation.
- Input buffers: decay before edge capture, rising edge writes 5 (`0x413080`).
  AppKit OS auto-repeat does not create new edges; the original tests held state.
- Walking uses a separate phase modulo `walking_frame_rate * 6`: frames
  5, 6, 7, 8, 7, 6. Running uses modulo `running_frame_rate * 4`: 9, 10, 11, 10.
- The signed double-tap counter decays only inside standing/walking control.
  Rising right/left adds/subtracts 10; the threshold is +11/-11. Turning clears it.
  Running continues after release and starts its control block in the same tick
  in which a double tap selected frame 9.
- Diagonal walking divides x speed by binary64 1.4; running divides it by 1.2.
- Physics integrates x/z before ground friction. Airborne y integrates before
  the 1.7 gravity increment. Integer coordinates truncate toward zero.
- Jump velocity is assigned on transition into frame 212, after that tick's
  physics. Naruto's source jump-height literal is **-16.299999**, not -16.3.
- Rendering precedes frame scheduling. `renderFrame`/`renderFacing` preserve
  that distinction; displaying the post-scheduler frame is one tick premature.
- Bounds clamp position without clearing velocity. Camera uses the original
  794-pixel viewport, ±130 look-ahead and integer smoothing (`0x41b910–0x41bc74`).
- Native sprite placement follows `0x40dffc–0x40e0b5`: source centerx/centery,
  mirrored cell width, integer x/y/z. Shadow offsets use integer halves of
  shadowsize (`0x41a72f–0x41a767`); the shadow does not shrink during a jump.
  These placement rules are statically recovered and visually checked on macOS;
  exact raster/color equivalence with Windows remains unverified.

## Native host behavior and remaining work

AppKit supplies held physical keys (arrows/WASD, Space). SpriteKit supplies only
nearest-filtered bitmap presentation. The normal clock decides simulation ticks;
display refresh never multiplies movement speed. Esc pauses, R resets practice,
M mutes. Losing window focus clears held input and pauses; refocusing resets the
host clock so time spent away is not simulated. A manual pause remains paused
when focus returns. These are native host controls, not recovered Windows menu
or focus semantics.

UI verification on macOS included walking, a jump captured in flight with the
shadow at ground depth, reset and pause/resume. Focus loss is handled by
NSWindowDelegate; an automated held-key focus-loss trace has not been captured. The complete
original game has not run on Windows in this session; no claim of full-match,
end-to-end keyboard latency, audio-mix or pixel equivalence follows from these
isolated tests. Intel and a clean second Mac have not been tested.

The following milestone is now implemented as the default Naruto/Sasuke melee
practice. See [COMBAT.md](COMBAT.md) for the recovered attack/defend transitions,
collision/hit resolution, damage, falling and voice-object comparison. The
movement-only reference and this scene remain available for regression checks.
