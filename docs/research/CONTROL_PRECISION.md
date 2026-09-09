# Precision in whole Actor and World control

This follows [INITIALIZED_GAMEPLAY](INITIALIZED_GAMEPLAY.md). Actor control now
uses the explicit arithmetic context of its enclosing match. Its old host
binary64 arithmetic could not reproduce the original's separate arithmetic
rounding and binary64 store. All existing fixtures remain unchanged.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.

## Original operations and native change

The complete `413080..4143cb` contains these 13 arithmetic instructions:

| Mechanism | Original arithmetic PCs | Operands |
| --- | --- | --- |
| Ordinary walking | 413568, 4135d3, 4135ef | Actor vx / binary64 constant 1.4 at447a10 |
| Heavy walking | 41395e, 4139bd, 4139d7 | Same division |
| Ordinary running | 413bcd, 413bea | Actor vx / binary64 constant 1.2 at4479f8 |
| Dash from running | 413d3a | Sign-extended facing factor `(1-2*facing)` × Object+70 |
| Heavy running | 413e2f, 413e53 | Actor vx / binary64 1.2 |
| Airborne weapon attack | 414231 | Actor vy - 1 |
| Frame dvy | 414353 | Integer dvy + stored Actor vy |

Every arithmetic result is stored separately in binary64. `OriginalActorControl`
uses `OriginalExtended` for these operations at supplied24/53/64-bit precision;
`OriginalWorldControl` forwards `OriginalMatchPreparation.arithmeticPrecision`
through the live slot loop. Historical defaults remain64. No character or
scenario lookup is added. Direct finite loads, sign changes, comparisons and
Int32-to-binary64 loads remain exact and do not round to the precision control.

`41423e` can store infinity after arithmetic on finite inputs: subtracting1 from
the greatest finite binary64 value rounds beyond binary64 range at24 bits.
The same call can then reach `414353`, reload that infinity and add finite dvy.
That addition preserves signed infinity. The initial native comparison caught
an incorrect rejection at this continuation; it is now handled explicitly.
This does not establish arbitrary NaN operands, hardware exceptions or traps.

## Controlled original execution

`oracle_control_precision.py` executes original instructions with unchanged
EXE constants and real input/RNG/sound helpers. It checks helper ABI/returns,
Actor write masks, object immutability, full globals and event order. The
World controls additionally check the full400-slot pool and World masks.
Each new arithmetic call explicitly writes its declared FPCW and FPSW0; the
reported control word and empty x87 stack are checked on return.

| New corpus | Cases | Distinct observed PCs | Ordered events |
| --- | ---: | ---: | ---: |
| Actor controls at53 bits | 25,795 | 1,999 | 3,672 |
| All42 original type0 Objects, frame0 ×128 held inputs, at53 bits | 5,376 | 1,343 | 1,487 |
| Historical whole World controls at53 bits | 1,491 | 949 | 3 |
|9,236 arithmetic inputs ×24/53/64 bits | 27,708 | 851 | 648 |
|12 live aliased World arithmetic inputs ×24/53/64 bits | 36 | 445 | 0 |

The first three runs also re-execute all32,662 historical cases using fresh
CPUs and the original no-FPCW-write harness. Complete case data reproduces the
pinned historical captures. New explicit53-bit results are identical for those
inputs. The catalog run verifies original DAT/storage hashes; native rebuilds
the complete137-Object catalog before using its own42 type0 Objects.

The arithmetic corpus adds signed zero, binary64 subnormals, normal boundaries,
finite overflow, signed-byte facing factors, frame integer limits, subtraction
followed by store/reload/add, and4096 seeded finite operands for each walking
and running division. All13 arithmetic PCs execute. These are supplied caller
states, not naturally reached frames or all branch outcomes.

Compared with64-bit precision,24-bit results change8,762 Actor cases and53-bit
results change24. For example, a positive running speed whose binary64 bits
are `0000000000000003` divided by1.2 stores:

| Arithmetic | Result bits (big-endian notation) |
| --- | --- |
| Actual whole original control, CW027f /53 bits | 0000000000000002 |
| Actual whole original control, CW037f /64 bits | 0000000000000003 |
| Host binary64 division used by the former native implementation | 0000000000000003 |

At53 bits, arithmetic rounds in the extended exponent range before the
binary64 subnormal store rounds again. A direct host division gives a different
result. The24 differences are controlled tiny velocities, not evidence that
24 ordinary game frames were visibly wrong.

The World arithmetic corpus uses one allocation aliased by1/2/3 active slots
at0/1/399, signed activity values1/255/128, and both directions/signs. Each
visit consumes the previous visit's stored velocity and phase. All12 cases
change at53 vs64 bits. This tests context propagation and live alias order,
which the historical World controls alone did not discriminate.

## Unwritten FPCW is not an established arithmetic mode

