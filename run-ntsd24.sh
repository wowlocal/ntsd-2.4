#!/usr/bin/env bash
set -euo pipefail

# One-command launcher for the known-good NTSD 2.4 setup.
# Override via environment variables if needed.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CXSTART_BIN="${CXSTART_BIN:-/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxstart}"
BOTTLE="${BOTTLE:-NTSD24XP}"
GAME_DIR="${GAME_DIR:-$SCRIPT_DIR/downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a}"
EXE_PATH="${EXE_PATH:-$GAME_DIR/NTSD 2.4.exe}"

if [[ ! -x "$CXSTART_BIN" ]]; then
  echo "CrossOver cxstart not found or not executable:"
  echo "  $CXSTART_BIN"
  exit 1
fi

if [[ ! -d "$GAME_DIR" ]]; then
  echo "Game directory not found:"
  echo "  $GAME_DIR"
  exit 1
fi

if [[ ! -f "$EXE_PATH" ]]; then
  echo "Game executable not found:"
  echo "  $EXE_PATH"
  exit 1
fi

# If the game files are checked out as LFS pointers, restore binary content.
lfs_pointer_header="version https://git-lfs.github.com/spec/v1"
is_lfs_pointer() {
  LC_ALL=C head -n 1 "$1" 2>/dev/null | LC_ALL=C grep -aEq '^version https://git-lfs\.github\.com/spec/v1\r?$'
}
if is_lfs_pointer "$EXE_PATH"; then
  if ! command -v git >/dev/null 2>&1; then
    echo "Executable is a Git LFS pointer, but git is not available."
    exit 1
  fi
  if ! git lfs version >/dev/null 2>&1; then
    echo "Executable is a Git LFS pointer, but git-lfs is not installed."
    echo "Install git-lfs, then run: git lfs checkout -- \"downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a\""
    exit 1
  fi

  echo "Detected Git LFS pointer in game files. Restoring content..."
  game_rel="$GAME_DIR"
  if [[ "$game_rel" == "$SCRIPT_DIR/"* ]]; then
    game_rel="${game_rel#"$SCRIPT_DIR"/}"
  fi

  (
    cd "$SCRIPT_DIR"
    git lfs checkout -- "$game_rel" >/dev/null 2>&1 || true
    if is_lfs_pointer "$EXE_PATH"; then
      git lfs pull --include="$game_rel/**" >/dev/null
      git lfs checkout -- "$game_rel" >/dev/null
    fi
  )

  if is_lfs_pointer "$EXE_PATH"; then
    echo "Failed to restore NTSD files from Git LFS."
    echo "Try manually: git lfs pull && git lfs checkout -- \"$game_rel\""
    exit 1
  fi
fi

exec "$CXSTART_BIN" \
  --bottle "$BOTTLE" \
  --workdir "$GAME_DIR" \
  --wait "$EXE_PATH" \
  "$@"
