# Actual Windows reference environment

Status: preparation only. No Windows guest or NLS response has been obtained.
Parent: [CRT_STARTUP_PLAN](CRT_STARTUP_PLAN.md),
[WINDOW_INITIALIZATION](WINDOW_INITIALIZATION.md).

## Behavior, artifacts and comparison boundary

The game initializes its VC80 CRT before WinMain, then creates a Win32 window,
DirectDraw surfaces and input/audio devices. The current controlled CRT capture
stops at GetStringTypeW(type1, UTF-16 NUL, count1), returning to7813b3b5. Its
destination's prior bytes `d8e9` are caller storage, not a Windows response.
An actual Windows process is needed to recover this response and identify the
OS/NLS version. A later whole original game run must recover synchronous window
callbacks and observable rendering/input/audio; controlled API requests alone
do not establish those behaviors.

The declared original reference remains downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a:
EXE SHA256 3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c,
lib.dll 28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba,
MSVCR80 c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d.
The first NLS collector does not execute these binaries: it queries their OS
dependency directly. Its results will not by themselves be game/CRT matches.

The host is Apple Silicon/macOS26.6.2,24GiB RAM, with119GiB free at preparation.
A prospective ARM64 guest receives at most4vCPUs/8GiB RAM and a thin64GiB disk.
Recheck free space before allocation. No VM disk, hypervisor or guest is installed
by this preparation. Windows ARM executing the x86 collector/game includes
Windows x86 translation; it is not physical x86 CPU/FPU or device evidence.
Record native and process machine IDs instead of assuming architecture.

## Access and isolation

Use an available licensed Windows installation or an official evaluation under
its applicable terms. Do not invent registration details, accept terms on an
unidentified user's behalf, or change the guest's installation/security checks.
Microsoft's [ARM64 ISO guidance](https://learn.microsoft.com/en-us/windows/arm/iso)
describes local development VMs. The
[IoT evaluation page](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-iot-enterprise-ltsc)
describes a90-day evaluation and registration; no evaluation has been registered
or downloaded for this project.

The web tool rejected the public download redirect2276103 on2026-09-10 with:
`URL https://go.microsoft.com/fwlink/?linkid=2276103 is not safe to open (non-retryable error)`.
The exact response, recording timestamp, thread and unavailable turn-ID field
are preserved in build/research/windows-reference/download-refusal-20260910.json.
This was a web URL rejection, not a cyber_policy or automatic approval-review
response. Do not retry that operation through a different tool. No source job,
build or VM was running; no download occurred. Access to an independently
available authorized Windows reference remains an external dependency.

The prospective guest has no NIC by default. The first transfer contains only
collector sources/binaries/manifests and explicit documentation, using read-only
media; no host home/workspace sharing or host credentials. Later original game
execution remains offline because its background worker may open external URLs.
Any network-game tests require separate controlled instances and explicitly
authorized addresses. Guest images remain ignored research files. Nothing from
Windows/QEMU/EXE/DLL execution enters the native shipping runtime.

## Finite first capture

Build freestanding x86 and ARM64 collectors from the same C source, importing
only documented Windows APIs and dynamically querying optional OS metadata.
The collector creates a new nls.json, refuses to overwrite an existing capture,
and records exact input bytes, destination capacity, full before/after bytes,
numeric results and immediate GetLastError. Last-error values after success are
observations, not specified error semantics. Before/after differences are not
instruction-level write masks.

1. Two calls reproduce the observed type1/NUL/count1 request with the original
   two destination bytes and a separate declared fill pattern. Addresses differ
   because this is an independent process, not the original CRT stack.
2. Two GetCPInfo1252 calls retain complete20-byte before/after structures.
3. Four MultiByteToWideChar calls convert bytes00..ff at explicit length256,
   codepage1252, flags0/MB_PRECOMPOSED1, and two destination fill patterns.
4. For each successful conversion, query CT_CTYPE1, en-US lower/upper mapping,
   and reverse1252 conversion using that call's actual UTF-16 output. Record
   dependency IDs. With all conversions successful there are24 NLS case records;
   failures remain records and skip only their dependent queries.
