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

exec "$CXSTART_BIN" \
  --bottle "$BOTTLE" \
  --workdir "$GAME_DIR" \
  --wait "$EXE_PATH" \
  "$@"

