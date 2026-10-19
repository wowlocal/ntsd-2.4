# ES — Separate the engine from the game

Workflow: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md); gates and
measurement from [TVOS_WEB](TVOS_WEB.md), [MEMORY_LOADING](MEMORY_LOADING.md) and
[CORE_REALTIME](CORE_REALTIME.md). Related: [LF2_OPEN_SOURCE_ENGINES](LF2_OPEN_SOURCE_ENGINES.md)
(outside engines; not a source of rules), and the local branch `exp/ntsd-2.8.3.3`
(its `NTSD_2_8_3_3_IMPLEMENTATION_PLAN.md` and M0 content origin).

**Reason:** user request 2026-10-18: "let's plan on how can we separate LF2
engine from the game itself. to publish engine as the separate github repo";
then, after the plan: "ok … when the plan is setteled start the loop in a
separate branch" and "push automatically every step (on that new branch)".
**Status:** E0–E3, E4a, E4b (all six hosts), E4c-1 (the engine's self-contained tests), E5a (the game profile's survey and design) and E5b (the record type, the copied tables out), E4c-1a (a nondeterministic engine test corrected) E5c-0 (the profile's plumbing, reflection), E5c-1a (one storage, the reflectors), E5c-1b (armour), E5c-1c (special interactions) and E5c-1d (impact) done; E5c-2a (the items family's first rows) and E5c-2b (camera and links) done; E5c-2c, post-draw commands and the mission stage, next.
**Branch:** `exp/engine-split`, from `main` 380b448d. Worktree
`/Volumes/NTSD-Builds/tasks/engine-split/worktree` (T7-backed APFS, see
[BUILD_STORAGE_T7](BUILD_STORAGE_T7.md)). It tracks `origin/exp/engine-split`
and the post-commit hook pushes every commit (user, 2026-10-18). Merging into
`main`, creating the engine repository, choosing its licence, CI and any
publication need the user.
**Game result:** unchanged by definition. Every increment is behaviour-neutral:
the same requests, events, frames and timings on every host.
**Reference:** the pinned EXE (SHA-256 `3f7ac67c…ff71c`) is not touched. The
comparators are those of TVOS_WEB: the frozen app_e2e references, the frame
references by text group (`m1-frames-ref`, `rt-4w-appkit`, `android-app-ref` on
X5, read-only), `compare_frames.py`/`compare_text_frames.py`, and the Core suites.

## Decisions

