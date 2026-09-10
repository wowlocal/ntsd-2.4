# Whole controlled window and DirectDraw initialization

[OriginalWindowInitialization](../../native/Sources/NTSDCore/OriginalWindowInitialization.swift)
implements whole43bec0 and all its window, DirectDraw, surface, clipper and clear
children at the declared platform/helper-entry boundaries. All280 controlled
whole calls match12920320 global bytes, complete global write masks,4574 ordered
requests, returned interface tokens/releases and1182 structures with their field
write masks. The plan is [WINDOW_INITIALIZATION_PLAN](WINDOW_INITIALIZATION_PLAN.md).

This is **not** an initialized WinMain/CRT continuation or actual native/Windows
window/device test. Current NTSDApp still uses the older practice engine. The
independent [CRT startup](CRT_STARTUP_PLAN.md) remains stopped at Windows NLS.
The verified native request model is a dependency for the application connection.

## Original behavior and ordering

The controlled source first reproduces the complete accepted EXE-entry/lib.dll
installer case0, including all13 patches/62 bytes and full image evidence.
Then original43bec0 stores its instance in4554c0 and calls43bdd0. The entire
controlled call preserves code and DLL bytes. It executes501 EXE instruction
starts, zero DLL starts; synthetic Win32/COM adapters and the stopped return
boundary are excluded. The installer has its separate original-instruction scope.
Source traces contain2115 complete helper returns. Whole return is EAX1,
SP2000f004 and preserved EBX/EBP/ESI/EDI. CW037f stays unchanged; no native/Windows
FPU-status equivalence follows from these non-floating routines.

### Window requests

Windowed401b00 calls metrics7,8,8,4 in that exact order. It doubles the first
result, sums both separately sampled metric8 results and metric4, and uses
32-bit wrapped addition with global width44d78c/height44d790. Results go to
44d014/44d018. The two explicit size arguments supplied to the helper are unused.
The WNDCLASS requests style3, original procedure43b3d0, zero extra bytes,
the passed instance, icon32512, system cursor32512, null background, and both
menu/class strings `Marti`. RegisterClass's return is ignored. CreateWindowEx
requests exStyle0, style10cb0000, X80000000/Y5, computed width/height and title
`Little Fighter 2`. Successful creation calls UpdateWindow **before**43bdd0
stores the window handle in4546f4. This ordering matters for the still-open
synchronous Windows callback connection. Creation/placement/menu semantics
beyond those requested parameters have not been measured on Windows.

Fullscreen401bf0 samples metrics1 then0 for height/width and requests exStyle8,
style80000000 and origin0/0. It does not request a cursor or call UpdateWindow.
Its WNDCLASS.hCursor is never written: all232 fullscreen calls retain the four
explicit helper-entry backing bytes, with their field-write mask false.
Do not replace those bytes with a fabricated recovered cursor. Actual callback,
class registration, resource-menu and Windows handle provenance remain open.

The whole wrapper ignores nCmdShow. All280 controlled calls have zero actual
reads of the absolute caller show word; varied show inputs leave requests alone.
Both the inner successful windowed configuration and the outer wrapper call
ShowWindow(handle,5), yielding315 requests across the corpus.

### DirectDraw and surfaces

After a nonzero window handle,401000 requests DirectDrawCreate with null GUID
and outer object, storing a successful interface at457578. Windowed cooperative
flags are8; fullscreen flags are11hex. A fullscreen nonnegative cooperative
result precedes SetDisplayMode(global width,height,8). Preserve all debug strings
and their position relative to failure checks; windowed logs its mode even when
SetCooperativeLevel returns negative.

Windowed401110 requests a primary surface, then an offscreen back surface. It
reuses the same108-byte DDSURFACEDESC: size108/flags1/caps200 first, then flags7,
height/width and caps40. The untouched fields retain their earlier backing.
4011d0 creates a clipper, attaches HWND, calls primary.SetClipper, releases the
clipper, and shows the window. SetClipper's status and Release's count are ignored;
the global457584 pointer stays retained after Release. An earlier failure leaves
already-created interfaces in their observed state without invented cleanup.
The supplied format-word pointer is never written by this helper: retained
453e0c selects mode3 for zero and mode1 otherwise.

Fullscreen401300 first tries a primary/attached-back combination with two back
buffers, then one, then the plain-surface fallback.401090 sets flags21hex,
height/width, back-buffer count and caps4218; GetAttachedSurface receives caps4.
Failure after primary creation can be followed by another primary creation
without releasing the first. Preserve those requests and overwritten output
words; do not add cleanup the original did not request.

