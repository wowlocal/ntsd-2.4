# Both initialized result continuations

Both fresh initialized startup/menu/loading/selection/match/HUD/notice chains now
continue through the whole result-recording gate to422944/SP1000e9bc. Each native
comparison covers513221 records/842185012 bytes and masks,536 or544 helper returns,
63 complete state checkpoints and1605 FPU checkpoints. The full pinned
[GAMEPLAY_NOTICES](GAMEPLAY_NOTICES.md) parent reproduces unchanged. This is still
the first unreturned gameplay tick, not an own saved replay or a full match.

## Own stack and state provenance

`MenuCycleReference.Portion.roundResults` now retains the actual
`OriginalMatchRoundResult` returned by `OriginalLoadedMatchEntry.run`. The public
`OriginalResultRecording` consumer receives that own `stageDefeated`, never an
expected source stack word. The source stack audit verifies preservation from
its semantic producer; it does not initialize the native value.

[oracle_gameplay_result_recording.py](../../tools/oracle_gameplay_result_recording.py)
executes each entire pinned parent before continuing the original caller. Hooks
observe memory/register/FPU state to verify round-result lifetime and the exact
continuation. Neither enabled flags nor recording/stack bytes are injected to
select the new path. Each complete rootSP64 audit has89 accesses. Since the last
actual round initialization at41d7d7, the only access is its four-byte write0.
Both final retained words are0. This proves these two initialized paths, not all
branches, paused paths or arbitrary earlier stack aliases.

Seven actual caller instructions execute:421cdc/421ce1/421ce4/421ce6/421ced/
421cf0/421cf6. The eighth observed address422944 is an unexecuted stop. Complete
state changes only450bbc from0 to1. The `early.globals` and `state.globals`
snapshot fields describe the same changed global record; they are not two game
mutations. Recording remains owned and live, no writer is called, and no helper,
event or undefined read is added. Both own before/after recordings remain the
same buffers already verified in their parent chains.

All1604 parent FPU checkpoints survive, with one additional point at421cdc.
Entry/exit CW023f/FPSW4000/tagffff remain unchanged. Native caller-local notice
storage remains unavailable as before; no expected raw stack backing is imported.
The subsequent result table's422673 read still belongs to this round word:
4222ce's apparent `[esp+64]` store is actually root4c after six pending pushes.
See the independent **static** audit in [RESULT_LAYOUT_PLAN](RESULT_LAYOUT_PLAN.md).

## Verification and limits

Both raw own tests first passed40.632s without a rebuild. They passed again in
40.441s within the final ten-test raw acceptance set58.577s/build149.00s, alongside
all95 controlled result calls and retained codec/stream/writer/output helpers.
NTSDNative linked, but no app window, Windows execution or device was tested.
[accept_gameplay_result_recording.py](../../tools/accept_gameplay_result_recording.py)
checks each full parent identity, complete after-state difference, every inner
blob and exact stack/FPU observations. The shared acceptance runner uses that
same validator, preserving publication order after the controlled caller.

| Corpus | Raw bytes | Packed bytes | Inner blobs |
| --- | --- | --- | --- |
|Primary|9271943|1289971|2757|
|Control|9288253|1301431|2758|

All175 prior fixtures remain unchanged. Both own fixtures were published after
controlled result acceptance, with178 intermediate pins; subsequent compared
helpers bring the current set to182. Full raw/packed byte identity, complete JSON,
SHA and lengths are independently checked by
[verify_result_tail_artifacts.py](../../tools/verify_result_tail_artifacts.py).
Reports are [primary](../evidence/gameplay-result-recording.json) and
[control](../evidence/gameplay-result-recording-control.json). Both source captures
and their raw acceptance SwiftPM processes are terminal.

Next join the complete result-layout/indicator consumer without inventing the
retained SP68 surface when its branch is enabled. Then compose the proven mode,
notice/presentation and enabled sound helpers in original order through the true
function return. Native app/full tick/full match, Windows/device/clean-Mac checks
and the full game goal remain open.

Final packaged verification: the ten-test release set passes58.142s after a0.23s
resource-copy build, without raw-corpus overrides. This study takes40.355s. All
source and SwiftPM jobs are terminal; full artifact/pin/vendor checks pass. This
does not establish an app-window, Windows or actual device result.