Settled (the user's "ok" on the recommended plan, 2026-10-18):

- The goal is a data-driven engine that runs LF2 2.0a-format content with a
  game profile, reached in stages, not only a runtime/platform kit.
- The split happens inside this repository first (two local packages), and is
  extracted only once the engine package builds and tests on its own.
- The published repository starts with fresh history: `NTSDCore`'s history
  contains the original content, so a filtered history is not used.
- Module names stay `NTSD*` until the name is chosen (D2); the rename is one
  mechanical step in E8.

Open (the user's; each blocks only the step named):

- **D1 — a second reference.** The sources mark ID branches as "explicit EXE
  branches" without saying which come from LF2 2.0a and which are NTSD edits.
  Telling them apart needs the LF2 2.0a EXE as a second pinned reference, which
  extends AGENTS.md's "only the original NTSD distribution" rule. Blocks E6
  only; until then every ID-specific rule stays in the NTSD profile, and the
  engine without a profile is not claimed to match any released game.
- **D2 — name and licence.** Proposed: no "LF2" in the repository name (an
  engine "for LF2 2.0a-format games"); MIT or Apache-2.0. The engine is code
  recovered from a copyrighted EXE; whether to publish it is the user's call.
  Blocks E8 only.
- **Outside this card:** the existing GitHub repository is public, has no
  licence and holds the original EXE, `lib.dll`, DAT files and music (noted to
  the user 2026-10-18).

## Verified starting point (2026-10-18, 380b448d)

A read-only survey of `native/` (three agents, 2026-10-18):

- `native/Package.swift`: one package `NTSDNative`. `NTSDCore` (231 files,
  34.5k lines) → `NTSDReplayCodec` (zlib 1.1.4); `NTSDRuntime` (7.4k) → Core;
  hosts `NTSDMacPlatform`/`NTSDApp`, `NTSDSDL`, `NTSDiOS`, `NTSDAndroid`,
  `NTSDWeb`, `NTSDHeadless` → Core + Runtime; `NTSDMusicDecoder` → `CALAC`;
  `NTSDFreeTypeText`; `NTSDReferenceChecks` (11.5k) and nine `*Check` tools;
  `NTSDCoreTests` (366 files, 53k lines, 838 tests, 4.3 GB `Fixtures/` as
  plain Git blobs). unsafeFlags: `-cross-module-optimization` (release Core and
  Runtime), opt-in `-enforce-exclusivity=unchecked`, SDL/FreeType paths.
- Core is an instruction-level model of the EXE: globals are the record at
  `0x44d000` (size `0xc3a8`) loaded from `Resources/OriginalStartup/initial.bin`,
  a copy of the EXE's `.data`; 400 actors of `0x420`; ~3,600 EXE addresses in 135
  Core files. Core imports Foundation and conditional libc/CryptoKit/Dispatch
  only; Runtime has no AppKit/UIKit/SpriteKit either.
- Content is bundled into Core: seven `Original*` resource directories
  (`OriginalCatalog` 634 MB, `OriginalMatchArenas` 61 MB, `OriginalStartup`
  28 MB, menus/sounds/loading interface) and `OriginalMusic` (112 MB) in
  `NTSDMacPlatform`. Six `OriginalApplication*Inputs` loaders look in the app
  bundle, then `Bundle.module`, and check pinned manifest digests, counts
  (catalog: 1198 entries, 521 files, 669 bitmaps, 8 tracks) and the EXE SHA,
  which 66 source files pin. `--resources DIR` only relocates the same bundle.
- NTSD-specific rules inside engine logic: the AI's `switch own`
  (`OriginalCharacterAI.swift`) into 20 per-character routines
  (`OriginalCharacterAISpecial.swift`: `naruto2` … `kyubi52`); ~90 object-ID
  sites (e.g. `OriginalActorHits`, `OriginalActorPhysics`, `OriginalWorldFusion`,
  `OriginalWorldHits`, `OriginalWorldDrawing`, `OriginalMissionStage`,
  `OriginalWarBattle`, `OriginalProjectile`); the Naruto/Sasuke-only Practice
  code (`GameData`, `OriginalMelee`, `OriginalFighter`, `OriginalMovement`,
  `OriginalProjectile`) used only by NTSDApp's lab, two checks and tests.
- Identity in hosts: the "NTSD Native" user-data folder (five hosts), the wasm
  import module `"ntsd"`, Android's `ntsd/` asset prefix and
  `ntsd_android_on_create`, queue/thread names, window titles.
- The host seam exists: every host implements `OriginalRuntimeSessionHost` and
  starts `OriginalRuntimeSession`.
- Prior work: `codex/l2df-native-prototype` (unmerged, 2026-09-12) put an
  outside Lua engine in front of a copy of Core through a C ABI; no earlier
  engine/game split exists. `exp/ntsd-2.8.3.3` (local) adds a second version on
  the same Core with one fixed content origin per session
  (`OriginalRuntimeContentInputs`), the second consumer for E2/E5.

## Target layout

| Engine package (later its own repository) | Game package (this repository) |
| --- | --- |
| DAT decoding, `data.txt`, frame/object/stage/background loaders, simulation, RNG, replay, menus, network, rendering into the framebuffer | NTSD profile: ID-specific rules, the 20 AI routines, the starting state (`initial.bin`) and other EXE-copied data |
| Runtime: session, host protocol, window/audio/input/socket backends; host libraries (AppKit, SDL, iOS/tvOS, Android, Web, headless); ALAC/music decoder, FreeType text, C shims | Content: the packers (`tools/package_*.py`), the `Original*` packages and music, their identity policy (digests, counts, EXE SHA) |
| Self-contained tests and a from-scratch synthetic content pack | `NTSDReferenceChecks`, the `*Check` tools, oracle tooling, fixtures, evidence, the fixture-driven suites |
| | Apps: names, icons, bundle IDs, entry points, Practice/Lab, release and publishing scripts |

## Boundaries

- Behaviour-neutral. No gameplay change, no per-host branch, no second engine.
  Code moves with `git mv` plus the smallest edit, so `exp/ntsd-2.8.3.3` can
  rebase onto it; that branch is not edited here.
- Fixtures, expected bytes, masks, frozen plans and frame references are
  immutable. Test code may change where a resource is found, never what it
  expects. A difference is a recorded mismatch, never a new expected value.
- Performance is not traded: an increment touching shared code keeps load time
  and the A12's per-tick time (mlgate's phone and Mac A/B with music and
  sounds). Package boundaries matter for cross-module optimization (E4).
- No original bytes in the engine package: no resources, no `initial.bin`, no
  fixtures, no tables copied from the EXE (E7 scans for them).
- Storage: the worktree, builds and gate outputs on `/Volumes/NTSD-Builds`
  (APFS `E36E5CAF-…`, T7 `7C9569C1-…` keeps 40 GiB free). X5 (93 % full) gets no
  new outputs; its frozen references are read only.
- Not without the user: merging into `main`, a new GitHub repository, a
  licence, CI, publishing, D1's reference files.

## Gates (every increment)

1. Clean builds of every product the increment touches (cross-module
   optimization leaves stale incremental builds).
2. Core, Runtime, `Package.swift` or resource-layout changes: the mlgate set
   (headless vs and all 10 scenarios with frames identical to `m1-frames-ref`,
   20 AppKit launches, AppKit vs and playback, the Android emulator's vs
   frames, the named Core suites in a release test build, the A12 load and
   per-tick A/B and the Mac A/B against the previous increment).
3. Packaging scripts or bundle names changed: the rows they touch — the
   browser runner's scenarios (Chromium, WebKit), the iOS/tvOS simulators,
   Linux and Windows packages (`matrix.py`).
4. An independent read-only review (a separate agent) for each Core, Runtime
   or package change; its follow-ups fixed before the gate or recorded.
5. A phone or Mac A/B whose ranges do not overlap at the gate's three runs
   against two is followed by an interleaved 4-against-4 A/B before it is read
   as a change (twice on 2026-10-18 the gap closed: E1b with byte-identical
   library code, E3b).
6. Per-host rows build from clean folders, like the mlgate set's own builds
   (rows before E4b-3 reused their folders; see E4b-3's evidence).
7. One commit per checked increment on `exp/engine-split`, staging only its
   files (the tested tree), evidence in `docs/evidence/es-*.json`; the hook
   pushes it.

## Plan

| ID | Step | Status |
| --- | --- | --- |
| E0 | Harness: an mlgate copy parameterized by tree, output root (T7) and scratch path, defaults unchanged; a baseline gate of 380b448d in this worktree as PREV `es-base`; phone and emulator availability | **done** ([evidence](../evidence/es-e0-base.json)) |
| E1a | Content is its own target: the seven `Original*` directories leave `NTSDCore` for the game-side `NTSDContent`; Core loaders take an `OriginalContentLocation` from the session/host instead of `Bundle.module`; tests and packaging follow the bundle (E1 design below) | **done** ([evidence](../evidence/es-e1a-content-target.json)); the iOS simulator row moves to E1b's gate |
| E1b | Music: `OriginalMusic` leaves `NTSDMacPlatform` for `NTSDContent` (in the bundle on Mac builds only); the source paths in tools and hosts follow; the iOS simulator row with a device set on `/Volumes/NTSD-Builds` | **done** ([evidence](../evidence/es-e1b-music.json)); its packaged-app and iOS rows, and E1a's iOS row, closed after the Mac's audio came back ([evidence](../evidence/es-e1b-open-rows.json)) |
| E2 | Content policy out of Core: the digest, count and EXE-SHA pins become the NTSD content identity the game passes; Core checks what it is given with the same checks and errors (2.8.3.3's content origin as the model, read only) | **done** ([evidence](../evidence/es-e2-content-identity.json)) |
| E3 | Identity and Practice: user-data folder, wasm module, Android prefix/entry, queue/thread names, titles and messages become game configuration; Practice/Lab and its two checks move to the game side | **done**: E3a ([evidence](../evidence/es-e3a-practice.json)), E3b ([evidence](../evidence/es-e3b-game-identity.json)); diagnostic labels wait for D2 |
| E4 | Two packages: `engine/Package.swift` (Core, Runtime, codecs, decoders, shims, host libraries, self-contained tests) and `native/Package.swift` depending on it by path; the unsafeFlags plan (SwiftPM rejects them in version-pinned dependencies) | E4a **done** ([evidence](../evidence/es-e4a-engine-package.json)); E4b: headless **done** ([evidence](../evidence/es-e4b1-headless-host.json)), browser **done** ([evidence](../evidence/es-e4b2-web-host.json)), SDL **done** ([evidence](../evidence/es-e4b3-sdl-host.json)), AppKit **done** ([evidence](../evidence/es-e4b4-appkit-host.json)), UIKit **done** ([evidence](../evidence/es-e4b5-uikit-host.json)), Android **done** ([evidence](../evidence/es-e4b6-android-host.json)); E4c-1 **done** ([evidence](../evidence/es-e4c1-engine-tests.json)), E4c-1a **done** ([evidence](../evidence/es-e4c1a-sorted-keys.json)); E4c-2 (split the 11 mixed test files, the War trio) queued |
| E5 | Game profile: the ID sites (100 rows, about 125 branch points; first estimated ~90) and the AI dispatch behind a profile the game supplies; the engine defines the `0x44d000` record's layout and the game supplies `initial.bin`; the NTSD profile bit-exact (all gates plus the full fixture-driven suites); the API's fit with 2.8.3.3 checked read only | E5a **done** (survey and design, [evidence](../evidence/es-e5a-design.json)); E5b **done** ([evidence](../evidence/es-e5b-record-type.json)); E5c-0 **done** ([evidence](../evidence/es-e5c0-profile-plumbing.json)); E5c-1a **done** ([evidence](../evidence/es-e5c1a-reflector-roles.json)); E5c-1b **done** ([evidence](../evidence/es-e5c1b-armour-roles.json)); E5c-1c **done** ([evidence](../evidence/es-e5c1c-interaction-roles.json)); E5c-1d **done** ([evidence](../evidence/es-e5c1d-impact-roles.json)); E5c-2a **done** ([evidence](../evidence/es-e5c2a-items-roles.json)); E5c-2b **done** ([evidence](../evidence/es-e5c2b-camera-links-roles.json)); E5c-2c next |
| E6 | Classify each profile rule as LF2 2.0a or NTSD from the second reference; LF2 rules become the engine's default profile | needs D1 |
| E7 | Engine stand-alone: the engine package builds alone (macOS, Linux container) and passes its tests with a from-scratch synthetic content pack; a scan finds no original bytes (files under `downloads/`, the resources, fixtures, `initial.bin`) | queued |
| E8 | Publication: name, licence, a new repository with fresh history, a tag; this repository depends on it by revision; README credits | needs D2 and the user |

## E1 design (2026-10-18, before review)

Inventory (read-only agent, 2026-10-18): the only `Bundle.module` uses outside
the tests are the six `OriginalApplication*Inputs` lookups in Core and
`OriginalMacMusicOutput.directory(in:)`; every test use reads its own
`Fixtures`. Each lookup takes `appBundle.resourceURL/<Name>` when it exists or
the bundle is an `.app`, else `Bundle.module`. The packaged `.app` holds the
flat `Original*` folders and no SwiftPM bundle, so a fallback must stay lazy
(SwiftPM's accessor stops the process when its bundle is missing). Runtime
reaches content only through `OriginalRuntimeSession.resourceBundle()`
(`--resources DIR` or `.main`) and `OriginalRuntimeLoadingPackages(in:)`;
about 85 test call sites in 21 files use the loaders' `.main` default.

- **E1a** (Core's seven packages): a game-side target `NTSDContent`
  (`native/Sources/NTSDContent`: the seven directories by `git mv`, with
  `.gitattributes` following, and one accessor for its bundle). Core gets one
  value type for "where the content is": the app bundle plus a lazily
  evaluated fallback bundle, carrying the same two-level rule. Loaders and
  `OriginalRuntimeLoadingPackages` take it instead of a defaulted `Bundle`;
  the session takes it from its host (`--resources` still replaces the app
  bundle). Hosts pass the game's value (`NTSDContent.fallback`); the tests keep
  every call site through `Bundle` overloads in one test file
  (`NTSDContentLocations.swift`) that pass NTSD's location. E2 extends the same value with the content identity, as
  2.8.3.3's content origin does, so it is not throwaway. Rejected: a global
  registry (hidden state, and tests have no global set-up hook) and searching
  for any bundle that has the folders (finds nothing under xctest).
- **E1b** (music): `OriginalMusic` moves from `NTSDMacPlatform` into
  `NTSDContent`; the source paths in tools, hosts' `#filePath` fallbacks and
  the two `#filePath` tests follow.
- The built bundle becomes `NTSDNative_NTSDContent.bundle`
  (`.resources` on Windows). `app_e2e.compare` checks exitCode, boundary,
  milestones, progress and overlayFiles, not the printed `resources` path, so
  the frozen references stay valid. Scripts that name the bundle follow
  (android_app, web_app and `web/read-order.json`'s keys, package_linux,
  package_windows, matrix, ios_app, ios_device, run_headless_scenarios,
  web_saves_check, load_memory, package_assets). The 31 historical
  `finalize_application_*`/`verify_application_*` producers are frozen and
  stay as they are; they describe the old layout.
- Gates: the mlgate set, the browser runner's scenarios (pack contents and
  order identical apart from the prefix and the bundle's `Info.plist`, whose
  name and identifier carry the target's name on swiftbuild targets), an iOS
  simulator vs, the Linux and Windows package rows.

## E3 design (2026-10-18, before review)

Inventory (read-only agent, 2026-10-18, on E2's tree):

- **Practice/Lab.** `GameData`, `OriginalMovement`, `OriginalFighter`,
  `OriginalMelee`, `OriginalProjectile` and `OriginalClock` (Naruto/Sasuke
  guards, objects 2, 11, 203, 224, 440) are used only by NTSDApp's lab
  (`main.swift` lab parts, `Assets`, `OriginalScene`, `MeleeScene`,
  `MovementScene`), `NTSDMovementCheck`, `NTSDCombatCheck` and their tests;
  nothing in Runtime or a host's runtime path uses them. They use engine
  types the runtime path also needs (`OriginalFrameLoader.apply`,
  `OriginalFrameRecord`, `OriginalLoaderError`, `OriginalRandom`), which stay.
- **Identity strings in engine and host code** (none is the EXE's): the
  user-data folder "NTSD Native" (five hosts), queue/thread names (`NTSD.readahead`,
  `NTSD.load`, `NTSD.release`, `NTSD.Winsock.readiness`, `ntsd.render`,
  `NTSD.present`), the stop message "NTSD stopped at an unsupported
  boundary", `NTSDOriginalWindow` defaults key, Android's `ntsd/` asset
  prefix, `ntsd-data`, Android's program name `NTSDAndroid` (its argv[0]),
  `ntsd_android_on_create` and other `ntsd_` C symbols,
  the wasm import module `"ntsd"`. A test pins `NTSD.release`; tools pin
  `/save/NTSD Native`, `ntsd-data`, `NTSD.present`/`NTSD.release` timings.
  The EXE's own strings ("Marti", "Little Fighter 2", "LF2", lf2.net, the DAT
  key) are original behaviour and stay.

Plan:

- **E3a**: a game-side target `NTSDPractice` for the six files (by `git mv`),
  depending on Core; the engine types they use become public where they are
  internal; NTSDApp, the two checks and their tests import it. No behaviour
  or expected value changes.
- **E3b**: the identity a player sees that engine code holds becomes a game
  identity the host supplies (`OriginalGameIdentity`: the stop message's name
  and the user-data folder), with NTSD's current values, so every test and
  tool sees the same strings. Diagnostic labels (queue/thread names
  `NTSD.readahead`, `NTSD.load`, `NTSD.release`, `NTSD.Winsock.readiness`,
  `ntsd.render`, Android's `NTSD.present`, the stderr "NTSD: no display
  geometry" line) wait for the engine's name (D2): their neutral prefix is
  that name, and a test and a measuring tool key on them. Compile-time names
  (the wasm import module, the C entry symbols) wait for E4, where the host
  libraries are split from their apps.

## E4 design (2026-10-19, before review)

- **E4a**: a second local package `engine/` at the repository root holds the
  engine targets, moved by `git mv` from `native/Sources`: `NTSDReplayCodec`,
  `NTSDCore`, `NTSDRuntime`, `CALAC`, `NTSDMusicDecoder`, `NTSDMacPlatform`
  (Mac builds) and `NTSDFreeTypeText` with `CFreeType` (when a FreeType prefix
  is given), each a library product, with their settings (cross-module
  optimization, exclusivity, the environment switches) unchanged.
  `native/Package.swift` depends on it by path; the hosts, `NTSDContent`,
  `NTSDPractice`, `NTSDReferenceChecks`, the checks, `CZlib`, `CSDL3` and the
  tests stay. Module and bundle names do not change (D2 renames). The gate's
  tested trees add `engine`; the per-host rows and a 4-against-4 phone A/B
  run, as the package boundary is where cross-module optimization could
  change code.
- **E4b**: the hosts split into engine host libraries (the session host,
  windows, audio, input for AppKit, SDL, iOS/tvOS, Android, Web, headless)
  that take the game as a value (content location, content identity, game
  identity), and thin game apps; the compile-time names (the wasm import
  module, the Android entry symbol) go with the apps or become the engine's.
- **E4c**: the self-contained tests move to `engine/Tests`; the
  fixture-driven suites stay with the game.

## E5 design (2026-10-19, reviewed and revised)

From two read-only surveys at `40611c4d` ([ID sites and AI](../evidence/es-e5a-id-sites.md),
[record and tables](../evidence/es-e5a-record-tables.md)) and a read-only
design review ([evidence](../evidence/es-e5a-design.json)). Which rules are
LF2 2.0a's and which NTSD's stays open until D1 (E6); E5 moves all of them to
the NTSD profile and leaves the engine with none.

- **What there is.** 100 object-ID rows (about 125 branch points) in 27 Core
  files, 15 stage-ID, 11 background-ID and about 35 mode rules; Runtime and
  the hosts only report IDs. About 150 object-type and 260 frame-number rules
  are generic mechanics and stay. The AI rolls `draw(0x3c,…)` whatever the ID
  and then dispatches at `0x403a40` into 20 routines that read actor fields,
  frame `+8`/`+0x2c` and three globals and write only button/command bytes and
  the random state.
- **Rules move, layout stays.** The ID rules and the AI become the game's. The
  layout stays compile-time engine code: the `0x44d000` record, 400 actors of
  `0x420`, frame stride `0x178`, about 2,200 address constants, and the
  capacities and slots of stage and background IDs (D15, B11 and the
  Random/built-in slots 100/99 of B1–B10, tied to `OriginalCatalogRegistry`'s
  built-in record). The stage rules D1–D14 (decades, survival 50, the
  stage→background map, labels, menu cycles) move. lib.dll's hooks (ITR kinds
  80–89 and 800–825, effects ≥6000, states 4000–4999) stay behind
  `bundledLibrary` in E5 and join the D1/E7 list. 2.8.3.3 changes the layout
  (1,000 actors, stride `0x1b0`, globals +0x50000), a second layout in engine
  code for that study; that its rules fit this API is an inference (no
  recovered 2.8.3.3 rules, no ID-site file differs).
- **The record.** The game keeps supplying `initial.bin` (the EXE's 8 KB
  `.data` and zeros to `0xc3a8`) through its startup package. One engine type
  backs the existing named constants for the base and the two sizes (`0xb440`,
  `0xc3a8`) and the parts; the 138 `0x44d000` address sites stay as they are.
- **Copied tables.** `OriginalWarTroops.fileWords` (`0x44d350`, 1,064 B) and
  `OriginalTournamentLayout.words` (`0x44d120`, 504 B) duplicate `initial.bin`
  and only tests use them: compared once with the game's record (a difference
  is a recorded mismatch, neither side changes), then their tests read the
  record and the tables leave the engine; whatever replaces `initializeFileData`
  in the tests keeps its zeroing of `0x451b38..<0x451bb4`, `OriginalWarSetup`'s
  comment follows, and
  `sourceSHA256` moves into the test unchanged. The 151 front-menu rectangles
  and the bitmap/sound name lists become game data; the DAT key, the COM GUIDs,
  the C runtime's power-of-ten table and EXE strings stay engine constants
  until D1 sets E7's policy.
- **The profile's shape.** Engine-defined value types the game fills, carried
  per session with the content (the content location or identity, which
  already reach the loaders; not `OriginalGame`, since 2.8.3.3 picks its
  content per session), with a profile identity in the content identity. One
  named role per rule, not per object kind (122 alone against 122/123; three
  different "30" ranges). Roles on catalog objects compile into per-ordinal
  masks inside `OriginalLoadedCatalog` (as `frameAllocationOrder`), from the
  finished header `+0x6f4`, so a hot site costs one array load; building them
  never rejects or merges duplicate, negative or large IDs. IDs that are not
  catalog ordinals (the stage spawn word before the pseudo-ID substitution,
  pseudo-IDs 1000/3000/3001, the hero table, War-table words: A60–A63, A65,
  A67) get `Int32` value predicates. Lookups keep their scans (first match;
  War's unit binding last match). Only identical lists are shared (roster ×4,
  Random ×4, reflection ×2, 122 → HP 200 ×3; War's 122 case writes three
  fields and belongs to the War-life hook). Code hooks only at coarse points
  (about 8; fusion alone spans five files): the AI special (after the entry
  roll, with the same context), fusion, mission pseudo-IDs, War life, weapon
  break, the ID-300 exemption, armour. The 20 routines move to a game target
  with the NTSD profile.
- **Bit-exactness.** Only the comparison changes: each site keeps its read,
  accessor, error type and message in place (Runtime maps
  `outsideVerifiedDomain`, so errors are outcomes), and reads an ID test
  guards (possibly undefined storage, e.g. `word(0x458428)`) stay guarded. No
  hoisting, caching or reordering of reads, throwing reads, random draws (and
  their stream labels) or re-reads after writes; short-circuit order stays.
  Profile numbers are `Double`s wrapped at the site with the pass's precision
  (never pre-built `OriginalExtended`); exact literals and `Int32` wraparound
  stay; each site keeps its iteration domain (`objectCount` against
  `objects.count`, `max(objectCount,0)` against `objectCount > 0`) and its
  `Int(UInt32)` conversions (`Int` is 32-bit on wasm32). The profile is
  passed apart from `inout` pass state (an overlapping access goes unchecked
  in shipping builds); its types live in the engine so cross-module
  optimization still specializes the passes; gates use clean builds. No
  runtime-path API gets an empty-profile default.
- **Increments.** E5b: the record type behind the named constants, and the two
  copied tables' comparison and removal. E5c-0: the plumbing and one role
  (reflection) with the phone A/B. E5c-1: the hot-pass sites (contacts, hits,
  physics, drawing). E5c-2: the menu and mode sites with D1–D14. E5d: the AI
  special hook and the 20 routines in a game target (public pass primitives,
  the target with the cross-module flags). E5e: the other coarse hooks. E5f:
  menu rectangles and name lists as game data.
- **Gates (each Core increment).** The mlgate set from clean builds; a WASI or
  browser vs (the only 32-bit build); every `*Check` product built and the
  reference checks of the passes that changed run; the game's full
  fixture-driven suites (release test build) where rules move; the phone A/B
  for hot passes (and phone and Mac A/Bs for E5d), with rule 5's follow-up;
  per-host rows where a host changes. Each review checks a table mapping every
  row to its role (the literal sets compared mechanically), that only
  comparisons were replaced, no empty-profile default, error strings, event
  and random-stream order, exclusivity, and the public surface added.

### E5c-0 note (2026-10-19, reviewed and revised; done)

From a read-only plumbing map ([report](../evidence/es-e5c0-plumbing.md)) and
a read-only review of this note (its required changes are in; evidence with
the step).

- **ID sets for finite lists.** A membership role is an `OriginalIDSet`: the
  literal IDs (kept for the mapping table) and a bit array; `contains(id)`
  tests `UInt32(bitPattern:id) &>> 6 < words.count` and one bit, so it is true
  exactly when the old literal list contains `id`, for every `Int32` a catalog
  header can hold (negative and large IDs fall out with one compare; safe with
  32-bit `Int` on wasm32). Only the profile's own literals must lie in
  `0..<65536` (its initializer's precondition). Each site keeps its own header
  read, throw and order and replaces only the `contains`; a per-ordinal mask
  would need the ordinal (a second `object()` read or a changed helper), so ID
  sets replace the E5 design's masks for finite lists. Open-ended tests (A46
  `id < 30 || id >= 50 || id == 38`, A80 `id < 30`) keep a comparison with an
  `Int32` bound the profile supplies; their exact form is decided in E5c-1.
- **Types.** `OriginalGameRules` (engine, public, `Sendable`, `Equatable`):
  `profile` ("NTSD 2.4 2.0a") and one `OriginalIDSet` per role, first
  `reflectable`; `contains` internal for now (public when E5d needs it). No
  default value anywhere on the path. Code hooks (E5d's AI routines, the
  coarse hooks) travel separately from this `Equatable` value (with the game,
  e.g. `OriginalGame`); the engine cannot import the game's target.
- **Path.** `OriginalContentIdentity.rules` (built only by `NTSDContent`; the
  profile identity in the content identity; its doc comment follows) →
  `OriginalApplicationCatalogInputs.rules` (kept by `replacingFile`) → the
  catalog session's `Resources`/`Inputs` (the only runtime construction is
  `OriginalMacRuntimeLoading`'s) → `OriginalLoadedCatalog.rules` (all three
  public constructors require it) → `OriginalHitPass` and `OriginalContactPass`
  each store `let rules` from the catalog copy their `makePass`/`apply(state:)`
  already take before any in-place access (a statically checked read: no new
  `swift_beginAccess`). The test-only explicit-provider entry points take a
  required `rules:`. About 30 edits (12 engine, 3 game, 16 test); the frozen
  copies under `tools/loading_*_candidate/` stay untouched. 2.8.3.3's
  per-session content follows the same path.
- **Game side.** A resource-free target `NTSDProfile` (exclusivity settings, no
  bundle, so the packagers need nothing) holds `NTSDProfile.rules` (NTSD 2.4:
  `reflectable` = {200, 203, 205, 206, 207, 215, 216}); `NTSDContent` puts it
  in its identity; `NTSDReferenceChecks` and `NTSDCoreTests` depend on it. It is
  where E5d's AI routines go (injected as code; the game package then needs the
  cross-module settings).
- **Sites (this step).** `OriginalHitDamage`: `static let reflectable` removed,
  `rules.reflectable.contains(` at its four uses; `OriginalWorldContacts`:
  `rules.reflectable.contains(attackID)` (the per-box re-read of `attackID`
  stays). The two literal lists are equal; 209, 8 and 213 (the reflectors)
  stay literals until E5c-1 (rows not yet moved in the mapping table).
- **Tests.** In `engine/Tests/NTSDEngineTests`: `contains` against a literal
  list for `Int32.min`, −1, 0…4096, 63/64/127/128, 65535/65536, `Int32.max`,
  single-bit flips 0–31 of each member, an empty set, members 0 and 65535. In
  the game's tests: a synthetic hit case and a contacts case with a 209
  defender and a member and a non-member attacker, each also with empty rules,
  which must differ (the existing fixtures load only IDs 2, 7, 8, 51 and never
  reach reflection); a catalog loaded through the session carries
  `NTSDContent.identity.rules`, and `replacingFile` keeps them.
- **Gates.** As the E5 design, with the checked headless build's
  `swift_beginAccess` count (3,276) unchanged, and the WASI vs (the only 32-bit
  build). Clean builds everywhere (public layouts change).
- **Cost.** One compare and one load where hits hashed a `Set<Int32>` and
  contacts scanned seven literals; two retains per pass copy (`ids`, `words`),
  growing per role: before E5c-1 the roles' bits go into one storage so a copy
  costs one retain. The phone A/B decides.

### E5c-1a note (2026-10-19, reviewed with its change; done)

- **One storage.** `OriginalGameRules` keeps every role in one private
  immutable final class; its public properties read through it, so a pass's
  copy of the rules is one reference however many roles there are (the
  profile string included). Equality: the same storage, or every role equal.
- **The reflection family completed.** Three `Int32` roles, compared exactly
  as the literals were (the header read on the left, the role on the right):
  `reflector` (209: A8's attacker and defender tests, A13's `find`, A14, A20's
  defender), `rebinder` (8: A15), `heldRebinder` (213: A16). Single-ID equality
  tests stay equality (not ID sets). The other 209/213 literals in the engine
  are frames, coordinates, a random-stream label (`draw(209,30)`) or other
  families (items A83, weapon break A52/A54).
- **Tests.** The empty profile sets the three to `Int32.max` (no Object); a
  moved profile (reflector 210, rebinder 9, held rebinder 214) shows A13–A16 and
  A20 follow the profile, not 209/8/213. A8 stays covered by mapping only.

### E5c-1b note (2026-10-19, reviewed with its change; done)

- **Families.** `OriginalGameRules` takes one public value per family
  (`Reflection`, `Armour`), so its initializer grows by family, not by role;
  the sites keep reading flat accessors (`rules.steadyArmour`) through the one
  storage.
- **Armour (A1–A6).** The engine keeps each rule's thresholds and conditions
  (15, 1, the frame/state window, effect-based penetration); the profile names
  the Objects: `guardPenetrators` {214, 208} (A1, A4: one list, used twice in
  `guarded`), `steadyArmour` 37 (A2), `openingArmour` 6 (A3), `attackerArmour` 52
  (A4), `alwaysBlocked` {124, 220, 221, 222} (A5), `armourGuardSound` {37, 6}
  (A6, its own list: not derived from A2/A3). Single-ID tests stay equality.
- **Design revision.** The E5 design listed armour among the coarse code
  hooks (the survey also sketched guard thresholds as data). Here the IDs
  become roles and the thresholds and conditions (15, 1, frame < 20, states
  5/4/7, effect-based penetration) stay engine code: they are the EXE's, the
  same for every Object the profile names. E5e's armour hook is dropped for
  NTSD 2.4 and reopens only if D1/E6 or 2.8.3.3 shows a game with other
  thresholds (they would then become profile values). A5 (the defend block)
  is not armour in the survey's grouping; it shares the `guarded` site and
  the family.
- **Tests.** For each row, a synthetic `guarded`/`guardHit` case that holds
  under NTSD's profile and changes under a profile moving only that row's IDs.

### E5c-1c note (2026-10-19, reviewed with its change; done)

- **Order changed.** Most of the items family (A42–A44, A48–A50, A64) is in
  four passes that carry no rules yet (post-draw commands, camera, links,
  mission stage), so it moves after their plumbing. E5c-1c takes the
  special-interaction rows of the two passes that already carry the rules.
  Still in those passes afterwards: A7 (300, the ID-300 hook, E5e), A9–A11
  (OriginalHitDamage: 201, 214, held 100; next, E5c-1d), A39–A41 (the hit
  pass's item spawn in OriginalWorldHits; with the items family), A24–A26
  (fusion, the fusion hook, E5e).
- **Interaction family.** `holdKind101` {120, 124} (A17 kind-7 pick-up, A18
  kind-2 type-1 pick-up: the same rule, hold kind 101 instead of 1), `pullImmune` {201, 202} (A19),
  `teamBypass` 212 (A21 and A22: the same-team filter's exception, in both of
  its forms, the actors' and the held owner's teams), `countsAsCharacter`
  {201, 202} (A23, game mode 1). A19 and A23
  have the same list but are different rules, so they are different roles.
- **Tests.** A17, A18, A19 (`specialHit`, `pullingHit`) and A21 (the contacts
  helper with both actors on one team) hold under NTSD's profile and change
  under a profile moving only that row; A22 (the held-owner filter) and A23
  (mode 1) are covered by the mapping only.

### E5c-1d note (2026-10-19, reviewed with its change; done)

- **Impact family.** Three single-ID equality tests in `OriginalHitDamage`
  become `Int32` roles: `vanishingAttacker` 201 (A9: on a type-0 defender the
  attacker is deactivated, its World activity byte cleared), `spentAttacker` 214
  (A10: its HP goes to 0), `heavyHeldWeapon` 100 (A11, held: a type-4/6
  defender's x impulse +0x28 ×2.5 with sound 13, a non-zero result under 10 in
  magnitude becoming ±10). The conditions stay engine code.
- **Tests.** A11 through `hitHorizontal` (impulse 10 and sound 13 under NTSD's
  profile, 3 and no sound under a moved one); A9 and A10, and now A8 too,
  through `damageHit` with a type-0 (A9, A10) or type-3 (A8) defender.
- **Left in the hit and contact passes:** A7 (300) and A24–A26 (fusion), both
  E5e hooks, and A39–A41 (the item spawn), with the items family.

### E5c-2a note (2026-10-19, reviewed with its change; done)

From the items family's plumbing map ([report](../evidence/es-e5c2-plumbing.md)).
- **`OriginalIDRange`.** Two `Int32` bounds, half-open; `contains(id)` is
  `lowerBound <= id && id < upperBound`, the exact complement of the original's
  `id < 100 || id >= 200` for every `Int32` (both pure comparisons). It is also
  the form A46/A80's open-ended tests will take. It is built from a
  `Range<Int32>` (`OriginalIDRange(100..<200)`); two ranges are equal when their
  bounds are, so two empty ranges may differ, as `OriginalIDSet` compares lists.
- **Items family (fifth).** `itemRange` 100..<200 (A39 here, A48 in E5c-2c:
  both ask "is this an item a spawn may pick"; one rule, so one role, a sharing
  the E5 design's list did not name, recorded here; only the range is shared:
  A49's 122-only coin flip, stream 208, stays its own role), `scarceDropItems`
  {122, 123} (A40: the stream-147 draw stays before the mode test, so it happens
  in modes 1–4 too), `spawnHP200` 122 (A41 here, A50 and A64 later: one rule).
  Engine literals that stay: the HP value 200, the modes `[1,2,3,4]`, the
  random-stream labels.
- **Coverage.** The hit corpora (IDs 2, 7, 8, 51) never offer a candidate, so
  A39–A41 are covered by the mechanical check and these synthetic tests only.
- **Tests.** Through the hit pass's `advance` with no active Actor and an RNG
  table of ones (`draw(146,200) = 0`, `draw(147,2) = 1`): A39 (the picked
  Object follows the range), A40 (the stream-147 draw and the mode-1
  exclusion follow the set), A41 (HP 200 follows the role; a new Actor's is
  500). The engine's `OriginalIDRangeTests` compare `contains` with the
  original's comparisons at `Int32.min`/`max` and each bound ±1.
- **Review.** No code fix (literals restored: byte-identical to HEAD; the
  evaluation order unchanged). Required: the mode-1 test asserts the exact
  division-by-zero error, the stream-147 draw and no spawn. Adopted with it:
  every spawn assertion checks the spawn happened, the range's inner edges, the
  engine range test, `fullHPSpawn` renamed `spawnHP200`.

### E5c-2b note (2026-10-19, reviewed with its change; done)

From the plumbing map ([report](../evidence/es-e5c2-plumbing.md) §1–2).
- **Plumbing.** `OriginalWorldCamera.bounds` and `OriginalWorldLinks.apply(world:)`
  take a required `rules:` (after `background:`); their state entry points pass
  `catalog.rules` from the local catalog copy they already take, the links
  pass's copying call passes it through. No public or package signature
  changes; the 5 explicit test calls pass NTSD's rules.
- **Roles (Items).** `keptOnScreen` {122, 123} (A42, the camera's clamp 10 inside
  the edges; its mode-1 stage 50–59 case stays behind the same ID test; its own
  role though its list equals `scarceDropItems`, as A19/A23), `hpDrink` 122
  (A43), `mpDrink` 123 (A44: the second header read after the HP drink's block
  stays, so one ID in both roles runs both blocks).
- **Tests.** `bounds` directly (a type-1 Object at x 5: held at 10 with a team,
  or in mode 1 on stage 55; left at 5 under a moved profile) and the links pass
  (a holder in state 17 holding the drink: item HP −1 or −2, holder MP +3, the
  spent drink's stream-136/137 draw; moved profiles; both roles on one ID, and
  spent in the first block so the second is skipped); past the left edge a
  122 is held at 10 under NTSD's profile and deactivated under a moved one.
- **Review.** No code fix (literals restored: links byte-identical to HEAD,
  camera only its comment). Required: the drinks' docs say each links pass
  (twice a tick), and the MP drink's 500 cap and 150 setting. Adopted with it:
  the camera doc names +0x344 and the deactivation, the two extra test cases.

## Ledger

- 2026-10-18: plan agreed; branch `exp/engine-split` and its worktree created
  from 380b448d on `/Volumes/NTSD-Builds`; all 4,985 LFS files present
  (7.2 GB). `caffeinate -dims` with a one-minute `-u` ping runs without expiry
  for the loop.
- 2026-10-18 E0: `tools/crossplatform/mlgate.sh` (X5's mlgate.sh, SHA-256
  3312b3e9…, with `GATE_REPO`, `GATE_OUT`, `GATE_REFS`, `GATE_SCRATCH` and
  `GATE_PHONE`; unset, the X5 behaviour) and `NTSD_ANDROID_SCRATCH` in
  `android_app.py`. Gate `es-base` with outputs on `/Volumes/NTSD-Builds`:
  all 11 scenarios equal and 1,832 frames identical (`m1-frames-ref`), AppKit
  vs and playback equal (3,960 frames), unchecked vs and Demo, the emulator's
  vs (1,832 frames), 20 launches, 18 suites plus the exclusivity check. The A12
  was not on adb at the start; once the user connected it, its A/B against
  `mm-2` ran separately: same CPU to the loaded state and per-tick time, wall
  load converging run by run. Resident memory is ~28–30 MB above `mm-2`, from
  main's changes since 2026-10-13 (E0 changed no Native code).
  [Evidence](../evidence/es-e0-base.json).
- 2026-10-18 E1a: the content target, reviewed independently before the gates
  (behaviour-neutral, no code fix required; one harness fix: mlgate's
  tested-tree step dropped deletions under rename detection, so it now stages
  with `git add -A` in a copy of the index; E0's recorded tools tree differs
  from its commit only in two files' modes). Gate `es-e1a` against `es-base`:
  all 11 scenarios equal, frames identical, AppKit, unchecked, emulator, 20
  launches, 24 suites; phone A/B equal in CPU to the loaded state and per-tick
  time, memory ranges overlapping; the Mac's footprint after the match read
  higher (671 vs 558–590 MB) but `heap` shows the same live heap and an
  identical es-base run reaching 677 MB. Gate 3, one vs each: WASI, browser
  (packed, verified; text in the same 446 frames), Linux container, Windows
  (CrossOver) and the packaged `.app` equal with identical frames. iOS stays
  open: the simulator's data folder (all of CoreSimulator/Devices) is missing
  since 2026-10-17 19:47, outside the storage migration's records; `NTSDiOS`
  built. Harness error kept: the wasm SDK query matched two SDKs.
  [Evidence](../evidence/es-e1a-content-target.json).
- 2026-10-18 E1b: the music in `NTSDContent`. The independent review found
  one required fix before any gate: copying the music into the bundle on every
  platform would have shipped it twice (APK, Linux, Windows, the web's eager
  packs) and broken `ios_app.py`; it now joins the bundle on Mac builds only,
  confirmed by builds and the reviewer, and `web_app.py` refuses a bundle with
  it. Gate `es-e1b` against `es-e1a`: 11 scenarios, frames, AppKit (finished
  19:27), unchecked, emulator, 20 launches, 26 suite runs pass. The phone's
  footprint ranges did not overlap although both APKs run identical code and
  data (only the build ID differs): noise at three runs against two. The Mac
  A/B's first PREV runs found no music (its compiled source path moved); rerun
  with `--music-dir`: equal, the two binaries differing in one instruction.
  WASI, browser, Linux and Windows equal. Open: the packaged app and iOS. Both
  wait inside audio start-up, as does `es-base`'s iOS build and a plain
  `afplay`: the Mac's audio server stopped answering new clients between 19:27
  and 19:56, the first failing call being the new simulator's audio start.
  [Evidence](../evidence/es-e1b-music.json).
- 2026-10-18 E1 rows closed: the Mac's audio answered again with the same
  `coreaudiod` (no restart). On E1b's commit (checked out in the dev
  worktree), the packaged `.app` and the iOS simulator (T7 device set) vs are
  equal with frames identical to the CoreText reference.
  [Evidence](../evidence/es-e1b-open-rows.json).
- 2026-10-18 E2: the content identity (EXE SHA, seven manifest digests,
  declared counts, the startup's absent files) leaves Core for
  `NTSDContent.identity`; `OriginalContentLocation` carries it and the
  loaders check it in the old order with the old errors; hosts answer
  `contentLocation(in:)`. Reviewed independently (no blocking issue; the
  absent-file names and the EXE note adopted). Gate `es-e2` against
  `es-e1b`: 11 scenarios, frames, AppKit, unchecked, emulator, 20 launches,
  25 suite runs; phone ranges overlap; one vs equal with identical frames on
  WASI, browser, Linux, Windows, iOS and the packaged `.app`.
  [Evidence](../evidence/es-e2-content-identity.json).
- 2026-10-18 E3a: the practice model (six files) moves to the game-side
  `NTSDPractice` by `git mv`; no Core symbol needed a wider access level.
  Reviewed independently (no required fix). Gate `es-e3a` against `es-e2`:
  11 scenarios, frames, AppKit, unchecked, emulator, 29 suite runs; phone and
  Mac ranges overlap. The gate's 20-launch loop aborted when one launch
  outlived its 60 s timeout (the loop raises instead of counting); a recheck
  of 20 launches each of E3a and E2, interleaved, was clean. No per-host rows:
  no host or runtime-path code changed. Note for the next progress estimate:
  `estimate_port_progress.py` scans only `NTSDCore`.
  [Evidence](../evidence/es-e3a-practice.json).
- 2026-10-19 E3b: `OriginalGameIdentity` (name, user-data folder) from the
  host, NTSD's values in `NTSDContent.game`; reviewed (two required fixes in
  the harness line and the card, made). Gate `es-e3b` against `es-e3a`: 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs; one vs equal with identical frames on WASI, browser, Linux, Windows,
  iOS and the packaged `.app`; the macOS SDL host compiled. The gate's phone
  A/B (3 against 2) showed CPU to the loaded state 10.20–10.24 against
  9.99 s; an interleaved 4-against-4 follow-up overlapped everywhere.
  [Evidence](../evidence/es-e3b-game-identity.json).
- 2026-10-19 E4a: the engine is its own local package, `engine/`
  (328 files by `git mv`, settings unchanged); `native/` depends on it by
  path and names its products explicitly (SwiftPM does not resolve a name to
  another package's product). `package` access does not cross packages: the
  six Core entry points the game side calls are public, twelve stay
  `package`. Reviewed (three required fixes in `.gitignore`'s bytes, the
  estimate tool's snapshot and the tools' dirty checks, made and confirmed).
  Both build systems keep the engine's flags (Mac `beginAccess` counts as
  before; the APK's `manifest.pif` carries them and its library has as many
  `swift_beginAccess` calls as E3b's). Gate `es-e4a` against `es-e3b`: 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs; one vs equal with identical frames on WASI, browser, Linux, Windows,
  iOS and the packaged `.app`; a 4-against-4 phone A/B overlaps everywhere.
  [Evidence](../evidence/es-e4a-engine-package.json).
- 2026-10-19 E4b-1: the headless host is the engine library
  `NTSDHeadlessHost` (session and window host by `git mv`, the former main
  body as `run(arguments:game:defaultMusicDirectory:)`); Core's `OriginalGame`
  carries the game identity and its content factory, NTSD's is
  `NTSDContent.runtimeGame`; the game's `NTSDHeadless` is one call. Reviewed
  (no required fix; the music default stays lazy). Gate `es-e4b1` against
  `es-e4a`: 11 scenarios, frames, AppKit, unchecked, emulator, 20 clean
  launches, 29 suite runs, the checked headless build's 3,276
  `swift_beginAccess` calls unchanged; vs equal with identical frames from
  the new library on WASI, Linux, Windows and Android headless.
  [Evidence](../evidence/es-e4b1-headless-host.json).
- 2026-10-19 E4b-2: the browser host is the engine library `NTSDWebHost`
  (five files by `git mv`, the main body as its `run`); the game's `NTSDWeb`
  is one call. Reviewed (no required fix; the built module's 12 `ntsd` and 34
  WASI imports and its exports equal E4a's). Gate `es-e4b2`: 11 scenarios,
  frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite runs; WASI
  vs equal with identical frames; the packed browser vs equal with text in
  the same 446 frames in Chromium and WebKit. The phone's footprint ranges
  touched with identical Android code. [Evidence](../evidence/es-e4b2-web-host.json).
- 2026-10-19 E4b-3: the SDL host is the engine library `NTSDSDLHost`, with
  `CSDL3` (five files and the module by `git mv`, the main body as its `run`,
  the beside-the-executable music rule kept in the engine); the game's
  `NTSDSDL` is one call and keeps the SDL link flags. Reviewed (no required
  fix). Gate `es-e4b3`: 11 scenarios, frames, AppKit, unchecked, emulator, 20
  clean launches, 29 suite runs; from clean builds, macOS SDL vs equal with
  frames identical to the AppKit reference, Linux SDL (FreeType) and Windows
  SDL (GDI) equal with text in the same 446 frames. Method note: earlier
  per-host rows reused build folders; rows now build clean.
  [Evidence](../evidence/es-e4b3-sdl-host.json).
- 2026-10-19 E4b-4: the AppKit host is the engine library `NTSDAppKitHost`
  (`OriginalRuntimeLaunch.swift` by `git mv`, the arguments and the game passed
  in, the app's runtime branch as its `run`); the lab and the dispatcher stay
  in the game's `NTSDApp`. Reviewed (no required fix; two live docs updated).
  Gate `es-e4b4`: 11 scenarios, frames, AppKit, unchecked, emulator, 20 clean
  launches, 29 suite runs; the packaged app from a clean build: vs and
  playback equal, frames identical to the AppKit reference; the lab's data
  check. [Evidence](../evidence/es-e4b4-appkit-host.json).
- 2026-10-19 E4b-5: the UIKit host (iPad, Apple TV) is the engine library
  `NTSDUIKitHost` (two files by `git mv`, the former main as its `run`, the
  game kept for the scene delegate UIKit creates); the game's `NTSDiOS` is one
  call; the packagers' plist names the scene delegate's new module, which a
  restored session needs (its archive holds only the configuration name).
  Reviewed (no required fix). Gate `es-e4b5`: 11 scenarios, frames, AppKit,
  unchecked, emulator, 20 clean launches, 29 suite runs; from clean builds the
  iPad and Apple TV simulators: vs and playback with frames identical to the
  AppKit reference. Device packaging not run.
  [Evidence](../evidence/es-e4b5-uikit-host.json).
- 2026-10-19 E4b-6: the Android host is the engine library `NTSDAndroidHost`
  with `CAndroidNative` (four files and the C target by `git mv`); the game's
  content bundle folder name comes from the game, and its `NTSDAndroid`
  library keeps the `@_cdecl` entry as its one call. Review: one required fix,
  `android_speed.py`'s window-drawing phase (the moved symbol's new mangling),
  made and confirmed. Gate `es-e4b6`: 11 scenarios, frames, AppKit,
  unchecked, emulator vs, 20 clean launches, 29 suite runs; emulator playback
  equal with frames identical to the previous step's APK; phone profiles find
  the phase in both libraries (10.4%); phone 3 against 2 left render apart
  (faster), the 4-against-4 follow-up overlaps everywhere.
  [Evidence](../evidence/es-e4b6-android-host.json).
- 2026-10-19 E4c-1: 38 test files (105 tests) move by `git mv` to the engine
  test target `NTSDEngineTests`, the exclusivity check is copied, and the
  moved suites' Linux init lines move with them; `swift test list`: 838 before,
  106 + 733 after, none lost. The rest stays: 11 files mix synthetic tests
  with content reads (E4c-2 splits them), the War trio waits for a game suite's
  own helpers, and the classification found original data in the engine
  (`OriginalWarTroops`' table from 0x44d350, for E5/E7). Review: one required
  fix (the Linux suite runners take the module), made and confirmed. Gate
  `es-e4c1b` (`es-e4c1` stopped at its builds for the fix and a memory
  shortage): 11 scenarios, frames, AppKit, unchecked, emulator, 20 clean
  launches, 29 suite runs, the engine's 106 tests; Linux: both test targets
  build, the engine's 35 suites run (one root-only failure, as at HEAD);
  the Mac A/B's load gap (identical machine code) gone 4 against 4.
  [Evidence](../evidence/es-e4c1-engine-tests.json).
- 2026-10-19 E5a (read only): two surveys (100 object-ID rows in 27 Core
  files; the AI's dispatch at `0x403a40`; `initial.bin` as the EXE's `.data`;
  two engine tables that copy it, test-only; 2.8.3.3 changes the layout) and the
  E5 design, reviewed: five required changes made and confirmed (the 122 role
  ×3, value predicates for non-ordinal IDs, the profile per session with the
  content, the bit-exactness constraints, E5c-0 and the extra gates).
  [Evidence](../evidence/es-e5a-design.json).
- 2026-10-19 E5b: `OriginalRecordLayout` backs the record's named constants
  (machine code identical in every shared function, from same-path clean
  builds); the two copied tables leave the engine after comparing equal to
  `initial.bin` word for word, and the game tests read the record instead.
  Reviewed (no required fix). Gate `es-e5b`: 11 scenarios, frames, AppKit,
  unchecked, emulator, 20 clean launches, 29 suite runs, the 8 table and
  startup suites; WASI vs (32-bit) identical; every `*Check` product built.
  The engine bundle's one failure is a nondeterministic test (5 of 10 from the
  same binary, JSON key order), not E5b's: corrected next (E4c-1a). Phone
  3 against 2 apart on load and main, 4 against 4 overlapping. Notes: the
  bracket card's links went stale in E4a; the War trio now reads the record
  (E4c-2 needs synthetic War words); 2.8.3.3 still calls the removed APIs.
  [Evidence](../evidence/es-e5b-record-type.json).
- 2026-10-19 E4c-1a: `OriginalAudioBytesUniformTests` compared two
  `JSONEncoder` outputs whose key order varies (hash order); with
  `.sortedKeys` it passes 30 of 30 on macOS and 10 of 10 on Linux, the engine
  bundle 106 of 106. Test only; reviewed (no required fix; no production code
  compares this JSON). The next gate covers it.
  [Evidence](../evidence/es-e4c1a-sorted-keys.json).
- 2026-10-19 E5c-0: the game profile's plumbing and its first role.
  `OriginalIDSet`/`OriginalGameRules` (engine) travel from the game's content
  identity through the catalog inputs into `OriginalLoadedCatalog` and the hit
  and contact passes, with no default anywhere; the five reflection checks read
  `rules.reflectable`; NTSD's values live in the new game target `NTSDProfile`.
  Note and change reviewed (no required fix after the note's revision); new
  tests reach reflection (A14, A15, A16, A20) and fail on wrong wiring. Gate
  `es-e5c0`: 11 scenarios, frames, AppKit, unchecked, emulator, 20 clean
  launches, 29 suite runs, the engine's 108 tests, `swift_beginAccess` 3,276
  unchanged; the changed passes' 9 suites; WASI vs identical. Phone: 3 against 2
  slower, 4 against 4 faster on the same measures (noise; pooled ranges overlap),
  and profiles show the gameplay body's share unchanged (10.9% against 11.3%).
  [Evidence](../evidence/es-e5c0-profile-plumbing.json).
- 2026-10-19 E5c-1a: the profile's roles in one storage (a pass copy is one
  reference); the reflection family completed: `reflector` 209, `rebinder` 8,
  `heldRebinder` 213 at A8, A13–A16 and A20, compared as the literals were; a
  moved profile (210/9/214) shows the sites follow it. Reviewed (one comment
  fixed). Gate `es-e5c1a`: 11 scenarios, frames, AppKit, unchecked, emulator,
  20 clean launches, 29 suite runs, the engine's 108 tests, `swift_beginAccess`
  3,276; the changed passes' 9 suites; WASI vs identical; phone and Mac A/B
  overlapping. [Evidence](../evidence/es-e5c1a-reflector-roles.json).
- 2026-10-19 E5c-1b: the rules grouped by family (`Reflection`, `Armour`);
  the armour rows A1–A6 become roles (`guardPenetrators`, `steadyArmour`,
  `openingArmour`, `attackerArmour`, `alwaysBlocked`, `armourGuardSound`), the
  thresholds staying engine code (the E5 design's armour hook dropped for NTSD
  2.4). Reviewed (no behaviour change; design revision recorded). Gate
  `es-e5c1b`: 11 scenarios, frames, AppKit, unchecked, emulator, 20 clean
  launches, 29 suite runs, the engine's 108 tests, `swift_beginAccess` 3,276;
  10 suites with the armour tests; WASI vs identical. Phone: main 3 against 2
  apart, 4 against 4 touching (process lower), profiles unchanged; Mac A/B noisy
  (the user's release builds ran meanwhile).
  [Evidence](../evidence/es-e5c1b-armour-roles.json).
- 2026-10-19 E5c-1c: the special interactions become a third family:
  `holdKind101` {120, 124} (A17, A18), `pullImmune` {201, 202} (A19),
  `teamBypass` 212 (A21, A22), `countsAsCharacter` {201, 202} (A23); the items
  family moved after its passes' plumbing. Reviewed (docs corrected; the role
  renamed). Gate `es-e5c1c` (after the user's platform release finished):
  11 scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29
  suite runs, the engine's 108 tests, `swift_beginAccess` 3,276; 11 suites;
  WASI vs identical; phone and Mac A/B overlapping.
  [Evidence](../evidence/es-e5c1c-interaction-roles.json).
- 2026-10-19 E5c-1d: a fourth family, `Impact`: `vanishingAttacker` 201 (A9),
  `spentAttacker` 214 (A10), `heavyHeldWeapon` 100 (A11). Reviewed (docs
  corrected); direct `damageHit` tests now reach A9, A10 and A8 (mapping-only
  since E5c-0), and `hitHorizontal` A11. Gate `es-e5c1d`: 11 scenarios, frames,
  AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the engine's
  108 tests, `swift_beginAccess` 3,276; 12 suites; WASI vs identical; phone peak
  footprint apart 3 against 2, overlapping 4 against 4; Mac overlapping. The
  hit and contact passes keep only A7 and A24–A26 (E5e hooks) and A39–A41 (items).
  [Evidence](../evidence/es-e5c1d-impact-roles.json).
- 2026-10-19 E5c-2a: `OriginalIDRange` and a fifth family, `Items`:
  `itemRange` 100..<200 (A39), `scarceDropItems` {122, 123} (A40),
  `spawnHP200` 122 (A41) in the hit pass's random item spawn; no plumbing.
  Reviewed (one test fix: the mode-1 case pins its exact error, draw and
  no-spawn; tests sharpened, role renamed). Gate `es-e5c2a`: 11 scenarios,
  frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the
  engine's 110 tests, `swift_beginAccess` 3,276; 13 suites with 44 tests; WASI
  vs identical; phone main, render and process time apart 3 against 2 (the new
  build faster), overlapping 4 against 4; Mac overlapping.
  [Evidence](../evidence/es-e5c2a-items-roles.json).
- 2026-10-19 E5c-2b: `rules:` plumbed into the camera's bounds and the links
  pass; `keptOnScreen` {122, 123} (A42), `hpDrink` 122 (A43), `mpDrink` 123
  (A44). Reviewed (role docs corrected; two test cases added). Gate `es-e5c2b`:
  11 scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs, the engine's 110 tests, `swift_beginAccess` 3,276; 17 suites with 54
  tests (camera, links and cpoints corpora included; the commit message's 55
  is a miscount, the evidence has 54); WASI vs identical; phone
  overlapping; Mac load time apart 3 against 3 (the new build faster),
  overlapping 4 against 4. [Evidence](../evidence/es-e5c2b-camera-links-roles.json).

## Next task

E5c-2c (plumbing map: [report](../evidence/es-e5c2-plumbing.md) §1–2, §4):
`OriginalPostDrawCommands`' `Body` takes `let rules` and both internal
`apply(world:)` overloads a required `rules:` (`catalog.rules` from `run`);
`OriginalMissionStagePass` takes `let rules` (`catalog.rules` in `apply`). The
explicit test calls (OriginalPostDrawCommandsTests ×6, OriginalLibStageCommandsTests
×8) pass NTSD's rules; the engine's OriginalRequestSlotWordTests gets the engine
tests' first own rules value (synthetic, built in the engine's tests: no
NTSDProfile there). Roles: `itemRange` again (A48), a new `scarceRequestedItem`
122 (A49: the stream-208 coin flip only on an ID match), `spawnHP200` again
(A50, and A64 in the mission stage's spawn, `== 0x7a`). Tests: the requested
item spawn (`0x450bb8 = 1`) and the mission spawn under NTSD's profile and
moved ones. Gates as E5c-2b, with the post-draw, lib-stage and mission suites
in gate3. Then E5c-2's remaining rows (menus and modes, D1–D14) per the E5 design.
