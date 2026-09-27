# WAV metadata audit: stop at the original consumer's data boundary

2026-09-27 UTC. The frozen first inspector19874 terminated1 at01:04:11.892989;
its traceback, source and observations remain unchanged. The assertion at line74
combined chunk-count and header bounds. A separate static diagnosis identifies
the count guard for source390, data\\heart.wav, SHA from the pinned409-source
publication. This is an audit limit, not an original or Native memory fault.

The572652-byte file has fmt at12 (18bytes), data at38 (569912bytes), then LIST,
DISP, bext and a long zero-filled tail. After256 chunk interpretations the next
offset is572612,40bytes before the RIFF end. No original code or media decoder
ran; neither input bytes nor expected output changed.

OriginalWaveLoader.swift stops its search at the first data chunk. Inspector2
therefore retains the same409 files,128MiB aggregate read bound and256-header
per-file bound, but stops after finding that first data block. It records the
uninterpreted RIFF tail length explicitly and still hashes every complete file.
The inventory makes no claim about later chunks, metadata validity or device
acceptance. This is a declared narrower static question, not exclusion of a
comparison mismatch; no game comparator or expected value is changed.

First inspection and two bounded diagnostic reads consumed60545570 file bytes
(including hash reads). Inspector2 consumes at most46236186 more; publication's
single complete-file preservation pass consumes15412062. Total122193818 remains
below128MiB. Do not add another baseline reread. Protected candidate manifests
are separate preservation checks, not new original asset inventories.

The first job must be terminal/absent before inspector2. Keep separate input pins,
job, source, observations and inventory outputs. Maximum3 audit rounds still
applies; no source capture, Native/audio execution, reserve reduction or approval
change. All other provisions of APPLICATION_MAC_AUDIO_PREFLIGHT_PLAN remain.
