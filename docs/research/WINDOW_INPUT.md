# Original keyboard, mouse and joystick callbacks

[OriginalWindowInput](../../native/Sources/NTSDCore/OriginalWindowInput.swift)
matches **4369 whole input-message calls** of43b3d0 through its actual ret16,
plus **three separate text constructors**. Comparisons cover203184416 declared
storage bytes and defined masks, all global/local/replay write masks,5908 ordered
platform requests and23835 stores/50118 written bytes. The385 retained calls use
the preceding native output. They are controlled input streams, not a full
initialized application chain. The finite plan is [WINDOW_INPUT_PLAN](WINDOW_INPUT_PLAN.md).

The current application still uses its practice engine. These callbacks are a
verified input producer for the general engine; they do not connect macOS events,
finish every WndProc message, run Windows or prove a complete match.

## Reference and execution boundary

The pinned original EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
bundled lib.dll SHA256 is
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
The [source harness](../../tools/oracle_window_input.py) uses Unicorn2.1.4 and
first reproduces the entire accepted library-installer case0. Original text,
sound/music release and replay cleanup instructions execute. Windows API, COM
and CRT-free imports stop at explicit adapters with supplied numeric results,
synthetic interface tokens and declared allocation backing. No host window,
keyboard, joystick, sound device, heap free, process termination or network
operation occurs in this experiment.

Instruction and store traces recover the exact text/keyboard/recognizer order,
self-aliasing data writes, signed wrapped joystick calculations, caller HWND,
cleanup and return behavior. Calls execute561 distinct original EXE starts,
including424 in WndProc, and zero DLL starts after the separate installer.
The5822 observed helper returns include4369 WndProc,1387 text-input,12 sound,
12 music,24 single-buffer,12 replay-pair and3 each constructor/initializer returns.
These are source return/stack observations, not a private native C++ ABI claim.
Every WndProc returns atSP2000f014; the constructors return atSP2000f004.
Saved EBX/EBP/ESI/EDI survive. Supplied CW023f remains unchanged; CRT/Windows
FPU initialization and process status are not established by these callbacks.

A corrected complete static decode has576 starts through the three-byte ret16
at43bc3e. The earlier exploratory inventory stopped before those last bytes and
is retained separately. The152 unexecuted static starts are not dynamic coverage;
other message bodies and branch outcomes remain outside this corpus. The static
child inventory also contains exploratory neighboring/truncated ranges and must
not be called whole-child instruction coverage.

## Input behavior

Keyboard messages use valid virtual-key values0...255. Every value is captured
for keydown100 and keyup101; enabled keydown also covers indices0,5,298,299.
The keyup corpus starts with inactive text input. Its executed path writes one
keyboard byte and reaches DefWindowProc without accessing the editor or either
sequence word; enabled keyup is not a separate dynamic series here.

On keydown, active word458440 must equal exactly1 to run4031d0. The editor runs
before byte455378+VK becomes100, then the first sequence recognizer runs before
the second. On keyup that keyboard byte becomes117, without editor/recognizers.
Ordinary calls send the original HWND/message/wParam/lParam to DefWindowProcA
and preserve its returned32 bits. NumLock VK90 returns0 without that request.
Other virtual-key values, host key-code mapping and Unicode/layout conversion
are outside the recovered input domain.

The first recognizer uses45857c and virtual keys for `LF2.NET`; the second uses
458578 and `HEROFIGHTER.COM`. A matching next key advances its state; repeating
the immediately previous matching key retains the state. A mismatch resets0
without reprocessing the same key. Completion leaves the last state6/14 and
writes100 to455471/455470 respectively: keyboard-array sentinel indices249/248,
not a conversion to ordinary F9/F8 virtual keys. Each reachable recognizer state
has expected/repeated/mismatching controls. Full sequences use retained native
state, beginning with explicitly declared zero sequence words; the text
constructor itself does not initialize those words.

### Text data alias

Whole4031b0 clears only active+0, current index+130 and total input count+134.
The300 bytes at+4 are retained. Whole4031d0 accepts space, dotVKbe, digits0...9
and **B...Y**. A and Z are not accepted. It writes the character at+4+index,
increments total, increments index, rereads index and writes a terminating NUL.
Backspace decrements a positive signed index and writes NUL without reducing
total. Enter clears active. Other keys leave the editor alone.

At prior index299, the character fills+12f and the index becomes300. The NUL
address is then+130: it overwrites the index's low byte, leaving256. Preserve
this actual data-field alias. An ordinary retained360-B stream from index0
crosses it twice, at case4284 and4328, ending index272/total360. Two backspaces
leave270/360; Enter clears active. Activation before the first B is an explicit
controlled stimulus, not a recovered producer in the full application.

No control pointer, cookie, exception record or protection structure was changed.
No original memory fault or safety refusal occurred. The stream stays within
the declared record; this does not authorize or claim arbitrary corrupted-index
behavior. Unknown or out-of-owned-storage accesses remain explicit native errors.

### Mouse and joystick

Mouse200 zero-extends both16-bit lParam halves, storing X4546f0 before Y453cdc.
201/202 set/clear left457580;204/205 set/clear right4527e4. Double-click203 changes
nothing. Button messages do not update coordinates. Every selected mouse message
continues to DefWindowProc. The earlier450-message menu comparison now uses the
same native mouse implementation.

