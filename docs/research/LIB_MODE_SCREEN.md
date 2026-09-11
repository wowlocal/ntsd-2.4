# Mode screen with the installed library text helper

This study recovers whole431d10 with the bundled lib.dll replacement of401290.
The replacement requests transparent background mode1 and retains its DC only
after nonnegative GetDC. The pristine EXE helper instead uses background color.
Both routes now share OriginalModeScreen's input, drawing, strings, selection,
release and mouse-tail rules. The new public `advanceWithLibrary` stages globals,
bitmap/replay ownership, local bytes and OriginalLibSurfaceText together.

106 full returns and four playback continuations match native; two dependency
boundaries are separately rejected with rollback. Raw and packaged checks pass;
see the [evidence](../evidence/lib-mode-screen.json). This is a controlled study,
not the own installed-library catalog/menu chain or the native app connection.
See the finite [plan](LIB_MODE_SCREEN_PLAN.md), preceding continuous
[music/resource prefix](CHARACTER_MENU_MUSIC_SURFACE.md), retained
[MODE_SCREEN](MODE_SCREEN.md) and [library runtime](LIB_RUNTIME.md).

## Reference and controlled execution

Pinned original NTSD EXE SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`
and bundled lib.dll SHA256
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`
execute under Unicorn2.1.4. The existing research loader relocates the DLL to
36000000 and binds imports; actual DLL installer instructions request two
allocations4000/20000 and13 patches. VirtualProtect/RtlMoveMemory responses are
declared research boundaries, not measurements of Windows or host protection.
EXE/DLL execution remains development tooling, absent from native runtime.

The original screen begins at431d10 with actual prologue, rootSP1000f000,
bodySP1000e8e8, CW023f and declared nonvolatile registers. Normal return reaches
30000000/SP1000f014 after ret16; the stop itself is not executed. Fill415160,
bitmap43f010, clip43ef70, input431b70, sound401a30, release helpers, panel update,
key-name422b00 and installed text instructions execute. Saved registers and
stack cleanup are checked at every complete observed helper return.

Nine controlled Actor records and eight World seat references retain the
MODE_SELECTION domain; no Object/catalog record is consumed. Five declared
8016-byte bitmaps provide deterministic64x64 surfaces and500 rectangles each.
These are valid controlled inputs, not original raster assets or own loaded
resources. Two unused owned replay records remain live. The already present
background avoids the separately recovered resource-loading dependency here.
COM/GDI, string length, critical sections, Sleep, ShellExecute, free and
PostQuit are recorded responses: no host URL, quit, device or Windows operation.

112 cases comprise40 mode/network combinations,10 GetDC/help combinations,
10 screens covering256 key codes plus four out-of-range values,12 link clicks,
32 up/down/attack combinations, six consecutive DC controls and two explicit
dependency boundaries. The DC controls share actual library/resources but reset
declared caller inputs and stack for each call; this is not an own outer loop.
Network input is a declared DWORD assignment whose low signed byte the screen
uses; the remaining three bytes are zero in this controlled input.

106 cases reach real ret16 and four stop before playback43249c. Enabled panel
stops before423b1a with a declared valid four-byte header at26006200 containing1.
Worker update stops at43c780 after its actual preceding stores. Those two partial
source paths are explicit native rollback rejections, not completed matches.
Neither path is disabled to obtain a full return.

## Provenance and comparison boundary

Full source byte/write-mask replay verifies87,109 stores/316,663 bytes,
364,460 instruction reads/549,488 bytes and2,330 separate observer/API string
reads/27,635 bytes. All2,353 final regions/20,584,708 bytes and masks reproduce;
247 content-addressed blobs decode to10,488,620 bytes. All112 atomic case parts
and the nominal successful probe agree. Actual instruction bytes verify against
the pinned EXE with installed patches and relocated library code:1,284 EXE and
51 DLL starts. Stop/API addresses are excluded.3,789 complete helper returns
are verified. These counts include the two explicit boundary probes and do not
claim all branch outcomes or Windows CPU/device behavior.

