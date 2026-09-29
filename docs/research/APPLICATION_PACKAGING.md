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

Launched without arguments the app still starts the Practice engine;
`--original` selects the original runtime. Whether the shipped app should
start the original runtime by default is a product decision for the user.
Clean-Mac (other user, no Xcode/LFS checkout) not tested. EXE envelope not
recalculated.

**Re-check 2026-09-29:** `tools/build-native.sh` (2 min 42 s, `codesign --verify
--deep --strict` passes, 1.6 GB, Contents/Resources now also holds
OriginalWarMenu) and `tools/app_e2e.py --app "build/NTSD Native.app/Contents/MacOS/NTSDNative"`
for vs (with the quit and website checks), mission, demo, war, playback,
tournament and team-tournament: all pass, every resource path inside the app.
