#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! git lfs version >/dev/null 2>&1; then
  echo 'Install Git LFS first: brew install git-lfs' >&2
  exit 1
fi
git lfs install --local
git lfs pull --include='downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/**'
