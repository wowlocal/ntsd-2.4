# Original FPU initialization and the own gameplay chain

This follows [ARITHMETIC_PRECISION](ARITHMETIC_PRECISION.md). The original
precision initializer now executes before World construction on the same CPU
that continues through early menus, resource loading, character/match selection,
launch and the first gameplay passes. Independent native comparison starts its
match state with explicit 53-bit arithmetic. Historical fixtures remain intact.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
MSVCR80 SHA-256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Initialization boundary and observed control word

`oracle_initialized_gameplay.py` attaches the pinned CRT before the original
World constructor `419e40`. Its actual `_initptd` memory remains a supplied
boundary prepared by the established CRT harness. Original `445a31..445a59`
then executes on the game CPU, calling `_controlfp_s` through `445b16` and the
original IAT slot `4470f0`. The whole helper returns successfully after 170
distinct instruction addresses across EXE/DLL code.

The declared initial word is CW037f. Actual `fldcw` at `7814b118` changes it to
CW023f, selecting 53-bit precision. The initializer has a supplied caller at
stack `10006000`, returns to `30000000` with SP `10006004`, and leaves game
globals unchanged. The subsequent World caller supplies its own integer ABI;
the initialized FPU, actual CRT memory and initializer stack writes survive.
This is not execution of the complete PE entry, other startup initializers,
Windows thread creation or real graphics/audio drivers.

The observer watches 57 candidate FPU state-changing instructions in the pinned
DLL disassembly and verifies their bytes against the mapped image. Fresh
disassembly of both pinned images independently reproduced this inventory; none
of these instruction kinds occurs in the EXE text disassembly. Each candidate
records the control/status words before execution and at its next instruction.
The own chain records one control-word transition: the initializer's
`037f -> 023f`. No further watched instruction executes along the captured path.

There are 788 FPU checkpoints per chain, at 17 distinct source addresses. All
retain CW023f. They include World construction, early settings/menu, first
loading/catalog calls, later whole outer calls, match prelude/recording and
gameplay through `41f550`. The post-draw input and output status words are zero.
This does not establish a real Windows device boundary's effect on FPU state.

## Retained own execution and native state

All pre-existing source comparisons stay active. The initialized run must
reproduce the complete captured early/loading parents, startup, first mode and
whole return, repeated menu cycle, character selection, match selection,
launch, control, physics, links, contacts, hits, cpoints, camera and drawing
before continuing to post-draw text/impulses. Expected records are not copied
back into the source VM or native state.

The new final capture retains its own FPU audit and compares the complete old
post-draw game records/events separately from the now-different FPU metadata.
The game records reproduce exactly. The end is still the same unreturned
`4246b0` call at `41f550`, SP `1000e9bc`, phase 1/tick 1, mode 0. Naruto and
Sasuke remain registry ordinals 17/21 on District, frame 219, HP 500/MP 200,
RNG index 40/counter 1. This has not completed the first tick or a match.

`InitializedGameplayReference` checks the initializer identity, ordered control
transitions and checkpoint context, then invokes the existing complete native
composition. Explicit precision travels through the comparison callbacks into
`OriginalMatchPreparation` at its creation and remains checked in every
launch/gameplay snapshot. Native rules load original resources and produce
their own state; the FPU audit does not substitute game state.

The nested historical mode/return reference runners also retain their broader
control probes. Fresh initialized source execution establishes the own path
through those stages, not 53-bit source coverage of every extra historical
control probe. Keep that distinction when interpreting the nested counts.

Each native launch/gameplay composition compares 353,341 records and
665,509,242 bytes with masks, 499 helper returns and 53 state checkpoints.
Earlier startup/menu/selection comparisons are also rerun by nested runners;
their counters are not included in those launch/gameplay totals. The FPU audit
adds its separate 788 checkpoints and one transition per chain.

## Complete World handlers at explicit 53-bit precision

`oracle_world_precision.py` repeats the original declared controls while
changing only the arithmetic control word to CW027f. Scenario inputs are
checked against the pinned historical corpus; no expected fixture is rewritten.
The source helpers retain their original constructor, RNG, sound, CRT and
conversion boundaries. Native comparisons check full pool/masks/globals and
ordered requests; the hit pass also checks its mutable Frame heap and CRT state.

