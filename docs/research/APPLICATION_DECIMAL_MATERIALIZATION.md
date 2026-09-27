# Bound decimal text preparation in the loading path

2026-09-27. The [finite plan](APPLICATION_DECIMAL_MATERIALIZATION_PLAN.md)
continues the incomplete [audio loading composition](APPLICATION_LOADING_AUDIO.md).
The previous full Native catalog/pool/menu/Host comparison timed out at 3,600
seconds. That result remains immutable. This candidate changes one production
statement and adds one preservation test; it does not extend the accepted
decimal grammar or promote root Native.

## Implementation and evidence

`OriginalFrameScanner.binary64` previously converted the complete remaining DAT
suffix into a String before an anchored decimal regex. It now materializes only
the contiguous prefix containing ASCII digits, plus, minus, period, e and E.
The unchanged regex can consume only this alphabet and has no lookaround or
end-anchor. Text following the first other byte cannot change its match.
The regex, Double conversion, finite-value check, position/EOF updates, observer
calls and errors are byte identical. Integer and token readers are unchanged.

The prior one-second Native sample and saved 863-read input count justify this
bounded change. They do not measure a shipping loading time or speedup ratio.
The previous test also invokes source comparators throughout its repeated
attempts. A new successful duration cannot provide an exact speedup over an
unfinished run.

The new test compares the frozen parent method, reindented without statement
changes, with the candidate on 553 strings. Two observer modes and two sequential
reads produce 2,212 paired observations of Double bits or errors, position, EOF
and complete observer history. Controls include all 256 byte values in two
positions, overflow, subnormals, signed zero, incomplete exponents, a rounding
boundary, long numeric strings and a long nonnumeric suffix. The parent Native
method is a preservation control, not an authoritative game reference.

The known CRT `1e+` discrepancy remains open: the original consumes three bytes,
while this Native regex consumes one. General decimal lexing/rounding and actual
Windows CRT binding remain open. Saved actual-DAT and complete caller comparisons
provide their existing, separately bounded source evidence. No original code,
Unicorn or Windows capture executes in this task.

## Validation state

Preparation 16217 completed with exit 0 in 13.404338208 seconds. Candidate manifest
SHA-256 is `e23c59520310c10f97d505eb10386d8dd04d92f77022414589be1a8ae8c937ce`:
2,291 files, exactly one modified production file and one added test file.
All 676 prior files under Tests, including fixtures, are unchanged. Author
inspection verified the 165 retained selected methods in 53 unchanged test files.
This is author inspection; independent review remains unavailable and open.

Release build 17481 completed with exit 0 in 311.808079125 seconds, peak sampled
process-tree RSS 7,063,486,464 bytes. All observed build processes are absent.
The package verifier passed with Core210/Reference61/Mac11/Tests292 sources,
385 fixtures and 1,301 runtime resources. Candidate membership, fresh compiled
outputs and all 1,686 packaged resource bodies were verified. The binary is
69,518,392 bytes. This task adapted the already corrected source counts before
freezing; the parent's earlier package-verifier failure is preserved separately.

Queue 29527 runs 166 fixed methods (whole-loading PID34343): the new preservation control, 14 existing
numeric/catalog methods and all 151 prior audio/application methods in their
original relative order. Per-method limits and comparisons are unchanged for
those 151 methods. The whole loading method retains its 3,600-second limit and
3,000-request / 3,002-attempt bounds. A first nonpass stops the remainder.
The queue is still running; final Native comparison and archive gates are open.

The first 20 methods passed. The first 15 cover the preservation control, 863 actual DAT numeric
reads at explicit 53-bit precision, complete catalogs, Object and Stage streams,
Frame snapshots and rollback checks. The next five retain the parent audio ownership, common/registered, retry and
whole source caller checks. [Live evidence](../evidence/application-decimal-materialization-live.json)
pins those terminal results separately from the running full comparison.
Historical isolated Frame exclusions remain
historical; this change does not turn them into accepted behavior.

## Environment and open work

The 04:52:15 UTC host observation reports a locked console. CUA selecting UTM
returned `Computer Use server error -10005: cgWindowNotFound`. This is a window
availability error, not a safety refusal. No UI input was performed. Windows
installer approvals remain valid; installation resumes when the window is
observable. Existing Ghostty and other safety incidents stay open.

X5 retains its declared 121 GiB combined reserve. Parent 2,290, prior 2,257,
root 1,034 files, 55 source producer pins, old failures, fixtures and expected
bytes/masks remain protected. Root implementation, whole application integration,
runtime audio playback/device behavior, Windows font/cursor, clean-Mac acceptance,
full match and full game remain open. The EXE envelope is not recalculated.

Next: let this live queue reach its bounded terminal result, verify process
absence and archive/publication gates, then commit this increment. Do not restart
the queue, remove the full caller or mutate frozen producers to obtain a pass.
