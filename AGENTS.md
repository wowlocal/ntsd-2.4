# NTSD native macOS port

The user's requirement is a native macOS game without a browser engine,
CrossOver, or Wine at runtime, preserving the original Windows game's feel.

## Purpose and scope of low-level compatibility checks

Reverse engineering in this repository supports game compatibility and
preservation. The pinned original Windows distribution is the behavioral
reference for the native implementation. Research targets are the declared game
artifacts, their runtime dependencies, and controlled test environments. Existing
fidelity requirements and the research sequence below remain in force.

- Disassembly and execution hooks recover the game's control flow, update order,
  and helper behavior. Instruction addresses identify reproducible evidence.
- Memory, stack, register, and allocation traces establish data provenance,
  ownership, aliasing, and lifetimes needed to compose native game routines.
  Synthetic mappings and hooks belong to the reference harness; distinguish
  emulated observations from actual Windows, host, or device behavior.
- FPU, CRT, compression, and file-stream comparisons recover numeric results,
  replay bytes, and observable error/cleanup behavior across platforms.
- Malformed inputs, allocation/IO failures, and original crash cases test the
  limits of compatibility and native rollback. Their purpose is to document
  behavior and explicit unsupported boundaries. Reproducing a fault does not
  require developing an exploit or defeating a protection mechanism.

For each new or extended study, state the game behavior being recovered, the
reference artifacts and test environment, why the low-level operation is needed,
and the observable comparison or failure boundary. Keep this context in the
study and relevant tool description. Describe actual operations accurately,
including memory faults and protection checks; do not hide relevant evidence or
rename operations to obtain a different safety decision.

Keep immutable reference bytes, expected results, masks, and declared boundaries.
An explicitly rejected source fault is not a successful native match. Unknown
storage remains unknown until its provenance is recovered. Reference EXE/DLL
execution and emulation remain development tooling, separate from the native
shipping runtime. These checks do not authorize actions against unrelated systems.

If a safety refusal such as `cyber_policy` occurs, preserve the error, timestamp,
session/turn identifiers, and relevant operation for review. Stop automatic
retries of that blocked operation; do not attempt to bypass the safeguard.
Keep the affected dependency open and continue independent permitted work without
claiming it resolves the blocked path. Revalidate existing process handles before
acting: a model refusal does not establish that a source capture or build stopped.
This project context does not override platform safeguards or guarantee that
false positives will not occur.

## Current research status

**Current fidelity priority: bundled lib.dll hooks before the full application
join.** Read [LIB_RUNTIME](docs/research/LIB_RUNTIME.md). Actual PE entry445560
calls4464c4/security-cookie setup then LoadLibraryA(4464ab `lib.dll`) at4464ce,
before445565/CRT startup. The bundled6144-byte DLL SHA256 is
28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba.
Three whole-entry runs and four direct DLL notification controls recover four
actual installations:12 jumps plus2NOP bytes at13sites/62bytes each; two actual
VirtualAlloc requests4000/20000 and26VirtualProtect/13RtlMoveMemory requests.
These Windows API responses are declared, not actual Windows loader evidence.
Full31760384EXE/20480DLL image bytes reconstruct and hash-verify.151actual
initialization PCs=47EXE+104DLL;690 recursively decoded DLL starts are STATIC.
Stop445565 is unexecuted; CW remains037f, CRT initializer order still open.

OriginalLibSurfaceText matches276 calls through the installed401290 jump and
whole10001298..10001309:1106events/44436DLL data bytes, source166DC stores;52actual
starts=1patchedEXE+51DLL. SetBkMode(DC,1), not SetBkColor; GetDC-negative skips
later calls and retains priorDC; later GDI/ReleaseDC numeric failures ignored.
Six source/native calls retain own DC results. Late native-only ReleaseDC
observer failure rolls back DC. Buffer external effects until whole commit.
OriginalSurfaceText and earlier callers remain pristine controls; their native
library-enabled routing is OPEN. No runtime DLL or executable-memory patching.
Raw2release tests0.096s/build172.22s; final packaged3tests12.226s/build0.26s,
including retained pristine menu presentation. Source and owned SwiftPM jobs
terminal0.198priorpins unchanged/200current (includes concurrent active-gameplay
publication); full raw/packed bytes/JSON/SHA and10vendor hashes verified.

[LIB_STAGE_COMMANDS](docs/research/LIB_STAGE_COMMANDS.md) now implements the
whole library-enabled42d1ff..42d6ed preparation and4214d5..421a15 consumer.
OriginalLibStageCommands owns459ff8 with a required initial input. The native
consumer uses its own producer's output; no source after-state is injected.
Status1...10 hook42d473 overwrites liveECX AFTER RNG0xdd, so X becomes signed
BG+0xc+width/4 while still consuming RNG. Status>10 hook42d30b sets459ff8 BEFORE
RNG0xdb, retaining randomX. Later mode1 positioning remains.42d5ce writes only
byte450bb8=3; upper bytes survive. Command3 accepts all exact/duplicate signed
IDs in catalog order, without command1's100..<200 filter or122 selection draw.
Zero target still reads first header when count>0. Full pool retainsSP34 and
consumes FOUR coordinate draws before dereference. Flags remain until HUD.

All4330 controlled commands compare full400Actors/World bytes+masks, globals,
SP34 and6361events/9923helper returns;544EXE+29DLL actual starts. All3898prior
whole results reproduce unchanged through the installed library. Two35-case
preparation/consumer chains independently rebuild the whole catalog and compare
107732records/160959136bytes+masks,26942preparation constructors/756RNG,
1096bitmaps/1066releases; consumers add32RNG/8constructors/64helper returns.
Own requested-word3130accesses; each3677storage blobs.1094observed starts minus
3declared bitmap/memset/allocation adapters=1053EXE+38DLL actual starts.
Research relocation76HIGHLOW entries precedes actual104-PC DLL installation;
no native DLL or executable-memory patching. The between-caller command ABI
is DECLARED: this connection does not run the intervening initialized tick.

BG99+0xc is UNINITIALIZED. Each chain records7actual reads of untouched a5
catalog backing with zero masks. Native defaults to undefinedBytes rejection
and rollback; comparisons explicitly resolve that one word from independently
rebuilt declared a5 backing. Actual application allocator provenance stays open.
Do not call this an unrestricted native domain or import expected source bytes.
Four native-only preparation rollback trials cover missing backing and late
reset-input observers; command tests cover constructors/music/retained slot.
Buffer external effects until the whole encompassing operation commits.

Final packaged11release tests passed19.391s/build171.40s: new4330commands,
70preparation/consumer cases, rollback and retained50pristine preparations/
3898commands.200oldpins unchanged/203at publication; fullraw34991910/packed
5155811bytes,JSON/SHA/7354storage blobs and10vendor hashes independently verify.
Source and owned SwiftPM jobs terminal; NTSDNative linked, no app/window/device
claim. Initial source failures preserved: return-marker mapping, omitted
command EBX and actual undefined BG99 read. The host-Python transport API was
corrected after native tests passed, before any fixture publication; no expected
source result changed. Isolated514committed native files plus9overlays exclude
concurrent actor-control work. Python/137local Markdownlinks/owned diff pass.

[LIB_ACTOR_CONTROL](docs/research/LIB_ACTOR_CONTROL.md) now compares whole
413080..4143cb/ret8 with the actual41408b->10001125 hook:7168calls,7569408Actor
bytes and masks,330760192global hash bytes,384RNG/416sound events. Source
111460Actor/2784global stores independently reconstruct;98720helper returns/
26880FPU checkpoints.1458EXE+43DLL actual starts; all43hook starts, not every
branch outcome. Whole accepted preferred-base installer reproduces before
controlled Actor setup; no expected snapshot or native DLL runtime. EDI0 and
ST0=1/ST1=0 come from original instructions. Direction0 then1 compares raw
held bytes, preserves frame0 gate, adds1 for85 and0 for86, then rereads the
selected frame for velocities.1015changed/1015unchanged frame stores;1792
earlier same-call frame transitions. Native missing-frame42 trial rolls back
staged facing/frame changes. Pristine25795 calls and RNG rollback still pass.
Raw4release tests15.865s/build174.66s; final packaged10tests24.813s/build172.66s
also retain4330library commands/70preparation-consumer cases and command errors.
Final523-file native exportfe20733+three control files excludes unfinished
transforms.203oldpins unchanged/204published; full111033202raw/5591517packed
bytes,JSON/SHA and10vendor hashes verified. All owned source/SwiftPM jobs
terminal0; NTSDNative linked, no app/window/device claim. Source FPU history
is separate from native FPSW/tag equivalence; finite vx only in this corpus.
Read-only original catalog census verifies137DATs/54800defined state words/
15363present frames: NO85/86. The branch inputs remain synthetic; later runtime
mutation/reachability is not disproven. Prioritize remaining installed hooks
and initialized joins over expanding this matrix. Exact jobs/pins/results:
build/research/lib-actor-control-work.json. Full game goal remains open.

[LIB_WORLD_CONTACTS](docs/research/LIB_WORLD_CONTACTS.md) now compares both
installed4176ac/4177b9 filters inside10661 whole controlled calls. All7925
pristine whole outcomes remain identical. Full400Actors/World4524613688bytes
and equal masks,491941184global bytes,3917ordered events/193615helper returns.
142/142static DLL hook starts execute with1571EXE starts; not all branch outcomes.
32279hook entries verify actual417400 stack/slot/Actor provenance, preservedEDX
and unchangedCW037f/FPSW/tag; all whole returns keepSP1000e000/empty FPU stack.
Whole actual104-PC installer and76HIGHLOW relocations reproduce13copies/62bytes;
Windows API responses remain declared. Native has no DLL/patching runtime.

Kinds8/36/80..85/824 requiretype0;86..89/800/801/808/825 requiretype3;
810..816 accept1/2/4/6;817..823 require1.802..807/809 READ category but their
comparison has no conditional branch. Keep old invulnerability8/14 exceptions.
State20 uses ATTACKER current70, reverses team equality and resumes41780b
inside effect21/22 gate. Preserve defender state10/13 and sourceID212 bypasses.
CurrentSP44/48 are actual pair arguments after0x30locals/four pushes; do not
import expected stack words. Public native wrapper shares the pristine pass
with explicit library selection. Undefined category802 and late kind80 tieRNG
observer errors verify full rollback. Buffer events until whole tick commits.

Raw6release tests14.567s/build175.45s passed, including10661library/7925pristine
and rollback. Immutable raw48983626/packed3074744bytes, completeJSON/SHA/all1924
blobs and10vendor files verified;204oldpins unchanged/205at publication.
Raw525-file export0a7c7a6+three owned files excludes unfinished transforms.
Read-only137DAT census:54800defined state words/4384ITR records; NOnewkinds or
state20, only402oldkind8. New-rule cases are synthetic; later mutation remains
open. First source attempt returned then failed an undeclared initial FPU-tag
assertion; terminal log/source retained. Fresh complete capture explicitly sets
FPSW0/tagffff. A verifier field-access fix changed no expected/source bytes.
No source memory fault or safety refusal. Final packaged8release tests passed
51.661s/build175.11s, including both retained pristine initialized chains37.172s,
library8.375s/pristine6.114s. Same three native files in526-file0a7c7a6 export
plus new fixture, no raw overrides or unfinished transforms. All owned source/
SwiftPM jobs terminal; NTSDNative linked. Exact jobs/pins/failed harness history:
build/research/lib-world-contacts-work.json. Full library-enabled own join,
damage, app/window/device/Windows/full match and full-game goal stay open.

[LIB_WORLD_HITS](docs/research/LIB_WORLD_HITS.md) now composes installed42fcb1
effect and430c8c movement inside18137 whole calls, including300World callers.
Full400Actors/World7697487896bytes and equal masks,836913728globals,
4754505728mutable ITR heap,362740000library target bytes,38384events and42891
helper returns match Native. All238reachable/250static DLL starts execute;
12missing starts form the statically unreachable MP block.3723EXE starts are
separate from the real VC80 rand CPU. Actual15749hook entries preserve live
roles/SPentry-0x80/ST0zero/CW/FPSW/tag; no native hardware-FPU claim.

42fcb1 consumes ITR.effect, NOT Actor state.3/30 keepfreeze; other<6000 skip;
>=6000/type0 reads Object+7ac+previous78*0xb2 and sets70=effect-6000 iff unequal.
Preserve actual0xb2 stride, cross-Frame bytes and masks; no invented5000 MP rule.
430c8c preserves ordered timer/frame and binary coordinates. Z adds literal
DLL+3014 bits004176cb00447a08, NOT old+1 or a pointer dereference.824/825 retain
first word of attackerSlot*8 in separate20000-byte target buffer;777 binds,
equal allows, mismatch skips. Preserve all bytes and lifetime across calls.

Of15690prior inputs,15526outcomes unchanged/164changed. Fresh164pristine whole
calls recover exact old bytes: only164binary-Z words/1148bytes differ; all old
masks/globals/heap/CRT/events agree. Do not call164unchanged native matches.
Read-only137DAT/full loaded catalog census:4384ITRs,42effects>=5000 including
13records/12distinct6000+ effects.42type0Objects*400potential stride words:
14625defined/2175UNKNOWN/84crossFrame. Those2175 are static potential reads,
NOT executed source faults. Controlled898reads coverall400previous indices;
fully initialized synthetic backing does not resolve natural unknown storage.
Native unknown Frame89byte8 and late second-sound observer verify full rollback,
including target binding. Buffer external events until whole tick commits.

Raw5release tests31.397s/build44.10s pass. First175.77s build passed all source
comparisons but a new rollback test expected sound2 instead of0 atfall60; only
that test expectation changed. Terminal failed log/test hash retained. Final
packaged7tests68.432s/build175.93s pass: library17.335s, pristine13.856s,
both prior initialized hit chains37.242s. Raw528/final530file exports from
834b36a+five owned native files exclude unfinished concurrent transforms.
205oldpins unchanged/207published; fullraw121622254/packed7304579bytes,
JSON/SHA/all4347blobs and10vendor files independently verified. Paired164fixture
is source-only/nativeComparedfalse. All owned source/SwiftPM jobs terminal0;
NTSDNative linked, no app/window/device/Windows claim. Exact jobs/results:
build/research/lib-world-hits-work.json. Complete raw corpus is never restarted.

[LIB_LOADING](docs/research/LIB_LOADING.md) now implements whole4242e0/ret,
installed424352/424357 label/text, all rendering/link/overlay/present children
and actual43d230 message-pump tail.318controlled returns compare14673792global
bytes and20727events;1303global/384DC stores independently reconstruct.
309animated/9no-draw;1180draws/1776Blts/240fills/391GetDC/384text outputs,
640clocks/78Sleep/73Shell;309Peek/23Get/22Translate/22Dispatch.5082helper
returns,840EXE+80DLL+414CRT actual PCs. All253reachable caller starts execute;
282straight-line starts include28bypassed label/NOP and1alignment. Both DLL
bodies76starts+4import thunks. Not every child branch or actual Windows.

Preserve unsigned elapsed33/100 and fresh clock requests, signed wrapped phase
increment/remainder10. All three DLL strings say Loading files; phase<2 uses
ffffff,5..7 uses99,othersff at608/60,background0. Caller filename stays unread.
458420 is a BITMAP wrapper. Eight100-byte link slots skip leading?, retain
column3's extended right hover bound and top/bottom/left/right fill order.
Clear held before sound/Sleep300/Shell, retain4511b8 after link processing,
then cursor/overlay/present/message pump. GetMessage-1 is nonzero in the actual
branch. APIs are declared responses; no URL/message/device operation occurs.
All240fill inputs retain92unknown helper-entry bytes with their separate mask;
this does not recover initialized application stack/worker provenance.

Six linked calls independently retain timer/phase/click/DC; five carries.
Native late Dispatch callback and missing bitmap reject with full global/DC
rollback after earlier label output. Buffer all external effects until commit.
Raw4release tests11.687s/build176.07s pass first build: loading0.155s, text0.080s,
pristine presentation11.452s.532-file db588b3+three owned native files excludes
unfinished transforms.207oldpins unchanged/208published; fullraw7085256/packed
1080643bytes/JSON/SHA/all513blobs and10vendor hashes independently verified.
Two terminal source harness failures retained: initial panel binding and its
caller read observer. Verifier corrected actual installer scratch309c; expected
source bytes and game algorithms unchanged. Complete source is never restarted.
Final packaged6release tests24.923s/build177.75s pass without raw overrides:
both old initial-loading controls13.206s, newloading0.143s, text0.080s and
pristine presentation11.494s.533-file export keeps the same three native files
plus new fixture. All owned source/SwiftPM jobs terminal; NTSDNative linked,
no app/window/device/Windows claim. Jobs: build/research/lib-loading-work.json.
The enclosing
initial/catalog loading, asynchronous panel worker and full library app join
remain open; previous pristine no-draw loading fixtures keep their own scope.

[STARTUP_STORAGE](docs/research/STARTUP_STORAGE.md) compares12 controlled calls
of actual CRT _initterm(4472c8,4472d4), executing36 original game constructors.
Whole accepted EXE/lib installer case0 reproduces unchanged before this separate
call; this does NOT continue the incomplete CRT startup.27EXE+47CRT PCs,
25584storage bytes+masks,1248stores/4992written bytes. Observed458440..458c94 is
NOT sizeof:4031b0 clears only words0/130/134;414440 reads/writes nothing;
419e40 clears first word then400 bytes. Preserve all other bytes/provenance.
Four native calls carry their own results; late third-completion error rolls
back all storage. No expected after-state, runtime DLL or patching imported.

Fresh actual MSVCR80 entry7813232b reaches unresolved GetStringTypeW, BEFORE EXE:
1274CRT PCs/188API entries/622CPU stores1885bytes. It actually initializes
heap/TLS/PTD532 and writes _acmdln781c3b24 at781321d9 from GetCommandLineA.
First NLS request return7813b3b5 is type1/one UTF16 NUL, an availability probe,
NOT a complete classification table. Output backing d8e9 is not an API result.
No NLS answer is supplied; do not force failure/host tables to complete startup.
Separate missing-KERNEL32 attach returns0 and destroys heap:285PCs/14APIs.
Do NOT call that successful startup.11 exploratory captures/source versions
retained; no source memory fault or safety refusal. Windows APIs remain declared.

Raw3release tests0.580s/build175.80s and packaged3tests0.570s/build0.28s pass:
12constructor calls, late rollback and retained968sound calls. Isolated535files
at aa6f203+two native files exclude concurrent transforms; final537 adds two
fixtures.208oldpins unchanged/210current; fullraw797945/packed52712bytes,JSON/
SHA/exact two embedded raw CRT captures and10vendor files verify. All owned
source/SwiftPM jobs terminal. NTSDNative linked, no app/window/device/Windows.
Jobs: build/research/startup-storage-work.json and crt-startup-work.json.
Full CRT/NLS, library-enabled app join and full original-content goal stay open.

[WINDOW_INITIALIZATION](docs/research/WINDOW_INITIALIZATION.md) now implements
whole43bec0/43bdd0 and all window/DD/surface/clipper/clear children at declared
Win32/COM and helper-entry backing boundaries.280whole calls match12920320global
bytes+masks,4574requests,1182structures94588bytes/23788written fields and resource
output/release records.874CPU/823API global stores reconstruct.501actualEXE/0DLL
PCs,2115SOURCE helper returns; complete accepted installer case0 unchanged.
539decoded starts include30unreachable40137f..4013c5 and8at43bed2..43beed:
43e8e0 and43bdd0 return0/1, never negative. No forced branch or Windows claim.

Windowed metrics7/8/8/4 remain separate calls and use wrapped global dimensions;
class/menu Marti,title Little Fighter2,styles10cb0000/80000000 and exStyle0/8.
Fullscreen metrics1then0;232class cursor words stay unwritten in supplied backing.
UpdateWindow precedes4546f4 assignment. Source show argument stays unread;
ShowWindow always5,315requests. Actual Windows callbacks/placement remain OPEN.
Preserve shared primary/back DDSURFACEDESC, swap2->swap1->plain fallback, earlier
surfaces retained across failed retries, and clipper Release without clearing
457584.453e0c stays untouched and selects windowed mode3/1; fullscreen mode2.
Eight failed CreateWindow requests still ShowWindow(0,5)/return1;28fullConfigure
zero results still select2.14pixel-query failures continue clearing;2SetClipper
failures still release/show. Do not invent numeric-failure cleanup or early exits.

1057helper-entry backings are DECLARED, not initialized WinMain stack provenance;
structure masks identify current-helper field writes, not the whole stack lifetime.
Three native-only late/missing-backing/output errors roll back globals. Buffer
external effects. Current NTSDApp still uses the prior practice engine; no app
window/device/Windows run follows from this request model. CRT/NLS stays open.
Source driver's duplicate-context TypeError retained last50complete calls; later
unsaved calls are explicitly unretained. Terminal restart resumes those50exact
records, then atomically checkpoints each new case; final280checkpoint equalsraw.
No original memory fault/safety refusal; never restart this completed corpus.
Raw5release tests22.959s/build178.13s and packaged5tests20.203s/build0.28s pass,
including retained startup storage. Isolated539files6570660+two native files,
final540adds fixture, excludes concurrent transforms.210oldpins unchanged/211;
fullraw83756823/packed2905776bytes/JSON/SHA and10vendor files verify. All owned
source/SwiftPM jobs terminal; NTSDNative linked. Jobs: build/research/
window-initialization-work.json. Full initialized library app/match/content,
Windows/device and clean-Mac goal remain open.

[WINDOW_INPUT](docs/research/WINDOW_INPUT.md) now matches4369 whole43b3d0 input
callbacks plus3 separate text constructors, not4372 WndProc calls.385 controlled
retained calls use prior native output. Full203184416storage bytes+masks,
5908requests/23835stores/50118written bytes agree;5822source helper returns.
561actualEXE starts include424WndProc/0DLL after the separate full lib installer
parent, which reproduces unchanged.576STATIC WndProc starts include152unexecuted;
corrected inventory includes all3ret16 bytes; earlier truncated inventory retained.
CW023f supplied/unchanged, SP2000f014 and saved registers preserved. No Windows,
CRT startup, private native ABI, initialized app or device equivalence follows.

Keydown editor precedes byte100 and first/second recognizers; keyup writes117.
B..Y/digits/space/dot only; index299's NUL overwrites its own low byte→256.
360ordinary retainedB inputs cross this twice, end272/360;2backspaces→270/360,
Enter clears active. Activation/initial sequence zeros are explicit inputs;
constructor only clears0/130/134, no text/sequence initialization. LF2.NET and
HEROFIGHTER.COM retain last state and write keyboard sentinel249/248. Mouse XY
is unsigned16; buttons preserve coordinates. Joystick quarters use wrapped
signed arithmetic/truncation and exact byte-store order. No original memory fault,
control-pointer/security mutation or safety refusal. Arbitrary VK/index excluded.

ESC answer6 runs actual catalog→builtin→device/music/both replay cleanup, then
posts to INCOMING HWND, unlike menu's global4546f4. Numeric failures ignored;
shared native release children preserve the old menu/music contracts. Declared
COM/free ownership is not actual Windows heap/device lifetime. Late post, second
missing replay owner, NUL-store observer and undefined index verify whole rollback;
buffer external effects until commit. Lifecycle messages are compared below;
DirectShow400 and Winsock401 were explicit unimplemented dependencies at that
milestone; GRAPH_EVENTS and NETWORK_NOTIFICATION below now compare400/401.

All owned jobs terminal. First build176.09s linkedNTSDNative and passed6retained
tests;3new tests failed BEFORE comparison on framed-zlib/raw-DEFLATE transport.
Only new test reader corrected; original raw/game rules unchanged. First log/code/
export retained. Raw3 passed2.751s/build44.05s; final packaged9 passed59.951s/
build0.24s, input2.748s, no rawoverride.211oldpins unchanged/212current; independent
fullraw29400709/packed8260684bytes,JSON/SHA/4228blobs,4372atomic records,10vendor
hashes and543isolated nativefiles verified. Foreign transforms excluded. Never
restart completed source. Exact jobs: build/research/window-input-work.json.
NTSDApp still practice; native-window/device/Windows/full match/content/cleanMac
and the full native-game goal stay open. Read remaining WINDOW_INPUT_PLAN and
WINDOW_INITIALIZATION before joining platform callbacks to the general engine.

[WINDOW_LIFECYCLE](docs/research/WINDOW_LIFECYCLE.md) now matches318 whole
lifecycle callbacks plus2 separate43bec0 initializations. Two declared own window
chains retain18callbacks through move/minimize/restore/palette/two toggles/destroy.
Full14770944storage bytes+masks,3624requests/1757stores/7444bytes, replay lifetime
and interface release records agree.567window/display structures45868bytes/
11652written fields from479DECLARED helper-entry backings;56rectangle/point
requests672bytes separate.1235CPU/522API stores reconstruct all after bytes/masks.
809EXE/185WndProc/0DLL actual starts,1616SOURCE helper returns; complete installer
parent unchanged. CW023f supplied/retained, callbackSP2000f014/initializerf004.
This is not Windows, CRT/WinMain, device allocation or callback reentrancy evidence.

SYSKEYUP Enter logs before44d794 gate;458434=1 precedes normalized458430 toggle,
actual401a80 release/clear back→primary→draw then401ae0 DestroyWindow. Zero draw
skips both surfaces; HWND/palette/clipper remain retained. Whole43bdd0 now exposed
as OriginalWindowInitialization.configure, without43bec0's extra instance store/
ShowWindow.19zero recreation returns still ShowWindow and clear458434; negative
error branch unforced/unreachable. WM_MOVE samples height then width in fullscreen;
windowed ClientRect→ScreenPoint(first)→ScreenPoint(second) sees live outputs.
Numeric failures ignored; no API output is invented. Size wParam1 invalidates,
sets451dac0; others1, allreturn0. Cursor alwaysreturn0. Syscommand exactf100 only.

Destroy2 always sound/music/both replay cleanup; PostQuit only458434==0. Four
native-only late/missing-backing/ownership trials roll back whole state. External
palette311 lacks source primary-null guard; source dereferences only valid owned
primary tokens here. Ordinary null-notification reachability remains OPEN, not
an executed/matched fault. Buffer external effects. No original memory fault,
control/security mutation, safety refusal, restart or native-rule correction.

Together with unchanged WINDOW_INPUT,567/576STATIC WndProc starts execute. Nine
remaining:6Winsock402ec0 call instructions,1DirectShow401e90,2negative43bdd0 debug.
Next actual400/401 consumers, then initialized delivery/reentrancy/WinMain join;
never treat them as default messages. Source and all owned SwiftPM jobs terminal0.
Raw9tests23.532s/build177.11s; packaged9tests23.195s/build0.28s, new0.333s, no raw
path override. Retained280window/4369input+3constructors remain unchanged.212old
fixtures preserved/213current; independent fullraw11531205/packed733592bytes,
JSON/SHA/117blobs/320atomic records/10vendor hashes/546isolated nativefiles verify.
NTSDNative linked; app stillpractice, no window/device/Windows run. Foreign
transforms excluded. Exact jobs: build/research/window-lifecycle-work.json.
Full native application/match/content/network/clean-Mac and goal remain open.

[GRAPH_EVENTS](docs/research/GRAPH_EVENTS.md) now matches371 whole message400
callbacks through actual401e90/ret and4 separate whole401c90 initializations.
Five callbacks retain their own native graph initialized from four zero slots;
HWND/API responses remain declared, no full window/graph/playing-file join.
Full17327744 storagebytes+masks,2358 requests,1588stores/6343bytes and2772actual
local reads agree.1064GetEvent/693FreeEventParams/211positivezero seeks;4create/
9queries/3notify/3flags/371default.137EXEPC=31WndProc+57drain+49init;746helper
returns,0DLL after the separate fully reproduced installer. SuppliedCW023f/
FPSW0/tagffff survives entry/return/seek observations; no native-process/Windows
FPU claim. Combined immutable input/lifecycle/graph inventory is568/576WndProc
starts;6Winsock and2negative43bdd0 debug remain, not all branch outcomes.

Only exactE_ABORT terminates. Missing outputs retain frame+34code/+3cparam1/
+38param2; apply terminal outputs too. Read param2 beforeparam1/livecode, ignore
seek/free HRESULTs, then original DefWindowProc. Native shares music graph
initialization and seek. All64initial local bytes are declared stack backing,
not app provenance; unread unknown locals survive. Missing required word or
interface/exhausted provider/late default or init observer throws with rollback.
No manufactured source NULL-COM fault or infinite queue; actual reachability,
COM reentrancy and device lifetime stay open. Buffer external effects.

Initial12raw tests41.330s/build178.31s passed. Finite-plan review added one
native-only test for two missinginterface trials; new5raw0.326s/build45.77s.
Final13packaged tests40.526s/build0.26s passed, graph0.296s, no raw override.
An agent sequencing error launched premature packaged tests before fixture copy:
5missing-resource failures before comparison,8retained passed; artifact check
also lacked final exportpins. Logs/statuses preserved; process terminal before
copy/pins and successful rerun. No source/native-rule/expected byte correction.
All213oldpins unchanged/214current; fullraw2917279/packed132963bytes,JSON/SHA,
79blobs/375atomic cases/10vendor files/549isolated exportfiles verified. First8
probe cases unchanged; source corpus complete, never restart. All owned jobs
terminal; NTSDNative linked, app stillpractice, no app/window/device/Windows run.
Foreign transforms untouched. Jobs: build/research/graph-events-work.json.
Its next notification Winsock401/402ec0 is now compared below; actual initialized
delivery/CRT/WinMain/lib/app composition and the full goal remain open.

[NETWORK_NOTIFICATION](docs/research/NETWORK_NOTIFICATION.md) matches415 whole
message401 callbacks through402ec0..40316e/ret and actual WndProc ret16. Full
19216160storage bytes+masks,3692requests/1119304sendbytes agree. Four retained
notices use their own native accept output; listener/names/RNG/stack/API inputs
remain declared, not full menu/listen/client/peer/Windows provenance.225EXE PCs
=36WndProc+181/182notification+8thunk/check;37CRT actual starts. Only4030e9 skipped
alignment is absent from notification.1245EXEhelper returns+724actual VC80 memset
returns,362complete REP copies/76bytes each,415unchanged cookie checks. Supplied
CW023f and savedregisters survive, SP2000f014. Combined immutable WndProc
inventory574/576 leaves only2negative43bdd0 debug starts; not all branch outcomes.

Onlylow16lParam selects1/8/16/32; high16error/wParam ignored. READ/CONNECT/CLOSE
onlyMessageBox, all pathsDefWindowProc. ACCEPT stores44f1af2 BEFORE accept, then
storesreturned44f46c even-1. Exact-1 message thencloseaccepted/listener, no clears.
Otherresults close listener,send14,clearrecv77,Sleep3000,recv77 ONCE,Sleep500,
sendnames77,Sleep500,sendRNG3001,thenseats/remote names/44f1ae1. Numeric send/recv
errors ignored; partial output retains priorzero suffix. Adapter combinations
include non-OS status/output controls; do not call them actual Winsock behavior.
Frame2000ef3c data160bytes ends beforecookie+a0; recv+0,packet+50,names+70.
Fourglobal strings44fcc0+11*i copy throughNUL withoutstridecap, overlap live,
then44packet NULs→underscores/finalNUL. First4seats get1/2/3/4 before ASCII1→-1;
other4retain unlessASCII1. Remote44bytesrawstore thenunderscore→zero at44fcec.

44237rawstores=43892CPU/345API;33377native semanticstores coalesce ONLY724CRT
memsets. Bothwrite130913bytes;37790actualreads match. Rawwrites remain unchanged.
Unknownnames/RNG,50-byte native-only name boundary,oversizedoutput78, unavailable
recv andlateDefWindowProc roll back whole state; unknown untouchedlocals survive.
Longsettings names' source reachability remains open; no manufactured source
cookie/control fault, safety refusal or source/native-rule correction. Buffer
external effects. All8probe cases unchanged; full415source terminal, neverrestart.

Raw10release tests12.074s/build179.41s; finalpackaged10tests11.552s/build0.28s,
new4tests2.047s, no rawoverride. Retained5graph tests+menu1020probes/450mouse/
4150events/14networkfailures pass.214oldpins unchanged/215current; independent
fullraw41676959/packed3897568bytes,JSON/SHA/684blobs/415atomicrecords,10vendor
hashes and552isolatednativefiles verify. No file/source/expected byte correction;
allownedjobs terminal0; NTSDNative linked, noapp/window/device/Windows exercise.
Foreigntransforms unchanged. Jobs: build/research/network-notification-work.json.
Actual client428420 is compared below;402d70 is exit/cleanup (earlier label
corrected from static disassembly). Full initialized menu/listening/callback routing, CRT/NLS/
WinMain/lib/macOS runtime join and complete game/clean-Mac goal remain open.

[NETWORK_CLIENT](docs/research/NETWORK_CLIENT.md) matches392 whole deferred
428420 actions,357 completed handshakes,4116requests/37667semantic stores. One
additional client and whole server callback exchange4 own packets/3169bytes,
in source on2independent CPUs and natively via2states/own FIFO outputs. Source
packet bytes are comparison targets, NEVER substitute native peer output.
Combined394calls:4137requests/30658sendbytes,38012semantic stores/1185930bytes;
41980rawstores=40880CPU+1100API,47750recorded data reads,19413344storage bytes.
360actual CRTmemsets/359complete REPs/386greeting comparisons.386EXE+37CRT PCs;
client193/195missing only428703/42870a alignment.34prologuePCs counted separately.

Actual4246b0 prologue produces EBP19/EBX0 and own declared World/target locals,
phase4511f8=1. UI42709b→428420 is a DECLARED GAP; no EBP lifetime through UI or
whole menu return claimed. Stops42873e presentation/4287de epilogue unexecuted.
RootSP2000e000, local1024bytes starts+14, before cookie+414; root0..13/414..42b
unchanged. World2112bytes is declared input, not sizeof recovery; hostname+7d8.
402d70..402eb6 is actually optional exit/sendto/close/clear/WSACleanup, caller
427f6b. Earlier client-handshake label was a STATIC naming error, corrected;
no accepted server source bytes/results changed. Whole402d70 is compared below.

