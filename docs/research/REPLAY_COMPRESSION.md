# Original replay compression

The full815-call original corpus matches the public native Swift consumer.
This is the bounded codec dependency of [RESULT_RECORDING_PLAN](RESULT_RECORDING_PLAN.md),
not the complete43dd60 writer, file IO, an own initialized result continuation,
a returned gameplay tick or Windows execution.

EXE SHA256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The source executes whole43f4b0/ret16 and43f400/ret20 with actual440640,
440420,43f610,43f8a0 and their children. Original inlined REP operations perform
the copies. VC80 is mapped for resolved memory imports if reached; the initial
compression captures did not execute DLL instructions. Only calloc/free are
declared allocator boundaries. Their request order, failure ordinal, zero
backing and remaining ownership are retained. No host-compressed bytes enter
the original CPU.

## Native implementation and library provenance

The wrappers and1.1.4 literal match the compression interface in the official
[zlib1.1.4 archive](https://zlib.net/fossils/zlib-1.1.4.tar.gz). Its archive hash
is `9e3e973174f9910fd51539ef9ce94c86a3943d4f897fab8e9adf4b19e6a8291e`.
The natively compiled C subset retains the original license and source notices.
[upstream.json](../../native/Sources/NTSDReplayCodec/upstream.json) pins each
original and vendored file. The compression milestone changed two headers with
marked configuration includes: private symbol names, Darwin's Byte typedef,
allocator observations and copy observations. The subsequent
[whole writer](REPLAY_WRITER.md) also adds one marked longest_match invocation
observer to deflate.c. The compression algorithm and tables remain unchanged.

This source library is an implementation candidate, not a second behavioral
reference. Output acceptance depends on executing the NTSD EXE. An early349-case
native C comparison passed all statuses, output bytes, write masks and allocation
order. Modern host zlib1.2.12 differed on five successful level0 outputs in that
early set; matching a modern library or merely decoding its stream is inadequate.

`OriginalReplayCompression` is the public Swift consumer. It preserves the
original mutable output-length contract, including its unchanged value on
failure, partial output and previously defined destination bytes. Error statuses
are returned as data: the later source writer ignores that status and must not
be silently changed to discard the partial destination. The Swift consumer
serializes calls because the legacy C library initializes shared tables lazily.
There is no DLL, x86 execution, browser, system-zlib compression dependency or
decompression/file implementation in this native codec target.

## Allocation boundary and failure scope

Default initialization requests one5816-byte x86 state, then four65536-byte
allocations:32768*2 three times and16384*4. Native LP64 state storage is5920
bytes; the remaining request sizes and normalized allocation/free order agree
in the early corpus. Private C addresses/layout are not reconstructed game
addresses or an x86 heap emulation.

A failure of the first request returns-4 with no live allocation. Failures of
requests2..5 still issue all five requests and leave four allocations live.
The original calls43f8a0 before state status is initialized; it returns-2
without freeing those allocations, and the caller returns-4. This was discovered
by execution after an initial observer incorrectly required all allocations to
be freed on every return. The original results were not changed.

The native observer preserves this unfinished algorithm lifecycle in its result
before reclaiming private host storage. It does not reproduce Windows heap
exhaustion or assert identical leaked bytes. The whole game's allocation-failure
behavior remains a separate boundary; do not claim bitwise equivalence of these
different internal ABI layouts or silent resolution of the original leak.

## Output-write provenance

The initial memory-hook-only observer missed real output writes on the524288-byte
random input. It reported259526 written bytes although the destination contained
524454 output bytes. Both ranged and global memory hooks produced that same
incomplete mask. A separate simple REP-copy probe observed all bytes through1MiB;
the broader cause is not established. This is a limitation of the observed
instrumentation, not evidence that the original left its output unwritten.

The source now observes the actual output-copy instructions43f5c3/REP MOVSD and
43f5ca/REP MOVSB, and their successors43f5c5/43f5cc. For every completed copy it
checks DF0, the initial count, ECX0 on exit, exact ESI/EDI advancement and full
destination equality with the original pending bytes read before the copy.
These instruction-derived writes define the output mask. Raw memory-hook masks
remain separate evidence, and any raw observed write outside the verified REP
extent is rejected. No byte or register is written by these observations.

The524288-byte control passed this audit:68 completed REP instructions establish
524454 output bytes;26 copies have incomplete memory-hook coverage. Its full
bytes, statuses, masks and allocation order also match the native C candidate.
This single control is not acceptance of the full codec corpus.

## Full corpus and acceptance

The fresh full capture includes all levels0..9/default and invalid levels,
zero/short/exact capacities, each allocation failure, sliding-window boundaries,
random/repeating inputs, the complete6491672-byte first-tick recording and full
zero/random buffers. The two accepted GAMEPLAY_NOTICES parents have identical
recording bytes and provide two provenance records for one distinct codec input;
this is a supplied buffer, not uninterrupted own-gameplay execution.

A full random recording needs6493663 compressed bytes. The original631200-byte
writer capacity is6492672, only1000 bytes larger than the input. The original
returns-5, preserves that capacity word and leaves partial output. The larger
640000 capacity succeeds. The real first-tick buffer compresses to10047 bytes;
the all-zero6491672-byte control compresses to6326. One earlier capture exhausted
its400-million-instruction limit; the current2-billion limit completed both
large random cases. No live process was restarted because its log was quiet.

All815 calls compare31390143 output bytes/masks and normalized private allocation
events. There are321 successful returns,397 capacity errors-5,72 invalid-level
errors-2 and25 allocation errors-4, including20 unfinished source lifecycles.
The source checks11388 helper returns and5116 complete REP copies. All51 starts
of43f400 and all11 of43f4b0 execute. The union contains3208 EXE instructions and
zero DLL instructions; this does not prove every possible deflate branch or
every input byte sequence. Four cases retain incomplete raw memory-hook masks,
missing11570063 writes; their instruction-derived masks and output bytes match
native. The full corpus has53 successful-output differences from host zlib1.2.12.

The early native C349-case comparison was followed by a successful full815-case
C comparison. The five-sample Swift check passed after a140.69s build. Initial
compilation required explicit allocator prototypes for SwiftPM's modular system
headers and a Darwin Byte typedef. Copy observation was moved to zmemcpy because
platform fortified memcpy macros bypassed the first observer. These were native
integration/observation changes; no deflate rule or original expected output was
changed. The full public Swift raw comparison passed in0.509s after a140.32s
release build before fixture publication.

[The accepted report](../evidence/replay-compression.json) records scope and
coverage. The raw corpus is35880366 bytes; its lossless fixture is32660900 bytes.
Independent verification confirms complete inflated bytes plus the transport's
omitted final newline, full JSON, both hashes and
lengths, all531 transport blobs, all10 upstream file hashes and, at that milestone,
exactly two marked changed headers. All172 old fixtures remain unchanged among173 pins in
build/research/replay-compression-fixture-pins.json. Artifact evidence is
build/research/replay-compression-artifact-verification.json.

Final packaged comparison and both retained own-chain tests passed:3 release
XCTest/40.353s after a140.28s build, compression0.595s and own notices39.757s.
NTSDNative linked. Compiled codec objects expose only prefixed symbols; the app
has no system-zlib link dependency. All source/SwiftPM jobs are terminal.
Python compilation and654 local Markdown links pass. First link verification
found and corrected one relative README link. The owned-file diff check passes;
vendored whitespace warnings are unchanged upstream bytes, retained for hashing.
This does not establish app-window, device or Windows behavior. Next compose
real43dd60, including key/name strings, stream writes and cleanup,
followed by the complete result caller. The accepted own initialized boundary
remains421cdc; the full writer, tick, app output and completed match stay open.
