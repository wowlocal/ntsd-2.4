# The packaged app runs the original runtime self-contained

2026-09-29. Parent: [end-to-end check](APPLICATION_E2E.md) (21dc762). Author
implementation and machine checks; independent review open. The original was
not executed.

**Consumer and criterion:** `build/NTSD Native.app` built by
`tools/build-native.sh` plays the whole end-to-end match with `--original`
from its own `Contents/Resources`, without the build tree.
**Finding:** every Core input (startup, common sounds, loading interface,
character menu, arenas, catalog) was already installed by
`tools/package_assets.py` and read from `Contents/Resources/<Name>` when the
main bundle is an `.app`; only the music, added in the music card, was read
through SwiftPM's `Bundle.module`, whose accessor looks at the app root or an
absolute build-tree path.

## Change

- `OriginalMacMusicOutput.directory(in:)` follows the Core loaders' rule:
  `Contents/Resources/OriginalMusic` in an `.app`, else `Bundle.module`.
- `tools/package_assets.py` installs `OriginalMusic` (tracks + manifest).
- The app's `started` event reports the catalog and music directories;
  `tools/app_e2e.py --app PATH` runs another executable.

A first attempt copied both SwiftPM resource bundles into the app; it
duplicated the 634 MB catalog and was reverted before any commit.

## Checks

- `tools/build-native.sh`: app of 1.6 GB, `codesign --verify --deep --strict`
  passes.
- `tools/app_e2e.py --app "build/NTSD Native.app/Contents/MacOS/NTSDNative"`:
  `pass`; resources from the app's `Contents/Resources`.
- A clone of the app in the scratch directory with the build tree's
  `NTSDNative_NTSDCore.bundle` and `NTSDNative_NTSDMacPlatform.bundle`
  renamed away: `pass` (restored afterwards). The packaged binary is built by
  SwiftPM's default build system, the reference by `--build-system native`;
  both give the same milestones and capture hashes.
- `OriginalMacMusicOutputTests` and `OriginalMacRuntimeStartupTests`: 10/10.

## Open

Since 2026-10-01 (user decision) the app opens the original game when
launched without arguments. The Practice laboratory needs `--practice` or one
of its own options (`--movement`, `--inspect`, `--verify-data`, …), and
`--original` is still accepted. A bundle launch with `--exit-after-startup`
emits `started`; `--verify-data` still loads 137 objects.
Clean-Mac (other user, no Xcode/LFS checkout) not tested. EXE envelope not
recalculated.

**Re-check 2026-09-29:** `tools/build-native.sh` (2 min 42 s, `codesign --verify
--deep --strict` passes, 1.6 GB, Contents/Resources now also holds
OriginalWarMenu) and `tools/app_e2e.py --app "build/NTSD Native.app/Contents/MacOS/NTSDNative"`
for vs (with the quit and website checks), mission, demo, war, playback,
tournament and team-tournament: all pass, every resource path inside the app.

**Re-check 2026-09-30** (after the front-menu screens, the network menu and
the frame/header policies): `tools/build-native.sh` builds the app and
`tools/app_e2e.py --app "build/NTSD Native.app/Contents/MacOS/NTSDNative"`
passes every scenario — vs with the quit, website, controls, online and
recording checks, mission, demo, war, playback, tournament and team-tournament
— with every resource path inside the app (OriginalCatalog, OriginalMusic).

**Bundle icon (2026-09-30):** `tools/make_app_icon.py` (standard library only)
decodes the pinned EXE's only icon — group 121, one 32×32 24-bit image with its
AND mask, the icon Windows shows for the game — scales it by whole factors with
nearest-neighbour sampling into the `iconutil` sizes and writes
`Contents/Resources/AppIcon.icns`; `tools/build-native.sh` sets
`CFBundleIconFile`. The runtime's LoadIconA answer is unchanged (the EXE asks
for group 32512, which it does not contain). The packaged app builds, passes
`codesign --verify --deep --strict` and runs.

## Offline acceptance follow-up (2026-10-02)

**Status:** queued; no new build, execution or acceptance is claimed here.
**Consumer and result:** a self-contained offline app including `7d592f9`,
with reproducible inputs and validation that does not depend on deferred N2.
The [hit-word card](APPLICATION_HIT_ITEM_SLOT.md) records 38 tests and e2e on
a working tree containing uncommitted network changes; its online-menu check
uses an uncommitted `--no-network` option. The [subsequent soaks](APPLICATION_SOAKS.md)
retain that limitation. These results remain evidence for their original inputs.

1. Identify the exact source, runner, resource and binary inputs of those
   checks. Inspect saved records first. Determine which results apply to the
   offline candidate and which require a new check because inputs differ.
2. Prepare an isolated candidate with the completed offline changes and
   `7d592f9`. A HEAD-only checkout is not proof of complete inputs: verify
   required generated resources, LFS files and relevant working inputs.
   Preserve all unrelated files and deferred network WIP in the original tree;
   do not delete, revert, stash or include that WIP in the candidate's commit.
   Record the actual input manifest and the basis for each included change.
3. Reuse the existing builder, asset packager and e2e runner. Before build IO,
   verify X5 and its reserves, process pins, task limits and the candidate's
   resource layout. Then do cheap checks before costly validation. Validate
   the applicable hit-word regressions and offline app scenarios once for the
   pinned inputs. The existing failed-Winsock menu check belongs to the saved
   offline implementation; do not use N2's dirty runner or execute live
   networking, host/client probes or the refused notification integration.
4. Establish the built binary's provenance, package contents, signature check
   and resource paths from the app. Reuse valid results only for the same
   relevant inputs; preserve expected values and capture differences instead
   of re-recording references. Report app/package checks separately from Native
   comparison. This host's bundle checks do not establish clean-Mac acceptance.

**Gate:** the offline candidate, binary and package have identified inputs;
the required applicable checks pass;
deferred network work and historical results are preserved. A failure keeps
the gate open and gets a correction within this mechanism. Use existing
task/job/evidence formats; this follow-up does not add a validation framework.
No original execution or network retry is authorized by this follow-up;
the [Claude refusal](../evidence/claude-code-network-safety-2026-10-01.json) stays open.

**Next after this gate:** reconcile the currently open review and full-scope
criteria with later evidence in the existing cards/map. Classify each as
verified, implemented with a specific missing check, an implementation gap,
or externally blocked with evidence. Stale status text alone proves neither
completion nor a current gap; three clean soaks do not prove full coverage.
Begin the first permitted concrete task found. Independent review stays
distinct from author checks; unavailable review is recorded, not invented.
If no permitted work remains after this reconciliation, report the supported
blockers rather than adding more unguided soaks or preparation stages.
