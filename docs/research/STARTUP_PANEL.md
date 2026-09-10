# Whole startup panel selection

[OriginalStartupPanel](../../native/Sources/NTSDCore/OriginalStartupPanel.swift)
implements actual43cf94..43cfb4 with all four original children on one source
CPU/stack. **212 complete caller executions match. Eight further source returns
consume unknown local bytes and are explicit native rejections with rollback.**
They are not220 whole native matches. The finite study follows
[STARTUP_PANEL_PLAN](STARTUP_PANEL_PLAN.md).

The children are [information reading](MENU_INFO_READING.md)43c4a0,
[content](MENU_CONTENT.md)43c780, [bitmap replacement](MENU_PANEL_BITMAP.md)43cc60
and [default writing](MENU_INFO_WRITING.md)43c690. Native composes these shared
implementations with its own globals, local provenance and bitmap generations.
Earlier standalone and panel-update fixtures remain unchanged.

## Reference and controlled environment

The pinned original EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
VC80 DLL SHA256 is
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Unicorn2.1.4 executes the original caller, actual child bodies/returns, integer
CRT functions, bitmap constructors/destructors and their cookie checks.

The caller begins after the earlier window helper, at declaredSP1000f004 with
controlled globals/device and preserved register inputs. The source rebuilds
initial globals from the pinned PE, then supplies device22003000. No saved
expected after-state is imported. Each child enters at1000f000, and the caller
stops before43cfb4 with SP1000f004. This is not a WinMain return or message loop.
Saved EBX/EBP/ESI/EDI, suppliedCW037f and the declared FS exception-list sentinel
ffffffff survive. Native processwide FPU/private C++ stack/Windows ABI is not
claimed. All13 bundled-library patches are disjoint from complete studied bodies;
this controlled source does not execute the installer or resume CRT/NLS startup.

Translated input-file bytes, fopen/read-close, info `_read` error responses,
allocator/DIB/COM and user-buffered output FILE are controlled boundaries. Input
chunks1/7/4096 are exercised. Content truncation/EOF is tested; arbitrary content
stream modes and Windows text translation remain the earlier explicit limits.
No actual game file or external network endpoint is written. No control pointer,
cookie corruption, memory fault or protection bypass is manufactured.

## Actual caller order

1. Call43c4a0 and test its return.
2. Only after nonzero, call43c780 and test its return.
3. Only after both nonzero, call43cc60 and test its return.
4. After zero from any of these, call43c690 exactly once.
5. Reach43cfb4 with the last child's EAX. No retry/cache writer or second content
   load is inserted into this startup caller.

The actual child return sites are43cf99,43cfa2,43cfab and43cfb4. All ten caller
instructions execute. Of212 supported calls,28 finish after bitmap success with
EAX1;184 finish after defaults with EAX18, the last formatted path length.
That18 is not a boolean success code or evidence that a file write succeeded.

The pinned `data/adinfo.txt` contains `now 0 4 <end>\r\n`, while ad0/ad1 text and
bitmap files are absent from the distribution. In the controlled original-file
case, information reading succeeds, content opening fails, bitmap loading is
skipped and defaults executes. For successful content, controlled rows follow
the recovered EXE format. A successful ad-path bitmap response is explicitly
bound to the original MENU_BACK1 DIB809×547, resource language1028. This is a
platform test binding, not replacement downloaded game content.

A failed bitmap can leave a newly allocated wrapper with null surface. Defaults
then changes date/index/period/paths but does not free, reload or rebind that
wrapper. Old resources are destroyed/freed before new allocation, including
allocation failure. SetColorKey-negative preserves the constructor's original
cleanup. These effects and all live/dead generations remain in native own state.

Thirty-two two-call sequences cover16 old/new bitmap conditions under both
backing patterns. Each second call starts with its own prior globals/resources;
source and native both retain freed generations when an address is reused.
The entire source has68 constructor and24 destructor returns. Their actual
return sites/pop counts and all90 bitmap children are preserved.

## Shared local provenance

Both information and content children enter with the same SP. Information owns
its observed184-byte region at entrySP-bc; content observes1104 bytes at
entrySP-454. Thus the information region overlaps content at offset398hex.
Original instructions and CRT calls run continuously between these entries.

The source records every actual write to the entire shared1104-byte region,
including private CRT stack writes. Its content observer separately seeds a
semantic mask from the preceding information region's actual output mask, then
tracks content writes. Every complete raw byte and both kinds of provenance are
retained. The independent audit reconstructs the shared region from its initial
backing and all651780 writes; it does not declare private CRT bytes native-owned.

