# NTSD native macOS port

The user's requirement is a native macOS game without a browser engine,
CrossOver, or Wine at runtime, preserving the original Windows game's feel.

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
