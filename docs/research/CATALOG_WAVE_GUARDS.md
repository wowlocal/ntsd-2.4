# WAV allocation guards in catalog research

The research allocator now reserves both32-byte guard regions around ordinary
WAV buffers. A bounded original/native comparison passes; the full own catalog
capture remains incomplete. This changes research memory geometry, not a native
game rule, original asset or accepted fixture. Evidence and hashes are in
[catalog-wave-guards.json](../evidence/catalog-wave-guards.json).

## Behavior, reference and failure boundary

The game function4014e0 reads a WAV, allocates temporary PCM, creates and locks
the sound buffer, copies its one or two parts, unlocks and frees the temporary.
The reference is the pinned NTSD EXE and original WAV files. The controlled
helper study uses Unicorn2.1.4 and the retained explicit MMIO/COM/CRT-copy
adapters; it does not execute Windows sound libraries or an audio device.
The separate own catalog chain executes the pinned EXE/lib/VC80 on its retained
application CPU. These are development tools, separate from native runtime.

The old primary catalog capture actually terminated at a guard AssertionError
after24 completed Objects and154 completed registered WAVs. The saved pending
input is ordinary `data/SNDDATA_2144.wav`, SHA256
`4d4ed9523d0292028f2205b3a466edbacc886aa2b2a563d03bf454a33072750b`.
Its RIFF data has20440 bytes. The previous allocation expression reserved
`roundUpToPage(max(count,1)+32)`, while region initialization writes32 guard
bytes on each side. The required extent is `roundUpToPage(max(count,1)+64)`.
For this temporary that changes20480 to24576 bytes.

The old layout placed24 bytes of the temporary's trailing guard over the next
buffer's leading guard. This is an inference from the pinned allocation and
initialization code plus recorded inputs. The terminal guard bytes were not
separately captured. Keep the full180308699-byte failure and exact traceback;
it is not an accepted own return, a native match, or evidence of a Windows/game
crash. All guard assertions remain. The old producer and its other live runs
remain unchanged; the corrected producer is separately named.

## Controlled acceptance

The finite study executes all155 recorded WAV inputs twice through whole
original4014e0: retained disjoint standalone buffers and corrected page-adjacent
buffers. It never executes the overlapping old geometry or resumes the failed
CPU. The helper has declared A5/ramp stack backing, entry1000f000 and its actual
ret4 witness at1000f008; the caller's private stack is not imported.

All155 pairs agree on full returns, saved registers, temporary/PCM bytes and
masks, globals, format/descriptor bytes and ordered events. The only normalized
values are the two declared lock pointer tokens in input and unlock arguments.
The154 completed own calls retain exactly the same temporary/PCM records and
liveness; their full caller/stack/format is outside this controlled comparison.
The pending155th has no accepted old own result.

The310 complete original calls observe231 original EXE PCs. This is not every
branch outcome. Each allocation layout retains414 regions/8468898 payload
bytes; the guarded result records all828 actual leading/trailing guards intact.
Both10220-byte portions of SNDDATA_2144.wav copy successfully and its temporary
is freed in the controlled helper. This does not prove its later own caller.

The155 new guarded cases were appended to a separate copy of the retained WAV
corpus. Every old field, case and blob stays unchanged. The already-built frozen
native comparator passes in1.234s without code changes. The new cases alone
compare22781908 bytes plus masks and2336 events. The combined input has586
direct cases and3 retained startup passes/54 child loads,98610946 bytes plus
masks and9318 events. Two old invalid CreateSoundBuffer continuations remain
their explicit boundary; do not describe all586 as successful direct returns.

## Fresh own first Object

The corrected full primary capture has independently reached its first atomic
Object checkpoint. Its complete JSON equals the old first checkpoint except
the study description and nine trace directory names. All actual1408 packed
trace parts/175799283 bytes compare byte-for-byte and by SHA. They are the same
prefix of the already fully audited primary20 corpus:70062806 trace rows and
5534239774 raw trace bytes. This reuses the prior raw/order audit explicitly;
the new comparison does not reparse that entire raw stream. All4478 first-state
blobs/462275047 bytes were separately decoded and SHA verified.

The actual new checkpoint passes the frozen native whole-factory test7.031s,
including its own1 Object/222 Frames/10 wrappers,233 records/277122 bytes plus
masks, nine registered WAVs and complete observed semantic prefix/globals.
All886 frozen native inputs remain unchanged. No source after-state enters
native loaders; the parent registry, files and full catalog return remain open.

The bounded helper and first-checkpoint jobs are terminal0. The full corrected
capture continues toward137 Objects, retaining first/every20 atomic snapshots.
A one-shot watcher with890 frozen pins will verify its20 checkpoint through
final, intermediate-state and read-provenance audits plus the native test.
It never restarts source processes or retries failures. Current jobs and plans
are in `build/research/application-catalog-work.json`.

Full own catalog/pool/UI/loading return, app window, Windows/device, full match,
all original content and clean-Mac checks remain open. The independently accepted
[initial match entry](INITIAL_MATCH_ENTRY.md) does not close those dependencies.
