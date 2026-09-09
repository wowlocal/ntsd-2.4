# Whole coordinate conversion and camera at startup precision

This follows [CONTROL_PRECISION](CONTROL_PRECISION.md). The native conversion
rules already reproduce the new original-instruction comparisons; no conversion
formula was changed. Whole camera/background control is now revalidated at53
bits. The remaining catalog-scanner context is distinguished explicitly below.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Pinned MSVCR80 SHA-256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Whole4450d0, two conversion paths

The original flag45971c selects the path. It lies outside the main game-global
record; both values remain explicit source/native caller inputs.

* Flag zero branches to445106. The helper rounds the retained x87 value to
  Int64, reloads that integer and applies its truncation correction. The
  low-zero/high-zero-or-indefinite shortcut at445165 precedes that correction.
  The returned EAX is the low32 bits, not a saturating Int32 conversion.
* Nonzero flag stores the retained value in binary64 at4450e2, then executes
  `cvttsd2si` at4450e5. The intermediate store is part of this path. The returned
  integer-indefinite bit pattern for the tested out-of-range values is80000000.

`oracle_coordinate_precision.py` executes the entire selected helper and its
actual return. It supplies unaligned caller SP24001003 and checks alignment
effects stay within the declared stack scratch, both outer canaries, return SP,
saved registers, unchanged CPU flag/control word, and the empty x87 tag/stack.
Each case explicitly writes nearest CW007f/027f/037f, FPSW0, empty tags and
MXCSR1f80. FPU/status observations are retained, but no native exception-status
or hardware trap claim is made. Actual Windows selection of45971c remains open.

Inputs reach the helper through original binary64 load, add/subtract/multiply/
divide and optional store/reload instructions. There are no injected opcodes,
host arithmetic results or changed EXE constants. A division denominator remains
below the result through the conversion and is discarded by actual419791 only
after the helper pops its own input. Seven original prefix instruction addresses
and all47 instructions in4450d0..4450eb /445106..44517a are reached. The adjacent
4450ec wrapper is outside this entry's scope. Instruction coverage does not
prove every possible branch outcome or caller state.

There are10,501 declared inputs ×3 precisions ×2 conversion paths =63,006 calls:

| Inputs | Calls |
| --- | ---: |
| Exact binary64 loads at signed zero/subnormal/integer/finite-range edges | 504 |
| Integer edges with a retained fractional remainder | 1,008 |
| Extended exponents and recovery through multiply/divide | 36 |
| Three hit-boundary expressions with the actual intervening store/reload | 18 |
| Seeded finite loads and add/subtract/multiply/divide prefixes | 61,440 |

Native builds the corresponding arithmetic value with the requested precision
and passes it directly to `OriginalCoordinateConversion`. It never substitutes
the source EAX as input. Load-only cases also compare the direct `Double`
overload, independently of the `OriginalExtended` overload.

| Comparison | Inputs with different returned EAX |
| --- | ---: |
| Legacy vs SSE2 at24 bits | 6,017 |
| Legacy vs SSE2 at53 bits | 6,022 |
| Legacy vs SSE2 at64 bits | 6,035 |
|53 vs64 bits, legacy | 41 |
|53 vs64 bits, SSE2 | 0 |

These counts describe this corpus only. For example, loading4294967295 at53
bits returnsffffffff (signed−1) through legacy, but80000000 through SSE2.
The three retained hit expressions reproduce the previously observed legacy
7fffffff→80000000 change from64 to53 bits. This remains an arithmetic-prefix
and whole-conversion check, not a second whole-hit or complete gameplay capture.
The earlier [whole hit branch witnesses](../evidence/hit-precision-branches.json)
provide that separate caller evidence.

## Whole camera and real background children

`oracle_world_precision.py camera` repeats all4,742 historical camera/background
inputs with explicit CW027f. All complete case records reproduce exactly:
400-slot World/pool bytes and masks, globals,101 background records/masks,
25,950 helper returns and6,898 ordered requests/reads. The1,133 observed PCs
also reproduce the old inventory. Actual background/drawing/clip/fill children
execute; metadata, COM replies and uninitialized fill-stack backing retain
their declared boundaries. This is not raster or real device output.

Remaining camera floating arithmetic uses Int32 bounds ±1/10/100/300, all exact
within53/64 significand bits; camera smoothing is integer arithmetic. Its direct
conversion consumers now have the dedicated checks above. This does not add
a24-bit whole-camera contract. The historical CW037f corpus remains unchanged.

## Catalog scanning uses a separate CPU

A fresh original initializer/early-menu execution followed by `MenuLoading`
attachment verifies a boundary that main-thread FPU checkpoints do not cover.
At41bc90, the main game CPU has CW023f. The attached settings CRT shares that
CPU. Catalog EXE code also shares it, but the catalog scanner does **not**:

`MenuLoading → InitialLoading → SoundCatalog → LoadedCatalog → Objects`
creates a new standalone `CRT()` in `Objects.__init__`. `Objects.imported`
routes non-decoder `fscanf` calls to that object's `crt.scan`, then copies its
returned output bytes into game memory. The new scanner reports unwritten
FPCW0. As [CONTROL_PRECISION](CONTROL_PRECISION.md) demonstrates, that reading
alone does not establish its effective arithmetic precision.

The [ownership probe](../evidence/catalog-scanner-fpu-boundary.json) executes
original initialization and early menus, then checks these actual CPU identities;
it stops before catalog execution. It proves the boundary, not a changed `%lf`
result. The initialized own chains still prove their complete game records
under the supplied scanner boundary. They do not establish53-bit numeric
parsing merely because the main EXE/attached-settings CPU has CW023f.

NEXT: execute the catalog's original DAT numeric scans at explicit53 bits and
compare their output bytes/consumption and the resulting independently loaded
native data. Retain the historical scanner results and distinguish this supplied
boundary from a future whole same-thread CRT integration. General `%lf`
lexing/rounding and Windows/thread/locale/file behavior remain open. Then resume
whole40d960 and the interleaved post-draw41f550..4214cf loop. The first tick,
finished match, app wiring, real Windows/device output and clean macOS remain
unverified; none is inferred from the new conversion or camera checks.

## Reproduction and acceptance

Generate the pinned historical camera corpus first, then:

```sh
uv run --script tools/oracle_coordinate_precision.py
uv run --script tools/oracle_world_precision.py camera
uv run --script tools/probe_catalog_scanner_context.py
python3 tools/accept_coordinate_precision.py
```

The ownership probe also requires the existing early-menu resource environment.
Acceptance validates source identities, counts, mode differences, complete old
camera records and historical fixture pins. It compares the two new corpora
natively before publishing lossless fixtures, refusing any changed overwrite
of an accepted resource. Reports: [conversion](../evidence/coordinate-precision.json),
[camera53](../evidence/world-camera53.json). The ownership report is explicitly
source-only and is not labeled native equivalence.

The first63,006-conversion comparison passed in0.398s (release build18.83s).
Combined acceptance passed both new tests in5.469s (build122.55s) before
publication. All152 historical fixture hashes remained unchanged; the two new
envelopes were independently unpacked and matched against their complete raw
captures, hashes and byte counts. The inventory is now154 fixtures.

The final packaged regression, without raw-corpus environment overrides,
passed all three tests in10.523s (build123.30s), including the retained64-bit
whole-camera corpus. Native numerical formulas and runtime code were unchanged.
NTSDNative compiled and linked; no app-window/device check is implied. Python
compilation, research links and diff checks passed. All source/probe and SwiftPM
processes were terminal before committing this milestone.