Pendingexact1 clears BEFOREcloseold/socket(2,1,6); store result even-1. Lookup
fallback inet_addr/root14/gethostbyaddr; successful host requires first-address
provenance only at dereference. Connect-1 closes LISTENER44f1b4, not new44f46c.
Greetingrecv100 and replyrecv77 NEVER clear; partial RNGrecv3001 retains suffix.
REPE14 stops first mismatch. Own EBP19 copies76templatebytes, then seats4..7
get1/2/3/4 BEFOREfinalMOVSB. Four live names copy first to44fcec then reread into
packet, no11-byte cap;44packet NULs→underscore. Byte44f1af1 BEFOREsend77, then
Sleep500/recv77/Sleep500/recv3001, numericerrorsignored. All8ASCII1→seat-1; no
first4defaults. Remote44raw bytes→44fcc0, secondzero forunderscore, thenmenu4.
Ownnames retain underscores; peers' whole88-byte banks intentionally differ.
Verifier first wrongly required equality; preservedattempt1 corrected verifier
only to derive each bank from owninputs/peerpackets. No source/native rule fix.

Required unknown hostname/name/local/host output and oversized3002recv fail
with whole rollback; late finalrecv/menu-store also rollback. First-byte greeting
mismatch needs no unknownsuffix. Broader settingsname/alias lifetime stays open;
no source control/cookie fault manufactured. Buffer external effects. Paired FIFO
is controlled transport, NOT actual TCP/Windows/reentrancy/latency evidence.
Raw10release tests15.351s/build181.47s; packaged10tests14.426s/build0.28s,
new5tests3.311s; retainedserver4+menu1020probes/450mouse/4150events/14errors pass.
215oldfixtures unchanged/216current; fullraw54323566/packed4724320bytes/JSON/SHA,
824main+7client+6serverblobs,392atomiccases,6probe/fullpeerprobe,10vendor hashes
and555isolatednativefiles verify. Source/raw/packagedjobs terminal0; neverrestart
completedsource. Foreigntransforms unchanged; NTSDNative linked, noappwindow or
device/Windowsrun. Jobs: build/research/network-client-work.json. Exit402d70,
complete client/host UI and initialized menu/listen/accept/output joins, actual
network/CRT/NLS/WinMain/lib/macOS runtime/fullgame/clean-Mac and goal stay open.

[NETWORK_EXIT](docs/research/NETWORK_EXIT.md) matches56 whole402d70 returns plus
one own client producer on the same sourceCPU/native ownstate.6earlysend-error
returns/50normal; all79/79exit starts,86EXE+35CRT exit-only PCs.48actualmemsets,
56cookiechecks/112helperreturns,160exitrequests/1058sendbytes,628semanticstores/
13888writtenbytes/1453recorded reads. Includingclient:281EXE(includes34prologue)+
39CRT,171requests/1135sendbytes,733semanticstores/17224bytes,3768rawstores=
3765CPU+3API,1584reads,2647680storagebytes+masks. Not everybranch/Windowsclaim.

Listener44f1b4 nonzero THEN44f1b0 nonzero gates notice. Clear256localbytes at
SP2000eefc before cookie; copy20-byte `Client want to EXIT.` then overwriteNUL
with4rawaddressbytes44f208..b in order0/2/1/3. Actualstrlen sends20+nonzeroaddress
prefix,20..24bytes, not fixed24/textIP; all4addressbytes stillread. sockaddr16
44f58c is unchanged. Sendtoexact-1 MessageBox thenreread/closelistener andearly
402e7b, NOglobalclear/WSACleanup. Otherstatuses reread/close, clear44f1b4 THEN
44f1b0,WSACleanup,402eb6. Gatebypass stillclose0/cleanup. EAXlastclose/cleanup;
callerignores. Connected44f46c/networkflags/names/RNG are notcleared here.

Ownfailure→retry→repeat retainsbothgates afterfailure, sendsagain, thenclose0.
Ownclient→exit→repeat uses independently executed nativeClient output; never
imports expectedafterstate. This is a declared inter-call ABI, not an enclosing
cancelmenu execution. Unknownrequiredgate/address/sockaddr andlatecleanup/error
close/finalstore reject withwhole rollback; unknownlocal clear onlyonsendgate,
bypass preservesunknowns. Bufferexternaleffects; actualreentrancy/TCP open.

Raw14release tests5.613s/build182.98s, new5tests0.099s; finalpackaged14tests5.678s/
build0.32s,new5tests0.091s. Retainedclient5/server4 pass.216oldpins unchanged/
217current;fullraw4584610/packed295535bytes/JSON/SHA/88blobs/56atomiccases/3probe
cases/10vendorhashes/558isolatednativefiles verify. No sourcefault/refusal/restart
or source/native/verifier correction. Allownedjobs terminal0; completedsource
mustnotrestart. Foreign6transforms unchanged; NTSDNative linked, noappwindow/
device/Windowsrun. Jobs: build/research/network-exit-work.json. NEXTwholemenu1/2/3
427ca7..42873e:background/address/links/waitinganimation/hostname/key422f60,
actualcaller/presentation/epilogue and initializedlistener/peer joins. Actual
Windows/CRT/lib/macOS/fullgame/clean-Mac and fullgoal remain open.

[MENU_CHARACTER](docs/research/MENU_CHARACTER.md) now matches10492 whole
422f60..423222 calls by caller-consumed AL and exact read/request order.11048
liveShift reads/2890GetKeyState requests/13938events,484142848globalbytes and
zero writes;305/318EXE starts,0DLL.13missing starts are a statically unreachable
duplicate letter block, not dynamic coverage. Source fullEAX/savedregisters/
SP2000f004/CW023f independently verify; native modelsAL only, consumed by428371.
Shift means exactbyte100; signedCaps low16 and two successive API responses
are distinct. Navigation keys produce keypad digits. Unknown required Shift/
response throws; helper has no mutation, enclosing menu must stage its changes.

Raw17release tests5.872s/build189.58s; packaged17tests5.912s/build0.30s include
new3 and retained14client/server/exit tests.217oldpins unchanged/218current;
fullraw26069138/packed1308644bytes/JSON/SHA/257blobs/10492atomiccases/3probe/
10vendor/561isolatednativefiles verify. All source/raw/packaged jobs terminal0;
no source/native/verifier failure, result correction or source restart.
Jobs: build/research/menu-character-work.json. Foreign6transforms untouched.

Current Practice app launched and emitted live state; built-in AppKit/SpriteKit
capture1588x1200 shows District/Naruto/Sasuke/HUD and exits0. CUA failed with
`Sky Computer Use native pipe startup failed`; no UI actions/input/latency/audio
claim. Initial owned app PID was revalidated then stopped SIGTERM/exit-15.
This is technical UI unavailability, not safety refusal. Neither decoder nor
network UI is wired into current Practice. NEXT[NETWORK_MENU_PLAN](docs/research/NETWORK_MENU_PLAN.md):
wholemenus1/2/3, ownhostname provenance, librarytext routing and actualoutput/
return/listener joins. All218pins stay immutable; unknownhostname storage stays
unknown. ActualWindows/CRT/lib/fullapp/fullmatch/content/clean-Mac goal stays open.

[NETWORK_MENU](docs/research/NETWORK_MENU.md) now composes whole427ca7 UI
with library-enabled parent/body/presentation and the actual epilogue. BOTH
fresh parents reproduce; each944caller starts/938UI/943ret4 then actual41bc90
loading entry,60632/67198events and87network requests. Hostname51 bytes begin
unknown; realmenu1→3 produces its NUL/index, then own append/backspace bytes.
All300keys/bothShift paths,252rectangle controls, capacity/retained keys, timer
wrap/dots, background missing/color-key failures and deferred client/error/exit
paths compare. Enter displays Connecting; connect occurs on a later tick.

Three17-start controls each match12UI and explicitly reject one unknown own
partial receive at local+270/f4/114; source reads14/52/44 unknown bytes. They
are NOT three successful native matches. Two additional enabled-sound controls
each match20whole returns/16UI/27COMsound methods, including negativeHRESULTs
and GetDC. All1944UI matches retain fullWorld/globals/hostname/resources and
newlocal writes; source private stack remains unimported. Semantic root18World
and root20target are proven arguments. SourceUI/tail CW0 remains0: this early
VM has no CRT FPU startup, unlike the gameplayCW023f chain. No native process
FPU, Windows, actualdevice or privateABI equivalence follows.

Raw14tests18.195s/build48.80s; firstpackaged23tests22.745s/build49.08s; sound
raw23tests9.930s/build0.27s. Final all-seven packaged23tests23.957s/build50.08s passed.
218old+5firstpublished+2sound=225immutablepins; raw/packedJSON/bytes/SHA/all
blobs/10vendorfiles/570isolatednativefiles checked. Jobs and observer corrections:
build/research/network-menu-work.json. Source/raw/packaged jobs are terminal;
no source restarted for silence. All6 foreign transform files stay untouched.

Resource/audio/listener bindings in controlled variants are NOT own initialized
producers. Main matrices keep device flag0; additive sound controls explicitly
enable it. Partial source returns remain unsupported own reads with rollback.
Reference callback composes these helpers; production OriginalFrontMenuLoop
still returnsotherSelector and Practice is not wired to the new menus. NEXT
CRT/NLS/WinMain, remaininglibraryhooks and initialized runtime/listener joins;
whole app/window/input/audio/latency/Windows/match/content/clean-Mac remain open.

[MENU_SOUND_STARTUP](docs/research/MENU_SOUND_STARTUP.md) now implements whole
401970 and controlled43d08e..43d100 with five original4014e0 loads.112 whole
segments match560WAV returns/672helpers/8066events/1092stores. Ten nonzero
CreateSoundBuffer continuations stop before40187a and are explicit native
rejections with rollback, NOT ten more whole matches. Their20 completed WAV
returns plus10stops/476events remain a separate partial contract. Full comparison
is533552320bytes/8542events; all20 short/failed-read temporary leaks retained.
OriginalMenuSoundStartup returns its own five buffer/allocation results, preserves
zero-only device HRESULT success, ignored cooperative errors, live output clear
before Open and continued loads after ordinary failure. Native late fifth-load
observer/missing successful device output roll back; buffer external effects.

392actual starts=27caller+19device+342WAV+3cookie+1import;408static starts include
16unexecuted (consecutive device recheck/nonPCM). All702completed helper returns
and CW037f verified; failed WAV calls have NOT restored registers. End43d100 is
unexecuted/SP1000f00c after three pending memset arguments, not WinMain return.
The original13DLL patches are disjoint from these whole ranges; no DLL runs in
this controlled source, no initialized WinMain/CRT or actual device claim.
Prior HWND/globals/API tokens and scratch are explicit inputs. Full earlier
window/settings/music/worker/CRT and menu consumer join stay open.

Raw5tests22.482s/build186.04s; packaged5tests22.466s/build0.29s passed, including
retained409-file WAV/allseven network fixtures.225oldpins unchanged/226current;
raw7643981/packed3890251bytes/JSON/SHA/all146blobs/122atomicparts verified.
10vendorfiles/573isolated native files checked. Source/native/app jobs terminal;
see build/research/menu-sound-startup-work.json. The first probe's spacing was
too small for m_pass.wav and was corrected before final capture. Initial native
compile needed explicit integer types; verifier's saved-register condition was
restricted to actual returns. No source expected bytes changed. Current Practice
rendered District/Naruto/Sasuke/HUD and exited0; new audio/menu not wired, no
input/latency/audio/Windows evidence. Full application/match/clean-Mac goal open.

[INPUT_STARTUP](docs/research/INPUT_STARTUP.md) now extends upward through whole
43d078..43d100/43bf10 and1900 actual joystick WndProc consumers.56 complete
native input/sound segments match280WAV returns/4758startup events. Four other
source returns read16unknown caps words and are native rejections with rollback;
only their22prefix events compare, not336later source events. No stack fields
are imported to make these four pass. Do not call this60 whole native matches.

Preserve exactly256 keys117, four48-byte joystick records, copied retained left
direction into right/down/up, and active/XY/buttons/trailing-word clear order.
Nonzero joyGetNumDevs probes exactly0/1; only position result167 skips. Threshold,
capture and caps numeric results ignored. JOYINFOEX52 is cleared once; JOYCAPSA404 starts
unknown and its own first API output survives failed second query. Source full
bytes remain immutable; native compares masks/defined bytes, not unknown backing.
Signed wrapped midpoint/store order and helper EAX match. New caller executes
all three original memset pushes itself; entry/endSP1000f00c, still not WinMainret.

All32caller/127joystick starts execute;645actual EXE PCs total include185WndProc,
278WAV,19device,3cookie,1thunk.1116static starts are not dynamic fullWndProc/WAV
coverage. SourceCW037f remains, no native processFPU/device/Windows equivalence.
Both helper bodies/consumer ranges are disjoint from all13 DLL patches; this
controlled source does not run the installer. Own callback bounds are never
injected. Late caps/fifth-wave/callback failures roll back; buffer externaleffects.

Main58source cases unchanged; two fresh successful threshold/capture/cooperative
controls add228of1900callbacks. Total56matches+4rejections;4780native startup
events include rejected prefixes. Raw8tests11.332s/build51.48s; packaged8tests
10.981s/build0.25s passed, retaining WAV/menu-sound/4369WndProc corpus.226oldpins
unchanged/228current; mainraw14379356/packed4654908, successraw3051536/packed2018943
bytes/JSON/SHA/all1914+309blobs verified (shared hashes not distinctbuffers).
577isolated native files exclude all6 untouched foreign transforms. All owned
jobs terminal; see build/research/input-startup-work.json. First test compile
needed explicit unknown replayPointers storage; verifier corrected tab-separated
last opcode byte parsing. No source expected bytes or native rules changed.
Practice window launched; CUA native pipe startup failed before input. Its PID
was verified before SIGTERM. Separate built-in render shows District/Naruto/
Sasuke/HUD and exits0. New input/sound not wired, real input/latency/audio/Windows,
full WinMain/match/content/clean-Mac remain open.

[MENU_INFO_READING](docs/research/MENU_INFO_READING.md) now implements whole
43c4a0..43c685/ret:194 complete native calls (82true/112false), plus2 original
missing-file returns rejected natively for unknown local1c byte, with rollback.
Do not call these196 whole native matches. Actual132reader+3cookie/1130CRT
starts execute; all reader starts, not every branch outcome/Windows/privateABI.
EntrySP1000f000/return1000f004, savedEBX/EBP/ESI/EDI and suppliedCW037f survive.

Preserve failureflag0 before fopen, four single-byte clears after successfulopen,
%s/%s/%s/%s and close before six-byte end comparison. Missingopen still compares
unknown endtoken before flag. Local184 bytes exclude cookie; three52-byte spans
are observed spacing, not recovered C array sizes. Native imports no unknown
stack bytes; source full bytes/masks remain unchanged. now/dont_update require
exactNUL. Date scanf widths4/2/2/2/2/2, literal slash, six-99sentinels; no calendar
validation. Index/period are NOT initialized before%d: failed scan retains own
values. Both paths format before final-99 checks; preserve trailing bytes/order.

16additional own read/cache-write/read chains compare32reader/16writer returns,
51descriptor requests/240accepted bytes; second reads7true/9false. Their global
ABI is explicitly transferred between controlled CPUs, not WinMain. Native
feeds only its own accepted writer bytes to its next reader. Full FILE/buffer/
global states and masks agree; existing writer handles error/short writes. Main
1052events include2pre-rejection opens; chains190reader+147writer events. Late
second-format observer rolls back globals/locals; callers buffer externaleffects.
Combined167EXE/1441CRT starts; all13 DLL patches disjoint, no installer in this
source. Whole CRT/NLS, source private backing and initialized caller remainopen.

Raw7tests2.269s/build51.67s; packaged7tests2.242s/build0.26s passed, retaining704
content/534writer cases.228oldpins unchanged/230current. Mainraw5955061/packed
1465387 and roundtrip1446631/434011 bytes/JSON/SHA/all393+158blobs verified;
10vendorfiles/581isolated files checked,6foreign transform files untouched.
First raw2tests0.158s/build195.51s also pass. Verifier initially imported Unicorn
for a hash under systemPython; removed that unnecessary import, no source/native/
expected change. All owned jobs terminal; NTSDNative linked, no window/device
claim this stage. See build/research/menu-info-reading-work.json. NEXT whole
43cf94..43cfb4 reader/content/panel/default selection, then date/time/music/input/
WinMain/dispatcher/application composition. Full game/match/Windows/cleanMac open.

[STARTUP_PANEL](docs/research/STARTUP_PANEL.md) now composes actual43cf94..43cfb4
with reader43c4a0/content43c780/bitmap43cc60/defaults43c690 on one sourceCPU/stack.
212 whole native callers match;8 more source returns have unknown-local reads
and are native rejections with full rollback. Do not call these220matches.
184 supported calls finish defaults/EAX18,28 finish bitmap/EAX1. Parent checks
children in order, calls defaults once after any zero, and makes no retry/cache
call. Failed bitmap wrapper remains owned through defaults; no invented cleanup.

Native carries its own184info locals into content1104 at398hex. All other prior
CRT stack backing stays unknown. Shared OriginalMenuContent has opt-in strict
reads and lazy file sourcing after path formats; old declared-backing default
contracts remain unchanged. Missinginfo2 rejectoffset28; empty/zero-linecontent4
reject604; header-only2 reject104. Allsource220 still reach43cfb4 withSP1000f004;
no source memory fault or unterminated-scan stop. Source shared physical bytes
are retained, NOT imported natively or equated to private CRT stack ABI.

212whole calls contain676child returns/39704events. Rejected prefixes add6info
returns/88events: combined682/39792, separately from source698/39894. All90bitmap
children and68constructor/24destructor returns match.32two-call own replacement
chains preserve live/dead generations/reused addresses. Late replacement/default
observer failures restore globals/resources/locals/output; buffer externaleffects.

All10caller starts,716EXE/1486CRT actualPCs;740staticEXE includes12unexecutedh/H
checks and12alignmentint3. CW037f/saved registers/declaredFSffffffff retained.
All13DLL patches disjoint; no installer/CRTstartup/WinMainreturn/Windows claim.
Source94418global/651780shared-stack stores reconstruct full bytes/masks;
708494976source-global snapshotbytes include rejected continuations, not a
wholesale native byte-count claim. OriginalMENU_BACK1 DIB language1028 is a
controlled ad-path device binding, not added/downloaded game content.

Raw13tests5.276s/build193.29s; packaged13tests5.019s/build0.30s passed, retaining
info/roundtrip,704content/118bitmap/534writer/266panel-update cases under their
old contracts.230oldpins unchanged/231current; raw71000012/packed11866492bytes/
JSON/SHA/all1502blobs/10vendorfiles verified.584isolated native files exclude6
untouched foreign transforms. Initialprobe used missinglanguage1033 and failed
before caller execution; fixed to pinned1028, freshprobe/finalsource pass. Probe
whole-stack trace is retained; final audit covers entire shared1104. Source/
native expected rules needed no correction. All owned jobs terminal; NTSDNative
linked. CUA inventory again failed nativepipe startup; no app/input action,
live nativePID revalidated before its normal completion. Transport failure is
not a safety refusal. Jobs/pins: build/research/startup-panel-work.json.
NEXT actual43cfb4..43d078 date/time/music/cursor, earlierwindow/critical-section/
CRT and full WinMain/dispatcher/app composition. Unknown local/WindowsNLS/lib
transforms, actualinput/audio/latency/fullmatches/content/cleanMac remainopen.

[CALENDAR_TIME](docs/research/CALENDAR_TIME.md) now implements VC80 startup
_time64/_localtime64 dependencies. Main9755whole returns match:20clocks,9718nonnull
localtime and17NULL/errno22 returns. Three additional original stops are native
rejections with rollback, NOT9758matches. Whole43cfb4..43d078 remains next.
_time64 subtracts unsignedFILETIME epoch with64-bit wrap then divides10000000;
pre1970 values become large positive quotients. Localtime retains its own36-byte
tm and fills all-1 before checks; successful calls retain prior errno. Maximum
32535244799 includes3001-01-01 07:59:59. First259200seconds use separate UTC-first
normalization; later calls subtract timezone before GMT and DST evaluation.

Actual lazytzset executes from supplied C-locale PTD/environment, never an
injected initialized flag. Own cache/names/allocations survive repeated calls.
OS responses cover positive/negative/fractional offsets, north/south/half-hour
DST, absolute/relative and500ms transitions; failure retains CRT PST fallback.
ASCII TZ parser preserves suffix first-byte flag(PST8PDT=80) and fallback rules
change at2007. Native host environment/timezone/name conversion remains open.
All36tm bytes/masks,128name bytes,three timezone/sixcache words,errno/pointer and
retained allocation bytes/masks compare. Source55803helper returns/1843CRT PCs
are source metadata, not native private ABI.0EXE;1141/1292staticcalendar starts,
all23time/16localtime wrapper starts, not every branch outcome.

Source313439stores/80adapter writes reconstruct data/PTD/owned/output storage;
44adapter writes are private stack outputs.40cases/7916blobs retained. At upper
range input and southern-zone adjustment source stops before actual invalid-
parameter78138a70; no Watson executed. Allocation failure stops before781819ad
reloads reserved word.78181971 pushECX wrote it: not unwritten physical memory.
Its78132da8 belongs to controlled priorCRT register state, NOT recovered own
WinMain provenance; do not import/follow it as a tm pointer. Late conversion and
own-buffer observer trials roll back all native state; stage external effects.

Raw4tests3.288s/build193.27s and packaged4tests2.819s pass, retaining212startup
panel matches/8unknown rejections; packaged build51.56s.231oldpins unchanged/232current; raw134473385/
packed4473165bytes/JSON/SHA/all7916blobs/10vendor hashes verify.587isolated files
exclude6unchanged foreign transforms. Initial Python bytearray API type failure
and first broad19case terminal-hook omission retain frozen sources/logs/parts.
Final capture reads10terminal boundaries after emulation; no expected bytes
edited. Native rules passed first comparison; all owned jobs terminal, app linked.
CUA nativepipe inventory failed again; no window/input action. PIDs revalidated
terminal independently. Jobs/pins: build/research/calendar-time-work.json.
Final input inventory found downsampled exact neighbors in half-hour/absolute/
500ms/nonzeroStandardBias controls. A SECOND immutable corpus adds1089 whole
returns from99 own June baselines and198 boundaries*5 neighboring seconds.
All11DST configurations/nine years explicitly verify0/0/1/1/1 and1/1/0/0/0.
Native rules unchanged; main fixture unchanged. Supplemental7310source helper
returns/1565CRT PCs are a subset of the1843start union; no new PC coverage claim.
Combined10844whole returns+3rejections/118requests. Raw5tests3.386s/build51.40s;
final packaged5tests2.822s/build0.25s. Main raw134473385/packed4473165 plus
supplemental17675299/1172064bytes, fullJSON/SHA/7916+706blobs verified. All231
priorpins unchanged/233current; intermediate232pins retained. Final588isolated
native files exclude6foreign transforms; all owned jobs terminal. Full goalopen.
NEXT whole43cfb4..43d078 ownclock/dateformat/wrappedperiod/music/cursor, then
earlierCRT/window/WinMain/dispatcher/application. WindowsNLS/transforms/host
timezone/input/audio/latency/fullmatches/allcontent/cleanMac remain open.

[STARTUP_OUTPUT](docs/research/STARTUP_OUTPUT.md) now compares whole43cfb4..43d078
on one sourceCPU/stack:49 whole native callers+9 explicit stopped-boundary
rejections, NOT58matches. Both actual date sprintf calls and music graph.log
sprintf execute the same realCRT. Retain first64bit time; expiry adds sign-
extended wrapping32(period*86400), not64bit multiplication. Both tm/date buffers
are own native results, followed by whole402020 and LoadCursor0/7f00->SetCursor.
Enabled music is the main path; all original HRESULT handling/order survives.

Actual _time64(0) leavesECX0;78181971 pushECX writes root1000efe4. Allocation
failure781819ad reloads that own0, helper/localtime returnNULL/errno12; stop BEFORE
43cfd3 NULL read. Native now supplies proven0 for this first caller only. Old
standalone calendar unknown-return corpus stays unchanged/rejected; never import
its78132da8 as a tm pointer. Six NULL-read stops include four wrapped negative
expiries and epoch/-1; three invalid-parameter stops include expiry beyondmax,
firstinput beyondmax and preepoch unsigned clock wrap. No Watson/fault executed.

Own repeated calls carry tm/cache/interface globals and wide buffers; thirdplay
releases/replaces its own graph while retaining both buffers. Native rollback
trials after each date, after music and after both cursor requests preserve all
state. Buffer external effects until complete startup commit. Every native
observation also compares full globals reconstructed from preceding source
stores, preserving write order at all1414event boundaries and final masks.

All64caller starts,371EXE/2021CRT actualPCs,790calendar/216music helper returns;
145real formats(104date+41log),1414events including963music/98cursor.2658original
+165adapter global stores,4041CRT+288adapter writes;101126stack+231adapter stores
are source metadata, not native privateABI.13lib patches disjoint. EntrySP1000f004
becomes1000effc with EBX/EBP still saved; CW037f, ESI/EDI survive. This boundary is
not WinMainret. PEperiod-99/volume100/enabled1; period4/directory/window are
explicit controlled entry inputs, not the preceding whole panel/host output.

Raw9tests40.683s/build191.05s; event-order2tests0.163s/build52.52s; finalpackaged
9tests40.055s/build0.26s pass including both music chains, calendar and panel.
233oldpins unchanged/234current; raw8576099/packed1543267 bytes, fullJSON/SHA/
all122blobs/51atomicparts/10vendor hashes verify.591isolated native files exclude
6unchanged foreign transforms. First native compile needed only explicit Swift
byte-array/read types; original bytes/rules unchanged. All owned jobs terminal;
NTSDNative linked, no production wiring. CUA nativepipe inventory failed; no
window/input action. Transport failure is not safety refusal. Jobs/pins:
build/research/startup-output-work.json. NEXT complete earlierCRT/window/panel,
followinginput and wholeWinMain/dispatcher/application join. WindowsNLS/lib
transforms/hosttimezone/input/audio/latency/fullmatches/allcontent/cleanMac open.

[WINMAIN_STARTUP](docs/research/WINMAIN_STARTUP.md) now connects actual43cf40
through43d100 on one CPU/stack.23 whole native chains match;5 original stops and
7 unknown-provenance native rejections remain separate, NOT35matches. Source
reaches boundary30times;3fullscreen/2panel/2caps paths are rejected natively.
Native owns timeGetTime->srand/PTD14, critical-section platform bytes, whole
window/DirectDraw/panel/settings/calendar/music/cursor/input/all5WAVs. HWND and
DirectDraw tokens flow from their own producers. Original adinfo exists, ad0
content does not:1/0/18 child returns produce period4 without injection.44ef38
stays PEempty, so actual sameCRT sprintf yields `\graph.log`; earlier controlled
C:\NTSD backing is not this own chain. CRT/NLS before WinMain remains declared.

Full startup23chains compare5361events;12 rejected prefixes add964, total6325.
119 whole native WAV results=115inwhole+4beforefifthWAVstop. Six late errors
roll back whole own state afterwindow/panel/date/output/fifthWAV/final callback.
Source35cases retain7266events/156WAVcalls/154WAVreturns and4046actualPCs:
1906EXE+2140CRT.128/132caller starts execute; missing4 earlyreturn instructions
follow a zero43bec0 result, but the controlled whole helper always returns1.
All13lib patch spans disjoint from executed instructions. No wholeWinMainret.

Fullscreen RegisterClass hCursor at1000efd8 has falsemask and zero preceding
writes since declared entry; don't import a5 or fabricate0. Capability failures
read retained CRT cookie/savedframe/return-address/privateFILEpointer bytes as
numbers. Actual last stores78141727/78141712/781777b0/781777a1 are preserved;
these are not native-owned calibration. No corruption/exploit/protection bypass
was performed. Keep both undefined-read rejections and Windows/private-backing
dependency open. Missinginfo/emptycontent remain separate unknown panel reads.
NULL calendar43cfd3/43d028, invalidparameter78138a70 and invalid WAV creation
40187a(first/fifth) are explicit source stops/native rollback, never matches.

Raw11tests24.939s/build197.81s; finalpackaged11tests24.347s/build0.29s passed,
including retainedwindow/panel/output/input.234oldpins unchanged/235current;
raw35021596/packed7434880bytes, fullbytes/JSON/SHA/all1029blobs/35parts/10vendor
hashes verified.594isolated native files exclude6unchanged foreign transforms.
Final source adds metadata only; all candidate1expected/stores/PCs/blobs intact.
Earlier source observer/label errors and two verifier assertion corrections are
retained; no native rule or expected byte changed. All own source/build jobs
terminal; NTSDNative linked, composer not wired to Practice app. CUA pipe failed,
no window/input action. Jobs:build/research/winmain-startup-work.json. Earlier
CRT/NLS, privatebacking, synchronouscallbacks, worker/message-loop/dispatcher/app,
libtransforms, devices/input/audio/latency/fullmatches/allcontent/cleanMac open.

[APPLICATION_MESSAGE_LOOP](docs/research/APPLICATION_MESSAGE_LOOP.md) now
continues the entire own startup through43d100..43d21f/ret16 loop decisions.
63loop returns at declared OS/dispatcher/recovery boundaries plus1own required-
dispatch stop, NOT64fullapp matches. Every64source chain and native comparison
rebuilds the complete unchanged174-event WinMain parent. Loop-only357actualEXE/
0CRT PCs include100/100caller starts and selected actual43b3d0 callbacks.13lib
patch spans disjoint; actual platform delivery/reentrancy and whole43e9a0 open.

PeekMessage uses removeFlag0; anynonzero callsGetMessage; only exactGet0 exits.
NegativeGet still Translate/Dispatch with its own precedingPeek MSG output.
No timer on message iterations; quit readsMSG.wParam and skipscounter.28-byte
MSG at1000f01c has zero parentwrites, native initiallyunknown, APIoutputs own.
Allprovided retrieval writes arewholeMSG; missingoutput native-only trial
rejects unreadablewParam8/4. Counter458580 is separately PE-backed, increments
wrapped32 THEN signed>60reset. Bothstores preserve61->0 and Intmax->Intmin.
Actualret16 leavesSP1000f04c and restorescallerESI33445566, distinct from the
last active timer baseline; keepboth observations, never replace sourcebytes.

215completed iterations/131wholecallbacks/896events compare plus1requiredprefix.
64cases contain216Peek/194Get/131Translate+Dispatch/80time/19gameDispatch/
6recovery/2Sleep. Only18dispatcher responses are declared timercontrols; own
19th stops atactual43e9a0/SP1000eff4 withtarget1/ESI123456822/counter1. No injected
success. Native rolls backthatiteration and retains preceding ownresize.4ms
Sleep uses explicitbackward-clock control, notmonotonicWindowsmeasurement;
retained2025timer corpus keeps1/2/3/5. Five latecontext failures plus actual
ownkeypress->failedkeyup verify MSG/counter/baseline/global rollback.

Raw8tests3.800s/build57.05s after199.55sfirstcompile/63testassertion failures;
onlycomparison conflated activebaseline withrestoredESI. Source/native rules
unchanged. Firstpackaged8tests3.748s/build0.26s; extraactualrollback1test0.072s/
build55.37s; finalpackaged9tests3.774s/build0.24s passed, retainingtimer/WinMain/
input.235oldpins unchanged/236current; raw4331171/packed2536603bytes, fullbytes/
JSON/SHA/305blobs/64parts/10vendorhashes verified.597isolatedfiles exclude6foreign
transforms; sharedstartuptest changesvisibilityonly. Source generator/clock-
stimulus errors and52completedparts retained; final560EAXmetadata additions
leaveallpreviousexpected unchanged. Allownjobs terminal; NTSDNative linked,
notwiredtoPractice. CUApipefailure,no window/input action; Windowsdownloadnot
retried. Jobs:build/research/application-message-loop-work.json. NEXTrequired
whole43e9a0/staticWorld/worker and43e890 recovery, earlierCRT/NLS/privatebacking,
WndProc/application/lib routing/transforms, devices/fullmatches/allcontent/cleanMac.

[APPLICATION_ART_SETUP](docs/research/APPLICATION_ART_SETUP.md) now implements
whole43e8e0..43e934 with actual401250 semantics.231 controlled returns match
693requests,11570328globalbytes,7392query/23100clear bytes+masks;225 independent
calls plus6 own retained calls. All26helper+17clear starts execute;4158source
stackstores+465declared adapterstores reconstruct all snapshots.32-byte query
writes size32 then calls455634/vtable54; queryHRESULT/output fields are never
read. Reread455608 AFTER query callback; clear black via shared401250. Negative
clear yields original failure string/0, otherwise success string/1; debugresult
ignored. Despite LoadGameArt text, helper loads no resources. No EXE global
stores: callback changes are explicitly declared valid surface-reference writes.
Query28/clear92 retained bytes remain supplied boundaries, not own WinMain
stack provenance. Six calls retain native own local output; four late query/
clear/debug/final errors roll back value context. Buffer external effects.

Raw5release tests4.912s/build212.31s; finalpackaged5tests4.695s/build0.32s passed,
including retained4348keys/420clears/staticWorld. No source/native correction.
236oldpins unchanged/237current; raw1424097/packed66603bytes, fullraw/packed
JSON/SHA/38blobs/231atomicparts/10vendorhashes verified. Isolated597committed
basefiles+3overlays exclude6foreign transforms. All own source/SwiftPM jobs
terminal0; NTSDNative linked, no window/device/Windows claim. Exact jobs/pins:
build/research/application-art-setup-work.json. NEXT whole43e9a0/43e890,
required own staticWorld/worker/stack composition, earlierCRT/NLS/lib routing/
transforms and full app/device/match/content/clean-Mac goal remain open.

