# Native resource inputs for the owned session

Accepted finite export, 2026-09-12. This supplies the raw input tree for
[the owned front-resource/settings session](L2DF_LOADED_SESSION.md), then its
catalog and gameplay continuation. It does not itself load a catalog or change
the running Practice app. The [full-game criteria](L2DF_FULL_GAME_GOAL.md) remain
open.

The reference is the pinned original distribution, EXE SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
`prepare_resources.py` copies original data and uses the existing static
`tools/inspect_original.py` parser to extract bitmap resources and the `.data`
prefix. No EXE/DLL execution, hooks, emulation or original capture occurs.
The exporter adds only the standard 14-byte BMP file header to each original
DIB; it does not alter pixels. These are data inputs to the native engine,
not reference after-states or compiled Windows code.

The single `resources-01` export used the task-owned X5 area after UUID/reserve
verification. Its frozen plan allows 120 seconds, 2 GiB output and preserves the
6 GiB reserve. The child returned normally in 2.034 seconds; input pinning and
subsequent audits are separate from that duration. No export was retried.

## Resource contract

Root: `build/l2df-prototype/loaded-session-20260912/resources-01/resources/`.
Its `manifest.json` contains portable relative paths and hashes:

- `original`: all 1,593 original DAT/BMP/WAV/WMA/TXT/LFR files, 822,767,627 bytes,
  beneath `original/` with the original directory structure and names.
- `embedded`: all 64 PE bitmap keys/languages, source offsets and dimensions,
  raw DIBs (31,382,294 bytes total) and BMP derivatives. Named keys are preserved;
  numbered output filenames do not become resource identities.
- `globals`: `static/globals-data.bin`, the exact 8,192 bytes at PE file offset
  `0x4d000`; global base `0x44d000`, native global span `0xb440`, and independent
  PE zero-fill extent `0x44f000..<0x459724`.

The PE `.data` section has RVA `0x4d000`, raw length `0x2000`, virtual length
`0xc724`, image base `0x400000`. The native global span starts with original file
bytes, then known PE zeros. Later saved-playback/replay-pointer BSS can use this
same provenance; unknown heap and stack storage cannot. Platform bindings are
the consuming session's typed inputs. Full CRT/static-World startup and bundled
DLL changes are separate dependencies.

The complete input tree has **1,723 files / 885,906,167 bytes**, including its
manifest. There are no symlinks, EXEs or DLLs in it. This is a development resource
package; a portable release and its runtime loading still require their own
acceptance.

## Verification and independent review

The exporter pins all 1,595 distribution files and four tool inputs before its
child starts. Its final check repeats the exact source set, hashes and absence
of symlinks. It compares every original file bytewise, all DIBs against their PE
slices, all BMP derivatives, the globals prefix and the complete output set.
Manifest schema, EXE identity and no-original-executable flag are checked too.

Read-only reviewer `l2df_reference_review` found a missing final source-set check
and requested explicit schema/identity checks. Both were corrected before the
first execution. The reviewed exporter SHA-256 is
`0441c771118dc88e5f9f8b718beaf15c0c65bddd4c55e0da210d023b0dd856f6`.
Root's separate `root-verification-01.json` rechecks complete original/DIB/data
bytes, BMP headers/pixel offsets, all input pins, the exact self-contained output
set and terminal job. No original or candidate execution was repeated.

Manifest SHA-256:
`49b323e944d0cef672eae2d7b45d36c759c73c30b060d5faa34422c0813a144a`.
[Evidence and artifact pins](../evidence/l2df-native-resources.json) retain the
job, plan, input manifest, exporter verification and independent root audit.

The completed label must not be overwritten or restarted. For a justified new
export use a new label:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 prototypes/l2df/native_bridge/prepare_resources.py --label NEW_LABEL
```

Next: the owned session consumes the original control file and 23 unique DIB
keys for 24 front bitmap wrappers, then continues settings. Each consumed input
must be verified and retained by its Swift owner. The two natural retained
settings trajectories compare actual session bytes, masks, events and rollback;
their expected snapshots remain external to the runtime. That bounded consumer
is now accepted in [the owned session](L2DF_LOADED_SESSION.md).

## Input binding for the later catalog

A separate read-only check binds this unchanged package to the raw inputs in
`original-loaded-catalog.json` and `original-initial-loading-catalog.json`.
It reads the retained compressed JSON/blobs and the exported files; no original
or Native code executes. This prepares a file/bitmap provider for the later
menu-to-catalog join and does not load or accept a new Native catalog.

Each retained context has the same 156 raw file inputs (parent registry plus
155 children), totaling 5,235,806 bytes, and 669 unique bitmap input paths.
All raw file bytes match their source blobs; bitmap presence, source hashes and
signed dimensions match. All requested images are present. These two overlapping
input sets are not 312 distinct files or 1,338 distinct game images. Repeated
bitmap constructors remain separate owners when the real catalog runs.

Lookup translates Windows path separators and resolves a unique case-insensitive
manifest name while retaining the request and original spelling. Embedded keys
resolve by key/language, independently of numbered output paths. The manifest
has no ambiguous case-insensitive file or embedded-key entries. Input hashes and
complete mappings are retained in
`resources-01/catalog-input-bindings-plan-01.json` and
`resources-01/catalog-input-bindings-01.json`; the check took 0.966 seconds.
Independent read-only review derived the requests again from both fixtures and
verified the exact report set/order against all 825 distinct resource files;
it passed. [Evidence](../evidence/l2df-catalog-inputs.json) pins the plan, mappings
and review. No native game-state, allocator, file-lifetime or progress-clock
acceptance follows.
