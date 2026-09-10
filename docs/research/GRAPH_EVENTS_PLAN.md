# DirectShow graph notification loop

Status: finite scope accepted in [GRAPH_EVENTS](GRAPH_EVENTS.md):371 whole
callbacks,4 initializers and5 own retained notifications; final13 packaged tests
passed40.526s/build0.26s. Source/native comparisons remain distinct from Windows,
audible looping and full application acceptance. Parents: [MUSIC_PLAYBACK](MUSIC_PLAYBACK.md),
[WINDOW_LIFECYCLE](WINDOW_LIFECYCLE.md), [WINDOW_INPUT](WINDOW_INPUT.md).

Recover whole WndProc43b3d0 message400 through actual401e90..401f20 and ret16.
The helper drains graph events, seeks the music position to binary64 positive
zero on event1 and frees event parameters. This is needed to preserve original
music looping and callback order in the general native application. Capture
whole401c90 graph creation as its own producer, then retain its resulting
interface state across notification calls. Reuse native music initialization
and seek behavior; do not copy expected pointer globals into an own continuation.

Pinned original NTSD EXE SHA256
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c and lib.dll
28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba execute in
Unicorn2.1.4 after the full accepted installer. Controlled CoCreate/QueryInterface,
GetEvent/seek/free/DefWindowProc responses and nonzero owned interface tokens
are explicit adapter boundaries. Actual Windows event queues, codecs, audio
hardware, callback/thread reentrancy and CRT/WinMain are not emulated facts.
No real device, process, network or host memory release is operated.

Low-level traces establish the64-byte aligned local frame, three live output
words, the reversed physical order of parameter1/parameter2, API writes versus
caller reads, x87 FLDZ/FSTPQ bytes and exact loop termination. Do not replace
arbitrary negative HRESULTs with an invented empty queue or invent successful
API outputs. Local helper-entry backing is declared input, not recovered full
application stack provenance. Missing native provenance must remain explicit.

Finite acceptance:
1. Execute whole message400 callbacks with empty, one-event and multi-event
   queues, event1 and other signed32-bit codes/parameter bits. Test0/1/positive/
   negative GetEvent results and exactE_ABORT termination. Vary seek/free results;
   preserve their ignored status and DefWindowProc's original four arguments.
2. Exercise all subsets of the three output writes, including retained values
   between successful/failed reads and output writes on the terminalE_ABORT.
   Capture before/after full local frame, API masks, full globals and exact
   requests. Controlled initial backing remains a separate declared contract.
3. Original401c90 creates/query-initializes the native-own graph interfaces and
   installs message400 notification. Continue repeated notifications using their
   own native global output. Initialized window token is a declared input here;
   this is not a completed window/graph/WinMain or playing-file chain.
4. Observe source entry/exit control/status/tag and each original seek's exact
   +0 binary64 bytes. Do not infer Windows/hardware/process-FPU equivalence from
   Unicorn. No signaling-NaN or deliberately corrupted FPU/security state.
5. Native-only missing required local/interface data, provider exhaustion and
   late observers must reject/roll back the whole callback. Buffer external
   effects. Do not manufacture source null-COM faults or an infinite queue;
   absent/bad interface reachability and nonterminating API behavior stay open.
6. Preserve atomic source cases/blobs; raw native acceptance precedes packing.
   Verify original bytes, parent, frame reconstruction, all raw/packed JSON/SHA,
   old fixtures, codec vendor files and isolated export excluding foreign work.

Winsock401/402ec0, actual nested delivery during window APIs, full CRT/NLS,
lib-enabled runtime composition, macOS events/renderer/audio and complete match/
content/network/replay/Windows/device/clean-Mac acceptance remain open. Passing
this event dependency does not establish actual audible looping or finish the goal.