5. Record executable architecture, ACP/OEMCP/locales, optional IsWow64Process2,
   OS version and NLS version, loaded system module paths, source/binary hashes,
   and explicit VM/translation description. Hash available relevant OS/NLS files
   without redistributing them. Keep raw output even when validation fails.

The first case can supply an independently observed Windows response only after
the complete provenance and raw bytes verify. New Windows NLS data must be a
separate OS profile; it must not relabel the existing synthetic XP5.1 responses.
No host Unicode table, guessed Windows failure or expected snapshot may fill the
gap. Future CRT calls outside this finite capture remain unsupported until their
exact inputs have their own recorded Windows answers.

## Acceptance and subsequent stages

Preparation acceptance is limited to reproducible cross-compilation, PE/import
inspection, exact source/binary/package hashes, a reviewable runner, and bounded
collector self-tests. Eighteen self-tests execute only our new x86/ARM64 PE code
under Unicorn2.1.4 with deliberately artificial API values. These exercise
complete and short writes, zero/failed writes, existing output, flush/close
failures, conversion failure and missing optional metadata APIs. Their full
outputs remain in explicitly synthetic envelopes; they never execute the
original game/CRT or supply its missing NLS response. They are not Windows
validation. Preserve failures and do not publish an
accepted Windows fixture until the collector has actually run in a declared OS.

After access exists: run both applicable architectures, verify captures, compare
the exact NUL request and use a declared Windows profile to continue the CRT.
Then run the pinned whole game from a copied, hash-verified distribution inside
the isolated guest, preserving startup failures and unmodified original files.
Confirm the original menu, window callbacks, a complete Naruto/Sasuke District
match, input/render/audio order and observable differences against the native
application. Virtual devices, physical device checks, initialized library joins,
all content and clean-Mac acceptance remain separate open requirements.

## Prepared collector usage

From the repository, build into a new directory with local clang/lld-link:

```sh
python3 tools/build_windows_nls_probe.py --output build/research/windows-reference/build-new
uv run tools/test_windows_nls_probe.py --kit build/research/windows-reference/build-new/kit --output build/research/windows-reference/self-test-new
```

Transfer the kit to the declared Windows test environment. In a normal
PowerShell session permitted to execute the reviewed script:

```powershell
.\run_windows_nls_probe.ps1 -OutputDirectory C:\NTSD-Research\nls-001 -EnvironmentDescription 'Actual OS build, VM/physical host and translation description' -Architecture x86
```

On ARM64 Windows, `-Architecture both` additionally runs the ARM64 collector.
Do not run ARM64 binaries on an x64/x86 Windows host. No administrator privilege,
execution-policy change, internet access or installed game is needed for this
collector. Keep the resulting directory intact, including raw files on failure.
The runner records OS/NLS file hashes as visible to its own filesystem view,
not loaded-image hashes; WOW64 redirection remains explicit. Its PowerShell
execution is unverified until an actual Windows run.

Back on the research host, pass the trusted host-build manifest hash:

```sh
python3 tools/verify_windows_nls_capture.py /path/to/capture --manifest-sha256 HOST_BUILD_MANIFEST_SHA256
```

This verifies structure, input/dependency bytes and file hashes without inventing
expected API outputs. OS provenance still requires the declared actual run;
`compatibilityAccepted` remains false. A formatted JSON file alone is not proof
of Windows execution. See [WINDOWS_REFERENCE_PREPARATION](WINDOWS_REFERENCE_PREPARATION.md)
for the achieved build-only result and outstanding access dependency.

API references:
[GetStringTypeW](https://learn.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-getstringtypew),
[MultiByteToWideChar](https://learn.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar),
[LCMapStringW](https://learn.microsoft.com/en-us/windows/win32/api/winnls/nf-winnls-lcmapstringw),
[IsWow64Process2](https://learn.microsoft.com/en-us/windows/win32/api/wow64apiset/nf-wow64apiset-iswow64process2).
