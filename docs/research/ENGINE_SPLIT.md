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
**Status:** E0 (harness) next.
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
5. One commit per checked increment on `exp/engine-split`, staging only its
   files (the tested tree), evidence in `docs/evidence/es-*.json`; the hook
   pushes it.

## Plan

| ID | Step | Status |
| --- | --- | --- |
| E0 | Harness: an mlgate copy parameterized by tree, output root (T7) and scratch path, defaults unchanged; a baseline gate of 380b448d in this worktree as PREV `es-base`; phone and emulator availability | next |
| E1 | Content is its own target: the seven `Original*` directories leave `NTSDCore` for a game-side resources target, music leaves `NTSDMacPlatform`; Core loaders get the content location from the session/host instead of `Bundle.module`; tests and packaging follow the bundle | queued |
| E2 | Content policy out of Core: the digest, count and EXE-SHA pins become the NTSD content identity the game passes; Core checks what it is given with the same checks and errors (2.8.3.3's content origin as the model, read only) | queued |
| E3 | Identity and Practice: user-data folder, wasm module, Android prefix/entry, queue/thread names, titles and messages become game configuration; Practice/Lab and its two checks move to the game side | queued |
| E4 | Two packages: `engine/Package.swift` (Core, Runtime, codecs, decoders, shims, host libraries, self-contained tests) and `native/Package.swift` depending on it by path; the unsafeFlags plan (SwiftPM rejects them in version-pinned dependencies) | queued |
| E5 | Game profile: the ~90 ID sites and the AI dispatch behind a profile the game supplies; the engine defines the `0x44d000` record's layout and the game supplies `initial.bin`; the NTSD profile bit-exact (all gates plus the full fixture-driven suites); the API's fit with 2.8.3.3 checked read only | queued |
| E6 | Classify each profile rule as LF2 2.0a or NTSD from the second reference; LF2 rules become the engine's default profile | needs D1 |
| E7 | Engine stand-alone: the engine package builds alone (macOS, Linux container) and passes its tests with a from-scratch synthetic content pack; a scan finds no original bytes (files under `downloads/`, the resources, fixtures, `initial.bin`) | queued |
| E8 | Publication: name, licence, a new repository with fresh history, a tag; this repository depends on it by revision; README credits | needs D2 and the user |

## Ledger

- 2026-10-18: plan agreed; branch `exp/engine-split` and its worktree created
  from 380b448d on `/Volumes/NTSD-Builds`; all 4,985 LFS files present
  (7.2 GB). `caffeinate -dims` with a one-minute `-u` ping runs without expiry
  for the loop.

## Next task

E0. `mlgate.sh` (X5 `crossplatform/ml-tools`) hard-codes the main tree
(`cd /Users/michael/Developer/ntsd-2.4`), an old session's scratchpad for frozen
binaries, and X5 outputs. Give a copy on T7 variables for the tree, output root
and scratch (frozen binaries kept on T7, not in a scratchpad a reboot wipes),
keeping the existing references read-only and the default behaviour unchanged.
Check the A12 (`adb devices`, swipe lock per AGENTS.md) and the emulator. Then
run it once on this worktree at 380b448d as `es-base`, the PREV of E1. Done
when every gate line reports, the results match the last recorded gates on
`main`, and the evidence is in `docs/evidence/es-e0-*.json`.
