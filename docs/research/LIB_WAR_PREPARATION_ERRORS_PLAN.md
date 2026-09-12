# War preparation: ordinary resource errors and subsequent release

The accepted [success matrix](LIB_WAR_PREPARATION_MATRIX.md) contains successful
platform responses. Its observer rollback tests do not establish original API
failure behavior. This finite study recovers that missing preparation contract;
War gameplay, own startup, Windows and app/device checks remain separate work.

## Reference, operation and boundary

Use the pinned original NTSD 2.4 EXE
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
lib.dll `28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`,
VC80 `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`,
original DAT/BMP files and the accepted bound preflight inputs. Original
instructions execute in Unicorn 2.1.4, CW023f, C locale, with explicitly supplied
allocation/Win32/COM responses. API failures below model ordinary resource or
operation failures. They are not measurements of host/Windows heap or devices.
Original files and all accepted results stay unchanged.

Trace complete World/Actor/global/resource bytes and masks, original reads and
writes, registers/stack/FPU, helper returns, API requests/results and allocation
lifetimes. These observations establish whether the caller ignores a failure,
retains a partial owner, frees preceding resources or reaches an actual memory
fault. No protected structure, control pointer or original file is deliberately
corrupted. A NULL returned by an allocation or failed interface request is an
ordinary declared API result, not an injected pointer overwrite.

Static file evidence is `war-preparation-errors-static1.json/.txt`, produced by
`tools/inspect_war_preparation_errors.py`: 330 War,105 arena,180 bitmap,88 copy,
457 music and59 recording-prefix instruction starts. This is not execution.
40c091 checks wrapper allocation, then40c0ad stores NULL and advances. The
release helper checks only its first layer at40c0ee;40c116/40c118 dereference
later wrapper/surface pointers. After calloc,43d2fd writes through its result
without a NULL check. Dynamic outcomes must be recorded independently.

## Frozen finite cases

Run29 independent fresh chains. Each first executes the original401 constructors
and the same ten accepted bound-preflight calls; compare each entire prefix
case and constructor parent bytewise to its immutable original counterpart.
Keep references and hashes of reproduced prefix bytes, and full atomic files
for every new Start and subsequent release call. Do not import an after-state
or resume any completed historical capture. Normal controls use both primary
and control inputs; all error cases use the primary input with five arena
layers, six CPU and two human participants. The first and last layers are0/4.

1. Two normal Start controls.
2. Eight Start cases: first/last wrapper allocation returns NULL; first/last
   bitmap image is unavailable; first/last CreateSurface returns-1; first/last
   SetColorKey returns-1. A missing image applies to both ordinary file and
   embedded fallback requests for that loader, without deleting a file.
3. Ten first-layer API cases: GetObject returns0 with no output;
   GetSurfaceDesc returns-1 with no output; GetDC returns-1 with no output;
   Restore returns-1; CreateCompatibleDC returns0; SelectObject returns0;
   StretchBlt returns0; ReleaseDC returns-1; DeleteDC returns0;
   DeleteObject returns0. Existing private output backing keeps its masks.
4. Eight music cases, installed only on entry to preparation: CoCreateInstance
   returns-1 with NULL output; each of the four QueryInterface results returns-1
   with NULL output independently; wide-name allocation returns NULL;
   RenderFile returns-1; conversion returns0 without writing its destination.
   Existing failed graph.log open, CloseHandle and ignored method results remain
   the declared parent responses. No successful pointer is paired with these
   newly declared failed create/query results.
5. One replay calloc returns NULL for the actual1*630e18 request. Preserve the
   old-buffer free/clear and all writes before any fault; do not map address0.

If each of the eight cases in item2 returns normally, continue that live state
through one next-Start selecting99, with normal new API responses. The existing
matrix's declared bridge44d020=202,451b84=0,44d024=99,44d028=0 and a Start press
drives this comparison. It studies release of the actual partially loaded
owners. It does not prove that gameplay between these Starts was played or
that every such state survives a full match. No continuation follows a source
fault. There are at most37 new calls, in addition to290 prefix reproductions.

Each scenario has its own terminal process and immutable inputs, outputs and
failure records. An invalid-memory observer only records access/address/size,
PC/registers and returns false; it must not map memory or continue execution.
Ordinary source faults are separate from normal returns. Unexpected harness
errors stop the batch for review, preserving every preceding result. A safety
refusal stops automatic retries of the affected operation; retain the exact
error, time, thread/session and operation and continue independent work only.

## Acceptance

Audit every new call's complete records/masks, ordered events, reads, stores,
helper returns and terminal boundary against its declared inputs. Check that
every intended failing API actually executes. Explain absent later requests
from original control flow. Keep unknown storage unknown and source faults
distinct from passing comparisons. Verify prefix reproduction without counting
overlapping parent calls as new startup coverage.

Native must reproduce returned source states, retained owners and request order
where the recovered owned-storage model supports them. Recover any newly used
unknown private backing before claiming its Native match. Explicitly reject
source fault paths with whole coupled-state/resource/event rollback; do not count
that rejection as a successful match. A normally returned NULL/partial-owner
source case cannot be reclassified as a source fault to avoid implementing it.

Retain the accepted256-case and22-case tests, add source-coupled error and late
rollback comparisons, verify raw and lossless packaged bytes/JSON/SHA/masks,
then run the relevant bundled release tests. Preserve325 old fixture pins and
the23 unrelated workspace files. Full preparation stays open while any required
failure path, backing provenance or Native comparison remains unresolved.
