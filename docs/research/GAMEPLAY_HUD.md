# Initialized match through the complete HUD

Both fresh original startup chains now agree with independently reconstructed
native state through421a2d/SP1000e9bc. Each native comparison checks449,269
records,771,514,704 bytes with masks and59 state checkpoints. The primary chain
has536 helper returns; the control chain544. All1,603 FPU observations preserve
the original startup53-bit precision.

This continues [GAMEPLAY_COMMANDS](GAMEPLAY_COMMANDS.md) on the same original
CPU, stack, catalog, allocations and retained menu/gameplay state. The native
consumer invokes the public `OriginalWorldHUD` API after the full existing
command pass. It is a continuous research chain through one unreturned tick,
not yet the native app's full tick or an actual Windows launch.

## Provenance and boundary

`tools/oracle_gameplay_hud.py` starts with actual445a31/CRT and reproduces each
entire pinned command parent before resuming421a15. Parent fixture hashes,
state, complete accumulated FPU initialization/transitions/checkpoints and
watched instructions must match. No Actor input, state or expected after-value
is injected to obtain a convenient HUD path.

The whole HUD41ae60 and its real43f010/43ef70/43f310 children execute through
421a2d. Inherited COM Blt has declared alternating results0/1. It is a device
response boundary, not DirectDraw execution or a pixel comparison. All earlier
platform and separate catalog-CRT boundaries remain explicit and unchanged.

The source retains complete before/after World/400Actor state and masks,
globals, all14,586 Frame allocations,854 source bitmap records,101 Background
slots, music, recording storage and live/retained menu allocations. Both own
before-states equal the preceding command after-states exactly. The entire
HUD before/after state is identical in this first tick: command flags were
already0, and drawing does not change these records.

Native reconstructs those resources through its own previous public APIs.
It resolves catalog, interface and retained early-menu bitmap ownership from
that state; source surface identities are checked against the declared bindings.
Expected snapshots only compare outputs. The render target comes from native
global455608, not the source's retained stack argument. Source and native
catalog bitmap ordinals are mapped through actual retained ownership.

CallerSP+68 holds28002020 in both captures. Its full trace is a read at421a15,
then a push write at421a19/SP−4;41ae60 never reads that argument. It happens to
equal targetglobal455608 here, so the independent variations in
[WORLD_HUD](WORLD_HUD.md) are necessary to establish the distinction.

## Observed rendering and undefined metadata

Both paths select Naruto/Sasuke catalog ordinals17/21 in cells0/1. Each draws
all eight interface cells, two portraits and two team marks. HP500 gives width124
for both HP rows; MP200 gives width49 over backdrop124. Timers are0, so no
healing overlay is drawn. There are eight rectangle calls and12 bitmap calls.
No other Actor participates in this own first-tick HUD.

| New HUD observation | Primary | Control backing |
| --- | ---: | ---: |
| Draw events |12|12|
| Rectangle events |8|8|
| Metadata read events |72|112|
| Clip events |12|20|
| Blt events |20|28|
| All ordered events |124|180|
| Helper returns |33|41|
| Executed original instruction starts |419|424|
| Undefined bitmap read events |20|52|

The source's observed-PC inventories contain two additional boundaries:
PAPI30009000 is a host COM response and421a2d is stopped before execution.
Both execute177/223 HUD instructions; controlled coverage of the remaining
instruction starts belongs to the separate whole-HUD study. Clipping executes
27/57 or32/57 starts; bitmap171/214 and rectangle38/38 are the same in both.

The early interface wrapper's count+0c was not initialized. Primary backing
containsa5a5a5a5; control backing contains0f0e0d0c. The latter permits the
picture−1 fallthrough in43f010 and eight additional clipped Blt requests.
Control also reads backing metadata at+fac/+7dc/+177c, with valuesafaeadac,
dfdedddc and7f7e7d7c respectively. Native preserves bytes and defined masks,
including thea5a5a5a5 count of the separate team bitmap; it does not replace
these fields with0 or a guessed count.

The source state-access inventory reports two bitmap read sites,43f04b and
43f183, both at+0c. The separate ordered renderer observer also captures the
pre-array metadata reads and their masks. The two inventories measure different
things and must not be treated as interchangeable coverage. These are declared
research backing values; their actual Windows allocation provenance and visible
pixel consequences remain open.

## FPU and acceptance

Ten new checkpoints comprise resumed421a15 atSP1000e9bc,41ae60 entry at
SP1000e9b4 and eight loop heads41ae70 atSP1000e99c. All1,593 parent checkpoints
remain identical, as do initialization and transitions. New entry/exitCW023f,
FPSW4000 and tagffff are explicitly checked; no floating-point transition is
introduced by HUD.

Raw captures are9,283,133 and9,309,179 bytes, with2,756/2,757 independently
hashed blobs. [Primary evidence](../evidence/gameplay-hud.json) and
[control evidence](../evidence/gameplay-hud-control.json) pin full raw and
packed artifacts and distinguish original PCs from external/terminal boundaries.

```sh
uv run --script tools/oracle_gameplay_hud.py
uv run --script tools/oracle_gameplay_hud.py --control
python3 tools/accept_gameplay_hud.py
swift test --package-path native -c release --filter OriginalGameplayHUDTests
```

SwiftPM must run sequentially. Source/native comparisons use raw new captures
and retained packaged parents; acceptance publishes only after full comparison.
Final packaged verification uses no raw override. All prior fixture hashes must
remain unchanged, and all transport blobs must independently inflate to their
pinned lengths and SHA256.

Both initial raw comparisons passed in39.921s (build0.21s); acceptance passed
again in39.692s (build0.21s) before publishing the two fixtures. The combined
packaged run passed five tests in46.123s after a137.47s build; the own-chain
portion took39.731s, without raw-corpus overrides. The earlier controlled-HUD
acceptance also rechecked both retained command chains in39.493s. Native game
rules and expected states required no adjustment during these comparisons.

Packed sizes are1,282,079 and1,293,927 bytes. Independent byte/JSON/SHA/length
and2,756/2,757-blob checks passed; all165 old fixture hashes remain unchanged
among168 current pins. See build/research/hud-artifact-verification.json and
gameplay-hud-fixture-pins.json. Source/SwiftPM jobs were terminal before the
milestone commit. The release build linked NTSDNative; no new native-window,
pixel/device-output or Windows claim follows.

Next follow [TICK_TAIL_PLAN](TICK_TAIL_PLAN.md) through diagnostics/results,
mode labels, presentation, sound and the actual422ab8/ret4 while preserving the
caller registers, stack, resource ownership and startup numeric context. The
first full tick, native window integration, complete Naruto/Sasuke District
match, other content/modes/AI/network/replays, real Windows/device comparison
and clean-macOS delivery remain open.
