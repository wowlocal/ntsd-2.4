# Post-draw accumulated impulses

Baseline EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The pristine Windows distribution is the only behavioral reference.

## Entire4196f0

`OriginalWorldImpulses` implements `4196f0..419798`, including the ascending
400-slot pass. Nonzero activity is the only slot gate. It does not inspect
Object type, source ID, current Frame, HP, carried state or input. Every nonzero
signed Actor+b4 skips all processing, preserving both pending vectors and count.

For a nonzero signed Actor+20, the original calculates each velocity in order:

```
velocityX(+40) = binary64(x87(pendingX(+28) * 2 / signed32(count + 1)))
velocityY(+48) = binary64(x87(pendingY(+30) * 2 / signed32(count + 1)))
velocityZ(+50) = binary64(x87(pendingZ(+38) * 2 / signed32(count + 1)))
count(+20) = 0
pendingX(+28) = +0.0
pendingY(+30) = +0.0
pendingZ(+38) = +0.0
```

The increment wraps in32 bits before signed FILD. Each division follows a fresh
Actor pointer/count read. The multiply and divide retain the x87 64-bit
significand until each binary64 store; evaluating a binary64 multiply first
would prematurely overflow for large operands. Signed zero and underflow are
preserved by the existing finite `OriginalExtended` arithmetic.

When count is zero, velocities remain unchanged, but all three pending values
are still cleared to positive zero. With aliased World pointers, the first
eligible visit consumes the impulse; later visits see the already cleared
count and leave the new velocity untouched. Slot order is never deduplicated.

The masked arithmetic cases retain the observed value bits: count−1 creates
a zero divisor, zero/zero stores the negative indefinite NaN, and nonzero
finite operands produce signed infinity. Infinite operands preserve or flip
sign with the divisor. NaN sign/payload survives; signaling NaNs are quieted.
This is value compatibility under CW037f, not a native model of process-wide
x87 status, traps, other rounding modes or Windows exception handling.

The whole pass stages the Actor pool before committing. Observer failures or
invalid late bindings leave the original pool intact. Other match storage is
not modified; observers represent pending events and must not publish device
effects before an enclosing tick succeeds.

The source's initial `push ecx` reserves scratch storage. FILD divisors overwrite
that slot, so final ECX is not necessarily the World pointer. It is a volatile
register; the original preserves EBX/EBP/ESI/EDI and restores the function stack.

## Caller text and mode boundary

`41f4ac` calls437860 only for mode451160=1; `41f4c2` separately reloads the mode
and calls43a860 only for4. These mode children remain unrecovered. The native
common-tail entry explicitly rejects those modes; it never silently substitutes
empty mode handlers. The own Naruto/Sasuke/District launch currently has mode0.

`41f4d3..41f545` always reads the Actor pointer in **World slot10**, irrespective
of that slot's activity. It sign-extends bytes at **c4,c5,c3,c2,be,c0**, in this
argument order, and executes the original CRT format:

```
u%d d%d l%d r%d a%d d%d 
```

These are buffered diagnostic fields, not the held-input bytes cd..d3. The
trailing space and repeated `d` label are original. All six signed-byte values
produce at most36 bytes. The cdecl destination is the existing caller stack
local at bodySP+48c; this is not a new Actor field or persistent game buffer.

Actual401290 receives global455608, text, background0, colorffffff, x0 and y30.
It executes GetDC, SetBkColor, SetTextColor, string length, TextOut and ReleaseDC.
A negative GetDC result skips later GDI operations but does not skip4196f0.
Later platform failures do not change the source return. After both cdecl
argument lists are removed,4196f0 executes. The caller then resets EDI and jumps
to the active-slot post-draw loop at41f550 on the same stack.

`OriginalPostDrawImpulses` shares the existing `OriginalSurfaceText` and emits
the formatted text followed by its real ordered boundary requests. It stages
the entire preparation state until impulses succeed.

## Controlled source evidence

`tools/oracle_world_impulses.py` runs actual original constructors and the entire
function against declared a5/ramp backing and a400-slot pool. It compares full
pool and World bytes/masks, global bytes, and every ordered Actor write. Object
storage is retained and asserted unchanged in the source. No original game RNG
is consumed; the deterministic varied cases supply test inputs only.

The source corpus has1030 cases:175 activity/hitstop/count gates,456 binary64
edge patterns,320 varied bit patterns,16 targeted double-rounding cases,
60 aliases, two400-slot controls and one empty pool. All58 instructions execute,
producing9385 ordered writes. The value
cases include signed zeros, subnormals, normal boundaries, overflow, infinity,
quiet/signaling NaNs and signed count overflow. This is not exhaustive coverage
of every possible64-bit operand or every natural game sequence.