43e8e0 calls primary.GetPixelFormat into a32-byte local whose size word is set.
Its result/output is not used to decide whether to clear. Whole401250 then
requests Blt with null rectangles/source, flags1000400 and color0. It sets only
the size and fill-color words in100-byte DDBLTFX. GetPixelFormat failures remain
ignored; a negative clear result produces the original debug text and return0.
A successful clear returns1. The supplied43e8e0 arguments are not consumed.

### Preserve the original failure propagation

The internal43bdd0 returns0 or1, while43bec0 checks **negative**. It therefore
still calls ShowWindow and returns1 after internal failure. Eight controlled
CreateWindow failures consequently produce ShowWindow(0,5); no error popup or
cleanup branch runs. Native numeric responses preserve that behavior.

Likewise,401300 returns0 when its final surface fallback fails, but43bdd0 accepts
nonnegative and still selects display mode2. This also happens for a failed clear
in the appropriate fallback path:28 complete calls return0 from fullConfigure
and still store mode2. Fourteen failed GetPixelFormat calls continue to clear;
two failed SetClipper calls still release and show.

The539 decoded starts in the declared bodies include38 unexecuted starts:
30 at40137f..4013c5 require a negative43e8e0 result, and8 at43bed2..43beed require
a negative43bdd0 result. Both helpers return only0/1 in this contract. These
branches were neither forced nor counted as executed.501 reachable starts are
covered, not every possible Windows callback or device behavior.

## Storage, resource and rollback boundaries

All controlled globals are declared inputs from the installed image plus bounded
mode/dimension/metric/format/show stimuli. Every CPU/global API write reconstructs
the full after-state and mask:874 CPU stores and823 declared API output stores.
Native supplies its own staged globals. The callback responses provide interface
tokens; tests independently retain their ownership/release records. These are
not actual COM allocations, reference counts, Windows driver buffers or C++ ABI.

The1182 structures contain94588 bytes;23788 bytes are written fields. Remaining
bytes come from1057 declared helper-entry backings. Their masks describe fields
written by the current helper, **not** a recovered complete caller-stack lifetime.
The source captures backing at helper entry before its own field stores; native
never imports a completed expected descriptor. The shared primary/back descriptor
is constructed once and mutated in native state between the two requests.
Initialized WinMain scratch, API stack side effects and callback reentrancy remain
open. Unknown bytes must stay explicit until the consumer's needed provenance
is recovered; do not use this controlled contract as actual Windows pixel proof.

Three native-only trials reject a late second ShowWindow observer, missing pixel
scratch and missing successful DirectDraw output. All roll back the entire global
state. They are explicit adapter/provenance failures, not matching original
memory faults. Buffer external platform effects until the operation commits.
No original memory fault, control-pointer/security mutation or safety refusal
occurred in this study.

## Capture history and acceptance

The initial two exploratory calls completed and are preserved as
`build/research/window-initialization-probe1.json` with their source version.
That exploratory profile supplied zero RegisterClass/UpdateWindow/ShowWindow
results; the final corpus includes explicit failures beside successful defaults.
Neither the original game rules nor existing expected results were changed.

The first full-suite driver stopped with a TypeError when a duplicate context
returned no cached case. Its process was terminal before continuation. The last
atomic checkpoint retained50 complete calls unchanged. Calls after that checkpoint
were not serialized before the driver failure; that limitation is recorded in
`window-initialization-attempt1.json`. The corrected driver resumes those50 exact
records and checkpoints every newly completed call. Final280 cases are identical
to the terminal280 checkpoint; the independent verifier confirms the first50
are unchanged. No live or completed source job was restarted for silence.

Raw release5 tests pass22.959s/build178.13s on the first native build: all280 calls,
three rollback trials and both retained startup-storage tests. The539-file native
export is committed6570660 plus only the two new native files, excluding concurrent
transforms. Final packaged5 tests pass20.203s without NTSD raw overrides; the
540-file export adds only the new fixture and preserves all earlier exported bytes.
NTSDNative links; this does not exercise its window or a sound/display device.

Raw83756823 bytes pack losslessly to2905776. Complete raw/packed bytes, JSON,
lengths, newlines and SHA256 verify independently, with all210 earlier fixture
pins unchanged and211 current. All10 replay-codec vendor hashes remain unchanged.
Transport deflation is fixture packaging, not a replacement game codec.
All owned source/SwiftPM jobs are terminal; exact PIDs, sessions, versions and
results are in `build/research/window-initialization-work.json`.

[Source](../../tools/oracle_window_initialization.py),
[verifier](../../tools/verify_window_initialization.py),
[tests](../../native/Tests/NTSDCoreTests/OriginalWindowInitializationTests.swift),
[packer](../../tools/accept_window_initialization.py),
[evidence](../evidence/window-initialization.json).
Full CRT/NLS/MSVCP80, WinMain/callback/worker composition, real window/device/
Windows checks, library-enabled full match, original content and clean-Mac
acceptance remain open.
