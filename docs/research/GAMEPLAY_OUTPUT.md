# Controlled gameplay output and normal return

`OriginalGameplayOutput` composes the complete422994 output caller. All170
controlled original calls match the native globals and119700 ordered events.
The source executes the original422ab8/ret4, verifies saved registers and SEH,
and performs340 normal cookie checks. This is a controlled output/return study;
it does not establish a returned initialized tick or Windows/device behavior.

## Behavior and implementation

The caller reads450b84 and451160, then calls whole41b130 mode label. Its retained
text, difficulty suffix, coordinate calculation and four mutable bitmap-font
passes use [OriginalModeLabel](MODE_LABEL.md). Next comes whole4028a0 notice and
volume handling, followed by43e940 presentation. Whole419e60 drains the enabled
sound queues only after presentation. Finally the caller jumps to422a95 and
returns through422ab8. None of these helpers is omitted to reach the return.

This order makes a volume change visible to sound requests in the **same call**.
Both volume keys held select the increment path. The original notice timers,
wrapped arithmetic, query/read/set/release behavior and ignored numeric COM/GDI
failures survive composition. All400 catalog slots precede all80 builtin slots;
positive pending flags clear before the sound sum check. A nonpositive wrapped
sum suppresses playback after clearing its flag. See [QUEUED_SOUND](QUEUED_SOUND.md).

Native stages World, globals and presentation ownership together. A thrown
eighth sound method on the volume-change case occurs after label rendering,
volume change, surface presentation, the first playback and both pending-flag
stores. The test verifies complete rollback to the initial globals, World and
ownership state. Observers must buffer external output until the enclosing tick
commits; storage rollback cannot undo an already submitted device operation.

## Original execution and boundaries

[oracle_gameplay_output.py](../../tools/oracle_gameplay_output.py) verifies the
pinned EXE and VC80 artifacts and executes their instructions on one Unicorn2.1.4
CPU at CW023f. The EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
CRT and package hashes are retained in the [evidence](../evidence/gameplay-output-controlled.json).

The actual41bc90..41bcd0 prologue establishes alignment, saved registers, the
SEH link and security cookie. The experiment then enters the declared422994
output context, with supplied globals, three font bitmaps and COM resource
tokens. It does not execute the intervening gameplay body. No control pointer,
SEH structure or cookie is corrupted. The original normal epilogue is executed
unchanged. EntrySP1000f624 produces bodySP1000effc and finalSP1000f62c.

COM/GDI and CRT thread responses are controlled boundaries. Actual VC80 sprintf
runs on the same CPU, with complete format/output bytes retained. Memory and
register hooks establish global writes, bitmap values and masks, helper order,
stack cleanup and return restoration. These observations distinguish emulated
requests from host audio, pixels, input latency or actual Windows execution.

The finite [acceptance plan](GAMEPLAY_OUTPUT_PLAN.md) covers ordinary output,
both label positions, real mode labels and retained unknown mode, notice timer
and blocking boundaries, both volume keys and signed extremes, query/read/set/
GDI failures, presentation modes, device gates, queue overflow and all480 slots.
There are no source faults in these170 cases.

All15 caller starts and12 epilogue starts execute in every case. The body/helper
inventory contains903 EXE and414 CRT instruction starts; the19 prologue starts
are recorded separately. Stop addresses and supplied boundary hooks are excluded.
This does not imply every helper instruction or branch outcome was exercised.

The corpus contains24918 complete helper returns,109 actual formats,10968Blts,
76776 bitmap reads including192 reads of declared undefined backing,4505 COM
method requests plus57 queries and55 volume reads,816 pending-flag writes and
780play calls. The119700 ordered events include680 helper-entry stage markers.
Source globals/write masks reconstruct exactly from original stores. Native
compares full globals and their declared defined masks, all format bytes and
the whole event stream; private stack writes and overlay store counts are not
separate native memory-trace comparisons.

## Verification and next join

The170-case raw native test passed0.454s after a169.37s release build. NTSDNative
linked. The packaged test passed0.420s/build0.28s without a raw-corpus override.
An early three-case setup stopped at an incorrect expected aligned bodySP; the
harness assertion was corrected to the actual prologue result. Source bytes,
expected output and native game behavior were unchanged. The initial sample
remains preserved separately; no live process was restarted for silence.

[accept_gameplay_output.py](../../tools/accept_gameplay_output.py) reconstructs
source globals/write masks, checks every bitmap read, stage order, formats and
helper returns, then runs native acceptance before publication.
[verify_gameplay_output_artifacts.py](../../tools/verify_gameplay_output_artifacts.py)
independently verifies every raw/packed byte, complete JSON, SHA and all292 blobs.
The new fixture preserves183 existing pins and brings its publication set to184.
Raw17815852bytes; packed1823384bytes; raw SHA256
`5fb54908f5c366948acb1adfb1bc96c4b7a70ee679f0b87712f36c5e68a15418`.

Both initialized result-layout parents now feed their own mode, resources,
sound queues and retained caller through both actual returns in
[GAMEPLAY_RETURN](GAMEPLAY_RETURN.md). That separate whole own comparison
preserves this controlled corpus and never imports unknown caller stack words.
Continuous ticks, the new engine's app integration, a complete match, Windows,
audio/pixel/latency measurements and clean-Mac delivery remain open.
