# Private native replay compressor

C subset of zlib 1.1.4 (compression, and inflation for playback loading) by Jean-loup Gailly and Mark Adler,
downloaded from <https://zlib.net/fossils/zlib-1.1.4.tar.gz>. Archive and file
SHA256 values are recorded in `upstream.json`; the original license is retained
in `vendor/zlib.h` and all upstream source notices are preserved.

The original NTSD EXE is the behavioral reference. Matching a library version
string alone does not prove matching compressed bytes. Original-instruction
comparison of the complete wrappers is required before accepting this port.

Only `zconf.h` and `zutil.h` are altered, with marked includes for private
namespacing, Darwin's missing classic `Byte` typedef, allocator observation and
output-copy observation. Compression algorithms and tables are unchanged.
Inflation (uncompress, for the playback loader 43e620) is vendored unchanged; gzip, archive/file IO, DLL loading and x86 emulation are not compiled.

The wrapper records algorithm allocation/free requests and partial output
writes. The private native deflate state uses 5,920 bytes on LP64, versus
5,816 in the x86 EXE; comparisons distinguish these ABIs. Legacy late allocation
failures leave four algorithm allocations unreleased. Their lifecycle is
reported before private host memory is reclaimed. This does not reproduce
Windows heap exhaustion or claim identical leaked heap contents. The Swift API
serializes access to legacy lazily initialized tables.

All815 original calls now match the public Swift consumer's output bytes,
write masks, statuses and normalized allocation order. See
[the study](../../../docs/research/REPLAY_COMPRESSION.md) for the complete
comparison scope and oracle instrumentation limitations. The wider result
writer and full gameplay tick are still separate, unimplemented consumers.

The private prefix header undefines `DEBUG`: SwiftPM defines `DEBUG=1` for C in
debug builds, which would add zlib 1.1.4's debug-only `deflate_state` fields
(5,936 instead of 5,920 bytes) and its Assert/Trace code. Release and debug
builds therefore compile the same library.
