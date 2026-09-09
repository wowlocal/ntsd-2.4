# Original diagnostic number formatting

The diagnostic caller at421a60 uses `%2.3f %2.4f %d`. Its two fixed decimal
conversions require the original VC80 behavior before the whole caller can be
ported. `OriginalDiagnosticNumber` implements those numeric conversions from
binary64 bits with integer arithmetic; it does not use host printf or load a
DLL in the native runtime.

The source is the pinned MSVCR80.6195 DLL, SHA256
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`,
extracted from the original redistributable. The original game EXE is SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
These are distinct from the native host's formatting library.

## Recovered algorithm

The real sprintf entry7817775d dispatches fixed conversions via78149d53 and
78149b87. It calls78149e94, which converts the binary64 representation through
78149dd9 into a64-bit explicit significand and15-bit exponent (LD10). This is
an integer representation conversion; it preserves signed zero and the NaN
payload distinction without a floating-point load.

$I10_OUTPUT at78149f23 estimates a decimal scale using the original integer
constants, then multiplies by selected powers from781c1ff0/781c2150. The two
sets contain twelve-byte records: an80-bit significand and exponent. The native
constants are byte-for-byte copies of the first21 records in each source table;
three base8 exponent groups suffice for binary64. This is504 bytes with SHA256
`13175ac4fec5e3602495c2164b80050d181c3d0f9b948e48dd524f367b8d5508`.
Acceptance verifies each constant directly against the pinned DLL bytes.

Preserve the original multiplication algorithm. It accumulates only the upper
five convolution diagonals of16-bit words into96 bits, normalizes the result
and rounds the low16 guard bits to an80-bit significand using ties-to-even.
It does not propagate contributions from omitted lower products. Certain table
entries first decrement only the32-bit word at+2, without propagating a borrow
to other words. Replacing this with a mathematically exact big-number product
would be a different algorithm.

After scaling into the required interval, the source produces18 decimal digits
from an88-bit fraction, rounds to17 digits using a next-digit comparison with5,
and removes trailing zeros. The caller then rounds that string again to
`decimalPosition + fractionDigits`, pads zeros and inserts the decimal point.
Both rounds and their order matter. This is not a single host operation of
rounding the exact binary value to three or four decimal places.

The fixed string-rounding helper7814d4b2 treats its input as bytes even for
special-value spellings. It can therefore turn `1#INF` into `1.#IO` at precision3
and `1#QNAN` into `1.#QNB` at precision4. Negative canonical indefinite NaN uses
`1#IND`; other quiet and signaling NaNs retain their separate source categories.
Signed zero remains negative when its input sign bit is set.

Observed examples from the original DLL and the local macOS26.6.2 arm64 libc:

| Binary64 value / precision | VC80 original | Darwin snprintf |
| --- | --- | --- |
|0.03125 /4|0.0313|0.0312|
|0.0625 /3|0.063|0.062|
|bits4280000000000001 /3|2199023255552.001|2199023255552.000|

The local comparison over the complete corpus found34,693 finite and34
nonfinite formatting differences. These counts describe these declared inputs,
not the prevalence of visible differences during gameplay. The audit is retained
at build/research/diagnostic-numbers-host-differences.json.

## Source capture and native comparison

`tools/oracle_diagnostic_numbers.py` executes the real exported sprintf with
formats `%2.3f` and `%2.4f`. Its C-locale PTD is initialized by the retained CRT
harness; CW023f, empty x87 tags and FPSW0 are set explicitly for each call.
The source checks actual return/stack cleanup, complete output bytes, the
terminating NUL, every output write-mask byte and untouched surrounding guards.
All74,424 calls retain CW023f, FPSW0 and empty tags.

At78149ed8, immediately after $I10_OUTPUT returns, the source additionally
captures the decimal position, sign, finite-result flag and complete significand
string. Native compares this intermediate as well as every final formatted
byte. Thus a matching final string cannot hide a different first rounding step.

