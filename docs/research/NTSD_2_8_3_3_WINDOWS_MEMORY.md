# NTSD 2.8.3.3 — original Windows launch and memory capture

Update later on 2026-10-17: startup now works with the per-application Windows
ARM **Disable hybrid execution mode** setting. Title menu and Versus character
selection were observed. A separate454.5MiB live dump was saved and is the current planning input; see
[its pinned path and validation](#live-memory-after-the-fix). The initial
run below remains the historical default-setting failure; see the
[startup fix](#windows-arm-startup-fix).

2026-10-17. Bounded capture complete; original startup fails before a game window.
Requested by the user, without Astra or other subagents. Local branch
`exp/ntsd-2.8.3.3`; no push or publication. No Native change or parity acceptance.
[Evidence](../evidence/ntsd-2.8.3.3-windows-memory-20261017-run1.json).

## Question, reference and boundary

Launch the unchanged supplied game in VMPal Windows and save its process memory.
This is a diagnostic snapshot, not packed-file extraction or a complete resource
inventory. The earlier packed-content access incident remains open; the exact
rejected action is unknown. Nothing here resumes protection bypass or claims
that the saved memory resolves that dependency.

ZIP SHA-256: `fca38bfe1391d969b9d29d1289c51bbf5270a384fa7da6d4a7c053da77c52b2d`.
Main member `NTSD2.8.3.3/NTSD.exe` SHA-256:
`5eda51440039099069d041e5bd13fde8be9fd8c7b20983985b1712a59719d86b`.
VMPal Windows VM 1, ID `BC1E05CE-1482-4C28-A4E3-FE5718DAA147`, Windows 11
24H2 build26100.4349, ARM64 host OS with Windows x86 compatibility, VMPal0.86 /
Tools0.56. This is actual Windows guest observation, not physical x86 Windows
or a successful whole-game compatibility check. No synthetic game state supplied.

Before execution: task-owned T7 ExFAT UUID and40GiB reserve verified; frozen
`plan1.json` declares20minutes,8GiB artifacts and4GiB per dump. Permitted writes
are its task directory and `C:\NTSDResearch\2833-memory-run1`, plus this local
handoff. Original package, baseline, historical evidence and Native are protected.
Corrections below retain separate records; no completed successful capture repeats.

## Actual observations and corrections

- Two VMPalMachine host crashes occurred before NTSD execution, while listing
  the Downloads share. Both reports identify `HVPal virtio-fs` and matching
  fault offsets. Library API temporarily reported stale running state. Reports
  and diagnostics ZIP retained; exact filesystem defect unknown. A narrow task
  share and direct archive access succeeded without enumerating Downloads.
- Ordinary outer-ZIP staging in the guest produced112 files /95,556,293bytes;
  ZIP and main EXE hashes match. This does not extract the EXE's hidden content.
- First launch failed activation: missing `Microsoft.VC80.MFC` x86 version
  `8.0.50727.762`. The bundled repair EXE has a Valid Microsoft signature and
  SHA-256 `4ee4da0fe62d5fa1b5e80c6e6d88a4a2f8b3b140c35da51053d0d7b72a381d29`.
  User explicitly approved its licence before acceptance. Windows Installer
  events11707/1033 confirm Visual C++2005 Redistributable8.0.61001 installed.
- Initial GUI installer started under a short-lived PowerShell command did not
  remain present; no installation success was inferred. Direct managed GUI
  execution succeeded. A read-only diagnostic query also had a PowerShell
  empty-pipe parser error; its correction did not execute the original game.
- Second launch, PID5084, ended with `0xC0000005`, `NTSD.exe+0xB9D37` before any
  game window. WER retained the report but removed its temporary dump.
- Separately declared `capture-correction1.json` enables NTSD.exe-only WER full
  local dump collection and allows one further fresh launch for the requested
  memory. PID2320 also faults at that offset. The faulted process is not resumed.
  Capture uses Microsoft's documented [LocalDumps](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps),
  `DumpType=2`, not code patching, injection or a reconstructed executable.

The game's direct VMPal command is the full guest EXE path, with cwd
`C:\NTSDResearch\2833-memory-run1\package\NTSD2.8.3.3`; launch2 timeout600s,
corrected capture3 timeout60s. Their jobs end with signed exit-1073741819
(`0xC0000005`), not timeout or a successful source return. Job IDs, exact earlier
launch script, raw Windows reports and correction records are retained externally.

## Saved artifact and checks

[Full startup dump](/Volumes/T7/ntsd-2.4-artifacts/version-diff-20261017/windows-memory-run1/NTSD-startup-full1.dmp):
117,282,498bytes (111.8MiB), SHA-256
`3965fdb513d3248ca08fe35982122c415671e6001d2651610a16257eca32fbf0`.
Guest and host checksums agree. Standard MDMP structure validates:16 streams,
flags `0x21826` include `MiniDumpWithFullMemory`;489 readable-memory regions /
117,190,656memory bytes fall within file bounds. SystemInfo reports x86;51 modules.
Exception is read access violation at `0x4B9D37`, with target parameter
`0xFFFFFFFFC2CC7FFC`. Dump memory payload was not extracted or analyzed.

App-specific WER settings restored to absent after verifying task ownership;
original Downloads share preserved and temporary task share removed. VM remains
running; no NTSD process remains. Original ZIP and guest EXE hashes, and immutable
instruction archive hash, verify unchanged. Task artifacts allocate approximately
206MiB; all large data remain outside Git. Installer, staging and source jobs
are terminal. Author checked file structure/provenance; independent review and
Native comparison were not performed or claimed.

This is a full dump at an early startup failure, not memory from a running match,
proof all resources loaded, a successful resource extraction or full game parity.
Next relevant work is diagnosis of this retained startup failure and a usable
original Windows reference environment, using saved evidence first. Cause of the
original access violation, complete content access and faithful Native transfer
remain open. This request does not start the full-port queue.

## Windows ARM startup fix

User requested diagnosis and correction, without Astra. Parent507d0b3c; same
Windows guest and pinned EXE. [Fix evidence](../evidence/ntsd-2.8.3.3-windows-startup-fix-20261017-run1.json).
Task-owned T7 `windows-startup-fix1/plan1.json` limits25minutes, three documented
compatibility profiles, one new full dump and2GiB;40GiB reserve retained. Native
integration still requires recovered contracts; this fixes reference startup.

Read-only diagnosis of the saved crash context with configured Capstone5.0.7
shows `xor edx, dword ptr [ecx]` at0x4B9D37, ECX0xC2CC7FFC. Adjacent code checks
block-header flags and consistency: allocator-like context is an inference,
not a symbolically identified function. The prior origin of the invalid pointer
was not reconstructed. No new execution was needed for this bounded diagnosis.

Microsoft documents that hybrid x86/ARM system libraries can be incompatible
with some x86 applications. The successful per-application change is:

1. In Explorer, select the exact game EXE and open Properties → Compatibility.
2. Open **Change emulation settings**, enable **Use advanced settings**.
3. Check **Disable hybrid execution mode (x86 apps only)**, then OK and OK.

Baseline UI showed Default, all flags off. Keep multi-core Fast, other advanced
flags off, ordinary compatibility mode off and administrator mode off. The
[official documentation](https://learn.microsoft.com/en-gb/windows/arm/apps-on-arm-program-compat-troubleshooter)
describes this compatibility option. No EXE, DAT or DLL bytes were patched.

Only this one profile was tried. Controlled PID1828 reached the title menu and
responded to navigation; its managed120second deadline subsequently terminated
it. This is a declared tool boundary, not another source access violation.
A normal Explorer launch with the saved setting created PID8092, start
2026-10-17T15:47:44.3863085Z. It reached the title menu, GAME MODE SELECT and
Versus character selection with the visible roster. It was still responding
at15:54:33Z and is left open without an exec-job deadline. Its process cwd was
not separately queried; Explorer selected the EXE in its package directory.

The original title-screen mouse targets required a vertical compensation;
clicking the displayed START text first opened ONLINE GAME. Cancel returned to
the title menu; the OS firewall access prompt was cancelled without granting
network access. Short key presses did not advance mode selection. Digit8,
present in the supplied control.txt, held0.3seconds confirmed Versus. These are
observed test-input limitations, not new canonical game input rules. No joined
seats, loaded arena, complete match, sound or Native parity acceptance is claimed.

The single changed setting and two successful startups support a Windows ARM
hybrid-execution incompatibility as the practical explanation and workaround.
The exact responsible library or prior heap corruption remains unknown; do not
turn this into a general engine rule or claim a Windows x86 hardware result.

### Live memory after the fix

Task Manager's built-in Create memory dump file completed for verified PID8092,
with path/starttime checked immediately before capture. The game remained alive.
[Working dump](/Volumes/T7/ntsd-2.4-artifacts/version-diff-20261017/windows-startup-fix1/NTSD-versus-selection-live1.dmp):
476,556,770bytes (454.5MiB), SHA-256
`adb00fd69a252cd1d0def2ce21d4963b9853f7f963613785047ad4633ea7c303`.
Guest/host hashes match; MDMP flags0x421826 include full memory;16 streams,
1,407readable regions /476,327,936memory bytes lie within file bounds. MiscInfo
PID8092 matches the verified game;93 modules include the exact NTSD path.
SystemInfo is ARM64 for this Task Manager dump, unlike the earlier x86 WER dump;
it contains the emulated x86 game process on Windows ARM64.

Raw title, setting-before/after and character-selection screenshots are saved
with the external receipt. A PNG-extension housekeeping check matched a vanished
AppleDouble sidecar after renaming its JPEG main file; the dump validation had
already completed successfully. Corrected screenshot enumeration excluded ._
files; no image content, old evidence or source capture changed. A rejected
hold_key durationMs field was corrected to duration0.3 before input was sent.
A read-only lookup under HKCU\Software\Microsoft\Wow64 found no key; this did
not establish absence or storage location of the actual saved UI setting.

Task share removed and original Downloads share retained; Task Manager closed.
The successful per-game flag and user-visible game are retained. The old crash
dump and all original EXE bytes verify unchanged. No Native modifications,
agents, push, new safety refusal, packed-file extraction or full resource claim.
New dump/format/provenance checks are author checks, not independent review or
whole-game acceptance. Further reference work can use this working environment;
complete content mapping and the earlier packed-content access incident remain
open. Do not rerun old terminal captures to update their presentation.
