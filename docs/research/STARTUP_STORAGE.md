# Controlled static game constructors; full CRT startup remains open

[OriginalStartupStorage](../../native/Sources/NTSDCore/OriginalStartupStorage.swift)
now matches twelve complete calls of actual MSVCR80 `_initterm(4472c8,4472d4)`.
Those calls execute the final three C++ initializer-table entries. This is an
independent controlled dependency, **not** a continuation of the incomplete
CRT process-attach chain below and not a whole application startup claim.
The bounded acceptance plan is [CRT_STARTUP_PLAN](CRT_STARTUP_PLAN.md).

## Original behavior

The pinned EXE C table4472d8..4472e8 contains zero,44547e,44571e,44576f.
Its C++ table4472c0..4472d8 contains zero,445254,4462e0,4462f0,446300,zero;
the caller's actual `_initterm` end pointer is4472d4, excluding the last zero.
This table and the enclosing startup order are static evidence. The controlled
subrange invokes the last three nonzero C++ callbacks in order:

| Callback | Actual target | Observed operation |
| --- | --- | --- |
|4462e0|4031b0 with ECX458440|Clear words at object+0,+130,+134; retain text backing.|
|4462f0|414440 with ECX458af8|Return the object pointer; no object read or write.|
|446300|419e40 with ECX458b00|Clear the first word, then400 bytes at+4 via real CRT memset.|

Each callback returns its original object pointer. The controlled table call
preserves EBX/EBP/ESI/EDI and returns SP2000f004 with CW037f. The native routine
performs no floating-point operation; that source word is not a native hardware
FPU-status comparison. Actual startup precision selection remains separately
accepted in [FPU_PRECISION](FPU_PRECISION.md), with the whole startup join open.

The observed458440..458c94 storage extent is2132 bytes, not `sizeof` any object.
Every call compares all bytes and initialization masks. Only416 bytes become
written/defined; all intervening globals and untouched text bytes retain their
own prior backing and provenance. The first case uses declared loader-zeroed
storage. Other cases use bounded known/unknown data backing. Four linked calls
carry their own preceding native result across three continuations. No source
expected after-state is imported to build native storage.

The source first reproduces the **whole accepted** EXE-entry/lib.dll installer,
identical to the original installer case0, including all13 patches/62 bytes and
full image hashes/changes. The later controlled constructors retain all observed
code and DLL bytes. CRT code/data comes from the pinned original file; this
sub-study does not run its process attach or earlier argv initializer. Real
`_initterm` and `memset` execute, with no initializer-success substitution.

Across12 calls:25584 storage bytes and equal-sized masks,1248 actual stores/
4992 written bytes,36 callback returns,27 EXE and47 CRT instruction starts.
An independent verifier reconstructs every final byte/mask from actual stores,
checks the original bytes of all74 instructions and verifies the complete parent.
This small fixed constructor domain is not all CRT branches or Windows evidence.
A native-only observer error after the third completed constructor verifies
rollback of the entire staged storage and its initialization mask. External
observers must buffer effects until the enclosing operation commits.

## Actual CRT process-attach prefix and unresolved NLS

[oracle_crt_startup.py](../../tools/oracle_crt_startup.py) separately starts the
pinned MSVCR80 process-attach entry7813232b, with original file data and a declared
single-threaded Windows API profile. The planned next stage is whole EXE entry,
actual bundled DLL installation and the call into WinMain43cf40 on that same CPU.
The primary capture has **not reached EXE entry**.

The profile supplies synthetic stack/TEB, clocks, process/private heap tokens,
page-backed allocations, TLS, synchronization, command line, empty environment,
CP1252 metadata and unavailable optional exports. It supplies KERNEL32 as a module
token, not executable Windows code. CRT code performs real private-heap and TLS
initialization, allocates/initializes its532-byte PTD, constructs low-level stream
storage, and obtains the command/environment inputs. The store781321d9 actually
writes the GetCommandLineA result to `_acmdln`781c3b24; no completed CRT data
snapshot or expected pointer is injected.

The first unresolved API is `GetStringTypeW`, returning to7813b3b5. Its actual
arguments are type1, source78194ff0 containing one UTF-16 NUL, count1 and output
at2000e9ac. This first request probes API availability; it is **not** a captured
256-entry classification table. The retained output backing is bytes `d8e9`;
no API output or success value has been supplied. Windows NLS classification,
conversion/casing and their effect on CRT initialization remain open. Do not
replace them with host Unicode tables or force an API failure to finish startup.

The partial primary trace retains1274 actual CRT instruction starts,188 API
entries (including the unresolved call),622 CPU writes/1885 bytes and five heap
allocations, one already freed. These are an instruction/write trace, not a full
heap-byte/mask comparison. Explicit API memory writes are recorded as boundary
operations rather than counted as CPU stores. Native startup and Windows are
both false in its evidence report.

A separate missing-KERNEL32 control completes CRT attach with rejection, restores
its caller stack and invokes HeapDestroy:285 actual CRT PCs and14 API requests.
The harness records `crtRejected` only after observing the actual return0. This
is a declared API-failure control, not successful application initialization.
The initial exploratory captures stopped at newly unsupported APIs; all11 raw
captures and source versions are preserved under `build/research`, along with
terminal statuses in `crt-startup-work.json`. Probe11 only adds exact arguments
at the same unresolved NLS boundary. No original memory fault or safety refusal
occurred, and no completed source corpus was restarted.

## Verification and retained artifacts

- [Source constructors](../../tools/oracle_startup_storage.py),
  [independent source verifier](../../tools/verify_startup_storage.py),
  [native tests](../../native/Tests/NTSDCoreTests/OriginalStartupStorageTests.swift),
  [acceptance packer](../../tools/accept_startup_storage.py).
- [Constructor report](../evidence/startup-storage.json),
  [incomplete CRT report](../evidence/crt-startup-prefix.json).
- Exact jobs, pins and full artifact checks:
  `build/research/startup-storage-work.json`,
  `startup-storage-artifact-verification.json`, `crt-startup-work.json`.

Raw release3 tests pass0.580s/build175.80s: both new tests plus the retained968-call
queued-sound comparison. The535-file isolated export is committed aa6f203 plus
only the two new native files, excluding concurrent transforms. Packaged3 tests
pass0.570s/build0.28s with all NTSD raw overrides removed. The final537-file export
adds only the two fixtures and verifies every prior exported file unchanged.
NTSDNative links; no app window, sound device or Windows instance is exercised.

| Artifact | Raw bytes | Packed bytes | Comparison scope |
| --- | ---: | ---: | --- |
|startup-storage|643450|29158|12 complete native constructor calls|
|crt-startup-prefix|154495|23554|Incomplete primary + separate rejected attach; source-only|

All208 previous fixture pins remain unchanged;210 after publication. Full raw/
packed bytes, JSON, newlines and hashes verify. The CRT bundle embeds **exact raw
JSON bytes** of both original captures, preserving their distinct outcomes.
All10 replay-codec vendor hashes verify unchanged. Every owned source/SwiftPM job
is terminal. Full CRT initialization, Windows loader/NLS/MSVCP80, WinMain,
initialized library-enabled gameplay, full match, native app/device/clean-Mac
checks and the full original-content goal remain open.
