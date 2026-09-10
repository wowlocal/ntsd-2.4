# Original window lifecycle and display recreation

[OriginalWindowLifecycle](../../native/Sources/NTSDCore/OriginalWindowLifecycle.swift)
matches318 whole lifecycle-message callbacks of43b3d0 and two separate whole
window initializations. Two controlled chains preserve their own18 subsequent
callback results. Full14770944 storage bytes and defined masks,3624 requests,
1757 ordered stores/7444 written bytes, replay allocation lifetime and interface
release records agree. The finite scope is [WINDOW_LIFECYCLE_PLAN](WINDOW_LIFECYCLE_PLAN.md).

This supplies window lifecycle decisions for the general native engine. NTSDApp
still uses the practice engine. API responses and message delivery remain
controlled; actual window/device/Windows checks and full application composition
are not proved by this comparison.

## Reference, environment and evidence

The pinned original EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
bundled lib.dll SHA256 is
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
The [source harness](../../tools/oracle_window_lifecycle.py) first reproduces the
whole accepted installer case0, then executes original callbacks and all display/
sound/music/replay children with Unicorn2.1.4. Original code and DLL images stay
unchanged. Win32/COM/free responses, interface tokens, rectangle outputs and
helper-entry backing are declared inputs. No real Windows window, COM object,
device, host heap free, process exit or network operation is performed.

Instruction, stack and store observations recover live global state and the
ordering of destruction, recreation and failure propagation. The corpus executes
809 original EXE starts, including185 WndProc starts, and zero DLL starts after
the separate installer. Its1616 source helper returns include318 whole callbacks,
140 each display-release/destruction children and142 display creations. Callback
returns useSP2000f014; the two initializer returns useSP2000f004. Saved EBX/EBP/
ESI/EDI survive, and supplied CW023f remains unchanged. These are controlled
source observations, not private C++ ABI or initialized Windows FPU equivalence.

Combined with immutable [WINDOW_INPUT](WINDOW_INPUT.md),567 of576 static WndProc
starts have executed. The nine remaining starts are six at43b98f..43b99a for
Winsock402ec0, one at43bc1f for DirectShow401e90, and two at43b88a/43b88f requiring
a negative43bdd0 result. The latter actually returns0/1 in this contract. This
is an instruction inventory, not every branch outcome or complete WndProc.
Network/music notifications remain explicit required dependencies.

## Original lifecycle behavior

### Display-mode changes

System-key-up105 handles Enter13. It logs `Alt enter...` before checking44d794.
If that word is zero, the call continues directly to DefWindowProc. Other keys
skip that debug request too. The procedure does not inspect lParam's Alt flags;
translation of macOS modifier/key events is a separate application task.

When enabled,43b86a stores458434=1 before setting458430 to whether its old value
was zero. Every nonzero old mode becomes0. Actual401ae0 calls401a80, then calls
DestroyWindow only if global4546f4 is nonzero. Destruction does not clear that
window word, and its numeric return is ignored.

401a80 first checks DirectDraw457578. If it is zero, both surface words remain
untouched. Otherwise it releases nonzero back455608, clears it, then releases
nonzero primary455634 and clears it, then releases and clears457578. All numeric
Release results are ignored. Palette4554c4 and retained clipper457584 are not
released or cleared by this function. The corpus covers all eight presence
combinations of these three display words with declared valid resource tokens.

The caller then executes whole43bdd0, including its actual windowed/fullscreen
window, DirectDraw, surface fallback, clipper and clear children. Native now
exposes this internal operation as `OriginalWindowInitialization.configure`.
The existing43bec0 API shares the implementation while retaining its own extra
instance store and ShowWindow. A fullscreen toggle does not acquire those extra
wrapper operations. Instance comes from the caller's retained4554c0.

43bdd0 returns0 or1, but this caller checks for a negative result. It still
requests ShowWindow(global4546f4,5), clears458434 and reaches DefWindowProc after
an internal0. Nineteen recreation calls demonstrate that ignored0 path, including
failed window/DirectDraw/surface setup. The unreachable negative debug branch is
not forced or counted as covered. Existing retry order, retained interfaces after
failed creation, ignored clear errors and display-mode selection remain those
of [WINDOW_INITIALIZATION](WINDOW_INITIALIZATION.md).

DestroyWindow and UpdateWindow are explicit API boundaries here. The harness
does not deliver nested WM_DESTROY or WM_MOVE while those APIs are pending.
Actual synchronous message delivery, reentrancy, class registration and device
lifetimes still require their own initialized/Windows evidence. The surrounding
458434 flag and the separately executed destroy callback cannot by themselves
prove that whole operating-system connection.

### Movement, size, activation and cursor

Window move3 ignores the message's coordinates. In fullscreen it samples metric1
(height) before metric0 (width), then requests SetRect at453ccc with0/0/width/
height. In windowed mode it requests GetClientRect(HWND,453ccc), then
ClientToScreen(HWND,453ccc), then ClientToScreen(HWND,453cd4). Thus both corners
use the latest rectangle bytes. Numeric API failures do not stop the sequence.
All three API output contracts explicitly supply changed bytes or no write;
the native model applies those outputs without fabricating successful geometry.
The56 rectangle/point requests compare672 bytes of live request backing.
Move then returns the original four-argument DefWindowProc result.

