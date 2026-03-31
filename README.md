# NTSD 2.4 (CrossOver Setup)

Known-good NTSD 2.4 setup for macOS + CrossOver with a one-command launcher.

## Quick Start

1. Install prerequisites:
   - CrossOver
   - Git LFS (`brew install git-lfs`)
2. In this repo:
   - `git lfs install`
   - `git lfs pull --include="downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/**"`
3. Launch:
   - `./run-ntsd24.sh`

Default launcher config:
- Bottle: `NTSD24XP`
- Game dir: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a`
- EXE: `NTSD 2.4.exe`

## Why LFS Matters

Game assets are stored with Git LFS. If LFS objects are not checked out, files like `NTSD 2.4.exe` become small text pointer files and Wine/CrossOver can fail with:

`winewrapper.exe:error: cannot start ... NTSD 2.4.exe (error 11)`

`run-ntsd24.sh` now detects this and tries to auto-restore required files via `git lfs checkout` and `git lfs pull`.

## Manual Recovery (if needed)

From repo root:

```bash
git lfs pull --include="downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/**"
git lfs checkout -- "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a"
./run-ntsd24.sh
```

## Detailed Troubleshooting

See [NTSD24_CROSSOVER_ERRORS_AND_SOLUTIONS.md](./NTSD24_CROSSOVER_ERRORS_AND_SOLUTIONS.md).