[APPLICATION_RECOVERY](docs/research/APPLICATION_RECOVERY.md) now implements
whole43e890/43e860 with actual401ae0/401a80 and43bdd0 children.318 whole recovery
returns+3 own initializations match;1 ordinary null-back source fault is explicitly
rejected, NOT322matches. Source5113requests/2431helper returns/2236global stores,
840structures/65968bytes,565EXE/0DLL newPCs. All18restore+14/16caller starts run;
43e8b1/b6 need a negative43bdd0, but its217actual returns are0/1. Do not invent
negative helper success. Primary restore result ignored; backnonnegative or
exact8876024c becomes0. Other negative triggersflag1, release/clearback-primary-
draw when drawexists, DestroyWindow, wholeconfiguration, ShowWindow(liveHWND,5),
flag0. ShowWindow numeric result survives as recovery result. Shared display
destruction also serves unchanged Alt+Enter lifecycle corpus.

Two own43bec0 initializations each continue6recoveries; third ownsfailedcreation
thenfault. All14retained states and576stackbytes exactly retain own previous
output;28955CPU/116API stackwrites reconstruct. Fresh globaltemplate includes
normal installer cookie/complement stores44eea4/a8, notpurePE; verifier corrected
that assumption, sourceexpected unchanged. Helpers retain suppliedopaque frames,
notownWinMain provenance. After negative restore and CreateWindow0, original
still ShowWindow(0,5)/flag0; next43e876 reads4bytesat0/UC_ERR_READ_UNMAPPED.
Native explicit missing-back rejection preserves preceding failed-create state.
Six late failures verify whole globals/object-lifetime/buffered-context rollback.

Raw13release tests23.212s/build203.64s; finalpackaged13tests23.211s/build0.3s,
including retainedwindow init/lifecycle/art/message-loop, allpassed.237oldpins
unchanged/238current; raw11152693/packed1368288bytes, fullJSON/bytes/SHA/93blobs/
322parts/10vendorhashes verify.600committedbasefiles+ownedoverlays exclude6foreign.
Firstprobe helper-return bookkeeping error retained; four completeprobe cases
and failedtrial requests/stores unchanged. Source/nativejobs terminal; no rules
or sourceexpected corrections. CUA nativepipe failure, no window/input action.
Jobs:build/research/application-recovery-work.json. NEXT whole43e9a0/ownWorld/
worker/stack composition and earlierCRT/NLS/library transforms/application/
Windows/devices/fullmatches/allcontent/cleanMac. Actualdispatchernegative-result
reachability remains open despite controlled recovery completion.

[WINDOWS_REFERENCE_PREPARATION](docs/research/WINDOWS_REFERENCE_PREPARATION.md)
prepares freestanding x86/ARM64 Windows NLS collectors,22KERNEL32 imports/noCRT.
The exact type1/UTF16NUL/count1 CRT request remains unanswered on actual Windows.
Eighteen collector-only Unicorn self-tests use explicitly artificial API values
for serialization, dependencies and ordinary IO failures; NEVER import them into
the original CRT or call them Windows/game/native comparisons. No new fixture,
Swift code, app run, Windows guest or VM installation follows from this stage.

The web tool rejected download redirect2276103 as unsafe/non-retryable. Exact
error/time/thread and unavailable turn-ID field are in build/research/
windows-reference/download-refusal-20260910.json. This is not cyber_policy or
automatic approval-review output. Do not retry this download via another tool.
An independently available authorized Windows ISO/endpoint remains requested;
continue independent permitted work. Read the bounded
[WINDOWS_REFERENCE_PLAN](docs/research/WINDOWS_REFERENCE_PLAN.md) before capture.
Build/pack hashes and terminal jobs: build/research/windows-reference-work.json.
Windows NLS must be a new explicit OS profile, never relabel synthetic XP5.1.

Remaining hook is41f5fc transforms, plus all enclosing
library-enabled routing and full CRT initialization. Recover Actor+7b4 and
actual unknown0xb2 backing/reachability without silently fixing source bugs.
Old pristine-EXE fixture bytes remain immutable and valid in their declared
unloaded-library controls; they do NOT establish the DLL-enabled application.
Active captures are separate pristine controls: inspect their current process
handles and work metadata before acting; never restart or relabel them as
DLL-enabled. Full initialized application, full match/content, app/window,
Windows/device/clean-Mac and the full native-game goal remain open.

Both pristine EXE/VC80 active48 controls now compare completely. Read
[ACTIVE_GAMEPLAY_CAPTURE](docs/research/ACTIVE_GAMEPLAY_CAPTURE.md) and its
[finite plan/history](docs/research/ACTIVE_GAMEPLAY_PLAN.md). Each keeps the
whole neutral16 parent, then48 acquired movement/attack/guard/jump/depth/release
calls:6484388records/27160941109bytes+masks/1549states;49308/51996active events
and13366/13750body/output helpers. Source55568FPU checkpoints retain023f;
all28590 retained active16 checkpoints reproduce. This is source FPU history,
not native process FPSW/tag or hardware equivalence.102259stack accesses/59PCs
each; broad5355/5363address inventories include hooks/stops, not actual coverage.
No source Actor/phase/RNG/stack words drive Native. Twenty actual key transitions
and20changed replay returns; counters450b8c/450bbc18..65, recording flag1/live.
Call17 creates slot50, processes/removes it in the same pass and drains two
catalog plays in order. Across48:51primitive RNG,1constructor,7catalog/queued
plays. The400-byte memset adapter runs once, bytes already zero, not CRT code.
Only slots0/1 remain at every return; HP500 throughout, final MP221/frame0/212,
Naruto354/0/497 and Sasuke364/-78/525. No damaging-hit/round-result/fullmatch claim.
Full137Objects/130weapon strings at returns/acquisition,14586Frame allocations;
95undefined portrait words remain unknown,1824/3360undefined bitmap reads remain
declared research backing. Late dispatcher observer rolls back whole-call owned
state after changed replay/movement while preserving acquired input.
Raw2release tests159.390s/build169.00s; packaged2tests153.680s/build166.35s.
Both48source jobs and all owned SwiftPM jobs terminal; never restart completed
capture.196priorpins unchanged/198at publication; subsequent lib milestone adds
two separate fixtures to200. Fullraw/packedJSON/bytes/SHA,7811blobs/1314manifests
and10vendor hashes verify. Final isolated package4298b7e+six active files excludes
then-concurrent lib changes; earlier integrated6timer/neutral/pause tests also
passed160.603s/build175.89s with those exact files. No DLL-enabled join follows.
Exact capture producer archived before comment-only scope annotation; raw bytes
unchanged. Three terminal preparation failures and intermediate16/17 proofs
remain in build/research/active-gameplay-work.json. NTSDNative linked; no window
or device tested. App still uses Practice; bundled-library hooks/initialized
join, fullmatch/content, Windows/device/clean-Mac and the full goal remain open.

The read-only [ACTIVE_LIB_IMPACT](docs/research/ACTIVE_LIB_IMPACT.md) audit finds
5of13installed patch sites in both active48 instruction inventories: control,
lifecycle,commands,text all48;contacts11. These are inventory intersections,
not DLL execution/outcomes or dynamic instruction counts. Full byte intervals
preserve partial-instruction patches; absent loading/preparation/other hooks
remain required. No original byte or native acceptance fixture changes.

Additional dispatcher prerequisites now compare in
[APPLICATION_DISPATCH](docs/research/APPLICATION_DISPATCH.md). Shared
OriginalApplicationKeyScan matches4348 further prefix exits/9847ordered stores
and217782624 complete global bytes, including signed invalid states and seeded
keyboard bytes. OriginalSurfaceClearing matches420 whole401250 returns:
100effect bytes/masks, null rectangles/source, flags1000400 and unchanged
HRESULT. Preserve92 supplied local bytes; own outer stack provenance is open.
Actual57key/17clear/14initializer-constructor PCs exclude stops/adapters.
The existing World constructor matches explicit446300 over recovered PE
zero-fill at458b00; pointer446300 at4472d0,2008zero bytes,404constructor writes.
The400-byte memset is a declared adapter, not executed CRT instructions.
This is NOT CRT initializer order or an own whole43e9a0 join. Earlier controlled
World22000020 must not be silently aliased/copied into static458b00. Full236
outer instructions are byte-checked STATIC inventory; preserve live mode
rereads after callbacks, global455608 target, enabled loader/editor branches
and normal return1. Raw3release tests4.258s/build176.63s; all195priorpins
unchanged/196current, raw16337221/packed10247264, completebytes/JSON/SHA,
4853blobs and10vendor hashes verified. The initial terminal build failed only
from a concurrent API replacement; the corrected harness reuses a11f571's
KeyScan without changing source expected bytes or algorithm. Final packaged
5release tests4.452s/build173.02s pass, including retained3964scanner cases,
chains and rollback. Source and final SwiftPM jobs terminal0; initial compile
failure terminal. NTSDNative linked; job details in
build/research/application-dispatch-work.json.
Full initialized dispatcher, app/window/device/Windows and full-game goal remain
open. Active48 captures are independent terminal controls, described above.

Two independent outer-application dependencies now compare; neither is the
whole initialized43e9a0 join. Read [APPLICATION_TIMER](docs/research/APPLICATION_TIMER.md)
and [APPLICATION_SERVICE_KEYS](docs/research/APPLICATION_SERVICE_KEYS.md).
OriginalApplicationTimer matches2025 whole43d157..43d1ef decisions/8163ordered
requests, all59actual instruction starts. Fresh clock reads, unsigned lateness,
baseline clamp, signed-negative dispatcher recovery and signed/capped Sleep
survive. Dispatcher/recovery/OS bodies are declared boundaries; Sleep4ms is
not exercised. Timer-only late failure rolls back baseline, not external game
effects.191oldpins unchanged/192milestone; raw2tests0.026s/build173.41s and
packaged2tests0.027s/build0.29s. The old aggregate OriginalClock stays unchanged.

OriginalApplicationKeyScan matches3964 whole43e9db..43ea95 prefix exits and9278
ordered stores;997303 key reads,57/57actual starts. Scan0..<250 recognizes100,
retains/reset A/B/C sequence, stores450bec then4593a4, and checks enabled
F1/F2/F3 in order, preserving multiple4593a0 stores.28retained calls in3chains
use native prior results. Complete50088global bytes reconstruct from source
stores; all300keyboard bytes unchanged. Late third-mode observer failure rolls
back all native fields. Controlled sequence0..3/diagnostic0..1/mode0..2, not
own acquisition or full dispatcher;236whole-dispatcher starts are STATIC.
Do not extend loaded-match globals or import a World snapshot to invent outer
4593a0/4593a4 ownership or fixed458b00 provenance.194priorpins unchanged,
195atmilestone; raw6762062/packed485739, fullJSON/bytes/SHA and10vendor hashes
verified. Raw2release tests0.086s/build174.13s; final packaged2tests0.065s/
build180.90s after naming the independent API KeyScan to avoid concurrent
dispatcher API collision. All owned prefix/timer jobs terminal0; NTSDNative
linked, no window/device/Windows evidence. Active48 captures remain separate;
both completed and must not be restarted. See build/research/active-gameplay-work.json.

Both fresh own chains now match pause, single-step and resume through both
actual returns. Read [PAUSED_GAMEPLAY](docs/research/PAUSED_GAMEPLAY.md).
OriginalLoadedGameplayCall routes own pausedRendering into OriginalPausedGameplay:
direct background (no camera bounds), World drawing, preserving HUD, PAUSE bitmap,
indicator join and whole output/dispatcher transaction.14 new calls each after
all16 neutral parents:8paused/6unpaused, F1/F2/F1 from acquired key bytes only.
Replay/elapsed counters17->19, hold,21, hold,23. No pause flag or stack injection.
Each native comparison reports3000280records/9685070146bytes+masks/651states,
including parents and rollback; new14337/15121events and3490/3602helper returns.
All20368FPU checkpoints keep023f;15102parent unchanged,843/unpaused and26/paused.
Paused local input has no helper/pre-dispatch checkpoint; preserve that skip.
Source921actual paused-body/helper PCs exclude stopped422994/COM;12811stack
accesses each. Own stageDefeated/formatter remain nil on pause; target has own
caller provenance. Preserve320/576 undefined bitmap reads and live sound drain.
Late whole-call observer rollback passes for unpaused and paused calls. Raw2
release tests pass72.131s/build173.90s; packaged2pass72.523s/build167.30s.
All192prepublication pins unchanged,194current; fullraw/packedJSON/SHA/lengths,
2861/2862blobs,107components each and10vendor hashes verified. Both source jobs
terminal0; all owned SwiftPM jobs terminal,NTSDNative linked,435links/Python/diff
checks pass. Initial acquisition-name and decode-contract failures are preserved;
no accepted source bytes or native game rules changed to force agreement.
This is own non-playback pause, not all paused branches/playback prologue, outer
loop/app/device/Windows/complete-match evidence. Full game goal remains open.

The preceding paused HUD dependency is implemented in
[PAUSED_HUD](docs/research/PAUSED_HUD.md). OriginalWorldHUD.drawPreservingCommands
matches1789 whole41ae60..41b12d/ret4 calls with command flags preserved, full
World/400Actor bytes+masks/globals and283090 events. The1753 earlier HUD inputs
reproduce every pool/mask/event/helper result;36 more flag pairs remain unchanged.
Source ECXWorld/EDI1/ESIargument, controlled EBP, CW027f/FPSW0/tagffff; argument
and rootSP68 remain unread. All223HUD starts execute;477 total original PCs,
61173 helper returns,40542Blts/70undefined reads. Six unpaused caller PCs and
the stopped sentinel are excluded. This is not every branch, the whole paused
caller or an initialized own pause. Preserve direct background draw (no camera
bounds pass), command flags, PAUSE bitmap and the422952 indicator join when
composing that remaining caller. Static39paused instructions are byte-verified,
not dynamic whole-pause evidence. Original apply still clears both flags.
Raw6release tests pass58.484s/build172.20s; final packaged6pass58.119s/build169.18s,
including retained1753HUD/two late failures and both initialized bodies with
19checkpoints/1012+1068events. All190 prior fixtures unchanged,191current;
raw35383336/packed737624bytes, fullJSON/SHA/lengths and10vendor hashes verified.
The source harness failure, tightened ESI binding and isolated-build preparation
are documented; no accepted expected bytes changed. All owned jobs terminal.
NTSDNative linked; no app-window/device/Windows claim. Full pause/resume,
active inputs, outer clock, app integration/full match/full goal remain open.
See build/research/paused-hud-work.json for exact process and package provenance.

Both fresh own chains now match16 successive loaded gameplay calls through
both actual returns. Read [CONTINUOUS_GAMEPLAY_CAPTURE](docs/research/CONTINUOUS_GAMEPLAY_CAPTURE.md).
OriginalLoadedGameplayCall joins input/round and OriginalGameplayBody under one
transaction; a late dispatcher observer verifies whole-call rollback. Each full
comparison checks2050892records/6526992869bytes+masks/442state checkpoints,
15102FPU checkpoints; new16400/17296events and4400/4528body/output helpers.
All1614parent FPU checkpoints reproduce; new843percall keepCW023f. Source
33960stack accesses per variant retain own stageDefeated and unknown caller
storage; normal saved frames/SEH/cookies restore. No source stack import.
Actual450b8c and450bbc advance2..17;450b80 stays1 because it is recording-enabled.
The unchanged source log mistakenly labels450b80 "tick"; derived verification
was corrected without touching source/expected bytes. Final frames3/2,wait2,
HP500/MP205.16neutral replay packets leave existing buffer bytes unchanged;
do not claim rollback after changed replay payloads on this path. Enabled sound
drains16times without newly queued sounds, separately from the parent's play.
Full allocated Frame heap is compared at every returned call, not every middle
boundary. Packed Object/Frame table baselines remain the accepted catalog's;
this study adds no whole packed-table snapshot at every return. Observed broad
original-address inventories3983/3991 include inherited hook boundaries and
must not be called per-instruction coverage. Output instruction evidence stays
separate. Raw2release tests passed61.109s/build163.45s.188oldpins are unchanged;
190milestone pins include2newfixtures,5911verifiedblobs/410components/10vendor
hashes. Final isolated packaged2tests passed61.572s/build173.90s. All owned
continuous source/build/test jobs are terminal. NTSDNative linked; no new app
window/device/Windows run. Source sessions23453/
58546 and PIDs86511/86510 are terminal0; never restart for silence. Native final
verification exports only the pinned native package to exclude concurrent HUD
edits. An initial full checkout was cancelled while fetching unrelated LFS
archives, before any build began; this was not a source/build restart. See
build/research/continuous-gameplay-work.json. Next bounded active input and
paused/menu/epilogue joins, actual timed outer43e9a0, app engine integration,
fullmatch/Windows/device/clean-Mac and the full goal remain open.

The preceding body-only milestone (its input/16-call boundary is superseded):
OriginalGameplayBody now composes the unpaused native body from the own round
gameplay continuation through output and dispatcher clear under one transaction.
Read [GAMEPLAY_BODY](docs/research/GAMEPLAY_BODY.md) and
[LOADED_TICK_PLAN](docs/research/LOADED_TICK_PLAN.md). Both accepted initialized
paths match19 complete semantic checkpoints and1012/1068 ordered events;
the full old parent chain and1614FPU checkpoints still compare. A final output
observer failure rolls back the earlier simulation and globals. Replay/CRT
storage is unchanged on this path; do not claim exercised mutations of each
owned subsystem. Packaged2tests passed44.737s/build175.44s; core build61.57s.
Final source-stage/event-order checks passed2tests45.395s/build70.81s. Retained
default return API2tests passed42.617s with all prior counts unchanged.
No original fixture changed:188 pins retained, no fresh source/instruction claim.
The body preserves actual recorder continuation and own stageDefeated. Unknown
caller words stay unknown; shared formatter support does not complete the enabled
own formatter domain. Mode1/4 post-draw children and paused/menu/epilogue remain
explicit alternatives or rejections, never silent successful gameplay returns.
Input/round entry still needs the enclosing native transaction and dispatcher;
16 successive source calls, runtime integration and the full game remain open.
All body build/test jobs are terminal. Separate16-call captures remain live;
preserve those jobs and tools. See build/research/loaded-gameplay-composition-work.json.

**Current priority: bounded active input and loaded continuations, then timed outer-loop/full-match/app integration.** Read
[GAMEPLAY_RETURN](docs/research/GAMEPLAY_RETURN.md),
[CONTINUOUS_GAMEPLAY_PLAN](docs/research/CONTINUOUS_GAMEPLAY_PLAN.md),
[GAMEPLAY_RESULT_LAYOUT](docs/research/GAMEPLAY_RESULT_LAYOUT.md),
[GAMEPLAY_OUTPUT](docs/research/GAMEPLAY_OUTPUT.md),
[RESULT_LAYOUT](docs/research/RESULT_LAYOUT.md),
[RESULT_RECORDING](docs/research/RESULT_RECORDING.md),
[GAMEPLAY_RESULT_RECORDING](docs/research/GAMEPLAY_RESULT_RECORDING.md),
[RESULT_LAYOUT_PLAN](docs/research/RESULT_LAYOUT_PLAN.md) and
[TICK_TAIL_PLAN](docs/research/TICK_TAIL_PLAN.md).

BOTH fresh own chains now match through actual422ab8/ret4,424746 held clear and
428805/ret4 toSTOP30000000/SP1000f42c. Each577173records/912855320bytes+masks,
703/711helpers,67state/1614FPU checkpoints. Complete layout parents reproduce.
New output each794events/76Blts/532defined reads/167helpers/1VC80format/1play;
13stores touch32globalbytes,21change; all other storage and ownership survives.
VS mode (Difficult), actual recording notice450b6c1->2, present primaryFlip1 /
controlBlt3, then enabled queued sound. Clear4575a0 before pan-525/volume0 and
Stop/Position0/Play0 on own24001060;418distinct loaded sound buffers. COM adapter
bindings are separate declared responses, not Windows/device initialization.
All15caller+12inner+12outerepilogue starts execute; source568/576EXE+303CRT PCs,
3normal cookie checks. Both actual entry/saved4/SEH/return frames verified;
no source stack word seeds Native. All1606parent FPU checkpoints plus8new keep
CW023f/FPSW4000/tagffff. Native output also rolls back on the final dispatcher
observer after preceding label/notice/queue mutations. Buffer device effects.
Raw3release tests pass44.480s/build177.49s: own44.059s,controlled170calls0.422s.
Both source sessions11350/20649 terminal exit0, never restarted. First native
build had only a comparison-variable shadowing collision; renamed corpus fixed
it, test-support build110.84s. No source expected byte or game rule changed.
Two new fixtures preserve186oldpins,188current. Independent fullraw/packedbytes/
JSON/SHA/all5515blobs and10vendor hashes verify. Ownraw9395792/9412226bytes;
packed1302527/1313871bytes. Final packaged3release tests pass43.474s/build167.94s
without raw overrides: own43.050s,controlled0.424s. All owned source/SwiftPM jobs
terminal;539local Markdown links/Python compilation/diff checks pass.
Work:build/research/gameplay-return-work.json.
A separate launched window/image check used the existing OriginalMelee prototype;
it is not this new engine's app integration or input/audio/latency evidence.
The first match/mode-dispatcher call has returned; continuouscalls,43e9a0/outer
app loop,fullmatch,Windows/devices/cleanMac and the entire game remain open.

The preceding milestones retain their narrower historical boundaries:

BOTH fresh initialized chains now match through422994/SP1000e9bc. Each compares
545197records/877520166bytes+masks,536/544helpers,65state/1606FPU checkpoints.
The whole GAMEPLAY_RESULT_RECORDING parent reproduces; complete before/after
state is identical. Only422944/42294b execute, followed by the unexecuted422994
stop. No new helper/event/undefined read, no access to root34..6b or44c..5c3.
CW023f/FPSW4000/tagffff and all1605parent FPU checkpoints survive. Native uses
the actual recorder continuation and own retained round result. Formatter
backing and indicator target remain nil; no expected stack word is imported.
Source70983/12479 are terminal exit0; neither restarted. Raw native2tests pass
42.459s/build162.43s. A stale183-count publication assertion first stopped after
source verification because concurrent accepted output had added fixture184;
all183prior pins were unchanged. Acceptance now preserves the184-pin baseline.
Two own fixtures bring184old unchanged pins to186current. Independent fullraw/
packedbytes/JSON/SHA/all6084 controlled+own blobs and10vendor hashes verify.
Own raw9250044/9266358,packed1278715/1289563bytes. NTSDNative linked; no app window,
Windows or device evidence. The output/return join is accepted above;422994 alone is
not a tick return. Track verification in build/research/result-layout-work.json.
Final packaged4release tests pass44.987s/build0.25s without raw overrides: both
own joins42.452s,599-match/1-rejection layout2.115s and170controlled output0.419s.
All layout source/SwiftPM jobs are terminal. The concurrent own-output/return
work is separate and must retain its live processes and uncommitted files.

Controlled OriginalGameplayOutput now matches170 whole original output/returns:
119700ordered events,10968Blts,109VC80formats,4505COMmethods,816queue writes and
780play calls. Source executes real41bc90 prologue, then declared422994 context,
all15caller+12epilogue starts and actual422ab8/ret4;903EXE+414CRT PCs exclude
the separately recorded19prologue starts. Both saved-register/SEH restoration
and340normal cookie checks are verified. No intervening own gameplay body is
claimed. Mode label -> notices/volume -> present -> enabled sound order preserves
the same-call volume change. A late eighth sound method rolls back all native
output state. Source globals/write masks reconstruct independently; native
compares complete globals/defined masks and ordered events, not private stack
or a separate overlay store trace. All183prior pins unchanged;184at publication;
fullraw17815852/packed1823384bytes,JSON/SHA/all292blobs verified. Raw release
test0.454s/build169.37s; packaged0.420s/build0.28s; NTSDNative linked, no app/device
or Windows check. Controlled output jobs are terminal; separate initialized
layout source PIDs73470/73471 were left undisturbed and have since completed above. Read
build/research/gameplay-output-work.json. Commit9784426 preserves this controlled
milestone; own initialized return is accepted above;fullmatch/app/cleanMac and full goal stay open.

OriginalResultLayout now implements whole422218/422944..422994.599 whole original
returns match full records/masks/globals, caller formatting and ordered output.
One additional127-byte author input overwrites44fd8c with41414141 and faults at
43f04b reading4141414d. Native rejects its unavailable bitmap backing and rolls
back after the same observed prefix. This is599matches+1source-fault rejection,
NOT600matches. All537caller starts execute;600-input inventory1103EXE+424CRT PCs.
Normal599:386781events/25661Blts/66705helper returns/9877formats/9589GDI text calls.
Source288complete REPs/420undefined bitmap reads;155root64/156root68 reads.
Native uses the recorder's actual continuation. Preserve optional root44c string
backing and root68 indicator target, live playback ownership, exact-one stage
result, primary/fallback seats and actual negative-picture fallthrough. Root50
pointer adjustment alone is normalized to the logical World+4 displacement10.
Four rollback trials include a late overlay failure after the table and22formats.
Raw acceptance passes2.239s/build155.60s; initial full comparison2.195s/build34.31s.
Initial149.02s build linked but relative test path failed; corrected absolute path
passed. All182 old fixture hashes unchanged;183 current, fullraw57182095/
packed7989824bytes,completeJSON/SHA/571blobs/10vendor hashes independently verified.
Packaged3release tests pass44.722s/build157.73s without raw overrides: layout2.098s,
both retained own result chains42.624s. Their full prior records/FPU reproduce.
Source setup first collided with the base harness arena and was moved. The first
full source stopped at the malformed author pointer guard; after terminal status,
580 atomic cases were retained unchanged and the actual unmapped read recorded.
No live source was restarted. Both own captures and their joins are now accepted
above; the own boundary is422994/SP1000e9bc. Controlled output was independently
committed9784426/872964f during this work and remains preserved.

The preceding accepted result-recording/output-helper milestone:

OriginalResultRecording now matches95 whole controlled returns:82 actual writers,
12playback restores,18322 descriptor requests/33219692bytes.13gates have no writer;
76codec successes,5allocation-4 and1no-temporary-2 returns retain original cleanup.
All296 caller starts,116writer/40restore starts,3212DLL PCs;1277codec/410stream
helper returns,608complete REPs,1936406longest_match invocations. This is not all
branch outcomes, a host/Windows CPU measurement or private C++ ABI equivalence.
Retain live playback/recording aliases, restore-before-key-count order, both buffers'
free/clear/destroy order, and ignore numeric IO/codec failures as the original does.
Missing stage-result and late destruction observers verify whole native rollback.
Writer's prior21returns+5explicit source faults remain their separate contract.

BOTH fresh own chains now match through422944/SP1000e9bc: each513221records/
842185012bytes+masks,536/544helpers,63state/1605FPU checkpoints. Full pinned parents
reproduce. Only450bbc changes0->1; recording remains live and no own writer runs.
Seven actual caller instructions plus unexecuted stop. Each89-access rootSP64
audit has only the actual41d7d7 write0 since last round initialization. Native
MenuCycleReference retains its own roundResults; no source stack word is imported.
CW023f/FPSW4000/tagffff and all1604parent FPU checkpoints survive. This is still
an unreturned first tick, not a full tick/match/app/Windows/device claim.

Stack correction:4222ce has six pending pushes, so its[esp+64] writes root4c,
NOT root64;422673 still reads the retained round result. The833-instruction/92
ESP-operand audit through422994 is STATIC, not dynamic coverage. RetainedSP68
is actually used by the indicator when450b84 is nonzero; require real own target
provenance then. Choose result-table or indicator entry from the recorder's actual
continuation. Unknown caller string backing stays unknown until recovered.

Accepted output dependencies:
- [BITMAP_FONT](docs/research/BITMAP_FONT.md):2450 whole423940/423a70 calls,
  143462events/6125NULwrites/10971Blts/555undefined bitmap reads,35720returns.
  394EXEPCs:103/104single(alignment absent),63wrapper,171bitmap,57clip. Mutable
  shared string sees each preceding pass's truncation; preserve signed glyphs.
- [MODE_LABEL](docs/research/MODE_LABEL.md):148 whole41b130 calls,181730events/
  10156Blts;156/157caller starts(alignment absent),523EXE/0DLL. Unknown modes
  retain existing text; signedstage/10==5 selects Survival, X uses pre-truncation
  length. Complete global writes/order and late rollback match.
- [PLAYBACK_INFORMATION](docs/research/PLAYBACK_INFORMATION.md):120 whole41b390
  calls,157795events/240formats/14766Blts/240REPcopies/468undefined bitmap reads;
  200/200caller starts,562EXE+418CRT,32470returns. Exact10-byte sentinels, live
  author/info truncation, signed wrapped tick formatting and late rollback.
- [QUEUED_SOUND](docs/research/QUEUED_SOUND.md):952whole419e60 drains+16direct
  401a30 calls;8314events/5776COMrequests/1410flagstores/2080returns.143/145queue
  starts(skipped alignment)+30/30play.400catalog slots precede80builtin slots;
  clear positive flags before sum checks, read right weight first, preserve pan/
  volume wrap and ignoredHRESULTs. Initialized own audio/device join remains open.

All source and SwiftPM jobs are terminal, including the long95-case source44597.
Never restart it: its completed raw corpus is hash verified. Intermediate cases
were atomically retained; no live process restarted for silence. Raw acceptance10
release tests passed58.577s/build149.00s, including own40.441s and result10.977s,
plus all four output helpers and retained writer/815codec/66stream corpora.
Final packaged10tests passed58.142s/build0.23s without raw overrides; own40.355s,
result11.120s. NTSDNative linked; no app window or device was exercised.
Seven immutable new fixtures bring175old unchanged pins to182current. Independent
fullraw/packedbytes/JSON/SHA/all9040blobs and10vendor hashes verified; intermediate
176/178/179/180/181/182 pin sets agree. Source/raw files retain every original
expected byte. Native codec remains private C1.1.4; transport deflation only packs
research fixtures. Initial build-only playback-info invocation lacked testing
support; normal swift test passed without game/expected changes. Final artifact
verifier's first vendor path omitted the vendor subdirectory; corrected path
checks unchanged files. Read build/research/result-recording-work.json for jobs
and final evidence. Whole layout/indicator/initialized output composition and
actualret4 remain next; full-game/app/Windows/device/clean-Mac goal stays open.

The preceding whole-writer milestone (own boundary superseded above):

Whole43dd60 is now implemented in OriginalReplayWriter.21 whole returns match
full buffers/masks/globals,4588a8 ownership and24350 descriptor writes/58522686
bytes. Five more source faults are explicit native rejections with rollback:
NULL key-adjustment read, NULL payload CRT invalid-parameter/Watson, two path
cookie overflows, and a6500-byte key overwriting the compiled-version pointer.
Do not call these26 successful matches. The compiler-version pointer44dce8 is
read by440434/44043c before codec allocation; alternate backing remains open.
The original ignores compression and IO numeric errors, still closes, frees
temporary, re-reads/frees4588a8, clears4588a8, then destroys the stream.

Keep live key/name globals and lazy44dd50 selector: native C counts actual match
invocations, and only selector2 with a nonzero count requests the supplied
original processor signature. The original detector produced306c4 on this
controlled CPU.4353858 native/source match counts agree, including4074271 for
the fullrandom capacity failure. This is not a host/Windows CPU measurement.
Source365 codec/117 stream helper returns,882 complete REPs,116/117 writer starts
(43de0c alignment missing) and3292 DLL code-hook PCs. Decoded helper-block starts
are NOT per-instruction execution proof. All26 source calls request27522 writes/
71508038bytes, including cookie-failure IO NOT compared natively; use the smaller
successful-call counts above for native claims. Private C++ ABI/heap pressure,
actual Windows files/exception handling and own initialized result join remain
open. Native source storage must have recovered provenance; version-pointer
alternatives and corrupted descriptor backing are not a completed native domain.

The whole raw comparison passed0.774s/build145.03s before publication. Early
checks passed the prior815 codec/66 stream corpus,6 whole writer returns plus
one rejected pointer fault, then15 returns plus3 source faults. A late-observer
trial fails at destruction after staged frees/clear and verifies rollback.
Both retained own notices passed40.301s alongside the initial whole-writer case.
The source suite's research string limit was corrected before the long-key
case, then actual unmapped/Watson boundaries were recorded. Completed cases
were preserved in atomic hash-verified checkpoints only after each previous
source process was terminal; no live process was restarted for silence.
All174 old fixture pins remain unchanged,175 current. Independent fullraw/
packedbytes/JSON/SHA/1882 zlib-framed blobs and10 vendor hashes verified.
Raw44801203/packed36098192bytes. Native compression still uses private C1.1.4;
transport zlib framing does not replace game output or run a DLL in the app.
Final packaged5 release tests passed44.296s/build145.99s: whole writer, retained815 codec,
66 streams and both own notices. NTSDNative linked; this is not app-window or
Windows execution. All source/SwiftPM jobs, including the primary stack audit,
are terminal. The own initialized gameplay boundary remains421cdc/SP1000e9bc.
Python compilation,534 local Markdown links and owned-file diff checks pass.

The new original-stack audit tools/oracle_result_stack.py reproduces the entire
primary GAMEPLAY_NOTICES corpus unchanged.89 accesses total to rootSP64; after
the final41d7d7 round initialization only that one write0 occurs, with final0
at421cdc/SP1000e9bc. No stack value was injected. This proves the selected own
path, NOT the control variant or every branch. Preserve the already computed
OriginalMatchRoundResult.stageDefeated through MenuCycleReference (currently
discarded); do not import expected stack bytes for the next result consumer.

The preceding codec
dependency is now implemented:815 whole43f4b0/43f400 calls match the public
OriginalReplayCompression Swift API/private native C1.1.4 subset.31390143 output
bytes/masks,11388 helper returns,5116 complete REP copies; all51+11 wrapper starts,
3208 EXE/0 DLL PCs.321success/397capacity-5/72level-2/25allocation-4 statuses.
Output length remains unchanged on failure; partial bytes must survive because
43dd60 ignores the status. The full6491672-byte own recording compresses10047;
zero control6326; fullrandom needs6493663 bytes, so original6492672capacity fails.
Both own parent recordings are identical inputs, NOT two own codec continuations.

