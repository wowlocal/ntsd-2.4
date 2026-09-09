# Whole original replay writer

The whole43dd60 source probe executes the original compressor, MSVCP80
ofstream and MSVCR80 CRT through the original return. All21 successful whole
returns match OriginalReplayWriter. Five additional source failures are explicit
native rejections with game-record rollback, not successful-call equivalence.
The26-case corpus is accepted after its full raw/native comparison.
The accepted initialized gameplay boundary remains421cdc/SP1000e9bc.
See [RESULT_RECORDING_PLAN](RESULT_RECORDING_PLAN.md) for the enclosing caller.

## Recovered order and storage

The writer formats `recording\%s` from live44fd98, reads4588a8, calloc-allocates
0x631200 zero bytes, and compresses the entire0x630e18 recording. It ignores
the status and modifies only the leading min(key length, published length)
bytes, adding the live key byte and subtracting0x30 modulo256. The key is a
NUL-terminated string at44d7a0, not a repeating cipher over the whole output.

Actual stream construction, header write, payload write and close precede
free(temporary), a fresh read/free(4588a8), and clearing4588a8. Only then does
the C++ destructor run, followed by SEH/cookie restoration and the original ret.
Open/write/close return failures do not change this ownership order.
Native uses the existing OriginalMenuPresentationMemory allocation registry;
it does not maintain a second replay buffer disconnected from input/loading.

NULL source with the original nonzero declared size is distinct from an empty
input. The original compressor returns−2 and leaves the published length at
0x631200. The writer still adjusts/writes the zero-filled destination and
eventually calls free(NULL) for the recording. A failed temporary allocation
also yields−2, but the next behavior depends on the key and stream: a nonempty
key reaches a NULL byte read at43de1d. An empty key plus failed file open avoids
all payload reads and returns normally after both frees and pointer clearing.
With an empty key and a successful open, the actual CRT instead rejects the
NULL payload and reaches `_invoke_watson` from78180458. There is no NULL memory
read or successful payload return on that path. The probe stops at the declared
Watson platform boundary after real CRT validation/handler selection; native
explicitly rejects the invalid parameter. Windows diagnostics/termination and
custom invalid-parameter handlers are not reproduced by this check.
An additional unchanged-source observation records memcpy_s arguments as
(destination28001ea4, capacity4092, source0, count4092): the header already
occupies four bytes of the4096-byte CRT buffer.7818047a clears its remaining
capacity, then78180444 sets errno22 and selects the invalid-parameter handler.
That private CRT buffer mutation is source evidence, not native ABI equivalence.
NULL backing is an explicit unsupported access boundary in the native model,
not invented bytes from the oracle's FS/SEH zero page.

## Lazy processor selector

Whole execution revealed one game-global mutation missed by isolated codec
output comparison:44dd50 changes from2 to1. Dispatcher4428b0 checks this word
at actual longest-match invocations. With selector2, it executes443ac1's EFLAGS
and CPUID detection, then stores0 when `(signature & 0xf00) < 0x600`, otherwise1.
That first invocation still uses generic442770. Subsequent selector0 calls
with window mask0x7fff use4435e0; selector1 uses443aff without that mask gate.
Other selectors retain generic matching. The writer's codec uses mask0x7fff.

The controlled Unicorn detector returns0x306c4. This is an observed research
CPU, not a real Windows machine or the ARM Mac. Native portable C records
actual longest_match invocations and requests an explicit original processor
signature only when the live selector is2 and a match search actually occurred.
No x86 execution is introduced into the native runtime. All4353858 invocation
counts and the resulting full buffers agree in the whole-writer corpus, including
4074271 searches in its random-capacity case. Selector0/1/3 controls preserve
their words; selector2's observed signature chooses1. Other processor signatures
and actual Windows CPU behavior remain separate verification.

The initial key ends before the selector. A6500-byte synthetic key of `1`
overwrites the compiled-version pointer44dce8 with31313131. The real44043c
then faults reading that unmapped address, before codec allocations or a status
return. This cannot be treated as an ordinary long-key success. Native explicitly
rejects modified version-pointer backing; resolving alternate backing remains
open. The same key also overlaps tree descriptors,44dd50 and the security-cookie
global. None of those source globals is restored to manufacture a passing probe.
Native reads the key after compression so a selector change cannot be hidden
behind a stale key snapshot. The length clamp is statically recovered; this
corrupt-state probe does not dynamically prove its shorter-output branch.

## Name extent and failure scope

