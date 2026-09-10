# Continuous WinMain startup

`OriginalWinMainStartup` now composes the uninterrupted original
`43cf40..43d100` startup prefix. **23 whole native chains match. Five original
stops and seven unknown-provenance native rejections remain separate contracts.**
The source reaches the first message-loop boundary in30 cases; seven of those
are deliberately rejected by native because required storage is still unknown.
This is not35 successful native matches or a WinMain return.

The finite scope is in [WINMAIN_STARTUP_PLAN](WINMAIN_STARTUP_PLAN.md).
Reference artifacts are the pinned NTSD2.4 EXE, actual VC80 MSVCR80, original
`adinfo.txt`, `MENU_BACK1` DIB and five menu WAV files. The35 cases execute on
Unicorn2.1.4 with controlled file, allocator, Win32 and COM responses. Low-level
execution recovers call order and the shared stack/global/CRT lifetimes needed
to join previously separate native routines. No original files are changed,
no external network is used, and no protective/control storage is corrupted.
The full earlier CRT/NLS/loader path remains an explicit entry dependency.

## Continuous source and native ownership

The source starts at actual WinMain43cf40 with SP1000f038 and four declared
arguments. After its prologue, startup captures timeGetTime, calls actual
srand7816d5e3 in the same CRT/PTD later used by scanf/sprintf and calendar code,
requests InitializeCriticalSection(4554a4), and calls CoInitialize(0). The COM
result is ignored. The critical section's24 output bytes are declared platform
input, not bytes measured on Windows. No native host pointer or private CRT
stack word is imported.

Window and DirectDraw initialization43bec0 runs with the caller's instance and
show arguments. Its misleading numeric return1 survives ordinary window/device
failures, so the caller continues. HWND73000001 on the ordinary case subsequently
appears in both joystick captures and DirectSound cooperative-level requests.
DirectDraw31001000 supplies the valid panel bitmap call. Failed creation cases
carry their own resulting globals forward too; no expected child after-state
is used as the next child's input.

The original case reads the pinned `now 0 4 <end>\r\n` information file. The
`data/ad0.txt` content file is actually absent. Whole information/content/default
children return1/0/18 and compute period4 themselves. Native does not seed this
period from a later fixture snapshot. Controlled valid-content cases exercise
bitmap success, missing resource, NULL bitmap allocation, and periods-1,24855,
24856 andInt32.max before actual calendar arithmetic.

Both dates, whole402020 music and both cursor requests follow on the same CPU.
The loaded PE's44ef38 string stays empty on these chains. Thus actual VC80
`sprintf` produces `\graph.log`, without the `C:\NTSD` directory explicitly
supplied by the earlier isolated music/output controls. The complete EXE static
xref inventory finds only401dbf pushing44ef38. This does not recover a Windows
current-directory value or prove the earlier full CRT/loader environment.

Input initialization then clears the keys, initializes both joystick IDs,
creates DirectSound and calls all five original4014e0 WAV loaders. Native
compares every completed load's output, PCM, temporary/first/second storage,
format and normalized descriptor bytes and masks. Ordinary missing WAVs and
failed DirectSound creation retain the original behavior. Source adapters
relocate temporary/first/second research regions to2a000020/27000020/29000020
with60000 stride to avoid the already-live calendar and panel allocations.
These are declared research tokens, not native or Windows allocation addresses.

No child resets SP, registers, globals or RNG. The source stack is initialized
once before WinMain. Phase-specific masks describe ownership without clearing
the physical stack. The ordinary chain ends at43d100/SP1000effc, before the
message-loop setup, with EBX78182153/EBP7817775d/ESI123456789/EDI30007500.
CW remains037f. Zero and UInt32.max seeds are also preserved; no rand call
advances the seed within this prefix. Eight ordinary-case stage snapshots
retain the same own seed through the shared PTD.

The native composer uses the existing window, panel, startup-output and input
implementations. Its required platform protocol makes file/device/calendar
responses explicit. All owned state commits together after the fifth WAV.
Platform implementations must stage their external effects until this commit.
Six observer trials fail after window, panel, second date, output/music, fifth
WAV, and the final callback; each verifies complete globals and owned-state
rollback. Existing separate helper tests retain their repeated-generation
coverage. This study starts fresh WinMain instances, not repeated WinMain calls
inside an initialized Windows process.

## Unknown provenance and ordinary failures

Three fullscreen/fallback source cases reach43d100 but native rejects them
before RegisterClass. `WNDCLASS.hCursor` at1000efd8 is a5a5a5a5 with a false
ownership mask. Each exact pre-request stack-store prefix contains **zero writes**
to that word since declared WinMain entry. Later writes to the address do not
establish its earlier value. Earlier CRT stack provenance and actual Windows
handling remain open. Native reports `unknownFullscreenCursor`; it does not
supply a made-up zero cursor. Other opaque platform-structure fields retain
false masks and compare only owned bytes; the full raw source bytes are kept.
This is not private Win32/C++ structure byte equivalence.

Missing adinfo and empty content reach unknown reads in the already documented
panel contract: info offset28/count1 and content offset604/count1. Native stops
at root events26 and39, respectively. The continuous source prefix and global
stores at each first unknown read are retained. Source execution continues
under the declared physical backing, separately from the native rejection.

Two ordinary joystick capability failures first read unknown offset36/count4
at root events88/89. Earlier CRT formatting has physically written all four
calibration words, but these are **private CRT values, not native-owned joystick
calibration**. The eight unknown source reads retain these last producers:

