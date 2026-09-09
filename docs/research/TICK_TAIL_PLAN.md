# Remaining match tail after HUD

This is a static caller research plan; completed dependencies are explicitly
linked below. EXE SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The static inventories themselves add no dynamic or native equivalence claim.
Completed dependencies are linked separately. Both own chains now return
through422ab8 and428805, as documented in [GAMEPLAY_RETURN](GAMEPLAY_RETURN.md).
Their next bounded continuation is [CONTINUOUS_GAMEPLAY_PLAN](CONTINUOUS_GAMEPLAY_PLAN.md).

The old shorthand421a2d..422994 does not reach the match return. At422994 the
original still calls mode-label rendering, notices/volume, surface presentation
and queued sound playback. The common epilogue starts422a95;ret4 is422ab8.
Follow these in order and preserve the actual outer caller through its return.

## Sequence and dependencies

Ranges below are half-open except the explicit final ret. Instruction counts
refer to static starts, include alignment instructions inside a range, and do
not represent executed PCs or covered branch outcomes.

| Step | Caller range | Static starts | Work |
| --- | --- | ---: | --- |
|1|421a2d..421cdc|198|Diagnostics and command-key/exit notices; real CRT format,401290 text,415160 fill and43f010 bitmap children|
|2|421cdc..422218|296|Elapsed-tick counter and conditional result recording, including43df00 and whole43dd60|
|3|422218..422944|515|Result-table layout, generic participant fields/portraits, team/outcome marks and time strings|
|4|422944..422994|22|Recording indicator and optional41b390 author/info/time overlay|
|5|422994..4229cc|15|Whole41b130 mode/difficulty label,4028a0 notices/volume,43e940 present,419e60 queued sound|
|6|422a95..422ab8 inclusive|12|SEH/cookie restoration, saved registers and actualret4 into the retained caller|

4229cc..422a95 is the alternative menu branch, not the successor of gameplay
at4229c7. Its existing [menu return](MENU_RETURN.md) evidence does not by itself
prove the gameplay caller or close the new epilogue comparison.

### Diagnostics and command-key notices

The controlled whole caller is now implemented in
[POSTHUD_NOTICES](POSTHUD_NOTICES.md):819 direct comparisons,8 explicit
signaling-NaN/Unicorn discrepancies with separately executed quiet-NaN
companions, and4 source cookie-overwrite controls rejected natively. Both
fresh initialized continuations from GAMEPLAY_HUD now match in
[GAMEPLAY_NOTICES](GAMEPLAY_NOTICES.md). Each481245records/806849858bytes+masks,
61state/1604FPU checkpoints; no new event or caller-local access. Unknown native
backing remains nil, never imported from the source's unused stack contents.

421a2d comparesglobal450bec to the retained EDI0, then loads actualsprintf
from447174 intoESI even on the disabled branch. The enabled branch formats
Actor slot0 values from+48/+60/+14 with `%2.3f %2.4f %d`, eight signed bytes
44d040..47, and signed byte4553e8 plusword450bfc. Preserve the double formatting
contract and signedness; platform-default formatting is not evidence.

The numeric dependency is now implemented and checked in
[DIAGNOSTIC_NUMBERS](DIAGNOSTIC_NUMBERS.md):74,424 actual VC80 sprintf outputs
and17-digit intermediates match native `%2.3f`/`%2.4f` conversions. The source
uses a separate CRT CPU. That isolated numeric study does not execute the compound caller. The new
POSTHUD_NOTICES study establishes its known stack extent and documents the
architectural signaling-NaN load conversion separately from Unicorn behavior.

450c2c==1 displays the original exit text, locally decodes the literal449204
by subtractingindex%4, displays the resulting original URL string, then draws
global44f8f8. This branch changes callerESI/EDI; the native composition must
track any later consumption instead of assuming their421a2d values survive.
Other branches use450c28==1 for function-key counts or==2 for locked status.
Mode451160==1 changes the notice fill and position. Observe real GDI requests
and bitmap clipping, retaining any earlier proven fill-stack provenance.

### Result ownership and records

[RESULT_RECORDING_PLAN](RESULT_RECORDING_PLAN.md) records the recovered
43dd60/compression/retainedSP64 dependencies, now composed in
[RESULT_RECORDING](RESULT_RECORDING.md).
[REPLAY_COMPRESSION](REPLAY_COMPRESSION.md) now implements the codec dependency:
815 whole calls match the native C/Swift consumer, including capacity and
allocation errors. Correct REP-derived masks and incomplete raw hook masks,
private5816/5920-byte ABIs and native host cleanup are explicitly distinguished.
The [whole writer](REPLAY_WRITER.md) now has21 whole-return matches and five
explicit source-fault rejections. The [result caller](RESULT_RECORDING.md) and
both own joins are now accepted:95controlled returns and two fresh initialized
continuations through422944. Do not
turn a compressor error into an early exit, because43dd60 ignores that status.
[REPLAY_STREAM](REPLAY_STREAM.md) adds66 whole C++ sequences with actual CRT
buffering:1772 descriptor writes/6664690bytes and330 ios states match Native.
Failed flush retains its triggering byte;4096-byte allocator failure switches
to unbuffered single-byte writes. Open/descriptor/private heap/thread responses
are explicit; actual Windows IO remains outside the whole-writer comparison.
RetainedSP64 has a recovered own producer, OriginalMatchRoundResult.stageDefeated,
now retained by MenuCycleReference. Both fresh own result captures audit its
intervening lifetime. Apparent[esp+64] operands can alias other root locals
after pending arguments:4222ce writes root4c and422673 still reads root64.
[RESULT_LAYOUT_PLAN](RESULT_LAYOUT_PLAN.md) records the subsequent static stack
audit, table/indicator rules and the mutable-string bitmap-font dependency.
[RESULT_LAYOUT](RESULT_LAYOUT.md) now implements both caller entries with599
whole native matches and one explicit corrupted-author bitmap fault rejection.
All537 table/indicator instruction starts execute. Its two fresh own joins now
match in [GAMEPLAY_RESULT_LAYOUT](GAMEPLAY_RESULT_LAYOUT.md): complete before/after
states remain identical, the native recorder's own continuation is preserved,
and formatter/target backing stays nil. The accepted initialized boundary is422994.

