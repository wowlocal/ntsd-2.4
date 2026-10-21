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
**Status:** E0–E3, E4a, E4b (all six hosts), E4c-1 (the engine's self-contained tests), E5a (the game profile's survey and design) and E5b (the record type, the copied tables out), E4c-1a (a nondeterministic engine test corrected) E5c-0 (the profile's plumbing, reflection), E5c-1a (one storage, the reflectors), E5c-1b (armour), E5c-1c (special interactions) and E5c-1d (impact) done; E5c-2a, E5c-2b and E5c-2c (the items family: the random and requested spawns, camera, links, the mission stage) E5c-2d (the roster family), E5c-2e (the modes family), E5c-2f (the match prelude) and E5c-2g (the mode label) done: E5c-2's menu and mode rows are in the profile; E5c-1e (physics), E5c-1f (drawing) and E5c-1g (the post-draw effects) and E5c-1h (the slot prefix, scheduler and round restore) and E5c-1i (the object input) and E5c-1j (A28, the input chain) done: every E5c row is in the profile; E5d-1a (the AI's target roles) and E5d-1b (its fight roles) done: every object-ID literal of the generic AI is in the profile; E5d-2 (the special-move hook) and E5d-3 (the 20 routines in the game) done: the AI's NTSD code is the game's; E5e (the coarse hooks) surveyed: roles, no new hook; E5e-1 (the ID-300 roles), E5e-2 (the mission pseudo-IDs), E5e-3 (War life), E5e-4 (fusion) and E5e-5 (the weapon break) done: every object-ID rule of the E5a table is the game's; E5f surveyed; E5f-1 (the front menu's names and rectangles, carried by the startup), E5f-2a (the interface and common sound names), E5f-2b (the menu and War names), E5f-3 (the menu WAVs) and E5f-4 (the panel and BATTLEMODE rectangles) done; E4c-2 (the mixed test files split) done; E7 surveyed; E7a (the engine alone on macOS and Linux) and E7b (the original-bytes scan: no unexpected hit; the policy for the expected classes is the user's) and E7c (a synthetic content pack loading on macOS and Linux) and E7d (a session load, a headless start and a VS match on it, equal on both) E7e-1 (the VC80 power-of-ten table computed) and E7f (a computer match to its end, the replay and text on the synthetic pack) done; the user settled the scan policy and granted D1, D2 and E8 (2026-10-21); E7e-2 (the policy enforced by the scanner) done; E6a (the LF2 2.0a reference pinned; every profile rule is LF2 2.0a code, NTSD's changes are lib.dll's) done; E6a-2 next.
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

Settled 2026-10-21 (the user: "принимаю твои рекомендации по правилам для
E7e, продолжай", then "разрешаю тебе все" and, after being told of LF2
Remastered's Steam release, "бро все разрешаю. действуй полностью автономно"):

- **Scan policy (E7e).** The published engine keeps vendored zlib, the DAT
  key (a format constant), Microsoft's DirectShow GUIDs, the data files' names
  and field vocabulary (the format) and the project's own labels; the VC80
  power-of-ten table is computed (E7e-1); EXE strings are sorted by D1's
  reference in E6. `tools/scan_original_bytes.py --policy` enforces it, with
  the loop's rules for the classes the recommendations did not name (E7e-2).
- **D1 — granted.** The official LF2 2.0a distribution is a second pinned
  reference, used to tell LF2 2.0a rules from NTSD's; NTSD behaviour is still
  recovered from the NTSD distribution. It stays outside the repository
  (E6a pins it).
- **D2 — delegated to the loop.** No "LF2" or "NTSD" in the name; the
  licence and the name are chosen and recorded at E8.
- **E8 — authorized**, publication included: a new public repository with
  fresh history, a tag and CI. Recorded 2026-10-21: lf2.net links "Little
  Fighter 2 Remastered", sold on Steam since 2025-07-18 by Little Fighter Co
  Pty Ltd and Marti Wong; the user confirmed after being told.
- The loop does not merge into main (not a step of this plan).

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
| E4 | Two packages: `engine/Package.swift` (Core, Runtime, codecs, decoders, shims, host libraries, self-contained tests) and `native/Package.swift` depending on it by path; the unsafeFlags plan (SwiftPM rejects them in version-pinned dependencies) | E4a **done** ([evidence](../evidence/es-e4a-engine-package.json)); E4b: headless **done** ([evidence](../evidence/es-e4b1-headless-host.json)), browser **done** ([evidence](../evidence/es-e4b2-web-host.json)), SDL **done** ([evidence](../evidence/es-e4b3-sdl-host.json)), AppKit **done** ([evidence](../evidence/es-e4b4-appkit-host.json)), UIKit **done** ([evidence](../evidence/es-e4b5-uikit-host.json)), Android **done** ([evidence](../evidence/es-e4b6-android-host.json)); E4c-1 **done** ([evidence](../evidence/es-e4c1-engine-tests.json)), E4c-1a **done** ([evidence](../evidence/es-e4c1a-sorted-keys.json)); E4c-2 **done** ([evidence](../evidence/es-e4c2-mixed-tests.json)); the War trio stays with the game (recorded) |
| E5 | Game profile: the ID sites (100 rows, about 125 branch points; first estimated ~90) and the AI dispatch behind a profile the game supplies; the engine defines the `0x44d000` record's layout and the game supplies `initial.bin`; the NTSD profile bit-exact (all gates plus the full fixture-driven suites); the API's fit with 2.8.3.3 checked read only | E5a **done** (survey and design, [evidence](../evidence/es-e5a-design.json)); E5b **done** ([evidence](../evidence/es-e5b-record-type.json)); E5c-0 **done** ([evidence](../evidence/es-e5c0-profile-plumbing.json)); E5c-1a **done** ([evidence](../evidence/es-e5c1a-reflector-roles.json)); E5c-1b **done** ([evidence](../evidence/es-e5c1b-armour-roles.json)); E5c-1c **done** ([evidence](../evidence/es-e5c1c-interaction-roles.json)); E5c-1d **done** ([evidence](../evidence/es-e5c1d-impact-roles.json)); E5c-2a **done** ([evidence](../evidence/es-e5c2a-items-roles.json)); E5c-2b **done** ([evidence](../evidence/es-e5c2b-camera-links-roles.json)); E5c-2c **done** ([evidence](../evidence/es-e5c2c-requested-mission-roles.json)); E5c-2d **done** ([evidence](../evidence/es-e5c2d-roster-roles.json)); E5c-2e **done** ([evidence](../evidence/es-e5c2e-modes-roles.json)); E5c-2f **done** ([evidence](../evidence/es-e5c2f-prelude-roles.json)); E5c-2g **done** ([evidence](../evidence/es-e5c2g-mode-label-roles.json)); E5c-1e **done** ([evidence](../evidence/es-e5c1e-physics-roles.json)); E5c-1f **done** ([evidence](../evidence/es-e5c1f-drawing-roles.json)); E5c-1g **done** ([evidence](../evidence/es-e5c1g-effects-roles.json)); E5c-1h **done** ([evidence](../evidence/es-e5c1h-lifecycle-roles.json)); E5c-1i **done** ([evidence](../evidence/es-e5c1i-object-input-roles.json)); E5c-1j **done** ([evidence](../evidence/es-e5c1j-input-roles.json)); E5d: [survey](../evidence/es-e5d-plumbing.md), E5d-1a **done** ([evidence](../evidence/es-e5d1a-ai-target-roles.json)), E5d-1b **done** ([evidence](../evidence/es-e5d1b-ai-fight-roles.json)), E5d-2 **done** ([evidence](../evidence/es-e5d2-ai-special-hook.json)), E5d-3 **done** ([evidence](../evidence/es-e5d3-ai-routines-in-game.json)); E5e: [survey](../evidence/es-e5e-plumbing.md), E5e-1 **done** ([evidence](../evidence/es-e5e1-id300-roles.json)), E5e-2 **done** ([evidence](../evidence/es-e5e2-mission-pseudo-ids.json)), E5e-3 **done** ([evidence](../evidence/es-e5e3-war-life.json)), E5e-4 **done** ([evidence](../evidence/es-e5e4-fusion.json)), E5e-5 **done** ([evidence](../evidence/es-e5e5-weapon-break.json)); E5f: [survey](../evidence/es-e5f-plumbing.md), E5f-1 **done** ([evidence](../evidence/es-e5f1-front-interface.json)), E5f-2a **done** ([evidence](../evidence/es-e5f2a-interface-sound-names.json)), E5f-2b **done** ([evidence](../evidence/es-e5f2b-menu-war-names.json)), E5f-3 **done** ([evidence](../evidence/es-e5f3-menu-sound-names.json)), E5f-4 **done** ([evidence](../evidence/es-e5f4-panel-war-frames.json)) |
| E6 | Classify each profile rule as LF2 2.0a or NTSD from the second reference; LF2 rules become the engine's default profile | D1 granted 2026-10-21; E6a **done** ([reference](../evidence/es-e6a-lf2-reference.json), [classification](../evidence/es-e6a-classification.json), [survey](../evidence/es-e6a-survey.md)); E6a-2 next (E6 design below) |
| E7 | Engine stand-alone: the engine package builds alone (macOS, Linux container) and passes its tests with a from-scratch synthetic content pack; a scan finds no original bytes (files under `downloads/`, the resources, fixtures, `initial.bin`) | [survey](../evidence/es-e7-survey.md); E7a **done** ([evidence](../evidence/es-e7a-standalone.json)), E7b **done** ([evidence](../evidence/es-e7b-scan.json); policy open, the user's), E7c **done** ([evidence](../evidence/es-e7c-synthetic-pack.json)), E7d **done** ([evidence](../evidence/es-e7d-synthetic-runs.json)), E7e-1 **done** ([evidence](../evidence/es-e7e1-power-table.json)); E7f **done** ([evidence](../evidence/es-e7f-synthetic-match-end.json)); E7e-2 **done** (the policy enforced, [evidence](../evidence/es-e7e2-scan-policy.json)); EXE strings follow E6 |
| E8 | Publication: name, licence, a new repository with fresh history, a tag; this repository depends on it by revision; README credits | authorized 2026-10-21 (D2 delegated) |

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
  stage→background map, labels, menu cycles) move. (Revised in E5c-2e, F3
  option B: the stage predicates and D8's map move; the decade arithmetic,
  D15's sixty stages and the label strings stay engine code; a set size other
  than 10 joins the D1/E7 list.) lib.dll's hooks (ITR kinds
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

### E5c-2c note (2026-10-19, reviewed with its change; done)

From the plumbing map ([report](../evidence/es-e5c2-plumbing.md) §1–2, §4).
- **Plumbing.** `OriginalPostDrawCommands`' private `Body` holds `let rules`;
  both internal `apply(world:)` overloads take a required `rules:` (after
  `background:`), passed through the slot-word overload and the copying call;
  `run` passes `catalog.rules` from its local catalog copy.
  `OriginalMissionStagePass` holds `let rules` from `catalog.rules` in its one
  construction. No public or package signature of the passes changes (the
  public surface added: `Items.init`'s new parameter and the two
  `scarceRequestedItem` accessors); the 14 explicit native test calls pass
  NTSD's rules.
- **The engine tests' own rules.** `OriginalGameRules.engineTests`
  (engine/Tests/NTSDEngineTests/EngineTestRules.swift): synthetic, every ID role
  −1 and every set empty, except the item range 100..<200 the requested-items
  pools (Object ID 100) are built on; `OriginalRequestSlotWordTests` uses it.
  The engine's tests still build records with IDs (999, 998, 217, 2) for sites
  that keep their literals (the post-draw lifecycle's, E5c-2's later rows).
- **Roles (Items).** `itemRange` again (A48: the same rule as A39),
  `scarceRequestedItem` 122 (A49: a coin flip on stream 208 only on an ID match,
  no mode test; its own role, not `scarceDropItems`), `spawnHP200` again (A50,
  and A64 in the mission stage's spawn, where the original compares with 0x7a).
  The library path (0x450bb8 = 3) compares the DLL's requested ID instead and
  has no ID rule.
- **Tests.** The requested spawn through `apply(world:)` with 0x450bb8 = 1 and an
  RNG table whose first draw over 2 is chosen (A48 range, A49 coin flip and
  its absence under a moved role, A50 HP 200 or 500), and the mission pass's
  `spawn` built directly (A64: HP 200 or the stage's 300), under NTSD's profile
  and moved ones.
- **Review.** No code fix (literals restored, plumbing removed: both files
  byte-identical to HEAD). Required: the claim that the engine tests name no
  game IDs (they do, for sites still literal) withdrawn; the item range's doc
  says a requested spawn creates every kept item; HP 200 is of 500 only in the
  random and requested spawns. Adopted with it: the engine rules' doc, the
  scarce requested item's range condition, the public surface listed.

### The remaining role rows (survey 2026-10-19; decisions open)

A read-only survey ([report](../evidence/es-e5c-rest-plumbing.md)) mapped the
rows still literal outside E5d (AI) and E5e (hooks): physics A33–A38, drawing
A45–A46, the post-draw effects and lifecycle (A29, A31, A32, A47, A55–A59),
the War troop list A65, the roster and menus A70–A79, and the stage rules
D1–D14. A66/A68 read their IDs from the record (no literal), A69 left in E5b,
A100's 101 is a hold kind, not an ID. Its findings, each to be settled with its
increment's review and recorded there:
- **F1.** Five ID literals the E5a table missed: `OriginalPostDrawSlotPrefix`
  217/218, `OriginalPostDrawLifecycle` 998 and 999 ×2, `OriginalMatchSelection`
  `decade < 5`; when they move, `OriginalGameRules.engineTests` must carry
  217/218/998/999 or `OriginalRequestSlotWordTests` changes outcome.
- **F2.** D14's stage half (`OriginalWorldCamera` `g(0x450b94)/10 == 5`) is still
  literal (E5c-2b moved the ID half).
- **F3.** The stage decades: the survey recommends the decade arithmetic (10,
  the wrap at 60 = D15's capacity) stay engine code and only the predicates
  (survival 50..<60, numbered stages below 50, the final set 40..<50) and D8's
  stage→background map move; the design's wording moves "decades" too.
- **F4.** The fusion hook is narrower than the design's "five files": A27 has no
  literal; A28 (6 → 300), A29 and A30 ({51, 52}) read no fusion field and can be
  roles.
- **F5.** A35's thrown gravities stay engine values; the profile names the three
  Objects (the E5c-1b precedent).
- **F6/F7.** A45 and A57 read the header twice; a set test reads it once (a pure
  read: the same outcome). A46 as one set of the 19 unlabelled IDs instead of a
  range with an exception.
- **F8.** Shared roles: survival (D2/D3/D10/D14), numbered stages (D4/D6/D9 and
  F1's menu row), the bracket pair A78/A79; A45 and A55 stay separate.
- **F10.** Unlike E5c-1/2, physics, scheduler, prelude, mode label and gameplay
  output change public signatures (a `rules:` parameter).
- **F11.** Every new family edits all 11 `OriginalGameRules(` constructions; a
  test helper cuts that to the profile, the engine tests' value and the helper.
Order: E5c-2d roster, E5c-2e modes (mission, camera, War), E5c-2f prelude,
E5c-2g mode label, then the hot passes E5c-1e physics, E5c-1f drawing, E5c-1g
effects, E5c-1h lifecycle, E5c-1i object input, E5c-1j A28 (after F4).

### E5c-2d note (2026-10-19, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §2, §6).
- **Test helper (F11).** `OriginalGameRules.with(...)` in the game's tests
  (NTSDProfileTestRules.swift) copies a profile with the given families
  replaced; the 9 test constructions use it, so a new family now edits only the
  game's profile, the engine tests' value and the helper.
- **Roster family (sixth).** `hiddenRoster` {30–39, 50–59} (A70 character
  screen, A71 computer selection, A72/A73 the tournaments' setups:
  `id/10 ∈ {3, 5}` is exactly that set for every `Int32`, Int32 division
  truncating toward zero; 0x458428 stays read only for members),
  `randomCandidates` `OriginalIDRange(Int32.min..<30)` (A74 continuation,
  A75/A76 the tournaments, A77 War: `id < 30`; the type test, ordinal 0 and the
  selected seats stay engine), `bracketFavourites` {50–59} (A78 tournament,
  A79 team tournament: `id/10 == 5`; the coin flip's stream still follows the
  first side's membership; one rule in both brackets, a sharing the design's
  list did not name, recorded here). Each site reads the rules of the catalog
  it already holds (`candidate.catalog.rules`, `catalog.rules`): no new
  parameter, no public signature change.
- **Tests.** A74 through `randomRosterCandidates` on a small declared catalog
  (NTSD's profile: IDs below 30, a negative one included; a moved range: the 30s
  and 40s; no seat selects ordinal 0), A77 through the War setup's own native
  harness (its catalog builder takes the rules: the first seat's Random
  candidates are ordinals 11…22 under NTSD's profile, 1…8 and 23 under a moved
  range), A72 through the tournament setup with Right pressed (the roster stops
  at 122 past the hidden 30s, at the first 30 with 0x458428 = 1, past a moved
  set's two), A78 through the bracket to its checkpoint 0x433c22 (55 beats 5
  without a coin flip; moved favourites reverse it, both members or none flip
  on stream 0xfb or 0xfa). A70, A71, A73, A75/A76 and A79 rest on the mechanical
  check and the loaded-catalog menu corpora under NTSD's profile.
- **Review.** No code fix (the literal forms restored: all 8 engine files
  byte-identical to HEAD). Required: the moved-profile tests the Next task
  named (A72's hidden roster, A78's bracket), and Random's users (computer and
  match selection) in the docs. Adopted with it: no seat selects ordinal 0 in
  A74's test, a negative ID there, the engine rules' note on the menus.
- **Access count (gate run `es-e5c2d`, failed).** Reading
  `candidate.catalog.rules` inside the menus' nested functions (which capture
  the local `var candidate`) raised the checked headless build's
  `swift_beginAccess` count from 3,276 to 3,279 (the app 3,404 to 3,407); the
  run is kept as failed and its extra rows were stopped. Fix: each of the seven
  functions reads `let rules = state.catalog.rules` once at the top (a static
  read of the `inout` parameter; `catalog` is a `let` and `candidate` is only
  ever `state` or a copy, so the sites see the same rules). A clean build then
  counts 3,278: a second read-only review disassembled `roster` in both
  tournament setups (10 → 11 sites each, every other function unchanged) and
  found the optimizer emitting the `write(flag,1)` exit block twice instead of
  sharing it once `contains` is inlined; per path the number of dynamic
  accesses is unchanged (no new check executed), on a key-press menu path. Two
  other source forms gave the same count. Recorded as a dated change of the
  static count's baseline (3,278 headless; the app as `es-e5c2d2` measures it),
  not an unchanged row; earlier rows keep their 3,276.

### E5c-2e note (2026-10-19, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1–3, §6).
- **F3 settled (option B).** The stage predicates move; the decade arithmetic
  stays engine code: ten stages a set (D1's `s%10 == 0`, D5's `s%10 == 9`, D7's
  next-set formula `(q·5+5)·2`, D12/D13's rounding) and D15's sixty stages (D11's
  wrap). They are the stage loader's layout, as the E5 design keeps D15.
- **Modes family (seventh).** `survivalStages` 50..<60 (D2 the blink flag, D3 the
  survival revive, D14 the camera's stage half: `s/10 == 5`), `numberedStages`
  `Int32.min..<50` (D4 as `!contains`: `q >= 5`; D6: `s < 0x32`; F1's menu row
  N5 in match selection: `decade < 5`), `finalStageSet` 40..<50 (D7: `q == 4`;
  its single `g(0x450b94)` read kept), `stageWeightPlus1` 51 and
  `stageWeightPlus2` 52 (A30: two independent tests, as now), `warTroops`
  {30–37, 39, 122, 123} (A65: `UInt32(bitPattern: id &- 30) <= 9 && id != 38`
  or 122/123). Each replacement is exact for every `Int32` (truncating division;
  the unsigned compare is 30…39). Shared as F8 proposed: survival by D2, D3,
  D14 (and D10 in E5c-2g), numbered stages by D4, D6, N5 (and D9 in E5c-2f).
  The labels and the mode tests stay engine.
- **Plumbing.** The mission pass and the camera already hold the rules; the War
  battle pass takes `let rules` at its one construction; match selection reads
  `let rules = state.catalog.rules` once (E5c-2d's static read). No public
  signature changes.
- **Tests.** The mission pass built directly: `hud`'s stage line (stage 15
  "STAGE 2-6", 55 "Survival Stage: 3", −1 numbered; a moved range turns 55 into
  "STAGE 6-6" and 15 into the survival line) and `setTail(3)` on the wipe's last
  step (45 goes to the menu, 35 to the next set; a moved last set swaps them);
  the camera's survival case with a moved range and the boundaries 49/50,
  59/60, 39/40; the mission pass's `run` on stage 0 (one phase, every slot
  empty): D2's blink and D3's revive to HP 5 under a moved survival range,
  D4's banner (the digits under NTSD's profile, the survival bitmap under a
  moved numbered range); War's battle pass (A65): a side-1 unit 31 at its
  limit keeps the reserve under NTSD's profile and spawns one under a moved
  troop list, past the spawn step both times. A30 and N5 rest on the
  mechanical check and the mission and match selection corpora (whether the
  latter holds mode-1 stages from 50 is not checked).
- **Review.** No code fix (each literal restored: the four engine files
  byte-identical to HEAD; every predicate checked over all 2³² values).
  Required: no test suite instantiates another (swift-corelibs-xctest has no
  `init()`; the camera helper is now a shared static), the named survival and
  War tests (added), D4 among the tested rows, the access count recorded: the
  clean release headless build counts 3,278, the baseline. Adopted with it:
  the design bullet's annotation, `finalStageSet`'s wording, survival and
  numbered not complements, the boundary cases.

### E5c-2f note (2026-10-19, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §3, §6).
- **Plumbing (F10: a public signature change).** Both public
  `OriginalMatchPrelude.apply` overloads take a required `rules:` after the
  local time; the one forwards it. `Modes.init` gains a required
  `stageBackgrounds:` (its four constructions updated). Callers: the application's match launch
  (`model.catalog.rules`, read next to its `model.globals` read), and the
  MatchLaunch and MatchPrelude reference checks, which pass `NTSDProfile.rules`
  (`OriginalMatchPreparation.catalog` is internal to the engine; these checks
  build their states from catalogs loaded with NTSD's rules, so the value is
  the same and the engine's public surface does not grow).
- **Roles (Modes).** `stageBackgrounds` `[Int32: Int32]` = [0: 1, 10: 2, 20: 3,
  30: 4, 40: 5, 50: 6] (D8: the dictionary literal, the same lookup; other
  stages keep their arena), and D9's replay name suffix through
  `numberedStages` (`group < 5` with `group = stage/10` is `stage < 50` for every
  `Int32`; the strings and `group+1` stay; D9's block keeps its single 0x450b94
  read, D8's block its own).
- **Tests.** The prelude in stage mode from arena 77: stages 10 (arena 2,
  "_Stage_2"), 49 (arena kept, "_Stage_5"), 50 (arena 6, "_Survival"), 55 (arena
  kept, "_Survival") under NTSD's profile; a moved map [55: 9] and numbered
  range below 60 give 55 arena 9 and "_Stage_6", 10 keeps its arena; a
  numbered range below 10 makes 10 "_Survival".
- **Review.** No fix required (literals restored: both engine files
  byte-identical to HEAD; the reference checks' catalogs are all loaded with
  NTSD's rules). Adopted: the narrowed-range case, the docs, the call-site
  comments. The clean release build counts 3,278 (the baseline; the launch's
  `model` read sits next to its `model.globals` read).

### E5c-2g note (2026-10-19, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §6).
- **Plumbing (F10: public signatures change).** `OriginalModeLabel.draw` and
  `drawInPlace` take a required `rules:` after the globals; so do the four
  `OriginalGameplayOutput` entry points (after `input:`; public
  `returnFromDispatcher`, `apply`, `applyInPlace`, package
  `returnFromDispatcherInPlace`), each forwarding it: five public signatures, one
  package.
  The gameplay body (every tick) and paused gameplay read `let rules =
  state.catalog.rules` once from their `inout` state before copying it (the
  E5c-2d lesson: no read through a captured copy); the gameplay return reference
  check passes NTSD's rules (its states' catalogs are loaded with them); the 8
  explicit test calls pass NTSD's rules. A clean release headless build counts
  3,278 `swift_beginAccess`, the baseline (the app's count comes with the gate).
- **Site.** D10: `staged.integer(at: 0x450b94…)/10 == 5` →
  `rules.survivalStages.contains(…)` (the same read, only in mode 1; exact for
  every `Int32`), the survival role D2/D3/D14 already share.
- **Test.** The label in stage mode for stages 49, 50, 59, 60 (NTSD's profile)
  and 55, 65 (a moved range): three stores for "Stage mode ", four more for
  "Survival Stage "; the synthetic globals then stop at the label's font (the
  expected "Bitmap font: Null resource").
- **Review.** No fix required (literal restored, rules removed: the four engine
  files byte-identical to HEAD; no caller missed; the return reference's
  catalogs are loaded with NTSD's rules; `state` is an `inout` parameter read
  before any copy). Adopted: the public/package split, the headless wording,
  the call-site comment.

### E5c-1e note (2026-10-20, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §2, §5, §6).
- **Physics family (eighth).** In the actor physics (per actor, per tick):
  `extraDrift` 120 (A33: `type == 4 || id == 120`), `reverseDrift` 101 (A34),
  `lowGravityThrow` 124, `midGravityThrow` 120, `highGravityThrow` 101 (A35: the
  state-1002 chain, tested in that order; the gravities stay engine values, F5),
  `restingPiece` 999 (A36: a non-weapon Object's landing to frame 101). In the
  world physics: `revivalPicture` 30..<37 (A37: `(30...36).contains`, exact
  for every `Int32`), `revivalEffect` 998 (A38: `find(998)`, still after the
  free-slot scan). Equal NTSD values in different roles stay separate roles
  (F9: 120 in A33 and A35, 101 in A34 and A35).
- **Plumbing (F10: a public signature change).** The actor physics' internal
  `apply(header:)` and the public `apply(object:)` take `rules:` after the
  globals and pass it as a parameter to `Body.run` and `objectLanding`: the
  `Body` is built per Actor per tick, and a field would retain the rules each
  time (the survey's §5 form; the hit pass's `let rules` is built once per
  pass); the world physics' internal `apply(world:)`
  takes it after `frame:` (through its copying call) and passes it to the actor
  physics; `run` passes `catalog.rules` from its local catalog copy. The state
  entry points and their callers (the gameplay body, the match launch
  reference) do not change; the 8 explicit test calls pass NTSD's rules. The
  public surface added: `Physics`, `physics:` on `OriginalGameRules.init`, nine
  accessors.
- **Tests.** One actor physics step per row with synthetic headers (x from 100
  with vx 10: ±2 for the drifts; vy from the three gravities and the default;
  frame 101 for the resting piece), and the world physics' revival (+0x318 =
  140 for 31, not 37; the 998 effect spawned, none under a moved ID), under
  NTSD's profile and moved ones; all three gravity roles moved, the first match
  winning on a duplicate ID, a type-4 Object's drift, a 999 weapon not
  stopping.
- **Review.** No correctness defect (literals restored, plumbing removed: both
  files byte-identical to HEAD). Required: moved-profile tests for A35's 120
  and 101 (added), and the rules as a parameter instead of a per-Actor `Body`
  field (done; a field would add a retain per Actor per tick). Adopted: the role
  docs (types, the grounded stop each tick, the revival's Object), the extra
  cases, the public surface listed.

### E5c-1f note (2026-10-20, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §2, §5, §6).
- **Drawing family (ninth).** `shadowless` {223, 224} (A45) and
  `unlabelledComputers` {30–37, 39–49} (A46). F6 settled: A45's
  `h(0x6f4) != 223 && h(0x6f4) != 224` becomes `!shadowless.contains(h(0x6f4))`
  in the same place of the lazy `&&` chain; HEAD's code read the header twice
  for any ID other than 223 and once for 223 (the EXE was not examined here), the set test reads it once: the
  read is pure (the same header record, no state change between), so the outcome
  and any throw are the same. F7 settled: A46's `id < 30 || id >= 50 || id == 38`
  becomes `!unlabelledComputers.contains(id)`; its complement is exactly {30–37,
  39–49} for every `Int32`. The opoint's {223, 224} (A55) stays its own role in
  E5c-1g (F8).
- **Plumbing.** The internal `draw(world:)` takes a required `rules:`;
  `applyInPlace` passes its local catalog's rules; the state entry points and
  their callers (the gameplay body, paused gameplay, the gameplay drawing
  reference) do not change; one explicit test call passes NTSD's rules; `draw`'s
  doc says its `header` closure must be pure (F6 relies on it; all three
  closures are). The public surface added: `Drawing`, `drawing:` on
  `OriginalGameRules.init`, three accessors.
- **Tests.** `draw(world:)` with one active Actor whose blink counter leaves only
  the row under test (−28: the shadow alone; −22: the label alone), stopping at
  the first bitmap fetch after its "draw" event: the shadow for 5, none for
  223/224; the label for 29, 38, 50, −1 and none for 30, 37, 39, 49; moved sets
  swap them, 224 included, and 29 and 38 lose the label under a set holding them.
- **Review.** No correctness defect (literals restored: byte-identical to HEAD;
  A46 exact for every `Int32`; every header closure pure, so F6's single read
  is accepted). Required: the note says HEAD's code read the header twice, not
  the EXE. Adopted: the purity doc on `draw`, the partial-literal cases, the
  public surface; the sets stay inline (about two retain pairs per drawn actor
  at worst; the same pattern runs in the hit pass).

### E5c-1g note (2026-10-20, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §2, §5, §6).
- **Effects family (tenth).** Opoint (`OriginalPostDrawOpoint`, per slot):
  `fixedDepthChildren` {223, 224} (A55: a child in 3000/1002/3006 takes its z
  speed from the parent's up/down except these; its own role, not
  `shadowless`, F8), `quarterDepthChild` 211 (A56; the re-read of the child's
  source kept), `weakChildren` {5, 52} (A57: HP, its maximum and the third HP
  word 10, MP 5; F6: one read where HEAD's code read twice for any source other
  than 5, every header closure on these paths being pure). Lifecycle
  (`OriginalPostDrawLifecycle`): F1's rows `commandEffect` 998 (N2: `free()`
  and `find` together, the catalog cursor still stepped), `deathParticles` 999
  (N3: leaving state 13 or frame 200) and `fireParticles` 999 (N4: states 18 and
  19), named after the engine's own `deathSlot`/`fireSlot`; equal values in
  separate roles (F9). A53's `find(999)` (weapon break) stays for E5e's hook.
- **Plumbing.** The opoint's two internal entry points take `rules:` after
  `frame:` (the public `apply(state:)` passes its catalog's) and pass it to
  `Body.run` as a parameter (the Body is built per slot: the E5c-1e
  lesson); the lifecycle's internal `apply(world:)` takes `rules:`, its `Body`
  (built once per call, iterating the slots) holds `let rules` and passes it to
  the opoint (`self.rules` at the call, as `header`/`frame` there); `run`
  passes the catalog's; both internal entry points document that `header` must
  be pure. `OriginalGameRules.engineTests`
  carries 998 and 999 for the effects (the request-slot tests' lifecycle pools,
  F1); those 10 tests keep their outcome, three of them depend on these values. 9 explicit test calls pass the rules.
  The public surface added: `Effects`, `effects:` on `OriginalGameRules.init`,
  seven accessors.
- **Tests.** One opoint child (state 3000, the parent holding Up): z speed
  −2.5, 0 for 223/224, −0.625 for 211; HP 10 for 5/52, 500 otherwise; moved
  roles swap them. The lifecycle for one slot: the command's effect spawned for
  998 (none and the cursor run to the count under a moved ID), the death and
  fire particles for 999 (none, or the fire path's provenance error, under
  moved IDs).
- **Review.** No correctness defect (literals restored, rules removed: both
  files byte-identical to HEAD; every header closure pure; the opoint Body has no
  rules field; the lifecycle's is built once per tick). Required: the note's
  entry-point wording (fixed). Adopted: the purity docs, exact role docs (the
  three HP words; the death and fire particles' conditions), the engine rules'
  doc.

### E5c-1h note (2026-10-20, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §2, §5, §6).
- **Lifecycle family (eleventh).** Slot prefix (`OriginalPostDrawSlotPrefix`,
  per slot): `halfHPRegen` {51, 52} (A29: MP regeneration from HP/2; the source
  read once, as before), `state9995Object` 50 (A31: `find(50)`; `put(0x70, 0)`
  after it whether or not it matched), F1's `pieces` 217 and `lastPiece` 218
  (N1: `find(ordinal == 4 ? 218 : 217)` after the free-slot guard; a miss keeps
  the retained index). Scheduler (`OriginalActorScheduler`, per Actor):
  `noRiseInvulnerability` {30–37, 39} (A47: `sourceID / 10 == 3 && sourceID != 38`,
  exact for every `Int32`, still read only in the mode 1/4 special branch; the
  scheduler writes +8 = 15, the invulnerability countdown, not a state).
  Round restore (`OriginalMatchRound`): `roundRevertFrom` 50 and `roundRevertTo`
  6 (A32: 0x458428 still read only on an ID match; F4: a role, not the fusion
  hook).
- **Plumbing.** The slot prefix's internal entry points take `rules:` after
  `frame:` (the two public ones pass their catalog's) and pass it as a parameter
  to `Body.run`, `particles` and `resources` (the Body is built per slot); the
  prefix passes it to the scheduler, whose public `apply(object:)` (F10) and
  internal `apply(header:)` take it and pass it to `Body.run` as a parameter
  (per Actor); the lifecycle passes its `rules` to the prefix; the round
  restore reads `let rules = catalog.rules` once at its top (a mutating method:
  a static read). `OriginalGameRules.engineTests` carries 217/218 (the
  request-slot tests' prefix pool); its other new roles are −1 or empty, which
  gives the same answers for those pools. 12 explicit test calls pass the rules.
  The public surface added: `Lifecycle`, `lifecycle:` on
  `OriginalGameRules.init`, eight accessors.
- **Tests.** The slot prefix: MP regenerates by 2 from HP 400, by 4 for 51/52
  (moved sets swap them); a 9995 character becomes Object 50 (none under a
  moved ID); the pieces of 217 with the fifth of 218, the retained index when
  218 is missing, the provenance error when neither is found. The scheduler: a
  team-5 character leaving a state-14 frame gets the invulnerability countdown
  (+8 = 15) unless 30–37 or 39 in modes 1 and 4. The round restore through `beginMatchRound` on a
  small declared catalog (the roster tests' builder, now a shared static
  helper): 50 reverts to the first 6, moved roles follow.
- **Review.** No correctness defect (literals restored, plumbing removed: the
  engine files byte-identical to HEAD; no rules field on the per-slot or
  per-Actor bodies; the engine tests' prefix pool needs only 217). Required:
  A47's wording: +8 = 15 is the invulnerability countdown (STATE_LAYOUT), not
  a state; the role is named `noRiseInvulnerability` (first written
  `noLyingDelay`) and its doc gives the frame and team conditions. Adopted: the
  A31 miss keeps frame 0, the unused roster-test helpers removed.

### E5c-1i note (2026-10-20, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §2, §6).
- **Roles (Effects).** `burstChild` 225 (A58: `find(0xe1)` in `burst`, an
  Object's hit_Fa 8 split into three or more Objects aimed at random enemies)
  and `escortChild` 219 (A59: `find(0xdb)` in `escort`, one per living allied
  character); each `find` stays after its free-slot scan in the same `guard`.
- **Plumbing.** `OriginalObjectInputPass` is built per slot, so the rules go as
  a parameter of `run` to `burst` and `escort` (the survey proposed a pass field;
  a parameter avoids its per-slot retain, the E5c-1e lesson); `applyInPlace`
  passes its catalog's; no signature of the entry points changes (`run` is
  internal). The public surface added: two `Effects` fields and accessors, and
  `Effects.init`'s two parameters.
  `Effects.init` gains `burstChild:` and `escortChild:` (its constructions
  updated); `OriginalGameRules.engineTests` gives −1 (no engine test reaches the
  object input).
- **Tests.** The pass built directly for slot 10 (a type-1 Object whose frame
  has hit_Fa 8 or 5) with an ally in slot 11: three bursts of 225 without
  enemies, one escort of 219 for the ally; none under moved IDs, the same
  counts for Objects with the moved IDs; the slot deactivated, the child the
  role's Object. The `find`-miss branches (0x4074a0 for 225, 0x407b98 for 219)
  never ran in the object-input corpora: they are decoded statically, so the
  moved-ID cases test Native's model of them, not observed behaviour.
- **Review.** No correctness defect (literals restored, rules removed:
  byte-identical to HEAD; `find` still only after `free()` in the `guard`; the
  other 0xe1/0xdb literals are byte offsets, stream labels and key codes, not
  these IDs). Required: exact role docs (the burst count, its targets without
  enemies, the ally conditions, the deactivation) and the static-only note on
  the miss branches. Adopted: the comments name the roles, the slot and child
  assertions, the departure from the survey recorded.

### E5c-1j note (2026-10-20, reviewed with its change; done)

From the survey ([report](../evidence/es-e5c-rest-plumbing.md) §1, §2, §5 (order
and exclusivity), §6).
- **F4 settled.** The fusion hook covers `OriginalWorldFusion` only: A27 has no
  literal, A29 (E5c-1h) and A30 (E5c-2e) are roles, and A28 is one here (it
  tests the source ID and the hit_ja target, no fusion field). Engine code
  outside the hook still reads the fusion record: A27 reads +0x328/+0x330/+0x334,
  and the same recognizer's route 8 reads +0x328 and writes +0x338
  (`OriginalActorInput` after A28); a replacement fusion hook keeps that layout.
  In NTSD `guardedTransformer` and `roundRevertTo` are both 6 and its frame 300
  is inferred to lead to the 9995 form (`state9995Object` 50); the roles stay
  separate (F9) and nothing ties them, which a profile moving one must respect.
- **Role (Lifecycle).** `guardedTransformer` 6 (A28: `index == 8 && sourceID ==
  6 && target == 300 && HP > 177 && 0x458428 == 0` holds combo 8 back, its
  progress 3 kept; the frame 300 and the HP threshold 177 stay engine values,
  as E5c-1b's thresholds; the read order is unchanged).
- **Plumbing (F10: three public signatures).** Down the input chain as
  parameters: the world control's internal `apply(world:)` takes `rules:`
  after `frame:` (its state entry points pass the catalog's), the actor
  control's internal `apply(header:)` and public `apply(object:)` and the
  bundled library's public `apply(object:)` after `globals:`, the actor input's
  internal `apply(sourceID:)` and public `apply(object:)`, and
  `recognizeCombos`. The actor control's per-Actor `Body` does not need them.
  16 explicit test calls pass NTSD's rules. The public surface added:
  `guardedTransformer` (a `Lifecycle` field, its accessor and init parameter).
- **Test.** `recognizeCombos` with combo 8 complete and a hit_ja of 300: held
  back for 6 above 177 HP, transferred at 177 and for 7; a moved role swaps
  6 and 7.
- **Review.** No required fix (literal restored, rules removed: token-identical
  to HEAD, four lines re-wrapped; the read order kept; every caller covered;
  `rules` a guaranteed parameter, no `Body` field). Adopted: the role doc names
  its NTSD coupling to `roundRevertTo` and `state9995Object` (as inference),
  F4 records the fusion-record reads outside the hook, the note cites §5.
  `swift_beginAccess` measured before the gate: 3,278 from a clean release
  headless build.

### E5d note (2026-10-20, from the survey)

From a read-only survey ([report](../evidence/es-e5d-plumbing.md)). The AI is
one pass per slot (`OriginalCharacterAI.applyInPlace`, reached from the local
input step every host shares, not the gameplay body); `special` (0x403a40)
rolls `draw(0x3c, …)` for every ID, reads the own ID and switches into the 20
routines of `OriginalCharacterAISpecial.swift`.
- **Settled by the loop.**
  - *Carrier (revises E5c-0's "hooks travel separately, e.g. `OriginalGame`").*
    The routines' hook goes inside `OriginalGameRules`' storage, so it travels
    with the content as the roles do (2.8.3.3 picks content per session, so a
    hook in `OriginalGame` could pair with the wrong content); `==` compares
    the hook's type (stateless conformers).
  - *Parameters, not fields* (the E5c-1e lesson): the pass is built per slot;
    `applyInPlace` reads `catalog.rules` from its local copy and passes it
    down `run`.
  - *Granularity.* One role per rule; identical lists shared (A89's band
    twice, A96's set twice, the healers {2, 34} of A81 and A95, the held
    drinks {122, 123} of A87, A91 and A95). 200 is one role for A81, A84 and
    A88: the same Object (the AI's heal ball) read by one pass for one
    behaviour, going to it. The single drink IDs of A83/A85 are roles of their
    own beside the held-drinks set (a profile moving a drink moves both, as
    E5c-1j's coupling note). A86 is a table of (ID, first, last frame): the
    windows are that character's frames and mean nothing without its ID.
  - *Access.* `package` cannot cross the two packages: the primitives the
    moved routines call become `public` (or `@_spi`) in E5d-3; the pass's own
    `abs` must stay the one they resolve (`Swift.abs` traps on `Int32.min`
    where the pass's `0 &- v` wraps): E5d-3 tests it.
- **Increments.** E5d-1a: the target roles (`setup`, `items`, `idle`: A80–A86).
  E5d-1b: the fight roles (A87–A91, A93–A98). E5d-2: the hook with the
  routines still in the engine (a temporary engine conformer; the pass, `Key`
  and `Locals` public types). E5d-3: the routines to `NTSDProfile` (`git mv`),
  the temporary conformer removed, `NTSDProfile`'s cross-module settings, the
  `abs` test and a check that no unspecialised generic read is called. Gates
  as a hot pass, with `OriginalCharacterAITests` (two corpora, 7,770 calls),
  `OriginalLocalInputTests` and `OriginalMacRuntimeLoadingTests` in gate3 and
  phone and Mac A/Bs (E5d-2 and E5d-3 above all).
- **For the user:** nothing blocks E5d. An engine default with LF2's own
  routines belongs to D1/E6; the `public`-or-SPI surface can be revisited at E8.

### E5d-1a note (2026-10-20, reviewed with its change; done)

- **Family (thirteenth).** `CharacterAI`, the target choice of
  `OriginalCharacterAI` (`setup`, `items`, `idle`): `stageAllyBound` 30 (A80:
  `slot < 20 || id(s) < bound`, the short-circuit kept, an `Int32` bound as
  E5c-0 foresaw for open-ended tests), `healBall` 200 (A81's two frame groups
  and A84; A88 joins in E5d-1b), `healers` {2, 34} (A81; A95 shares it in
  E5d-1b), `stateDanger` 211 (state 18) and `frameDanger` 212 (frames 150–170
  stay engine values) (A82), `pickupItems` 100..<200 (A83's `id/100 == 1`:
  `Int32` division truncates, so it holds exactly for 100…199) and
  `pickupExtra` 213, `soughtDrink` 122 (A83 twice, A85) and `avoidedDrink` 123
  (A83), and `idleDefenders` (A86), a table of `OriginalIDFrames` (an ID and
  an inclusive frame window: 7 255–261, 9 280–290, 32 240–245). The drink
  roles are named after the AI's tests: `Items` already has the links pass's
  `hpDrink`/`mpDrink` with the same values (separate rules, F9), as it has
  `itemRange` equal to `pickupItems`.
- **Frames.** A86 is a table with its frames because it is a per-character
  list whose length belongs to the game; the frame tests on one fixed Object
  stay engine values (A81/A84's groups 50–69 of `healBall`, A82's 150–170 of
  `frameDanger`, as A28's 300). A profile that moves `healBall` or
  `frameDanger` must keep those frames in its Object.
- **Sites.** Only the comparisons change: each keeps its reads (A81's own-ID
  read inside group 5, A83's single header read per slot, A86's one ID and
  frame read before the table) and order; A86's three windows become
  `contains(where:)` over the table, pure comparisons of values read before.
- **Plumbing.** `applyInPlace` passes `catalog.rules` (its local copy) to
  `run`, which passes it to `setup`, `items` and both `idle` calls; all
  internal. Public surface added: `OriginalIDFrames`, the `CharacterAI`
  family, `characterAI:` on `OriginalGameRules.init`, its family and ten flat
  accessors. Three constructions (the profile, `engineTests` with −1/empty,
  the `with` helper).
- **Tests.** `NTSDProfileCharacterAITests` (5): the pass's `setup`, `items` and
  `idle` run directly on synthetic records, each role under NTSD's profile and
  a moved one (A80's level; A81's `near48`, A84's `seen44`; A82's steering;
  A83's target, with +0x404 = 1 too, and A85's `seen44`; A86's window edges, a
  moved window and the empty table).
- **Review.** No defect in the code (literals restored, rules removed: byte-
  identical to HEAD; `id/100 == 1` exact for 100…199; the set, the table and
  A80's short-circuit equal; no throwing read added or reordered; every
  construction and `==` covered; no other caller). Required: A83's +0x404 use
  tested; the `healBall` doc (another team, the search's target, `seen44`).
  Adopted: the `stageAllyBound` doc (`max(…, 0)`, 0x450c2c = 1), the frames
  rationale and coupling, `pickupItems` beside `itemRange`, the A86 tests.
  `swift_beginAccess` measured before the gate: 3,278.

### E5d-1b note (2026-10-20, reviewed with its change; done)

- **Roles (into `CharacterAI`).** `drinks` {122, 123} (A87: the held drink in
  `fight` when +0x404 is 1; A91: `item`'s far target; A95: `weapon`'s held
  `wid`: one identical list, F-granularity of the E5d note), `healBall` again
  (A88: `fight`'s `id(t) == 200`), `rangedBand` {4, 5, 31} (A89, `approach`
  and `tactics`) and `rangedJoiner` 36 (A90), `meleeWeapons` {100, 101, 120,
  121, 124} and `rollingWeapon` 124 (A93; tested only inside the melee
  branch, so a profile's rolling weapon must be a melee one),
  `thrownWeapons` {150, 151} (A94: `wid == 150 || wid == 151` on a local, a
  set test), `healers` again (A95's command at `weapon`'s end),
  `dashCounters` {2, 4, 6, 9, 10, 11, 8, 7, 33, 34} (A96: the `Set` built at
  every call becomes the profile's `OriginalIDSet`, its two `id(s)` reads
  kept), `shortDasher` 1 (A97, both uses), `dashJumper` 34 (A98: `dash`'s
  `jumpID` from `attackHelper`, so stream 0x3a is still drawn only on a match
  inside the counters' dash). With them every object-ID literal of the generic
  AI is in the profile; `special`'s switch (A92) and naruto2's targets (A99) wait for
  E5d-2/3.
- **Plumbing.** `run` passes the rules to `fight`, which passes them to
  `item`, `approach`, `weapon`, `tactics` and `attackHelper`; all internal.
  Public surface added: nine `CharacterAI` fields, their init parameters and
  flat accessors.
- **Tests.** `NTSDProfileCharacterAITests` (10): `fight` (A87, A88: told by
  its random streams: only the entry roll 0x14 when it returns, the special
  roll 0x3c when it goes on), `approach` (0x1a against 0x1c), `tactics` (0x21,
  0x23), `item` (the walk), `weapon` (0x2a, 0x2b, 0x2d, its result; A95's
  0x35 at the first random state that passes the 1-in-5 roll under NTSD's
  profile), `attackHelper` (0x39, 0x3a, 0x3b), each under NTSD's profile and a
  moved one. The pass builder gained a held Object, a random table and a
  background (E5d-1a's tests unchanged in outcome).
- **Review.** No code defect (literals restored, rules removed: identical to
  HEAD; each form answers every `Int32` alike and evaluates its operands once
  in the same order: A87's 0x9c chain after `+0x98 > 0`, A91's `id(t)` only
  when far, A96's two reads, A98's draw only on a match; `special`'s switch
  alone keeps literals). Required: tests that catch a kept literal at A96's
  and A97's second uses (the counters' dash carrying the jumper; the short
  dasher's dash attack at 200), and the docs (the family's line, the band's
  close-attack skip and signed 100, the throw's actual flag, "clears its
  buttons"). Adopted: the drink path's steering and the 0x35 condition, A88
  in `healBall`'s doc and A95 in `healers`', every member looped under NTSD's
  profile. A91 shares `drinks` though it tests the target, not a held
  Object: the same Objects and property. `swift_beginAccess` measured before
  the gate: 3,278.

### E5d-2 note (2026-10-20, reviewed with its change; done)

- **The hook.** `OriginalCharacterAISpecial: Sendable`, one requirement
  `special(own:_:s:t:slot:_:) throws -> Bool` on the pass in place (`inout
  OriginalCharacterAIPass`) with its `Locals`. `special` (0x403a40) keeps the
  entry roll (stream 0x3c, range 0x44f618 + 1) and the own-ID read, then calls
  `rules.characterAISpecial`; its result ends `fight` or goes on as before.
  The rules reach it as a parameter from `fight` (E5d-1b's chain).
- **Carrier.** `OriginalGameRules`' storage holds the conformer beside the
  families (an init parameter, `characterAISpecial`, apart from the
  `Equatable` families); `==` compares the conformer's type
  (`ObjectIdentifier` of its metatype), so conformers are stateless. This
  revises E5c-0's "code hooks travel separately" (the type's doc follows).
- **Routines.** Still in the engine: the switch (A92) moved verbatim into a
  temporary public conformer `OriginalCharacterAIBuiltInSpecial` (calling
  `ai.<routine>`), which NTSD's profile passes until E5d-3 moves the routines
  and the conformer into the game. `engineTests` gets an always-false
  `NoSpecialMoves` in the engine's tests (no runtime default).
- **Public surface added.** The protocol, `OriginalCharacterAIPass` and its
  `Locals` as public types (members internal: E5d-3 decides which become
  public), the temporary conformer, `characterAISpecial` (accessor and init
  parameter; the `with` test helper takes it too). `Key`, which the E5d note
  and the survey listed for this step, stays internal: the hook does not name
  it; E5d-3 makes it public with the primitives the routines call.
- **Cost.** `&self` from the mutating `special` is a statically checked
  access; `rules` is a parameter and the conformer a `let` in the storage, so
  no `swift_beginAccess` is added (measured before the gate: 3,278). Per call
  past the roll: one witness call and the existential's copy, no retain for an
  empty-struct conformer.
- **Tests.** `NTSDProfileCharacterAITests.testSpecialMoveHookE5d2`: with test
  conformers that store the own ID and end or go on: no call when the entry
  roll is above 0, the own ID passed when it is 0, `fight` ending right after
  the roll on true and going on on false, NTSD's conformer the built-in one,
  rules unequal across conformer types and equal for the same type, and a
  going-on `fight` drawing exactly as under NTSD's own conformer. The routines
  themselves stay covered by `OriginalCharacterAITests`' corpora.
- **Review.** No code defect (the switch byte-identical after stripping `ai.`;
  the roll and ID read before the call; errors and partial writes as before;
  no dynamic exclusivity; every construction and caller covered; the
  signature covers all 20 routines). Required: the note on `Key`. Adopted:
  the cost line, the protocol doc on value-type conformers, per-component
  assertions, the going-on comparison with NTSD's own, the rewrapped doc.

### E5d-3 note (2026-10-20, reviewed with its change; done)

- **Move.** `git mv engine/Sources/NTSDCore/OriginalCharacterAISpecial.swift
  native/Sources/NTSDProfile/NTSDCharacterAISpecial.swift`; the edits: `import
  NTSDCore`, the conformer renamed `NTSDCharacterAISpecial` with its doc, and
  `frameField` cut out (it reads the pass's Objects and its error: it stays in
  the engine as a public primitive, its body unchanged). NTSD's profile passes
  the game's conformer; the engine has none of the 20 routines and no
  conformer of its own (the engine's tests keep `NoSpecialMoves`).
- **Public in the engine** (`public`, not `@_spi`: the game is an ordinary
  client; E8 may revisit): `Key` and its cases; the primitives `g`, `active`,
  `index`, `i`, `facing`, `id`, `type`, `state`, `ftol`, `byte`, `press`,
  `release`, `abs`, `draw` and `frameField`; `Locals`' `nearest38`,
  `aligned34`, `ball30` and `tState` as `public internal(set)` (their
  declaration order kept). Everything else stays internal.
- **`abs`.** In the moved extension an unqualified `abs(` finds the pass's
  member first now that it is visible (`0 &- v`, wrapping); were it hidden it
  would bind to `Swift.abs`, which traps on `Int32.min`.
  `testMovedRoutinesUseThePassAbs` drives `dx`/`dz` at `Int32.min`.
- **Cross-module.** `NTSDProfile` keeps its settings (exclusivity only, the
  same `NTSD_UNCHECKED_EXCLUSIVITY` switch as the engine's). The engine's
  `-cross-module-optimization` copies only small or generic bodies into a
  client: in the clean release build the moved object
  (`NTSDCharacterAISpecial.swift.o`) inlines `abs`, `press`, `release` and
  `ftol` and calls 13 engine functions out of line: the pass's `active`,
  `byte`, `draw`, `facing`, `frameField`, `g`, `i`, `id`, `index`, `state` and
  `type`, `OriginalStateRecord.binary64(at:)` and
  `OriginalCoordinateConversion.integer(_:sse2:)` (no unspecialised generic
  `integer` read; no `swift_beginAccess` in the object). E5d-2's object, still
  inside the engine, already called nine of the pass's primitives, `object`
  and `binary64` out of line; new out-of-line calls are `active` (up to 400
  per `deidara10` call) and `frameField`. So the performance claim rests on
  the gate's frame-time A/Bs, not on inlining. `swift_beginAccess` 3,278
  before the gate. The AI's two corpora pass in debug through the moved
  routines. (A first check filtered the simplified demangling, which drops
  module names, and saw one symbol: the review corrected it.)
- **Stale builds.** The inlined `ftol` reads the pass's `actors` and `sse2`
  from inside `NTSDProfile`: an incremental build after a change to the pass
  can leave the game's copy stale (the CMO memory note). Gates and the
  access checks build in fresh directories; the reused `worktree/build`
  check directories are only for quick tests.
- **Review.** No correctness defect (the moved file differs only by the
  import, the conformer's name and doc and `frameField`'s removal; its body
  byte-identical in the engine; every unqualified call binds as before,
  `abs` to the pass's member; exactly the listed members widened; no routine
  or NTSD conformer left in the engine; the test proves the binding and
  `@testable import NTSDProfile` works in the gate's `-enable-testing`
  release test build). Required: the cross-module bullet corrected (above).
  Adopted: the stale-build note; `NTSDProfileCharacterAITests` in gate3.

### E5e note (2026-10-20, from the survey)

From a read-only survey ([report](../evidence/es-e5e-plumbing.md)).
- **No new hook.** All five coarse points become profile roles where only the
  comparison changes, with three small tables; the AI's special moves (E5d-2)
  stay the only code hook. This revises the E5 design's hook list ("fusion,
  mission pseudo-IDs, War life, weapon break, the ID-300 exemption"), as
  E5c-1b dropped the armour hook: each mechanism stays engine code and only
  its IDs move; every pass involved already holds `rules` (no public pass
  signature changes).
- **Granularity.** The ID-300 exemption is three roles (A7 in the hits, A51 in
  the commands' recovery, A60 on the mission spawn word: different passes,
  behaviours and value domains, F9). Fusion: `fusers` {7, 8}, the partner sum
  15 (exact for every value, a pair table would not be) and `fusedForm` 51
  (A25 and A26 share it); A27 and route 8 fix the record's layout, which
  stays engine. The mission pseudo-IDs: single roles (1000, 3000, 3001, the
  boss 32, the troop base 30 and the draw's range 2); the shuffle, the hero
  table's layout, 1-in-7, ×4 and the streams stay engine. War life: a table
  `[Int32: Int32]` (the 500 default and both +0x318 stores engine; a mechanical
  check that life is a function of the unit). The weapon break: A52 a table,
  A53 its own role, A54 per-branch roles with the shapes engine (a table form
  needs three action kinds; deferred to D1 or 2.8.3.3); `engineTests` must
  carry [100: 5] for `OriginalRequestSlotWordTests`.
- **Increments.** E5e-1 the three 300 roles (hot: phone A/B); E5e-2 the mission
  pseudo-IDs; E5e-3 War life; E5e-4 fusion (phone A/B); E5e-5 the weapon
  break. Each with the three constructions, synthetic tests under NTSD's
  profile and a moved one, a mapping-table review and the survey's gate3
  suites.
- **For the user:** nothing blocks E5e; D1 would show which of these are LF2
  2.0a's (inference: fusion and the 300 rule).

### E5e-1 note (2026-10-20, reviewed with its change; done)

- **Roles.** `Impact.hitConverted` 300 (A7, `OriginalHitDamage.damageHit`:
  `h(d,0x6f4) == rules.hitConverted`, the body-word read only on a match, the
  convention (> 1000, frame word − 1000, team 1, ±3) and the early return
  engine code); `Modes.killRequestSpared` 300 (A51, the commands' `recover`:
  still the last test of its chain, after 0x451160, team 5 and type 0) and
  `Modes.fixedDifficultyHP` 300 (A60, the mission `spawn`: both factors'
  tests on the spawn word before the pseudo-IDs are replaced). Three roles,
  equal NTSD values (F9).
- **Plumbing.** None: the hit pass, the commands' body and the mission stage
  pass already hold `rules`. Public surface added: three fields, their init
  parameters (`Impact.init` and `Modes.init` change) and flat accessors.
- **Tests.** `NTSDProfileExemptionTests` (3): `damageHit` on a defender whose
  frame body's first word is 1005 (the whole-function return, team 1, frame 5,
  freezes ±3, no damage); the commands with request 2 in stage mode over a
  team-5 character (HP kept or zeroed); the mission `spawn` at difficulties −1,
  0 and 2 (300 kept or 450/225); each under NTSD's profile and a moved one.
- **Review.** No code defect (literals restored: byte-identical to HEAD; the
  orders kept; no new throwing read; every construction updated; the other
  300/0x12c literals are frame numbers, timers, menus, the +0x12c offset,
  sizes or coordinates, not these IDs; `engineTests`' −1 reaches no such
  site). Required: the `hitConverted` doc (only an unguarded kind-0 hit;
  +0xb8 = 45 still written; the spark and the attacker's remaining contacts
  in this `resolve` skipped). Adopted: an injury of 20 so the moved case loses
  HP, MP asserted with HP in A51. `swift_beginAccess` before the gate: 3,278.

### E5e-2 note (2026-10-20, reviewed with its change; done)

- **Roles (into `Modes`).** `heroSpawnWord` 1000 (A61), `troopSpawnWord` 3000
  (A62), `troopOrBossSpawnWord` 3001 (A63), `spawnTroops` 30..<32 and
  `bossTroop` 32. The two troop draws become `draw(stream, upper &− lower) &+
  lower` with `spawnTroops`' bounds: `draw(0x111, 2) &+ 0x1e` and `draw(0x113,
  2) &+ 0x1e` for NTSD's (the same range in the events, the same result). The
  hero table's layout and cursor, the 50 swaps (streams 0x10f/0x110, range 10),
  the 1-in-7 (stream 0x112) and HP ×4 stay engine; the `else if` order, the
  difficulty factors before the substitution and the first-match catalog scan
  after it are kept.
- **Plumbing.** None (the mission stage pass holds `rules`). Public surface
  added: five `Modes` fields, their init parameters and flat accessors.
- **Tests.** `NTSDProfileMissionSpawnTests` (2): the pass's `spawn` with each
  word: the hero table's entry and the cursor (with and without the shuffle),
  both troop draws (stream and range in the events, a moved range widening
  the draw to 3), the boss branch from the counter whose 1-in-7 roll is 0 (HP
  1,200), each under NTSD's profile and a moved one (a moved word leaves the
  old one an ordinary word the catalog lacks); exact troop IDs.
- **Shape changed from the plan.** The E5e note and the survey named two
  roles, `troopBase` 30 and `troopChoices` 2; one `OriginalIDRange`
  `spawnTroops` holds both (the width derived with `&-`), as a troop range is
  one fact. An empty or wrapped range draws 0 without advancing the random
  state (`OriginalRandom.next`'s guard, as 0x417170) and spawns `lowerBound`:
  the doc says so; nothing traps.
- **Review.** No code defect (literals restored: identical to HEAD apart
  from the `let troops` lines; the draws' streams, ranges and results equal
  for NTSD's values; the branch order and the comparisons on the spawn word
  kept; no new throwing read or draw; the other such literals are frame
  states, offsets, sizes, sleeps and positions). Required: the shape change
  recorded, the range edge in the doc. Adopted: the doc's cursor and shuffle
  details, exact troop IDs, the boss case's next draw (0x114, no 0x113),
  positive tests for moved troop words, `let troops` inside the troop branch.
  `swift_beginAccess` before the gate: 3,278.

### E5e-3 note (2026-10-20, reviewed with its change; done)

- **Tables (into `Modes`).** `warUnitLife` [36: 250, 37: 200, 35: 200, 32:
  200, 39: 150, 33: 150, 34: 100, 31: 50, 30: 50, 122: 200] (a unit not listed:
  500, engine) and `warSideZeroMarks` [37: 0x72] (a side-0 character's +0x318:
  0x8c stored first, then the unit's mark; both stores kept, in that order).
- **Why a table is exact.** The chain tested the War-table word `unit` only
  for equality with ten constants; `at43` held only when `unit == 0x25` (set
  inside `unit == 0x25`), so `!at43 && unit == 0x24` is `unit == 0x24` and
  `at43 || unit == 0x25 || …` is `unit == 0x25 || …`; the remaining
  assignments are on disjoint values (0x22 takes the `if` branch, the
  others the `else`). Any other word keeps 500. So the life is a function of
  the unit alone, which the table gives. `NTSDProfileWarLifeTests` keeps
  HEAD's chain as the reference and compares it with the tables for every unit
  in −2048…2048, the `Int32` extremes and two aliases of 0x25 (0x10025,
  −0x25), for both side flags. Writes and their order: +0x318 (0x8c, then the
  mark) before the life; the life to +0x300, +0x2fc, +0x304 as before.
- **Plumbing.** None (the War pass holds `rules`); a dictionary lookup per
  reserve spawn (cold). Public surface: two `Modes` fields, init parameters
  and flat accessors.
- **Tests.** The equivalence above, and the pass's `spawn` for each listed
  unit, an unlisted one, both sides and a non-character, under NTSD's profile
  and moved tables.
- **Names.** The survey's `warLeftMark` became `warSideZeroMarks`; "the first
  side" is `s == 0` (team 1), as the site comment now says.
- **Review.** No code defect: equivalent for every `Int32` unit and both
  side/type cases (each unit matches at most one assignment; 0x25 gets 200
  with or without `at43`; 0x7a is reachable); the writes and their order kept;
  no read or throw moved; every construction updated; `engineTests` reaches no
  War spawn. Required: the side naming made consistent (the role doc and the
  site comment). Adopted: the tables' keys added to the compared units, the
  site comment's "disjoint" made precise, `Modes`' summary mentions War life,
  the rename recorded. `swift_beginAccess` before the gate: 3,278.

### E5e-4 note (2026-10-20, reviewed with its change; done)

- **Family (fourteenth).** `Fusion`: `fusers` {7, 8} (A24's
  `[7,8].contains(h(a))`, one read), `fusionPartnerSum` 15 (A24's partner test
  `h(d) == sum &- h(a)`: `h(d)` still read first; the sum form exact for every
  value, a reloaded 51 giving 15 − 51 = −36 as before) and `fusedForm` 51
  (A25's first-match scan with its `break`, A26's defuse test). Everything
  else in `fusion` is engine code: the HP-177 gate and 0x458428, the state,
  slot and distance conditions, the HP merge and halving, frames 290/112,
  timers 4500/900, the record (+0x328/+0x32c/+0x330/+0x334/+0x338), A26's
  no-break restore scan and its `.reconstruct`. A27 and the input's route 8
  read the same record without IDs (unchanged).
- **Plumbing.** None (the contact pass holds `rules`); `OriginalGameRules.init`
  gains `fusion:` between `lifecycle:` and `characterAI:`, with the family and
  three flat accessors; `==` compares it. Three constructions (the profile,
  `engineTests` with −1/empty, the `with` helper).
- **Tests.** `NTSDProfileFusionTests` (2): `fusion` over 20 slots (each its own
  Actor): 7+8 and 8+7 fuse into 51 (the partner deactivated, both IDs saved),
  the HP-177 gate and 0x458428 = 1 lifting it, and moved fusers, sum and form;
  a defuse of 51 back into 7 and 8 with its `.reconstruct`, none under a moved
  form, and a moved form defusing; a second 51 in the catalog pins the first
  match; `==` compares the family.
- **Review.** No code defect (literals restored: byte-identical to HEAD;
  the set answers every `Int32` alike; `h(d)` still read first, `&-` wrapping
  kept; the scan's `break` and the defuse's short-circuit kept; no new
  throwing read; every construction updated; `engineTests` never reaches the
  contact pass). Required: the construction wording; the doc (each contact
  pass, skipped at 0x44d05c = 2; the partner's frame range and x order;
  strict distances). Adopted: the defuse as the `else` of the fuse test, MP
  500/0 and the team copy, the same-ID pair a profile could make, the
  first-match and `==` tests. `swift_beginAccess` before the gate: 3,278; the
  per-slot `rules.fusers` read is the pattern the contact pass already uses
  (`reflectable`, `countsAsCharacter`): the phone A/B decides.

### E5e-5 note (2026-10-20, reviewed with its change; done)

- **Family (fifteenth).** `WeaponBreak`, the post-draw lifecycle's `weapon`:
  `fragments` [101: 7, 218: 7, 100: 5, 213: 5, 217: 5, 201: 3, 150: 13, 151: 15,
  120: 3, 124: 3, 121: 4, 122: 9, 123: 9] (A52: the dictionary built at every
  call becomes the profile's; `Int32` keys, so the lookup is the old
  `[Int(originalID)] ?? 0` for every value; counts ≥ 0 checked by a
  precondition when the profile is built), `fragmentObject` 999 (A53: `find`
  after `free()`, the kept Object and its error unchanged), `highToss` {150,
  151, 213} and `lowToss` {100, 201, 101, 120, 121, 122, 123, 124, 217, 218}
  (A54's two speed draws, streams 168 and 169), and one role per frame branch
  named by its first frame: `frames0` 150, `frames10` 100, `frames150` 213,
  `frames20` 101, `frames40` 151, `frames54` 120, `frame170` 124, `frame60` 121,
  `frames70` 122, `frames160` 123, `frame174` {217, 218}. Each of the thirteen
  per-piece tests (fourteen reads with A52's) keeps its own `source(parent)` re-read, its streams, ranges, frame bases
  and ordinal tiers; the branch shapes (three action kinds) stay engine code.
  The family is read once into `breaking` at the top of `weapon` (immutable).
- **Departure from the Next task.** It named `Effects` and the fields
  `weaponFragments`, `weaponFragmentObject`, `highTossPieces`, `lowTossPieces`;
  fifteen fields would have doubled `Effects`, so the break is its own family
  (as `Fusion`) with names that read under `weaponBreak.`.
- **Plumbing.** None (the lifecycle's body holds `rules`);
  `OriginalGameRules.init` gains `weaponBreak:` after `fusion:`; `==` compares
  it. Three constructions: the profile, `engineTests` (100's rows as NTSD's:
  [100: 5], 999, 100 in `lowToss`, `frames10` 100; the rest −1/empty, so the
  request-slot weapon test keeps its draws and outcome; the engine's 110 tests
  pass) and the `with` helper.
- **Tests.** `NTSDProfileWeaponBreakTests` (2): the lifecycle's weapon creation
  for each listed weapon (its pieces) and an unlisted one (none), moved counts,
  the piece Object missing (the error) and moved; each weapon's own streams and
  the first piece's draw order (166, 167, the toss, 170), and moved toss sets,
  frame branch and 174 set; every weapon's exact streams and ranges against a
  specification of HEAD's branches (tiers, 177→178, 190→191 pinned), each of
  the ten single frame roles moved onto 7, and `==`. The frame bases and the
  speeds themselves rest on the unchanged engine literals.
- **Review.** No behavioural defect (literals restored: identical to HEAD;
  the table equal for every `Int32`, also on wasm32; `find` after `free()`;
  each test's re-read, streams, ranges, bases and tiers kept; the hoisted
  family read pure; every construction updated; only one engine test breaks a
  weapon, needing [100: 5]). Required: thirteen tests, the departure
  recorded, exact draw sequences. Adopted: the doc's gaps, `==`, every frame
  role moved, `breaking` for the local (`rules.pieces` is Lifecycle's), the
  precondition's wording, a throwing test frame closure.
  `swift_beginAccess` before the gate: 3,278.

### E5f note (2026-10-20, from the survey)

From a read-only survey ([report](../evidence/es-e5f-plumbing.md)).
- **What moves.** The front menu's rectangles (9 sheets, 151 frames, `.text`
  immediates: no game file carries them) and six ordered name lists (front 24,
  interface 10, menu 11, War 2, common WAVs 18, menu WAVs 5) become a public
  `Interface` family of `OriginalGameRules`; the manifest checks that compare
  four of the lists with the pinned manifests stay (same check, same error).
  Arrays, not dictionaries: the write order (sheets, frames, x/y/width/height,
  the count after the frames, the null-bitmap exit) is the contract the front
  corpus (145 cases, 497,585 writes) checks.
- **Startup carries the rules.** The front menu runs before any catalog: the
  rules travel on the startup inputs (from the content identity) to the
  bootstrap's session state, a path only NTSDRuntime among the hosts touches;
  the catalog keeps its own copy (the two match by construction).
- **What stays (D1/E7).** The music tracks and labels, `MENU_BACK` and its
  count, the built-in background names, the tournament and result coordinates,
  EXE strings; the panel atlas and BATTLEMODE rectangles are optional (E5f-4).
- **Increments.** E5f-1 the rectangles and front names with the startup
  plumbing; E5f-2a interface and common sounds; E5f-2b menu and War names;
  E5f-3 the menu WAVs; E5f-4 (optional) the panel and BATTLEMODE rectangles.
  Cold paths: the mlgate set's A/Bs suffice (load time the measure to watch).

### E5f-1 note (2026-10-20, reviewed with its change; done)

- **Family (sixteenth).** `Interface`: `frontBitmaps` (the front menu's 24 names
  in load order, one per `OriginalFrontMenuResources.slots` entry) and
  `frontSheets` (`[OriginalBitmapSheet]`, the 9 sheets and 151 frames the
  front menu writes into its first eleven bitmaps, in order). The engine keeps
  the slots (the record's layout), the write order and offsets, the count after
  the frames, the null-bitmap exit, the WORDS grid and everything else.
- **The table moved.** `git mv engine/Sources/NTSDCore/OriginalFrontMenuRectangles.swift
  native/Sources/NTSDProfile/NTSDFrontMenuRectangles.swift`; the generator
  (`tools/extract_front_menu_rectangles.py`) now writes `NTSDProfile.frontSheets`
  there (header lines only; every frame line unchanged) and its `--check`
  against the pinned EXE passes (151 rectangles, 9 sheets, 613 assignments).
- **Carrier: construction, not each call.** The front menu runs before any
  catalog, so the rules travel with the objects that start the application:
  `OriginalApplicationStartupInputs.rules` (from the content identity, kept by
  `replacingFile`) → the Runtime's startup passes it to
  `OriginalApplicationObservedStartup`/`WindowStartup(…, rules:)` →
  `OriginalApplicationHostSession(platform:rules:)` →
  `OriginalApplicationBootstrap(rules:)` → `OriginalFrontMenuResources(interface:)`
  in the session state. No `start`/`load` signature changes. The ENDING screen
  takes `endingSheet(rules.interface)` from the catalog's rules (the two copies
  match by construction in the app: both come from the same content location;
  nothing compares them at run time). `load` checks the interface first, before
  any effect (one name per slot; each sheet in the first eleven slots, at most
  once, with at most 500 frames, the x array's room): a declared error where
  the old `firstIndex(of:)!` trapped or a long sheet would overrun the next
  array. For an invalid profile this error now comes before the selector check
  and before the 0x44d068 = 0 early return (which still returns `.ready` after
  its phase write for a valid one); NTSD's profile sees no change.
- **Public surface.** `OriginalBitmapSheet`, `OriginalGameRules.Interface`, its
  init parameter and accessor; `OriginalFrontMenuResources.init(interface:)`
  and `interface` (the static `paths` removed); `endingSheet(_:)`;
  `OriginalApplicationBootstrap.init(rules:)` and `rules`;
  `OriginalApplicationHostSession.init(platform:rules:)`; the two startups'
  inits; `OriginalApplicationStartupInputs.rules`. 43 test call sites gained
  NTSD's rules or interface; two reference checks read NTSD's names.
- **Tests.** `NTSDProfileInterfaceTests` (4): the profile's ENDING frames equal
  the ENDING oracle's declared frames (`original-stage-ending.json`, a copy of
  the same table: this pins the copies together; the generator's `--check`
  against the pinned EXE is the proof of the table); `endingSheet` under NTSD's
  sheet, a moved one and none; the front load's first constructed name under
  NTSD's and a renamed list; the declared error for a short list, a sheet
  outside the first eleven, a slot twice and 501 frames, with no event before
  it (also with the flag 0x44d068 = 0, where a valid profile reports only its
  phase write); `==`. A front load writing moved or reordered sheets needs the
  bitmaps constructed: the sheet writes are covered by the front corpus
  (NTSD's) and `endingSheet`'s moved case.
- **Review.** No behavioural change for NTSD (the 24 names and their order
  equal the removed `paths`; the rename touches only header lines; the loop's
  order, offsets and count unchanged; `endingSheet` identical); every
  construction updated (the only production one is the Runtime's startup; no
  host or `*Check` constructs these types); no empty-profile default; cost
  negligible. Three frozen tool files (`tools/OriginalStartupAudioTests.swift`,
  `tools/OriginalMacAudioBackendTests.swift`, `tools/generate_startup_audio_tests.py`)
  and `tools/oracle_stage_ending.py`'s docstring still name the old APIs or
  table: they are records, in no package target, and stay as they are.
  Required: the "independent capture" wording, the invalid-profile ordering
  recorded. Adopted: the check pinned before any effect, the 500-frame and
  unique-slot checks. `swift_beginAccess` before the gate: 3,278.

### E5f-2a note (2026-10-20, reviewed with its change; done)

- **Lists (into `Interface`).** `interfaceBitmaps` (the initial interface's 10
  names, one per `OriginalInitialInterfaceLoading.slots` entry) and
  `commonSounds` (the 18 WAVs loading reads before the catalog, one per
  destination from 0x451db0), in load order; the two static `paths` lists are
  gone from the engine. Each loader checks the count (a declared error before
  any effect of its own, after its existing context check; within the larger
  entry points, `OriginalInitialLoadingCommon.load`'s prologue stores and
  `OriginalInitialPoolAndInterface`'s actor pool come first, tentative and
  discarded on the throw). The catalog session's check bounds its index (the
  same `Boundary.input` error, no trap for a short list).
- **Plumbing (parameters, not stored).** `OriginalInitialInterfaceLoading` keeps
  `init()` (its empty value is a holder in `OriginalMatchPreparation`) and its
  `load`/`loadWithSurfaceLoading` take `names:`; `OriginalInitialSoundLoading.load`
  (both overloads) takes `names:`, `OriginalInitialLoadingCommon.load` and
  `OriginalInitialLoading.load` `soundNames:`, `OriginalInitialPoolAndInterface.load`
  (public overloads) `interfaceNames:`. The callers with a catalog pass its
  rules (`OriginalInitialLoadingContinuation`); the loading session passes
  `OriginalApplicationLoadingInputs.rules` (new, from the content identity);
  the catalog session's check reads `inputs.rules`. The manifest checks
  (`OriginalApplicationInterfaceInputs`, `OriginalApplicationLoadingInputs`)
  compare with the identity's lists: the same check and error.
- **Public surface.** The two `Interface` fields and init parameters;
  `OriginalApplicationLoadingInputs.rules`; the `names:`/`soundNames:`/
  `interfaceNames:` parameters above. Three reference checks and the tests
  that call the loaders pass NTSD's lists; five files that read the old static
  lists read the profile's.
- **Tests.** `NTSDProfileInterfaceTests.testInterfaceAndCommonSoundNames`: the
  counts; the interface's first source request and the sounds' first prepared
  path under NTSD's lists and renamed ones; the declared errors for a short
  list, with no effect before them; `==` for each list. Every name and its
  order is pinned by the bundled-input tests (the manifest checks) and the
  reference corpora, not by these.
- **Review.** No behavioural change for NTSD (the 10 and 18 strings equal the
  removed statics; iteration and events unchanged; each former use reads the
  matching list from NTSD's rules in the app; every inserted test argument is
  the right list); no empty-profile default (`OriginalInitialInterfaceLoading()`
  stays a holder that never loads). Required: the catalog session's bounds
  check, the note on effects in the larger entry points. Adopted: the
  no-effect and per-list `==` tests, the content identity's doc, the engine
  rules' comment, `destinationCount`. The public surface also loses the two
  statics, `Interface.init` takes four lists, and `OriginalApplicationLoadingInputs`'
  `==` compares `rules`. `swift_beginAccess` before the gate: 3,278.

### E5f-2b note (2026-10-20, reviewed with its change; done)

- **Lists (into `Interface`).** `menuBitmaps` (the character menu's 11 names,
  one per `OriginalMenuResourceLoading.slots` entry) and `warBitmaps` (the War
  menu package's two), in load order; `OriginalMenuResourceLoading.paths` and
  `OriginalApplicationMenuInputs.warPaths` are gone. The menu loader checks the
  count after its extent check (a declared error before any effect of its
  own, also on the path that loads nothing, which for an invalid profile now
  throws where it used to return `.ready`; in `OriginalCharacterMenuStartup`
  the music request and `afterMusic` run first, staged in its candidate and
  dropped on the throw). War's setup (`OriginalWarSetup`, the code that builds
  the two War bitmaps) reads `warBitmaps` from its candidate's catalog and
  checks the count before its troop initialisation; the survey had missed this
  site.
- **Plumbing (parameters, as E5f-2a).** `OriginalMenuResourceLoading.load` and
  both `loadWithSurfaceLoading`s take `names:`; `OriginalCharacterMenuStartup.run`
  and `runWithSurfaceLoading` `menuNames:`; `OriginalModeMenuContinuation.advance`
  `menuNames:` (it has no catalog). The loaded menu session and the character
  menu continuation pass their catalog's rules. `OriginalApplicationMenuInputs.load`'s
  `names:` (now `[String]?`) defaults to the identity's `menuBitmaps` (not an
  empty list: the identity the load already takes); `bundledWithWar` passes its
  `warBitmaps`. The loaded menu session holds the menu names in a `let` taken
  from its attempt's catalog when the attempt is made: reading them through
  the attempt's `model` added four `swift_beginAccess` (3,282, measured, found
  per function in `Attempt.run()` and its specialisation); with the `let` the
  count is back to 3,278.
- **Public surface.** The two `Interface` fields and init parameters (six lists
  now); the `names:`/`menuNames:` parameters above; the two statics removed.
  Three reference checks and five test calls pass NTSD's list (inserted by the
  helper script, now placing middle arguments correctly); 17 files that read
  the old static read the profile's.
- **Tests.** `NTSDProfileInterfaceTests.testMenuAndWarNames`: the counts and
  War's two names; the menu load's first source request under NTSD's list and
  a renamed one; the declared error for a short list; `==` for each list.
  `OriginalWarSetupNativeTests.testWarBitmapNamesFollowTheProfile`: the War
  setup constructs NTSD's two names, a renamed pair, and throws for one name
  before any resource event. Two War surface adapters and the outer rollback
  test read the profile's names.
- **Review.** No change for NTSD (the 11 + 2 strings and order equal the
  removed statics; the loader's events, slots and checkpoints unchanged; every
  inserted argument correct; `OriginalModeMenuContinuation.advance` and
  `OriginalCharacterMenuContinuation.advance` are called only from tests;
  production goes through the loaded session). Required: War's setup literal
  (moved to the profile, with a count check) and the note on the staged music
  effects. Adopted: the War adapters and rollback test, the doc comment order,
  `Interface`'s doc. The suggested counters for the menu loader's short list
  stay with the error test (the War test checks no resource event).

### E5f-3 note (2026-10-20, reviewed with its change; done)

- **List (into `Interface`).** `menuSounds`: the five menu WAVs WinMain's
  input startup loads, one per destination (`0x45560c+4i`), in load order;
  `OriginalMenuSoundStartup.paths` is gone and `destinationCount` (5) names
  the slot count, as `OriginalInitialSoundLoading.destinationCount` does.
- **Plumbing (parameters).** `OriginalMenuSoundStartup.load`/`loadObserved`
  take `names:` and check the count before the device requests;
  `OriginalInputStartup.load`/`loadObserved` and `OriginalWinMainStartup.run`
  take `menuSounds:` and check it first (the input startup before its key
  table and joystick requests, WinMain with its globals' extent, before any
  request or store). The bootstrap passes its rules' list (the startup
  inputs' identity, E5f-1). The Runtime's `prepared` reads its startup inputs'
  rules; its loading reads its catalog inputs' rules and checks the count
  against the startup's loads (a declared `Boundary.unexpected` where an index
  past five used to trap, and where fewer loads used to pass until the catalog
  entry's check rejected them). The catalog session's `StartupSounds(owner:platforms:)`
  takes `names:` (one per platform, checked; no empty-name fallback); its
  entry check reads its inputs' rules. One count check,
  `OriginalMenuSoundStartup.checkNames`, serves the loader and both startups.
- **Access count.** Measured first: 3,279. The extra access was in an
  unchanged closure of the menu session's step (the settings screen's, where
  one more call of `OriginalFrontScreenAlternate.advance`'s `store` was
  inlined; measured). Inferred, not measured: the session's state copies
  `OriginalFrontMenuResources`, which held the whole `Interface`, so every
  new list added a release there and moved the inliner. The front resources
  now keep only their two lists
  (`frontBitmaps`, `frontSheets`; `init(interface:)` unchanged): 3,278, the
  per-function counts equal E5f-2b's (one specialisation renamed).
- **Public surface.** `Interface.menuSounds` (seven lists now) and its init
  parameter; `names:`/`menuSounds:` above; `OriginalMenuSoundStartup.destinationCount`;
  the static removed; `OriginalFrontMenuResources.interface` replaced by
  `frontBitmaps` and `frontSheets`. Sixteen test calls gain NTSD's list (the helper script);
  four files that read the old static read the profile's.
- **Tests.** `NTSDProfileInterfaceTests.testMenuSoundNames`: the count; the
  first name the menu WAV load binds (a failed DirectSoundCreate, so the load
  goes on with device 0) under NTSD's list and a renamed one; the declared
  error for a short list with no sound request before it; the input
  startup's error before any request or store; `==`.
- **Review.** No change for NTSD (the five names byte-identical to the
  removed static; iteration, destinations and events unchanged; each count
  check before its entry point's first effect; the three routes all start
  from the content identity's rules; all 16 inserted arguments correct).
  Required: the note on the Runtime guard's short-load case. Adopted: the
  `Interface` doc, one shared count check, `Boundary.unexpected`, the checked
  names in `StartupSounds`. Not adopted: a WinMain test with a short list (its
  check is the shared one, placed after the extent guard and before the first
  write; the input startup's test covers the shared check's error). The front
  resources' two lists (the access count) were reviewed in a second pass.

### E5f-4 note (2026-10-21, reviewed with its change; done)

- **Lists (into `Interface`).** `panelFrames` (the information panel's 11
  atlas rectangles, `OriginalMenuPanelBitmap`, 43ccf2..43cf10) and
  `warModeFrames` (BATTLEMODE's 2, `OriginalWarSetup`), each frame x, y,
  width and height (`Interface.init` requires four values a frame, as
  `OriginalBitmapSheet` does). Values only: the panel keeps its write order
  (frame by frame, x/y/width/height, then the count, each write observed) with
  the count now the list's length (11 for NTSD). BATTLEMODE's writes go to an
  owned copy of the bitmap with no event or other effect between them
  (between checkpoints 0x438d2a and 0x438da5; no write can throw: the storage
  is 0x1f50 bytes, the count and fields checked) and the copy is committed
  after them, so the original's order within a frame (x, y, height, width for
  the first) is not observable; the engine writes frame by frame,
  x/y/width/height, then the count (2 for NTSD). This departs from the
  survey's plan ("the engine's write order kept"): keeping it would need an
  NTSD-specific field order in the engine. The bytes are the same.
- **Counts.** At most 500 frames (each rectangle array's room, 0x7d0 bytes):
  `OriginalMenuPanelBitmap.checkFrames`, called by the loader after its extent
  check, by `OriginalStartupPanel.run` first and by WinMain's startup with the
  menu WAVs' check; War's setup beside its names' check, before the troop
  initialisation. A declared error before any effect in each.
- **Plumbing.** `OriginalMenuPanelBitmap.load(frames:)`,
  `OriginalStartupPanel.run(panelFrames:)`; `OriginalWinMainStartup.run` now
  takes the whole `interface:` (its menu WAVs and panel frames) instead of
  E5f-3's `menuSounds:`; the bootstrap passes its rules' interface. War's setup
  reads its catalog's `warModeFrames`.
- **Access count.** 3,278 measured before the review. With the review's
  four-fields check in `checkFrames` the gate's precheck measured 3,330 (52
  more) and the gate did not start: WinMain's run was no longer inlined into
  the bootstrap (3 accesses in it and its specialisation each) and the panel's
  and menu info helpers' specialisations were duplicated (the info writer's
  `save` three times instead of once); all startup code. Isolated by clean
  builds: the pre-review trees again 3,278 (deterministic), the same trees
  with only the check 3,330. Tried and measured without effect: a loop instead
  of `allSatisfy`, and `@inline(never)` on `checkFrames` (that one together
  with WinMain taking two lists instead of the `Interface`, so not isolated).
  The check is dropped: a frame of other than four values traps at its first
  missing field, as `Interface.init`'s precondition and `OriginalBitmapSheet`
  do.
- **Public surface.** The two `Interface` fields and init parameters (nine
  lists now); `frames:`/`panelFrames:`/`interface:` above; `menuSounds:` on
  WinMain's run replaced. Nine WinMain test calls and the bootstrap pass an
  interface (the tests NTSD's), one startup panel test call and two reference
  checks NTSD's panel frames.
- **Tests.** `NTSDProfileInterfaceTests.testPanelAndWarModeFrames`: the lists;
  the panel's whole rectangle and count write sequence (45 and 49 writes)
  under NTSD's frames and a moved and longer list; the declared error for 501
  frames with no event before it;
  `==`. `OriginalWarSetupNativeTests.testBattleModeFramesFollowTheProfile`:
  NTSD's geometry (2; 0, 0, 705, 400; 0, 471, 705, 16) as the replaced
  literal wrote it, three moved frames (all three frames' offsets), the error
  before any resource event.
- **Review.** No change for NTSD (the 11 + 2 frames equal the removed
  literals with x +0x10, y +0x7e0, width +0xfb0, height +0x1780; the panel's
  write events unchanged; the BATTLEMODE departure accepted as recorded; every
  check before its entry point's first effect; every caller updated).
  Required: the WinMain call count. Adopted: the departure's record and its
  checkpoint boundaries (an unsourced address dropped), the doc comment above
  `@discardableResult`, whole write sequences and the third frame in the
  tests. Adopted and then dropped: four fields checked in `checkFrames` (the
  access count, above). Not adopted: a 501-frame `OriginalStartupPanel.run`
  test (its check is the shared one, first in `run`). The review's warning to
  re-check the access count held, though not for the `Interface` parameter.

### E4c-2 note (2026-10-21, reviewed with its change; done)

- **Survey.** A read-only agent read the 11 mixed files E4c-1 left (46
  tests): 26 synthetic tests in ten of them read no content; 17 there and
  `OriginalApplicationLoadingSessionTests`' three read the game's content
  (bundled packages, `Bundle.main`, `#filePath` into `NTSDContent`,
  `NTSDProfile`, `initial.bin`).
- **Split.** The ten files each get an engine half under the same file and
  class name (`Mac/OriginalMacMusicOutputTests` in the engine's `Mac/`): the
  26 tests and the helpers they use, copied verbatim; the native halves keep
  the 17 and their helpers (`Recorder`, `iid`, `play` stay for native's
  `OriginalMacRuntimeLoadingTests`; `release`, the read-ahead `tearDown` and
  four unused generators leave native). Each half's doc gains one E4c-2 line;
  the engine halves drop imports they no longer need (no game module), keep
  the CryptoKit guard where a moved test needs it. The two packages build
  separate bundles, so one class name in both is safe (the gates call
  `NTSDCoreTests.<Class>` and `NTSDEngineTests.<Class>`), as with
  `OriginalExclusivityChecksTests` since E4c-1.
- **Package.** `NTSDEngineTests` depends on `NTSDMusicDecoder` (the ALAC
  test); CALAC already builds on every engine platform. Eight Corelibs
  initialisers join the engine's shim (ALAC none, as in native's).
- **Counts.** `swift test list`: before 110 + 824, after 136 + 798; the union
  of class/test pairs 933 both times, none lost or new; only the exclusivity
  check in both.
- **Linux.** Both packages' tests build with the glibc SDK; the engine's 46
  suites run in `swift:6.4.0-noble` (114 passed); the one failure is
  `OriginalPosixFileFactsTests` as root, as since E4c-1, passing as uid 1000.
  Native's SHA256 halves have no Linux tests now (their remaining tests are
  CryptoKit-only); their synthetic tests run in the engine.
- **The War trio stays** (`OriginalWarSetupNativeTests`,
  `OriginalWarOuterRollbackTests`, `OriginalStageFinaleTests`): since E5b they
  read `initial.bin` through `NTSDInitialRecordData` and since E5 NTSD's
  profile (bitmap names, frames, the ENDING sheet, roster ranges); moving them
  would mean new tests on a synthetic War record with values the engine
  computes, not a move. E4c-1's call that they were synthetic predates E5b.
- **Review.** No required code change (every moved test and helper verbatim;
  every classification checked against its reads; imports, guards and the
  package change correct; the dropped `tearDown` reset a global no native
  test sets). Required and done: the Linux build and run, the records. Not
  adopted: trimming the engine halves' class docs (kept verbatim; the E4c-2
  line says which half it is).

### E7 note (2026-10-21, from the survey)

From a read-only survey ([report](../evidence/es-e7-survey.md)).
- **Stand-alone build.** Nothing in `engine/`'s build reaches outside it (one
  doc link dangles in a copy); its Linux runners and the cross-build SDK are
  the repository's and the Mac's. E7a builds and tests a `git archive` of
  `engine/` alone: macOS (default products and `NTSDEngineTests`, debug and
  release) and a native build inside `swift:6.4.0-noble` as uid 1000. The SDL,
  wasm, UIKit and Android products are compile-only rows outside E7's gate.
- **Synthetic pack.** Generated by Swift code in the engine's tests into a
  temporary folder (no binary files committed), every byte authored; record
  words zero unless a documented table names the engine check needing them.
  Proved in steps: loading (E7c), a headless start and a match of N bodies
  with frames equal on macOS and Linux (E7d). Where the pack must meet engine
  constants (file and bitmap names, `MENU_BACK%d`, `bgm\*.wma`, record words
  the engine checks) is listed in the report.
- **Scan.** A tool the loop runs, printing locations and hashes, never bytes
  (E7b). The expected hits are policy, not findings: the DAT key, DirectShow
  GUIDs, the VC80 power-of-ten table, CRT constants, EXE strings, the engine's
  names and tables, statically linked zlib 1.1.4, address constants. Which of
  them the published engine may keep is the user's call with D1 (E5's
  "until D1 sets E7's policy"); E7e acts on that policy (the power-of-ten
  table can be computed instead of copied before it).

## E6 design (2026-10-21, from E6a)

NTSD 2.4.exe is LF2 2.0a's `lf2.exe` plus a `lib.dll` loader; every NTSD
code change is one of lib.dll's twelve jumps and its two-byte patch
(LIB_RUNTIME). All 128 code entries of the profile (107 ID roles, the AI's
special-move hook and its 20 routines) are LF2 2.0a code, none lies in a
hook's bypassed range; the 10 interface entries are data. lib.dll's
behaviour lives outside the profile, in six carriers the application turns
on unconditionally. So the engine default becomes LF2 2.0a, not "no
special IDs", and NTSD is that default plus the library:

| Step | Change | Evidence |
| --- | --- | --- |
| E6a-2 | The scan policy's "EXE strings" become "keep" (every hit lies in `.rdata` before the only differing run); lib.dll's `Loading files` label and its colours move to the game | static; the scan, the loading suites |
| E6b | The ID families become the engine's LF2 2.0a rules; `NTSDProfile` composes them (a family-by-family equality test) | static; E5c's gates |
| E6c | The 20 routines move back to the engine as the default special-move conformer, named by ID | static; E5d-3's gates |
| E6d-1 | The library becomes a game value (the application's three switches); NTSD sets it | NTSD unchanged; mlgate set |
| E6d-2 | Menus and the Runtime follow it; lib.dll's data constants grouped as NTSD library data | NTSD unchanged; mlgate set, host rows |
| E6e | Optional: pristine models where only the library path exists (animated loading, network menu and front-body text, the text filters) | new pristine comparisons (either EXE below the library entry) |

The earlier pristine-EXE fixtures (run below the library-loading entry)
executed exactly `lf2.exe`'s instructions, so they are evidence for the
engine's pristine paths as LF2 2.0a code, not for LF2 2.0a's game (NTSD's
data). Claiming the default reproduces LF2 2.0a gameplay needs LF2's data
against `lf2.exe`, outside E6.

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
- 2026-10-19 E5c-2c: `rules:` plumbed into post-draw commands and the mission
  stage's pass; `itemRange` (A48), a new `scarceRequestedItem` 122 (A49),
  `spawnHP200` (A50, A64); the engine tests' own synthetic rules value. Reviewed
  (docs corrected; no code fix). Gate `es-e5c2c`: 11 scenarios, frames,
  AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the engine's
  110 tests, `swift_beginAccess` 3,276; 21 suites with 70 tests (post-draw,
  lib-stage and mission corpora included); WASI vs identical; phone main,
  render and process time apart 3 against 2 (the new build faster),
  overlapping 4 against 4; Mac overlapping. The items family is complete
  except the AI's rows (E5d). A survey of the remaining rows is recorded above.
  [Evidence](../evidence/es-e5c2c-requested-mission-roles.json).
- 2026-10-19 E5c-2d: the tests' `with(...)` helper (F11) and a sixth family,
  `Roster`: `hiddenRoster` {30–39, 50–59} (A70–A73), `randomCandidates`
  `Int32.min..<30` (A74–A77), `bracketFavourites` {50–59} (A78/A79). Gate run
  `es-e5c2d` failed its `swift_beginAccess` row (3,279 against 3,276: rules read
  through the captured `candidate`); kept as failed, extra rows stopped. Fixed
  by one static read of the rules per function; a second review found the
  remaining +2 (3,278) to be a duplicated exit block in the two tournament
  setups' `roster`, no new check on any path, and accepted it as recorded.
  Gate run `es-e5c2d2`: 11 scenarios, frames, AppKit, unchecked, emulator, 20
  clean launches, 29 suite runs, the engine's 110 tests; `swift_beginAccess`
  3,278 headless and 3,406 app (+2 each, the app's per-function diff in the same
  two functions only; **the new baseline from here on**); 23 suites with 67
  tests (the menu, tournament and War corpora); WASI vs identical; phone and Mac
  overlapping. [Evidence](../evidence/es-e5c2d-roster-roles.json).
- 2026-10-19 E5c-2e: a seventh family, `Modes`: survival 50..<60 (D2, D3,
  D14), numbered stages below 50 (D4, D6, N5), the last set 40..<50 (D7), the
  mission weights 51/52 (A30), War's troops (A65); F3 settled as option B (the
  decade arithmetic stays engine code; the design bullet annotated). Reviewed
  (every predicate checked over all 2³² values; tests added for D2–D4 and A65;
  no suite instantiates another). Gate `es-e5c2e`: 11 scenarios, frames, AppKit,
  unchecked, emulator, 20 clean launches, 29 suite runs, the engine's 110 tests,
  `swift_beginAccess` 3,278/3,406 (the baseline); 18 suites with 59 tests (first
  written 51, a miscount; the evidence has 59); WASI
  vs identical; phone overlapping; Mac process time apart 3 against 3 (the new
  build faster), overlapping 4 against 4.
  [Evidence](../evidence/es-e5c2e-modes-roles.json).
- 2026-10-19 E5c-2f: the match prelude takes the rules (both public overloads);
  `stageBackgrounds` (D8) and D9's suffix through `numberedStages`. Reviewed (no
  fix required). Gate `es-e5c2f`: 11 scenarios, frames, AppKit, unchecked,
  emulator, 20 clean launches, 29 suite runs, the engine's 110 tests,
  `swift_beginAccess` 3,278/3,406; 16 suites with 55 tests; WASI vs
  identical; phone render and process time apart 3 against 2 (the new build
  slower; the prelude runs once a match), overlapping 4 against 4; Mac
  overlapping. [Evidence](../evidence/es-e5c2f-prelude-roles.json).
- 2026-10-20 E5c-2g: the mode label's survival test (D10) through
  `survivalStages`; `rules:` on the label and the gameplay output (five public
  signatures, one package), read once from the gameplay body's and paused
  gameplay's `inout` state. Reviewed (no fix required). Gate `es-e5c2g`: 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs, the engine's 110 tests, `swift_beginAccess` 3,278/3,406; 18 suites with
  59 tests (the gameplay output, return, paused and body corpora); WASI vs
  identical; phone peak footprint apart 3 against 2, overlapping 4 against 4;
  Mac overlapping. E5c-2's menu and mode rows are done (D1, D5, D11–D13, D15
  and B1–B11 stay engine code by F3). [Evidence](../evidence/es-e5c2g-mode-label-roles.json).
- 2026-10-20 E5c-1e: an eighth family, `Physics` (A33–A38: the drifts, the
  thrown gravity's three IDs, the resting piece, the revival's picture range and
  effect; the gravities stay engine values). Reviewed (moved-profile tests for
  all three gravity roles; the rules passed as a parameter, not a per-Actor
  field). Gate `es-e5c1e` (a clean-build access precheck first: 3,278): 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs, the engine's 110 tests, `swift_beginAccess` 3,278/3,406; 18 suites with
  68 tests; WASI vs identical; phone and Mac overlapping.
  [Evidence](../evidence/es-e5c1e-physics-roles.json).
- 2026-10-20 E5c-1f: a ninth family, `Drawing`: `shadowless` {223, 224} (A45,
  F6's single header read accepted: every header closure is pure) and
  `unlabelledComputers` {30–37, 39–49} (A46, F7's finite set). Reviewed (no
  correctness defect). Gate `es-e5c1f` (access precheck 3,278): 11 scenarios,
  frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the
  engine's 110 tests, `swift_beginAccess` 3,278/3,406; 17 suites with 60 tests;
  WASI vs identical; phone and Mac overlapping.
  [Evidence](../evidence/es-e5c1f-drawing-roles.json).
- 2026-10-20 E5c-1g: a tenth family, `Effects` (the opoint's children A55–A57,
  the lifecycle's command effect and death and fire particles N2–N4; A53 left
  for E5e). Reviewed (no correctness defect; the note's entry-point wording
  fixed). Gate `es-e5c1g` (access precheck 3,278): 11 scenarios, frames,
  AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the engine's
  110 tests, `swift_beginAccess` 3,278/3,406; 19 suites with 68 tests; WASI vs
  identical; phone main time apart 3 against 2 (the new build slower),
  overlapping 4 against 4 (its median lower); Mac overlapping.
  [Evidence](../evidence/es-e5c1g-effects-roles.json).
- 2026-10-20 E5c-1h: an eleventh family, `Lifecycle` (A29, A31, N1 in the slot
  prefix, A47 in the scheduler, A32 in the round restore). Reviewed (no
  correctness defect; A47's +8 = 15 named as the invulnerability countdown, the
  role `noRiseInvulnerability`). Gate `es-e5c1h` (access precheck 3,278): 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs, the engine's 110 tests, `swift_beginAccess` 3,278/3,406; 21 suites with
  79 tests; WASI vs identical; phone and Mac overlapping.
  [Evidence](../evidence/es-e5c1h-lifecycle-roles.json).
- 2026-10-20 E5c-1i: the object input's two spawns into `Effects` (`burstChild`
  225, A58; `escortChild` 219, A59). Reviewed (no correctness defect; exact
  role docs; the miss branches noted as static only). Gate `es-e5c1i` (access
  precheck 3,278): 11 scenarios, frames, AppKit, unchecked, emulator, 20 clean
  launches, 29 suite runs, the engine's 110 tests, `swift_beginAccess`
  3,278/3,406; 18 suites with 68 tests; WASI vs identical; phone and Mac
  overlapping. [Evidence](../evidence/es-e5c1i-object-input-roles.json).
- 2026-10-20 E5c-1j: A28 into `Lifecycle` (`guardedTransformer` 6; the frame
  300 and HP 177 stay engine), the rules as parameters down the input chain
  (three public `apply(object:)` signatures). Reviewed (no required fix; the
  role's NTSD coupling and the fusion-record reads outside the hook recorded).
  `swift_beginAccess` measured first (3,278). Gate `es-e5c1j`: 11 scenarios,
  frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the
  engine's 110 tests, 3,278/3,406; 21 suites with 84 tests; WASI vs identical;
  phone and Mac overlapping. Every E5c row is in the profile.
  [Evidence](../evidence/es-e5c1j-input-roles.json).
- 2026-10-20 E5d-1a: the AI's target roles into a `CharacterAI` family (A80–A86;
  `OriginalIDFrames` for A86's windows). Reviewed (no code defect; the
  +0x404 test and the `healBall` doc fixed). `swift_beginAccess` measured first
  (3,278). Gate `es-e5d1a`: 11 scenarios, frames, AppKit, unchecked, emulator,
  20 clean launches, 29 suite runs, the engine's 110 tests, 3,278/3,406;
  20 suites with 81 tests (the AI's two corpora among them); WASI vs
  identical; Mac overlapping; phone 3v2 load time apart, the 4v4 follow-up
  overlapping everywhere. [Evidence](../evidence/es-e5d1a-ai-target-roles.json).
- 2026-10-20 E5d-1b: the AI's fight roles into `CharacterAI` (A87–A91,
  A93–A98; A96's per-call `Set` replaced by the profile's set). Reviewed (no
  code defect; tests for A96's and A97's second uses and four role docs
  fixed). `swift_beginAccess` measured first (3,278). Gate `es-e5d1b`: 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs, the engine's 110 tests, 3,278/3,406; 20 suites with 86 tests;
  WASI vs identical; phone and Mac overlapping.
  [Evidence](../evidence/es-e5d1b-ai-fight-roles.json).
- 2026-10-20 E5d-2: the AI's special moves behind `OriginalCharacterAISpecial`,
  carried in the rules (compared by type); the switch in a temporary engine
  conformer NTSD's profile passes. Reviewed (no code defect; `Key`'s deferral
  noted). `swift_beginAccess` measured first (3,278). Gate `es-e5d2`: 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs, the engine's 110 tests, 3,278/3,406; 20 suites with 87 tests (the
  AI's corpora through the hook); WASI vs identical; Mac overlapping; phone
  3v2 load apart, the 4v4 follow-up overlapping in main, render, process and
  peak, load apart the other way (noise).
  [Evidence](../evidence/es-e5d2-ai-special-hook.json).
- 2026-10-20 E5d-3: the 20 special-move routines moved into `NTSDProfile`
  (`git mv`; the game's conformer `NTSDCharacterAISpecial`); `Key`, 15 pass
  primitives and four `Locals` fields public; `frameField` stays in the
  engine. Reviewed (no correctness defect; my first symbol check was wrong
  and is corrected: 13 engine functions called out of line, 4 inlined, no
  generic read). `swift_beginAccess` measured first (3,278). Gate `es-e5d3`:
  11 scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29
  suite runs, the engine's 110 tests, 3,278/3,406; 20 suites with 88 tests
  (the AI's corpora through the game's routines); WASI vs identical; Mac
  overlapping; phone 3v2 render apart, the planned 4v4 overlapping
  everywhere. [Evidence](../evidence/es-e5d3-ai-routines-in-game.json).
- 2026-10-20 E5e-0 and E5e-1: the coarse hooks surveyed (roles and three
  tables, no new hook); the ID-300 exemption as three roles (`hitConverted`,
  `killRequestSpared`, `fixedDifficultyHP`). Reviewed (no code defect; the
  `hitConverted` doc made exact). `swift_beginAccess` measured first (3,278).
  Gate `es-e5e1`: 11 scenarios, frames, AppKit, unchecked, emulator, 20 clean
  launches, 29 suite runs, the engine's 110 tests, 3,278/3,406; 24 suites
  with 99 tests; WASI vs identical; phone and Mac overlapping.
  [Evidence](../evidence/es-e5e1-id300-roles.json).
- 2026-10-20 E5e-2: the mission pseudo-IDs into `Modes` (`heroSpawnWord`,
  `troopSpawnWord`, `troopOrBossSpawnWord`, `spawnTroops` 30..<32, `bossTroop`).
  Reviewed (no code defect; the shape change and the range edge recorded).
  `swift_beginAccess` measured first (3,278). Gate `es-e5e2`: 11 scenarios,
  frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the
  engine's 110 tests, 3,278/3,406; 21 suites with 86 tests; WASI vs
  identical; phone and Mac overlapping.
  [Evidence](../evidence/es-e5e2-mission-pseudo-ids.json).
- 2026-10-20 E5e-3: War life as two `Modes` tables (`warUnitLife`,
  `warSideZeroMarks`), equivalent to the chain for every unit (a reference
  test). Reviewed (no code defect; the side naming made consistent).
  `swift_beginAccess` measured first (3,278). Gate `es-e5e3`: 11 scenarios,
  frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the
  engine's 110 tests, 3,278/3,406; 32 names with 100 tests (two names are
  files whose tests run under classes in the list); WASI vs identical; phone
  and Mac overlapping. [Evidence](../evidence/es-e5e3-war-life.json).
- 2026-10-20 E5e-4: fusion's Objects as a `Fusion` family (`fusers`,
  `fusionPartnerSum`, `fusedForm`). Reviewed (no code defect; the doc made
  exact). `swift_beginAccess` measured first (3,278). Gate `es-e5e4`: 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs, the engine's 110 tests, 3,278/3,406; 27 suites with 100 tests
  (the contacts, round and input corpora); WASI vs identical; Mac overlapping;
  phone 3v2 load apart, the 4v4 follow-up overlapping everywhere.
  [Evidence](../evidence/es-e5e4-fusion.json).
- 2026-10-20 E5e-5: the weapon break as a `WeaponBreak` family (A52–A54;
  `engineTests` carries 100's rows). Reviewed (no behavioural defect; exact
  draw sequences tested, every frame role moved). `swift_beginAccess`
  measured first (3,278). Gate `es-e5e5`: 11 scenarios, frames, AppKit,
  unchecked, emulator, 20 clean launches, 29 suite runs, the engine's 110
  tests, 3,278/3,406; 27 suites with 104 tests (the post-draw corpora); WASI vs
  identical; Mac overlapping; phone 3v2 load apart by 0.01 s, the 4v4
  overlapping everywhere. Every object-ID rule of the E5a table is now in the
  profile; the E5f survey is recorded. [Evidence](../evidence/es-e5e5-weapon-break.json).
- 2026-10-20 E5f-1: the front menu's names and rectangle sheets into an
  `Interface` family (the table moved into the game, its generator checked
  against the pinned EXE); the rules carried by construction down the startup
  path; `endingSheet` from the catalog's rules. Reviewed (no behavioural change
  for NTSD; the oracle wording and the invalid-profile ordering fixed).
  `swift_beginAccess` measured first (3,278). Gate `es-e5f1`: 11 scenarios,
  frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the
  engine's 110 tests, 3,278/3,406; 40 suites with 136 tests (front, startup,
  ENDING and sound corpora); WASI vs identical; phone and Mac overlapping.
  [Evidence](../evidence/es-e5f1-front-interface.json).
- 2026-10-20 E5f-2a: the initial interface's 10 names and the 18 common WAVs
  into `Interface`, passed to the loaders as parameters. Reviewed (no
  behavioural change for NTSD; a bounds check added). `swift_beginAccess`
  measured first (3,278). Gate `es-e5f2a`: 11 scenarios, frames, AppKit,
  unchecked, emulator, 20 clean launches, 29 suite runs, the engine's 110
  tests, 3,278/3,406; 18 suites with 59 tests; WASI vs identical; Mac
  overlapping; phone 3v2 apart (slower), the 4v4 follow-up overlapping
  everywhere. [Evidence](../evidence/es-e5f2a-interface-sound-names.json).
- 2026-10-20 E5f-2b: the character menu's 11 bitmap names and War's 2 into
  `Interface`, passed as parameters (War's setup reads its catalog's). Reviewed
  (no behavioural change for NTSD; War's literal, which the survey had missed,
  moved too). `swift_beginAccess` measured first: 3,282 through the menu
  attempt's `model`, 3,278 with a `let`. Gate `es-e5f2b`: 11 scenarios,
  frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite runs, the
  engine's 110 tests, 3,278/3,406; 27 suites with 72 tests; WASI vs
  identical; Mac overlapping; phone 3v2 main apart (slower), the 4v4 follow-up
  overlapping everywhere. [Evidence](../evidence/es-e5f2b-menu-war-names.json).
- 2026-10-20 E5f-3: the five menu WAVs into `Interface`, passed as parameters
  through WinMain's and the input startup to the loader (one shared count
  check), the Runtime and the catalog session reading their rules. Reviewed
  twice (no behavioural change for NTSD). `swift_beginAccess` measured first:
  3,279 (one more in an unchanged menu-session closure); the front resources
  keep their two lists instead of the whole `Interface`: 3,278. Gate
  `es-e5f3`: 11 scenarios, frames, AppKit, unchecked, emulator, 20 clean
  launches, 29 suite runs, the engine's 110 tests, 3,278/3,406; 24 suites
  with 84 tests; WASI vs identical; phone overlapping; Mac complete time
  apart 3 against 3 (the new build slower), overlapping 4 against 4.
  [Evidence](../evidence/es-e5f3-menu-sound-names.json).
- 2026-10-21 E5f-4: the information panel's 11 atlas rectangles and
  BATTLEMODE's 2 into `Interface` (frame lists), the panel's through WinMain's
  startup (which now takes the `Interface`), BATTLEMODE's from War's catalog;
  BATTLEMODE's unobservable field order within a frame not kept (recorded).
  Reviewed (no behavioural change for NTSD). `swift_beginAccess` 3,278 before
  the review; the review's four-field check gave 3,330 at the gate's precheck
  (the gate did not start; isolated by clean builds) and was dropped. Gate
  `es-e5f4` (second attempt): 11 scenarios, frames, AppKit, unchecked,
  emulator, 20 clean launches, 29 suite runs, the engine's 110 tests,
  3,278/3,406; 20 suites with 69 tests; WASI vs identical; Mac
  overlapping; phone 3v2 render and process apart (slower), the 4v4 follow-up overlapping everywhere.
  [Evidence](../evidence/es-e5f4-panel-war-frames.json).
- 2026-10-21 E4c-2: ten mixed native test files split; their 26 synthetic
  tests move to the engine's tests under the same names, 17 content-reading
  ones stay; `NTSDMusicDecoder` joins the engine's test target. Counts:
  110 + 824 before, 136 + 798 after, the union of 933 class/test pairs
  unchanged. Linux: both test targets build; the engine's 46 suites run
  (114 passed; the root-only failure as since E4c-1, passing as uid 1000).
  The War trio stays with the game (reads `initial.bin` and NTSD's profile
  since E5b/E5). Reviewed (no required code change). Gate `es-e4c2`: 11
  scenarios, frames, AppKit, unchecked, emulator, 20 clean launches, 29 suite
  runs, the engine's 136 tests, 3,278/3,406; the War trio and loading session
  suites; WASI vs identical; phone overlapping; Mac (identical machine code at
  other addresses) load apart 3 against 3, the first 4v4 complete apart by 0.004 ms, a second 4v4 (order reversed) overlapping everywhere.
  [Evidence](../evidence/es-e4c2-mixed-tests.json).
- 2026-10-21 E7a: the engine alone. `tools/crossplatform/engine_standalone.sh`
  exports `engine/` (412 files, tree `b36189eb`) with `git archive` into an
  empty folder: macOS debug and a clean release build each pass the 136
  tests (the repository's list); inside `swift:6.4.0-noble` as uid 1000 a
  native build passes 115 (all but the 21 `Mac/` tests the target excludes
  there). No engine change; one finding for E8 (a README links outside
  `engine/`). The SDL, wasm, UIKit and Android rows not run (this Mac's SDKs;
  E4b built them). A first run's tree-id echo was garbled by zsh (fixed, run
  again). [Evidence](../evidence/es-e7a-standalone.json).
- 2026-10-21 E7b: `tools/scan_original_bytes.py`, a scanner the loop runs
  (locations, lengths and hash prefixes, never bytes): the literals of
  `engine/` (strings, integer runs in four widths, hex strings and their runs)
  against the pinned distribution (DATs also decrypted, the EXE and DLL by
  section), the content packages, the fixtures (inflated) and the pinned VC80
  DLL; 3,871 files, 6.4 GB, about 100 s. No unexpected hit. Expected classes:
  the DAT key (2 sites), DirectShow GUIDs (2), the VC80 power-of-ten table
  (1), EXE strings (107), the data files' vocabulary (10), vendored zlib (33);
  54 more are the project's own labels its JSON fixtures also hold. Two
  earlier runs recorded (a raw-DEFLATE fixture; the DLL missing). Limits: copies
  under 15 bytes, constants written as separate immediates, encoded fixture
  payloads. The policy for the expected classes is the user's, with D1
  (recommendations in the evidence). [Evidence](../evidence/es-e7b-scan.json).
- 2026-10-21 E7c: a synthetic content pack in the engine's tests: every byte
  authored in code (133 files, about 1 MB, written to TMPDIR and removed), a
  synthetic profile and an identity from the generated manifests; 14 tests
  load all eight packages through the engine's loaders and refuse changed
  files. macOS 150 engine tests, Linux 128, with one pinned digest of the
  pack and the catalog checksum equal on both. The scanner's new file mode
  finds in the pack only format structure (WAV headers, short audio runs,
  DAT format text, the project's JSON labels) and two examined coincidences
  (common frame lines, the all-ones mask's digest). Reviewed: the generator
  authored; the scanner tightened as required; the review's shadowsize point
  corrected (the loader reads it). No engine source change.
  [Evidence](../evidence/es-e7c-synthetic-pack.json).
- 2026-10-21 E7d: the synthetic pack beyond loading, in the engine's tests
  only: the first load through the runtime's loading and session types to the
  mode screen; startup to the title screen, also through the engine's own
  `OriginalRuntimeSession` with a test host; a scripted VS match of 100 bodies
  (a walk-up, an item drop, punches) with frame digests pinned. macOS 155
  engine tests, Linux 128 → 133; the pack's digest, the frames and the match
  equal on both hosts and time zones. Five record words, each with its engine
  check (two forced, three invented); the pack gained characters, an item
  and frames the engine's rules need. Reviewed: nothing copied, the driver
  only calls the engine; comments corrected. Three engine findings recorded
  (the virtual clock's time zone, tracing needing networking, an unlabelled
  divide by zero with no item). No engine source change.
  [Evidence](../evidence/es-e7d-synthetic-runs.json).
- 2026-10-21 E7e-1: the VC80 power-of-ten tables (42 twelve-byte entries the
  scan found copied from the pinned DLL) are computed: the top 64 bits of
  10^±p rounded to nearest, the low 16 bits rounded at 80 bits (a rule found
  over all 42 entries before the code; their digest unchanged). The native
  corpus still compares every entry with the DLL's and its 74,424 sprintf
  cases pass. Reviewed (no defect; two verbatim entries in the new test now
  derived; the study doc gained a dated statement). The scan's power-table
  class is gone. Gate `es-e7e1`: 11 scenarios, frames, AppKit, unchecked,
  emulator, 20 clean launches, 29 suite runs, the engine's tests,
  3,278/3,406; 9 suites with 28 tests; WASI vs identical;
  Mac overlapping; phone 3v2 main, process and peak apart (faster, smaller), the 4v4 follow-up overlapping everywhere. [Evidence](../evidence/es-e7e1-power-table.json).
- 2026-10-21 E7f: the synthetic match to its end, in the engine's tests only:
  a computer player on the engine's character AI (first attack at body 118),
  the knock-out at body 299, the result screen and the epilogue, the replay
  written at the end and read back by the engine's playback loader, and text
  drawn through an invented glyph source; all pinned and equal on macOS (161
  engine tests) and Linux (139), across six time zones. Two record words
  (one forced, one invented); characters 3-8 punch further and harder.
  Reviewed (accepted after comment fixes; limits and the open time-zone
  finding recorded; the four rungs in one commit, as they share one run).
  No engine source change. [Evidence](../evidence/es-e7f-synthetic-match-end.json).
- 2026-10-21 E7e-2: the user accepted E7b's recommendations and granted D1,
  D2 and E8 (Decisions). `scan_original_bytes.py --policy` enforces the
  policy: each class keep/removed/open, by the user or the loop; a removed or
  unexpected hit fails unless examined (three, with digests); the DAT key and
  GUID hits pinned by digest; the run refused without its originals or the
  VC80 DLL. Both runs pass (engine literals, every match region: 3,205 hits;
  the synthetic pack: 589,089); EXE strings stay open for E6. Reviewed: four
  required fixes made (refusals, a vocabulary bound, the frame-line rule's
  digits and sources, user/loop rules). No engine source change.
  [Evidence](../evidence/es-e7e2-scan-policy.json).
- 2026-10-21 E6a: the official LF2 2.0a installer (lf2.net's
  `LF2_v2.0a.exe` via the Internet Archive, SHA-256 `540c4855…`) unpacked
  without running it (`tools/extract_clickteam_setup.py`: 690 files, every
  stream checked; `lf2.exe` `12dfa00f…`), kept outside the repository.
  `tools/compare_pe_sections.py`: NTSD 2.4.exe is `lf2.exe` (same timestamp,
  entry, layout) except 24 `.text` bytes (the entry's call and the lib.dll
  loader in padding), the import IsDebuggerPresent swapped for LoadLibraryA
  (used otherwise only by the CRT's /GS failure report) and `.rsrc` (the same
  67 resource names). A read-only survey: all 128 code entries of the profile
  are LF2 2.0a code, the 10 interface entries data, none lib.dll's; 4176ac's
  pristine target checked. AGENTS.md records D1. No source change.
  [Reference](../evidence/es-e6a-lf2-reference.json),
  [classification](../evidence/es-e6a-classification.json).

## Next task

E6a-2 (E6 design): the policy's "EXE strings" class becomes "keep" (E6a: all
of them lie in `.rdata` before the only differing run, so they are LF2
2.0a's) with the scan rerun; lib.dll's `Loading files` label and its phase
colours (`OriginalLibLoadingProgress.swift`) move into the game as NTSD
library data, behaviour-neutrally, with the loading suites and the mlgate set.