Original allocator failure2..5 leaves4 allocations live: deflateEnd sees an
uninitialized status and returns-2; init returns-4. Native reports that algorithm
lifecycle before reclaiming private host storage. State ABI5816x86/5920LP64 is
explicitly distinguished; no Windows heap-exhaustion/leaked-byte equivalence.
Raw Unicorn write hooks miss11570063 bytes in4cases. Actual43f5c3/43f5ca REP
counts, DF0, ECX0/ESI/EDI advancement and full copied bytes verify the correct
mask; raw hook masks remain separate. Do not replace source bytes or present
those masks as complete. Simple isolated REP controls did not reproduce the
broader issue. Full815 native C and public Swift comparisons pass; host zlib1.2.12
differs on53 successful outputs. That milestone changed two marked header
includes. Whole-writer work adds one marked longest_match invocation observer
in deflate.c; the C algorithms/tables and license remain, hashes inupstream.json.
Raw Swift815 passed0.509s/build140.32s; prior5-sample build140.69s passed.
Initial native integration needed Byte/prototypes and zmemcpy observation after
fortified platform headers, not changed compression rules.172oldpins remain
unchanged,173current; fullraw/packedbytes/JSON/SHA/531blobs and10vendor files
verified. Raw35880366/packed32660900bytes. Final packaged3release tests passed
40.353s/build140.28s: compression0.595s and both own notices39.757s. NTSDNative
linked; codec symbols are privately prefixed, no system-zlib dependency.
All source/SwiftPM jobs terminal. This is no app-window or Windows evidence.
Python/654 local Markdown links and owned-file diff checks pass. Vendored
whitespace is unchanged upstream content; do not reformat the pinned sources.
Whole43dd60 is now compared above; NEXT full421cdc result caller.
The codec alone does not execute the writer, an own continuation or a Windows file.

The stream dependency is now implemented in OriginalReplayFileOutput:66 full
construct/write/write/close/destroy sequences match Native at the declared open/
descriptor boundary.1772 writes/6664690 requestedbytes,330 ios states/returns;
2950 actual code-hook PCs,1626MSVCP80+1324CRT. Real C++ and CRT buffering execute,
not stdio stubs. A4096-byte failed flush still retains the triggering byte for
close; failed4096malloc uses unbuffered single-byte writes, NOT a two-byte queue.
Modewb/share40 and C-locale widening/truncation to259 units are original rules.
Openfail states2/6/6/6/6, payloadfail0/0/4/4/4, closefail0/0/0/2/2; combined6.
Actual43dd60 ignores these states; never invent earlyexit or retain freed replay.
Source inputs explicitly bind_osplatform2 and descriptor3's binary/nonappend
64-byte record via781c4820->270e0000. Initial missingplatform and descriptor
backing were corrected before fresh66capture; old expected fixtures unchanged.
PrivateC++/CRT objects/allocations and wholeDLLstartup are NOT native comparisons.
Host heap pressure remains separate from the internal buffer-failure stimulus.
Two acceptedcodec buffers10047/6492672 bytes are supplied without key; no ownjoin.
Initial64Swift0.084s/build133.87s; fresh66acceptance2.293s/build137.55s. Nativeopen
now exposes path/mode/share explicitly. Final packaged4tests42.771s/build138.78s
passed: stream2.427s,codec0.608s,both ownnotices39.736s. NTSDNative linked;
no app-window claim.173oldpins unchanged,174current; fullraw+transportnewline/
packedbytes/JSON/SHA verified,29709098/20460176bytes. Python/664local links/diff
checks pass; all source/SwiftPM jobs terminal.
Whole43dd60 and bounded source failures are now compared above; actualWindowsfiles
remain open. The accepted initialized gameplay boundary is still421cdc/SP1000e9bc.

The preceding [GAMEPLAY_NOTICES](docs/research/GAMEPLAY_NOTICES.md) milestone:
BOTH fresh initialized HUD chains now continue the whole notice caller through
421cdc/SP1000e9bc. Each481245records/806849858bytes+masks/61state/1604FPU;
536/544helpers unchanged. Both complete before/after states reproduce the whole
parent. Own flags are0 without injection;10 actual instructions plus unexecuted
stop, no new helper/event/undefined read. ESIactualsprintf7817775d/EDI0;
CW023f/FPSW4000/tagffff entry and exit, all1603 parent FPU checkpoints preserved.
No access to344bytes of caller-local/cookie backing; Native retains nil and
never imports those source bytes. The public API shares the controlled caller;
a separate native locked-writer trial rejects unavailable backing explicitly.
This does NOT recover that backing's earlier lifetime or make enabled own
string paths complete. Raw2release tests passed40.138s/build141.27s after
retained4tests41.975s/build141.41s. All170oldpins unchanged,172current; independent
fullraw/packedJSON/bytes/SHA and2756/2757blobs verified. Packaged2release tests
passed39.808s/build139.74s without rawoverride. NTSDNative linked; noUIclaim.
Python/653localMarkdownlinks/diff checks passed; both source captures and
allSwiftPM jobs terminal.

Next43dd60 consumes the WHOLE630e18 replay, compresses through43f4b0/43f400
and actual1.1.4 children, modifies only the key-length prefix, writes length
and payload, then frees BOTH buffers and clears4588a8. Do not stub success or
substitute fixture transport deflation. RetainedSP64 has an own semantic producer
OriginalMatchRoundResult.stageDefeated, currently discarded by MenuCycleReference;
audit its intervening stack lifetime and preserve own output. Apparent[esp+64]
at41f12f and421039 are root4c/root5c after pending RNG arguments, NOT this word.
The writer/SP-lifetime findings remain STATIC; codec comparison is described
above and does not prove the whole result caller.

The preceding controlled notice milestone:
Read [POSTHUD_NOTICES](docs/research/POSTHUD_NOTICES.md) first. The controlled
whole caller is implemented in OriginalPostHUDNotices.819 direct source/native
matches,8 explicitly DIFFERING signaling-NaN source cases compared to separately
executed quiet-NaN companions,4 actual cookie-overwrite cases rejected natively.
DO NOT call this827 direct matches. Source and actualVC80 run on the same
controlledCPU; not an initialized own chain or Windows.195/198caller starts,
all46text/all28fill,45/57clip,171/214bitmap;485EXE+1705DLL=2190 original PCs
across831 calls including4overflows. Boundaries/_getptd/stopped421cdc excluded.

All827 compare424408World/Actorbytes+masks,46144globals,340callerlocalbytes+masks
and19802events under the distinct direct/NaN-companion contracts.2061formats,
2375text/GetDC,2167eachfiveGDI/release events,69fills,157draws,1400reads,
290clips,240Blts;4952helperreturns.192undefinedbitmap reads. EDI0 entry;
nonzero450bec reads slot0 eveninactive,14signed then60/48FLDQ/FSTPQ. Eight
signedbytes44d040..47; `%c` lowbyte4553e8 canNUL before remaining sprintf output.
Exit450c2c==1 overrides450c28, decodes28-byte URL with29-byte copy. ExitESI28,
EDIrootSP+489; otherbranchESIactualsprintf/EDI0. Preserve later register consumers.
Allformats useSP48c; URLSP46c; known340-byte local region ends atcookieSP5c0.
This is NOT a recovered C-array size. Real oversized strings overwritecookie;
native explicitly throws and rolls back, never truncates.92fill-effectbytes are
actualhelperentry backing, a declared input after preceding CRT stack writes.
Latebitmapresolver after2texts verifies localrollback; buffer external events.

Unicorn2.1.4 does NOT quiet sNaN on FLDQ/FSTPQ and misses IE/DE status. Preserve
that discrepancy, never change original expected output or native to match it.
IntelSDM Vol1 4.8.3.5/Table4-7 +Vol2A FLD, corroborated by24 x87load/store probes
through explicitly identified Rosetta, support native quiet-bit conversion.
Eight sourceQNaN companions prove remainder composition; Windows/hardware FPU
status is still open. Native here models operand bytes, not processwide flags.
Probe source tools/probe_x87_load_store.c is research-only. Evidence embeds the
24 local observations and8 exact discrepancies, with source/manual hashes.

Rawacceptance3release tests passed1.453s/build137.25s including74424 numeric
comparisons. Earlier compile needed an innertry; first executable test exposed
ambiguous duplicate midpoint labels. Producer labels were clarified and4identical
inputs deduplicated before fresh capture; no oldfixture/expectedresult wasedited.
All169priorfixtures unchanged;170pins inposthud-notices-fixture-pins.json.
Independent fullraw/packedbyte/JSON/SHA checks:7304998/233963bytes. Packaged
verification3release tests passed1.422s/build138.96s. Python compilation,
625local links/diff checks passed. Allsource/SwiftPM jobs terminal beforecommit.
NTSDNative linked; noUIclaim.
Its former own boundary421a2d is superseded by GAMEPLAY_NOTICES above;
do not inject source local bytes simply to make native unknown backing agree.

The preceding numerical dependency and HUD evidence:
Read [WORLD_HUD](docs/research/WORLD_HUD.md),
[GAMEPLAY_HUD](docs/research/GAMEPLAY_HUD.md) and the static
[TICK_TAIL_PLAN](docs/research/TICK_TAIL_PLAN.md).

