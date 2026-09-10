# Windows NLS collector preparation

Status: collector prepared; Windows execution and compatibility acceptance open.
Plan and usage: [WINDOWS_REFERENCE_PLAN](WINDOWS_REFERENCE_PLAN.md).

The current original VC80 startup still stops at its first GetStringTypeW
request for one UTF-16 NUL. No Windows response, completed CRT startup, WinMain
callback, device output or full game run has been obtained in this preparation.
Existing game/native results and fixtures are unchanged. No Swift code changed.

The new freestanding C collector builds as x86 and ARM64 PE files with22 exact
KERNEL32 imports, no CRT, ASLR/NX enabled and no writable executable section.
The ARM64 object's references use PAGEBASE_REL21/PAGEOFFSET_12A/12L/BRANCH26;
it requires no base-relocation directory. The first inspector incorrectly
required one for both architectures. Both compilers/linkers had succeeded;
the inspector was corrected, leaving that incomplete build retained. No
Windows loader failure or original memory fault occurred.

The finite case set starts with the actual CRT request's input bytes and
separate declared destination fill, followed by CP1252 conversion/classification/
case mapping/reverse conversion. With successful conversions there are24 case
records. All input, capacity, full before/after storage, return and immediate
last-error bytes are retained. These are not instruction-level write masks.
The runner verifies the trusted kit, creates a new output directory, records
OS/build/architecture/NLS metadata and hashes available OS files. It does not
launch the game or use a network. Its actual PowerShell/Windows execution is
still unverified; the host validator checks format/hashes without asserting
expected Windows output or accepting a compatibility match.

Two independent final builds are byte-identical, including their8-file kits.
The trusted manifest SHA256 is
093182b1787e30ecdd7b65e4e66accd2ec8432bb54ae74f2acb8947b559160f4.
x86 is9728bytes/SHA256
0ba7192479eac881a2925e23950b7d63b007cc0cdd7abc9649c61e7b2ecb7e71;
ARM64 is10240bytes/SHA256
84526361e571ce36a2e70d46c09be256d812aa89ed1077df582b58c6ab99aeda.
The26164-byte archive build/research/windows-reference/ntsd-windows-nls-kit.zip
has SHA256 f4ffdf7676e7cc4667b7fa44a793410678e4157be39d7e86e8a104ed56983c65;
every archived member round-trips exactly. All211 prior fixture hashes verify
unchanged. No native build/test is needed for this tools/documentation-only stage.

Eighteen controlled self-tests execute only the new collector's x86/ARM64
instructions under Unicorn2.1.4. Each architecture covers complete output,
short writes, conversion failure, missing optional metadata APIs, existing
output rejection, failed write, zero-length write, flush failure and close
failure. Artificial NLS output0x6000 and deliberately invalid metadata markers
make the testing boundary explicit. They are never sent to the original CRT.
Each complete raw byte sequence, including partial/failed results, is preserved
inside an envelope labeled synthetic/Windows-false/game-false. The test validator
checks own conversion-output dependency bytes. There is no Windows acceptance
fixture and no source/native game match from these self-tests.

The web download redirect2276103 was rejected as unsafe/non-retryable. Its exact
error, recorded time and thread identifiers remain in
build/research/windows-reference/download-refusal-20260910.json. There was no
cyber_policy or automatic approval-review response. No retry through another
tool was made; no ISO, hypervisor or VM was installed. An independently available
authorized Windows ISO/endpoint has been requested. This access dependency does
not stop independent native implementation work or complete the full-game goal.

Build commands, tools/hashes, initial inspector error, terminal job IDs,
reproducibility checks, kit/archive hashes and immutable prior fixture checks
are recorded in build/research/windows-reference-work.json. Guest/physical
Windows evidence, architecture/translation differences, CRT integration,
initialized library joins, actual native app/device checks, a complete match,
all original content and clean-Mac acceptance remain open.
