# Original replay output stream

The source corpus executes66 complete construct/write/write/close/destroy
sequences from the C++ stream imported by43dd60. `OriginalReplayFileOutput`
matches the corresponding native descriptor-boundary behavior in all66 cases.
The complete writer, key transformation, ownership
cleanup, own initialized continuation and Windows filesystem remain open.

This is a dependency of [RESULT_RECORDING_PLAN](RESULT_RECORDING_PLAN.md),
following the independently compared [compressor](REPLAY_COMPRESSION.md).

## Original instructions and environment

[The producer](../../tools/oracle_replay_stream.py) verifies the original EXE
hash and resolves its four IAT entries against the pinned MSVCP80 exports:

| EXE IAT | Original function | Entry |
| --- | --- | --- |
|4470d8|ofstream constructor|7c43a26c, ret16|
|4470dc|ostream write|7c4442e2, ret8|
|4470e4|ofstream close|7c4336dc, ret0|
|4470e0|ofstream destruction|7c43f756, ret0|

MSVCP80 is extracted without executing the installer from the same pinned
redistributable as [the original CRT](../../tools/oracle_crt.py). Package SHA256
`8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd`;
C++ DLL SHA256 `372af797353f9335915cd06d4076bab8410775dcaf2dac0593197d7c41bbffb2`;
CRT SHA256 `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Neither DLL, the EXE nor Unicorn belongs to the shipping runtime.

Actual C++ locale/stream initialization and CRT conversion, buffering, fputc,
flush, fclose and destruction execute. Declared boundaries supply private
allocations, single-thread locking/PTD and open/descriptor responses. The
platform word781c37c0 is explicitly2; its startup producer78132179 is not run.
The open boundary supplies FILE fields(0,0,0,2,3,0,0,0) and descriptor3's
64-byte binary/non-append record, flags1, opaque handle13572468. The table
pointer781c4820 is bound to270e0000. `_flsbuf` reads that descriptor even when
`_write` is intercepted; it must not read the mapped zero/SEH page instead.

The first exploratory constructor failed because the CRT platform word had
not been initialized. Later static inspection found the missing descriptor
backing. Both were corrected as explicit environment inputs, then the complete
source corpus was freshly captured. No accepted expected fixture was rewritten.
The source preserves separate private C++/CRT allocations and object/FILE bytes;
their layout and process-global locale lifetime are not native ABI comparisons.
Full DLL startup, allocator exceptions, arbitrary locales/FILE backing, Windows
path validity/permissions and actual OS IO are outside this comparison.

## Recovered behavior

The caller requests output mode20/share40, then writes a four-byte little-endian
payload length and the payload, closes explicitly and destroys the stream.
The original MSVCP constructor selects binary `wb` and the wide FILE opener.
Its7c4275e2 conversion passes259 as the conversion limit and260 as destination
capacity. Under the declared C locale, nonzero byte values widen directly to
UTF-16; names longer than259 bytes are truncated by this original conversion.
This does not make an empty or long path a valid Windows filename: the opener's
success/failure is a supplied response in these path controls.

The first byte requests a4096-byte CRT buffer. The header and payload share
that buffer. Filling it exactly does not flush until another byte or close.
At `_flsbuf`7813ef8b, the next byte triggers the descriptor write. Stores at
7813f0b0..7813f0b6 retain that byte in the newly emptied buffer **before** the
write count is tested at7813f0d0. Thus a failed4096-byte flush can leave one byte
to be written by close; the remaining payload is skipped after stream badbit.

If the4096-byte allocation fails, actual `_getbuf`78142378 uses FILE+14's
two-byte local backing with unbuffered mode. Writes then request one byte each
through7813f0c5. This is not a two-byte buffered stream. Native exposes that
fallback only as an internal allocator stimulus; actual host heap pressure and
the different private native allocations are not claimed equivalent.

The five observed ios states distinguish the failure point:

| Condition | Constructor/header/payload/close/destructor states |
| --- | --- |
|Success|0,0,0,0,0|
|Open fails|2,6,6,6,6|
|Short/error write during payload|0,0,4,4,4|
|Short/error flush only on close|0,0,0,2,2|
|Descriptor close fails|0,0,0,2,2|
|Payload write and descriptor close fail|0,0,4,6,6|

Explicit close still requests descriptor close after a failed flush. Destruction
does not repeat IO after the FILE has been detached. The wider43dd60 caller
ignores these stream states and still frees both replay buffers; that caller
has not yet been composed. Native callback numeric failures follow this source
contract. A thrown callback means the research/platform observer itself failed,
not an invented original stream exception or rollback of external file effects.

## Corpus and comparison scope

All66 sequences complete330 whole C++ calls with saved registers, stack cleanup
and SEH restoration checked. Actual code hooks collect2950 original PCs:
1626 C++ and1324 CRT, excluding hooked boundary addresses and the unexecuted
stop. These are observed instructions, not all branches of these libraries.

The corpus includes empty/binary payloads, exact4096-byte boundaries, buffer
allocation failure, open and close failures, short/zero/-1 descriptor responses,
combined errors, all nonzero path bytes and path lengths255..512. Two inputs
come from the accepted codec: the10047-byte own-recording output and the entire
6492672-byte capacity-error destination. Neither has the writer's key applied;
these are supplied bytes, not uninterrupted whole-writer execution.

Native compares all1772 ordered descriptor writes/6664690 requested bytes,
wide open path/mode/share, close requests,330 ios states and the first buffer
attempt/fallback. Source private object/FILE bytes and other library allocations
remain evidence only; the native implementation does not simulate their ABI.
The initial64-case Swift comparison passed0.084s/build133.87s before the final
environment audit and two full codec inputs. Fresh66-case Swift acceptance
passed2.293s/build137.55s before fixture publication:54 use the public API,
12 use its internal buffer-allocation failure stimulus. The native open callback
then gained an explicit path/mode/share request structure; this changes no file
rule or source fixture. Final packaged4-test regression passed42.771s after
a138.78s release build: stream2.427s, retained codec0.608s and both own gameplay
notice chains39.736s. All source and SwiftPM jobs are terminal; NTSDNative linked.

All173 prior fixtures remain unchanged among174 pins. Independent verification
checks the entire inflated byte sequence plus the transport's omitted newline,
full JSON, sizes and hashes: raw29709098 bytes/SHA256
`9b57323c74522ef145c43acda807b9de67166b3eed88c32897df31ef029e9aad`,
packed20460176 bytes/SHA256
`b0e11e1f538cecdd40b7a81f30044817ece5d22c590794ee51265b27bc98a8b3`.
Artifacts are build/research/replay-stream-{fixture-pins,artifact-verification}.json.
Python compilation,664 local Markdown links and diff checks pass.
[The accepted evidence](../evidence/replay-stream.json) retains source/private
ABI limits. No app-window, device, Windows or completed
match claim follows from this dependency.

Reproduce source and native acceptance sequentially:

```sh
uv run tools/oracle_replay_stream.py --suite
python3 tools/accept_replay_stream.py
```
