# Own loading prologue and common sounds

The three accepted [own menu input](APPLICATION_MENU_INPUT.md) activation chains
now execute41bc90 through its prologue, MENU_WAIT,18 common WAV calls and final
presentation. Nine source/native prefixes reach the actual catalog allocation
request4450ac:81273768 bytes, caller41bff5, SP1000e430. Three additional failed
CreateSoundBuffer cases stop before the retained unsafe40187a continuation and
are rejected natively with rollback. These are nine completed prefixes and three
explicit rejections, not12 successful loading calls.

The [finite plan](APPLICATION_LOADING_PREFIX_PLAN.md) fixes three unchanged own
parents and, from the default parent, missing-file/short-data/create failures at
WAV positions0,8,17. The source executes the pinned NTSD EXE, bundled lib.dll and
VC80 on Unicorn2.1.4. Its full earlier relocated library attach, independently
entered WinMain and delivered mouse callbacks reproduce unchanged on the same
CPU. No parent register, stack, World, held input, RNG or resource is reset.
MMIO, COM, allocation and copy responses remain declared research boundaries;
the WAV files and bitmap inputs retain their original bytes. No Windows sound
DLL, allocator pressure, host device or private native ABI equivalence is claimed.

## Actual loading entry and lifetime

The own loading call enters atSP1000ea6c, with returnPC424746 and target31003000.
Normal source prologue aligns ESP to64 bytes, installs its ordinary SEH frame
and stores its cookie/saved registers. The resulting bodySP is1000e43c, distinct
from the historical controlled loader's1000e9fc. The phase450b90 changes0->1;
the own pause remains0. Twenty separate byte stores clear the two10-byte local
command arrays at body+434 and body+440. Their intervening padding and private
prologue storage never become native input.

MENU_WAIT uses the earlier own bitmap wrapper and target through real43f010/
43ef70/COM. The already freed background wrapper remains dead. All preceding
bitmap bytes/masks and five menu sound buffers survive unchanged. The original
then clears400 dwords at457588 and80 at453e10, loads the18 paths in EXE order,
writes count18 to45843c and presents through the retained primary/back surfaces.
The negative presentation response from the third parent is ignored. No library
text path is called in this particular prefix; the installed library/DC state
and CRT/RNG remain unchanged. Its earlier installation remains part of the parent.

New WAV temporary/lock regions are disjoint declared allocation backing. Their
original source bytes and masks, descriptor/format, caller output slots and
live/dead status are retained. No old audio storage is overwritten by the new
adapter. A missing file returns0 with its output cleared and no temporary;
a short data read returns0 while retaining its partially written temporary.
The caller ignores both false returns, loads subsequent files and still stores
count18. The three short-read allocations remain live in the algorithm result.

Failed CreateSoundBuffer follows the actual message/free path to40187a, where
the retained WAV contract stops before Lock/copy using the failed result and
freed temporary. This study does not execute a memory fault or continue past
that boundary. Native rejects the enclosing pending prefix instead of claiming
success. It retains the isolated child's explicit rejected result for byte/
ownership verification; no partial prefix result is committed.

## Native comparison

`OriginalInitialLoadingCommon` composes the existing non-playback prologue and
common sound loader. The older full `OriginalInitialLoading` uses that same
composition, retaining its complete catalog/pool/UI comparisons. The optional
output-store observer follows401526's clear before opening the WAV and40193d's
store after copy/unlock/free. The clear regions now expose their actual dword
store order. Arithmetic, resource lists, bytes and failure rules are unchanged.
The original public WAV call form remains available through a forwarding overload.

The own comparison obtains its target, globals, resources, allocator registry,
library/DC and RNG from the pending menu iteration. It checks every generated
event against full source globals and compares every completed wave, PCM buffer,
mask and checkpoint. Its two command arrays contain independently produced zero
bytes; private source stack storage is never imported. Five native late failures
cover the phase store, MENU_WAIT Blt, a middle PCM copy, final presentation and
prefix pre-commit. The caller retains all previously completed message/menu
iterations and rolls back the pending one at either failure or the still-open
catalog allocation dependency. External effects must be buffered until commit.

Source audit:223 full states,27611 CPU and2302 API stores/7118519 bytes;
6241 local reads/22892 bytes,12 normal SEH stores.187 whole WAV returns plus
33 bitmap/clip/presentation helper returns;872 wave records/7243472 bytes+masks
and5575 unchanged bitmap records/44689200 bytes+masks.566 actual EXE instruction
starts execute; zero new DLL/CRT PCs. These inventories are not all branch
outcomes or evidence of a complete loading return.

## Acceptance and remaining work

Jobs and final acceptance are recorded in
`build/research/application-loading-prefix-work.json` and the
[evidence](../evidence/application-loading-prefix.json). The first nominal source
probe passed. The missing-file probe exposed a MessageBox routing omission after
the parent's bitmap APIs were installed; the adapter now resolves that existing
IAT binding. The final12-case source run completed and must not be restarted.
The source verifier initially incorrectly excluded40187a from a whole case with
earlier successful WAV calls; it now distinguishes those earlier executions from
the stopped final call. No original expected byte changed.

The raw corpus has71768199 bytes, SHA256
`2bba3691974e5202add664270e8fc2f60d7a9b80cee5a1f6e7163732bf33c8a5`.
Initial raw7 release tests passed57.010s/build209.52s, including both retained
full initial-loading controls, the own menu-input corpus and431 WAV calls.
Final raw7 tests passed57.097s/build198.64s. Packaged7 tests passed56.288s/
build0.32s without raw overrides. All source/SwiftPM jobs are terminal.
Full raw/packed bytes/JSON/SHA,7097 blobs,12 atomic parts,24 bitmap and18 WAV
assets,10 vendor files and245 prior pins verify;246 current fixtures. The new
fixture is37335552 bytes, SHA256
`47704282bfa6080a71b795519d3ca486ea66928195fb2d936fcace5df4af8977`.
The623-file isolated package excludes the six foreign working files.
NTSDNative linked; no app window or device was exercised.

Next satisfy the actual81273768-byte catalog allocation request and compose
4122f0 with this own global/device/target/resource state and the installed loading
screen helper. The loader's catalog/pool/UI/input/return, following424746 held
clear and whole application iteration remain open. Worker execution/delivery,
full CRT/NLS, actual Windows, a complete Naruto/Sasuke District match, all content/
network/replays and clean-Mac acceptance remain part of the active full-game goal.
CUA inventory returned no apps/browsers and its native pipe failed to start, so
no window or device was exercised in this study.

The historical catalog adapter assumes60000020, which overlaps this study's
declared common-WAV regions. Its fixed address must not be remapped over retained
PCM/temporaries. Future own allocation/record observers need disjoint storage;
historical pointer-normalized controls remain unchanged. That adapter also uses
separate CRT scanf and bitmap-load response boundaries, so attaching it alone
does not establish own CRT/library/bitmap lifetimes. Resolve those boundaries
explicitly before claiming the new catalog join.

Tools: [source](../../tools/oracle_application_loading_prefix.py),
[verifier](../../tools/verify_application_loading_prefix.py),
[acceptance](../../tools/accept_application_loading_prefix.py).
