# CRT and EXE startup through the real WinMain call

Status: bounded study in progress; no native or Windows acceptance.
Parent: [LIB_RUNTIME](LIB_RUNTIME.md), [FPU_PRECISION](FPU_PRECISION.md).
The loading-screen consumer is separately accepted in [LIB_LOADING](LIB_LOADING.md).

## Behavior and reference environment

Recover initialization that the original game performs before WinMain43cf40:
CRT process state, the bundled library installation, C/C++ initializer order,
53-bit FPU selection, global game constructors, and WinMain command-line/show
arguments. This matters because historical own game chains start below the real
PE entry and explicitly supply their FPU/CRT state.

Only the pinned original EXE (SHA256
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c), bundled lib.dll
(28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba), and pinned
MSVCR80 (c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d) execute
in Unicorn2.1.4. The CRT redistributable is verified by the existing oracle_crt
extractor. The harness supplies a controlled, single-threaded Windows API
contract: mapped module images, stack/TEB, clock, command/environment strings,
heap allocations, synchronization and optional API-discovery responses. These
are emulated observations, not a Windows loader/heap/thread/CPU measurement.
No host window, filesystem write, process launch or network action follows from
an emulated API request.

## Sequence and finite acceptance criteria

1. Independently decode both initializer tables and their direct game
   constructors. Retain exact original addresses/bytes and source hashes.
2. Execute the actual CRT DLL process-attach entry from its original file data,
   with every required external response declared. Then execute the complete
   EXE entry445560, actual bundled DLL entry/installer, and continuation445565
   until the actual call reaches WinMain43cf40. Stop before WinMain executes.
   Do not substitute CRT initializer successes or imported data after-states.
   Preserve partial evidence at every newly encountered unsupported dependency.
3. Once that chain returns/reaches the boundary, capture a finite matrix of
   ordinary command lines (empty/default, quoted path, whitespace, remaining
   arguments and quotes), STARTF_USESHOWWINDOW on/off, and declared API failures
   relevant to this prefix. Extend only when a newly observed behavior or
   unresolved discrepancy justifies it. Preserve every completed case.
4. Compare native semantic outputs: exact WinMain suffix bytes/show value,
   ordered game initializer operations, global game storage writes, and chosen
   arithmetic precision. Keep CRT private allocations, pointer encoding, SEH,
   argv/environment ownership and CPU feature observations separate unless their
   complete provenance and corresponding native contract are recovered.
5. Accept only complete supported native matches; preserve actual source faults
   or unsupported dependencies separately. Late native observer failures must
   roll back staged state. Keep original bytes, masks and prior fixture pins.
6. Verify raw/packed bytes, JSON and hashes independently; run relevant native
   checks from an isolated committed export excluding concurrent transforms.
   Update evidence and documentation only to the achieved boundary.

## Explicit boundaries

No deliberate mutation of callback pointers, security cookies, exception records
or control flow is part of this study. Natural process initialization may write
such fields; trace those writes accurately. Do not force CPUID, SSE probes or
exception branches to obtain a desired result. A naturally encountered fault is
preserved and investigated for input provenance; it is not a successful match.
Stop automatic retries of a safety-refused operation and preserve its full error
and identifiers. Revalidate process handles before any later action.

MSVCP80 process startup, full Windows DLL load order, WinMain/window/device
initialization, background workers, full application lifetime, initialized
library-enabled gameplay, a full match and clean-Mac acceptance remain open.
The API contract of this study must not be described as actual Windows behavior.

## First observed dependency and independent work

The fresh primary chain currently stops during CRT process attach, before EXE
entry, at the first GetStringTypeW call (return7813b3b5): type1, one UTF-16 NUL,
without supplying an API output or result. Its retained output bytes are caller
backing, not a classification result. A Windows NLS response has not been recovered.
Do not supply success/failure or fabricated classification tables to reach an
attractive WinMain boundary. The earlier missing-KERNEL32 control does complete
with CRT result0 and HeapDestroy; it is an API-failure control, not startup success.

Independent finite sub-study: execute the original last three C++ table entries
4472c8..4472d4 via actual MSVCR80 _initterm78131733, after a fresh accepted whole
bundled-library installation. This bypasses the preceding CRT/argv initializer
and is explicitly a controlled constructor call, not the interrupted own chain.
Compare twelve storage controls covering loader bytes, defined/unknown backing,
and retained repeated calls. Observe the entire458440..458c94 region (an observed
storage extent, not sizeof any C++ object), all writes/masks, three callback
entries/returns, exact installed parents and untouched code/DLL bytes. Actual
CRT memset executes with declared original-file CRT globals and inherited037f.
No NLS/CRT initialization result is imported. Native implementation must preserve
all untouched bytes/provenance and roll back on a late constructor observer.

The independent constructor sub-study is now accepted in
[STARTUP_STORAGE](STARTUP_STORAGE.md); the enclosing CRT/NLS chain remains open.

[WINDOW_INITIALIZATION](WINDOW_INITIALIZATION.md) now accepts another independent
controlled dependency: whole43bec0 and its window/DirectDraw children. It does
not continue this stopped CRT process or supply its missing NLS response.
