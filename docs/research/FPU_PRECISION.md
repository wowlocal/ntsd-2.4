# FPU precision: required correction before further tick expansion

This audit changes the next task. Historical native arithmetic comparisons use
an explicitly supplied CW037f, with a64-bit x87 significand. The original EXE
has a startup initializer that requests **53-bit precision**. Its executed
results differ from that historical contract. Do not treat the earlier green
CW037f comparisons as proof of Windows numerical equivalence.

Baseline EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Pinned MSVCR80 SHA-256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Static startup path

The PE entry445560 reaches44529f. The first CRT initializer table is passed to
`_initterm_e` at445324..44532e, covering4472d8..4472e8. The original table
contains44547e. That initializer calls445a31 at445546, before WinMain43cf40 is
called at4453da. The whole helper445a31..445a59 calls IAT4470f0 through445b16:

```
_controlfp_s(NULL, 0x10000, 0x30000)
```

The imported name and table are read directly from the pristine PE. The
outer startup/thread/OS and other initializers are static evidence here;
the audit does not claim to execute the entire PE entry through WinMain.

## Original-instruction evidence

`tools/oracle_fpu_precision.py` executes the entire445a31 and actual pinned
DLL `_controlfp_s`7814a7e9, `_control87`7814b04c and its conversion helper.
No host substitute changes the control word. Four declared initial words give:

| Before | After | Result |
| --- | --- | --- |
| 0000 | 0200 | success0 |
| 037f | 023f | success0 |
| 027f | 027f | success0 |
| 0b7f | 0a3f | success0 |

All have precision bits0300=0200 afterward. The change is the53-bit significand;
other initial flags/rounding remain relevant. Reserved bit0040 differs when the
CRT rewrites the word, so do not demand identical full words for the same
precision.191 instruction addresses execute across initialization controls.

The audit then runs entire4196f0 on16 declared midpoint inputs under four
conditions: inherited CW0, actual startup helper from037f, explicit027f and
historical037f. All64 calls complete. Actual startup-helper values match027f;
037f values exactly match the accepted native World-impulse corpus. **32 stores
differ between53-bit and64-bit precision**.

For pending binary64 bits3ffc111680d7849f and count789644137:

| Mode | Stored velocity bits |
| --- | --- |
| CW0 /24-bit | 3e33151140000000 |
| Actual EXE startup helper /53-bit | 3e3315113574ea8d |
| Historical CW037f /64-bit | 3e3315113574ea8c |

At the time of this audit, `OriginalExtended` reproduced the third value in its
declared domain and did not implement the startup-selected53-bit contract. These
differences cannot be repaired with a comparison tolerance or by changing
expected fixtures. x87 still has its extended exponent range at53-bit precision;
replacing every operation with host `Double` would introduce premature overflow.

The follow-up [ARITHMETIC_PRECISION](ARITHMETIC_PRECISION.md) now implements
explicit24/53/64-bit native arithmetic and compares53-bit whole Actor physics
and impulses. Its new evidence is separate from this historical audit. The
initialized own chain and Windows/thread/device provenance remain open.

The subsequent [INITIALIZED_GAMEPLAY](INITIALIZED_GAMEPLAY.md) now executes
this initializer on the same CPU before World construction and reproduces both
own chains through41f550 with CW023f. It also revalidates whole World physics,
links and hits at53 bits. Declared initial CW/outer ABI/PTD/device boundaries,
remaining arithmetic consumers and real Windows provenance are still open.

The later [CONTROL_PRECISION](CONTROL_PRECISION.md) corrects Actor control and
adds an important harness qualification: a fresh UNWRITTEN Unicorn FPCW0 does
not behave like explicitly writing0. This audit's source mode named
`inherited-zero` explicitly writes0 before execution, so its retained results
prove that explicit control only. They do not establish the effective numerical
mode of historical unwritten own chains. Initialized chains explicitly write037f
and execute actualCRT, avoiding that ambiguity. Do not rewrite old captures.

## Own-capture limitation

Fresh own early-menu/loading/launch captures inherit FPCW0 because that harness
starts below PE/CRT startup. [WORLD_IMPULSES](WORLD_IMPULSES.md) records this word
explicitly for the first time. Its own new4196f0 pass has count0 for both active
Actors, executes no multiply/divide and only clears constructor pending0.1.
Those clearing/caller results remain valid within the declared harness scope.
Earlier own numerical paths need revalidation from an initialized FPU context;
matching parent fixtures is insufficient to establish Windows precision.

## Required follow-up

1. Recover FPU initialization/provenance across the real startup, thread and
   device boundaries. Preserve the current historical corpus as a declared
   control, and create a new chain executing the original precision initializer.
2. Add explicit supported precision to native arithmetic, retaining extended
   exponent range, rounding after each relevant operation and exact stores.
   Compare53-bit/64-bit discriminating inputs before choosing the runtime context.
3. Audit all users of `OriginalExtended`, legacy/SSE2 conversion, CRT parsing and
   direct floating arithmetic. Revalidate original gameplay mechanisms and own
   loading→menu→match state with the recovered context. Resolve differences from
   original instructions, without copying expected states into the native engine.
4. Confirm actual game-thread control words and numerical results in Windows;
   library/device boundaries may affect the thread state. This remains open.
5. Resume whole40d960 and the interleaved400-slot post-draw loop41f550..4214cf.

Reproduce with `uv run --script tools/oracle_fpu_precision.py` after generating
and accepting the World-impulse corpus. The [report](../evidence/fpu-precision.json)
retains raw hash, original initializer pointers, control transitions, counts and
the pinned native64-bit reference. `native53Compared` and `windowsVerified` are
explicitly false in this historical report. The new arithmetic acceptance is
recorded separately; full numerical correction and hardware exception behavior
are still not established.
