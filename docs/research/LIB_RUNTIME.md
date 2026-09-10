# Bundled library changes required for native game fidelity

The actual application entry loads the bundled `lib.dll` before the CRT
initializer tables. Its process-attach code installs twelve game-code jumps
and one two-byte patch. The native port must implement those behaviors without
loading the DLL or patching executable memory in its shipping runtime.

This is a correction to the scope of the preceding gameplay comparisons. Those
fixtures execute the pristine pinned EXE below the library-loading entry and
remain immutable, useful controls. They do not prove the behavior of the
application with its bundled library loaded. The full-game goal remains open.

The first native replacement is
[OriginalLibSurfaceText](../../native/Sources/NTSDCore/OriginalLibSurfaceText.swift).
It matches276 calls through the actually installed401290 jump and complete DLL
text routine, including six retained-state calls. Native preserves transparent
background mode, the retained DC and the original HRESULT behavior.
[LIB_STAGE_COMMANDS](LIB_STAGE_COMMANDS.md) now compares the command hook and
three whole-preparation hooks, connecting their own requested-ID output to the
whole consumer. [LIB_ACTOR_CONTROL](LIB_ACTOR_CONTROL.md) additionally compares
7168 whole control calls through41408b, retaining the inserted state85/86 rules
and their live EDI/x87 provenance. Those states are absent from the original
loaded DAT tables; their new branches are controlled cases.
[LIB_WORLD_CONTACTS](LIB_WORLD_CONTACTS.md) now compares both contact hooks
inside10661 whole calls, preserving all7925 pristine outcomes and late rollback.
New contact kinds/state20 are likewise absent from the original loaded catalog.
[LIB_WORLD_HITS](LIB_WORLD_HITS.md) now composes both hit hooks inside18137
whole calls. The unexpected0xb2 read stride and literal binary-Z addend are
preserved. The latter changes164 old kind8 outcomes; fresh pristine controls
prove that only their binary-Z words differ. Original data has6000+ effects,
while2175 potential stride words have unknown backing and remain outside the
controlled successful domain. [LIB_LOADING](LIB_LOADING.md) now compares318
complete loading calls with the label jump/two-byte patch, real output children
and message-pump return. One remaining transform destination, enclosing
library-enabled callers and a fresh initialized application join remain open.

## Pinned artifacts and actual entry path

| Artifact | Bytes | SHA256 |
| --- | ---: | --- |
|NTSD 2.4.exe|31715328|`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`|
|lib.dll|6144|`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`|

The files come from the same accepted original distribution. No on-disk source
file is modified. A source-only Unicorn2.1.4 VM executes this sequence:

1. PE entry445560 calls4464c4.
2. 4464c4 calls the original security-cookie initializer445a5d, with declared
   Windows clock/process/thread responses.
3. 4464c9 pushes the original `lib.dll` string at4464ab;4464ce calls the real
   LoadLibraryA import slot447068.
4. The declared loader maps the pinned DLL at its preferred base10000000 and
   enters its actual10001b62 entry with process-attach reason1. The same CPU
   executes the full installer and its original helper code.
5. On its nonzero return, the loader supplies module10000000. The EXE returns
   to445565, where the following jump to44529f is the unexecuted stop.

The detour4464c4 lies in file-backed .text padding beyond its declared virtual
extent. A section-only llvm-objdump inventory omitted it. Actual execution and
byte-checked decoding from the observed entry recover it; the file-backed code
must not be discarded merely because it falls outside the virtual-size label.
This qualifies the earlier static path in [FPU_PRECISION](FPU_PRECISION.md):
the later C initializer's precision helper is still real, but the library load
precedes it. The new installer stop retains CW037f and does not yet execute
those CRT tables or establish the application's final CW023f.

## Installation evidence

Three fresh whole-entry runs vary declared clock/process/thread responses and
allocation addresses. Four separate DLL-entry controls use notification reasons
0,1,2,3. These direct notifications are controlled calls, not a Windows loader
lifecycle test. Reason1 performs installation; reasons0/2/3 make no allocations
or patches and return their unchanged numeric reason. Each whole-entry attach
returns1 from DllMain and the declared loader then returns the module token.

