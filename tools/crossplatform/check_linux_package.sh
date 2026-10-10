#!/bin/bash
# Checks the Linux package from package_linux.py in ntsd-linux-clean:noble
# (Ubuntu 24.04 without Swift; linux-clean/Dockerfile), a test harness only.
#   tools/crossplatform/check_linux_package.sh ARCHIVE OUT_DIR [linux/arm64|linux/amd64]
# 1. every shared library resolves (ldd); 2. a run with no --music-dir starts,
# finds the packaged music and a font, and writes a frame; 3. the X11 smoke
# (real xdotool input to a match); 4. the app_e2e vs scenario, compared with
# its frozen reference.
set -euo pipefail
ARCHIVE=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); OUT=$2; PLATFORM=${3:-linux/arm64}
# The clean image is built per platform: ntsd-linux-clean:noble (arm64) and
# ntsd-linux-clean:noble-amd64 (docker build --platform linux/amd64).
IMAGE=ntsd-linux-clean:noble; [ "$PLATFORM" = linux/amd64 ] && IMAGE=ntsd-linux-clean:noble-amd64
TOOLS=$(cd "$(dirname "$0")" && pwd)
rm -rf "${OUT:?}"; mkdir -p "$OUT/pkg" "$OUT/run"; OUT=$(cd "$OUT" && pwd)
tar -xzf "$ARCHIVE" -C "$OUT/pkg"
PKG=$(ls -d "$OUT"/pkg/ntsd-linux-*)
docker run --rm --platform "$PLATFORM" -v "$PKG:/app:ro" -v "$OUT/run:/out" "$IMAGE" bash -c '
  set -u
  echo "== ldd"; ldd /app/NTSDSDL | tee /out/ldd.txt | grep -c "not found" || true
  ! grep -q "not found" /out/ldd.txt || { echo "missing libraries"; exit 1; }
  echo "== default launch"
  mkdir -p /out/overlay
  SDL_VIDEO_DRIVER=offscreen SDL_AUDIO_DRIVER=dummy TZ=Etc/GMT-1 /app/NTSDSDL --virtual-clock 123456789 8 \
      --overlay /out/overlay --script "20 frame /out/menu.png; 30 exit" > /out/events.jsonl 2> /out/stderr.txt
  echo "exit=$?"; grep -o "\"event\":\"[a-zA-Z]*\"\|\"font\":\"[^\"]*\"\|\"musicOutput\":\"[^\"]*\"" /out/events.jsonl | sort | uniq -c
  ! grep -q sdlMusicError /out/events.jsonl'
mkdir -p "$OUT/x11"
docker run --rm --platform "$PLATFORM" -v "$PKG:/app:ro" -v "$PKG:/sdl:ro" -v "$PKG/OriginalMusic:/music:ro" -v "$OUT/x11:/out" \
    -v "$TOOLS/linux_x11_smoke.sh:/smoke.sh:ro" "$IMAGE" /smoke.sh
echo "== x11: $(grep -o '"event":"[a-zA-Z]*"' "$OUT/x11/events.jsonl" | tr '\n' ' ')"
grep -q '"event":"gameplay"' "$OUT/x11/events.jsonl"
NTSD_LINUX_PLATFORM="$PLATFORM" NTSD_LINUX_IMAGE="$IMAGE" NTSD_SDL_LIB="$PKG" python3 "$TOOLS/run_headless_scenarios.py" "$OUT/scenarios" --linux-sdl "$PKG" vs
