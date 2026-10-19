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
**Status:** E0–E3, E4a and E4b's headless, browser and SDL hosts done; the AppKit host next.
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
| E4 | Two packages: `engine/Package.swift` (Core, Runtime, codecs, decoders, shims, host libraries, self-contained tests) and `native/Package.swift` depending on it by path; the unsafeFlags plan (SwiftPM rejects them in version-pinned dependencies) | E4a **done** ([evidence](../evidence/es-e4a-engine-package.json)); E4b: headless **done** ([evidence](../evidence/es-e4b1-headless-host.json)), browser **done** ([evidence](../evidence/es-e4b2-web-host.json)), SDL **done** ([evidence](../evidence/es-e4b3-sdl-host.json)), AppKit next |
| E5 | Game profile: the ~90 ID sites and the AI dispatch behind a profile the game supplies; the engine defines the `0x44d000` record's layout and the game supplies `initial.bin`; the NTSD profile bit-exact (all gates plus the full fixture-driven suites); the API's fit with 2.8.3.3 checked read only | queued |
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
  prefix, `ntsd-data`, `ntsd_android_on_create` and other `ntsd_` C symbols,
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

## Next task

E4b-4: the AppKit host (`OriginalRuntimeLaunch.swift`: the runtime delegate
and `OriginalMacSessionHost`) becomes the engine library `NTSDAppKitHost`
(Mac builds), with a public `run(arguments:game:)` holding the app's runtime
branch (NSApplication, the delegate, the run) and `arguments` passed in
instead of main.swift's global; the music through the game's content in the
main bundle. The lab (`main.swift`'s lab parts, `Assets`, `OriginalScene`,
`MeleeScene`, `MovementScene`) and the dispatcher stay in the game's
`NTSDApp`. Gates: review, the mlgate set (its AppKit launches, vs and
playback) and the packaged-app row from a clean build.
