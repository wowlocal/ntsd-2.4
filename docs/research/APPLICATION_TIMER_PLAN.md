# Application timer and whole dispatcher join

This is an independent source/API audit and finite next plan while the active
gameplay captures run. It does not extend their source execution coverage or
claim a native timing match. The original function order and earlier limited
experiments remain in [TICK_PIPELINE](TICK_PIPELINE.md).

The first timer-slice dependency is now compared in
[APPLICATION_TIMER](APPLICATION_TIMER.md):2025 decisions/8163 requests, with
all59 actual timer instruction starts. The whole dispatcher, recovery routine,
message loop and initialized device join below remain open.

The reference is the pinned NTSD2.4 EXE, SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Fresh llvm-objdump output for43d11d..43d20f was checked against each actual PE
instruction byte during this audit. These are static observations. A future
controlled execution will use Unicorn2.1.4 and explicit clock/message/device
responses; it must distinguish those responses from Windows or macOS timing.
Low-level observation is needed to recover the number and order of clock reads,
unsigned lateness checks, signed sleep decisions and caller baseline lifetime.

## What the current clock omits

[OriginalClock](../../native/Sources/NTSDCore/OriginalClock.swift) implements the
normal33ms arithmetic using one supplied `now`, aggregating catch-up ticks in a
loop. The actual application code executes at most one43e9a0 call per outer
iteration and obtains fresh timeGetTime responses at distinct sites:

| Normal / fast site | Operation |
| --- | --- |
|43d160 /43d1a0|Read time and test unsigned `now-baseline >33` or `>3`.|
|43d169 /43d1a9|If due, read time again and test unsigned lateness `>100`.|
|43d172 /43d1b2|If over100, read a third time and set baseline to that time minus100.|
|43d17f /43d1c0|Advance baseline by33 or3 before dispatch.|
|43d182 /43d1c3|Call43e9a0 with the live global451dac target.|
|43d18a /43d1cb|A signed-negative dispatcher result calls43e890 before the next time read.|
|43d193 /43d1d4|Read time and compute wrapped `baseline-now+33` or `+3`.|
|43d1df..43d1ed|Sleep only for a signed-positive remainder, capped at5ms.|

The speed flag44d02c is read once to select the branch. This slice ends at
43d1ef, before the458580 loop counter. It does not include message processing,
clock initialization, actual surface recovery43e890 or the dispatcher body.
An unchanged time response repeated across several decision iterations can
reproduce the old arithmetic corpus; that is narrower than the full loop.

## Finite dependency checks

First compare whole43d157..43d1ef decisions at declared clock/dispatcher/
surface-recovery/sleep boundaries. Cover both speed branches, threshold
neighbors3/33/100, time advancing between reads, UInt32 wrap, signed sleep
remainders, all three dispatcher result signs and both sleep clamp paths.
Retain actual request order, baseline, stack/callee preservation and every
executed instruction start separately from the static inventory. A dispatcher
boundary event is not execution of its game body or device recovery.

Then execute the whole43e9a0 dispatcher on the initialized state, preserving
its service-key sequence, target clear, actual mode routing and return. Join
its actual4246b0 calls to the accepted loaded-gameplay operation. Do not replace
it with a call counter or label the already returned4246b0 as43ed01.
Any newly reached loader, dialog or recovery dependency remains explicit.

Finally compose an outer iteration including message handling and458580,
retaining live global reads after callbacks. Model initialization and baseline
ownership before reusing this in the macOS update loop. Clock, input, render,
sound and file requests need one declared commit boundary; a failed native
iteration must not expose a partial game-state commit. Callbacks which already
submit external effects cannot be undone by copying Swift state.

Use finite deterministic clock-response sequences for comparison, then verify
real frame pacing, pause/resume, input latency and audio in the application
window. Full Windows and clean-Mac evidence remain separate. Do not alter old
timer fixtures or the current application clock merely to make new tests pass.