| Handler | Cases | Helper returns | Events | Cases changed from CW037f |
| --- | ---: | ---: | ---: | ---: |
| Whole World physics `41e634..41eed1` | 515 | 8,329 | 136 | 0 |
| Whole depth/held-object pass `417f80..4187a3` | 3,018 | 6,922 | 3,878 | 0 |
| Whole hit resolution `42e100..431b64`, including 150 caller cases | 7,845 | 19,211 | 16,750 | 3 |

All 11,378 new cases match native. The three changed hit cases are existing
`extended` controls with defender integer y=2147483647, incoming pending y of
`-2^63`, `-1e-9` or `-3e-10`, dvy=1 and the legacy conversion path. Original
`42f1c2..42f1dd` adds/stores the impulse and adds integer y; `42f1e0` calls
`4450d0`. The signed test at `42f1e7` then decides whether `42f1f6` overwrites
Actor+0x30 with 12. In all three controls the conversion return changes from
`0x7fffffff` to `0x80000000`, which changes that signed branch. Under the
historical word it writes 12 in all three controls;
under 53-bit precision that overwrite is skipped. The discrepancy therefore
affects a gameplay branch, not just low stored mantissa bits. Native follows
the new original results without a scenario exception or tolerance.
The separate [six source branch witnesses](../evidence/hit-precision-branches.json)
record the actual conversion return and presence/absence of the overwrite PC,
while reproducing each complete controlled case under both words.

Reports:
[own chain](../evidence/initialized-gameplay.json),
[control backing](../evidence/initialized-gameplay-control.json),
[World physics](../evidence/world-physics53.json),
[World links](../evidence/world-links53.json),
[World hits](../evidence/world-hits53.json).

## Reproduction and remaining work

First generate/accept the historical parents described in the linked studies.
Then run:

```sh
uv run --script tools/oracle_initialized_gameplay.py
uv run --script tools/oracle_initialized_gameplay.py --control
uv run --script tools/oracle_world_precision.py physics
uv run --script tools/oracle_world_precision.py links
uv run --script tools/oracle_world_precision.py hits
uv run --script tools/oracle_world_precision.py hits --witnesses
python3 tools/accept_initialized_gameplay.py
```

Acceptance checks the complete raw/packed identities, old fixture pins, FPU
audit and retained final game records, then runs both native chains and three
new World comparisons before publishing any fixture.

Verification before publication: the retained own-chain regression passed two
release tests in 40.196s (build 79.35s); the World suites passed eight tests,
covering both old/new precision and rollback, in 20.009s (build 19.10s). The first
new initialized native chain passed in 19.614s (build 0.20s). Both own prefixes
were then reconstructed with fresh disassembly; their 57 watched instructions,
170 initializer PCs, transition and first four FPU checkpoints reproduced the
full-capture audit exactly. NTSDNative compiled and linked during the builds.

The combined acceptance passed all five release tests in 48.763s (build 123.45s)
before publishing the five new fixtures. All 142 historical fixture hashes
remained unchanged. Each new packed envelope and every embedded blob was
independently checked against the complete raw source data; there are now 147
fixtures. The same five tests then passed from packaged resources with no raw
environment override in 48.507s. Python compilation and staged diff checks
passed; all source and SwiftPM processes were terminal before the milestone
commit. This does not add Windows/device or app-window verification.

The following [CONTROL_PRECISION](CONTROL_PRECISION.md) now corrects ActorControl
and World context transfer, with whole53-bit and24/53/64-bit comparisons. Its
remaining inventory includes direct conversion, camera and CRT numeric parsing.
The initialized chain's explicit037f/actualCRT setup avoids the newly observed
ambiguity of an unwritten harness FPCW0. Native application wiring and the
complete post-draw loop `41f550..4214cf` remain unfinished. Actual Windows
startup/thread/device behavior, continuous DAT gameplay, a finished first
match, all game modes and clean macOS verification remain open.
