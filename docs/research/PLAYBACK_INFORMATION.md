# Whole playback information

`OriginalPlaybackInformation` implements41b390..41b5cc/ret12. All120 controlled
original calls match the native raw comparison, including actual VC80 sprintf,
423a70/423940 and bitmap/clip children. The native test passed0.645s after a
149.28s release test build. The late observer trial verifies whole-global rollback
after author/info rendering, both time formats and two passes of the time overlay.
The fixture is now published after the accepted result-recording/own comparisons
and preceding bitmap-font/mode-label dependencies.

## Recovered behavior

The initial row is155 for mode4 or133 otherwise. Ten-byte comparisons, including
the terminating NUL, decide whether44fd18 equals `<No name>` and44f900 equals
`<No info>`. REP CMPSB stops at the first mismatch. Do not read unavailable later
bytes just to implement the comparison as a fixed-size native slice. Author
presence draws `Author:` and the mutable author string with one line, then moves
Y by22. Info presence draws `  Info:` and its mutable string with four lines.

The actual four-pass font truncates author to at most64 consumed bytes and info
to at most256, with the original newline behavior. Those NUL stores modify the
live game globals; they are not edits to an independent display copy. The helper's
resource bindings stay separate from its possible font NUL destinations in this
contract. Initial author/info extents are declared research backing, not recovered
C-array sizes or proof of every corrupt overlapping-input case.

Current ticks are formatted first to450e98, recorded ticks second to450e30. Each
uses signed `(ticks + 15 wrapping to32 bits)/30`. Seconds below3600 use `%02d:%02d`;
the other branch uses `%02d:%02d:%02d`. Recorded time has the literal prefix ` / `.
Negative wrapped values preserve signed division/remainder and sign-aware minimum
width formatting. The caller appends recorded text including its NUL with actual
REP MOVSD/MOVSB, then draws the combined450e98 string at(5,510),64 columns/four lines.
No host date/time API, floating-point conversion or native runtime CRT is used.

## Original execution and comparison

[oracle_playback_information.py](../../tools/oracle_playback_information.py)
executes EXE and CRT on one controlled CPU atCW023f/FPSW0/tagffff. The pinned
CRT's initialized PTD is supplied as the declared C-locale/thread environment;
whole DLL/Windows startup and private caller-stack bytes are outside the native
comparison. Only existing PTD/locking/import and COM boundaries are intercepted.
The two initial source probes were terminal before the full capture. Source
formatter return records include exact arguments, literal, output bytes and count.

All200 caller instruction starts execute.980 actual PCs include562 EXE and418 CRT
instructions; hooked PTD/import boundaries and the unexecuted stop are excluded.
This is not every branch outcome or Windows hardware execution.32470 helper
returns preserve saved registers and stack cleanup.240 completed caller REP
copies separately verify DF0, count, ECX0, ESI/EDI advancement, full bytes and raw
write masks. These small-copy checks do not generalize away the separate codec
REP-observer limitation.

The native comparison covers full globals and actual store masks/order, all
157795 events,240 formatter outputs/returns and14766 Blts. Events include2497
caller/CRT stores,206 four-pass entries,824 passes/NUL writes,15728 draws,
107358 bitmap reads and15352 clips.468 bitmap reads retain undefined provenance.
All3321 source global stores cover4368 requested bytes. Numeric Blt failures are
ignored as in the source. External callbacks must be buffered until the whole
containing tick commits; native rollback does not undo already performed IO.

A build-only `swift build --build-tests` attempt first failed on an existing
`@testable` import because the core module lacked testing support. The normal
`swift test` command built and passed without changing implementation or expected
outputs. All playback-info source and SwiftPM processes are now terminal.

[accept_playback_information.py](../../tools/accept_playback_information.py)
passes `--verify-only`: complete raw JSON,155 transport blobs with length/SHA,
actual store reconstruction, helper ABI, format returns, REP evidence and
four-pass mutation are independently checked. Raw27219988 bytes have SHA256
`2ea900e61a1e4e70d2678d9d7ea97b7c64d7dcfafa431c0d65d144c1d4115088`.
Publication follows the preceding180 fixture pins and adds the181st. The shared
raw acceptance set passes this test in0.624s. All155 inner blobs and the1433480-byte
packed fixture are independently verified; evidence is
[playback-information.json](../evidence/playback-information.json). This helper does not join
the whole result layout/indicators or the initialized own tick. Those consumers
and remaining labels/notices/presentation/queued sound are tracked in
[RESULT_LAYOUT_PLAN](RESULT_LAYOUT_PLAN.md) and [TICK_TAIL_PLAN](TICK_TAIL_PLAN.md).

Final packaged verification: the ten-test release set passes58.142s after a0.23s
resource-copy build, without raw-corpus overrides. This study takes0.554s. All
source and SwiftPM jobs are terminal; full artifact/pin/vendor checks pass. This
does not establish an app-window, Windows or actual device result.