The original formatter's destination is entrySP−0x204. Its first subsequent
security cookie is500 bytes from that destination. Prefix `recording\` uses10
bytes: a489-byte name leaves room for its NUL, while a490-byte name overwrites
the cookie. The490-byte probe executes all five stream calls and cleanup, then
actually takes4450b2's mismatch branch to44556a. The probe stops at the failure
helper; it does not simulate a successful return or execute a Windows failure UI.

Native explicitly rejects this unsupported stack overwrite and rolls back game
records. It does not truncate the formatted path. This is distinct from the
original C++ path conversion's proven259-unit truncation. Faulting source paths
and native rejection are not successful whole-call equivalence. Likewise,
throwing observers are unsupported boundaries rather than original IO errors;
game-record rollback cannot undo host file effects already performed.

## Evidence boundaries

Source: tools/oracle_replay_writer.py. Actual EXE and pinned VC80 DLLs execute;
calloc/free, thread state and file-descriptor responses remain declared inputs,
as in [REPLAY_COMPRESSION](REPLAY_COMPRESSION.md) and
[REPLAY_STREAM](REPLAY_STREAM.md). No original distribution file is written.
The supplied recording comes from an accepted initialized first-tick snapshot;
this standalone writer is not an uninterrupted own result continuation.

Writer instruction hooks distinguish executed starts from a stopped NULL-read
instruction. Library PCs use actual code hooks. Decoded helper-block starts are
reported separately: a block observed before a fault may include unexecuted
instructions, so they are not a count of executed helper instructions. REP-copy
observations retain raw memory-hook masks separately and check complete actual
copies. Input storage and both16-byte guards remain unchanged.

The new corpus uses SHA-addressed blobs with **zlib-framed transport deflation**;
the blob's full uncompressed bytes, count and SHA are authoritative. This
transport is unrelated to the original replay compressor's output. Existing
fixtures retain their historical encoding and expected data.

The first suite terminated at the inherited4096-byte research string-reader
limit, before executing its long-key case. After widening only the observation
to the available global backing, the next suite reached the real44043c fault.
Its six completed cases were retained in an atomic checkpoint. After that
process was confirmed terminal, unmapped-access observation was added and the
remaining fresh CPUs continued the corpus. No live process was restarted for
silence, and no completed case was rebuilt from an expected after-state.
The following continuation finished the random-capacity, NULL-source and five
codec-allocation failure calls, then exposed the previously unhandled Watson
boundary. Its16 completed cases were retained before extending that observer
and continuing the remaining fresh calls. The actual−5/−2/−4 outputs were not
changed to turn failures into successful compression.

## Accepted comparison

[The report](../evidence/replay-writer.json) distinguishes21 direct whole-call
matches from five rejected source failures. It retains all26 actual captures:
11 compression successes, one capacity−5, eight stream−2 and five allocation−4
statuses; the modified-version-pointer case never returns from compression.
The ordinary input compresses10047 bytes. The random recording retains length
6492672 and its partial output on−5. No early return is introduced for those
numeric statuses or file failures.

Successful whole calls compare24350 descriptor requests/58522686 bytes, complete
compressed/adjusted storage with masks where backing exists, unchanged source
storage, whole globals, allocation liveness and4588a8, ordered format/allocation/
IO/close/free/clear/destruction, five stream states and normalized codec private
allocation events. A separate late-observer trial throws at stream destruction,
after both frees and pointer clearing in staged state, and verifies rollback.
It does not claim to roll back previously performed physical file IO.

Across all source captures there are27522 descriptor requests/71508038 bytes.
The difference is the two cookie-failure paths: original IO completes before the
cookie check, while native rejects the unsupported overwrite earlier. Those
additional source writes are not counted as native descriptor comparisons.
Source verifies365 codec helper returns,117 stream returns and882 completed REP
copies.116 of117 writer instruction starts execute;43de0c is skipped alignment.
3292 actual library code-hook PCs are retained; this is not every branch outcome,
and helper-block decoding is separately scoped above.

The raw corpus is44801203 bytes, SHA256
`44d61ea68aa666a43537ade0b2823f7d27d39f7e406bba7edd7df02e7b0e2326`.
The lossless fixture is36098192 bytes, SHA256
`662c1fe8b087b4e5e24686d8f39b3d64bc655a4487a79f3abbd4b333df8c97c5`.
Independent verification checks the full inflated bytes plus transport newline,
complete JSON, both hashes/lengths, all1882 zlib-framed blobs, all175 current
fixture hashes and174 unchanged prior pins. All10 vendor original/vendored
hashes are verified; the deflate.c change is exactly its marked invocation
observer. Evidence: build/research/replay-writer-artifact-verification.json.

Raw acceptance passed0.774s after a145.03s release build. Final packaged
verification passed five release tests in44.296s after a145.99s build: the whole writer0.885s,
the retained815 codec cases,66 stream sequences and both complete own notices
comparisons. NTSDNative linked. All source/SwiftPM jobs are terminal; no app
window or Windows file execution is inferred from these tests.
Python compilation,534 local Markdown links and the owned-file diff check pass.
Vendored whitespace is retained exactly apart from the marked observer.

Reproduce with `uv run tools/oracle_replay_writer.py --suite`, then
`python3 tools/accept_replay_writer.py`. The optional `--suite --resume` reads
only completed, hash-verified checkpoint cases after confirming the previous
process terminal; it starts a fresh CPU for each remaining case. Raw transport
must pass native comparison before publication. Existing fixtures are immutable.

Next: whole421cdc..422218 and the remaining tick tail. Full-match gameplay,
actual Windows files/exceptions, CPU variants and clean-macOS checks stay open.