The base observer's masks record writes for original globals. The only reads
with false global masks are the pinned cookie44eea4 (112 entry/106 return reads)
and the worker toggle44d784 (one read). Their exact values are independently
checked against initial EXE data. The native boundary test initializes that
toggle from its recovered-99; it does not read an expected after-state.
There are no observed reads of unknown stack bytes in this corpus. Unread
private bytes remain unknown; absence of such reads is limited to this domain.

The native screen writes its own argument words, decoded literals, highlights
and key labels into an initially zero/undefined1,796-byte (0x704) local record. String
reads require defined bytes through NUL. Every defined local byte and mask is
compared; untouched native bytes must stay zero. No source private stack snapshot
enters the native call. Fill's100-byte DDBLTFX has only size and color defined:
native uses zero for the other92 bytes, and the source keeps its actual A5
backing. Undefined padding is not claimed as a native byte match.

For110 completed selected continuations, the source records13,906 ordered events,
3,771 helper returns and1,272 EXE/51 DLL instruction starts.930 text helper calls
yield800 successful GDI sequences;130 negative GetDC results retain the prior
DC and skip GDI/ReleaseDC.588 key-name calls,893 Blts,15 sound requests,
eight background frees, four quit requests and three link requests retain order.
Full globals/masks, bitmap/replay storage and liveness, read-only World/Actors,
defined local storage and the native semantic DC are compared. Full source
stack/DLL storage verification is distinct from that native semantic comparison.

Late native observer failures after text, after confirmation sound/background
release, at the27th key label and at the final cursor Blt check whole rollback.
External effects must remain in a caller-owned buffer until the screen commits.
The test supplies such a buffer; these observer failures are not source failures.

## Preserved errors and next dependency

The isolated release build uses accepted47f31fd plus only OriginalModeScreen
and its new test.635 other accepted files remain byte-identical. All six
retained tests passed in24.318s:1,264 pristine screens,2,690 selection controls
and276 library text calls, including existing rollback tests. The first full
build took220.98s and linked NTSDNative; its new worker test failed as below.
Final raw new tests pass0.906s/build68.33s after correcting that test input.
Packaged tests pass0.667s/build0.27s with no raw override. The same isolated
package's637 raw input files are unchanged; only the fixture is added for the
638-file packaged archive. All archive/package files are hash verified.

All249 older fixtures remain unchanged; the250th contains the full51,431,876-byte
raw corpus in a4,499,136-byte lossless transport envelope. Whole raw bytes, JSON,
SHA256, every internal blob and atomic source part are checked. Transport
deflation only packages research data and does not run a DLL in the game.
Source and SwiftPM jobs for this study are terminal; no app window was exercised.

Initial probes1/2 stopped at observer inventory assertions for patched401290
and disabled-panel epilogue4242af. Pinned bytes confirm the missing entries;
the original producer versions, errors and job metadata are preserved.
Probe3 returned normally. The finite capture retained110 atomic cases, then
encountered an actual unmapped read at423b11 because the new producer incorrectly
assigned integer1 to the panel-header pointer458420. That error and full state
remain immutable; no fault continuation or damaged-pointer study was performed.
Only a separate valid-header boundary and independent worker probe followed.
The invalid input is not a game-reachable failure claim or native match.

The read-only verifier initially miscounted21 regions as20; preservation checking
initially resolved fixture basenames outside their Fixtures directory. Both
errors are retained and the checks corrected without source/artifact edits.
The first native run passed all six retained tests and four late rollback cases,
then rejected the final worker test's missing44d784 initialization. Only the
test's declared initial knowledge was corrected; native rules and expected bytes
were unchanged. The first correction mistakenly assumed zero; its explicit
input assertion rejected the actual9dffffff bytes. Direct pinned-EXE and
recorded-read inspection confirmed-99, which is now the declared input. Both
partial native globals are also compared at the child boundary before rollback.
No platform safety refusal occurred in these operations.

The full own installed-library catalog is still running, with its frozen
twenty-Object watcher unchanged. The actual initialized menu entry, enabled panel,
worker/file/background composition, outer menu return and application connection
remain separate dependencies. App window, input/output latency, audio, Windows,
full Naruto/Sasuke match, all original content/network and clean-Mac acceptance
remain open. This study does not complete the full-game goal.
