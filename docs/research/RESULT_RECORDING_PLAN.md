# Next whole result-recording caller

Static follow-up to [GAMEPLAY_NOTICES](GAMEPLAY_NOTICES.md). The codec, stream and
[whole writer](REPLAY_WRITER.md) are now independently implemented and compared;
the enclosing421cdc..422218 caller is implemented in OriginalResultRecording
and its full controlled/own comparisons are in progress. See
[RESULT_RECORDING](RESULT_RECORDING.md) for the current unaccepted work.
This records the concrete dependencies
of421cdc..422218 before extending the whole tick. EXE SHA256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The broader queue remains [TICK_TAIL_PLAN](TICK_TAIL_PLAN.md).

## Order and retained state

The296 caller instruction starts first increment450bbc when signed450bdc<100.
The result block is entered only when unsigned(450bdc−101)<=248; otherwise
control goes422944. Exactly101 additionally permits result serialization when
450be4 and450b80 are nonzero and450b84 is zero. Do not reduce this to the first
own tick's disabled result flags.

Eight result seats choose primary0..<8 or fallback10..<18. The source writes
ID, primary/fallback kind, team, combat statistics and outcome into the owned
4588a8 allocation; only the Object ID is serialized, not a native registry token.
Count is saved at+10. Mode4 copies451b64/68/6c/70 to+134/138/13c/140;
elapsed450bbc goes+144. Then450b6c=0 and450b70=2 are stored.

When4588ac and450b88 are nonzero, whole43df00 restores playback settings,
then the caller copies recorded sound flags+630bb8/+630bbc to458428/45842c.
Only after this restoration does it copy44fb6c and four function-key counts
into+8ac..8bc of the recording. Preserve this order and the two allocation
identities. The live400-slot scan counts living type0/team5 Actors; its result
feeds mode1's+8c0 value. Mode4 computes a separate packed value with signed
quotients/remainders and wrapping decimal accumulation at422147..4221f0.

The mode1 participant outcome also consumes **rootSP+64** at421eb1. Its
semantic producer already exists as `OriginalMatchRoundResult.stageDefeated`,
returned by `OriginalLoadedMatchEntry.run`. `MenuCycleReference` now retains
these own outputs in `Portion.roundResults` after checking the source snapshot;
the new native composition consumes that own result instead of importing
a word from the result-stage source snapshot.

Static candidate lifetime sites:

| PC | Observation |
| --- | --- |
|41d7d7|Root local initialized to0 on the unpaused path|
|41dd02|Stage scan writes its defeated flag|
|41de01/41e0d0|Restoration reuses it as a400-slot counter, ending0|
|41f12f|Apparent `[esp+64]` read is at root+4c after24 bytes of pending RNG arguments; it is an item slot|
|421039/42103d|Apparent `[esp+64]` store/read is at root+5c after8 bytes of pending RNG arguments; it is a numeric temporary|
|421eb1|Result caller consumes root+64|
|4222ce|Six pending pushes make `[esp+64]` a store to root+4c, NOT root+64|
|422673|Later mode1 result layout still consumes root+64|

The new [result-layout stack audit](RESULT_LAYOUT_PLAN.md) independently
propagates ESP across all833 decoded caller instructions through422994 and
checks normal-return cleanup. It confirms the two fixed-offset root64 reads;
indexed operands remain explicit. This is static CFG evidence, not execution.

The two misleading operands illustrate why textual searches for `esp+64`
are not lifetime proof. The whole intervening caller still needs a stack-aware
access audit before asserting preservation in all branches. Paused rendering
has no newly assigned round result. Keep unknown values explicit until read.

An additional [primary own-path audit](../evidence/result-stack.json) now
executes the complete initialized GAMEPLAY_NOTICES chain without changing its
accepted full result. tools/oracle_result_stack.py observes89 total accesses
over startup/menu/match entry. From the last41d7d7 initialization through421cdc
there is exactly one access: that four-byte write0 at rootSP64. Final value0
agrees with the existing own round producer. No source stack word is injected.
This establishes preservation for this own path; the control variant and other
branches remain open. Native must still retain its own returned stageDefeated
when composing the result consumer.