A new five-run source witness exposes a Unicorn2.1.4 initialization distinction.
A fresh CPU reports FPCW0 without any write, but ordinary running6.4/1.2 returns
binary64 bits `4015555555555556`. Explicitly writing the same word0 instead
returns `4015555560000000`, matching explicit007f /24-bit precision.
Explicit027f and037f both produce the first result for this particular input.

Thus an unwritten reported word0 does **not** prove24-bit arithmetic in an old
harness. This witness does not distinguish the unwritten mode from53 vs64 on
all inputs. Historical game results remain reproduced, but their numerical
scope must be described by the actual execution setup, not the register value
alone. New captures always write the word or execute the real CRT initializer.

The older `oracle_fpu_precision.py` mode named `inherited-zero` actually writes
FPCW0 explicitly before the impulse call. Its retained numbers remain valid as
an explicit-zero control; they are not a measurement of an unwritten CPU's
effective arithmetic. The initialized own chains explicitly write037f and
execute actual445a31/CRT to023f, so they do not have this ambiguity. Actual
Windows FPU provenance is still unverified.

## Remaining numerical audit

The direct-operation inventory distinguishes these remaining consumers:

| Consumer | Current observation / remaining check |
| --- | --- |
| World physics respawn41eb8d..41ebe9 | Integer quotient plus bounded RNG minus26/16; all intermediates fit33 significant bits, so operations are exact at53/64. Whole53-bit physics was already compared. This is not a24-bit whole-physics guarantee. |
| World camera41b5d0 | Remaining floating arithmetic computes Int32 bounds ±1/10/100/300, exact at53/64; camera motion itself uses integer arithmetic. Direct conversions and fresh whole-camera53-bit controls still need an explicit audit. |
| Cpoint placement/throw, match creation/teleport | Int32 loads, binary64 copies, finite comparisons and sign changes; inspect alongside remaining conversion consumers. |
| Coordinate conversion4450d0 /445106 | Legacy consumes the extended value, SSE2 first stores binary64. Whole hits already cover discriminating53-bit branches; dedicated conversion boundary coverage remains open. |
| CRT `%lf` and OriginalFrameScanner | General decimal lexing/rounding still uses a declared boundary. Original source catalog/initialized own chains are compared; arbitrary decimal input remains unproved. |
| Earlier Practice (`OriginalFighter`, `OriginalMovement`, `OriginalMelee`, `OriginalProjectile`) | Retains older direct arithmetic and incomplete engine composition. It is not the new raw-state pipeline or proof of a faithful playable app. |

Continue conversion/remaining-consumer checks, then whole40d960 and the
interleaved41f550..4214cf slot loop. No first tick return, continuous match,
application integration, Windows/device output or clean macOS claim is added.

## Reproduction

Generate the historical Actor/World control and loaded-catalog captures first.
Then run source producers (independent source jobs may overlap; SwiftPM may not):

```sh
uv run --script tools/oracle_control_precision.py actor
uv run --script tools/oracle_control_precision.py catalog
uv run --script tools/oracle_control_precision.py world
uv run --script tools/oracle_control_precision.py edges
uv run --script tools/oracle_control_precision.py worldedges
python3 tools/accept_control_precision.py
```

Acceptance validates complete source identities, retained historical/catalog
pins, counts and precision differences; runs five native release comparisons;
only then publishes five lossless fixtures. Existing fixture overwrite with a
different hash is refused. Reports are separate from the historical studies:
[Actor53](../evidence/actor-control53.json),
[catalog53](../evidence/actor-control-catalog53.json),
[World53](../evidence/world-control53.json),
[Actor arithmetic](../evidence/actor-control-precision.json),
[live World arithmetic](../evidence/world-control-precision.json).

The initial combined regression passed the historical Actor/catalog/World
controls, rollback checks, new53-bit controls and both initialized own chains;
its one failure was the finite-to-infinite store/reload continuation described
above. After correcting that rule, acceptance passed all five new release
tests in30.785s (build122.61s), comparing all60,406 new cases before publication.
All147 historical fixture hashes stayed unchanged. Each of the five new
envelopes was independently unpacked and matched against its complete raw
capture, including raw/packed hashes and byte counts; the inventory is now152.
NTSDNative compiled and linked during the release builds. Python compilation
and diff checks passed. These checks do not constitute app/device execution.

The final packaged regression, with no raw-corpus environment override, passed
all12 release tests in89.060s (build123.96s): retained and new Actor/World control,
both rollback checks, and both initialized own continuations. Each own chain
again compared353,341 records /665,509,242 bytes with masks,499 helper returns,
53 state checkpoints and788 FPU checkpoints, ending at the same unreturned
41f550. All source-capture and SwiftPM processes were terminal before commit.

Follow-up: [COORDINATE_PRECISION](COORDINATE_PRECISION.md) now validates whole
conversion and camera53. It also identifies a separate catalog `CRT()` CPU:
initialized main-thread FPU checkpoints do not establish that scanner's mode.
Original DAT numeric scans at explicit53 bits are therefore the immediate
remaining check before expanding the full tick.
