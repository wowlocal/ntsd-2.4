#!/bin/sh
# Runs inside swift:6.4.0-noble. /repo and /build are bind mounts; recreate the
# macOS absolute paths that #filePath and Bundle.module compiled in.
set -e
mkdir -p "$(dirname "$NTSD_REPO")" "$(dirname "$NTSD_BUILD")"
ln -sfn /repo "$NTSD_REPO"
ln -sfn /build "$NTSD_BUILD"
exec "$NTSD_BUILD/NTSDCoreTests-test-runner" "$@"