## Whole43dd60 writer and compression dependency

43dd60..43def8 contains117 instruction starts, including real SEH/cookie setup
and restoration. It formats `recording\%s` using the format at44a170 and
the name at44fd98. The path is original output behavior; research
must record the intended write without modifying the original distribution.

The function allocates zero-filled0x631200 bytes and calls43f4b0 with the
entire0x630e18 recording, a mutable output-length word and the new allocation.
The return status is ignored by this caller. Do not stub compression success,
replace it with transport-fixture deflation or compress only used input events.

43f4b0..43f4cb is an11-instruction stdcall wrapper that passes level−1 to
43f400..43f49e/ret20. That51-instruction wrapper constructs a0x38-byte stream,
uses literal **`1.1.4` at44a2b4**, calls440640 to initialize,43f610 with flush4,
and43f8a0 to end. It only publishes the actual output count on the stream-end
path. These signatures and the version literal identify a zlib-style interface;
matching compressed bytes requires executing the original implementation.
[REPLAY_COMPRESSION](REPLAY_COMPRESSION.md) now implements this dependency with
a private native C1.1.4 subset:815 whole original calls match the public Swift
consumer. All51+11 wrapper starts and3208 EXE instructions execute. The corpus
retains partial output, allocation failures, distinct internal ABIs and the
REP-derived write-mask evidence. This is not the whole writer or Windows IO.
Modern host zlib1.2.12 differs on53 successful outputs in that corpus.

After compression,43dde4..43de4f adjusts only the leading
min(strlen(44d7a0),compressedLength) bytes by `byte + keyByte - 0x30`, modulo256.
The repeated strlen observes the current key; it is not a cyclic key across the
whole payload. The EXE's initial key has1345 bytes and SHA256
`a1e3e58e52cb7091bff6e1ea7ed8e14274b882f51134af69ca4ce0a72cc8613b`.
Actual live global ownership, not an assumed immutable key, must supply it.

Imported MSVCP80 calls construct basic_ofstream with arguments(path,0x20,0x40,1),
write the four-byte length, write the adjusted payload, close, then destroy the
stream. The EXE does not branch on those return values. Real file/stream responses
and the output byte requests now have bounded evidence in
[REPLAY_STREAM](REPLAY_STREAM.md):66 sequences compare all1772 descriptor writes/
6664690 bytes and330 ios states to Native. Actual C++ and CRT buffering,259-unit
C-locale path truncation, retained byte after failed flush and unbuffered fallback
execute. Open/descriptor/allocator/thread responses remain declared; whole DLL
startup, private ABI/heap pressure, writer composition and Windows IO are open.
The function frees the temporary allocation, frees global4588a8, clears4588a8,
and performs stream destruction before SEH/cookie restoration. It does not leave
a successfully saved replay buffer alive. The caller then clears450b80 and,
when the result timer is still101,450b84.

## Required comparison

Compression and output-stream behavior are independently compared above.
[Whole43dd60](REPLAY_WRITER.md) now has21 successful whole-call matches plus five
explicit source-fault rejections. It retains live key/name/selector globals,
NULL and codec errors, exact stream IO and ownership cleanup. This is a supplied
recording buffer, not an initialized result continuation or Windows file proof.
Next compare the entire296-instruction result caller,
including mode1/4 branches and both fresh own initialized continuations.
Allocation failures, insufficient compression capacity, path extents and source
stream exceptions must be investigated rather than assigned convenient success.
Result table rendering from422218 remains a subsequent consumer.

Static artifacts are build/research/result-writer-static.asm,
result-recording-static.asm andresult-writer-static-plan.json. The plan itself
does not execute instructions or create a fixture; the linked codec study has
its own dynamic evidence and explicit scope.
