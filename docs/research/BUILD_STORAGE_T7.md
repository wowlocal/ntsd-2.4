# NTSD build storage on T7

Completed 2026-10-17. The user's priority is freeing the internal drive.
Existing X5 artifacts may remain there; no further bulk X5 migration is needed.
The full-port goal remains paused while this separate storage/VM task is handled.

## Result

- 28 internal build/cache/output roots relocated: 88,390,090,064 logical bytes.
- 77 total units relocated, including already completed X5 moves:
  299,777,916,228 logical bytes. Existing canonical paths remain valid symlinks.
- At the final audit Macintosh HD had 101,771,808,768 bytes free (94.8 GiB),
  X5 had 146,742,661,120 bytes free, and T7 had 1,050,012,549,120 bytes free.
  Logical bytes moved differ from physical space reclaimed because of APFS sharing.
- Sources, reference inputs, Git history and 462 tracked evidence metadata files
  remain in place. No game logic or expected results were changed.

Both migration producers stopped after finishing their current units when the
user clarified the scope. Tool sessions 13376/28339 returned exit 143 after
intentional termination; the boundary watcher 96537 and monitor 5341 returned 0.
All 77 canonical links and manifest hashes verify; no partials or original
backups remain. The internal scan found no remaining `.o`, `.pcm`, `.swiftmodule`,
`build.db`, APK, WASM or NTSDNative outputs outside the relocated links.
The unused portions of the historical queues are inventories, not pending work.

## Future builds

New NTSD build outputs/caches belong on T7. POSIX-dependent active trees use
`/Volumes/NTSD-Builds`, APFS UUID `E36E5CAF-8FC7-4521-A7F3-679CFF71D663`,
backed by `/Volumes/T7/ntsd-build-storage/NTSD-Builds.sparsebundle`.
This task-owned container has a 1152 GiB virtual maximum and grows with actual
stored data; that maximum is not preallocated. No physical disk was formatted.
The underlying writable ExFAT T7 UUID must be
`7C9569C1-BC8F-3288-B3FD-8831A3F07FAA`, with at least 40 GiB free.
The container preserves the modes, links and nanosecond mtimes needed by builds.

If it is not mounted, verify T7 and mount the container before building:

```sh
hdiutil attach -nobrowse -owners on -mountpoint /Volumes/NTSD-Builds /Volumes/T7/ntsd-build-storage/NTSD-Builds.sparsebundle
```

Keep the existing canonical-path symlinks. Do not replace missing-volume links
with local fallback directories. Common default paths in this worktree, including
`native/.build`, app/headless/SDL caches and generated app/resource folders, have
separate T7 targets. New task-specific scratch paths must also use T7. Existing
X5 artifacts and working trees need no relocation merely to satisfy this policy.

## Verification and audit

Each migrated unit was checked for live open handles, copied with `ditto`, and
verified for complete membership, SHA-256 file bytes, modes, symbolic-link targets
and nanosecond mtimes. Source metadata was rechecked before replacing its path
with a symlink; only then was the verified original removed. Ditto preserves
file hard links and copies extended attributes/ACLs. No game/capture producer was
stopped or restarted.

The copied main app's `codesign --verify --deep --strict` emitted no errors,
its Info.plist passed lint, and Swift's `--show-bin-path` still resolves the
original `native/.build/out/Products/Release` path through T7. These checks did
not rebuild or launch the game and do not establish new gameplay acceptance.

Audit directory: `/Volumes/T7/ntsd-build-storage/`.

- `internal-migration-final1.json`: final totals, free space and checked links.
- `tree-*.json`, `tree-*-manifest.json`, `completed.jsonl`: per-unit provenance
  and full byte/metadata verification before publication/removal.
- `future-default-paths1.json`, `git-local-exclude-change.json`: default routing
  and local Git exclude changes for generated symlinks.
- `user-scope-stop1.json`: PID/start/cwd validation and exact stop boundaries.
- `canonical-app-path-check1.json`, `internal-residual-compiled-markers1.txt`:
  app/cache path checks and the empty internal residual scan.
- Original inventories/queues and producer versions remain preserved. An eight-row
  overlapping inventory correction, its terminal checkpoint and a syntax-only
  preflight failure/correction are recorded in `queue-overlap-*` and
  `resume-preflight-correction1.json`. Preserved partial copies were reused.
- `capacity-stop1.json`, `capacity-expansion1.json` and operation logs: safe
  offline expansion of only this sparsebundle from 1024 to 1152 GiB; UUID unchanged.
  `current-jobs4.json` is historical identity evidence, not a live-job instruction.

## VM disk limit

Windows VM 1 (`BC1E05CE-1482-4C28-A4E3-FE5718DAA147`) had reached its separate
40 GB VMPal quota. Only `diskLimitGB` was changed, to 80 GB, and its existing
paused session was resumed. VMPal then reported `running`, `problem: null`, no
pending settings and 42.9 GB used. Screenshot fallback after an empty text read
showed the original game at character selection without the disk-limit dialog.
No VM/game reset or restart was used. See `vm-disk-limit-fixed1.json`.

The main worktree's only intentional source edit is the storage policy in
AGENTS.md; it remains uncommitted there. The experiment worktree records this
checked increment locally. No push, publication, PR or merge was performed.
