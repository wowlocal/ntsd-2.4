# Whole application art setup43e8e0

[OriginalApplicationArtSetup](../../native/Sources/NTSDCore/OriginalApplicationArtSetup.swift)
implements whole43e8e0..43e934, composing the existing whole401250 surface
clear. This dependency belongs to43e9a0's44dce4==1 branch. Despite the original
success string `LoadGameArt: Art loaded.`, this helper performs no resource load:
it issues one surface query, clears the current back buffer and emits a debug
string. The enclosing dispatcher and its own stack remain open.

## Reference and finite comparison

The [plan](APPLICATION_ART_SETUP_PLAN.md) declares the game behavior, reference,
controlled environment and acceptance boundary. The pinned NTSD2.4 EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Unicorn2.1.4 executes both original functions at CW023f, with declared COM and
OutputDebugStringA responses. This does not measure Windows surfaces, pixels,
actual device failure or host FPU behavior. EXE execution remains research tooling;
the native helper has no DLL/emulator/runtime executable patching.

225 independent calls cross five query HRESULTs, five clear HRESULTs, three
query-output extents and three local backings. Results include INT32_MIN,-1,0,1,
INT32_MAX. Query outputs write zero, eight or28 bytes after the size field.
Six further calls retain their own preceding local/global output. These are
231 successful source/native helper comparisons, not231 application matches.
Callbacks optionally change455608 between valid supplied surface tokens, so
native must consume its own callback output. No expected after-state is imported.

All693 requests and complete11570328 global bytes compare. Local comparisons
cover7392 query bytes and23100 clear bytes, with masks. The source independently
records4158 stack stores and465 adapter stores; reconstructing them reproduces
all stack/global snapshots. All26 helper and17 clear instruction starts execute,
with no CRT instructions or unexecuted return markers counted. This is instruction
coverage for these finite calls, not every branch outcome in the application.
All231 atomic case records and38 content-addressed blobs are retained.

## Request and storage order

The helper reserves32 stack bytes, loads455634, writes size32 at local offset0,
and calls that surface's vtable+0x54. The remaining28 bytes retain their supplied
backing. It never reads the result or the output fields. Thus a failed query with
no output still reaches clearing, with the untouched local bytes and masks kept.

After the query callback, it reads455608 again. Whole401250 clears that live
surface with color0, null rectangles/source, flags0x1000400 and the100-byte
DDBLTFX record described in [APPLICATION_DISPATCH](APPLICATION_DISPATCH.md).
At declared rootSP1000f000 the query record occupies1000efe0..1000efff and the
clear record1000ef70..1000efd3. They do not overlap. Only size100 and color0 are
written into the latter; its other92 bytes remain supplied backing. These offsets
and retained bytes are controlled caller boundaries, not recovered own WinMain
stack provenance. The repeated chain preserves prior fields and output masks.

A signed-negative clear result selects the exact original string
`UpdateFrame: Couldn't fill back buffer.\n` and returns0. Zero or positive selects
`LoadGameArt: Art loaded.\n` and returns1. OutputDebugStringA's numeric result is
ignored. The source restores its32-byte local frame and returns at SP1000f004,
preserving EBX/EBP/ESI/EDI and CW. It makes no global stores of its own; the observed
global changes are explicitly supplied callback effects. The dispatcher later
changes its flags independently of this helper result; that caller is not covered.

The native operation stages a value-semantic context. Four late exceptions at
query, clear, debug and final observation discard its staged changes, including
a changed surface reference and buffered events. Reference-type context internals
and already submitted external effects cannot be undone by a value copy; callers
must own value state and buffer those effects until the enclosing operation commits.
Unknown local fields remain unknown. Native extent/null guards are explicit API
rejections; this study does not reproduce corresponding source faults.

## Reproduction and limits

[oracle_application_art_setup.py](../../tools/oracle_application_art_setup.py)
produces the original corpus and atomic case files.
[verify_application_art_setup.py](../../tools/verify_application_art_setup.py)
reconstructs all source stores, verifies pinned PE instruction/string bytes,
complete globals/locals/masks and evidence transport.
[accept_application_art_setup.py](../../tools/accept_application_art_setup.py)
requires the completed isolated native acceptance and matching overlay/producer
before publishing the lossless fixture. Expected source bytes stay immutable.
The machine-readable report is [application-art-setup.json](../evidence/application-art-setup.json).

Raw release acceptance passed5tests/4.912s after212.31s build, including the
retained4348 service-key calls,420 clears and static-World initializer. No source
expected bytes or game rules needed correction. Raw corpus1424097bytes has SHA256
`658aecaee9837c4946d5ccc50c72e79c0b376e328632d88623865151476d85e3`;
lossless fixture66603bytes has SHA256
`7f23d128c5b92518348f06aaa7ca04177ff0804a588503b128188a36f045c484`.
All236 prior fixture pins remain unchanged;237 current. Full raw/packed bytes,
JSON/SHA,38 blobs,231 parts and10 codec vendor hashes are independently checked.
Final packaged5release tests passed4.695s/build0.32s without raw override.
All source and owned SwiftPM jobs are terminal0; NTSDNative linked.
Exact jobs and final packaged results are in
`build/research/application-art-setup-work.json`. The isolated committed6b69cc3
native export excludes the six foreign transform files. Full43e9a0,43e890
recovery, actual own stack/static-World/worker composition, CRT/NLS, installed
library routing/transforms, window/device/Windows/full matches/all content and
clean-Mac acceptance remain open. Linking NTSDNative does not prove those paths.