Native starts unknown, copies only its **own** information local bytes whose
masks are defined into the398 overlap, and leaves all other bytes unknown. The
shared content helper now has an explicit `requireDefinedLocals` option. It
reads C strings and marker comparisons through typed byte reads, stopping at a
first mismatch/NUL as the original does. The startup composition enables it.
The old default retains the standalone helper's declared-backing contract, which
is rechecked with all original fixtures. A lazy file-source callback runs after
both path formats, preserving source request order. Write observation exposes
native global masks without using source stores as implementation inputs.

Native compares complete global bytes/write masks and all defined local bytes
plus every semantic mask at child checkpoints. It does not compare unknown raw
local bytes or claim that its retained semantic records are a private CRT stack
snapshot after later children reuse that physical storage.

## Unknown reads and rollback

There are eight source-return/native-rejection cases:

| Controlled input | Cases | First unavailable native byte |
| --- | ---: | --- |
| Missing information file | 2 | Information offset28 |
| Empty content, including the zero-line truncation control | 4 | Content offset604 |
| Header-only content | 2 | Content offset104 |

The missing-info comparison reads an unwritten end token. Empty/header-only
content leaves a failed-fgets destination containing prior stack backing; the
original subsequently scans it. All eight whole source calls still return to
43cfb4/EAX18 after defaults. None faults or stops before an unterminated scan in
this corpus. Their mapped stack happens to contain a NUL, unlike some old
standalone A5 controls; this does not recover its native/Windows provenance.

Native rejects the first unknown byte and restores the whole prior caller state.
It does not convert the rejection to content-false and continue through defaults.
All source later events/stores remain immutable and outside the native match
claim. The212 whole matches contain676 child returns/39704 child events. Rejected
prefixes add six completed information children and88 events, giving682 compared
child returns/39792 events under the combined, explicitly separate contracts.
The whole source has698 child returns/39894 child events and1396 parent events.

Two late native trials begin with their own live bitmap and fail after its
replacement, respectively after the subsequent defaults writer. Both restore
all prior globals, live/dead bitmap generations, locals and output. External
file/device effects must be staged until the encompassing operation commits.

## Evidence and acceptance

188 controlled cases contain220 caller executions. The source executes716EXE
and1486CRT instruction starts:10caller,132info,298content,156bitmap,30defaults,
87constructor/destructor and3cookie EXE starts. Static inventory740 includes
12 unexecuted h/H-link checks and12 alignment int3 bytes. Those remain separate
from dynamic coverage; all branch outcomes or runtime reachability is not claimed.

Source94418 global stores reconstruct every global snapshot and write mask;
source651780 shared-stack stores reconstruct the physical region. The708494976
reconstructed global snapshot bytes include source-only rejected continuations;
this is not a wholesale native comparison count. Full bitmap generation bytes/
masks, FILE/buffer bytes/masks, ordered requests, local provenance and caller
selection compare at their stated native boundaries.

Raw13 release tests passed5.276s/build193.29s. Packaged13 tests passed5.019s/
build0.30s without raw overrides, retaining information/roundtrip, both content controls (704 cases total),
both bitmap controls (118 total),534 writers and266 panel-update
cases under their unchanged historical contracts. NTSDNative linked; it remains
the Practice application and this startup composition is not wired into it.

The231 current fixture pins preserve all230 prior fixtures. Raw71000012 and
packed11866492 bytes, full JSON/SHA/all1502 blobs and10 codec vendor files verify
independently. The isolated native export has581 committed files, one modified
shared helper, two added native files and one fixture:584 files total. All six
foreign transform files remain untouched and excluded. Owned jobs are terminal.

The first probe stopped before any caller execution because it requested resource
language1033; the pinned DIB entry is1028. Correcting the lookup allowed the fresh
12-case probe and final capture. Both earlier source copies/logs remain. The
final observer narrows its stack audit to the entire shared1104-byte region;
the probe's broader stack trace is retained unchanged. Native rules and final
expected bytes needed no correction after comparison began.

CUA inventory again reported `Native apps: Error: Sky Computer Use native pipe
startup failed`. No window/input action executed. The native test PID was then
verified live and allowed to complete. This is a tool transport failure, not a
safety refusal. Actual window/input/latency/audio checks remain open.

[Source](../../tools/oracle_startup_panel.py),
[verifier](../../tools/verify_startup_panel.py),
[packer](../../tools/accept_startup_panel.py),
[tests](../../native/Tests/NTSDCoreTests/OriginalStartupPanelTests.swift),
[evidence](../evidence/startup-panel.json).
Exact jobs, source errors and pins: `build/research/startup-panel-work.json`.
Fixture transport deflation is research packaging; no EXE/DLL/Unicorn is used in
the native shipping runtime.

Next is actual43cfb4..43d078 date/time/music/cursor and the remaining earlier
window/critical-section/CRT initialization, then whole WinMain/dispatcher/app
composition. Unknown local provenance, Windows NLS, library transforms, actual
Windows/device/input/audio/latency, full matches/all original content and clean-Mac
acceptance remain open. This milestone does not complete the full game goal.