The sixteen midpoint controls were selected by exact rational arithmetic to
distinguish a64-bit significand division followed by a binary64 store from a
direct binary64 division. Original instructions supply all expected outputs;
no rationally calculated result is fed into the native comparison. All1014
prior source cases remain byte-for-byte unchanged when adding these controls.
Thirty-two original stores differ from direct correctly rounded binary64
division, distinguishing the actual intermediate precision in this helper.

Unicorn reports only status words0/4 in this corpus, including zero-divisor
cases; these flags are retained as harness observations, not asserted to be
hardware-accurate x87 exception behavior. Actual Windows verification is open.

A separate256-case run executes the pinned MSVCR80 sprintf at7817775d, covering
all256 byte values in each of the six argument positions. It verifies output
bytes, return length, NUL and untouched destination tail. Thread/lock responses
remain declared boundaries. DLL SHA-256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Reproduction and scope

```
uv run --script tools/oracle_world_impulses.py
uv run --script tools/oracle_gameplay_impulses.py
uv run --script tools/oracle_gameplay_impulses.py --control
python3 tools/accept_gameplay_impulses.py
```

The acceptance command runs SwiftPM sequentially and publishes lossless fixtures
only after native comparisons pass. Existing accepted fixtures are retained.
The two own captures reproduce the complete pinned GAMEPLAY_DRAWING parent
before continuing on its own CPU/stack. Full snapshots include the mutable
Frame heap and all11 retained character-menu wrappers in addition to the earlier
World, Actor, catalog, replay, music, early and initial-interface resources.

Both fresh source runs reach41f550/SP1000e9bc, still in the same unreturned
4246b0 call. Each executes three whole helpers,499 instruction addresses and
seven format/GDI events. The text is `u0 d0 l0 r0 a0 d0 `,18 bytes, white on
background0 at0,30, target28002020. No undefined owned-data reads occur.

The first two Actors have count0 and hitstop0. Their constructor pending
vectors still contain0.1 in all axes;4196f0 clears exactly these six binary64
fields to positive zero. Current velocities, coordinates, frames, HP/MP, RNG,
CRT state and all remaining state/resources stay unchanged. This is a visible
state transition even though the first tick performs no impulse division.

The own harness retains **FPCW0**, inherited from the early source VM, and
FPSW0. It is not silently reset to037f at this continuation. No instruction in
41971b..419770 executes, and native comparison requires count0 for every
eligible own Actor. Thus the own result proves clearing and caller order,
while the separate controlled CW037f corpus proves arithmetic values. Neither
establishes actual Windows startup FPU initialization; that provenance remains
open. The historical parent fixtures are not rewritten to conceal this boundary.

Paired native acceptance passed4 release tests in39.905s after a57.49s build,
then published three lossless fixtures. Each own launch/gameplay chain compares
353341 records/665509242 bytes with masks,499 helpers/53 checkpoints, including
a public rollback trial after diagnostic output and before a late invalid
Actor binding. Earlier startup/menu/selection parents are validated separately
and are not counted in these totals. Both chains total706682 records and
1331018484 bytes with masks,998 helpers/106 checkpoints.

The preceding6-test release regression passed in78.456s/build19.50s, retaining
both own World-draw and MatchLaunch comparisons plus the initial1014-case
impulse corpus and rollback test. The final1030-case suite also passed in the
paired acceptance. All135 previous fixture hashes are unchanged. The current
138 fixture pins are retained at build/research/gameplay-impulses-fixture-pins.json.
NTSDNative compiled and linked; no app/device/Windows validation is implied.

**The follow-up [FPU precision audit](FPU_PRECISION.md) changes the immediate
priority:** original startup445a31 requests53-bit precision, and its actual
DLL execution changes32 midpoint stores compared with the accepted64-bit
arithmetic contract. The separate [arithmetic correction](ARITHMETIC_PRECISION.md)
now validates native24/53/64-bit arithmetic and all1030 impulse controls at each
precision. Initialized own chains still need revalidation before expanding
gameplay. Keep this corpus
as an explicitly declared CW037f control, not a Windows-equivalence claim.

The next source body is the complete400-slot loop `41f550..4214cf`, with
interleaved substitutions, spawning, scheduler, recovery and deletion. Its
first branches include state9995→sourceID50 and state8000..<9000→state−8000;
these are static observations, not newly implemented or dynamically verified
rules. Mode1/4 children, the full tick return, runtime integration, sustained
DAT sequences, the first complete match, Windows/device and clean macOS remain
open. This milestone does not close R02.1, R01.2 or the full-game goal.