| Input group | Calls |
| --- | ---: |
|All2048 binary64 exponent fields, both signs, seven mantissa boundary patterns and both precisions|57,344|
|Decimal rounding midpoints and adjacent representable values|1,320|
|Decimal powers and adjacent representable values|7,568|
|Deterministic full64-bit samples|8,192|
|Total distinct input/precision pairs|74,424|

The mantissa controls include zero, one, boundaries around the quiet-NaN bit
and the maximum fraction. This covers normal/subnormal boundaries, signed
zero, infinities, several signaling/quiet NaNs, carry chains and extreme scales.
It is not an exhaustive check of all2^64 bit patterns.

The source observer records1,568 PCs. The registered_getptd hook at78132e29
returns the declared PTD token and does not execute that DLL instruction;1,567
PCs are actual original instruction starts. Selected function inventories:

| Source range | Executed / static starts |
| --- | ---: |
|78149dd9..78149e93 binary64 to LD10|72/72|
|78149e94..78149f21 conversion wrapper|54/62|
|78149f23..7814a7c4 I10 output|579/747|
|7814d4b2..7814d56e digit rounding|71/90|
|78149b87..78149c3f fixed wrapper|66/81|
|78149a92..78149b86 fixed layout|70/99|

Unexecuted paths include general extended-range inputs, other precision/format
options and invalid-buffer/error paths. These counts are instruction starts,
not proof of every branch outcome or all possible CRT invocations.

## Reproduction and limits

```sh
uv run --script tools/oracle_diagnostic_numbers.py
python3 tools/accept_diagnostic_numbers.py
swift test --package-path native -c release --filter OriginalDiagnosticNumberTests
python3 tools/compare_diagnostic_numbers_host.py
```

SwiftPM runs sequentially. Acceptance checks source and DLL identity, raw
transport hash, unique inputs, exponent/sign coverage, original scaling-table
bytes, instruction inventories and all old fixture pins before running the
native comparison and publishing the lossless fixture. The source raw file
contains20,331,263 bytes; [evidence](../evidence/diagnostic-numbers.json) pins
raw and packed artifacts. Packaged verification is separate from raw acceptance.

The release NTSDNative build passed in52.26s. The first test compilation
failed because the existing internal fixture-unpack helper required@testable
import; only that test import changed. The numeric comparison then passed all
74,424 cases in0.361s after a27.97s build, with no numeric-rule or expected-data
correction. Final packaged verification passed in0.331s after a137.36s build.

The lossless fixture is884,564 bytes. Independent inflation checks full
raw/packed byte and JSON equality, lengths and SHA256; all168 old fixtures
remain unchanged among169 current pins. Audits are retained at
build/research/diagnostic-numbers-artifact-verification.json and
diagnostic-numbers-fixture-pins.json. Python compilation,1,211 local Markdown
links and diff checks passed. All source and SwiftPM jobs were terminal before
the milestone commit. Native app-window or Windows/device output was not tested.

This module implements the two fixed formats required by the diagnostic
consumer. It is not a general printf implementation or a replacement for other
CRT parsing/formatting contracts. All reachable binary64 decimal scalings are
normal within the wider internal exponent range; the private multiplication
algorithm is not exposed as a general80-bit arithmetic API.

The source here runs on a separate declared CRT CPU. The real421a2d..421cdc
caller, its compound format, signed byte-to-character behavior, full stack
storage/provenance, GDI/fill/bitmap requests and both initialized continuations
still require comparison. In particular, the caller loads and stores operands
through x87 before formatting; any signaling-NaN quieting belongs to that
caller, not this raw-varargs conversion. Large compound strings also need an
actual caller-buffer analysis rather than assuming this4096-byte test output
allocation describes the game's stack.

The accepted own native chain remains at421a2d, as in
[GAMEPLAY_HUD](GAMEPLAY_HUD.md). Continue the first stage in
[TICK_TAIL_PLAN](TICK_TAIL_PLAN.md), then results, labels, presentation, sound
and the actual422ab8/ret4. Native app integration, a complete match and actual
Windows/device/clean-macOS checks remain open.