Every attach requests VirtualAlloc for4000 and20000 bytes with arguments
`(NULL, size, 0x1000, 4)`. The source retains the two returned addresses in DLL
data+0x92/+0x96. The declared allocation boundary supplies zero-filled mapped
pages. Their later gameplay use is not established by successful allocation.

The original installer performs13 RtlMoveMemory requests totaling62 bytes.
Each is bracketed by VirtualProtect calls:26 protection requests per attach.
The source builds its relative-jump bytes itself. The API adapters apply those
exact bytes to the research VM and restore declared page protection values.
The source ignores numeric copy/protection outcomes; this corpus supplies
successful outcomes and does not claim failure or real Windows permission
behavior. Native does not reproduce this installation mechanism.

The independent verifier rebuilds both mapped images from pinned file bytes
and declared import bindings, replays every original instruction write and
explicit memory-copy effect, and checks complete before/after image SHA256s
and exact changed-byte runs. Each EXE image spans31760384 bytes; each DLL image
spans20480. Attach changes62 EXE code bytes; whole-entry runs additionally
change eight security-cookie bytes. No expected game state is injected.

Across installation controls,151 actual instruction starts execute:47 EXE and
104 DLL. Stops and API adapters are excluded. The recursive static DLL inventory
has690 starts and43 indirect-transfer sites; these are not690 executed starts
or proof that every DLL branch is covered. Decoding starts from actual hook
entries and follows control flow, keeping embedded pointer data separate.

## Installed hooks and remaining work

These destinations are established by actual copy requests and verified jump
bytes. Text, preparation/commands, Actor control, contacts and hits have separate
native studies linked below. The remaining behavior notes are static findings,
not native comparisons or complete branch analyses.

| EXE patch | DLL destination | Recovered role / required work |
| --- | --- | --- |
|430c8c|100013d0|Whole hits compared in [LIB_WORLD_HITS](LIB_WORLD_HITS.md): movement kinds, ordered timer/frame/coordinates, literal Z addend bits004176cb00447a08 and retained20000-byte target buffer; continuations430ceb/43187a.|
|4176ac|10001807|Whole contact collection compared in [LIB_WORLD_CONTACTS](LIB_WORLD_CONTACTS.md):10661 calls, category groups and unchanged invulnerability gates; continuations4176cb/417f59.|
|42fcb1|10001322|Whole hits compared: live ITR.effect, type0 frame assignment through actual0xb2-stride read, preserved freeze3/30; continuations42fcbb/42fd1d. Apparent MP branch is statically unreachable.|
|41f5fc|1000109d|Transform-state routing adds4000-range behavior before41f675; retain8000-range continuation41f60a.|
|41408b|10001125|Whole Actor control compared in [LIB_ACTOR_CONTROL](LIB_ACTOR_CONTROL.md):7168 calls, live zero EDI and x87 operands, state85/86 frame/facing order.|
|4177b9|100011b9|Whole contacts compared: attacker current-frame state20 reverses the team gate and enters the effect check at41780b; three continuations and live stack provenance retained.|
|401290|10001298|Whole replacement text routine; native276-call comparison completed below.|
|424352|10001236|Whole loading compared in [LIB_LOADING](LIB_LOADING.md):318 calls, signed phase colors, identical Loading files strings, bitmap/link/output/message order; continuation4243b1.|
|424357|two bytes `90 90`|Installed bytes preserved and verified; the label jump bypasses both NOPs and the former caller label block.|
|4214d7|10001a9a|Whole command3/catalog consumer compared in [LIB_STAGE_COMMANDS](LIB_STAGE_COMMANDS.md), retaining distinct continuations.|
|42d5ce|10001b1b|Whole preparation compared: retains450c1c write and writes only byte450bb8=3.|
|42d30b|10001b2e|Whole preparation compared: copies BG perspective+0xc into459ff8 before X RNG.|
|42d473|10001b48|Whole preparation compared: sets459ff8 and overwrites live ECX, changing X despite consuming RNG.|

