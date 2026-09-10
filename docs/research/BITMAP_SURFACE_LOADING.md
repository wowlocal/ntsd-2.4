# Bitmap image loading, surface copy and own front resources

`OriginalBitmapSurfaceLoading` now implements whole43ed10 and4013d0.
Fifty-nine direct source calls match Native; two further original returns require
unknown private stack fields and are explicitly rejected with rollback. They
are not successful native matches. Eight fresh own startup/dispatcher chains
also continue the first allocation through the front-resource caller: seven
reach settings call427089, and one stops before a NULL metadata write. The
World and application dispatcher have not returned.

The [finite plan](BITMAP_SURFACE_LOADING_PLAN.md) follows
[APPLICATION_DISPATCH_ENTRY](APPLICATION_DISPATCH_ENTRY.md). Earlier bitmap
constructor/resource corpora retain their declared43ed10 boundary and all their
immutable expected data. This study executes that dependency and its copy child.
The selected native front path now composes those implementations through an
optional constructor provider, preserving the old provider contract unchanged.

## Reference and test environment

The pinned EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
the actual MSVCR80 SHA256 is
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Unicorn2.1.4 executes the original helpers, constructors and actual CRT memset.
The23 distinct front-menu PE DIBs and original District `district3.bmp` are
retained in full and independently checked against their original bytes.
The original missing `sprite\sys\ad0.bmp` supplies the both-image-loads-fail path.

Win32 image/GDI, DirectDraw COM and allocation results remain declared platform
inputs. They are not actual Windows calls, raster comparisons, scaled image
measurements or native device output. The file control requests17×23 but supplies
GetObject metadata from the original DIB as an explicit independent API output;
no scaling behavior is inferred. Positive/extreme HRESULTs are numeric controls,
not assertions that a particular Windows driver returns them.

The own paths preserve the complete174-event WinMain parent and prior loop/
dispatcher entry without changing CPU, stack, registers, globals or resources.
New API bindings are research adapters; existing own DirectDraw identity is
retained. Direct helper calls instead declare their own stack/arguments and
objects. Their inherited Unicorn CW is0; own startup establishes037f. Neither
value is changed by these integer-only new paths or claimed as host FPU state.
Direct controls use distinct output-dimension and optional-format storage;
output/format aliases and reentrant platform delivery are not established here.
Earlier real CRT initialization/NLS and the other installed-library routes stay
open. Normal constructor cookie checks execute; no control/protective storage
is corrupted, no protection is bypassed and no arbitrary fault is continued.

## Original loader43ed10

The original first obtains the module handle and requests LoadImageA with
flags2010, using the incoming ECX/EAX width/height and EDI name. On a zero bitmap
handle it obtains the module again and retries with flags2000 and both dimensions
zero. These flags select file loading plus a DIB section, then a module-resource
DIB section; the API meanings are documented by
[Microsoft LoadImageA](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadimagea).
The first module request occurs with five future LoadImage arguments pending;
the exact stack is retained, without a native private ABI claim.

If both attempts return zero,43ed10 returns zero without writing output dimensions.
Otherwise it requests a24-byte BITMAP through GetObjectA and ignores its numeric
result. The documented API output/zero-failure distinction is in
[Microsoft GetObjectA](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-getobjecta).
Native requires the width/height fields to have actual API-produced bytes.

The original clears108 descriptor bytes through4450a0 and actual78144a20 memset.
It writes output width then height before requesting the surface. The descriptor
contains size108, flags7, height/width at8/12 and supplied surface caps at104.
An optional eight-word pixel format copies only words1…7 into76…100 and changes
descriptor flags to1007. The pixel-format size at72 stays zero; Native does not
invent a32-byte size there.

CreateSurface must return **exactly0** to continue. Any other result returns0
without DeleteObject; output dimensions already survive. A controlled positive1
API response also supplies a surface pointer, which the original leaves unused.
The source retains both that allocation and the unreleased bitmap observation.
Native preserves this algorithm's requests/outputs; no host heap or Windows
leak-byte equivalence is implied.

