# Original menu sound device and five initial buffers

[OriginalMenuSoundStartup](../../native/Sources/NTSDCore/OriginalMenuSoundStartup.swift)
implements whole401970 and controlled WinMain43d08e..43d100 with all five actual
WAV children. **112 complete segments match; ten stopped CreateSoundBuffer
continuations are separate native rejections with rollback.** This is not122
successful startup matches. The finite plan is
[MENU_SOUND_STARTUP_PLAN](MENU_SOUND_STARTUP_PLAN.md).

The successful segments contain560 whole WAV returns,672 helper returns,
8066 ordered events and1092 global stores. The ten stopped cases contain30
attempted WAV calls (20 returned,10 stopped),30 completed helper returns,
476 events and60 stores. Full source/native comparison under these two distinct
contracts covers533552320 bytes,8542 events and all global write masks.

This recovers producers previously only identified statically in
[CHARACTER_SCREEN](CHARACTER_SCREEN.md) and explicitly supplied in
[NETWORK_MENU](NETWORK_MENU.md). Their existing fixtures remain unchanged.
The new producer is not yet joined to those initialized menu chains or the
application. The original HWND, prior global bytes and API responses remain
declared inputs; this is not a resumed CRT or complete WinMain startup.

[INPUT_STARTUP](INPUT_STARTUP.md) now extends a separate controlled caller to
43d078, executing the memset argument pushes and whole joystick initialization
before these shared sound helpers. Its callbacks use the resulting own bounds;
this earlier corpus remains unchanged with its original43d08e entry contract.

## Reference and boundaries

The reference is the pinned31715328-byte original EXE, SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
and the five unchanged original WAV files. Unicorn2.1.4 executes the actual game
instructions. The retained [WAV adapter](WAVE_LOADING.md) supplies MMIO chunk
positions/read bytes, DirectSound methods, MessageBox, malloc/free and bounded
memcpy operations. These are explicit research adapters, not Windows DLLs,
OS allocations, sound devices or host heap-pressure measurements.

The independent verifier checks all13 accepted bundled-library patches/62 bytes
against the entire studied ranges: none overlap. This controlled source does
not install or execute the DLL, and is not relabeled as an initialized library
chain. The separate [CRT/NLS boundary](CRT_STARTUP_PLAN.md) remains open.

Entry43d08e follows the unexecuted earlier memset and43bf10 work. The three
pending arguments are455378,75hex,100hex, from the static caller instructions.
Their producer is not executed here. After401970 the caller removes16 bytes:
its HWND argument and those three older arguments. Every successful segment
ends at the unexecuted43d100 with SP1000f00c,12 bytes above inputSP1000f000.
This boundary is not a WinMain return or the message loop.

The declared prior device/slot words include inert nonzero sentinels. They
exercise retained storage, not proven values from real process startup. No
sentinel is dereferenced: creation overwrites or clears the device, and absent
audio makes the WAV helper return before consuming prior buffers. Source stack
uses two declared backing patterns; native never imports its completed stack.
The WAV format's overlapping saved destination word is reconstructed by the
shared native loader, rather than supplied as expected bytes.

## Device and caller rules

401970 calls the real43f384 import thunk with null GUID, output44eecc and null
outer object. **Only exact HRESULT0 succeeds.** Any nonzero result, including
positive1, clears44eecc, returns0 and requests no Release.

On success, the supplied output device is read from44eecc and receives
SetCooperativeLevel(device,HWND,1). Its numeric result is ignored;401970 always
returns1 after this call. Controls include positive1 and negative80004005.
The native adapter explicitly rejects a missing successful device output with
rollback; that adapter error is not a successful original source comparison.

After failed initialization the caller reloads4546f4 and requests MessageBox
with text `Could not initialize Direct Sound`, null title and flags30hex. Its
result is ignored. The caller then performs all five loads even without audio.

| Order | Global destination | Original path |
| --- | --- | --- |
| 1 | 45560c | `data\m_join.wav` |
| 2 | 455610 | `data\m_ok.wav` |
| 3 | 455614 | `data\m_cancel.wav` |
| 4 | 455618 | `data\m_pass.wav` |
| 5 | 45561c | `data\m_end.wav` |

