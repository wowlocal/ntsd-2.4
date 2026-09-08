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
Next recover menu/RNG input provenance, prelude 42cf8a..42d1ff and continuation
after 42d704, then connect to R01.2. Enabled music 402020 uses DirectShow and remains
unsupported. The new replay chain also executes nonempty-path 4025b0/402020 with
music disabled; this is not sound output or Windows startup.
The native preparation is not wired into practice. Do not restore synthetic
Object headers or treat constructor/PE zeros as final match defaults.
Verification: the existing 27 Swift tests passed (198.991s), then the three new
OriginalLoadedCatalogTests passed (135.451s), all on this shared-state change.
Release comparisons for all three packed fixtures also passed before acceptance.
The preparation stage additionally passed all 31 Swift tests in 398.752s,
including the new two-corpus comparison in 75.717s; both release comparisons
passed before fixture acceptance. The recording initialization stage then passed
all 32 Swift tests in 514.610s (new two-corpus test 113.006s), plus the release
comparison of both packed corpora before accepting them. Reference checks
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
