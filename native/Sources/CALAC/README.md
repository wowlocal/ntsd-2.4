# ALAC decoder

The decoding half of Apple's ALAC reference codec (`codec/` of
<https://github.com/macosforge/alac> at the commit in `upstream.json`),
vendored unchanged under the Apache License 2.0 (`vendor/LICENSE`, and each
file's header). `NTSDALAC.cpp` is the only addition: a C interface for
`NTSDMusicDecoder`.

It decodes the packaged original tracks (`NTSDMacPlatform/Resources/OriginalMusic`,
lossless ALAC of the FFmpeg decode of `bgm/*.wma`) on hosts without
AVFoundation. The decode is checked against the manifest's PCM SHA-256 for
every track (`OriginalALACTrackTests`). The encoder is not vendored.

`vendor/EndianPortable.c` defines `TARGET_RT_LITTLE_ENDIAN` only for x86 and
Win32, and Apple platforms get it from `TargetConditionals.h`; on Linux aarch64
it was undefined, the decoder skipped its byte swaps and rejected the first
packet. Package.swift defines it for the non-Apple (little-endian) targets
instead of altering the vendored files.