Preparation's byte450bb8=3 feeds the replacement post-draw command path. Their
controlled own-state connection is now compared in LIB_STAGE_COMMANDS, with
explicit semantic ownership of459ff8 and declared backing for uninitialized
BG99 perspective. The initialized application connection remains open. Existing
pristine chains with zero command flags do not establish that enabled path.
No global record is extended with expected source bytes to conceal provenance.

The transform hook's write through Actor+0x7b4 still needs allocation/lifetime
provenance. The hit hook's0xb2 stride is now directly executed across all400
controlled previous-frame indices, including cross-Frame reads. Its2175
unknown words in the original loaded catalog are static potential reads, not
observed source faults. Native rejects unknown bytes and rolls back; actual
gameplay reachability/backing remains open. Do not silently repair source sizes.

## Compared replacement text

The source first executes its own whole entry/DLL installer. Each controlled
call then enters401290 and executes the installed jump, all relevant DLL body
instructions10001298..10001309, and its GDI import thunks. COM/GDI and lstrlenA
remain declared platform boundaries. There are52 actual starts across these
calls:one patched EXE instruction and51 DLL instructions. No other hook body
is executed by these text comparisons.

The original replacement requests GetDC and keeps its signed HRESULT. On a
nonnegative result it stores the returned DC into DLL data+0x6e, requests
SetBkMode(DC,1), SetTextColor, lstrlenA, TextOutA and ReleaseDC, in that order.
It returns the original GetDC result even when later GDI/ReleaseDC responses
fail. On a negative result it skips the later operations and retains the
previous DLL DC. The background-color argument is loaded but no SetBkColor
request is made. Source DC output also overwrites the caller's target-argument
slot while the actual target remains cached in ESI; this is a compiler-stack
observation, not native pointer/stack equivalence.

The270 independent cases cross three valid targets, six byte strings, five
GetDC results and three later API responses. Strings include empty, high bytes,
an embedded NUL with an ignored suffix, all nonzero byte values and4095 bytes.
Coordinates include signed extremes; colors and DC tokens include full32-bit
values. Six further calls retain each preceding source/native DC independently.
Native compares1106 ordered events, the resulting retained DC and all44436
bytes of declared DLL-data backing. The source records166 DC stores. Only
the native semantic DC field changes; unchanged
backing is verified rather than substituted from expected after-state.

A native-only late observer failure after ReleaseDC verifies that retainedDC
rolls back. External effects must be buffered until the encompassing operation
commits. There is no corresponding source exception in this corpus. The native
implementation adds a `setBackgroundMode` event and leaves
[OriginalSurfaceText](../../native/Sources/NTSDCore/OriginalSurfaceText.swift)
as the pristine-EXE control. Existing enclosing gameplay/menu APIs are not yet
routed through the new library state; their required library-enabled join stays
open. No DLL or emulator is linked into the native implementation.

## Reproduction and validation

Source installation: [oracle_lib_initialization.py](../../tools/oracle_lib_initialization.py).
Installed text: [oracle_lib_surface_text.py](../../tools/oracle_lib_surface_text.py).
Static inventory: [inspect_lib_runtime.py](../../tools/inspect_lib_runtime.py).
Independent verification: [verify_lib_runtime.py](../../tools/verify_lib_runtime.py).
Native acceptance: [accept_lib_runtime.py](../../tools/accept_lib_runtime.py).
Reports: [installation](../evidence/lib-initialization.json),
[text](../evidence/lib-surface-text.json),
[static inventory](../evidence/lib-runtime-static.json).

The initial full-startup probe had two terminal harness failures: an undersized
image mapping and duplicate API callbacks from overlapping observers. Correcting
those produced the actual previously undeclared LoadLibraryA boundary. All three
probe logs and source versions are preserved under `build/research`; no live
process was restarted. The subsequent installation and text source captures
both complete with exit0. No old expected bytes were changed.