| Capability offset | Last original store | Provenance |
| --- | --- | --- |
|36|78141727|CRT security-cookie store, following cookie load and XOR with EBP|
|40|78141712|Saved CRT frame|
|44|781777b0|CRT return address|
|48|781777a1|Private CRT FILE pointer|

The original reads these retained bytes as numbers after ordinary API failure.
No experiment corrupts the cookie, dereferences these words as pointers, or
changes control flow. Their presence is documented accurately; no exploit or
protection bypass is developed. Native keeps its undefined-read rejection and
whole rollback. These failures can follow ordinary device/resource errors;
they are not declared irrelevant to game compatibility. Recovering earlier
Windows/private backing remains an open dependency.

The other five cases stop at existing source boundaries: NULL calendar reads
at43cfd3 (tm allocation failure) and43d028 (period24856), actual CRT invalid-
parameter78138a70 (pre-epoch wrapped clock), and invalid CreateSoundBuffer
continuations40187a on WAV1/WAV5. Native explicitly rejects each with rollback.
No Watson/fault continuation is followed. The40187a PC exists in the fifth-WAV
case's union because earlier successful WAVs executed it; that union does not
claim the stopped fifth invocation executed the instruction.

## Evidence and verification

The35 source cases retain7266 ordered events and4046 actual original PCs:
1906EXE+2140CRT. Of132 statically decoded WinMain-prefix starts,128 execute.
The four absent starts43cf8c/8d/8e/91 are the early return after a zero43bec0
result; this controlled whole wrapper always returns1. Stop43d100 is excluded.
All13 bundled-lib patch sites are disjoint from executed instruction byte spans;
these startup observations do not establish library behavior in later paths.

Source returns comprise399 calendar helpers,159 music,214 window,106 panel and
186 input/sound helpers. There are156 WAV calls and154 source WAV returns.
Native comparisons contain5361 events in23 whole chains, plus964 events in the
12 explicitly rejected prefixes:6325 total. The119 completed native WAV results
are115 in whole chains plus4 before the fifth-WAV source stop. The7266 source
events and154 source WAV returns must not be presented as all native matches.

The independent verifier checks all1029 blobs,35 atomic case parts, pinned
EXE/CRT instruction bytes, PE initial globals, all final globals/masks, CRT data
and PTD, own calendar/music allocations, and the1104-byte panel stack window
at entry, return and startup end. It reconstructs10722 original global stores
plus351 adapter writes;3530 original CRT stores plus230 adapter writes; and
400835 original stack stores plus1738 adapter writes. Counts describe the
recorded research operations, not Windows/device/host measurements. Full WAV
storage comparisons run in native tests; original WAV/DIB bytes and hashes are
independently bound to the pinned resources.

The first source probe failed because the attached panel observer lacked its
`visited` member; the second completed the whole chain. Another case-selection
probe stopped before CPU execution because a label lacked its existing `-a5`
suffix. Both errors and frozen versions are retained. Four complete controls
then preceded the full35-case capture. A final metadata-only capture adds
pre-request and first-unknown-read prefix counts and source resource metadata.
All preceding candidate1 expected data, stores, instruction bytes and blobs
remain exactly unchanged. No process was restarted for a quiet log.

The first native compile and11 raw release tests passed:197.81s build and
24.939s tests, including retained window, panel, startup-output and input tests.
Two independent-verifier assertions initially used the wrong panel slice and
a single calling convention for both input helpers. They were corrected to the
existing declared1104-byte range and actual4014e0 ret4 versus401970 ret0.
No native game rule or original expected data changed to make these checks pass.
Final11 packaged release tests passed24.347s/build0.29s without raw
overrides. All owned source and SwiftPM jobs are terminal; NTSDNative linked.

Raw35021596 bytes, SHA256
`0b8e2c61cac383b147a619ea0edd1e2f2f1ba85965f230e39f5cf9cf3c76ef4d`;
lossless fixture7434880 bytes, SHA256
`e7801d29a96235ddbc0488b784b8c5764841d3c9414f62ebef85162f66708182`.
All234 prior fixtures are unchanged,235 current. Transport deflation only packs
research bytes; native does not execute an EXE/CRT/COM emulator. The isolated
build exports591 committed native files plus the new composer, test and fixture,
594 total. Six foreign transform files remain unchanged and excluded.

CUA inventory returned `Native apps: Error: Sky Computer Use native pipe startup
failed`. No app/window/input action executed. This is a transport failure, not
a safety refusal. The separate Windows download refusal remains recorded and
was not retried. Source/build process states are checked independently.

[Source](../../tools/oracle_winmain_startup.py),
[verifier](../../tools/verify_winmain_startup.py),
[packer](../../tools/accept_winmain_startup.py),
[evidence](../evidence/winmain-startup.json),
[native composer](../../native/Sources/NTSDCore/OriginalWinMainStartup.swift),
[tests](../../native/Tests/NTSDCoreTests/OriginalWinMainStartupTests.swift).
Jobs and final evidence are in `build/research/winmain-startup-work.json`.

[APPLICATION_MESSAGE_LOOP](APPLICATION_MESSAGE_LOOP.md) now continues this own
startup through message-loop decisions and selected actual WndProc callbacks.
Its63 loop returns keep declared dispatcher/recovery boundaries, and one due
own dispatch stops at actual43e9a0 without a fabricated return. It is not a full
initialized gameplay/application claim.

Earlier CRT/NLS/loader initialization, unknown fullscreen/private backing,
synchronous window callbacks, worker/whole-dispatcher/application join,
library transforms, actual window/input/audio/latency, full matches/all original
content and clean-Mac acceptance remain open. The Practice app still uses its
existing engine. This startup milestone does not complete the full game goal.