On exact0,43ed10 calls the whole4013d0 copy helper, ignores its result, calls
DeleteObject on the bitmap, ignores that result and returns the created surface.

## Original copy4013d0 and constructor

A zero surface or bitmap returns80004005 without platform calls. Otherwise:

1. Restore the surface, then CreateCompatibleDC(0), SelectObject(bitmap) and
   GetObjectA(bitmap,24). Their numeric results do not stop the helper.
2. Use each explicit source width/height when nonzero; otherwise read that
   dimension from BITMAP. Preserve signed32-bit argument patterns.
3. Request GetSurfaceDesc with size108/flags6. Other private descriptor bytes
   remain unknown natively; the API result itself is ignored.
4. Call GetDC. Only exact0 performs StretchBlt with destination0,0, the queried
   surface dimensions, supplied source rectangle and SRCCOPY00cc0020, then
   ReleaseDC. StretchBlt and ReleaseDC results are ignored.
5. DeleteDC is requested even when GetDC returned nonzero. Return the saved
   GetDC result, not the later GDI/COM result.

The corpus fields `surfaces.released` and `dcs` mark Release/DeleteDC **requests**,
not proof of object destruction. Release returns17 in its control; DeleteDC can
return0. Bitmap `deleted` records the declared DeleteObject result. All numeric
responses and ordered requests remain available alongside these bookkeeping flags.

The new constructor entry uses these loader/copy routines. It preserves output
dimensions even when a later CreateSurface failure returns no surface. It then
performs the original required-resource diagnostics or SetColorKey. A negative
color-key result still reports, releases and clears the wrapper surface word;
all dimensions and the wrapper return remain intact. The old constructor API,
which explicitly supplies43ed10 results, retains its previous behavior.

## Own allocations, metadata and rollback

Each own continuation starts at the actual pending4450ac from the accepted entry.
Wrapper allocation begins at28010020 after the independently rebuilt empty parent
bitmap registry; subsequent successful allocations advance2000. A5 backing and
NULL allocation responses are declared allocator inputs, not host heap content.
The startup device comes from own457578, not an injected surface/global snapshot.
Every original43ee50,43ed10 and4013d0 executes on the same CPU and stack.

Seven paths reach427089/SP1000ea74 with load flag44d068 still1, World458b00 still
zero-filled, and all resource/glyph writes complete. They include restore/minimize,
a missing first image, negative first CreateSurface, positive last CreateSurface,
negative last color key and NULL cursor allocation. The eighth has a NULL MENU_CLIP
wrapper and stops at424ca4 before its first metadata write. Page0 remains mapped
for normal SEH; this stop does not execute or legitimize a NULL write.

Across these paths179 allocation requests yield177 constructors and177 full
wrapper records:1418832 bytes plus masks. Each settings path compares6795 ordered
parent writes after the previously accepted phase toggle; the NULL metadata path
compares61. Global pointer stores, two-byte player names, literal rectangles and
interleaved six-font tables all use Native's own producers. Surface word+0 is
canonically1/0 only after checking its actual returned surface binding; other
wrapper bytes and masks compare literally.

After that matching staged prefix, Native reports the pending settings or NULL
metadata dependency and rolls back the entire enclosing loop iteration. Own
startup, prior callback, MSG, counter, baseline, globals and resource ownership
survive unchanged. Six additional failures occur at the first module request,
last surface creation, last bitmap deletion, last color key, final font metadata
write and settings-boundary observer. Each verifies the same complete rollback.
External effects must remain buffered until the enclosing transaction commits.

## Scope of comparison and evidence

