# All arenas in the app: plan

2026-09-29. Parent: [packaged app](APPLICATION_PACKAGING.md) (623845f). Rules:
[WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md). Written before
the change. **Executor/reviewer:** Claude; independent review open.

**Consumer and criterion:** every background of `data/data.txt` (ids 0..16)
and "Random" can be chosen in the app's VS start menu and its match launches
and plays; the end-to-end District check is unchanged.
**Proven blocker (APPLICATION_RUNTIME_MATCH):** a random background chose
CastleRoof and stopped at an undeclared bitmap file — `OriginalMatchArenas`
holds only District's 13 deferred layer BMPs.

## Finite changes

1. `tools/package_match_arenas.py` (build tool, data only): from the pinned
   EXE's package, every BMP of the 17 registered background folders (228
   files, 63 MB; all 24- or 8-bit uncompressed, as District's) into
   `OriginalMatchArenas` with the existing manifest format; verify mode.
   District's 13 entries keep their bytes. The BMPs go through LFS.
2. `OriginalApplicationArenaInputs.manifestSHA256` pins the new manifest.
3. No game logic changes; if a background reaches another boundary, it is
   recorded and handled in its own step.

## Checks

The existing launch suite (`OriginalApplicationLoadedLaunchTests`); an app run
per background under `--virtual-clock` (script: the computer-VS path with the
Background option advanced k times) to the first 300 bodies with a capture;
`tools/app_e2e.py` pass. EXE envelope not recalculated.
