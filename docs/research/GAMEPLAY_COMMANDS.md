# Initialized match through resource commands

Both fresh initialized source chains and independently rebuilt native matches
now agree through 421a15/SP1000e9bc, immediately before the HUD caller. Each
comparison covers 417,293 records,736,179,550 bytes with masks,503 helpers and
57 state checkpoints;1,593 FPU checkpoints retain startup 53-bit precision.

This stage continues the two [initialized lifecycle](GAMEPLAY_LIFECYCLE.md)
chains from 4214d5 to 421a15/SP1000e9bc. The original CPU, stack, allocations,
menu/loading/selection state and FPU context survive the entire continuation.
The new native consumer uses the public `OriginalPostDrawCommands` API on its
independently rebuilt match state. Expected snapshots and arbitrary original
stack bytes are never supplied as native inputs.

The wider [controlled command study](POSTDRAW_COMMANDS.md) remains separate:
its 3,898 cases cover item requests, resource commands, healing, aliases, full
pools and overflow. The natural first own tick supplies no new command input.
This stage must establish its actual resource/cleanup behavior without changing
flags or injecting controlled cases into the initialized match.

## Source and comparison contract

`tools/oracle_gameplay_commands.py` starts fresh from actual 445a31/CRT before
World construction, using the inherited declared outer/platform boundaries.
It first requires complete equality with the pinned gameplay-lifecycle parent,
including the whole accumulated FPU audit. Only then does it resume 4214d5;
it stops before 421a15, before the HUD argument load or flag reset.

No new device response is supplied. Unexpected COM paths fail an instruction
guard rather than receiving invented output. The existing catalog scanner is
still a separate CRT CPU; this continuation does not change that established
boundary or constitute an actual Windows launch.

Before/after snapshots retain all 400 physical Actors and World, globals, all
14,586 Frame allocations,854 bitmaps,101 Background slots, music, retained menu
allocations and the full recording storage. Native reconstruction follows all
previous public APIs in order and compares complete bytes and defined masks
at each new boundary. Parent transport hashes and every compressed blob are
verified before publication.

The source additionally watches accesses to retained caller SP+34. If the own
path never accesses it, native keeps `retainedSpawnSlot` unknown. Any future
path that consumes it requires actual earlier write provenance; neither the
source backing word nor a convenient free-slot default is a substitute.

The verified FPU observer extension is the resumed4214d5 plus 400 visits to
4217b0. Existing initialization/transitions/watched instructions and all 1,192
parent checkpoints must remain identical. Equal entry/exit CW is explicitly
read and asserted separately from the instruction checkpoints. This is a
check of the declared source context, not hardware timing or Windows evidence.

## Observed own path

Both original continuations execute 49 instructions; the 50th observed PC is
421a15, where the hook stops before execution. Each has 401 new FPU checkpoints
(the resumed4214d5 and 400 loop heads), bringing the total to 1,593. Every
checkpoint retains CW023f; FPSW remains4000 and the x87 tag word ffff.

The entire before/after state is identical, including all resource records
and masks. This first tick has both command flags 0, both healing timers 0,
full HP500 and MP200. Cleanup rewrites the already-present values 1000 for
+2e8/2ec/2f0 and 0 for+2e4/byteEB. There are no helper calls or new events.
Naruto/Sasuke catalog ordinals 17/21 retain current and previous frame 219,
wait 1, mode 0, tick 1, District and RNG index40/counter 1.

CallerSP+34 remains3724541916 and has no reads or writes in the new stage.
That arbitrary word is not a valid slot index and is not imported into native
state; the public API receives nil. Full-pool/item requests remain covered by
the separate controlled study and still require actual retained-slot provenance.

The raw captures contain 9,249,671 and 9,265,981 bytes, respectively, with 2,756
and 2,757 independently hashed blobs. No parent fixture is rewritten.

## Reproduction and remaining work

```sh
uv run --script tools/oracle_gameplay_commands.py
uv run --script tools/oracle_gameplay_commands.py --control
python3 tools/accept_gameplay_commands.py
swift test --package-path native -c release --filter OriginalGameplayCommandsTests
```

Run SwiftPM sequentially. Both raw own comparisons passed in 39.539s after
a 134.80s build, before publishing their fixtures. Both retained lifecycle
comparisons passed again in 40.448s (build0.10s) after the reference API
extension. Both final packaged tests passed in 39.598s after a 135.22s build,
without a raw-corpus override. All source and SwiftPM jobs were terminal
before the milestone commit.

[Primary evidence](../evidence/gameplay-commands.json) and
[control evidence](../evidence/gameplay-commands-control.json) pin the raw and
packed artifacts. Packed sizes are1,278,615 and 1,289,911 bytes. Independent
inflation checks full bytes/JSON, lengths, SHA256 and all 2,756/2,757 blobs.
All 162 previously accepted fixtures remain unchanged; all 165 current pins
include the new controlled corpus and both own captures. Local audits are
build/research/gameplay-commands-fixture-pins.json,
gameplay-commands-artifact-verification.json and gameplay-commands-state-audit.json.
Source jobs are terminal. The release tests linked NTSDNative, but did not
open or validate a native app window.

Next recover the HUD caller and whole 41ae60..41b12d/ret4. Static disassembly
shows its stack argument is popped but never read: rendering usesglobal 455608.
The eight cells prefer slots0..<8 and otherwise10..<18, and bars use wrapped
integer 31*HP/125 widths. These are static seeds, not new HUD execution proof;
see build/research/hud-static-plan.md. Clear 450bc0/450bb8 at 421a1c/421a22 before
calling the HUD, then continue421a2d..422994 diagnostics/results/epilogue.

The first full tick, native window integration, a complete Naruto/Sasuke
District match, all remaining content/modes/network/replays, Windows/device
comparison and clean-macOS delivery remain open.
