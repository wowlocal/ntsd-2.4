#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "${1:-}" == '--build' ]]; then
  exec bash tools/build-native.sh
fi
if [[ ! -x 'build/NTSD Native.app/Contents/MacOS/NTSDNative' ]]; then
  bash tools/build-native.sh
fi
exec 'build/NTSD Native.app/Contents/MacOS/NTSDNative' "$@"
