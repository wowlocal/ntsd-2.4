# Initialized match through the complete post-draw loop

This study connects [the complete post-draw lifecycle](POSTDRAW_LIFECYCLE.md)
to the [initialized own match](INITIALIZED_GAMEPLAY.md), advancing the original
first tick from `41f550` to `4214d5` with SP `1000e9bc`. Both fresh source
captures match the independently rebuilt native chains. The full tick has
not returned and the Practice window remains a separate prototype.

## Provenance and comparison

`oracle_gameplay_lifecycle.py` starts with the actual `445a31`/MSVCR80 precision
initializer, then runs the historical World construction, early menus, complete
catalog/resource loading, selection, launch and gameplay prefixes on the same
CPU and stack. The entire accepted initialized parent, including its FPU audit
and storage blobs, must reproduce before the new instructions run. No new
gameplay stimuli, expected after-state, replacement Actor or reset RNG is
supplied at `41f550`.

The original loop runs through its final EDI advance to400, stopping before
`4214d5` resets EDI. All scheduler, constructor, RNG, sound and conversion
helpers execute original instructions; helper ABI and saved registers are
checked. Existing memory hooks retain defined-byte read checks, resource
ownership and full snapshots. Before/after snapshots include all World/Actor
and global bytes/masks, the 14,586 retained Frame allocations, backgrounds,
bitmaps, music, early allocations and the full recording buffer.

The FPU observer remains attached to the original EXE and DLL state-changing
instructions. New checkpoints cover loop heads and surround the scheduler.
The source separately reads and asserts equal entry/exit CW; the terminal
FPU hook follows the stopping gameplay hook and does not add a checkpoint.
The previous initialization, transitions and checkpoint prefix must be
unchanged. Native rebuilds the match through the public loaders and recovered
gameplay APIs at53-bit precision, then invokes `OriginalPostDrawLifecycle` on
that same native state. Expected source records are only comparisons.

The source additionally records reads/writes and before/after values for the
six retained caller words at SP+44/+50/+5c/+60/+6c/+70. The native comparison
requires that this particular first pass does not access them, and starts with
unknown `OriginalPostDrawScratch` fields. It does not import arbitrary original
stack bytes as native defaults. If a later pass consumes retained state, its
provenance must be implemented before extending this comparison.

## Verification

Both source captures reproduce their complete initialized parents. The new
stage makes four helper calls in return order: sound416fb0, scheduler40d960,
sound416fb0, scheduler40d960. The two catalog sound events are slot0/X442/index6
and slot1/X289/index6. No constructor or RNG call occurs. Both actors remain
on frame219 with HP500/MP200; previous frame becomes219 and wait becomes1.
The original RNG index/counter remain40/1. All six retained stack words remain
unchanged and have no source read/write accesses in this pass.

The inherited 788 FPU checkpoints are followed by 400 loop-head checks and
two scheduler entry/return pairs, for1,192 total. Scheduler entries retain
SP1000e9b0; loop heads and returns retain SP1000e9bc. Every word is023f,
the original startup transition remains the only observed control change,
and the explicit entry/exit assertion agrees. Both x87 stacks are empty.

The first native attempt caught an overly strict reference check requiring a
terminal FPU checkpoint. Hook ordering stops execution before that late hook;
the source had already read/asserted the final word separately. The reference
now checks the exact404 added instruction checkpoints and their stack positions,
plus the separate exit contract. Source data and native game rules were not
changed to resolve this observer-metadata distinction.

There are303 observed PCs:157 in the loop,90 in the scheduler,55 in sound,
and the unexecuted terminal boundary4214d5. Thus302 instruction addresses
actually execute. The standalone5,432-case lifecycle fixture remains a
separate controlled domain; its wider branch coverage is not attributed to
this first pass. These source runs use the inherited legacy conversion flag
and explicit initialized53-bit context, not a Windows hardware observation.

Acceptance passed seven release tests in86.894s after a132.28s build:
both new chains39.453s, both old initialized chains39.053s and the three
controlled lifecycle tests8.388s. Each new chain compares385,317 records and
700,844,396 bytes with masks,503 helper returns and55 state checkpoints,
plus1,192 FPU checkpoints. These totals include the existing launch/gameplay
reference stages; the nested parent results remain separately accounted for.
The old chains retain353,341 records/665,509,242 bytes/499 helpers/53 checkpoints.

Two lossless fixtures were published only after comparison. All160 old
fixture hashes remain unchanged. Reports pin the complete source and packed
identities: [primary](../evidence/gameplay-lifecycle.json) and
[control backing](../evidence/gameplay-lifecycle-control.json).
The primary raw/packed sizes are9,245,469/1,292,643 bytes; control sizes
are9,261,999/1,304,535 bytes. Both packaged comparisons passed without a raw
override in39.509s after a132.96s build. Complete JSON/length/SHA equality and
all2,758/2,759 embedded blobs were independently verified, together with all162
current fixture hashes. Local records are
`build/research/gameplay-lifecycle-fixture-pins.json` and
`build/research/gameplay-lifecycle-artifact-verification.json`.

The reference target first compiled in109.67s. The first test build133.92s
rejected the FPU checkpoint assumption described above before gameplay
comparison; the subsequent acceptance and packaged runs are the successful
whole-chain results. NTSDNative linked during verification; no app window or
device output was compared. Python compilation,591 local documentation links
and diff checks passed. Source and all SwiftPM processes were terminal before
the milestone commit.

```sh
uv run --script tools/oracle_gameplay_lifecycle.py
uv run --script tools/oracle_gameplay_lifecycle.py --control
python3 tools/accept_gameplay_lifecycle.py
swift test --package-path native -c release --filter OriginalGameplayLifecycleTests
```

Run SwiftPM sequentially. Acceptance verifies both complete original parent
identities, all embedded blobs and retained fixture hashes, runs the new and
existing native comparisons, and publishes only after success.

## Remaining work

The next original region is `4214d5..421a15`: requested item creation, resource
commands, healing timers and temporary-field cleanup. `402000..402011` calls
the existing control interface's method+1c when present. HUD is the separate
`41ae60..41b12d` function, returning4; the later `41b130`/`41b390` functions
and camera `41b5d0` are distinct. Diagnostics, result recording/UI and the
epilogue still follow. Static notes and instruction inventories for this queue
are in `build/research/postdraw-tail-notes.md` and
`build/research/postdraw-tail-static-plan.json`; they are not execution evidence.

The declared original initializer/outer ABI/FILE/COM/device boundaries remain
those of the parent. Catalog numeric scanning still has its separately audited
CRT CPU. This does not establish full Windows startup/thread or actual device
behavior. Natural techniques, a complete Naruto/Sasuke District match, app
integration, all game content and clean-macOS delivery remain open.
