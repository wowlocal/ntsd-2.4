# Original window input callbacks

Status: declared input corpus accepted in raw and packaged native comparisons.
Actual coverage and retained boundaries: [WINDOW_INPUT](WINDOW_INPUT.md).
No Windows/device or complete WndProc-message acceptance follows.
Parents: [MAIN_MENU](MAIN_MENU.md), [MENU_PRESENTATION](MENU_PRESENTATION.md),
[STARTUP_STORAGE](STARTUP_STORAGE.md), [WINDOW_INITIALIZATION](WINDOW_INITIALIZATION.md).

## Behavior, reference and need for low-level observation

Recover the original producer of acquired keyboard/mouse/joystick state before
the menu/match consumers. NTSDApp still runs the older practice input path;
its key mapping is not a substitute for the general original input mechanism.
This study executes whole WndProc43b3d0..43bc3e/ret16 for keyboard100/101,
mouse200..205, joystick3a0/3a1/3b5..3b8. The ESC branch includes both MessageBox
answers and actual4019b0/401d30/43d2a0/43d280 shutdown children, not a forced
negative answer. Enabled text entry executes whole4031d0..40325e/ret4.

Only the pinned original EXE SHA256
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c and bundled lib.dll
28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba execute, using
Unicorn2.1.4 after a fresh complete accepted library installation. Win32/COM/free
responses and resource tokens are declared harness inputs. No Windows API,
keyboard/device, host free, process termination or network action is performed.
This is not the interrupted CRT startup, actual Windows, or an initialized app.

Instruction/write traces are needed to recover keyboard write order, both
sequence recognizers, text counters and aliasing, signed wrapped joystick
thresholds, the exact return and cleanup order. Ordinary globals44d000..458440
and separate320-byte storage458440..458580 are compared with full bytes/masks.
The latter contains the312-byte text-entry record followed by two sequence
words; it is not imported wholesale from expected after-state. Replay slots
4588a8/4588ac have separate explicit allocation ownership.

## Finite acceptance criteria

1. Read-only byte-checked static decoding identifies dispatch tables and child
   bodies. Static instruction starts remain separate from actual executed PCs.
2. Capture all256 valid virtual-key values for keydown/keyup, editor inactive
   and enabled; enabled text indices0,5,298,299. Cover every reachable state of
   both recognizers with expected, repeated prior and mismatching keys. Include
   ordinary full key sequences on retained state from the real constructors.
3. Continue a long stream of supported ordinary keys from index0, including the
   first write of a terminating NUL into the editor's own current-length word.
   Trace that data-field overwrite exactly. No deliberate control-pointer,
   cookie, exception-record or protection mutation is part of this experiment.
   Do not inject an out-of-record index to manufacture a fault. If a real ordinary
   key stream leaves declared storage, retain the fault and stop that chain;
   native rejection/rollback is separate from a successful match.
4. Exercise all four joystick button bits on both devices, mixed old bytes,
   unsigned16 coordinates and signed wrapped quarter thresholds, including
   equality boundaries, reversed bounds and explicitly synthetic numeric limits.
   Mouse buttons must retain coordinates; mouse move remains unsigned16.
5. ESC confirmation covers absent/present sound, music and both replay buffers,
   ordered release/free/clear, distinct caller/global HWND values, ignored
   numeric failures, and caller return0 without DefWindowProc. Include NumLock
   key90's separate return and ordinary DefWindowProc return values.
6. Native comparisons cover full before/after bytes, defined masks and ordered
   requests. Native-only missing storage/ownership and late observer errors must
   roll back the encompassing call. External effects remain buffered until commit.
   Reuse the accepted shutdown routines and retain their existing comparisons.
7. Preserve atomic completed source records, verify hashes independently, compare
   raw native results before packaging, and verify packaged tests and old pins.
   Use an isolated committed native export excluding foreign transform work.

## Explicit remaining boundaries

Messages outside the declared input set are not silently passed through:
WM_MOVE/SIZE/DESTROY/ACTIVATEAPP/SETCURSOR, system keys/fullscreen recreation,
palette messages, DirectShow events400 and Winsock notification401 remain
separate WndProc dependencies. This does not claim the whole message procedure
for every message, actual callback reentrancy, text beyond recovered reachable
storage, initialized input-device provenance or Windows placement behavior.
The remaining whole procedure is recorded in the static inventory so these
consumers cannot disappear from the application join.

Mac input-event translation, current general runtime initialization, all menu/
game paths with bundled hooks, the native renderer/audio/loop, actual window
checks, a full Naruto/Sasuke District match, remaining content/network/replay,
Windows/device and clean-Mac requirements remain open. This input producer alone
must not be presented as the completed application or full tick/match.