The two raw native release tests pass0.096s/build172.22s; acceptance repeats
the built tests in0.098s before publication. The isolated native package verifies
all506 committed files from4298b7e and overlays only the event addition, native
library text and its tests. It excludes concurrent active-gameplay changes.
The final packaged three release tests pass12.226s/build0.26s without the raw
override, including the retained pristine menu-presentation comparison.
NTSDNative linked; no application window was opened. All source and owned
SwiftPM jobs are terminal0. Complete artifact verification and process records
are in `build/research/application-initialization-work.json`.

| Artifact | Raw bytes | Packed bytes | Packed SHA256 |
| --- | ---: | ---: | --- |
|lib-initialization|70920|6133|`3697e7d6c40c78fd1ae026f658c28654a4ed825bde24c087df7ad51242f0584c`|
|lib-surface-text|3372468|81671|`258ddf5df17bc843eb483e3e40e59c6cf0c85bfe166e84fa8e223221151ffece`|

All198 prepublication fixture pins remain unchanged;200 after these two
artifacts. Those pins include the concurrent active-gameplay publication; its scope
remains pristine EXE. Both complete raw/packed byte sequences, JSON, lengths
and SHA256s independently verify, along with all10 replay-codec vendor hashes.
The source-only installation fixture is retained as evidence, not counted as a
native installation comparison. Transport compression does not replace the
game's replay codec.

The source-only installer fixture is explicitly `nativeCompared=false`; the
text fixture report is `nativeCompared=true`. Neither label establishes the
whole library, full CRT startup, real Windows loader/raster, native app window,
complete match/content, device timing or clean-Mac behavior. Preserve the full
native-game goal and prioritize the remaining installed hooks before treating
the earlier pristine chains as the delivered application's behavior.

The later [STARTUP_STORAGE](STARTUP_STORAGE.md) accepts the three controlled
game constructor callbacks after an unchanged whole installer. Its separate
actual MSVCR80 process-attach chain stops at the first unresolved Windows NLS
query before EXE entry. Neither result closes full CRT/library application
initialization; see [CRT_STARTUP_PLAN](CRT_STARTUP_PLAN.md).

[WINDOW_INITIALIZATION](WINDOW_INITIALIZATION.md) subsequently compares the
whole controlled43bec0 display/window request chain after the unchanged installer.
Its Win32/COM and opaque helper-entry boundaries do not resolve actual Windows
callbacks, devices, CRT/NLS or the initialized library application join.

[APPLICATION_SCREEN_BODY](APPLICATION_SCREEN_BODY.md) now connects the installed
text helper to43 own startup/loop/resources/settings/background continuations.
All39 critical parent records reproduce exactly after the declared relocated DLL
attach;129 text calls and their retained DC compose through4275cb. Native uses
its own target and produced local strings, leaving private bytes unknown. This
closes that particular early-screen text connection; other enclosing callers,
worker delivery, complete CRT/application startup and device output remain open.

## Subsequent own menu return

[APPLICATION_MENU_RETURN](APPLICATION_MENU_RETURN.md) now continues the accepted
own body and separate settings-1 alternative through whole main/tail/World and
dispatcher returns. Forty-seven first due iterations commit at43d110/SP1000effc;
one pre-NULL cursor stop remains explicitly rejected with rollback. Full parents,
resources/library and private-stack evidence remain separate and unchanged.
Subsequent input/worker/CRT/NLS/Windows/device/app/full-match work stays open.

## Subsequent own input and loading entry

[APPLICATION_MENU_INPUT](APPLICATION_MENU_INPUT.md) preserves all47 completed
own parents, delivers actual mouse callbacks and continues repeated menu calls.
Fifty chains compare62 completed iterations plus three actual41bc90 loading
entries after single-player selection/3000rand/confirmation sound and background
release/World2. Source CPU/stack/resources and native own state are retained;
no mouse/World/expected-state injection. Whole loading remains the next dependency.