All pass through whole4014e0. No per-file decoder or special character rule is
added. With device0, the five destination words remain untouched and every
helper returns1 without file IO. With a device, each destination is cleared
before Open. A successful load writes its returned buffer after free; an
ordinary failed load retains0. The caller ignores the helper's return and
continues the next load. It does not request SetVolume or release prior buffers.

Open, three Descend positions, format read, Ascend, short/failed payload read,
buffer-lost Restore and ignored final Lock errors are exercised at each of the
five positions under both backing patterns. The exact original files remain
unchanged. Failed Close/Unlock and Restore results remain ignored. Error Lock
controls supply valid output regions explicitly; no such device behavior is
asserted for Windows.

All20 short/failed payload reads preserve their live temporary allocation.
Each load receives separate synthetic payload and first/second buffer regions,
and source checks every earlier region unchanged after later loads. Native
returns its own five-result aggregate with complete PCM, masks, temporary
lifetimes and interface tokens. These are modeled ownership observations,
not COM reference-count or private Windows allocation equivalence.

Ten nonzero CreateSoundBuffer results execute the actual diagnostic and free,
then stop before40187a's unsafe continuation, following the already accepted
WAV boundary. The native caller throws and rolls back its whole global state;
the stopped helper's data is compared separately. No null dereference, freed
payload copy or protection failure is executed. Allocation exhaustion remains
unverified, and is not silently converted into a successful load.

## Coverage, transactions and verification

The source executes392 original instruction starts:27 caller,19 device helper,
342 WAV loader,3 cookie-check and1 DirectSound import thunk. Actual byte strings
are independently checked against the EXE. The stopped end and synthetic API,
allocator/copy boundaries are excluded. Of408 static starts,16 do not execute:
seven require44eecc to become0 between its consecutive WAV checks (fixed menu
destinations cannot alias it), and nine handle a non-PCM format absent from the
five original files. The retained standalone WAV corpus has its separate
non-PCM control. This is not every possible branch outcome.

All702 completed helper returns assert stack cleanup and saved registers.
The stopped WAV calls have not restored their saved registers and are not
subject to a false whole-return assertion. CW037f stays unchanged; no native
process FPU-status or actual Windows CPU claim follows.

Native event observers see the live staged globals at every request. Its
ordered store observer independently reconstructs the complete source mask,
including the device's API output store. Late failure after the fifth load and
missing successful device output both roll back. External effects/requests must
be buffered until the enclosing operation commits.

The first probe stopped because the research region spacing was too small for
the379766-byte original m_pass.wav. Its source version remains retained; the
spacing was corrected before the successful two-case probe and final122-case
capture. No original file or expected result was changed. Final capture is
terminal and each completed case has an atomic, hash-verified checkpoint.

The first native build required explicit `as: UInt32.self` arguments. Before
the first executable comparison, the test distinguished declared readable
global inputs from the separate observed write mask. The source verifier also
initially required restored registers on the deliberately stopped WAV calls;
that assertion was corrected to apply to complete returns only. Source bytes
and native game behavior were not changed to satisfy it.

Raw acceptance passed5 release tests in22.482s after186.04s build, including
the unchanged409-file WAV corpus and all seven network-menu fixtures. The
isolated export contains570 committed files plus two new native files, then
the new fixture. All225 earlier fixture hashes and10 codec vendor hashes are
preserved. Full raw7643981/packed3890251 bytes, JSON, SHA,146 blobs and122 atomic
parts are independently verified. Fixture compression is research transport.
Final packaged5 tests pass22.466s/build0.29s without raw overrides. All source,
native build/test and app processes are terminal; the packaged export has573
verified files, excluding the six untouched foreign transform files.

The current Practice application also launched and produced its own
AppKit/SpriteKit render of District, Naruto/Sasuke and HUD, then exited0.
This checks the existing window/render path, without new menu-sound wiring,
input interaction, latency or audio-device verification.

[Source](../../tools/oracle_menu_sound_startup.py),
[verifier](../../tools/verify_menu_sound_startup.py),
[packer](../../tools/accept_menu_sound_startup.py),
[tests](../../native/Tests/NTSDCoreTests/OriginalMenuSoundStartupTests.swift),
[evidence](../evidence/menu-sound-startup.json).
Job/acceptance details are retained in
`build/research/menu-sound-startup-work.json`. Full WinMain initialization,
menu/application connection, library-enabled match, Windows, real devices and
clean-Mac acceptance remain open.
