# Initial keyboard/joystick state, sound and own callbacks

[OriginalInputStartup](../../native/Sources/NTSDCore/OriginalInputStartup.swift)
implements whole43bf10 and the complete43d078..43d100 input/sound caller.
**56 complete native segments match and1900 subsequent joystick callbacks use
their own produced bounds. Four further source returns are explicit native
rejections for unknown capability fields, with rollback.** They are not60
successful native startup matches. The finite plan is
[INPUT_STARTUP_PLAN](INPUT_STARTUP_PLAN.md).

This extends [MENU_SOUND_STARTUP](MENU_SOUND_STARTUP.md) upward: the source now
executes the three memset arguments and actual joystick initializer before
the device and five shared WAV loads. It then invokes complete
[WINDOW_INPUT](WINDOW_INPUT.md) joystick messages using the resulting globals.
No callback bound or preceding expected after-state is imported into native.
The production Practice app remains separate from these original startup APIs.

## Reference and controlled environment

Only the pinned original EXE and five original menu WAVs are used. EXE SHA256
is `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Unicorn2.1.4 executes the original instructions, including real child returns.
WinMM, DirectSound, DefWindowProc and retained allocator/copy adapters are
explicit boundaries. No Windows sound/input DLL, device, OS message delivery,
full WinMain/CRT or private Windows allocation equivalence is claimed.

The58-case main corpus includes ignored error results for threshold/capture.
Two additional fresh controls supply successful position, threshold, capture,
capabilities and cooperative-level results. The main raw corpus remains
unchanged. These two controls add228 of the1900 callbacks, but the callbacks
are still direct controlled invocations, not measured WinMM event delivery.

The whole studied ranges are disjoint from all13 accepted bundled-library
patches. The controlled source does not execute the DLL installer; the broader
initialized library/CRT chain and Windows NLS dependency remain open.

Entry and end SP are both1000f00c. Caller43d078 pushes count100hex, value75hex
and destination455378, executes the memset boundary, then calls43bf10 while
those arguments remain pending. The joystick helper returns at43d08e/SP1000f000.
The later sound caller removes those12 bytes with its own HWND argument.
End43d100 is unexecuted and is not a WinMain return or a completed message loop.

## Exact initial writes

The caller fills **256 bytes**455378..455477 with117. The remaining44 bytes of
the300-key region retain their prior state. The native implementation does not
expand that fill to the full region used by later key scans.

43bf10 initializes four48-byte joystick records starting453fd0. For each record
it first reads byte+23hex (left direction) and copies it, in order, into+22,
+21,+20 (right, down, up). The original byte may be nonzero or a retained
non-boolean value; it is copied exactly. It then clears, in order, words+0,
+1c,+18,+24 and the16-bit field+28. These are21 written bytes per record.
Identifier+4, bounds+8..+14, the original left byte and remaining fields are
untouched unless a later device query writes them.

The initialized active flag, X/Y and buttons do not imply initialized bounds.
Both backing patterns preserve all unrelated bytes and complete global masks.
The four-record loop is followed by joyGetNumDevs. Zero skips all probes;
any nonzero count probes exactly IDs0 and1, even when the supplied count is1.
The two other records remain in their partially initialized state.

## Device requests and shared backing

The source clears one52-byte JOYINFOEX, sets size52/flags83hex, and passes that
same structure to both joyGetPosEx calls. API-written fields from the first
call survive into the second request. Only result167 skips the device. Other
results, including ordinary nonzero error controls, still activate it.

For an accepted device ID the order is:

1. Store active1 and ID0/1 into its global record.
2. Request joySetThreshold(ID,100).
3. Reload HWND4546f4 and request joySetCapture(HWND,ID,25,1).
4. Request joyGetDevCapsA(ID,shared404-byte backing,404).
5. Read Xmin/Xmax/Ymin/Ymax from offsets36/40/44/48 and write globals.

The numeric threshold, capture and capabilities results are ignored. The
capabilities structure is not cleared between IDs. A failed second query with
no output consequently reuses the first query's **own** written values. That
case matches natively and its later messages consume those retained bounds.
Controls supplying output even on a failed API result are explicitly declared;
they do not establish that a Windows driver does so.

Midpoints use signed32-bit wrapped sums and division truncating toward zero.
Global write order is Xmin, X midpoint, Xmax, Ymin, Ymax, Y midpoint. Original
coordinates/ranges, reversed bounds and signed-boundary controls preserve this
order and arithmetic. The helper's otherwise ignored EAX is retained:0 with no
devices,167 after an unplugged final probe, or the final Y midpoint after caps.

All complete52-byte request images match. Source preserves the full404-byte
capability backing and masks at every checkpoint. Native begins that private
backing unknown, applies only actual API output bytes, and compares every
defined byte plus the complete mask. Unwritten raw stack bytes are not imported
or claimed to match. Source has100 capability checkpoints across both corpora;
native reaches98, including the four checkpoints before its explicit rejection.

## Unknown reads and transactional limits

Four ordinary error controls supply no capability output before the first
needed fields have been produced: first-device failure, or first unplugged and
second-device failure, under both backing patterns. Source executes16 reads of
unknown32-bit fields, then returns through the full caller using its retained
mapped stack bytes. This is an unknown-provenance observation, not a memory
fault or recovered Windows calibration.

Native stops on the first offset36/count4 read and rolls back the entire
input/sound operation. It does not import those source bytes or run the later
sound loads in these four cases. The first22 combined request events and exact
stores up to these boundaries compare separately; the336 later source events
are retained but not counted as native matches.

The56 supported segments match4758 startup events and280 complete WAV results,
including all PCM/masks/format/descriptor/temporary ownership from the shared
loader. Together with the22 rejected-prefix events, native observes4780 startup
events. All source60 segments contain300 WAV returns; only280 are matched by
this native whole-segment contract. The earlier complete WAV/menu-sound corpora
keep their separate, unchanged coverage and failure contracts.

## Own callback composition

Eighteen main-corpus initialized states and two successful-API states feed
1900 complete3a0/3a1 and3b5..3b8 callbacks. Coordinates include unsigned16
extremes and neighbors of the actual producer's signed wrapped quarter
thresholds. Button controls preserve the existing set-present/clear-absent rule.
Every native callback begins with its preceding own global state; full bytes,
write masks, ordered stores, DefWindowProc arguments and ret16 agree.

The local text and replay records remain unknown in native because these
joystick branches do not consume them. No unrelated local backing is imported.
Late failures at capabilities, after the fifth WAV return, and at a later
callback's DefWindowProc verify rollback. External effects must be buffered
until the encompassing operation commits.

There are645 actual EXE instruction starts:32 caller,127 joystick initializer,
19 device,278 WAV,185 WndProc,3 cookie check and1 import thunk. All32 caller and
127 joystick starts execute. The1116 static starts also include other WAV and
WndProc branches; their unexecuted inventory is separate. API/copy boundaries
and stopped addresses are excluded. CW037f remains the supplied source value;
no native process-FPU or Windows CPU equivalence follows.

## Acceptance and artifacts

The three-case initial probe and final58-case source capture complete without
source faults. Every completed case has an immutable atomic checkpoint. The
additional two-case success corpus preserves the whole main corpus unchanged.
The first native test compile needed the existing replayPointers initializer;
the records are now explicitly unknown, not fabricated as owned replay data.
The verifier's initial byte parser omitted the last byte of a long objdump line;
tab-separated bytes are now parsed completely. Neither correction changed
native input rules or original expected bytes.

Main raw8 tests passed10.991s/build52.60s. Both-corpus raw8 tests passed11.332s/
build51.48s, retaining the112-match/10-rejection menu-sound study,409-file WAV
corpus and4369 whole window-input callbacks. The isolated native export begins
with573 committed files and excludes the six untouched foreign transform files.
The two new native files and two fixtures bring it to577 files.
Final packaged8 tests pass10.981s/build0.25s without raw overrides. All owned
source, native and app processes are terminal.

Main raw14379356/packed4654908 bytes and supplemental raw3051536/packed2018943
bytes preserve complete JSON, SHA and all1914/309 blobs. All226 old fixture pins
and10 codec vendor hashes remain unchanged; there are228 current fixtures.
The supplemental blobs may share hashes with the main corpus; they are not
claimed to be2223 distinct buffers. Transport deflation is fixture packaging.

The current Practice window launched, but CUA failed with
`Sky Computer Use native pipe startup failed` before any input action. The app
PID was verified live before intentional termination. A separate built-in
AppKit/SpriteKit render then showed District, Naruto/Sasuke and HUD and exited0.
This does not verify the new input startup in the app, input latency or sound.

[Main source](../../tools/oracle_input_startup.py),
[successful controls](../../tools/oracle_input_startup_success.py),
[verifier](../../tools/verify_input_startup.py),
[packer](../../tools/accept_input_startup.py),
[tests](../../native/Tests/NTSDCoreTests/OriginalInputStartupTests.swift),
[main evidence](../evidence/input-startup.json),
[successful evidence](../evidence/input-startup-success.json).
Jobs and corrections are retained in `build/research/input-startup-work.json`.
Full WinMain/CRT, menu/application wiring, actual device/input/latency/Windows,
complete matches/content and clean-Mac acceptance remain open.
