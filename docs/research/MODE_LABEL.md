# Whole mode label

`OriginalModeLabel` implements41b130..41b384/ret8 and matches all148 controlled
original calls, including the actual423a70/423940/43f010/43ef70 children.
The raw comparison passed1.485s without a rebuild. The two initial calls passed
0.009s after a147.43s test build; the core release build linked NTSDNative in
56.94s. This is now published after result-recording, both own continuations
and [BITMAP_FONT](BITMAP_FONT.md). It is not an initialized label
continuation, complete tick, app-window, pixel or Windows comparison.

## Recovered behavior

Modes0..4 copy the original `VS mode `, `Stage mode `, `1 on 1 `, `2 on 2 ` and
`Battle mode ` literals, including each actual NUL and original store width/order.
Mode1 first writes its base label, then replaces it with `Survival Stage ` when
signed450b94/10==5. Difficulty450c30 appends `(Difficult)`, `(Normal)`, `(Easy)`
or `(CRAZY!)` for0/1/2/−1. Unknown modes retain the previous global450c38 string;
unknown difficulties leave the resulting string without an appended suffix.
There is no invented default label or clearing of unused trailing bytes.

The caller computes X790−8*strlen **before** font truncation. Its second argument
selects Y531 when zero or510 otherwise. The whole four-pass font gets64 columns,
four lines, style0 and no cursor. It mutates the same global string, so a retained
511-character input has the original offscreen placement even when drawing later
truncates it. Newlines, embedded NUL and signed negative glyph bytes remain byte
text. A thrown observer at the third pass verifies complete global rollback after
six caller stores and two font NUL stores. Buffer external effects until the
whole tick commits; numeric Blt failures do not become a source exception.

## Evidence and boundaries

[oracle_mode_label.py](../../tools/oracle_mode_label.py) supplies complete global
before-state and three independent bitmap records. Its1024-byte retained-label
research region is an explicit input extent, **not** a recovered C-array size.
No expected after-state enters the original CPU or native caller. Only COM Blt
responses are intercepted. Full globals, actual write masks and store order,
all181730 events and10156 Blts match. The events include602 literal/suffix stores,
592 font passes/NUL writes,20200 draws,129748 bitmap reads and19840 clips.
Source saved registers and all helper stack returns are separately verified.

All156 nonalignment caller instruction starts execute;41b34f is the missing
alignment NOP among157 decoded starts. There are523 actual EXE PCs overall and
no DLL PCs. CW023f/FPSW0/tagffff are unchanged. This is instruction coverage of
the declared corpus, not every branch outcome or native private-stack equivalence.
The source and all corresponding SwiftPM jobs are terminal.

[accept_mode_label.py](../../tools/accept_mode_label.py) independently verifies
full raw JSON, every transport blob's length/SHA, all global writes, four-pass
mutation and bitmap read provenance. `--verify-only` passes. The raw file contains
127779990 bytes, SHA256
`19eecbde7c3b93a5ed51be4014a10eb009b4dba621373832df9d73c0730ea2b6`.
The large raw size includes actual repeated string-read records; it is not a
native game allocation. Publication is gated on the preceding179 fixture pins.
The shared acceptance set passes this test in1.452s; all188 inner blobs and
the2436985-byte packed fixture are independently verified. Evidence is
[mode-label.json](../evidence/mode-label.json). [PLAYBACK_INFORMATION](PLAYBACK_INFORMATION.md)
also now compares the conditional41b390 helper. Whole result layout/indicators
and the own join remain subsequent work in [RESULT_LAYOUT_PLAN](RESULT_LAYOUT_PLAN.md).

Final packaged verification: the ten-test release set passes58.142s after a0.23s
resource-copy build, without raw-corpus overrides. This study takes1.058s. All
source and SwiftPM jobs are terminal; full artifact/pin/vendor checks pass. This
does not establish an app-window, Windows or actual device result.
