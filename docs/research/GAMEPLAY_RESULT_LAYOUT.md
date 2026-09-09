# Initialized result-layout continuation

Both fresh original startup/menu/loading/selection/match chains reproduce their
entire pinned [GAMEPLAY_RESULT_RECORDING](GAMEPLAY_RESULT_RECORDING.md) parents,
then continue from the recorder-selected422944 entry through422994/SP1000e9bc.
The complete before/after state is identical. Both native joins pass: each
compares545197records/877520166bytes and masks,536 or544 helper returns,65 complete
state checkpoints and1606FPU checkpoints. The first gameplay tick has not returned.

## Own state and caller storage

The original executes422944 and42294b. The third observed address,422994, is an
unexecuted stop. Both own450b84 flags remain0, so there is no result table,
indicator draw or playback-information call in this continuation. This is the
recorder's actual branch, with no flag injection. Enabled table and indicator
branches remain covered by the separate599 whole comparisons and one explicit
source-fault rejection in [RESULT_LAYOUT](RESULT_LAYOUT.md).

[oracle_gameplay_result_layout.py](../../tools/oracle_gameplay_result_layout.py)
executes the full original parent on the same initialized CPU. Hooks observe
memory, registers and FPU state to establish the caller boundary and whether
the retained target or formatter is accessed. The watched low-local range is
root34..6b; the formatter/cookie range is root44c..5c3. Both access lists are empty.
Neither source stage word nor caller backing is injected to select this path.
CW023f/FPSW4000/tagffff survive, and the1605 complete parent FPU checkpoints are
preserved with one new422944 checkpoint, for1606 total.

`GameplayResultRecordingReference` now returns the actual native recorder
continuation. `GameplayResultLayoutReference` passes it and the own retained
`OriginalMatchRoundResult.stageDefeated` to the public `OriginalResultLayout`
consumer. The source word is used only as a comparison assertion. Formatter
storage and the indicator target remain nil. This preserves the distinction
between an unused value and a reconstructed native surface or stack allocation.
The controlled failure tests separately require those inputs at their first
actual consumption; the initialized join does not invent them.

## Verification and remaining work

[accept_gameplay_result_layout.py](../../tools/accept_gameplay_result_layout.py)
checks complete parent identity, whole before/after equality, every raw blob,
the exact executed/terminal addresses, absence of new helper/checkpoint/undefined
read events, and the complete FPU audit. Both source processes are terminal with
exit0; neither was restarted. Raw primary9250044bytes has SHA256
`6a463e2ad49b9161106b85b3d3d46a1c6c75e0f3f63ea6cb56f8de0337714a13`;
control9266358bytes has SHA256
`cb9fe717c678dcc06e35c6e69bf121cac8d8156c1de1ebb48b46217508038018`.

The initial publication attempt stopped at a stale183-fixture directory-count
assertion, after both source verifications passed. Concurrent controlled output
work had legitimately published fixture184; all183 old pins were unchanged.
Acceptance now verifies the complete184-pin published baseline before testing
and preserves that addition. This changes no source fixture or game rule.

Both raw release tests pass42.459s/build162.43s. NTSDNative linked; no app window
or device was exercised. The two immutable own fixtures have1278715/1289563bytes
and2756/2757 inner blobs. All184 prior pins remain unchanged, with186 current.
[verify_result_layout_artifacts.py](../../tools/verify_result_layout_artifacts.py)
checks all three controlled/own full raw and packed byte sequences, complete JSON,
SHA and lengths, all6084 inner blobs and ten unchanged vendor hashes. Source
and raw acceptance processes are terminal. Reports are
[primary](../evidence/gameplay-result-layout.json) and
[control](../evidence/gameplay-result-layout-control.json).

Final packaged verification passes all4release tests in44.987s/build0.25s,
without raw-corpus overrides: both own joins42.452s, controlled layout2.115s and
the170-call controlled gameplay-output corpus0.419s. All layout source and
SwiftPM processes are terminal. This does not execute an application window,
an audio device or the own gameplay return.

The next original operations at422994 are mode-label rendering, notice/volume,
presentation and enabled queued sound, followed by the real422ab8/ret4. Their
[controlled output comparison](GAMEPLAY_OUTPUT.md) is accepted. Both own
initialized compositions and retained match/dispatcher returns are now also
accepted separately in [GAMEPLAY_RETURN](GAMEPLAY_RETURN.md).
An app window, actual Windows/device output, continuous ticks, a complete match
and clean-Mac delivery remain outside this source continuation.