Size5 with exact wParam1 requests InvalidateRect(HWND,NULL,1), writes451dac=0,
and returns0. Every other tested wParam writes451dac=1 and returns0, without
DefWindowProc. Activation1c only logs exact bytes `Active App!\n `, then reaches
DefWindowProc; it does not toggle an activity word according to wParam.
Cursor20 calls SetCursor(NULL) only for nonzero458430, but returns0 in both
branches. System-command112 returns1 only for exact f100. f101 and other values
reach DefWindowProc; no standard-command low-bit masking is added.

### Palette and close

Query-palette30f requires both primary455634 and palette4554c4 nonzero. Then it
logs `We have the palette.`, requests primary method+7c(palette), ignores the
result and reaches DefWindowProc. If either word is zero, it logs the original
ignore text and returns1. Palette-changed311 from this same incoming HWND skips
work and reaches DefWindowProc. An external HWND logs `Palette lost.`, then
calls primary+7c with the live palette, even when that palette token is zero.

Unlike30f, external311 has no primary null check in the source. The controlled
source cases supply valid owned primary tokens for that dereference. A null
primary at this notification remains a static possible fault whose ordinary
Windows delivery/reachability is not established. It was not manufactured or
counted as a successful source match. Native missing-primary storage is rejected.

Destroy2 always runs the original sound, music and replay release children.
Their existing order is retained: catalog sounds, builtins, sound device, four
music interfaces, first replay free/clear, second replay free/clear. Only after
that cleanup does it read458434. Zero requests PostQuitMessage(0); any nonzero
value suppresses that request. The callback returns0 in both cases and does not
reach DefWindowProc. It does not call the display-release helper itself.
Numeric release/free/PostQuit results are ignored. The shared native resource
cleanup remains the one used by menus and ESC input, preserving their contracts.

## State, structures and retained chains

Independent controls begin from explicitly declared globals44d000/0xb440 and
eight replay-pointer bytes4588a8/8. API adapters carry distinct interface families,
returned tokens and release records. Native tests retain their own adapter audit
of those tokens across calls, alongside core replay allocation ownership; this
is not actual host COM/device reference counting.

The two own chains first run whole43bec0 in windowed/fullscreen mode respectively,
then retain each native output through move, minimize/restore, cursor, palette,
two SYSKEYUP-Enter changes, another move and final destroy. Each next before-state
is independently checked against that native prior output. Message delivery and
initial feature/palette values remain explicit stimuli. No source after bytes
are imported to initialize a native continuation.

There are567 window/display structure requests containing45868 bytes, of which
11652 are helper-written fields. Their masks are reconstructed from the original
479 helper-entry backings. The windowed primary/back descriptor is reused live.
Unknown fullscreen cursor and other untouched frame fields retain their declared
backing. This does not recover their complete WinMain stack lifetime. Rectangle/
point request bytes above are checked separately from these helper descriptors.

All source stores reconstruct complete after-state and masks:1235 CPU stores and
522 declared API writes. Native preserves their combined order relative to every
request, including ignored failures and zero-valued writes. Allocations retain
their bytes when marked dead at the declared free boundary.

Four native-only trials reject the late DefWindowProc after recreation, missing
surface-description backing after display release, the late PostQuit after both
replay frees, and missing ownership of the second replay allocation. Each rolls
back full globals, replay pointers, allocation bytes/masks and liveness. Callers
must buffer external effects until the encompassing operation commits. These
adapter errors are not original crashes or successful source-fault matches.

## Acceptance and remaining work

A six-call exploratory probe completed, followed by the complete320-case capture.
All320 atomic case records and117 base64/SHA-identified blobs reproduce the final
raw corpus. No source memory fault, control/security mutation, safety refusal,
source restart or native rule correction occurred. Raw release acceptance passed
all nine tests in23.532s/build177.11s, including retained280 initializations and
4369 input callbacks plus their rollback checks. New lifecycle tests took0.372s.
NTSDNative linked; no application window was exercised.

Final packaged verification passed nine tests in23.195s/build0.28s without a
raw override; lifecycle tests took0.333s. All owned source/SwiftPM jobs are
terminal0. One fixture preserves all212 previous pins, making213. Full raw
11531205 bytes have SHA256
`626b6b3db20b47fac621755cc204f1d0959650b30087d7c690f1cb9b845da14f`;
packed733592 bytes have SHA256
`0ff7c4899ba1b832338037131dff60373ee0e71be6db9ed282415fb1ff2008cc`.
The isolated export has546 files and excludes unfinished foreign transforms.
All10 codec vendor hashes remain unchanged. Results and immutable pins are in
[window-lifecycle.json](../evidence/window-lifecycle.json) and
`build/research/window-lifecycle-work.json`. The independent verifier checks
original instruction bytes, the complete installer parent, own before-states,
store/request order, frame fields, all raw/packed JSON/bytes/SHA, prior fixtures,
codec vendor files and the isolated native export. Transport deflation only
packs the research fixture. No EXE, DLL or interpreter enters native runtime.

Next required message consumers are DirectShow400/401e90 and Winsock401/402ec0.
Input events retain the separate accepted WINDOW_INPUT contract. The public
lifecycle API rejects those specialized messages instead of treating them as
ordinary defaults. Actual callbacks during window APIs, CRT/NLS/WinMain, library
routing/transforms, macOS event translation and renderer/audio/loop ownership
remain open. The practice app, full Naruto/Sasuke District match, all content,
network/replays, Windows/device checks and clean-Mac acceptance are not complete.