Joystick1 starts at453fd8, joystick2 at454008. Four bounds words precede X/Y at
+10/+14; byte flags up/down/right/left are+18/+19/+1a/+1b, buttons+1c...+1f.
Move3a0/3a1 stores unsigned16 X/Y, then clears right,left,down,up in that order.
Lower X threshold is signed wrapped `(3*left+right)/4`; upper is
`(left+3*right)/4`, with division truncating toward zero. Y uses top/bottom.
Less than lower selects left/up; otherwise greater than upper selects right/down.
Equality is neutral. Reversed bounds retain that branch priority. The corpus
includes threshold neighbors, unsigned16 extremes and explicitly synthetic
signed-overflow bounds, not a joystick-device calibration measurement.

Button-down3b5/3b6 sets only the present low four bits' bytes to1. Button-up3b7/3b8
clears only absent bits' bytes to0. Other bytes retain their previous values;
move messages do not update buttons. All paths continue to DefWindowProc.

### ESC and shared shutdown

ESC still performs the editor/keyboard/recognizers first, then requests
MessageBoxA with incoming HWND, flags4 and exact strings `Are you sure to quit?`
and `LF2`. Only answer6 executes cleanup and PostMessageA(HWND,10,0,0). Other
answers return0 directly. Every ESC result skips DefWindowProc.

Actual4019b0 releases catalog entries452948/count458438 before builtins451db0/
count45843c, then device44eecc and its clear. A zero device skips the two lists;
stale list pointers and counts are retained. Actual401d30 releases and clears
44f04c,44f048,44f044,44f040 in that order. Actual43d2a0/43d280 frees and clears
4588a8 before4588ac. Numeric Release/free/post results are ignored. Tests cover
full400/80 lists and both replay-presence combinations. Declared64/128-byte replay
backings are sufficient for this free boundary; these are not full own replay
allocations or actual CRT heap lifetimes.

WndProc posts to its **incoming HWND**, which deliberately differs from global
4546f4 in this corpus. The menu shutdown keeps its existing global-HWND behavior.
Both now share release children; the new store observer exposes clears between
requests without changing the earlier menu/music behavior.

## Native storage and failure contract

Full globals44d000/0xb440, separate local458440/0x140 and replay pointers4588a8/8
are declared inputs for independent controls. The local extent includes the312
text bytes/fields and two sequence words. Allocation bytes and live/dead states
are compared too. Source stores independently reconstruct all after bytes and
write masks. Native defined masks remain complete for supplied storage; expected
after bytes never initialize a retained native continuation.

Three constructor cases seed their declared backing before actual constructor
execution. The385 retained calls carry their own native prior output, with only
the first text activation supplied separately. This proves those streams, not
actual CRT/WinMain storage provenance or whole application callback reentrancy.

Native-only trials throw at the late post after both frees, remove second replay
ownership, throw at the NUL/index store, and remove a required index byte's
defined mask. Each rolls back globals, local bytes, pointers and allocation
liveness together. These are adapter/ownership failures, not original crashes
or successful source-fault matches. Callers must buffer external effects until
the encompassing operation commits.

## Capture and verification

A12-call exploratory probe is retained unchanged. Before the full capture, the
driver replaced repeated growing-corpus writes with atomic per-case journals.
The final4372 case files and4228 immutable blob entries exactly reconstruct the
full corpus. All source processes are terminal0; the completed corpus must not
be restarted for silence. The verifier checks every original instruction byte,
full installer parent, store/request order, storage reconstruction, allocation
lifetime, both own aliases and retained continuations.

The first isolated release build compiled and linked NTSDNative in176.09s. All
six retained menu/presentation/music/startup tests passed. The three new tests
failed before native comparison because their reader passed zlib-framed inner
blobs to the shared raw-DEFLATE decoder. The first log, reader and export pins
are preserved. Only the new test reader was corrected: it checks framing,
Adler-32, length and SHA-256. No source result or native game rule changed.
Raw acceptance passed all three new tests in2.751s/build44.05s. Final packaged
verification passed all nine tests in59.951s/build0.24s, without a raw override;
new input tests took2.748s. All owned source/SwiftPM jobs are terminal; final
raw and packaged runs exited0. The first failed test invocation remains exit1.
Results and hashes are recorded in [window-input.json](../evidence/window-input.json)
and `build/research/window-input-work.json`.

The isolated native export excludes concurrent unfinished transform work. One
new fixture preserves all211 previous pins, making212. Independent verification
checks full raw/packed bytes, JSON, SHA, all4228 inner blobs, atomic case journals,
10 codec vendor hashes and all543 final isolated native files. Raw29400709 bytes
have SHA256 `13599d1f4cab88a67736994ca509d27fabd4673f57555c119e7f751423a05818`;
packed8260684 bytes have SHA256
`59764bcf501953d74d1ab17cf1a4544dc30cb74b75ef7ba4ead3d6587fbf8be4`.
Inner zlib framing and outer raw
DEFLATE are research transport only; native game compression remains the private
C1.1.4 implementation. EXE/lib/Unicorn never enter the shipping runtime.

## Remaining application dependencies

WM_MOVE/SIZE/DESTROY/ACTIVATEAPP/SETCURSOR, system-key/fullscreen recreation,
palette messages, DirectShow400 and Winsock401 are still separate WndProc
consumers. The native API explicitly rejects unimplemented message kinds. This
is whole return coverage for the declared input set, not the entire procedure
for all messages. Resource ownership, synchronous Windows callbacks, macOS input
translation, renderer/audio/loop and bundled-library gameplay composition remain
open. [CRT/NLS](CRT_STARTUP_PLAN.md) still needs actual Windows evidence under the
[Windows plan](WINDOWS_REFERENCE_PLAN.md); this input corpus does not provide it.
App-window/device checks, the full Naruto/Sasuke District match, all content and
network/replay sessions, Windows comparison and clean-Mac acceptance are pending.