The69 source cases contain51 direct loaders,10 direct copiers and8 own prefixes.
Two direct loaders return using unwritten private fields: failed first GetObject,
and failed surface description followed by successful GetDC. Native explicitly
rejects the required unknown read and rolls back. A copier with explicit nonzero
source dimensions can ignore failed GetObject output; another with failed GetDC
does not read the missing surface dimensions. Both of those controls match.

All106 loader,88 copier and75 constructor instruction starts execute across the
corpus; this is not all branch combinations. There are1987 new EXE starts and33
actual CRT memset starts,226 memset/230 copy/228 loader/177 constructor returns.
Thirteen library patch spans are disjoint from these instructions. Source traces
retain82345 CPU stores and1123 API outputs, reconstructing3456072 global bytes,
635904 stack bytes and every wrapper byte/mask. Complete own parents reproduce.

Native compares59 direct returns,8 staged own prefixes and the pre-rejection API
requests of the two unsupported cases:3783 API requests with26108 owned structure
bytes. Another33448 compared-request bytes stay unknown and are asserted zero/
false natively; their original values remain immutable evidence. This is not
full native equality for private structures or the whole original stack. The
full source corpus additionally retains requests after those two rejected reads.

Unicorn omits the caller-sentinel code hook on11 short direct returns. Actual
post-execution PC30000000/SP1000f004, result and preserved registers finish the
observer record; the sentinel is neither executed nor counted. The initial
24 completed candidate cases remain byte-for-byte unchanged, apart from new
terminal-hook metadata. Earlier direct-observer initialization and method-name
collisions, plus the terminal observer assertion, are retained with their logs.
No original expected bytes or game rules were corrected to obtain comparison.

## Acceptance and remaining work

Raw10 release tests passed6.207s/build124.59s; strengthening the fresh own ordered
metadata comparison passed10 tests6.299s/build57.91s. The first build reached
NTSDNative but test compilation found a duplicate local name; only test bookkeeping
needed correction. Review also moved direct-copy test object metadata to original
DIB-derived inputs before execution. Final packaged10 tests passed6.257s/build0.27s
without a raw override, including prior entry, front-resource, initial-interface
and panel-bitmap corpora. The final isolated610 files contain607 committed base
files plus owned additions, and exclude six unchanged foreign worktree files.

Raw19573929bytes SHA256:
`1fd0fddd03875cf0a34e15d1dbea786e35cceafc786c7df99522d5d916dbfd6d`.
Lossless fixture5571380bytes SHA256:
`6e88a23fca997cad390cad50c6b940f7ebbcc77f41bc6d4471e47462d70c8b14`.
Full raw/packed bytes, JSON/SHA,546 blobs,69 atomic cases,24 original assets,
239 unchanged prior fixture pins and10 codec vendor files verify;240 fixtures
now exist. All owned source and SwiftPM jobs are terminal. Do not restart the
completed candidate2 source capture.

Tools: [source](../../tools/oracle_bitmap_surface_loading.py),
[independent verifier](../../tools/verify_bitmap_surface_loading.py),
[acceptance](../../tools/accept_bitmap_surface_loading.py).
The [report](../evidence/bitmap-surface-loading.json) and
`build/research/bitmap-surface-loading-work.json` retain exact jobs and boundaries.
NTSDNative linked; this composition is not wired into the Practice app. CUA again
reported`Native apps: Error: Sky Computer Use native pipe startup failed`.
No window/input action, device pixel/audio or latency check occurred.

Next continue actual423480 settings on this own stack/CRT/resource state, then
the early screen and whole World/dispatcher return. Earlier CRT/NLS, private
backing, library transforms, worker/application integration, actual Windows,
window/input/audio, complete matches/all content and clean-Mac acceptance remain
open. The full game goal remains active.

Continuation: [APPLICATION_SETTINGS](APPLICATION_SETTINGS.md) now executes the
whole settings helper from seven fresh own parents through42709b. Its native
scratch remains unknown until written; the full World/dispatcher still awaits
the screen consumer. The original bitmap fixtures above remain unchanged.