The first dependency of421a2d..421cdc is now implemented in
[DIAGNOSTIC_NUMBERS](docs/research/DIAGNOSTIC_NUMBERS.md).
OriginalDiagnosticNumber matches74,424 actual VC80 sprintf %2.3f/%2.4f calls,
including the17-digit I10_OUTPUT intermediate/sign/position/finite flag.
Everybinary64 exponent/bothsigns/sevenmantissaboundaries plus decimalmidpoint/
power neighbors and seeded64-bit samples. SourceCW023f/FPSW0/tagffff; separate
CRT CPU and declared C locale/PTD. Its1,568 observedPCs include_getptd78132e29
as a hook;1,567 are original instructions. Do not claim everybinary64 value,
all I10/printf branches, the421a2d caller or an actual Windows run.
Keep upper-convolution80-bit decimal significands, source table adjustment
at+2 without borrow,17-digit rounding THEN fixed rounding, signedzero and
original special text(1.#IO/1.#QNB). Darwin snprintf differs on34,693 finite
and34nonfinite inputs of this corpus. No host printf/CRT DLL in native runtime.
Known rawvarargs signalingNaN behavior is distinct from caller x87quieting;
compound bufferextent is now studied above. The accepted own gameplay boundary
is421cdc in GAMEPLAY_NOTICES; remaining TICK_TAIL_PLAN consumers stay open.

Diagnostic-number verification: releaseNTSDNative52.26s. First test compile
needed@testable import for existing internal fixture unpack; only that import
changed. Raw74,424 outputs/intermediates passed0.361s/build27.97s; packaged
passed0.331s/build137.36s. Numeric implementation and source cases needed no
correction. All168 oldfixture hashes remain unchanged,169 current pins in
build/research/diagnostic-numbers-fixture-pins.json. Independent raw20,331,263/
packed884,564bytes/JSON/SHA/length checks passed. Source/SwiftPM jobs terminal;
Python compilation,1,211local links/diff checks passed. NTSDNative linked;
no app window/device/Windows evidence follows from this numeric dependency.

OriginalWorldHUD implements whole421a15..421a2d caller and41ae60..41b12d/ret4.
All1,753 controlled passes match full400Actor/World bytes+masks,globals and
276,106 events (17,912draw/178,772read/33,856clip/39,462Blt/6,104rectangle).
All223 HUD instruction starts execute; caller6/6,clip45/57,bitmap171/214,
rectangle38/38. This is not every branch outcome or Windows pixel evidence.
The caller clears450bc0/450bb8 BEFORE HUD. Its retainedSP68 word is pushed but
NEVER read by41ae60; actual destination isglobal455608. Eight cells prefer
slots0..<8 then10..<18; shared Object+728 portraits, signed wrapped31*value/125
bars, heal(E0/1000==1||E4>0)&&tick%2==0, and team1..4/default marks. No ID cases.
Preserve real negative-picture43f010 fallthrough and undefined bitmap backing;
HRESULT failure does not stop HUD. Late resolver/observer errors roll back
flags; callers must buffer external events until the whole tick commits.

BOTH own initialized matches continue through421a2d/SP1000e9bc. Each compares
449,269 records/771,514,704 bytes+masks/59 state and1,603 FPU checkpoints;
536/544 helpers and124/180 newHUD events. Source original PCs419/424 exclude
COM30009000 and stopped421a2d. Parent state/FPU is fully reproduced. Both own
before/after states are identical; arbitrarySP68=28002020 is retained but not
imported as a native target. Resource ownership supplies original globals.
Primary wrapper counta5a5a5a5 vs control0f0e0d0c changes negative-picture
fallthrough:20/28Blts and20/52undefined read events. Full bytes/masks agree;
this is supplied research backing, not actual Windows allocation provenance.
Ten newFPU checkpoints(421a15,41ae60,8*41ae70) retainCW023f/FPSW4000/tagffff.

All165 prior fixture hashes are unchanged;168 pins are retained in
build/research/gameplay-hud-fixture-pins.json. Independent
build/research/hud-artifact-verification.json checks3full raw/packed byte
sequences/JSON/SHA plus2,756/2,757 own blobs. Controlled raw/packed:
34,689,334/727,640bytes; own9,283,133/1,282,079 and9,309,179/1,293,927.
The controlled source report initially omittedCW metadata; the producer was
fixed and recaptured, leaving the raw corpus SHA unchanged. Earlier test
compilation needed only an enumerated Zip2Sequence mismatch diagnostic;
no HUD game rule or expected state was changed to make comparisons pass.

Verification: initial own raw2tests39.921s/build0.21s; controlled acceptance
5tests45.951s/build137.16s includes both retained command chains; own acceptance
2tests39.692s/build0.21s. Final packaged5tests46.123s/build137.47s passed,
including own39.731s and controlled6.391s. NTSDNative linked; no app window
was tested. Allsource/SwiftPM jobs terminal; Python compilation,1,200local
Markdown links and diff checks passed. No old fixture was rewritten.

Controlled diagnostic/key-notice prefix421a2d..421cdc and both own continuations
are implemented above. Next result recording/layout and indicators through422994. That address is
NOT an epilogue:41b130/423a70/423940 bitmap-font mode label,4028a0 notice,
43e940present and enabled419e60 queued sound still precede422a95/422ab8ret4.
43dd60 recording writer is also an open dependency. Do not disable sound or
skip an unknown result/label consumer to obtain a convenient full return.
Native app/fulltick/fullmatch/Windows/device/cleanMac and the full goal stay open.

The preceding command milestone (boundary superseded above):
Read [GAMEPLAY_COMMANDS](docs/research/GAMEPLAY_COMMANDS.md) and
[POSTDRAW_COMMANDS](docs/research/POSTDRAW_COMMANDS.md).

OriginalPostDrawCommands implements whole4214d5..421a15. All3,898 controlled
calls match full400-Actor/World bytes and masks, globalsSHA, retainedSP34 and
3,252 events (2,436 RNG,566 constructors,250 resumeMusic). Source checks4,951
helper returns;318/327 caller PCs execute,545 total with helpers. The missing
caller PCs are3 alignment and6 unreachable negative-remainder instructions.
Preserve full-pool retainedSP34 with FOUR coordinate draws before dereference,
source ID122/300 rules, live aliases, distinctE0/E4 overflow and clamping,
state1700 even when dead, and byteEB-only cleanup. Flags450bb8/450bc0 remain
set until421a1c/421a22.402000 resumes via+1c; its HRESULT is ignored.
Atomic failure tests cover the second constructor, second music observer and
missing retained slot. Buffer events until the whole tick commits.
Controlled acceptance:4 tests/3.041s/build88.38s; final packaged:4 tests/
3.051s/build139.21s. Initial test compilation failed on a non-Equatable error
comparison; only its pattern matching changed to fix that test.

BOTH own initialized matches now continue through421a15/SP1000e9bc. Each
compares417,293 records/736,179,550 bytes and masks/503 helpers/57 state and
1,593 FPU checkpoints. The complete parent reproduces. This stage executes49
PCs; its50th observed PC is the unexecuted stop. Both command flags and timers
are0, with cleanup already set: the ENTIRE before/after state is identical.
Naruto/Sasuke17/21 retain frame219/previous219/wait1,HP500/MP200,RNG40/1,
District,mode0/tick1. RawSP34=3724541916 stays unread and untouched; native
keeps nil rather than importing it. The401 new FPU checkpoints are4214d5
plus400 heads4217b0, allCW023f. ExitCW is separately asserted.
Own acceptance:2 tests/39.539s/build134.80s; retained lifecycle:2 tests/
40.448s/build0.10s. Final packaged:2 tests/39.598s/build135.22s passed.
All162 old fixtures are unchanged;165 current pins are in
build/research/gameplay-commands-fixture-pins.json. Independent verification
checks all3 new raw/packed byte sequences, SHA, complete JSON and2,756/2,757
own blobs. Controlled raw/packed:2,776,979/201,611 bytes; own:
9,249,671/1,278,615 and9,265,981/1,289,911 bytes. NTSDNative linked.
All source and SwiftPM jobs are terminal; no app window was tested.

The earlier HUD static plan is superseded by WORLD_HUD/GAMEPLAY_HUD above.
The remaining output/sound/actualret4 boundaries are in TICK_TAIL_PLAN.
Full tick, app, full match, Windows/device/clean-Mac checks and the remaining
full-game goal stay open.

The preceding initialized lifecycle milestone (boundary superseded above):
Read [GAMEPLAY_LIFECYCLE](docs/research/GAMEPLAY_LIFECYCLE.md).
Both fresh original startup/menu/loading/selection/launch/gameplay chains now
continue the ENTIRE post-draw loop and match independently rebuilt native state.
Each385317records/700844396bytes+masks/503helpers/55state checkpoints;1192FPU
checkpoints keep023f. Same first unreturned4246b0,phase1/tick1/mode0,District,
Naruto/Sasuke17/21. Newstage4helpers/2catalog sounds: slot0/X442/index6 and
slot1/X289/index6. Frame219 andHP500/MP200 remain; previousFrame219/wait1;
RNG40/1 unchanged. All14586Frameallocations/854bitmaps/101BG/music/recording
survive. NO source access to six retained scratch words; native leaves them
unknown instead of importing arbitrary caller-stack bytes. Preserve that limit.
Exact404newFPU checkpoints are400loopheads+2scheduler entry/returnpairs. The
terminal hook follows emu_stop and does not fire; source separately reads and
asserts equalentry/exitCW. First native reference expected that nonexistent
checkpoint; corrected its observer contract, not source data/game rules.
Newstage302executed PCs=157loop+90scheduler+55sound;303observed includes the
unexecuted4214d5 boundary. Standalone controlled coverage below stays separate.
Acceptance7release tests86.894s/build132.28s passed before2losslessfixtures;
oldinitialized2tests and5432-case lifecycle3tests remain unchanged.160oldpins
preserved;162current in build/research/gameplay-lifecycle-fixture-pins.json.
Final packaged2tests39.509s/build132.96s passed without rawoverride. Complete
JSON/length/SHA and2758/2759blobs verified; raw/packed9245469/1292643 and
9261999/1304535bytes. NTSDNative linked; Python/591local links/diffchecks passed.
Source and allSwiftPM processes terminal before milestonecommit.
NEXT whole4214d5..421a15 requesteditems/resource commands/healing/cleanup,
then HUD41ae60..41b12d/ret4 and421a2d..422994 diagnostics/results/epilogue.
Static notes: build/research/postdraw-tail-notes.md and*-static-plan.json.
Do not skip command/result branches just because first own flags are zero.
Fulltick/app/fullmatch/Windows/device/cleanMac remain open.

The preceding controlled lifecycle milestone:
Read [POSTDRAW_LIFECYCLE](docs/research/POSTDRAW_LIFECYCLE.md).
OriginalPostDrawLifecycle composes prefix/scheduler/opoint/early lifetime with
weapon fragments, team commands, death/fire effects and live slot advance.
5432 controlled original calls atCW027f match full400Actor/World bytes+masks,
globalsSHA, six retained caller words and25638 ordered events.921 are entire
live-slot loops;4511 start after scheduling. All897 prefix/1991 opoint declared
inputs are freshly continued; old expected after-state is never injected.
6360 constructors/18116 RNG/974 catalog sounds/188 builtin sounds;71283 helper
returns.1885/1892 loop PCs execute: missing3 negative-count adjustment and4
alignment instructions. Helper coverage is separate; allbranches notclaimed.
Weapon/fire lookup misses consume retainedObject+6c/+50; optional nil errors
only at dereference. Fullpool retains values. Death/command lookup miss skips.
Scratch also retains fireSlot+44/deathSlot+5c/weaponSlot+60/particleObject+70;
these are stage-boundary values, not a complete caller-stack model.
New source observer labels nested scheduler sounds by its SAVED callerEDI;
40d960 itself reuses EDI. Pool/masks/globals/scratch already matched at the
old unpublished metadata-only failure; full source rerun verifies correction.
Atomic World/Actors/globals/scratch rollback tested after earlier slot updates
and second constructor; callers buffer effects until whole tick commit.
The own chain now continues through this loop in the study above; no
app/fulltick/fullmatch/Windows claim.
Acceptance9release tests10.454s/build127.58s passed before1lossless fixture;
159old fixtures unchanged,160pins in build/research/postdraw-lifecycle-fixture-pins.json.
Final packaged3tests8.156s/build129.66s passed. IndependentfullJSON/SHA/length
checks verify raw12872805/packed410044bytes. NTSDNative linked; allsource/
SwiftPM jobs terminal beforecommit. The original own state is now connected
above. Read the study for scratch/numeric/Windows limitations.

The preceding opoint milestone:
Read [POSTDRAW_OPOINT](docs/research/POSTDRAW_OPOINT.md).
OriginalPostDrawOpoint now implements whole41fb0b..4203b4 and its EARLY lifetime
paths4213a9..4214c6.1991 controlled original calls atCW027f match full400Actor/
World bytes+masks/globalsSHA,2291 constructors and exact continuation. An
opoint attempt goes420e93 even on pool/catalog miss; no-opoint goes4203b4;
early lifetime goes4214c6. These must not be flattened into one continuation.
Preserved: cachedFrameSP+38 versus currentparent center, ctor aliases, firstfree/
firstID, requested-count extended spread vs actual-count delays, vrest/hold links,
sourceIDs211/223/224/5/52, activityEXACTLY1 ownership lifetime and frame reset.
Native keeps x87 spread intermediate across vz store;53-bit arithmetic and
both4450d0 paths checked. GroundNaN comparison supported, nonfiniteZ arithmetic
explicitlyunsupported. Entirepool rollback after secondconstructor observer
and lateunavailabledepth tested. Caller must buffer events until wholetickcommit.
Static accepted-catalog survey verifies137DAT hashes and2454 opoints, allactions
0..<400 andcounts1..10/35. Allmultiplicities exercised by CONTROLLED cases, not
natural DAT execution.588body/lifetime+151ctor+47conversion PCs; four unexecuted
body PCs are negative-created-count arm/alignment. Full branch/Windows notclaimed.
Acceptance6release tests2.274s/build127.35s passed before1losslessfixture;
158oldfixtures unchanged,159pins in build/research/postdraw-opoint-fixture-pins.json.
Finalpackaged3tests1.573s/build127.12s passed. CompleteJSON/SHA/lengths verified:
raw2452941/packed111787bytes. NTSDNative linked; source/allSwiftPM jobs terminal.
The following milestone above implements4203b4..420e93 weapon creation, then420e93..4213a9.
Historical next step:4203b4..420e93 weapon destruction/creation ALTERNATIVE, then420e93..4213a9
common latecreation/deletion and originalEDI advance. Early deletion above does
not establish other incomingregistercontexts at4213a9. Join entirelive-slot loop
before extending own initialized chain, which STILL ends41f550/SP1000e9bc.

The preceding [POSTDRAW_SLOT_PREFIX](docs/research/POSTDRAW_SLOT_PREFIX.md):
OriginalPostDrawSlotPrefix now implements ONE complete41f550..41fb0b slot
prefix (inactive exit4214c6), including transforms9995/8000..<9000,
state9996 particle constructors/RNG, HP/MP and whole40d960/416fb0 below.
897 controlled original calls atCW027f match full400Actor+World bytes/masks,
wholeglobalsSHA, retainedcallerSP+70 and2334 ordered events. All329 prefix
instructions and151 constructor instructions execute; helper coverage is
separate. Lookup217/218 misses consume retainedSP+70, not a default or skip.
Native carries optional retainedObjectIndex and errors only if unresolved
when actually dereferenced; fullpool skips that read. Aliasedparent/free
construction and lateRNG observer rollback preserve allstate+retainedvalue.
All1491 oldWorldControl/515 oldWorldPhysics original cases/inventories reproduce
after the optional header-input extension. Read the study for source boundaries.
Acceptance6release tests3.160s/build125.38s passed before1lossless fixture;
all157old fixtures unchanged,158pins in
build/research/postdraw-slot-prefix-fixture-pins.json. CompleteJSON/SHA/length
verified independently: raw918456/packed59242bytes. Final packaged3tests passed
in0.712s/build125.61s; NTSDNative linked. All source/SwiftPM jobs terminal.
The next study above implements post-schedule/opoint/earlylifetime. Remaining
weapon/latecreation/deletion must precede EDI advance in original LIVE order.
Do not turn this prefix
into an allActor scheduling pass. Own initialized chain STILL ends41f550,
SP1000e9bc, first unreturned tick; this new prefix is not yet connected to it.
Fulltick/app/fullmatch/Windows/device/cleanMac remain open.

The preceding [ACTOR_SCHEDULER](docs/research/ACTOR_SCHEDULER.md) study:
Whole40d960..40de20 is now implemented generically in OriginalActorScheduler,
including actual416fb0 catalog sound behavior.6084 controlled original calls
atCW027f match allActor bytes/masks, whole globalsSHA and756 ordered sounds.
All316scheduler/58sound instructions execute; this does NOT prove allbranches
or naturalDAT sequences. Preserved: signed counters/byte, type3HP, state0/2000,
state14death/recovery, wrappednext/facing/999, invalidnext earlyreturn retaining
oldpreviousFrame, jump load/sign/store, negativeMP and same-call hit_d redirects.
SourceID30..<40 except38 is the original mode/category exception. Nocharacterlist.
Public API takes OriginalLoadedObject; atomicActor/globals rollback tested after
first sound+lateFrame failure and second soundobserver failure. Buffer observers
until wholetickcommit. NoFPU arithmetic here; finite/Inf/signedzero/subnormal
stores and quietNaN comparison tested, headerNaNload/store payloads unsupported.
Acceptance3release tests2.481s/build123.29s passed before1losslessfixture;
156old hashes unchanged,157currentpins in build/research/actor-scheduler-fixture-pins.json.
Final packaged3tests2.460s/build124.29s passed. Raw30,408,268/packed338,300 bytes
and completeJSON/SHA independently verified; source/allSwiftPM jobs terminal.
NTSDNative linked; no UI/device/Windows claim. Read the study before integration.
The enclosing prefix has since been recovered above; next finish
post-schedule/opoint/deletion in ORIGINAL live-slot order. Do not split scheduler
into an allActor pass or skip unsupported surrounding branches. First own
initialized tick still ends41f550/SP1000e9bc; app/fullmatch/Windows remain open.

The preceding [CATALOG_PRECISION](docs/research/CATALOG_PRECISION.md) study:
The numerical correction below now reaches original DAT parsing. A fresh whole
catalog with explicitCW027f on BOTH EXE and separate scanner CPUs reproduces the
entire95,289,959-byte historical raw capture byte-for-byte, including919,912
actualCRT scans. All863 actual%lf calls (43files/17callers) agree in53-bit,
unwritten and explicit64-bit controls on bytes/return/consumption/EOF/errno.
Native independently rebuilds all137Objects/17BG/25stages/15388Frameoccurrences,
829bitmaps/14586Frameallocations:112,063,739 bytes with masks, checksum31475378.
Native also compares all863full-file suffix scans; no runtime formula changed.
Acceptance2release tests11.501s/build122.80s passed before2losslessfixtures;
all154old hashes unchanged,156currentpins in
build/research/catalog-precision-fixture-pins.json. The scanner is STILL a
separate VM: this resolves its actualDAT outputs under explicit53, not full
same-threadCRT/Windows binding/generaldecimal parsing. Initialized own chain
still stops41f550/SP1000e9bc in its first unreturnedtick. Preserve explicit53
match precision, historical fixture contracts and raw byte/mask provenance.
The whole40d960 has since been implemented separately; integrate it with
recovery/spawn/deletion per original slot order, as described above.
Final packaged6release tests23.811s/build125.47s passed, including all3retained
catalog variants and originalintegerCRT. New envelopes/fullJSON/all3409blobs
independently verified. Source and bothSwiftPM jobs terminal, NTSDNative linked;
no UI/device/Windows claim. Appintegration/completeNaruto-SasukeDistrictmatch/
AI/allmodes/Windows/device/cleanMac and the full goal remain open.

Numerical correction history (its intermediate NEXT entries are superseded by
the current priority above): [FPU_PRECISION](docs/research/FPU_PRECISION.md).
New original-instruction evidence: EXE startup445a31 calls actual MSVCR80
_controlfp_s(NULL,10000,30000), selecting53-bit precision. Historical arithmetic
corpora explicitly used CW037f/64-bit; own menu/loading chains inherit CW0.
Sixteen midpoint inputs produce32 differing stores between startup53 and64.
Recover FPU provenance and correct/revalidate native arithmetic before expanding
the full tick. Preserve historical declared contracts; do not rewrite expected
fixtures or use tolerances to hide differences. Precision53 still has x87's
extended exponent range, so replacing OriginalExtended with Double is not enough.

The first [arithmetic correction](docs/research/ARITHMETIC_PRECISION.md) now adds
explicit24/53/64-bit precision and compares54,201 original arithmetic sequences,
55,433 whole Actor-physics calls at53 bits and3,090 whole impulse pools at three
precisions. All match exactly;53-bit results differ from historical64 in168
physics controls and22 impulse pools. Context is carried by match state to
physics/hits/links/impulses, but hits/links have only their old64-bit regression
here. Historical defaults remain64; own source chains still inheritCW0. NEXT:
initialize a NEW own chain with actual445a31/CRT and revalidate its independent
native state, then audit remaining direct arithmetic/conversions and whole
consumers. No full startup, Windows, app integration or full tick claim.

The new [initialized own chain](docs/research/INITIALIZED_GAMEPLAY.md) now
executes actual445a31/CRT BEFORE World construction, retaining one CPU through
41f550. Both backing variants reproduce all historical game-state parents;
170 initializer PCs, CW037f->023f at7814b118,788 FPU checkpoints each and no
further watched FPU-control instruction. New native comparisons start match state with explicit
53-bit precision. Separate whole World physics515/links3018/hits7845 cases also
match at53 bits; three existing hit controls change the branch at42f1e7 and
Actor pendingY, not merely low mantissa bits. See the new study for boundaries:
initial CW/outer ABI/PTD/device responses remain supplied, full Windows startup
is unverified, and the first tick has not returned. NEXT audit direct arithmetic
and conversions (especially ActorControl), then resume40d960 and the interleaved
41f550..4214cf loop under the declared initialized context. Preserve old fixtures.

The [control arithmetic audit](docs/research/CONTROL_PRECISION.md) now carries
match precision through World/Actor control. All13 arithmetic PCs use explicit
rounding and separate binary64 stores; finite arithmetic can overflow on store
and the same-call frame dvy addition must preserve that signed infinity.
32,662 historical Actor/catalog/World cases reproduce in fresh original runs
and match at explicit53 bits. New27,708 Actor/36 aliased World cases compare
24/53/64-bit arithmetic, including24 Actor/12 World changes at53 vs64. NoID list.
New harness finding: an UNWRITTEN Unicorn FPCW reports0 but differs from explicitly
writing0 on ordinary run division. Do not infer24-bit semantics from the reported
word alone. Old fpu audit's `inherited-zero` actually explicitly writes0; retain
its numbers under that exact contract. Initialized own chains write037f and run
actualCRT to023f, so are unaffected by this ambiguity. Historical fixtures stay
unchanged. NEXT dedicated legacy/SSE2 conversion and remaining-consumer audit
(camera/CRT parsing), then whole40d960/postdraw41f550..4214cf. See the study's
inventory; exact33-bit integer-derived sums at53/64 are not whole-game24-bit
support. Native app integration/fulltick/Windows/device/cleanMac remain open.
Acceptance5release tests30.785s/build122.61s passed before5lossless fixtures;
all147 old hashes unchanged,152 current pins in
build/research/control-precision-fixture-pins.json. Final packed12tests89.060s/
build123.96s passed, including retained controls/rollback and both initialized
own chains (each353341records/665509242bytes+masks/499helpers/53state/788FPU
checkpoints, same41f550). All source/Swift jobs terminal; NTSDNative linked,
no app-window/Windows/device claim. Read CONTROL_PRECISION before extending.

The [coordinate audit](docs/research/COORDINATE_PRECISION.md) now compares63,006
whole4450d0/445106 conversions after original arithmetic at24/53/64 bits, both
legacy/SSE2. All47 entry-path instructions execute; native already matches, no
formula changed.41 inputs change legacyEAX at53vs64; directDouble loads and
retained extended values are checked separately. Whole camera/background4742
cases also match at explicit53, retaining all old case records/1133PCs/6898events.
IMPORTANT newly verified boundary: MenuLoading's catalog EXE shares the initialized
gameCPU, but Objects creates a SEPARATE CRT() for non-decoder fscanf. It reports
unwrittenCW0; the main/attached-settingsCPU has023f. Fresh original early menus
plus observer attachment verify these CPU identities at41bc90. The initialized
own-chain FPU checkpoints do NOT establish the catalog scanner's precision.
No changed DAT result is claimed by that ownership probe. NEXT verify original
catalog DAT numeric scans at explicit53 and independently loaded native bytes;
retain old scanner boundary evidence. Then whole40d960/postdraw41f550..4214cf.
GeneralCRT lexer/rounding, actual thread/CPUflag45971c, fulltick/app/Windows and
cleanMac remain open. Read COORDINATE_PRECISION for reproduction and limits.
Acceptance2release tests5.469s/build122.55s passed before2lossless fixtures;
all152old hashes unchanged,154current pins in
build/research/coordinate-precision-fixture-pins.json. Final packaged3tests
10.523s/build123.30s passed, including retained64-bit camera. Native runtime
unchanged; all source/probe/Swift jobs terminal; no app/Windows/device claim.

## Authoritative reference

- Use **only the original Windows NTSD distribution** as the behavioral reference.
- Baseline: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a`.
- Baseline EXE SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
- The user rejected the previous JavaScript implementation. Do not copy its
  behavior, or use F.LF/another LF2 reimplementation as a source of engine rules.
- Never modify the baseline assets to accommodate an incomplete new engine.

## Fidelity and evidence

- Recover behavior from this EXE and/or observations of this EXE running on Windows.
- Record the EXE hash and instruction addresses or a reproducible reference
  capture for each recovered rule. Distinguish a static observation, an inference,
  and behavior verified by differential tests.
- Do not substitute guessed physics, combo timing, damage, AI, randomness, or
  standard game-engine physics. Unrecovered behavior remains explicitly incomplete.
- Preserve raw numeric literals, repeated frame definitions, and auxiliary hitboxes.
  Original parser behavior (including overflow and repeated fields) is part of compatibility.
- A native resource inspector is development tooling, not a playable port.
- Keep reference/test tooling separate from the shipping runtime. No Windows EXE,
  JavaScript engine, or emulation/compatibility layer in the final native game.

## Research sequence

Use [docs/RESEARCH_MAP.md](docs/RESEARCH_MAP.md) as the working queue. Address
seeds and their evidence limits are in
[docs/research/ADDRESS_BOOK.md](docs/research/ADDRESS_BOOK.md).
R01.1 established the ordinary dispatch/match boundary and the gap map:
[docs/research/TICK_PIPELINE.md](docs/research/TICK_PIPELINE.md),
[docs/research/TICK_GAPS.md](docs/research/TICK_GAPS.md).
The active task is [R02.1](docs/research/R02.1.md): recover complete state,
types and initialization. Its partial result is [STATE_LAYOUT.md](docs/research/STATE_LAYOUT.md).
Actor/World constructor bytes and defined masks match native storage in 16 cases;
raw snapshots retain all Actor/Object/globals and mapped catalog/heap regions in
the six R01.1 fixtures. Full initialization provenance, pointer normalization,
and remaining types are still open. Native OriginalStateRecord is not
yet wired into practice; its constructors are not match/spawn defaults.
The [bootstrap study](docs/research/BOOTSTRAP.md) now verifies the full loading-time
400-slot pool plus reconstruction/activation of slots 0..7 against native Swift.
Those eight use catalog entry zero and are not the selected players' match spawn.
Known pointers normalize to non-null registry/slot ordinals; do not treat ordinal
zero as null or normalize arbitrary opaque words. Reconstructing an Actor must
preserve the initialization mask of untouched fields. The
[catalog parent](docs/research/CATALOG_REGISTRY.md) now matches native registry
requests and parent-owned bytes/masks for all source entries and bounded probes.
That older corpus keeps Object/BG/Stage/bitmap children as opaque boundaries; its
parent checksum excludes child contributions. The joined study below now executes
real children. Registry ordinals are not source IDs and duplicate IDs remain separate. The separate
[Object loader](docs/research/OBJECT_LOADER.md) now executes 40ef70/4148a0/43ee50
and matches native decoding/header/frame/bitmap behavior for Naruto, Sasuke,
kunai and a control stream. Read that document before extending this loader.
Its shared Frame parser consumes a continuous stream: kunai frame 49 is swallowed
by frame 48's unclosed itr. Do not repair the DAT or restore an artificial boundary.
General MSVCR80 rounding/file translation remain open: the old decoder used raw stdio; the new
corpus retains both raw/text contracts and their different tails/checksums.
Object header bitmap/string references use index+1 with zero null, unlike the bootstrap's
non-null ordinals. Frame references now remain explicit 32-bit arena addresses,
supplied at the allocator boundary for raw comparison; never normalize partially
overwritten pointers. Full Frame bytes/masks and live/dead Frame malloc records
are compared by the newer raw suite described below. The new
loader is not wired to practice; its parent composition is described below. The separate
[Background loader](docs/research/BACKGROUND_LOADER.md) now matches all 17 source
arenas through metadata parse 40c160, layer allocation 40c030 and release 40c0e0.
It preserves all BG/bitmap bytes and masks, delayed layer loading, rect conversion,
name truncation, and the first-pointer release sentinel with stale remaining refs.
Its references use index+1/zero-null like Object, not the bootstrap ordinal scheme.
Read that document before extending arena loading; pixels, menu-driven selection
and true CRT/device behavior remain open. Source ID is unused in BG 40c160;
ordinal chooses the record. A numeric conversion at EOF must set scanner EOF even
when it assigns nothing. Native bitmap records are shared by the two loaders.
The [Stage loader](docs/research/STAGE_LOADER.md) now executes 40c910/414a30 and
matches all 25 original stages / 138 phases, plus repeat/order/100-phase controls.
It keeps all 60 records (0x149b08 each) and byte provenance: only count=-1 is set
for absent stages, and repeated initialization preserves old untouched masks.
Read that document before extending Stage. bound rewrites all 60 x values;
boss/soldier and parameter order matter; pre-id fields overlap the music area.
Stage contributes no checksum and its fields must not be pointer-normalized.
Its full-record evidence uses lossless DEFLATE only in development reference code.
Stage gameplay, Windows startup and selected-match initialization remain
open. The [CRT scanner study](docs/research/CRT_SCANNER.md) now executes the pinned
MSVCR80 8.0.50727.6195 from the repository's original redistributable. Its publisher
policy includes the EXE's requested .762; actual Windows assembly binding remains
unverified. Native %d/%ld wraps at 32 bits and consumes a failed optional sign;
5364 cases / 16092 DLL executions include all 867 source integer tokens, 39 outside
Int32. Pein/Naruto/Sasuke and a numeric control also match with actual DLL scanf
(817 occurrences, 216480 header/bitmap bytes/masks). %lf matches those whole-file
inputs only; its general lexer/rounding, especially incomplete exponents, is open.
The [raw Frame study](docs/research/RAW_FRAME_STORAGE.md) now compares ALL 137
source Objects in order natively: 15388 occurrences, 808 bitmaps, 400 sounds,
checksum 30847120. Complete Frame bytes/masks at every occurrence and EOF plus
live/dead Frame allocations match with externally supplied malloc addresses.
Including two controls: 71006 raw Frame observations, 14598 allocations,
37036545 compared bytes/masks. Frame constructor writes 325/376 bytes; keep
padding, names and unused array pointers/slots untouched. A repeated name writes
only itself plus NUL, can overlap sound pointer/index, and later sound writes can
change the readable name. Preserve opaque pointers; never dereference them as
host memory or silently replace with null. Native names are bounded at 27 bytes
within one Frame, covering all source names (max 25); crossing records is open.
The tenth sheet is now supported and compared; its last bitmap pointer ends at
Object+7a4. Frame data storage is shared by the existing parser, not a second set
of per-character rules. This raw-Frame study alone is not full gameplay equivalence.
The [joined catalog](docs/research/LOADED_CATALOG.md) now executes 4122f0 with real
Object/BG/Stage/bitmap/sound children in one VM, with actual VC80 scanf outside
decoder %c. Native OriginalLoadedCatalog composes the existing loaders through
OriginalCatalogRegistry.onLoad and shared OriginalLoaderResources. Two whole
source passes (text/a5 and raw/00) plus interleaved/repeated-ID control match
all Catalog/Object/bitmap/Frame-allocation bytes and masks. Each whole pass:
137 Object, 17 BG, 25 Stage/138 phases, 15388 Frame occurrences, 829 bitmaps,
14586 Frame allocations. Checksum text=31475378, raw=31461560, both 400 sounds.
The parent-only parentChecksum still excludes children; checksum includes them.
All 101 BG and 60 Stage are retained, including untouched regions. In the joined
backgrounds array, the four known BG99 pointers explicitly convert to index+1 /
zero-null; registry.records retains old non-null ordinals. Never infer nullness
without knowing the representation. Frame pointers remain raw supplied addresses.
The four embedded bitmap keys resolve to PE DIB dimensions at the device boundary;
they are not filesystem paths. Layers remain delayed. Stage contributes zero CRC.
The joined capture compares final whole Object/Stage storage; per-occurrence Frame
and per-phase Stage byte comparisons remain in their earlier standalone corpora.
No Windows startup, pixels, sound output, selected match or full tick is proved.
The catalog is now connected with World/400 Actor and the
[common match preparation](docs/research/MATCH_PREPARATION.md), 42d1ff..42d6ed.
Read that study before extending this state. OriginalMatchPreparation uses the
real loaded catalog, bootstrap and shared bitmap resources. Two chained corpora
(a5/ramp Actor/World backing) compare 50 scenarios / 52102 records / 79596336
bytes and masks, 19324 preparation constructors, 720 RNG calls, 796 new bitmap
records and 766 releases. Both include all 137 source Object bindings (controlled
menu inputs, not UI-selectable roster), all 17 arenas, Naruto/Sasuke District,
restart, Stage, BG99, status limits and RNG wrap. No per-character handlers.
Status 1..10 targets base slot, >10 targets seat+10; <=0 skips reconstruction.
Clear only activity 10..399, preserve the first ten input flags; do not guess
menu deactivation. Team=0 becomes slot+10 only when active. Random BG uses
count-2, result count-3 becomes99. Stage overrides x after the earlier RNG calls.
Only inactive slots 20..399 are reconstructed at the end; input reset 431c70
sets its 300-byte buffer to 0x75. BG release/load retains original stale pointers.
The reference restores the pinned complete catalog capture; native comparison
rebuilds and validates it before continuing through bootstrap/preparation.
Actual PE/BSS globals plus menu/RNG stimuli and disabled music remain supplied
boundaries. Do not call this whole menu startup or full match equivalence.
The [recording initialization](docs/research/REPLAY_INITIALIZATION.md) now follows
that preparation through the real menu call 42d6fc, all of 43d2c0..43db38, and
caller cleanup to 42d704. Read this study before extending replay/startup. Native
OriginalReplayRecording matches 50 complete calloc buffers (0x630e18 each),
324583600 bytes/masks, 50 allocations/50 frees; the linked preparation adds
77252 state records / 115486336 bytes/masks. Two 25-case chains retain full catalog
and bootstrap, metadata stimuli, all source bindings/arenas, restarts and control
byte patterns. Replay init copies ALL first 18 slots, including inactive ones,
as 13 arrays of 18 dwords. Object+6f4 exports the source ID, never registry ordinal.
Activity sign-extends Int8; strings copy through NUL (11-byte name stride is not
a length limit). RNG copies index and exactly 3001 table bytes, then RESETS
450c34 to 0, as well as 450bd0/4/8. The snapshot at 42d6ed is therefore not the final
RNG state before gameplay. The replay buffer has no pointer normalization;
recording ownership maps an optional native buffer/generation to 4588a8 only.
43d280 clears the recording pointer on free and leaves recording flags unchanged.
The neighbor 4588ac remains 0 in this corpus; playback/file IO/tick recording and
network remain open. Original calloc/free and metadata are supplied boundaries.
The old preparation fixtures retain their earlier stop and are not rewritten.
The [confirmed-menu prelude](docs/research/MATCH_PRELUDE.md) now executes
42cf8a..42d1ff before common preparation and recording in 50 chained cases.
Native OriginalMatchPrelude matches 4614400 global bytes/masks, filenames and
event order; actual pinned VC80 sprintf executes 130 times, sound methods 60,
fill methods 10. Linked preparation compares 77300 records / 115871104 bytes/masks,
recording 50 full buffers / 324583600 bytes/masks and 50 allocations/frees.
Actual caller 4229d0/4229d5 binds mode 451160 and menu-state 44d020; World+0 is
separate. Stage changes arena only for exact 0/10/20/30/40/50, and its name uses
signed stage/10 toward zero. Year uses SPACE-padded %4d; widths are minimums.
Native device handles are explicit opaque supplied values, never host pointers.
Real 401a30/415160 helpers execute up to COM boundaries; all three sound calls
continue even on failing HRESULT. Disabled/null sound and clear branches match;
device output, resource loading provenance and enabled music remain open.
44eecc is an audio-device pointer (S: 401970/4019b0), not a Boolean preference;
the prelude only checks nullness. Sound 455610 is statically loaded from
data/m_ok.wav at 43d0c4..43d0ce; that loader is not executed in this corpus.
Read that study before extending startup. Existing preparation/replay fixtures
are unchanged. The new optional beforePreparation callback applies native prelude
after supplied stimuli, never copying an expected state into the native model.
The [menu continuation](docs/research/MATCH_CONTINUATION.md) now executes
42d704..42e0f9 through real ret12/SEH/cookie after reproducing the pinned parent
chain. Native continueMenu matches 222 returns, 225298 records / 327834160 bytes
and masks, 1998 RNG calls, 544 constructors, 960 new bitmaps. Both a5/ramp corpora
include all 30 team-pattern results, commands 1..5, no-confirmation controls,
integer boundaries, nullable sound devices/buffers and success/failing HRESULTs.
The shared candidate rule scans ordinals 1..<count, type 0, signed source ID<30,
excluding all eight selected ordinals, rebuilt after each seat. Command 1 clears
selection only for flag==1; command 2 rerolls for any nonzero flag. Empty candidate
lists require prior stack-scratch provenance and remain outside native domain.
450c2c==1 runs even without confirmation, clears all 400 activity bytes, selects
BG/roster and reconstructs only 10..17. It does not reconstruct inactive 20..399,
copy base teams, create a replay or reset the RNG counter. Read the study before
extending this path. Sound confirmation and 431c70 input reset are shared with
earlier native paths. New bitmap addresses use a separate supplied arena 26000020;
The loaded source resources and new continuation resource bytes/guards remain
verified. The parent replay
cleanup is a research operation, not an inserted startup action. No Windows output.
The [RNG initialization](docs/research/RANDOM_INITIALIZATION.md) now executes
actual VC80 _initptd/srand/rand, bounded startup43cf40..43cf63 and both real
menu call sites427a2c/427a71 through the complete422ac0 return. Native
OriginalCRTRandom retains a separate UInt32 PTD state (initial1); table rebuild
draws3000, writes rand()%255+1 and tail450b48=0, preserving450bcc/450c34.
Seed prefix also writes458420=0. Read the study before extending RNG/startup.
Two25-case chains start from PE/BSS, never replay_random; native-generated tables
feed the verified prelude/preparation/replay path. 50tables,40seeds,150000table
and26178intervening actual DLL draws match results/state,4614400globalbytes/masks;
linked preparation77124records/114460288bytes/masks,242gameRNGcalls, recording
50fullbuffers/324583600bytes/masks. Timer/thread/menu/metadata/device inputs
remain supplied. Additional CRT draws are explicit controls, not a recovered
trace of intervening gameplay. Same-thread state must survive these consumers.
The default Python initialization boundary and optional before_prelude hook
preserve historical corpora; --check-parent reproduces the old prelude without
rewriting it. Native reference beforePrelude runs after recorded stimuli and
before applying the existing prelude; expected table bytes are never inputs.
Other rand consumers414774/431a42/431a86 remain S; thread them through instead
of assuming none. Next recover earlier menu decisions/input and complete CRT
lifetime before42cf8a, then connect toR01.2. This is not full startup or Practice.
The [main-menu study](docs/research/MAIN_MENU.md) now executes all five rows
427915..427ca7 to shared presentation/epilogue entries, including real
402b60/402ad0/402a60 network setup and WndProc43b3d0 mouse200..205 throughret16.
Read it before extending menus/input/network. Native OriginalMainMenu receives
typed OS results and emits ordered boundary requests; it performs no network IO.
1020probes/450mouse messages,139759680bytes/masks,4150events,250menu-generated
tables,46actual CRT sprintf calls and14network-error exits match Swift, followed
by50full preparation/recording chains. Old fixtures remain unchanged.
Mouse coordinates are unsigned16-bit words, button messages change flags only;
203 does not change game state, 204/205 set/clear4527e4. DefWindowProc result is
forwarded. EBX/EBP/ESI/EDI and ret16 stack are verified with explicit OS result.
Row2 rebuilds RNG BEFORE highlight/confirmation even when not clicked; row1
only after44d060==0/457580==1. Rows1/2 clear457580 before sound;3/4/5 preserve it.
Row1 setsWorld+0=1 and450b4c..58=1..4. Row3/4 set44d064=6/7; row5 requests
Sleep300 then ShellExecute open littlefighter.com (ignored result), not exit.
Network: startup return ignored, wVersion==0101 required; hostname only-1 fails.
Address selection rejects raw prefixes10./192.168/169.254/127, first nonrejected,
otherwise first. Do not use a modern IP classifier. Preserve htons(0) calls,
source ports5000/12345, sockaddr padding, opaque pointers and socket tokens.
AsyncSelect nonzero fails without closing; bind/listen only-1 fail, close result
ignored and global socket not cleared. All failure paths and nonstandard results
are explicit corpus controls, not Windows network execution. Real IPv4 controls
use matching address bytes/text; malformed prefix probes are marked non-OS.
Bitmap43f010 is an explicit request boundary; no renderer/pixel claim. Panel
423b00 executes only null/first-word0 paths; enabled panel is unsupported.
Next recover shared presentation tail42873e..428805, especially44d060=457580,
earlier screen/offset/resource setup, and the World+0=1 transition. Stack contexts
between4246b0 and429730 remain supplied; the intervening path is not executed.
This foundation is not wired to Practice. Windows output/network/latency stay open.
The new corpus retainsWorld+0=1 after row1 through recording; it is NOT a final
match-tick initial state. S: next dispatcher branch424701..424736 calls423910,
draws, writesWorld+0=2 at42471d, then4028a0/43e940. Recover that real transition.
The [presentation study](docs/research/MENU_PRESENTATION.md) now closes that
bounded gap in NEW corpora: real42873e..428805/ret4 plus the whole4246b0
World1 branch, including423910/43ef50, overlay/volume/text/present/shutdown
helpers to explicit COM/GDI/free/PostMessage boundaries. Native comparison:
1482 returns,66 World1-to-2 transitions,177955008 bytes/masks,5382 events,
184 actual CRT formats,8 frees,12 quit requests; then50 complete preparation/
recording chains. Read this study before extending presentation or shutdown.
World2 now comes from the native dispatcher branch before preparation, not
from a new supplied selector. The earlier main-menu fixture still endsWorld1.
Shared tail clamps cursor only above775/535 (y+2 wraps), presents, then writes
44d060=457580 even after failed PostMessage. Network errors skip the tail.
World1 releases only4511ac, draws45118c, writesWorld2, overlays/presents and
returns; it does NOT execute the cursor/latch tail. Real prologue/epilogue,
SEH/cookie and nonvolatile registers are checked; earlier screen selection
and the intervening context to429730 remain supplied, not a whole menu loop.
Volume:4553f3==64 wins over4553f2==64; wrap add then clamp0..100. Music uses
34*v-3900 (zero=-10000) after successful query/get, releases queried interface
on get failure too; five45560c..45561c buffers use ((v-100)*3800)/100 instead.
Notice3 increments450b6c twice when not blocked, once even with450bfc!=0.
GetDC failure skips GDI/ReleaseDC but not timers. GDI order is SetBkColor0,
SetTextColorCOLORREF, lstrlenA, TextOutA(3,531), ReleaseDC. No pixel/audio claim.
Shutdown releases both sound lists only when44eecc non-null, clears only that
device pointer, then44f04c/48/44/40, both4588a8/ac slots, then PostMessage10.
OriginalMenuPresentationMemory is an explicit allocator/ownership adapter;
opaque menu bitmap/replay-free controls do not invent loaded pixels or real
recording contents. Parent full replay buffers remain separately verified.
Core and reference callbacks compose the same native state, not expected
snapshots. Older fixtures are unchanged. Next recover screen/offset/resources
and the World2/41bc90 menu path to429730, then R01.2 with full provenance.
This remains separate from Practice and does not prove full startup or W.
The [WAV loading study](docs/research/WAVE_LOADING.md) now executes4014e0 for
all409 original WAVs and22 controls, plus the real initial-sound caller
41be98..41bfeb in3 passes/54 child calls. Native OriginalWaveLoader and
OriginalInitialSoundLoading match75829038 bytes/masks,6982 ordered events,
93 restores,13 messages,2 retained short-read allocations and2 explicit invalid
create continuations. Read it before extending sound or first loading.
MMIO/COM/allocator outputs are supplied boundaries, not Windows DLL execution.
Format read requests18 even for the100 fmt16 files. Descend-format flags0
means next chunk, not a fmt search. WAVEFORMATEX cbSize overlaps saved this:
copy low16(destination), never zero it or treat it as unknown padding.
Any nonzero CreateSoundBuffer result frees payload then falls through toward
Lock; the recovered domain stops at40187a, not a fabricated return0/1.
Data short reads leak the payload; final Lock/Restore/Unlock results are ignored.
Only88780096 triggers Restore and one retry. Source PCM bytes stay unchanged.
The initial caller draws45118c, clears1600 bytes457588 and320 bytes453e10,
loads18 fixed paths into451db0+4*i, writes45843c=18 and presents through the
same43e940 native method as menus. No device preserves old slots; ordinary
file failures leave slot0 and do not stop the caller. Global state after every
real child ret4, full records/masks and ABI are compared. Entry context remains
supplied, and41bfeb leaves the present argument on the stack for later cleanup.
Crucially44d05c is still1 in the earlier presentation/preparation/replay corpus.
Do not clear it by hand to enter a full tick. First41bc90 must load18 sounds,
catalog,400 Actors and10 UI bitmaps before41c577 clears it. Next recover those
10 bitmap allocations/constructors41c2f5..41c55e (now recovered below) and join
the whole loading path.
The existing full catalog uses disabled audio; connect enabled Object-registry
sound calls410a48/410a65 to this shared loader in a subsequent joined corpus.
This stage adds no playable coverage, mixer, Windows output or clean-macOS proof.
The [initial interface study](docs/research/INITIAL_INTERFACE.md) now extends
the real400-slot bootstrap through41c2f5..41c581 and all43ee50 constructors.
Read it before extending bitmap lifecycle or first loading.13 passes match
114 bitmap/5304 Actor constructors,5470 records/13029720 bytes/masks,519 events,
16 null allocations,23 messages and12 surface releases. Ten original embedded
DIBs are pinned, including dimensions;43ed10 itself remains a device boundary.
The fixed keys are PAUSE,DEMO,SCORE_BOARD1..4,WIN_ALIVE,WIN_DEAD,LOSE_DEAD,BARS.
Each malloc requests1f50. Null skips constructor and stores0; device failure
still returns a wrapper. All10 global stores precede the unconditional44d05c=0
at41c577, including failure controls. Previous global pointers are not released.
Native OriginalBitmapConstructor shares constructionStorage with Object/BG.
SetColorKey(+74,flags8,two zero dwords) tests SIGNED HRESULT: positives succeed,
negatives request message/debug,Release(+8),then clear only surface+0. Width/
height stay defined. Missing required surface requests message/debug and leaves
dimensions untouched. Source input.present is43ed10 availability, not current
surface liveness after a key failure; inspect storage+0. Surface pointer alone
normalizes1/0; wrapper pointers stay explicit supplied allocator tokens.
Full globals after every store and flag clear, all wrappers/masks and the whole
unchanged Actor/World pool match Swift. Real ret12/cookie/register preservation
is verified. The enclosing function has not returned; at41c581 ESP is the
supplied1000f000 and EDI comes from local+38. The parent catalog[0]/Object+90
and outer frame are supplied, not a complete loading path. Next connect enabled
Object sound registry410a48/410a65 to the WAV helper, then join18 common sounds,
full catalog,bootstrap and UI in41bc90 before input/menu/429730 andR01.2.
Historical fixtures are unchanged. Practice and full Windows/macOS checks remain open.
The [catalog sound study](docs/research/CATALOG_SOUNDS.md) now joins enabled
Frame/weapon sound registration with real4014e0 in the same full4122f0 CPU and
caller stack. Read it before extending the audio registry or first loading.
Full source:137 Objects/15388 occurrences,400 WAV loads from365 source files
(386 frame,14 weapon),66210142 audio bytes/masks plus112063739 catalog bytes/
masks,6426 audio events/80 Restore. Interleaved/repeated Pein:29 loads from28
files,4157380 audio plus82089953 catalog bytes/masks,466 events/6 Restore.
Native callbacks flow through existing Frame/Object/LoadedCatalog parsers;
OriginalRegisteredSoundLoading owns results indexed by the same byte cache.
Assignment occurs before WAV/SetVolume; path copy/count increment occur after.
Hits do not reload or reset volume. Weapon no-hit with previous index!=-1 keeps
that index and skips registration; do not turn it into unconditional new audio.
Both callers SetVolume(+3c,-10000) and ignore HRESULT; the corpus supplies-1.
The20-byte cache stride is not a string size limit:21-byte SNDDATA paths overlap
the next slot. Preserve400 buffers, not365 deduplicated paths. Before-cache,
source/kind/Object path, all WAV bytes/masks/events, real ret4/ABI and final
buffer tokens are compared while the full catalog is rebuilt/checked natively.
The WAV adapter now optionally attaches to an existing VM with disjoint stubs
and temporary hooks. Its historical431 cases/3 startup passes/ALL blobs were
re-executed identically; old fixtures remain unchanged. MMIO/COM/allocator/file
boundaries persist; no mixer/Windows output claim. S: null output is dereferenced
by caller410a5a/40be2a even after return0. Native rejects that invalid continuation;
full caller fault traces remain open. Next join18 common sounds, this enabled
catalog,400-slot bootstrap and10 UI bitmaps in the real initial41bc90, then
input/pause/menu429730 andR01.2. Practice and full Windows/macOS checks stay open.
The [continuous first loading](docs/research/INITIAL_LOADING.md) now executes
real41bc90..41c581 without replacing CPU/stack/state between common WAVs,
enabled full catalog,400 Actors and10 UI constructors. Read it before extending
first loading or the next input/menu path. Two full-source passes (a5 and ramp/
reversed Actor allocation with phase0/pause/present3) match362760002 bytes/masks,
36 common/800 registry WAVs,816 Actor/20 UI constructors. Actual41c577 clears
44d05c; local pause is restored into EDI. World selector2/device/clock remain
supplied boundaries, not whole startup. Sound cache455638..458438 includes
other globals457578/458348: preserve its existing bytes. OriginalLoadedCatalog
now accepts initialSoundBytes; do not restore a zero-only cache in first loading.
OriginalWorldBootstrap can continue an already constructed World. Its first
word90 comes from actual native catalog.objects[0], never a synthetic header.
Loading progress occurs before EACH BMP field read, plus three times per sheet;
40fd23 returns to40f1d8. Shared Object callbacks preserve these positions. The
parent discards one timeGetTime before fopen. Each source pass has4231 progress
calls,8464 timer reads and4231 Sleep5 with clock100. Only elapsed<=33/no-draw
helper is native; animated loading is explicitly unsupported. Non-playback
prologue alone is covered; full41bc90 ret4/input/pause/menu/AI is still open.
Native owns common/registered buffers, catalog, pool and UI; full state/PCM/
mask/ABI comparisons rebuild children and do not use expected after-state inputs.
Historical interleaved catalog was re-executed exactly, including all blobs,
after extracting capture_catalog for the actual parent. Old fixtures unchanged.
Next continue41c581/419a60 and the path to429730 from this loaded state, recover
animated4242e0 and remaining device/menu provenance. Practice/W/clean macOS
are still open. Do not manually change44d05c or replace loaded Object headers.
The continuous-loading stage passed10 targeted XCTest in314.981s: new full
passes158.857s, old catalog audio98.056s, Object/raw Frame56.300s, bootstrap
1.768s. Both packed release comparisons passed before accepting new fixtures;
old fixtures unchanged. Release NTSDNative passed in2.47s.
The [local input study](docs/research/LOCAL_INPUT.md) now continues the real
first loading to41c5e5 and executes419a60 through ret12. Read it before extending
input/network/AI. Both old full-loading raw transports were reproduced byte for
byte before continuing in the same CPU/stack; native rebuilds them through an
onLoaded callback. New606 cases/601 returns compare485214 records/567956264
bytes/masks, then retain the earlier full-loading comparisons. All128 keyboard
and128 joystick combinations per pass, phase/status/network/byte-value controls,
paused caller and all137 source Object bindings are covered. Old fixtures remain
unchanged. Twenty01 bytes plus00 are copied to44d040 even while paused. Positive
status copies Actor+cd..d3 to+c6..cc in BOTH phases, ignoring activity0..7; only
phase0 clears current/read/pack. Config=44fb20+80*status only for1..4. Keyboard
requires exact100; joystick any nonzero, directions0/1/3/2 and mapped buttons.
Negative device selectors skip new reads. Recording450b80!=0 ORs local commands;
network requires SIGNED byte44f1af>0 and ORs packet bytes. Preserve bit0 and old
bits;419a60 does not clear output buffers. Phase/mode are function arguments.
Tail10..399 runs in both phases and during playback; any nonzero activity,
type0 ->4094b0(slot,mode), other type only hit_Fa>0 ->406ba0(slot). Slots8/9
are skipped.1512 AI/618 object requests match at EXPLICIT no-effect child
boundaries; their bodies are not implemented/proved here. Default native throws
without a child handler. The natural first continuation has no active tail.
Read live state after every child, not a precomputed request list. Partial storage
rolls back on unsupported continuation, while external callback effects remain
caller-owned. OS polling/mapping/latency, remote/replay input, phase0 network/
hotkeys, remaining pause/menu->429730 and AI bodies remain open. Practice/W/full
match/clean macOS are still open. Next connect4198f0/4197a0 and the41c5e5..41d469
network/control path using this same loaded state, then continue to429730.
The local-input stage passed3 selected XCTest in249.612s: new two full-parent
input corpora172.239s and old match preparation77.373s. Both fresh EXE corpora
passed release comparison before fixture acceptance. The oracle now snapshots
stimulus metadata by value; after fixing its JSON/aliasing checks both source
runs were repeated completely. No expected after-state was repaired. All six
inherited loading fixture hashes verified; old fixtures unchanged. Release
NTSDNative passed in2.58s. No Practice/Windows input or whole-match claim.
The [received-input study](docs/research/RECEIVED_INPUT.md) now executes whole
4198f0/4197a0 and caller41d469 after reproduced first loading/natural local input.
Read it before extending input/replay/network. Two fresh726-case passes match
Swift:757 remote ret12/710 playback ret8,1173438 records/1373541288 bytes/masks.
The primary first phase1 caller continues41c5e5 on the same CPU/stack. The first
phase0 control explicitly STARTS41d469; network/hotkeys are not executed there.
Native receives its own verified state via LocalInputReference.onNatural; the
entire old local corpus still compares after that callback. All8 parent fixture
hashes remain pinned/unchanged. Both packed release comparisons passed before
new fixture acceptance. New JSON envelopes96.3/97.1 MB need an explicit128 MB
ReceivedInputReference unpack limit; old readers retain default64 MB and each
received-input blob remains capped2 MB. No expected snapshots were changed.
4198f0 visits ONLY status==-1;4197a0 visits all8 regardless status/activity.
Both copy raw cd..d3 to c6..cc in every phase; only phase0 clears/decodes current.
Remote recording!=0 REPLACES the whole command byte, including bit0, unlike
local-input OR. Bytes8/9 remain unchanged. The functions themselves do not check
playback flag; caller does remote FIRST, then playback if450b84!=0, so previous
can be overwritten twice. Any nonzero local pause skips both. Phase is an argument.
All256 byte values, phases/statuses/negative flags and real Actor-table aliases
are covered; resolve seats in order, because later seats see earlier writes.
Native API uses separate packet/output value arrays, not arbitrary source/output
address aliasing. New receiveInput returns explicit playbackChecksum/recording
continuation; it does NOT execute those stages. No Practice/AI/W claim.
Next: phase0 network/hotkeys41c5e5..41d469, playback source43dc50 (buffer+2b38+
10*tick), checksum41d4b7 and recording43db40/counter through41d714, then pause/
menu->429730. On ticks divisible by150, checksum sums Actor+2fc of first20
seats only when activity==1; error exit needs43df00 saved strings beyond globals.
S: even network flag0 makes four Winsock calls before41c64f; do not skip them.
The shared416cd0 hotkey also needs43df00 playback lifecycle. Read the study's
explicit boundaries; full playback prefix, file IO and Windows transport remain open.
The received-input stage passed both new XCTest in199.401s with no failures;
they also replay both entire old local-input and full-loading native comparisons.
Release NTSDNative passed in2.70s. All eight inherited fixture hashes verified;
no old fixtures or baseline assets changed. No new Practice/Windows/full-match proof.
The [input-control study](docs/research/INPUT_CONTROL.md) now executes
41c5e5..41d46f, whole416c70..416fad hotkey helpers and the received-input caller
after two freshly reproduced full loading/local parents. Both first callers,
including paused phase0, now continue on the same CPU/stack. Two2993-case
corpora match native Swift:25984 real hotkey calls,104810 ordered events,
996 sends/1096 receives,152 messages/close requests,160 frees,30 input resets
and4 saved-settings restores. Each pass compares2430722 records and80553312848
bytes/masks, including both FULL replay buffers at every checkpoint; this large
repeated byte count is not gameplay coverage. Both packed release comparisons
passed before accepting new fixtures. The entire303-case old local corpus
and full native loading still compare after the new onNatural callback.
All8 parent fixture SHA values are unchanged. Read the study before extending
network, playback or41d4b7. No Practice/W/full-match claim follows.
Phase!=0 skips control. Phase0 always calls two AsyncSelect then two ioctl,
even network0; first ioctl argp is NULL, second points to a zeroed scratch word.
The network byte is tested for EXACT0/1/2, unlike local-input's signed>0 test.
1 sends22 then receives fragments;2 receives then sends. Send failures are
ignored. Received total is unsigned; last result is signed. Old packet bytes
survive incomplete receive. Sequence is wrapping(old+1)%50; checksum is wrapping
sum of HP Actor+2fc in first20 seats with activity EXACT1, then%100+1.
44f620 is catalog checksum, not RNG. Three header bytes sign-extend before
comparison; catalog bytes compare raw. Each mismatch calls shared shutdown and
posts close, then CONTINUES through later checks/commands. Preserve repeated
messages, stale sound lists/counts and cleared device/replay pointers.
OriginalMatchPrelude.playSound shares real401a30 loop0 for455610/455618/45561c.
Control probes explicitly bind455618/c to two loaded registry buffers; their
actual startup slot assignment and audio output remain unproved.
OriginalMenuPresentation.shutdown is shared with these error exits.
resetOriginalInput now resolves all8 World table references in order, including
aliases, rather than assuming the first8 allocations. Real431c70 executes;
only its standard memset(455378,75,300) remains the inherited CRT boundary.
OriginalInputControlContext owns supplied saved320 bytes and the shared replay
allocation registry.43df00 restores signed byte45877c,8 names/3 strings through
NUL; caller restores flags from buffer+630bb8/c. Strings must terminate within
the supplied extent. Playback startup/save/file IO and out-of-extent overlaps
remain open. Helpers are observed, not stubbed; only OS/COM/free responses are
supplied. Explicit code hooks stop the harness at41d46f/41d4b7/41d5db because
cached translated blocks could cross a later emu_start until boundary. Diagnostic
snapshot restoration was not accepted as continuous evidence; both accepted
captures reran full loading. Next43dc50 playback source,41d4b7 checksum,
43db40 recording and counters through41d714, then pause/menu429730.
Shared preparation/menu regressions passed2 XCTest in220.747s. Both new fixture
XCTest passed in193.315s (97.052+96.263), no failures. Release NTSDNative built
in2.61s. This does not verify Practice, devices, Windows or clean macOS.
The new reference comparator checks full byte representations for speed in
debug, with semantic Bool-array fallback if mask representations differ. It
does not sample or rely only on hashes. Both release comparisons passed again
after this reference-only optimization; all10 fixture hashes stayed unchanged.
The [replay tick study](docs/research/REPLAY_TICK.md) now executes43dc50/43db40,
prefix41bdce..41be8b and checksum/recording41d4b7/41d5db..41d714. Read it before
extending playback or the pause/menu continuation. Both fresh loading/local/
control parents reproduced exactly before the natural tail; native receives
its own verified parent through InputControlReference.onNatural. Two1134-case
passes match Swift:630 packet reads/1026 writes,1224 checksum operations,
296 messages,114 real input resets/56 restores and614 connected input chains.
Each pass compares872088 records/28900704192 bytes/masks, including both FULL
buffers. All10 older fixtures stay unchanged; complete2993-case control,
303-case local and loading native comparisons still run after the new callback.
Prefix clears BOTH10-byte stack buffers even paused; only unpaused playback
reads43dc50. Offset2b38+10*tick uses32-bit wrap. Owned metadata overlap is
preserved; arbitrary globals/stack aliasing and out-of-allocation access are
unsupported, not clamped. Checksum sums HP first20 World references only for
activity EXACT1 with Int32 wrap, at14b8+4*(signed tick/150). At216000 this
overwrites the first packet. Checksum error runs431c70 and conditional43df00,
sets mode6/menu10 and clears playback flags, but does NOT clear450bdc or free.
Recording picks its source AFTER that error path, writes packet then checksum
BEFORE clamping tick647999. Reaching cap from below keeps recording; an old
tick at/above cap writes first, then clears recording/messages. Paused skips
record/counter. Explicit tick648000 writes saved flags at630bb8 before clamp.
Two24-step chains retain tick146..169/Actor/World/settings/buffers; onlyphase
is a new persistent-state input. Caller stack/registers are declared anew for
each chain, whose prefix clears commands itself. The earlier phase prologue
is outside. No AI/object child is stubbed in these
chains: active tails are absent, and reaching such a body fails the harness.
Playback buffers/settings and platform outputs remain declared inputs, not
startup/file provenance. Next pause/menu after41d714 toward429730, earlier
playback prefix/camera, file lifecycle and animated loading. Practice/W/full
match/clean macOS remain open; this is not a whole tick or a runtime integration.
Both replay XCTest passed in219.856s (109.519+110.337), including all five
native parents. The first debug run was deliberately stopped after sampling
identified repeated conversion of the same6.49MB initialization mask. Only
ReplayTickReference now caches validated mask values per blob; every snapshot
still compares full bytes/masks. No runtime code or fixture changed for this.
Both final release comparisons passed again after that change; all12 fixture
SHA and both raw corpora stayed unchanged. Release NTSDNative passed in2.56s.
The [round-control study](docs/research/MATCH_ROUND.md) now continues41d714
through the complete nonpaused round-control/restoration path to41e339,
4229cc or422a95; paused stops BEFORE rendering at41d73b. Read it before
extending match outcomes, restoration, paused rendering or the menu continuation.
Two fresh2074-case passes match Swift, including90 real4061d0 constructors,
3491 team/480 stage scans,914 input resets,22 playback restores and6775 events.
Each compares842450 records/27918510800 bytes/masks; all twelve old parent
fixtures stay pinned. Native receives its own state via ReplayTickReference's
onNatural, then still checks the entire1134 replay/2993 control/303 local
cases and loading per pass. The natural primary exits to menu10/mode0;
the control is paused. These are supplied startup-context consequences, not
selected-player match defaults. Do not replace menu10 by0 to reach gameplay.
All400 World seats are inspected live. A living team needs activity!=0, HP>0,
Object type0 and signed team1..39 except5. Mode1 scans only if cached menu0;
mode4 completion also requires451b7c EXACT1. Preserve highest-team/stale-winner
rules, timer80 effects, exact145->144 freeze, and350 restoration BEFORE menu.
Acknowledgement uses exact1 atd1/d2 for ALL first8 seats regardless activity;
it sets350 but still exits to gameplay, so restoration waits until next entry.
Restoration324 looks up the FIRST source ID and clears only on success; then
the proven ID50/458428==0 exception searches6 and skips the split branch.
Nonnegative328 selects the32c target seat and330/334 source IDs. Real constructor
and live rereads matter when target aliases source; signed HP halves are written
to target BEFORE source, preserving repeated division. Keep original frame112,
MP0, coordinate/velocity/facing/team writes, allocation masks and400-seat order.
The first diagnostic corpus had zero constructors because Object[0] isID50.
It was not accepted as sufficient coverage; BOTH fresh captures were repeated
with actual split/constructor cases, mode4 gate and numeric controls. The final
corpora execute45 constructors per pass. Two275-call sequences retain persistent
state from timer75 through350; caller stack/registers are supplied between calls.
Real402100 stop/seek and shared401a30/431c70/43df00 execute through returns;
COM HRESULTs remain supplied/ignored. Sound slot/COM handles and playback data
are explicit boundaries, not startup/device provenance. No paused drawing,
gameplay pass, menu body, full41bc90 return, Practice, Windows or clean-macOS
claim follows. Next real paused render helpers41d73b and4229cc->429730,
then connect41e339 gameplay; earlier playback/camera/file and startup gaps remain.
Both new round XCTest passed in282.407s (141.384+141.023), including all six
native parents. Both release comparisons passed before accepting the new
fixtures. All14 fixture hashes and both raw corpora verified; old fixtures
and baseline assets unchanged. No runtime integration or Windows claim.
Release NTSDNative built in2.65s; app-window and clean-macOS checks stay open.
The [enabled music study](docs/research/MUSIC_PLAYBACK.md) now executes whole
402020/401d30/401c90/401da0/401f30 after freshly reproduced loading/input/replay/
round parents. Both374-case passes match Swift before accepting new fixtures:
2450 real helper returns,11912 events,438 allocation requests,24 messages and
438 actual VC80 sprintf calls; each32575 records/18155382 bytes/masks.
Primary continues actual4229cc->429730 with music44d010 STILL1, menu10 and
previous0. Control remains paused; its4229cc entry is explicitly supplied.
Stop4297ae is BEFORE previous4512cc assignment and11 menu bitmap allocations.
Read the study before extending music or this menu. Do not disable music to
bypass the natural caller. Shared release/volume also serve MenuPresentation.
Same path only resumes; new path releases position/event/control/graph in order.
Create/render errors still continue toward volume and conditional Run/cache.
Query HRESULTs and output words are separate inputs; mandatory null interfaces
remain invalid continuations. Keep signed HRESULTs and wrapping volume*34-3900,
special zero=-10000. Long cached paths overlap directory44ef38; do not impose
an invented52-byte field length.401da0 never frees its wide allocation on this
path; retain backing/masks, even absent/partial conversion or failed rendering.
COM/Win32/new outputs remain boundaries; no Windows codec/file/music output is
claimed. Old match music selection4025b0/4025d0 is not connected yet. All14 older
fixture pins remain unchanged. Full2074 round/1134 replay/2993 control/303 local
and loading native parents still run after the callback. Next menu resources
4297ae..429e5a and431d10, paused rendering and gameplay. Practice/W/clean macOS
are open. The earlier replay chain's disabled4025b0/402020 keeps its old scope.
Both music XCTest passed in290.588s (145.694+144.894), including all seven
native parents per pass. Shared historical MenuPresentation passed in138.633s.
Both release comparisons passed before accepting the two new fixtures; all16
fixture hashes and both raw corpora verified. No expected after-state was fixed.
Final release NTSDNative passed in19.69s. No app-window/device-output claim.
The [menu-resource study](docs/research/MENU_RESOURCES.md) now continues both
fresh natural4297ae entries through429e5a, after validating full loading/input/
round/music parents. Both187-case passes match Swift before accepting fixtures:
2098 real43ee50 returns,2244 allocations/146 null,3376 checkpoints,8936 events,
194 messages/102 surface releases and12 null-SPARK boundaries. Each compares
82363 full records/731749936 bytes/masks; all16 old fixture pins stay unchanged.
Read this study before extending menu bitmap initialization or dispatch431d10.
Previous4512cc is ALWAYS updated from current44d020; old4512c8 is saved before
constructors. Any nonzero44d07c loads11 PE DIBs via shared bitmap constructor;
null allocation skips its ctor, but device failure returns a wrapper. Old global
pointers are replaced without release. Preserve all retained wrappers/masks.
Three8-word arrays451288/451268/451248 are cleared0/0/-1 in per-seat order.
SPARK+0c gets20, but only16 rectangle indices are written. Preserve0/5/10/15
and all other untouched storage.44d07c clears BEFORE height[13], not at end.
Null SPARK returns explicit partial-state boundary BEFORE429b21; page0 in the
reference VM is SEH backing, never evidence of a safe NULL write or Windows AV.
Missing SPARK surface still allows metadata writes if the wrapper exists.
Native receives its own parent globals through MusicPlaybackReference.onNatural;
all374 old music/2074 round/1134 replay/2993 control/303 local and loading cases
still compare after the callback. Full retained records are compared at case
ends; current records and full globals at each checkpoint. Only surface+0
normalizes1/0, never wrapper tokens or opaque/partially written words.
Control inherits its earlier supplied4229cc after pause; resource entry itself
continues on the same CPU/stack. No menu dispatch, pixels, Practice, Windows or
clean-macOS claim. Next actual429e5a dispatch and431d10 screen, paused41d73b
and gameplay41e339, with earlier playback/camera/file/loading gaps still open.
Both menu-resource XCTest passed in294.964s (146.542+148.422), including all
eight native parents per pass. Release comparisons passed before acceptance;
all18 old/new fixture SHA and both new raw corpora verified. The EXE stays pinned.
Release NTSDNative passed in2.93s. No app-window or device-output claim.
The [bitmap drawing study](docs/research/BITMAP_DRAWING.md) now executes whole
43f010/43ef70 through Blt(+14)/ret24 in3971 ISOLATED cases. Read it before
extending bitmap drawing, clipping or connecting actual menu/gameplay callers.
34 original embedded DIBs and76 real43ee50 constructions,3330 real clip returns,
2297 Blt requests/198 double draws,21475 reads/9055 from untouched backing match
Swift;8038 full records/215838896 bytes/masks. This is not a new continuous
loading/menu chain. Supplied backing/metadata/viewport/COM responses remain inputs.
Whole-image branch runs for count0 OR negative frame, then FALLS THROUGH to
signed frame<count. Preserve negative/wrapped4*frame aliases, strict clipping
comparisons, zero/inverted rectangles, both mirror formulas and ignored HRESULTs.
Effects are exact100 bytes: size100/flags2/rest zero. No Blt retry/release here.
Only the known surface word+0 is canonical1/0 in loaders. Drawing rebinds it to
the declared raw token BEFORE arithmetic, since frame=-4 can read it as x.
The first native mismatch found this alias; core binding was fixed, source
corpus/expected snapshots unchanged. Do not normalize opaque neighboring words.
Draw observes raw backing reads and masks explicitly without promoting them to
initialized defaults; OriginalStateRecord.integer remains strict. Actual Windows
heap provenance is open.18 outside-wrapper and2 null-target cases stop BEFORE
the original load and throw explicitly natively, retaining prior request order.
DirectDraw raster/pixels, runtime caller integration and Windows remain open.
Natural menu state still has4511a0/451178 null, so recover early startup resources
before full431d10; do not forge successful bitmap pointers to reach its return.
The new bitmap drawing XCTest passed in4.510s; release NTSDNative in2.28s.
All18 inherited fixture hashes remain unchanged; new raw/packed SHA verified.
No shared constructor or strict state-read implementation was changed.
The [front-menu resources study](docs/research/FRONT_MENU_RESOURCES.md) now
executes World419e40 and4246b0's early startup branch to427089, BEFORE423480.
Two145-case corpora match native:4090 real43ee50,995170 ordered parent writes,
244526 full records/1969423200 bytes/masks.24 wrappers use23 original PE DIBs;
151 literal rectangles/9 sheets are statically recovered from checked EXE bytes;
six256-glyph tables retain their interleaved writes. Eight names write ONLY
UInt16 at44fcc0+11*i. Preserve old wrappers and all untouched bytes/masks.
Any nonzero44d068 reloads; flag0 skips to42709b.4511f8 always wraps1-old.
The settings boundary does NOT clear44d068; real clear427092 follows423480.
Null metadata writes stop explicitly with partial state before source access.
This isolated early startup is not yet joined with prior loading/menu corpora;
outer caller frame and allocator/device responses are declared inputs. Do not
inject successful early bitmap pointers into historical natural-menu snapshots.
Next423480 settings/CRT, then427092/42709b and full early-screen integration.
Both new XCTest passed in4.207s; release NTSDNative in2.33s.19 old fixture SHA
unchanged; both raw/packed SHA and complete unpack verified, generator --check
passed. No shared constructor changed; full UI/pixels/Practice/Windows open.
The [settings-loading study](docs/research/SETTINGS_LOADING.md) now continues
each fresh World/front-resource parent on the SAME CPU/stack through actual
423480, VC80 fscanf/fgets/feof, ret42708e and store427092 to42709b. Native uses
its own World/resources via optional FrontMenuResourcesReference.onNatural.
Two94-case corpora match:8742 actual scans/696 gets/510 feof,186 helper returns,
15128 events/4620 parent writes,20648 records/481555672 bytes/masks plus parents.
44 integer fields use the shared scanner unchanged; four unbounded %s may overlap
11-byte names, then backticks become spaces. Trailing format whitespace consumes
blank lines. Profile trim removes only space/CR/LF, never TAB. Failed fgets keeps
old scratch; EOF after a final newline duplicates that last info line. Preserve
all copied bytes, NULs and dword/byte append order, including adjacent globals.
427092 writes caller EBX, natural0, not a literal0. The supplied retry after a
null-FILE interruption exposed this: core caller input fixed; fresh source
capture preserved every old event/snapshot/blob. Null FILE stops BEFORE4234db
call and does not clear the flag. It does not model CRT invalid-parameter exit.
First helper is continuous after real resources; subsequent427089 entries are
explicit caller probes, not full menu iterations. File open/close, translated
_read bytes, thread binding,500-byte scratch backing and controlled caller EBX
are declared inputs. Actual Windows file/CRT startup and stack lifetime remain
open; no native app UI integration follows. Next42709b screen selection,
4237e0/415160/423840/4236d0 and real42710f bitmap caller, then earlier/later menus.
Both release comparisons passed before accepting fixtures. Four targeted tests
(new settings and old front resources) passed in11.970s;21 old fixture hashes
unchanged, both new raw/packed SHA and complete unpack verified. Release
NTSDNative passed in2.31s. No window/device-output claim.
The [front-screen prelude](docs/research/FRONT_SCREEN_PRELUDE.md) now continues
fresh World/resources/settings on the SAME CPU/stack through42709b and the real
first bitmap caller42710f to427127/4275cb.356 cases match native, including
whole4237e0/43c450,415160,423840/43ee50,43f010/43ef70 and actual VC80 sprintf.
Native uses its own settings parent through optional onNatural; old corpora
remain unchanged. All13 MENU_BACK DIBs,64 new constructors/66 formats,354 fills,
354 draws/474 Blt,527 clips,2580 reads/1422 undefined,26 thread requests and
6 invalid-access boundaries;14982 records/131606688 bytes/masks plus parents.
Timer selection is UInt32 timeGetTime%13+1, not gameplay RNG. Keep the14-byte
MENU_BACK0000 buffer's unused suffix after sprintf. Background count/rectangles
remain untouched; replacing globals never releases old wrappers. Fill415160
initializes ONLY8/100 FX bytes (size+0,color+50), preserving declared stack
backing/masks; bitmap mirror effects are different. Do not silently zero either
bitmap count/rectangles or fill padding. Actual first draw now demonstrates
additional draws from ramp backing; this is not real Windows heap provenance.
Thread gate compares raw bytes;43c450 locks, reads458424, unlocks, then requests
43c240 only for status0. Worker/concurrency and WinMain/device binding remain
boundaries. Later42709b callers supply EBX0/ESI-1/EDI target/stack explicitly.
Null fill/bitmap/draw target stops before the original dereference and keeps
partial state. Next actual4236d0/427127 body,4275cb alternatives and joining
the earlier/later menu paths. No full screen, app UI, pixels or Windows claim.
Both release comparisons passed before acceptance. All23 old fixture hashes
unchanged; new raw/packed SHA and complete unpack verified. Both old94-case
settings source corpora were freshly reproduced and ALL blobs matched after
the default-noop device hook. Five targeted tests (new prefix, old settings and
bitmap drawing) passed in14.095s; new prefix tests2.474s. Release NTSDNative
passed in2.25s; no window/device-output claim.
The [menu-content parser](docs/research/MENU_CONTENT.md) now executes whole43c780
with actual VC80 sprintf/fgets/sscanf on the same CPU/stack. Two352-case corpora
match native:1408 formats,16998 gets/16992 scans,116462 events/79666 parent
writes,72204 records/1705747296 bytes/masks.64 successful/634 failed returns
and6 unterminated-input boundaries; source ret/stack/nonvolatile registers checked.
This is an independent helper on persistent globals, not yet joined to4236d0.
Original ad0/ad1 txt/bmp are absent; adinfo is now0 4. Present-file controls come
from the EXE format and never become game assets.24 ba/8 ta/un/y/end rows retain
all partial state. BA resets only its first scanf number; TA resets all3; Y
resets both to0 in reverse scanf order. String initialization writes ONLYUInt16
"-\0", unbounded%s may overlap adjacent fields, failed fgets retains old bytes.
Keep shared1104-byte scratch (markers0/52,buffers104/604), not isolated strings.
Missing NUL stops BEFORE the original scanf call, retaining earlier operations;
no stack corruption/Windows backing provenance is claimed. Native uses the
existing OriginalFrameScanner unchanged. File open/close, translated_read and
CRT thread/locks remain explicit boundaries. Next43cc60 bitmap lifecycle and
43c690/43c710 cache/default writers, then whole4236d0 through actual427127.
Both packed release comparisons passed before acceptance;25 old fixture SHA
unchanged, new raw/packed SHA and complete unpack verified. Both new XCTest
passed in28.684s; release NTSDNative passed in2.33s. No app UI/Windows claim.
The [panel bitmap lifecycle](docs/research/MENU_PANEL_BITMAP.md) now executes
whole43cc60 with real43ee50/43ef50 in118 independent helper calls. Native matches
202 child returns (102 constructors/100 destructors),2812 events/2018 parent
writes,74 releases/100 frees,2874 full records/27537088 bytes/masks.118 malloc
requests include16 null and44 repeated addresses; each pass retains51 allocation
generations on29 addresses. Freeze dead bytes/masks BEFORE the same physical
address is reused; native next backing comes from allocator input, never from
expected freed snapshots. Old bitmap always goes through destructor/free before
malloc; missing/key-failure wrappers remain live with untouched count/rectangles.
Only successful surface gets44 literal x/y/width/height writes, then count11.
These rectangles are independent of DIB dimensions; do not clamp them to fit.
Known surface+0 alone is canonical1/0; retain raw token per generation for release.
Both original ad0/ad1 bmp are absent; successful controls explicitly bind three
original PE DIB names (MENU_CLIP/MENU_BACK1/SPARK), never replacement ad assets.
This does not execute4236d0 or prove a natural Windows startup calls43cc60 after
missing text. Next43c690/43c710 default/cache writers, then whole4236d0 at427127
with existing43c780 and fresh early screen parent. Constructor core unchanged.
Both packed release comparisons passed before acceptance;27 old fixture SHA
unchanged, new raw/packed SHA and full unpack checked. Two new XCTest passed
in0.474s; release NTSDNative passed in2.36s. App UI/pixels/full match/W open.
The [menu-info writers](docs/research/MENU_INFO_WRITING.md) now execute whole
43c690/43c710 with real VC80 sprintf/fprintf/fclose.534 independent helper cases
match native:1068 formats/518 prints/518 closes,2618 low-level writes/148 failed
or short,6212 events/438 parent writes,18924 records/295329884 bytes/masks.
Defaults always writes now\0/index0/period4 AFTER file IO, even on failed open,
then formats both paths; EAX is the last sprintf length. Cache formats paths
BEFORE fopen, then prints raw date bytes and signed32 index/period; EAX is0 on
failed fopen or the fclose result. A failed fprintf may still lead to fclose0.
The new shared OriginalBufferedTextOutput covers the declared flags102 FILE
with user buffer1/7/64/4096, not general Windows fopen/stream initialization.
_flsbuf updates ptr/count BEFORE _write, then stores the next byte even after
failed/short flush. Fclose attempts that tail, resets ptr/count, calls_close
and clears flags while keeping user-buffer bytes/base/size. Do not retry the
whole block or silently discard the saved byte. Low-level _write/_close/_isatty
and same PTD (_getptd plus_getptd_noexit) are declared boundaries; errno28 on
negative IO, no EILSEQ42 replacement/append/wide stream. Bytes are logical LF,
BEFORE Windows text translation; baseline adinfo remains unchanged CRLF.
Now join content43c780/bitmap43cc60/both writers into whole4236d0 through actual
427127 after fresh early-screen parents. No new app UI/real file/Windows claim.
Both packed release comparisons passed before acceptance;29 old fixture SHA
unchanged, new raw/packed SHA and full unpack verified. Two new XCTest passed
in4.738s; release NTSDNative passed in2.30s. Existing shared helpers unchanged.
The [joined panel update](docs/research/MENU_PANEL_UPDATE.md) now executes whole
4236d0 through actual caller427127 and return42712c after fresh World/resources/
settings/screen prefix on the same CPU/stack.266 cases match native, composing
the existing content/bitmap/default/cache helpers:332/118/130/250 calls,
828 completed returns,94 constructors/92 destructors,3852 parent/34760 child
events,43156 records/734441674 bytes/masks. First natural status0 only enters/
leaves the lock; later caller registers/worker globals are explicit stimuli.
Compare signed versions BEFORE clearing458424. Toggle is signed remainder
(Int32(1) &- index)%2. Copy date458350 to4527b0 through NUL only on no-new-version
or first successful pair; second successful pair keeps the OLD date. Double
failure calls defaults THEN cache even after file errors. A failed bitmap can
destroy the previous image and retain an empty wrapper; writers do not undo it.
Keep all panel allocation generations plus World and25 early bitmap records.
The real content local base is child entryESP-454; its observed before-call
1104-byte backing is an explicit input. Both final controlled empty-file cases
stop BEFORE43c817 with partial state/status already cleared and no Leave, not
a false loader return or automatic lock cleanup. Next instructions are open.
Panel arena2c000000 is separate from early allocations; original MENU_BACK1 DIB
is an explicit device response at the requested ad path, never a new game asset.
Original ad0/ad1 remain absent. FILE/CRT/IO/COM/worker boundaries remain declared.
Native takes its own fresh parent via optional FrontScreenPreludeReference
onNatural, never expected after-snapshots. Next body42712c and alternatives4275cb,
then join earlier/later menu and loading paths; app UI/pixels/Windows remain open.
Both packed release comparisons passed before acceptance;31 old fixture SHA
unchanged, both new raw/packed SHA and full unpack checked. Both historical
content and both bitmap source corpora reproduced ALL cases/blobs unchanged
after the optional local/heap/device address hooks. Four targeted XCTest passed
in14.137s; release NTSDNative passed in2.39s. R02.1/full match still open.
The [front screen body](docs/research/FRONT_SCREEN_BODY.md) now executes
42712c..4275cb after the fresh panel parent, with real401290/401a30/43f010/
43ef70 children.1142 cases match native:8650 helper returns,180886 ordered
events,3742 text requests/3740 completed401290,2392 draws/clips/2304 Blt,
126 sounds/38 links,31978 records/284157936 bytes/masks. Keep raw28/31/29-byte
literal copies, byte subtract index&3 with repeated strlen and all192 local
bytes/masks. First backing comes from actual caller; later native locals persist.
Three text rows use x591 and base45757c+491/y+20/y+40 with raw COLORREF602010/
d07750. Website hover's upper-y check is bypassed when45757c==0. Author highlights
copy entire suffix through NUL THEN write a separate terminator at local+ae/b0;
keep the remaining tail. Click requires previous0/held1, clears held before
sound/Sleep300/ShellExecute. No external link is opened in reference execution.
Status1/2 button uses frame11; setting0 uses6/7, nonzero8/9. Hover x>=725/y<18
has no lower bounds; accepted click selects-3. Final logo y=453da4+96.
OriginalSurfaceText generalizes the EXISTING menu notice text helper; both callers
share GetDC/GDI/ReleaseDC rules. Negative GetDC skips GDI only; positive original
HRESULT is returned even if GDI/release fails. Two null-text cases stop before
401295 after preserving earlier local writes. GDI/COM/Shell/Sleep and control
sound handles are boundaries. All25 loaded bitmaps and World remain unchanged.
Both packed corpora compared before acceptance; all33 previous pinned fixtures
unchanged and both new raw/packed SHA/full unpack checked. Next4275cb selector-3
and its settings writer423230, then selector-1 at4277f3, join main-menu/tail.
Five targeted XCTest passed in150.890s: new body6.062s, old panel12.507s and
historical full menu-presentation chain132.322s, covering the shared text refactor.
Release NTSDNative passed in2.37s. No app UI/pixels/Windows or full-match claim;
R02.1 remains open.
The [settings writer](docs/research/SETTINGS_WRITING.md) now executes whole423230
with actual VC80 fprintf/fclose in452 standalone cases. Native matches442 returns,
23964 prints/442 closes,73626 descriptor writes/108 failed or short,107066 events/
8140 parent writes,298134 records/4615970322 bytes/masks. The first explicit field
inputs come from original control.txt and the logical full output roundtrips.
This is supplied PE/BSS/helper state, not a continuous427688/427704 menu caller.
Four groups of11 integers use stride50 and separate%d-space/newline calls.
Name bases44fcc0+11*i have NO11-byte limit: encode backtick to apostrophe,
otherwise space to backtick; repeat strlen each iteration. Empty names get ONLY
UInt16 digit/NUL. Print four names BEFORE defaulting profile name44fd18/info44f900/
email44f890. Then450be8/450be4, name/email with LF, info without final LF, close,
restore only backticks to spaces. Overlapping passes may turn an original space
into an apostrophe; metadata defaults can change a spanning name. EAX is the
last length of the fourth name after restoration, not fclose result.
The new shared OriginalBufferedTextOutput.printFormat handles plain%d/%s plus
ASCII literals. BOTH menu-info and settings writers use it. Actual DLL78141671
sets count=-1 on byte failure;781416c8 starts another segment even with count=-1.
Prefix78141f5d and digits78141fdf are separate calls: failed minus can be followed
by successful digits restoring count>=0; outer guard is78141871. Do not flatten
the whole format or globally stop at a failed prefix. Six source probes retain
FILE error bit but fprintf returns10 after this failure. Low-level printBytes/
flsbuf/close are unchanged; width/precision/other conversions/wide/EILSEQ42 open.
Eight null-FILE cases stop BEFORE423260; two no-NUL cases stop BEFORE423297
outside declared globals, after44 integers/four line breaks, without close.
No safe false-return or Windows invalid-parameter behavior is implied. Original
source file stays unchanged. The caller composition is described below;
app UI/Windows remain open.
Both new packed corpora compared before acceptance; all35 previous pinned
fixture hashes unchanged, both new raw/packed SHA/full unpack verified. Six
targeted XCTest passed in84.404s (settings67.138s, old info4.925s, joined panel
12.341s); release NTSDNative passed in2.69s. No old Python helper was changed.
The [alternate early screens](docs/research/FRONT_SCREEN_ALTERNATE.md) now
continue the fresh body through4275cb..42790f with actual bitmap/clip/sound/fill/
worker-gate and423230/VC80 writer children on the same CPU/stack. Read that study
before extending early UI. Native matches1066cases/6842helper returns,
31910parent/11104writer events,164settings calls/148returns/7992fprintf,
2652descriptor writes/36failed-short,63656records/788945104bytes/masks.
First natural EAX0 goes to427915; later caller/OS/FILE inputs are explicit,
not complete screen iterations. EAX selects the branch, not a new44d064 read.
4511f4=0 leaves global0 and local y96; nonzero uses signed multiply high32 and
sign correction after wrapped y+90. Enable/disable clear held/set450be8 BEFORE
actual423230; only after return clear selector/y, then sound. Enable alone
calls4237e0. Preserve local y even after global clear. Expand hitbox starts203,
draw x202. Waiting low-bit test is byte but OR1 writes DWORD4511f0; unsigned
timer delta must be>150, count is wrapped signed remainder14, timestamp uses
another timer call. Do not clamp positive count to13. Cancel sound precedes
held/selector writes, and4511e4 always increments. Both callers share the factored
OriginalMenuWorkerRequest; worker body remains outside. Retain declared fill
stack backing (only8/100bytes defined), caller local token without defining it,
World and all25early bitmap records.16null-FILE/6null-bitmap/2null-fill probes
stop before invalid access; no successful-return behavior is inserted.
FrontScreenBodyReference.onNatural passes its own validated native state/local/
resources/raw surface tokens; expected snapshots never seed the continuation.
The Python body observer now has default-preserving hooks for its child/PC/stop/
sound domains. Both historical body corpora reproduced every571cases/676blobs
exactly after this refactor. Next join these live early resources through427915
and42873e to the full screen return; main-menu/tail previous isolated coverage
is not yet composition. Practice UI, device pixels/audio, full loop and Windows
remain open. Do not mark R02.1/R01.2 or the full-game goal complete for this stage.
Both new raw and packed corpora passed before acceptance; all76 previous fixture
hashes are unchanged, both new packed SHA/full unpack verified. The78-fixture
pin inventory is build/research/front-screen-alternate-fixture-pins.json.
Six targeted XCTest passed in20.817s (new alternates12.441s, historical body
5.935s, historical prefix2.441s). Release NTSDNative build passed in2.44s. Initial
comparison exposed a reference-only read of the deliberately undefined stack+20
mask; the fix reads declared raw bytes without altering that mask. No expected
fixture was changed to accommodate native output.
The [front-menu completion](docs/research/FRONT_MENU_COMPLETION.md) now joins
fresh World/resources/settings/prefix/body/alternate EAX0 to427915/main menu and
42873e through actual ret4. Both403-case corpora match native:806returns,
6996helper returns,21948events,234000actual DLL rand/78tables,148sprintf,
42986records/395787072bytes+masks. Actual graphics children use all25real early
bitmap records; overlay/network/CRT/present/shutdown run on the same CPU/stack.
First caller/prologue is natural; later main/tail entries are explicitly supplied
after a real fresh SEH/cookie prologue, not full screen iterations. Final choose-
match plus whole4246b0 World1 releases the actual background through423910/
43ef50/free, preserves its dead record, clears4511ac and writesWorld2. No World2
41bc90 execution is claimed yet. Raw bitmap ownership tokens are converted only
at the drawing API's canonical+binding boundary; don't normalize arbitrary words.
Cursor/MENU_WAIT count+0c is untouched: frame-1 whole-image then frame<count can
produce a second draw. A5 has961clips/657Blt, ramp1357clips/925Blt; keep this
backing-dependent source behavior, don't initialize count to make it prettier.
Fresh PTD starts1 from the parent's actual_initptd; full process srand/CRT lifetime
remains open. OriginalMainMenu.run now accepts World/globals without a loaded
match catalog; existing OriginalMatchPreparation.runMainMenu delegates to it.
Old menu/network logic is shared, not duplicated. FrontScreenAlternateReference
onNatural exposes its own validated state/resources for composition. The source
reuses old network/GDI boundary observers while executing actual rand/sprintf
on the current VM rather than another helper VM. No OS/network/browser IO.
Both raw and packed new corpora passed before acceptance; all78old fixture hashes
are unchanged and both new packed SHA/full unpack checked (80-fixture pins at
build/research/front-menu-completion-fixture-pins.json). Initial native comparison
found a reference-only raw/canonical surface adapter mismatch; expected corpora
were not changed to accommodate it. Caller ABI/World/globals/bitmap storage are
checked; full main/overlay stack scratch is outside this new native domain.
Next compose repeated early dispatch/prefix/body/alternates through this return,
then continue World2 with the real loading chain. Enabled optional panel, other
selectors, app UI/device pixels/audio, Windows and full-game equivalence stay open.
Five targeted XCTest passed in139.941s: new completion7.656s, historical
alternates13.327s, MainMenu118.958s. The old MainMenu test rebuilds1020probes/
450mouse messages and50full preparation/recording chains through the factored
runner. Release NTSDNative build passed in2.49s. All commands/processes were terminal
before the milestone commit; no full-match/Windows completion is implied.
The native preparation is not wired into practice. Do not restore synthetic
Object headers or treat constructor/PE zeros as final match defaults.
Verification: the existing 27 Swift tests passed (198.991s), then the three new
OriginalLoadedCatalogTests passed (135.451s), all on this shared-state change.
Release comparisons for all three packed fixtures also passed before acceptance.
The preparation stage additionally passed all 31 Swift tests in 398.752s,
including the new two-corpus comparison in 75.717s; both release comparisons
passed before fixture acceptance. The recording initialization stage then passed
all 32 Swift tests in 514.610s (new two-corpus test 113.006s), plus the release
comparison of both packed corpora before accepting them. The prelude stage passed
all 33 Swift tests in 634.646s (new comparison 114.310s), plus both release
comparisons before accepting fixtures. Re-executing the two earlier a5 Python
oracles reproduced all 25+25 historical cases exactly after the optional hook
refactor, including state/mask hashes, calls and instruction access inventories.
The continuation stage passed all 34 Swift tests in 811.498s, with its new
parent-plus-continuation comparison in 172.950s. Both release comparisons passed
before fixture acceptance; earlier fixtures remained unchanged. The readable
reports retain inventories and canonical call digests; full ordered calls and
candidate lists remain in the accepted packed fixtures.
The RNG initialization stage passed three targeted Swift tests in287.065s:
new two-corpus chain114.852s, historical continuation plus parents172.116s,
and CRT integer fixture. Both release comparisons passed before acceptance.
The historical a5 Python prelude reproduced all25cases and ALL blobs exactly
after the default-boundary/hook refactor. Existing fixtures are unchanged.
Release NTSDNative build passed in2.31s on this change.
The main-menu stage passed two targeted Swift tests in230.344s: new menu chain
116.782s and historical RNG initialization113.562s. Both release comparisons
passed before acceptance. Existing fixtures are unchanged.
Release NTSDNative build passed in2.31s for the main-menu stage as well.
The presentation stage passed two targeted tests in249.281s: new tail/World1
chain132.072s and historical MainMenu117.209s. Both packed a5/ramp comparisons
passed before acceptance; older fixtures unchanged. Release NTSDNative passed
in2.53s. This does not increase verified Practice gameplay or close R01.2/W.
The WAV stage passed two targeted tests in150.419s: all409 WAVs plus initial
sound loading21.556s, historical presentation/full parent chain128.863s.
Release comparison passed before accepting the new fixture; existing fixtures
are unchanged. Release NTSDNative passed in2.30s. No playback claim follows.
The initial-interface stage passed six targeted tests in137.528s: new corpus
3.917s, historical bootstrap two tests1.681s and three loaded-catalog tests
131.930s. These cover the shared bitmap storage refactor in Object/BG and all
source catalogs. Release comparison passed before new fixture acceptance;
old fixtures unchanged. Release NTSDNative passed in2.24s. No new Practice/W proof.
The enabled-catalog sound stage passed eight targeted tests in250.754s:
new full/control audio96.688s, historical match preparation75.488s, four
Object/raw-Frame tests56.560s and old WAV corpus22.018s. Both new release
comparisons passed before fixture acceptance; all old fixtures unchanged.
The historical WAV Python oracle also reproduced every case/startup/blob after
the optional-attachment refactor. Release NTSDNative passed in16.80s.
After correcting the last partial cache-slot extent guard, both new catalog
audio tests passed again in96.614s. The source corpus uses400 registrations;
it does not exercise filling the cache to its allocation boundary.
Final release NTSDNative build passed in14.34s.
Reference checks
are a development-only Swift target, not an app dependency. Run SwiftPM commands
sequentially since they share native/.build.
R01.2 follows R02.1/R03.1 with a wider execution oracle.
Follow the map's dependencies; keep analysis, native implementation and
verification statuses separate. Update the map/card after completing a bounded
piece of work. Creating this map does not extend verified gameplay coverage.

Implement shared original mechanisms driven by DAT records. Character/frame
allowlists are prototype domain limits, not the target engine architecture.
Preserve and document ID-specific exceptions found in this EXE; do not invent
per-character handlers or remove original exceptions for architectural neatness.
Do not lift a prototype restriction before its newly reachable mechanisms have
been recovered and checked. Source characters are test cases for shared rules.

The [repeated early-menu calls](docs/research/FRONT_MENU_LOOP.md) now compose
the own fresh first ret4 with subsequent whole4246b0 entries. Both119-case
corpora match native:238calls/1094phases,228ret4,8selector/FILE boundaries,
2actual41bc90 entries,3945helpers/24951events,30000rand,40058records/
376899720bytes+masks. Each inner phase resumes the actual predecessor PC with
the same CPU/stack/registers. Only the outer caller ABI and declared global/
mouse/worker/timer/device/FILE inputs are supplied. Native OriginalFrontMenuLoop
chooses its own callback order from World/globals; expected phase arrays do not
drive execution. World1 uses the common completion, World2 stops before41bc90;
held457580 is not cleared until the original loading call returns at424746.
The new prefix initializer adopts its own previous background storage/surface;
all raw ownership records survive calls. Explicitly clearing4511ac allocates a
new MENU_BACK13 without releasing old MENU_BACK1; World1 releases only the new
current background. Preserve both live/dead records. Phase4511f8 uses wrapped
DWORD1-old, not Bool. Original shared settings/body/alternate/menu rules are
unchanged. Full body scratch is a declared before-body input, checked after
native writes; skipped-body/main/overlay scratch is outside this native domain.
Null-FILE stops before423260; the next probe supplies a new outer caller and
retains partial globals, not a claim of Windows SEH recovery. Worker body and
status2 panel children in repeated calls are not covered by this new corpus.
Both raw and packed new corpora passed before acceptance. All80old fixture
hashes remain unchanged; SHA/full unpack of both new fixtures checked,82 pins
at build/research/front-menu-loop-fixture-pins.json. Next join this early World2
and retained resources into the real41bc90 loading/catalog/input chain. Other
selectors, app integration/device output and Windows remain open. Do not close
R02.1/R01.2 or the full-game goal for this composition.
Six targeted XCTest passed in17.337s: new loop7.122s, historical completion
7.552s, historical prefix2.663s. Release NTSDNative passed in2.48s. SwiftPM
commands were sequential; all processes were terminal before the milestone.

The [early-menu to loading composition](docs/research/MENU_LOADING.md) now
continues the same menu World2/stack/CPU at actual424741/41bc90 through41c581.
Both fresh119-menu-call chains match native before/after loading:36common/
800registry WAVs,274Objects,816Actor/20UI constructors,363365426bytes+masks
after the menu parent. MENU_WAIT now executes actual43f010/43ef70 with its
retained early bitmap, including ret24/EAX and1/2Blt for A5/ramp.26early bitmap
records per pass (one dead), CRT and replay pointers remain owned; the10new UI
records belong to OriginalInitialLoading separately. Do not free old wrappers
when a later UI global replaces their reference unless the EXE actually does.
Read the study before changing attached loading observers. Constructors/Objects/
LoadedCatalog/SoundCatalog/InitialLoading accept an existing UC without resetting
PE/stack/World/globals. The existing World's mask is shared. Parent inactive
code/memset observers yield to the new loading domain. Audio second segment
uses2d000020:28000020 overlaps early bitmap memory,2c000020 overlaps panel memory.
OriginalWaveLoader.prefix_draw optionally executes the real early bitmap child;
default standalone capture retains its old opaque drawing boundary. Real audio/
presentation device tokens are declared BEFORE the first early resources and
retained through loading; attaching observers asserts unchanged registers,
entire stack, World/globals, early resources and CRT. Windows device creation
is not implied. The catalog keeps its old declared scanner VM boundary.
FrontMenuLoopReference.onLoading exposes its own checked native World/globals/
CRT/ownership. InitialLoadingReference.initialState bypasses standalone World2
construction and uses those records. The new bridge additionally binds every
registry WAV device/output-before to its own initial globals. No expected
after-state supplies the continuation. Native shared loading rules are unchanged.
Both new raw and packed sets passed before acceptance. Historical primary
initial-loading/catalog/sounds and all blobs reproduced exactly;431old WAV
cases/3initial passes and every blob also reproduced. The first historical
comparison needed JSON normalization of Python globalWrites tuples; after
correcting the check, a complete fresh replay matched. Four old XCTest passed
in175.906s (loop7.691s,initial-loading168.215s). Next continue this combined
state after41c581 through input/round/menu; frozen progress/animated4242e0,
full41bc90 return/held clear424746, remaining selectors, app integration and
Windows remain open. R02.1/R01.2/full-game goal are not complete.
Two new joined XCTest passed in168.500s; with the four old tests,6checks/
344.406s passed. All82previous fixture hashes are unchanged. All8new raw/
packed SHA/length/full-unpack checks passed, including declared catalog
transport filtering;90fixture pins at build/research/menu-loading-fixture-pins.json.
Release NTSDNative passed in0.17s. No SwiftPM or source-capture process remained
active before the milestone commit.

The [own startup continuation](docs/research/MENU_STARTUP.md) now joins the
early-menu/loading World through41c581/input/received/replay/round to the real
4229cc/429730, enabled music and11 menu bitmap constructors ending429e5a.
Both fresh natural phase1/pause0 passes match native raw and packed before
acceptance:44checkpoints/136events,6824records/11897268bytes+masks after their
checked menu-loading parents;2local/2received ret12,10music helpers/22constructors.
All26early bitmap records/liveness and CRT survive. No game-state stimuli or
paused-entry jump occur after loading. The control suffix now means ramp and
reverse allocation, not the old standalone paused phase0 initial caller.
Read the study before extending the continuation. Source observers forward
existing UC/World/loading options through their constructors, use world_address,
and accept separate music/resource arenas and import pages. Defaults retain
the historical corpus. New music31000000/resources32000000 and imports
33000000/33001000/33002000 avoid early bitmap/panel/PCM regions. No artificial
replay buffers are mapped: own4588a8/ac remain0. Saved-playback458588..4588a7
is a declared PE input captured BEFORE the first early menu, retained natively
and compared afterwards. Removing the old early front_code_hook after
continuing_loading only eliminates an inactive observer; early memory hooks
and the explicit real MENU_WAIT child remain. The control pass reproduced all
four pinned menu-loading documents/blobs after this change. The final source
observers also reproduced the whole historical menu-resources corpus, all its
parent captures and every blob exactly.
Native OriginalLoadedMatchEntry composes shared local/control/received/replay/
round rules and returns the actual continuation; no per-character logic added.
MenuLoadingReference.onLoaded exposes its own loaded result/CRT/early memory.
New MenuStartupReference preserves that state, then runs existing music/menu
resource loaders.4198f0 is called41d490 and returns41d495; a mistaken reference
ABI assertion was corrected from disassembly, without editing Core or expected
snapshots. Actual menu frame1000df08 comes from loading body1000e9bc, not the
old supplied1000df48. Next continue this own state/resources into dispatch
429e5a/431d10 and selection. Phase0/paused/AI retain their older bounded proof;
animated loading, full41bc90 ret/held clear, other selectors, app/UI/full match
and Windows remain open. R02.1/R01.2/full-game goal are not complete.
Old MenuLoading XCTest passed2checks/174.457s; release NTSDCatalogCheck builds
75.70s/46.90s after the ABI fix, accept0.18s, release NTSDNative2.88s.
Both new startup XCTest passed in172.401s;4old/new checks total346.858s.
All90old fixture hashes are unchanged; both new raw/packed SHA/length/full
unpack checks passed,92pins at build/research/menu-startup-fixture-pins.json.
Primary raw/packed546495/346002bytes, control564383/335670bytes. No SwiftPM
or source-capture process remained active before the milestone commit.

The [shared menu input and mode transitions](docs/research/MODE_SELECTION.md)
now execute all431b70 and keyboard4322ad..4328f8 independently with real
401a30/423910/43ef50/4019b0. Both raw/packed corpora match native:2690cases,
3626events/4318helper returns/40350records/176765280bytes+masks. These are
explicit caller-state probes, NOT continuation of the own MENU_STARTUP CPU.
Menu10/431d10 selects MODE before characters; CHAR* resource names do not
establish screen semantics. Caller429eb2 passes target,menu44d020,mode451160,
selection4512c8; the last argument is not mode. Common431b70 reads eight World
pointers regardless of activity/status/Object. Button priority is cd,ce,d0,cf,
d1,d2,d3; each seat's DWORD451320 latch blocks any further edge until all seven
bytes are zero. Nonzero bytes/latches need not be1, and Actor aliases do not
merge seat latches. Native OriginalMenuInput implements this shared mechanism.
OriginalModeSelection handles sequential up/down, signed wrapped remainder,
network Int8>0 skip6 and confirmation. Its46 playback probes stop BEFORE43249c;
no reset/file dialog/load success is invented. Quit calls ONLY4019b0, then
PostQuitMessage(0) iff458434==0. It preserves music/replay, unlike the earlier
composed shutdown. Shared releaseSoundDevice and releaseBackground were factored
from OriginalMenuPresentation; old callers retain their original sequences.
Native comparison retains all raw Actor/World/globals, bitmap/replay storage,
masks/liveness and events; expected after-states are never inputs. Source write
traces are retained, but native checkpoints are whole probe exits, not every
machine write. No CRT DLL or actual OS output is involved in this corpus.
Next continue the OWN429e5a through WHOLE431d10 with original rendering/panel/
key-name422b00/help/mouse/ret16, then character selection and selected match.
Do not replace that own state with these standalone inputs. Enabled423b00 and
playback431c70/GetOpenFileNameA/43e620/43dfa0 remain dependencies; empty stubs
cannot close them.422b00 ends at422f59 (S only); full-screen/UI/W/R02.1 goal open.
Six targeted XCTest passed in23.563s (new mode7.957s, old completion8.122s,
old repeated loop7.483s). Release CatalogCheck80.83s, accept build0.18s.
Release NTSDNative passed in2.84s; all SwiftPM/source/comparison processes were
terminal before the milestone commit. This does not extend Practice gameplay.
All92old fixture hashes unchanged; SHA/size/full unpack of both new files
checked,94pins at build/research/mode-selection-fixture-pins.json.

The [own mode screen](docs/research/MODE_SCREEN.md) now continues the same
startup429e5a through ordinary431d10/ret16. Both632-case corpora match native:
1264cases/1256returns/8playback boundaries,113028events/27570helpers,
1153328records/2323175616bytes+masks after their full verified parents.
OriginalModeScreen composes existing bitmap/text/input/release helpers;
OriginalKeyName covers all422b00..422f59. OriginalMenuBackground factors423840
for both early and mode menus. Retain all own World/400Actors/globals/early
wrappers/context/CRT; raw surface binding and704local bytes/masks are checked.
Only FIRST mode entry is natural; later429e5a callers are explicit probes.
They need EDX1/ECX2 from4297db/de or429e4e/57, not previous helper clobbers.
The inherited early SetColorKey token overlaps old catalog imports; mode
observers yield that inactive domain and rebind Sleep. Both fresh source
passes reproved ALL pinned startup/loading documents/blobs after fixes.
Enabled423b00, worker/status2 children and playback before43249c remain open.
Initial455610 is0: real sound helper calls in this new corpus do not reach
buffer COM; earlier standalone MODE_SELECTION covers declared enabled buffers.
WinMain m_ok loading/device output is NOT proved by this composition.
Next own429eb7→42e0d2/ret12 to4229e2 (actual CALL is4229dd), menu output/
41bc90 ret4→424746 held clear/early epilogue, then full next outer entry and
menu3/1 character selection. See MODE_SCREEN's S-only selection seeds; don't
skip these returns or replace own state with standalone selection inputs.
Application UI, selected match, Windows and full-game goal remain open.
Both new XCTest passed508.404s (control252.595/A5 255.809); six old prefix/
loop/mode-selection checks passed18.008s. Release CatalogCheck51.41s, accept
build0.18s, debug2.87s, NTSDNative3.03s. All processes terminal before commit.
All94old fixture hashes unchanged; two new SHA/size/full-unpack checks passed,
96pins at build/research/mode-screen-fixture-pins.json. No Core rule or expected
snapshot was changed to accommodate the diagnostic ABI/observer failures.

The [own menu return](docs/research/MENU_RETURN.md) now continues the first
431d10/ret16 through429730/ret12,41bc90/ret4 and4246b0/ret4 on the same CPU,
stack and owned World. Both95-case corpora match native:190cases/386checkpoints,
1142events/586helpers,164926records/297470304bytes+masks after checked parents.
Only the FIRST case per corpus executes all nested epilogues. Later4229e2
output probes stop BEFORE422a95; do not claim reconstructed outer frames/SEH.
Source freshly reproduces ALL loading/startup documents/blobs and the FIRST
pinned mode case/blobs; native still compares the whole632-case mode parent.
OriginalMenuReturn uses shared fill/bitmap/text/overlay/present helpers.
Network notice requires signed44d058>0 and Int8(44f1af)>0, decrements after text.
Menu0 alone writes451158=0 then timer451154. Held457580 clears only424746 after
the real41bc90 return; no cursor/44d060/second present is inserted there.
Five volume-control slots45560c..1c explicitly use own first common WAV buffers;
initial WinMain assignment is still open. GDI observer now uses the same VM's
cached cstr reader for original rdata; source was freshly rerun after that fix.
Next run WHOLE4246b0/World2->41bc90 using this own first return. Preserve actual
phase switching/pause/input/control, including phase0 Winsock calls with
network0. Confirm VS through real input, then reach menu3/1 character selection;
do not skip to standalone selection inputs. App UI/full tick/Windows stay open.
Both new release XCTest passed25.434s, two old completion debug tests8.532s.
Release CatalogCheck83.08s, acceptance0.19s, NTSDNative2.79s. All processes
terminal. All96old fixture hashes unchanged; both new SHA/size/full unpack
verified,98pins at build/research/menu-return-fixture-pins.json.

## Progress estimates

Use [tools/estimate_port_progress.py](tools/estimate_port_progress.py) when
estimating remaining work from code volume. It reads pinned Git revisions and
the original EXE, verifies its hash, unions documented native address ranges
without double counting, and reports historical growth, instruction/conditional
counts and planning scenarios. It requires Python 3 and Xcode's llvm-objdump.
It does not execute the game or change accepted research fixtures.

Read the [method and limitations](docs/estimates/2026-09-08-code-progress.md).
The [initial JSON](docs/estimates/2026-09-08-code-progress.json) records the
2026-09-08 c2c2c91 snapshot. Reproduce it with:

```sh
python3 tools/estimate_port_progress.py --revision c2c2c91
```

For a new estimate, explicitly pass the target commit with `--revision` and a
new dated JSON path with `--output`; defaults reproduce the historical snapshot.
Review the script's SUPPLEMENTS/WHOLE scope lists as new studies appear and
recompute the entire timeline when selection rules change. Keep old reports.
Documented range area is NOT branch coverage, semantic analysis coverage,
native equivalence or percentage of game completion. Unsupported paths can
remain inside counted ranges; implemented rules can lack range annotations.
Report measured rates separately from assumed slowdown/integration allowances,
and distinguish continuous hours from working days. The initial 50% allowance
and 2x risk slowdown are planning assumptions, not measured costs or a deadline.
These estimates do not replace RESEARCH_MAP.md or change the research sequence.

The [own repeated menu cycle](docs/research/MENU_CYCLE.md) now continues the
own first return through new4246b0/World2->41bc90 calls. Both4-case corpora match
native:8outer entries/6whole ret4,110checkpoints/546events,40076records/
59398312bytes+masks. Last entry per corpus stops429e5a with own menu3; it does
NOT execute the character-selection dispatcher/body yet. Phase0/1/0/1 comes
from real prologues. Only acquired keyboard J100/117 is supplied, resolved
from OWN control.txt; no Actor/menu/phase/loaded-state stimuli. Four asyncSelect
and four ioctl calls per corpus remain even with network0. Press during phase1
is applied only next phase0; release during final phase1 leaves Actor+d1=1.
Do not clear that current attack before next selection. Six whole returns keep
the actual nested frames/cookies/SEH and restore outer nonvolatile registers.
OriginalLoadedMatchCycle composes existing prologue/command/entry rules; menus
still use shared music/resources/mode/return. Reference compareCases extracts
old checks unchanged and passes own state onward; full95return/632mode parents
still compare after onFirst. Source repeats all loading/startup documents/blobs
and FIRST mode/return cases, not every old standalone probe. A cached translated
block crossed local-input until41c5e5 in the first diagnostic; explicit code
stop fixed the observer. Both complete fresh source passes then succeeded;
Core rules and expected after-state were not changed to hide that failure.
Two old release tests25.443s and two new24.291s passed. Release CatalogCheck
57.91s, acceptance0.19s, NTSDNative34.24s; all processes terminal. All98old fixture
hashes unchanged, new SHA/size/full unpack checked,100pins at
build/research/menu-cycle-fixture-pins.json. Next own429e5a->429f09/menu3->menu1
and character selection using retained menu bitmap; then selected arena/match.
New S-only left/up/attack/jump/latch and roster seeds are in MENU_CYCLE.md.
Application UI/full match/Windows/full-game goal remain open.

The [own character screen](docs/research/CHARACTER_SCREEN.md) now continues
MENU_CYCLE's own429e5a/menu3 through initialization and human-seat selection.
Both34-frame corpora match Native:68screens/68whole nested returns,66NEW
outer4246b0 entries,1816checkpoints/11382events/2428helpers,719848records/
965357588bytes+masks. The first screen completes the last entry already
counted in MENU_CYCLE; do not double-count it as a new outer call. Only acquired
keyboard100/117 from OWN control.txt selects Naruto17/Sasuke21 and team/ready;
no Actor/menu/phase/status/Object-binding stimuli. Generic Core traverses the
catalog by ordinal/type/source-ID gate; no character-name/ID selection handler.
Human status0/1/2/3 can fall through in the same frame. Ready status3 clears
latch when jump is absent, even after status2 confirmed with held attack.
All8 World activity bytes are rewritten after each seat,400 team fields are
checked before rendering. Portraits use own catalog bitmaps/name tails and
all raw read/clip/Blt events match, including undefined constructor fields.
Catalog tracker readsBeforeWrites belong to the character stage; do not carry
them into the next input guard. This metadata covers catalog allocations,
while draw events cover BOTH catalog and menu allocations. The first source
diagnostics failed that scope boundary after9 frames; both fresh retries
reproved all parents/34 frames. First Native acceptance also corrected only
the metadata comparison scope. Core rules/expected snapshots were unchanged.
Both9-frame diagnostic native prefixes matched; old2release MENU_CYCLE tests
passed25.187s/build87.59s, new2character tests28.747s/build87.12s. Release
CatalogCheck55.57s, final acceptance reference build53.89s, NTSDNative32.46s.
All source/SwiftPM/comparison jobs terminal. All100old fixture hashes unchanged,
both new raw/packed SHA/size/full unpack checked;102pins at
build/research/character-screen-fixture-pins.json. Last own complete return:
World2/menu1/mode0,selection0,countdown147,pulse4,selected17/21,status3/3,
team0/0,latch0/0,current attack released afterphase0. Continue that own World
through real outer calls/countdown (or actual jump acceleration), then computer
count42b296/arena/settings/preparation. Do NOT set selection1/countdown0 by hand.
Alternative modes, left/up/jump/team-exclusion/countdown boundaries have S
rules but need wider D. WinMain five menu-sound loads are still S; initial
slots remain0 in this chain. App UI/full match/Windows/full-game goal stay open.


The [own match selection](docs/research/MATCH_SELECTION.md) now continues
CHARACTER_SCREEN's own complete return through countdown/jump, zero computers,
VS settings/District and Start BEFORE42cf8a. Both fresh50-frame passes match
native:100NEW whole4246b0 entries/98whole nested returns/2prelude boundaries,
3026checkpoints/16840events/3516helpers,1203502records/1589446344bytes+masks.
Only acquired keyboard bytes from own control.txt are supplied; no countdown/
selection/Actor/menu/RNG stimuli. All full34-frame character and earlier parents
are revalidated. Native OriginalMatchSelection composes the existing human
screen, bitmap/text/fill/sound, generic random roster and continueMenu.
The same roster candidate method now serves old continuation and computer-count
confirmation: inactive seats also consume RNG and exclude their selected ordinal.
Each pass has6tagd7 draws followed by29tag1 music draws.402130 Random consumes
RNG EVERY settings frame, even without input. OriginalMusicConfiguration retains
path/label tails; OFF/Stage/manual choices have S rules and need wider D.
OriginalMusicPlayback.stop factors the previously verified round402100 helper.
Computer count D is min0/max6/confirmation0; positive CPUs, alternate modes and
other selector edges remain explicit open domains, not missing-character hacks.
Current native runner rejects unconnected CPU bodies and reselection/reroll
caller locals. Those old standalone commands remain implemented/verified.
Source prefix fill observer now accepts an optional validated rectangle;
new caller checks four popup borders by returnPC/ESI. Both first diagnostics
stopped there after18 complete new frames; both full retries re-executed ALL
parents and50 frames. No expected snapshots or Core rules were changed to
hide that failure. Both18-frame native diagnostic prefixes also matched.
CharacterScreenReference.compareCases/onLast preserves the whole old comparison;
raw UInt32 locals decode as signed, including+28=-1. Five old release tests
passed77.301s/build91.95s; two new tests35.904s/build90.17s, total7checks/113.205s.
Release CatalogCheck92.61s, acceptance build88.05s, finalNTSDNative34.23s.
All source/SwiftPM/comparison jobs terminal. All102old fixture hashes unchanged;
new SHA/size/full raw-packed JSON equality checked,104pins at
build/research/match-selection-fixture-pins.json. Last OWN42cf8a: World2/menu1/
mode0,selection3,option0,CPU0,District0/random0,countdown-53,pulse24; selected
17,21,24,38,39,32,22,36, only first2status3/activity1/team0; phase0attack held,
latches1/0. RNG index35/counter35, choice0/lastpath bgm\boss2.wma. Continue this
own state through prelude, full preparation with enabled4025b0->402020,43d2c0,
whole return and next full outer gameplay entry. Do not disable music or reset
RNG/selection to bypass missing composition. App UI/first full match/Windows/
clean macOS and the full-game goal remain open.

The [own match launch](docs/research/MATCH_LAUNCH.md) now continues the same
Start42cf8a through prelude, full preparation with enabled4025b0/402020,
43d2c0/43d280, remaining menu, ALL nested returns and next whole4246b0
BEFORE41e339 gameplay. Both fresh8-section corpora match Native:16sections,
45194records/397633900bytes+masks,900events/862launch-music-return helpers/
50checkpoints. The next local/received/recording helper ABI is also checked.
The two Start returns complete entries already counted in MATCH_SELECTION;
only the subsequent two4246b0 entries are new, and neither returns yet.
Full50match/34character/4cycle parents are reproved; source mode/return uses
FIRST own cases while Native still checks full632/95case parents. No game-state
stimuli after the prior acquired keyboard. OS time/device/allocator/caller
inputs stay explicit. Prelude's2sprintf run on the same CPU/DLL; music graph.log
uses the older separate pinned CRT boundary. Actual Windows binding stays open.
Shared prepare now exposes its music continuation with own RNG committed before
that child. Shared4025b0 reads own44eed0 and invokes existing402020. No character
handler added. Ten initial HUD/score/PAUSE bitmap resources now survive in
OriginalMatchPreparation.interface from their own loading, and all bytes/masks
are checked with catalog/new layers. Fifteen District bitmaps load; first2
Actor reconstruct plus380inactive20..399 and shared431c70. Spawn x442/289,
y0/0,z504/519,team10/11,HP500/500. RNG35/35->39/39, then recording counter0/index39.
Own calloc630e18 at72000020 joins context memory; ALL18 Actor arrays include
inactive random bindings. Native recording gets the same owned catalog through
its state overload. No replay metadata is supplied.450b8c resets88->0; name
20260909_123456_VS.lfr comes from declared SYSTEMTIME. Whole return has
SP1000f42c/restored SEH/registers/held0. Next phase1 records10zero command bytes,
checksum1000 atbuffer+14b8 andtick1 before41e339/SP1000e9bc,World2/menu0/mode0.
Both first diagnostics stopped at43d280 because the new instruction guard
omitted its unconditional null-pointer helper entry. Guard fixed; post-music
sprintf binding restored for the shared output observer. BOTH fresh retries
re-executed all parents and full8. No Core rule or expected snapshot changed to
hide observer failures. Both4-section diagnostic native prefixes, raw a5 full
and both packed full comparisons passed. Old6release tests87.819s/build97.16s;
new2tests36.288s/build91.75s;8checks total124.107s. CatalogCheck builds93.36/
93.88/57.65s,accept0.18s,NTSDNative2.81s. All processes terminal.104oldfixture
hashes unchanged; two new raw/packed SHA/size/full JSON checked,106pins at
build/research/match-launch-fixture-pins.json. Read this study before continuing.
NEXT: retain this OWN41e339 state and full replay/resource ownership into the
whole active-slot413080 caller41e339..41e62e, then physics/contact/link/draw/
scheduler/recovery and complete first tick. Do not substitute old Practice's
bounded composition, phase0 caller, supplied replay RNG or synthetic actor state.
WinMain sounds, other CPUs/modes, app/UI, full match, Windows/clean macOS and
R02.1/R01.2/full-game goal remain open.

The [generic Actor input](docs/research/ACTOR_INPUT.md) now implements
413080..4132ef and real40e170/40e2d0/40e450/412800..413077 rules on full raw
Actor/Frame storage.14,624 synthetic source probes match Native,30,885,888
Actor bytes/masks:112edges,4608invalidation,384transfers,7484combos,500DAT
priorities,1536continuous prefixes. These are declared synthetic frames, NOT
all original DAT transitions or whole gameplay. No character/technique allowlist.
Public OriginalActorInput.apply takes the actual loaded Object; unconnected
OriginalFighter Practice retains its old bounded logic until whole control joins.
Read the study before extending input. PositiveSIGNED bytes decay; exact0->1
edges shift five32-bit history words408..418 with R/L/U/D/Df/J/A codes6/4/8/2/9/0/5.
All9recognizers are sequential and later ones read the new current frame/buffers.
StrictSIGNED hit_a/d/j priorities allow0 above two negatives; ties skip. Transfers
check target presence, abs/999 and original cost, with wrapping statistics.
Negative target turns ONLY on successful resource-enabled branch. Directional
combo facing/progress resets also follow failed attempts. Original ID6/hit_ja300/
HP>177/458428==0 preserves progress3; keep this documented source exception.
Initial Swift build fixed try placement; first differential comparison passed
5.493s/build94.47s. Fresh acceptance reproduced identical raw SHA and passed
5.470s/build33.93s after preserving MP-before-HP read order. Packed fixture+
rollback passed5.336s; releaseNTSDNative34.14s. All jobs terminal.106oldfixtures
unchanged; raw/packed SHA/size/full JSON equality verified;107pins retained at
build/research/actor-input-fixture-pins.json. This does not complete R04.1:
original-file transition sequences, remaining control and full match stay open.
The new source-only oracle_gameplay_entry.py separately re-executes ALL own
MATCH_LAUNCH/selection/character parents on the same CPU/stack/World/resources,
then whole413080 caller41e339..41e634 and physics caller through41eed1. Both
fresh passes succeeded first try:each20control/2physics helpers,12checkpoints,
387/270unique instructions, no tracked catalog reads-before-writes. First empty
control preserves ALL state; ctorvelocities0.1 then produce x/z442.1/504.1 and
289.1/519.1, integer positions unchanged, y/velocities0 and frame219 BOTH actors.
HP500/MP200,RNG39/0,phase1,tick1/replay/resources retained. EndSP1000e9bc BEFORE
initial Z/contact passes; same unreturned outer entry, no new outer call counted.
Both source reports are docs/evidence/gameplay-entry{,-control}.json with
nativeCompared=false; raw captures remain build/original. No expected state
injection/native whole-pass claim. Source-only continuation does not supersede
MATCH_LAUNCH's accepted Native boundary41e339. NEXT native:use generic input
component and recover whole4132ef..4143cb, control caller400/401/500/501, then
physics/contact/link/draw/scheduler/recovery and full first tick, preserving own
launch state. Do not zero constructor velocities or substitute Practice RNG.
App/UI, Windows, clean Mac and full-game goal remain open.

The [whole Actor control](docs/research/ACTOR_CONTROL.md) now implements
413080..4143cb/ret8 in OriginalActorControl, reusing OriginalActorInput and
OriginalRandom. It includes ordinary/heavy walking/running, air attacks,
crouch dash, recovery rolls, dash turns/attacks and DAT velocity assignments.
No per-character/technique allowlist. Actor+98 is carried-kind, not source ID.
Two original caller args are accepted but unused by this EXE's control body.
The frame/global ownership is explicit; public apply takes loaded Object and
inout raw Actor/globals. withoutActuallyEscaping confines internal callbacks.
OriginalGameplaySound.queueBuiltin implements actual417090 accumulation before
later device output, with signed wrapping coordinates/counters and flag-based
reset. Index7 is the new D domain; no audio-device output is claimed.
The complete function matches25,795 synthetic cases,1999unique instructions,
900RNG/2772sound requests. ALL42 original type0 Objects additionally match
5376frame0/128-input cases,1343instructions/1487RNG/no sound requests. Source
restores unmodified pinned LOADED_CATALOG Object bytes/masks and checks source
DAT hashes; Native rebuilds/checks ALL137Objects then uses its own loaded data.
Both probe callers remain synthetic; this is not a natural selected match.
Full Actor bytes/masks total65,833,152 plus SHA of all1,438,354,624global bytes
and ordered events. All calls use real input/RNG/sound helpers and actual ret8;
no Actor/Object undefined reads in the original-file corpus. Other source types,
all frames/sequences, nonfinite/x87 rounding domains remain open.
First Native comparisons passed10.336s/build89.69s and7.866s/build5.11s. After
factoring source Object access, a fresh synthetic execution reproduced exactly
the same118,111,274-byte raw SHA. Both packed corpora, rollback AFTER RNG and
old ActorInput passed5tests/22.845s. NTSDNative built33.48s. All jobs terminal.
All107old fixtures unchanged; both new SHA/size/full raw-packed JSON verified,
109pins at build/research/actor-control-fixture-pins.json.
Preserve distinct cost branches: standing/air attacks use WHOLE mp with zero
clamp/no statistic on exhaustion; run/dash require funds; superPunch70 skips
that cost. Later jump/defend may replace an already paid attack. Crouch215 uses
vx>0.001 or vx<-0.001; dash attack requires STRICT vx sign, not zero. Retain
sequential two-direction dash/sound accumulation and original roll thresholds.
NEXT: join this function with OWN MATCH_LAUNCH state through400-slot caller
41e339..41e634 including403270 and400/401/500/501, then physics/contact/link/
draw/scheduler/recovery and full tick. Existing source GAMEPLAY_ENTRY reached
41eed1, but Native still stops41e339 at the accepted whole-parent boundary.
Do not inject its expected after-state or zero ctorvelocities0.1/frame219.
Practice/app integration, Windows, clean Mac and full-game goal remain open.

The [whole World control pass](docs/research/WORLD_CONTROL.md) now continues
both own MATCH_LAUNCH states through41e339..41e634 with shared413080 and full
403270 teleport plus400/401/500/501 rules.1491 synthetic caller cases match
all424408 pool bytes/masks and46144 globals plus ordered RNG/sound events;
45461 original helper returns/949 unique executed instructions. These are
explicit synthetic Objects/Actor/globals, not natural DAT coverage. Both own
launch chains also match full pool/resources/CRT/music/replay before/after
control and the two413080 returns, without expected-state injection. Raw
GAMEPLAY_ENTRY and its accepted lossless control fixtures retain a following
physics section: it is explicitly NOT compared by this new control check.
MatchLaunchReference.compare(gameplayControl:) checks only through41e634.
No new per-character handlers. World actor-table ordinals support aliasing;
source IDs and registry ordinals remain separate, including duplicate IDs.
State must be reloaded after each400/401/500/501 block. Linked slots already
visited get no second control; later ones use the changed Object in the same
pass. Whole control pool/globals roll back on unsupported paths; external
observers must buffer events until the whole tick commits. Read the study
before extending. Next is all40e490 and its41e634..41eed1 caller, then contacts,
rendering/scheduling and whole tick return. Preserve own constructor velocities
0.1 and source first landing frame219. App UI, Windows, clean Mac and the
full-game goal remain open.

The [whole Actor physics](docs/research/ACTOR_PHYSICS.md) now implements all
40e490..40ef6a on raw Actor/loaded Frame/Object/globals.9344 synthetic probes
and46089 cases across ALL15363 present frames/137 original Objects match.
Catalog inputs use three declared motion states per frame, NOT continuous
techniques. Native rebuilds/checks its complete loaded catalog before physics.
OriginalExtended provides finite64-bit-significand arithmetic with explicit
binary64 stores, nearest/ties-even CW037f. No CPU/instruction/EXE emulation in
runtime. Other CW/nonfinite/80-bit overflow/actual Windows startup FPU stay open.
4450d0's legacy/SSE2 finite conversion paths are explicit;45971c is OUTSIDE the
main globals snapshot. Own World captures use legacy0. Type/ID101/120/124/999
branches come from the EXE, not a character allowlist. Negative friction compares
its intermediate against POSITIVE epsilon; fallHurt<0 chooses182 only for
vy STRICTLY<12 and450bd0>=6. Frame212 landing requires storedy>0 andvy==0.
Catalog416fb0 shares the proved stereo rule with417090, distinct tables; old
ActorControl/WorldControl source recaptures reproduced identical full raw SHA.
The [whole World physics](docs/research/WORLD_PHYSICS.md) now implements
41e634..41eed1: real40e490 plus death/respawn/spawn998/reversion.515 synthetic
cases compare ALL400-slot pool bytes/masks, globals and ordered events,8329
helper returns. Active!=0 gets physics; respawn averaging needs EXACT1, type0,
same team and NOHP filter, excluding current slot, with wrapped integer sums.
RNG144/51 precedes average division; x subtracts26, then145/31 andz subtracts16.
No eligible ally faults at41eb98 AFTER first RNG/lives decrement; --fault keeps
source-only evidence, Native throws with whole-pool/global rollback. Events
must be buffered until caller/tick commit. Source-ID30..36 revival sets318=140.
Spawn998 assigns frame6 to CREATED ESI slot, current revival stays219. Initial
Native mismatch in four nonalias cases corrected this ESI/EDI distinction;
expected corpus unchanged. Integerz+1/binaryz unchanged, ctor unknown masks,
exact World aliases and ascending newly activated later slots are preserved.
Reversion clearsDC before lookup, even missing ID/count; state9998 deactivation
still continues reversion. Source IDs differ from catalog ordinals.
Both own MATCH_LAUNCH chains now compare through control AND physics41eed1,
56330records/512207004bytes+masks,906helpers/58checkpoints including retained
launch/control sections. New physics contributes4helper returns/4Actor returns.
Ctorvelocities0.1 naturally produce frame219, x/z442.1/504.1 and289.1/519.1,
y/velocities0,HP500/MP200,RNG39/0,phase1/tick1. Full854bitmap/101BG/music/CRT/
replay630e18 ownership survives. No expected-state injection or new outerentry;
4246b0 remains unreturned atSP1000e9bc BEFORE417f80/Z/contact. Historical
GAMEPLAY_ENTRY reports stay source-only; old control checks still stop41e634.
New physics fixtures compare BOTH sections, opt-in gameplayPhysics:true.
Raw acceptance6tests/64.517s/build97.67s passed. New packed corpora and retained
ActorInput/Control, WorldControl, GameplayControl and MATCH_LAUNCH passed together:
17release XCTest/161.849s/build98.21s, including four rollback checks. This build
also compiled/linked NTSDNative; no new UI/Windows claim. All jobs terminal.
All112old fixtures unchanged; five new raw/packed SHA/size/full JSON equality
checked,117pins at build/research/world-physics-fixture-pins.json. Read both
physics studies before extending. NEXT: same OWN41eed1 through417f80, contact/
item passes, linked objects, draw/camera/scheduler/recovery and full tick return.
Practice/UI, other CPUs/modes, first full match, Windows/clean Mac and entire
goal remain open.

The [whole depth/held-object function](docs/research/WORLD_LINKS.md) now
implements all417f80..4187a3, not just the old Z slice. Two400-slot passes:
active!=0/type0 clamps BG+4 then+8 and converts integerz; active!=0/Actor98<0
validates unsignedA0<=399, active owner and owner9c==current slot, then places,
consumes or throws held objects. Failure clears ONLY98. Keeps exact World
aliases/ascending order. Owner wpoint references its old Frame while later
centers use CURRENT Frames after weaponact, including aliases. Cover0 gives
z+1/y-1, other cover z-1/y+1. State12/10 drop still continues explicit throw/
kind3; binaryy<=-2 update does NOT refresh integery. Up/down use nonzero bytes,
both/neither preservevz. Ordinary throws clear98 but leave9c/A0. Generic DAT
mechanism, no character allowlist. Source ID122/123 consuming exceptions are
proved EXE branches:122 decrements HP1, signed%5/%6 restore ownerHP/MP;123
subtractsHP2/addsownerMP3, then tests ITEM owner2f4>-1 and ITEM MP>150 before
assigning OWNER MP150, not min/clamp. Exhaustion zeros both98/owner9c/itemA0,
itemframe0/vy-8, RNG136/137 forvx; ownerframe0/item31c0. State12/10 RNG138,
type2 RNG139, finalkind3 RNG140..143 preserve order even when overwriting.
Divisions reuse finite OriginalExtended; shared OriginalCoordinateConversion
factors the previously proved legacy/SSE2 ftol2 without changing its rule.
3018 synthetic full-pool cases match FIRST Native comparison:6922helpers/
588unique instructions/3878RNG, entire424408pool bytes+masks/46144globals.
Rollback after depth/placement/RNG passes. Declared synthetic DAT/Actors/BG,
CW037f and31c20, not all natural weapon/technique sequences. Separate pinned
DAT survey checks42type0 Objects/10041present Frames/688wpoint values;41frames
have weaponact-888/1000/9998 outside400-frame array. Source paths/IDs/frames
are recorded in world-links-dat.json. No repair/coercion; actual reachability
and backing-memory behavior stay open. It is a data inventory, not execution.
Both fresh own source runs reproduced entire MATCH_LAUNCH/GAMEPLAY_ENTRY on
same CPU/stack and continued through41eed3/417f80 to41eed8,3helpers/2depth
checkpoints/100instructions each,0catalog reads-before-writes. Both own Native
chains match, retaining pool/globals/CRT/early resources/101BG/854bitmaps/music/
fullreplay630e18. Own first417f80 has no held item and preserves postphysics
state,frame219,HP500/MP200,RNG39/0,phase1/tick1. New source cases have no game
stimuli/expected-state injection. Whole4246b0 still unreturned,SP1000e9bc.
Native own checks36.621s/build102.31s,61898records/569493556bytes+masks,
912helpers/62checkpoints including parents; newstage6helpers/4Actorchecks.
New packed fixtures and prior Actor/World physics, GAMEPLAY_CONTROL/PHYSICS/
MATCH_LAUNCH plus both rollback checks passed14release XCTest/178.394s,
build103.59s also compiled/linked NTSDNative. All source/Swift jobs terminal.
117oldfixtures unchanged;3new raw/packed SHA/size/full JSON verified,120pins
at build/research/gameplay-links-fixture-pins.json. Historical physics/control
stops/scopes remain unchanged. Read WORLD_LINKS before extending. NEXT own
41eed8:44d05c==2 caller/full419380 contact collection, type-separated42e100
with item-spawn between, remainingcpoint/link helpers/second417f80/draw/camera/
scheduler/recovery and full tick return. Practice/UI, Windows/cleanMac,
continuous gameplay, first full match and complete goal remain open.

The [whole contact collection](docs/research/WORLD_CONTACTS.md) now implements
caller41eed8..41eefb, all419380/417200/417400/4171c0 and mandatory4064d0 tail.
Caller44d05c==2 resets0 and skips EVERYTHING including fusion cooldowns.
Otherwise400-slot prefix copies70->7c; resetsEC foritrCount0 orstate1001 whose
owner currentwpointE8==0, without417f80 reciprocal/activity validation. Ascending
active!=0 pairs decrement positive SIGNED Int8 vrest in BOTH directions, then
broad/pair i->j and j->i with live state/World aliases. Broad counts use current70,
bounds/centers usecollision7c; effect2/20/21 also readseparate78. Rectangle4171c0
uses strict signed WRAPPED differences. Full417400 retains entry Frame pointers,
reads actual raw80-byte ITR/40-byte BDY via mask-checked native Frame allocations,
never host pointers/projected sanitized boxes. DAT kinds/effects/team/owner/mode
filters, source-ID exceptions200/203/205/206/207/215/216/209/212 and201/202, depth,
nearest/multiple buffers2e4/2e8/2ec, signed distances and RNG133/134 follow EXE.
Negative counts can write earlier bytes WITHIN Actor; unknown/out-of-extent
storage throws. No new per-character allowlist. This COLLECTS, not resolves hits.
4064d0 scans20 slots; positive338 decrements eveninactive, fusion activityEXACT1.
ID7/8->51 uses original HP177/cooldown/state/distance/team gates and firstcatalog
51, preserves wrapped/clamped resources, zeros OWNvx/OTHERvy, averagesix/z,
saves IDs/owner/cooldown4500 and continues scanning afterdeactivation. Unfusion
51/328==1/frame<9or>260/338<=0 scans ALL catalog, first branch330 andelse334,
reconstructs everyduplicate334 with real4061d0, preserves constructor masks;
missingIDs/aliases still run sequential HP/redHP halves,frame112/MP0/team/facing.
7925 synthetic cases match full424408 pool bytes/masks and46144globals,188787
real helper returns/1578 unique instructions/3737 ordered RNG/constructor events.
All instructions of four main bodies reached except skippedalignment41960d;
NOT all branch outcomes, arbitrary storage or natural DAT/gameplay coverage.
First6640 Native5.164s/build106.98s; directed expansion from source instruction
inventory adds mirror/gates/held distance/prefix lanes/clamps/caller controls.
Two fresh own source runs reproduced all GAMEPLAY_LINKS parents on same CPU/stack,
then continued through419380/4064d0 to41eefb,4helpers/163instructions each,
0undefinedcatalog reads. Only ownActor7c0->219 forNaruto/Sasuke changes inpool;
masks/globals/CRT/earlyresources/101BG/854bitmaps/music/replay630e18 unchanged.
Native own comparison36.749s;67462records/626775884bytes+masks/920helpers/
66checkpoints WITH parents. Newstage8helpers, no own contact/constructor/RNG
events. Joined raw5tests42.869s/build105.97s passed, including failure AFTER
prefix/actualRNG with wholeWorld/pool/global rollback and rawheap masks/offsets.
Public caller is atomic; observers buffer events until wholetick commits.
Batch acceptance5tests42.719s/build106.97s then published3 losslessfixtures.
All120oldfixtures unchanged; allnew raw/packedSHA/size/fullJSON verified;
Packed new/retained Actor/World physics, links, GameplayControl/Physics/Links/
Contacts and MatchLaunch passed19release XCTest/220.175s/build107.37s, also
compiled/linkedNTSDNative. Allsource/Swift processes terminal; noUI/W claim.
123pins build/research/gameplay-contacts-fixture-pins.json. Read WORLD_CONTACTS
beforeextending. Same unreturned4246b0/SP1000e9bc,phase1/tick1,frame219,
HP500/MP200,RNG39/0. NEXT own41eefb: type-separated42e100 with itemspawn between,
remainingcpoint/link helpers/second417f80/draw/camera/scheduler/recovery/fulltick.
Practice/UI, natural DAT sequences, Windows/cleanMac, fullmatch/goal remainopen.

The [whole hit resolution and item passes](docs/research/WORLD_HITS.md) now
implement all42e100..431b64 and caller41eefb..41f2ac. First active type0 hits
and live item count1/2/4/6, then conditional RNG146..154/candidates/constructor,
then all active signed-positive types, without a second contact collection.
7845 controlled cases include150 whole callers; full400-slot pool/masks/globals,
262144-byte mutable Frame heap, CRT state and16750 ordered events match Native,
19211actual helpers/3745unique instructions. 3204/3216 instructions of42e100
reached; remaining12 are behind contradictory type gates under readonly Object
storage, not proof of all branches/natural DAT sequences. FiniteCW037f only.
Generic DAT kinds, guards/falls/ID defenses, weapon strength, reflection3005/3006,
catch/pickup/force/obstruction and sparks follow source, no new character list.
Contact count is live; signed Int8 ITR indices and source early gates retain
lazy Frame reads. Frozen collision Frames and live current Frames are distinct.
A held kind5 can keep its raw ITR pointer; type2 halves dvx/dvy IN PLACE, and
repeated calls observe those writes. OriginalMatchPreparation.frameAllocations
now owns this live DAT heap; contacts read it, catalog remains loading evidence.
Allocation order/masks/interior offsets remain explicit, never host pointers.
Legacy4450d0 now accepts finite extended intermediates directly; SSE2 stores
binary64 first. Exact x87 nearest/zero/indefinite shortcut precedes truncation
correction. Full-pool item creation does NOT skip: original retains caller+4c,
native requires its provenance; synthetic full-pool supplies77. Actual outer
scratch lifetime/empty-candidate division fault domain still need evidence.
Both fresh own startup/menu/loading/selection/launch/control/physics/links/
contacts parents reproduced on the same CPU/stack and continued to41f2ac.
Each new stage has3helpers/2hit returns/98instructions, no undefinedcatalog reads.
Native compares all14586 retained Frame allocations before/after. First own
contacts are zero, RNG146/200->64 creates no item; index/counter39/0->40/1.
Frame219,HP500/MP200,postphysics positions, CRT,854bitmaps/101BG/earlyresources/
music/fullreplay630e18 survive. Same unreturned4246b0,SP1000e9bc,phase1/tick1.
Both launch/gameplay continuations report163328records/732256514bytes+masks,
926helpers/72checkpoints including a public rollback trial after actualitemRNG.
Earlier startup/menu/selection parents are revalidated by nested runners;
their counters are NOT included in these totals. World/pool/globals/heap/CRT
publish only on successful whole pass; observers buffer until wholetick commit.
Batch raw acceptance passed3release XCTest/44.422s/build111.55s before publishing
3fixtures. Final packed regression passed22XCTest/262.730s/build111.11s across
Actor/World physics, links, contacts, hits, GameplayControl/Physics/Links/Contacts/
Hits and MatchLaunch; NTSDNative also compiled/linked. All processes terminal.
123oldfixtures unchanged;3new raw/packedSHA/size/fullJSON/blob/parent identities
verified,126pins build/research/gameplay-hits-fixture-pins.json. Python compilation
and diff check passed. Historical parent scopes/stops remain unchanged.
Read WORLD_HITS before extending. NEXT same own41f2ac: whole418c30..419373,
4187b0..418c2f, held-owner cleanup and second417f80 through41f484. First helper
reads entrySP-4 into ESI; invalid reciprocal links can retain a prior slot into
throw paths. Preserve that provenance/slot-loop lifetime, collision7c vs current70,
and ECX retained between the two calls. Then camera/draw/scheduler/recovery and
whole tick return. Practice/app integration, natural DAT sequences, Windows,
clean Mac, first full Naruto/Sasuke District match and full-game goal remain open.

The [whole cpoint and second attachment passes](docs/research/WORLD_CPOINTS.md)
now implement entire418c30..419373/4187b0..418c2f and caller41f2ac..41f484.
Generic DAT cpoint actions/exhaustion/throw/Object substitution, placement/injury,
positive held-owner cleanup and shared second417f80; no new character-ID list.
2681 controlled cases match full400-slot pool/World/masks/globals,978nested helper
returns/176ordered RNG events/1274unique instructions. All446instructions of
418c30,266/267of4187b0 (onlyalignment4187c9 skipped) and118caller instructions
reached; not all branch outcomes, arbitrary backing or natural DAT sequences.
418c30 starts from collision7c and retains originalcpoint across action changes;
4187b0 requires CURRENT70kind1/state9 and current partnerkind2. Partneractivity/
type gates are absent. ESI partner survives400slots and can remain from entrySP-4
or an earlier reciprocal comparison on broken-link throw paths. Native optional
retainedPartnerSlot must be supplied when dereferenced; no substitutedActor8c.
Full outertick scratch provenance remains open. Positive decrease subtracts94;
negative adds and has a separate exhaustion branch with pendingX±4/Y-3/frame181.
Attack, directionalattack, jump run sequentially; negativeframe flips facing and
wrap-negates, partnerframe uses NEW captorframe vaction. Frozen cpoint remains.
Nonzero throwvx still runs after broken links. throwinjury-1 saves324/33c IDs,
rebinds own368, then all active2f4==slot Objects using LIVE partnerObject reads.
Placement uses live centers but caught cpoint from raw signed vaction, evenafter
currentframe abs. Controlled-1..-5 address Objectheader; known extent/masks are
preserved, unknown backing throws. Cover uses signed quotient/remainder10,
facing changes AFTER geometry; binaryz/x/y refreshed in sourceorder. No cpoint
normalization or proposed gameplay correction. Cleanup clearsONLYowner98.
DAT survey checksall137Objects/15363presentFrames,239cpoint values,775kind1/
650kind2. All observedvactions0..<400; undefinedc4/c8 words remain null. ID419
chars/chiyo_kunais.dat frame49/state9 has throwvx13 and undefinedthrowvz; exclusive
up/down can read it. Actualreachability/Windows backing remains open, nozero fix.
Both fresh ownGAMEPLAY_HITS parents reproduced entirely on sameCPU/stack, then
four sections to41f484,5helpers/2depthchecks perchain,0undefinedcatalog reads.
First owncpoint/heldlinks absent; allbefore/after states identical, including
14586Frame allocations,CRT/854bitmaps/101BG/earlyresources/music/fullreplay630e18.
Native chains report418964records/1013531154bytes+masks/936helpers/88checkpoints
in launch/gameplay; earlier startup/menu/selection revalidated separately by
nested runners, counters NOT included in those totals. First raw3tests40.063s/
build111.04s passed. Public trial clears an invalidpositiveheldlink, thenthrows;
originalActor/globalstate preserved. Entire public4-stage pass publishesonly
on success; observers buffer until wholetickcommit. Batchacceptance3tests40.005s/
build115.00s precedes3losslessfixtures.126oldfixtureSHAsunchanged;3newraw/packed
SHA/size/fullJSON/blobs/parents independentlyverified,129pins saved at
build/research/gameplay-cpoints-fixture-pins.json. Final packed regression
passed25release XCTest/303.164s/build113.91s across Actor/World physics, World
links/contacts/hits/cpoints, GameplayControl/Physics/Links/Contacts/Hits/CPoints
and MatchLaunch. NTSDNative also compiled/linked; no app-window/device claim.
Python compilation and staged diff check passed; all source/Swift jobs terminal.
Read WORLD_CPOINTS beforeextending. Same unreturned4246b0/SP1000e9bc,phase1/tick1,
frame219,HP500/MP200,RNG40/1. NEXT own41f484: full41b5d0 including actual41a250
background child (oldcamera slice stops41bc74), then whole41a5a0 actor drawing,
modebranches/scheduler/recovery/creation/deletion/fulltickreturn. Appintegration,
continuous DAT, Windows/device output, cleanMac and fullmatch/fullgame stayopen.

The [whole camera/background call](docs/research/WORLD_CAMERA.md) now implements
41b5d0..41bc87 and caller41f484..41f496 with actual41a250/41a050/43f010/43ef70/
415160 children. OriginalWorldCamera owns World/pool/globals/live BG counters
atomically; device requests must be buffered by the enclosing tick. All400 active
slots receive depth/x conversion even after deactivation. Type0 slots<20 use
minimum0 (or−300 forActor364==5), slots>=20 use−100..width+100. Non-type0/non-type3
ID122/123 alone receive10..width−10 whenActor344>0 or mode1/Stage quotient5;
the mode branch is ALSO behind the ID gate. No new per-character list.
Camera prioritizes8 living positive-input seats without type gate, falls back
all400 livingtype0, retains signed facing/wrapped sums and original /14,/7 smoothing.
Clamps are minimum0 THEN maximumwidth−794; negative limits are real original
content (Ramen Place width750). Nonzero450bb0 and positive450bb4 differ.
BG loop/nonloop arithmetic preserves division BEFORE/AFTER animation respectively,
inclusive gates, signed period remainder and counters for skipped layers.
Built-in99, four exact palette remaps and actual fill/bitmap children execute.
Fills useglobal455608; bitmaps usecaller target.415160's92 untouched DDBLTFX bytes
have explicit entry stack backing. Bitmap+0c reads retain undefined provenance.
4742 controlled cases compare fullpool/masks/globals/101BG/masks and6898 ordered
draw/read/clip/Blt/fill events;25950 helper returns. Camera491/491 instructions,
BG209/211 and built-in144/146; four skippedalignment addresses, NOT allbranches
or naturalDAT/fullgame/Windows.1133observed PCs include one declared COM boundary.
FiniteCW037f, legacy/SSE2 coordinate contracts; faults/nonfinite/out-of-record
and nonterminating loops remain outside accepted success corpus. DAT survey
checks302layers/17arenas/175positiveperiods against pinned whole BG loader;
all surveyed fields defined, all302bitmaplayers, nonzero stepspositive.
Both fresh own startup/menu/loading/selection/launch/control/physics/contacts/
hits/cpoints parents reproduced byte-for-byte, then continue on SAME CPU/stack
through41f496/SP1000e9bc. Target28002020 from originalcalleresp+68, mode0.
Each:22helpers,64events/8Blts, camera/velocity0→1 and9Districtcounters0→1;
pool(frame219,HP500/MP200,positions),RNG40/1,CRT/854bitmaps/earlyresources/music/
replay630e18/14586Frameallocations retained.16undefinedbitmap+0c reads each.
Native independent own state matches; public rollback throws at last bitmapBlt.
Both launch/gameplay counters514826records/1119007560bytes with masks,980helpers/
94checkpoints; earlier nested parents also validated but NOT in these counters.
Paired acceptance3release tests43.507s/build118.45s published3losslessfixtures.
129oldfixture hashes unchanged;3newraw/packedSHA/size/fullJSON/2746blobs perown/
parent hashes verified.132pins build/research/gameplay-camera-fixture-pins.json.
Final29release regression tests347.048s/build117.82s passed with retained
Actor/World/bitmap/own gameplay/MatchLaunch suites; NTSDNative compiled/linked.
All source/Swift jobs terminal. Python tools compile; no UI/Windows claim.
NEXT entire41a5a0..41ae50 and40de30..40e160; retain actual40be70 sheet selection,
40bf30 original pic-width lookup and43f310 rectangleBlt, not just43f010 stubs.
Then remaining mode/scheduler/recovery/spawn/deletion/fulltick return. Practice/UI,
continuous DAT sequences, first complete match, Windows/device/cleanMac and
full goal remain open. Read WORLD_CAMERA before extending.

The [whole World/Actor draw](docs/research/WORLD_DRAWING.md) now implements
41a5a0..41ae50,40de30..40e160,40be70..40bf1f,40bf30..40bfa8,43f310..43f37a,
with actual43f010/43ef70 children and cookie/ret12 in source.2679 controlled
cases match full400-slot pool/World/masks/globals/101BG and202262 ordered events;
55874 helpers,1268 PCs. Actor251/251,sheet61/61,width43/43,rectangle38/38 and
World648/663 instructions reached. World misses11 alignment, one unreachable
jump and3 negative-remainder corrections excluded by priorActor8>-70; not
allbranches/naturalDAT/Windows. Source synthetic constructors/metadata/COM.
Generic stable signed-z sort, aliases, sheet ranges with wrapped arithmetic,
normal/mirror wrappers, width from NORMAL unoffsetpic vs drawpic+Actor318;
state9997 clamp0then714; lowHP/bpoint rectangle usesglobal44fd7c/global455608.
Shadow IDs223/224 and alternateCom IDs30..<50 except38 are EXE rules, no new
character allowlist. Lives retain last2decimaldigits; names are rawNUL with
11byte stride/signedInt8 glyphs. Bracketedname>17 crosses20byte stack/cookie:
explicitunsupported, no truncation. Sparks mutate duringdraw, before scheduler:
f<5,10..<15,20..<29,30..<39 advanceAFTER draw; only lastinvalid reduces36c.
No compaction; aliases advance repeatedly. Public pass stages allMatch state;
externaldevice events must wait for enclosingtick commit.
Original DAT survey137Objects/15363presentFrames/362sheets, all10sheets supported;
8positivebpoints Itachi0/1/2/3/5/6/7/8, no ID rule inferred.1579basepics without
sheet atActor318=0 (1116pic999), no replacement; dynamicreachability/W open.
Both fresh own GAMEPLAY_CAMERA parents reproduced bytewise on sameCPU/stack,
then continue41f496..41f4ac/SP1000e9bc,phase1/tick1,target28002020,mode0.
Actor8 remains75: firstown hasONLY glyph1/2 at437,507 and284,522,20events/2Blts,
6helpers/354PCs/zero undefinedreads. Pool/CRT/RNG40/1/101BG/854bitmaps/early/
music/replay630e18/14586Frameallocations unchanged; Actor sprites tested by
controlledcorpus, not attributed to ownfirstdraw. ALL11 character-menu wrappers
now additionally captured/compared before/after: SPARK is owned by retained
OriginalMenuResourceLoading, distinct from early/context/interface/catalog.
Its resolver uses original menu devicebindings. Failedinitialintegration was
corrected and both sources freshly rerun; allv1data/events unchanged, onlymenu
snapshots/blobs added. Neither v1waspublished. NewNative publictrial adds2sparks
only totrialstate, fails secondBlt afterfirstincrement, verifiesfullrollback.
Both Native launch/gameplay610754records/1225013022bytes with masks,992helpers/
100checkpoints; earliernestedparents revalidated but notin these counts.
30retained/newrelease regression370.989s/build0.19s passed; pairedacceptance
3tests49.052s/build124.79s published3losslessfixtures.132oldfixtureSHAsunchanged;
allnewraw/packedSHA/size/fullJSON/blobs/parents verified,135pins at
build/research/gameplay-drawing-fixture-pins.json. NTSDNative compiled/linked,
Python compilation/diffcheck pass; all source/Swift jobs terminal. NoUI/W claim.
NEXT same41f4ac: mode1/4 children437860/43a860, realCRT sprintf/GDI401290 caller,
4196f0 accumulatedimpulses, fullpost-draw400slot loop41f550 onward, scheduler/
recovery/creation/deletion and wholetickreturn. Read WORLD_DRAWING before
extending. Practice/appintegration, continuousDAT, firstfullmatch, Windows/
device/cleanMac and entiregoal remainopen.

The [post-draw impulse pass](docs/research/WORLD_IMPULSES.md) now implements
whole4196f0..419798 and common41f4ac..41f545 text/caller. Mode1/4 children are
explicitunsupported, never silently skipped. Generic400-slot scan, allnonzero
activity, allnonzero b4 skip, wrapped count+1, stagedpool, exactorderedstores.
Count0 keeps velocities but clears pending+28/+30/+38 topositive0. Aliases
consume once, later visits clear again. CW037f controlled values include all
binary64 classes, signed count overflow, extendedexponent and double-rounding;
processwide FPUstatus/traps/otherCW remain outside nativecontract.
1030 controlledpools/9385writes/58of58instructions and256 actualCRT signed-byte
formats match Native. Sixteen newmidpointcontrols preserve all1014 priorcases;
32stores distinguish53 from64-bitprecision. SourceFPSW only0/4 is a harness
observation, not hardwareexception proof. Diagnostic usesWorldslot10 eveninactive,
signedbytesc4/c5/c3/c2/be/c0 andoriginal trailing-space/repeated-d format.
Real401290 runs toGDI/COM boundaries, then4196f0; publiccall stageswholematch.
BothfreshsameCPU/stackparents reproduce entireGAMEPLAY_DRAWING, then41f550/
SP1000e9bc,phase1/tick1,mode0,3helpers/499PCs/7events each. Text18bytes:
u0 d0 l0 r0 a0 d0, at0,30, target28002020. EachactiveActor0/1 count0/b4=0;
constructorpending0.1 triples clear to+0, exactly48poolbytes change. Noimpulse
division runs. OwnFPCW0/FPSW0 retained andexplicitlyguarded, NOT claimedCW037f.
Otherpool/masks/globals/CRT/RNG40/1/101BG/854bitmaps/11menu/early/music/replay/
14586Frameallocations retained. OwnNative353341records/665509242bytes+masks,
499helpers/53checkpoints each; earlierparents validatedseparately. Publicrollback
trial failslateActorbinding aftertext andearlierwrites, preservesfullstate.
6release regression78.456s/build19.50s and4paired acceptance39.905s/build57.49s
passed;3losslessfixtures published,135oldhashes unchanged,138currentpins at
build/research/gameplay-impulses-fixture-pins.json. Allsource/Swiftjobsterminal;
NTSDNative compiled/linked. Noapp/Windowsclaim.
Newtools/oracle_fpu_precision.py executeswhole445a31 +realCRT under4initialCWs
(191PCs), then64 whole4196f0 calls/16midpoints. Source53/native64 disagreement
is verified, native53 andWindows areNOT. SeeFPU_PRECISION for startup/table
addresses and nextaudit; this takespriority over40d960/41f550..4214cf.
After numericalcorrection, continuecompletepostdrawslotloop/modechildren/
fullreturn. Appintegration, continuousDAT, firstfullmatch andfullgoalremainopen.

## Current implementation

`native/` contains Swift/AppKit/SpriteKit Naruto/Sasuke practice with snake and
Chidori needles, the earlier movement slice (`--movement`) and a resource
inspector (`--inspect`). Read `docs/MOVEMENT.md`, `docs/COMBAT.md` and
`docs/PROJECTILES.md` before extending gameplay. The original functions match
the retained bounded corpora; see evidence JSON for counts/hashes. Full-match
behavior, other techniques/projectiles, regeneration and AI remain incomplete.
Unsupported combat ticks roll back completely. Sprite drawing precedes frame
scheduling and post-scheduler recovery in the tested original path. Practice RNG
comes from the supplied replay; do not substitute host randomness.
The older timer comparison stubs the dispatcher. `oracle_tick_trace.py` now runs
the original dispatch/match entries through returns with synthetic loaded data
and explicit platform boundaries. It is a control-flow witness, not full-match
or native equivalence. It exposes missing item-spawn RNG, type-separated hit
passes, input/pause phases, linked-object passes and resource recovery. Do not
patch expected fixtures to hide these gaps or call the old composed pipeline a
complete original tick. Actor allocation is 0x420; the harness spacing is 0x500.

`NTSDCore/OriginalFrameLoader.swift` implements the recovered frame-section
loader. Read `docs/FRAME_LOADER.md` before extending it. Do not silently coerce
numeric conversions beyond the recovered CRT rules or treat the isolated frame
tests as whole-file equivalence. The retained isolated corpus still has its old
349 exclusions; do not rewrite that historical scope. The inspector still shows
raw occurrences, not normalized records.