421cdc increments450bbc when signed450bdc<100. Unsigned(450bdc-101)>248 skips
the result block. At450bdc==101, result recording additionally requires450be4
and450b80 nonzero and450b84zero. Eight primary/fallback participant cells feed
the recording allocation at4588a8, including ID, active kind, team, combat
statistics and outcome. Mode1 also consumes retainedSP+64; use its recovered own
round producer and never import an expected source word. Result layout later reusesSP+34/44/50/54/58/
60; these slots have multiple lifetimes and are not interchangeable with the
preceding spawn scratch.

The recorder consumes full existing allocation ownership.43df00 is the known
playback settings restoration, with the caller subsequently copying sound flags.
43dd60 is now independently compared: it compresses the recording through
43f4b0, modifies leading bytes with a key, writes the file via imported stream
methods, frees temporary/original buffers and clears4588a8. Do not stub it as a
successful save or mutate the original distribution during research. File/API
responses must be explicit; encoded bytes and ownership changes need comparison.

### Labels, presentation and sound

41b130..41b384 builds450c38 from mode/difficulty, including Survival Stage when
signed450b94/10==5. It calls423a70, whose four423940 calls render offset text.
[BITMAP_FONT](BITMAP_FONT.md) now matches2450 controlled raw calls for the
complete423940/423a70 path; it is now published after result acceptance.
[MODE_LABEL](MODE_LABEL.md) also now implements and matches148 raw whole caller
comparisons. Both are accepted; existing401290 GDI text is a different renderer.
Unknown mode/difficulty values can retain prior string content and must be
investigated before applying a convenient default.

41b390..41b5cc conditionally formats author/info and elapsed/total time, using
wrapped arithmetic and the same bitmap-font helper.
[PLAYBACK_INFORMATION](PLAYBACK_INFORMATION.md) now matches120 whole calls;
its enclosing result indicator is now compared in RESULT_LAYOUT. It is conditional in step4,
whereas41b130 is unconditional in step5. Do not report that the ordinary first
tick has no rendering after HUD merely because diagnostics/results are inactive.

The existing `OriginalMenuPresentation` implements4028a0 notices/volume and
43e940 requests in other proven callers. Reuse those mechanisms, preserving
new caller order and state.419e60..41a043 consumes catalog/builtin sound queues,
computes pan/volume, clears pending flags and calls401a30.
[QUEUED_SOUND_PLAN](QUEUED_SOUND_PLAN.md) records its145+30 decoded starts,
400/80-slot arrays and wrapped arithmetic. [QUEUED_SOUND](QUEUED_SOUND.md) now
implements and matches968 whole helper calls, including enabled sound.
Its enabled queued-sound own join is accepted in
[GAMEPLAY_RETURN](GAMEPLAY_RETURN.md). The earlier disabled
fast return was part of the old broad tick trace. Sound remains enabled in the
initialized own chain; prove the whole consumer and device boundaries rather
than disabling audio to reach the return.

## Required evidence

The controlled steps5/6 are now composed and compared in
[GAMEPLAY_OUTPUT](GAMEPLAY_OUTPUT.md):170 original calls through the actual
normal422ab8/ret4 match native globals and119700 ordered output events. The
original prologue establishes the controlled saved frame; the intervening
initialized gameplay body is still a separate join. Both own result-layout
continuations now feed their own resources/queues/caller into this output in
[GAMEPLAY_RETURN](GAMEPLAY_RETURN.md), including both retained original returns.

Each new stage needs controlled full-state/side-effect comparisons and both
fresh initialized continuations that reproduce the entire pinned parent.
Preserve CW023f and the same source stack/CPU, ownership, immutable resources,
undefined masks and declared platform responses. Native must continue from its
own reconstructed state. Stop hooks and COM/import response addresses are not
executed original instructions. Reaching a firstret4 is a milestone, not proof
of multiple ticks, natural techniques, a finished match or Windows output.

After the first return, compare continuous original DAT-driven input sequences,
connect the complete owned pipeline to the native application and work toward
the full Naruto/Sasuke District match. Other modes, AI, replay/network/file
behavior, pixels/audio/latency and clean-macOS delivery remain in the full goal.
