# Windows DirectDraw menu-text probe preparation

2026-09-26, base e1567bf. [Plan](WINDOWS_MENU_TEXT_PROBE_PLAN.md),
[publication and exact input/tool pins](../evidence/windows-menu-text-probe.json).
This prepares the missing font/DC/pixel observation for the original first-menu
text. No Windows, original EXE/DLL or Native game execution occurs in this task.
The actual Windows installer remains at its last observed EULA screen because
the Mac screen is locked; the user's approval has already been received.

## Prepared operation and limits

A freestanding x86 collector creates its own window and original IDirectDraw
interfaces, then a primary and 794×550 offscreen surface. It uses the recovered
windowed cooperative flag8 and primary/back descriptor fields. Its other descriptor
bytes deliberately start at zero; these are controlled collector inputs, not
recovered original stack bytes. Its own class, default window procedure, placement,
no original callbacks/clipper/history, and no original EXE execution are explicit
context differences. No exclusive display mode or font selection is requested.

The three exact TextOutA byte strings, counts27/30/28 and coordinates591,491/511/531
are generated from the pinned first-menu command file. The builder verifies its
SHA and each count against its bytes. Each surface GetDC is followed by selected
font, LOGFONTW, TEXTMETRICW, face, charset, DC alignment/mapping, device-capability
and extent observations. The original transparent mode1, COLORREF0xd07750,
TextOutA and ReleaseDC sequence follows. The collector never deletes a borrowed
selected font. Numeric failures and unchanged seeded buffers remain observable.
A nonnegative GetDC with a NULL handle is an explicit collector boundary; it is
not silently passed to GDI or declared equivalent to the original caller.

A raw0x10206c fill precedes two readonly Lock snapshots, before and after the text.
Only a successful owned-surface descriptor with bounded dimensions, format, pitch
and non-NULL storage permits copying. Positive/negative pitch is retained; only
active pixel bytes are copied, with rows serialized top-to-bottom. Copying occurs
while locked, then Unlock precedes file serialization and any subsequent GDI draw.
Failed Unlock or ReleaseDC stops later drawing. Cleanup requests remain recorded,
including nonzero release counts; they are not proof of object destruction.

This controlled blank background differs from the actual menu's bitmap layers.
Neither these samples nor unchanged pixels establish final first-menu rendering,
font raster equivalence over those layers, initialization guarantees or write masks.
Actual Windows/virtual-device and original-context comparisons remain necessary.
The collector is x86; an ARM64 Windows run will explicitly record x86 translation.
It is research tooling, never shipping runtime.

The public COM slots were checked against Microsoft's retained ddraw.h, SHA256
faa9634fb2f65d633dd4dea3a1be2bf28d117f43919c6089479237381b4907f5.
In particular the original interface has LPVOID Unlock; Surface7's changed signature
is not imported. Public API references are recorded in the publication, including
[GetCurrentObject](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-getcurrentobject)
and [GetTextMetricsW](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-gettextmetricsw).
Those public contracts support observer construction, not original-game behavior.

## Verification

The first build succeeded. Before any execution, author inspection found that a
failed CreateSurface with a non-NULL output did not establish a valid owned object.
The corrected collector releases only successfully created interfaces. Original
build1, source and diagnosis are preserved; both primary/back failed-output cases
are explicit controls. There was no corresponding original-game fault or failure.

All33 finite synthetic tests passed in15.281s on build2. They cover 8/16/24/32-bit
storage, negative pitch, short/failed/zero writes, existing output, module/function/
window/DirectDraw/cooperative/surface/fill/lock/DC/font/metadata/text/cleanup failures,
positive GetDC and NULL outputs. Tests execute only this new collector in Unicorn
with synthetic Win32/COM objects and recognizable artificial pixel/font values.
The exact requests and partial/failure bodies are retained. They are not Windows
observations or Native expected data. A separate saved-request audit checks the
complete fill/lock/three text lifetimes/lock/cleanup order.

The structural validator was strengthened to require complete branch records.
All30 retained complete synthetic bodies pass the final validator without another
PE execution; nine deliberately damaged copies are rejected. A synthetic full
capture passes its CLI, and a wrong trusted manifest hash is rejected. These tests
use separately marked artificial process/OS provenance, not fabricated Windows
observations. PowerShell was unavailable on macOS, so the runner's actual Windows
syntax/execution validation remains open. It observes for60s; a timeout preserves
the live child and partial output without termination or retry.

Final builds3/4 contain ten byte-identical files. Their 14,848-byte PE matches the
tested build2, has15 KERNEL32 imports, no CRT and no writable executable section.
Python syntax checks pass. Ten prior input pins, the original EXE and immutable
AGENTS archive remain unchanged. Native sources/fixtures and unrelated dirty work
are untouched. Independent review is unavailable; author checks are not review.

## Packages and remaining gates

Task-owned X5 directory: `windows-menu-text-probe-20260926` under the session
research root. The task stays within1GiB and the original reserves.

| Artifact | Check | SHA-256 |
| --- | --- | --- |
| Final manifest | 10 kit members | 9276bf66788dc940f5dcf87f47030216b20bc359ad778da1066c4ffa358ffbe6 |
| Kit ZIP | 64,191 bytes; CRC/member bytes verified | 8fd666189b8cbbfd1e90b740207ab2f1f93e33a8ef1bd2be57a7217a987a69cd |
| Transfer ISO | 921,600 bytes; libarchive reads all10 identical members | 6596158ae3bd3813dc856ee307388e1826cf8c832db5f0ab90506bdc9cd691a4 |
| artifacts1.tar | 63,600,640 bytes; 163 members/bytes/modes/ns mtimes verified | 61e413f7f38e67fa747d06a62da18ef698ee24e68dd17afe7b21812235ae0b57 |

The ISO's read-only attachment returned `hdiutil: attach failed - Permission denied`.
The exact warning/error is retained; no second mount, changed permission or alternate
mount tool was attempted. Reading the already-created owned ISO as an archive
verified its member bytes without mounting it. No attached image remains. Mounted
or guest-media verification is still open; VM media was not changed. The earlier
header-fetch connection error was likewise retained; a normal curl download from
the same official public URL succeeded. Neither error is a model safety refusal.

Future invocation from the verified kit in Windows:

```powershell
.\run_windows_menu_text_probe.ps1 -OutputDirectory 'C:\NTSD-Research\menu-text-001' -EnvironmentDescription 'Actual Windows build, UTM ARM64 and x86 translation, virtual display configuration'
```

Host structural validation of the returned complete capture:

```sh
python3 tools/verify_windows_menu_text_capture.py /path/to/menu-text-001 --kit /path/to/verified-kit --manifest-sha256 9276bf66788dc940f5dcf87f47030216b20bc359ad778da1066c4ffa358ffbe6
```

NEXT after host unlock: reobserve the same live VM, accept the already-approved
Windows EULA and continue normal installation. Then validate the prepared NLS,
cursor and text observers under separately bounded guest plans. No repeat approval
question or VM restart is needed. CrossOver remains available. Actual Windows font/
DC/device/pixels, complete original frame comparison, independent review, Native
raster/root promotion, input/audio, full match/game and prior safety incidents
remain open. No EXE-envelope estimate was recalculated.
