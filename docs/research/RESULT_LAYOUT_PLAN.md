# Result layout and indicator dependencies

Static follow-up to [RESULT_RECORDING](RESULT_RECORDING.md), whose full controlled
comparison is still running. This plan does not implement or dynamically verify
the layout. It uses the pinned NTSD EXE, SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The remaining whole-tick queue is [TICK_TAIL_PLAN](TICK_TAIL_PLAN.md).

There are515 decoded instruction starts in422218..422944 and22 in422944..422994.
The recording caller can enter either range: its timer guard skips the table
directly to422944. Do not draw a result table unconditionally after the recorder.

## Stack lifetime

[audit_result_tail_stack.py](../../tools/audit_result_tail_stack.py) decodes the
actual833 instructions from421cdc to422994, propagating relative ESP across a
static control-flow graph. Normal callee cleanup is checked against the original
ret instructions, including41b390's ret12. Both conditional outcomes are explored,
even when a value constraint might make one impossible. Its output is
build/research/result-tail-stack-static.json; this is not execution coverage.

All joins agree on ESP and the normal422994 continuation has the original root
ESP. The audit retains92 ESP-relative operands. Indexed operands keep their
unknown index; it does not silently treat an indexed address as a fixed local.
The fixed rootSP64 operands are reads at421eb1 and422673.4222ce is instead a
rootSP4c store because six bitmap arguments have already been pushed. Preserve
the same own round result for the mode1 outcome mark in the result table.

| Root local | Static role in this region |
| --- | --- |
|34|45 times the number of visible participant rows, assigned42229c|
|3c..3f|Three-character participant label plus NUL, assigned before its reads|
|4c|Table top coordinate, assigned at4222ce after six pushes|
|54/58/60|Current seat, primary/fallback slot and row coordinate|
|64|Retained round result; fixed-offset mode1 reads remain live|
|68|Actual indicator destination argument at42294d, when450b84 is nonzero|
|44c|Integer/time formatting destination after accounting for pending arguments|

The indicator's SP68 target is unlike the preceding HUD's unused argument.
Keep unavailable own backing explicit when that branch is disabled; do not
promote the source's arbitrary stack word to a native surface token. The fixed
operand audit does not reconstruct arbitrary earlier pointer aliases or prove
the full lifetime of every stack byte.

## Participant table and time

Eight seats use the same primary0..<8 preference over fallback10..<18. The table
height is93+45*participantCount, with45 extra in mode4; its top is the signed
quotient `(530-height)/2`. Header/footer/row bitmaps retain the original negative
picture path in43f010. Portraits come from the live participant Object+728.

Three-character labels are `P1 ` through `P8 ` or `Com`. Their glyphs use the
team1..4/default resources and43f010 directly, with signed byte promotion and
nine-pixel horizontal advances. These calls are not the423940 bitmap-font helper.
The five signed statistics come from Actor+358/+348/+34c/+350/+35c. Each is
formatted with the original `%d` string at447b08 and displayed through401290.
Winner/team/HP and mode1/rootSP64 select the outcome marks in source order.
Mode4 adds its four451b64..451b70 summary counters and a second footer row.

Elapsed seconds use signed `(450bbc + 15 wrapping to32 bits)/30`. Values below
3600 use the literal `%02d : %02d` at449184; the other branch uses
`%02d : %02d : %02d` at449170. Division/remainders truncate toward zero, including
negative wrapped elapsed values. Preserve sign-aware zero padding and the
actual caller string storage; host date/time formatting is not this contract.

## Indicator and bitmap-font dependency

450b84 gates the indicator at422944. When enabled it draws picture24 from45116c
to the retained SP68 destination. Nonzero44d030 then reads elapsed time from
the playback allocation+144 and calls whole41b390(mode,recordedTime,currentTime).
The conditional overlay and the later unconditional41b130 mode label both depend
on423a70/423940. [BITMAP_FONT](BITMAP_FONT.md) now implements those helpers and
matches2450 controlled raw calls; publication awaits the priority result caller.
The whole overlay and mode-label callers remain unimplemented and unverified.

Static inspection shows that423940 **writes a terminating NUL into its input
string** at the consumed position. It is not a read-only text renderer. The
column and line limits are signed, characters advance X by8, and newline10 or
wrapping advances Y by16. Styles0/1/2 select three font resources; other style
values still consume characters and advance the position without a glyph draw.
A nonzero cursor flag draws `_` from the style0 font at the final position.
Character bytes are sign-extended before43f010, so bytes128..255 reach its
negative-picture behavior and must not be normalized to Unicode glyph indices.

The four423940 calls inside423a70 use the same mutable string at offsets
(-1,+1),(-1,0),(0,+1),(0,0) from the requested position. Later passes therefore
observe any truncation performed by the first. A native implementation must
preserve that mutation and original call/event order, including numeric device
failures; a copied immutable string per pass would change the behavior.

Next recover and compare the whole label/info callers with actual string
mutations, global/bitmap backing, clipping and device requests. Then join
the complete layout/indicator branch and both own continuations.422994 still
precedes labels, notices, present, enabled queued sound and the actual ret4.
