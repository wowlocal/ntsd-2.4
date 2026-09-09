# Native arithmetic with explicit x87 precision

This is the first correction following [FPU_PRECISION](FPU_PRECISION.md).
Original startup selects a 53-bit significand. Native finite arithmetic now
supports 24/53/64 bits, with the original extended exponent range retained across
intermediate operations. Historical fixtures remain unchanged. This study does
not yet provide an initialized own menu/loading/match chain or Windows evidence.

Follow-up: [INITIALIZED_GAMEPLAY](INITIALIZED_GAMEPLAY.md) now adds the initialized
own chain and controlled53-bit World physics/links/hits. The scope below records
this earlier arithmetic milestone; remaining direct arithmetic and Windows
startup/thread/device evidence are still open.

Baseline EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.

## Native change

`OriginalArithmeticPrecision` decodes the precision bits of a supplied control
word. Only round-to-nearest is supported; reserved precision and other rounding
modes throw. This is an explicit arithmetic context, not an emulated CPU or a
process-wide FPU setting. Exception masks, flags and traps are not modeled.

`OriginalExtended` loads a finite binary64 value exactly, rounds each arithmetic
operation to the selected significand precision, and rounds binary64 stores
separately. Loads must not round to 24 bits. Adding zero still performs arithmetic
rounding. Multiplication keeps the full product before rounding; division rounds
directly from quotient and exact remainder, without an intermediate 64-bit round.
Sign, subnormal binary64 inputs/stores and signed zero are retained. Intermediate
values can exceed binary64's exponent range. Overflow of the 80-bit exponent
format and nonfinite operands remain outside this finite arithmetic type.

The context is carried by `OriginalMatchPreparation` to World physics, hits,
links and impulses; Actor physics also accepts it directly. Defaults remain
64-bit for compatibility with historical declared controls. New 53-bit physics
and impulse comparisons select their context explicitly. Passing a context to
hits/links does not establish their 53-bit equivalence: that revalidation remains
open. Existing own chains still retain their historical harness and native
contracts; the source harness inherited CW0, as the preceding audit records.

## Original-instruction comparisons

`oracle_arithmetic_precision.py` executes actual instructions from the pristine
EXE at supplied phase boundaries, with declared registers and operand backing:

| Operation | Original address |
| --- | --- |
| Load binary64 | 40e51d |
| Add | 40e520 |
| Subtract | 4307be |
| Multiply | 40e556 |
| Divide ST0 by ST1 | 408425 |
| Store binary64 | 40e523 |
| Discard retained denominator | 419791 |

No synthetic opcode or changed EXE constant is used. Each step checks the next
PC; each case checks control word and empty x87 stack. The 54,201 cases cover
masked CW 007f/027f/037f, edge operands, exact loads, seeded finite operands,
multi-operation sequences, extended-range overflow/underflow witnesses and the
startup audit's midpoint witness. Native final binary64 bits match exactly.
These are arithmetic sequences with supplied boundaries, not whole game calls.

Two additional producers execute whole original gameplay helpers:

| Corpus | Explicit precision | Cases | Results changed from historical 64 |
| --- | --- | ---: | ---: |
| Actor physics controls, whole 40e490 | 53 | 9,344 | 168 |
| Actor physics, every present source Frame ×3 motion inputs | 53 | 46,089 | 0 |
| Whole 4196f0 impulse pools | 24 | 1,030 | 518 |
| Whole 4196f0 impulse pools | 53 | 1,030 | 22 |
| Whole 4196f0 impulse pools | 64 | 1,030 | 0 |

Physics retains every historical scenario input and changes only FPU precision.
All 137 source Objects and 15,363 present Frames are covered by the catalog
survey's three declared motion inputs; this is not natural frame reachability or
all possible physics state. Native independently rebuilds and validates the
pinned complete catalog. Whole Actor bytes/masks, globals and sound events match.

Impulse cases retain all 400 slots, aliases and ordered writes. Across three
modes, 28,155 ordered writes and full pool/mask/global hashes match native. The
64-bit source slice reproduces the entire accepted historical case data exactly.
This retains the older helper's nonfinite/zero-divisor value handling; it does
not extend the finite arithmetic type to general nonfinite calculations or prove
hardware exception behavior.

Machine-readable reports:
[arithmetic](../evidence/arithmetic-precision.json),
[impulses](../evidence/impulse-precision.json),
[physics controls](../evidence/actor-physics53.json),
[physics catalog](../evidence/actor-physics53-catalog.json).

## Reproduction and acceptance

Generate the historical physics/catalog/impulse corpora first as described in
their studies. Then run these source tools (SwiftPM must remain sequential):

```sh
uv run --script tools/oracle_arithmetic_precision.py
uv run --script tools/oracle_impulse_precision.py
uv run --script tools/oracle_physics_precision.py
uv run --script tools/oracle_physics_precision.py --catalog
python3 tools/accept_arithmetic_precision.py
```

Acceptance verifies raw hashes/counts, source identities and historical/catalog
fixture pins; runs the native release comparisons before any resource write;
then publishes four lossless fixtures with packed hashes and byte counts. It
refuses to rewrite a previously accepted fixture with different content.

The initial release regression passed 16 XCTest in 108.061s (build 120.24s),
covering the new arithmetic/physics/impulse cases and retained Actor hits,
World links/physics and both own GameplayImpulses chains. Acceptance then
passed the five new checks in 31.243s (build 122.06s) before publication.
All 138 historical fixture hashes remained unchanged; the four new envelopes
were independently unpacked and matched the complete raw captures. Python
compilation and diff checks passed. NTSDNative compiled and linked during the
release builds; this is not an app-window or device verification.
The final five tests also passed using the packaged fixtures, with no raw-data
environment override:31.338s, build123.11s. All source-capture and SwiftPM
processes were terminal before committing this milestone. The fixture inventory
now has142 entries; the previous138 pins are retained independently.

## Still required before expanding the tick

1. Execute original 445a31 and the actual CRT on the same CPU as a fresh own
   menu/loading/match chain. Retain a new explicit lineage instead of rewriting
   old parent snapshots. Recover earlier startup, thread and device boundaries.
2. Revalidate hits, links and whole World physics at the recovered precision.
   Audit direct floating operations and legacy/SSE2 conversions as well as CRT
   numeric parsing. In particular ActorControl still contains direct binary64
   arithmetic and has no explicit precision context.
3. Confirm the actual Windows game thread's control word and results. Leaf
   comparisons alone cannot establish the lifetime of that thread's FPU state.

Native app integration, device timing/output, complete tick return, a finished
Naruto/Sasuke District match, full game scope and clean macOS remain open.
