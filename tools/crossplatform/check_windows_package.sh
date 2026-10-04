#!/bin/bash
# Checks the Windows package from package_windows.py in a fresh CrossOver
# bottle (ntsd-xplat-pkg, recreated each time; test harness only):
#   tools/crossplatform/check_windows_package.sh ARCHIVE OUT_DIR
# 1. a launch with no --music-dir starts, finds the packaged music and GDI
#    text and writes a frame; 2. the app_e2e vs scenario through the unpacked
#    NTSDSDL.exe (offscreen/dummy SDL drivers), compared with its reference.
set -euo pipefail
ARCHIVE=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); OUT=$2; TOOLS=$(cd "$(dirname "$0")" && pwd)
CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"; BOTTLE=ntsd-xplat-pkg
rm -rf "${OUT:?}"; mkdir -p "$OUT/run/overlay"; OUT=$(cd "$OUT" && pwd)
(cd "$OUT" && unzip -q "$ARCHIVE")
PKG="$OUT/ntsd-windows-x86_64"
"$CX/cxbottle" --bottle $BOTTLE --delete --force >/dev/null 2>&1 || true
"$CX/cxbottle" --create --bottle $BOTTLE --template win10_64 >/dev/null
win() { printf 'Z:%s' "$(printf '%s' "$1" | tr '/' '\\')"; }
SDL_VIDEO_DRIVER=offscreen SDL_AUDIO_DRIVER=dummy TZ=Etc/GMT-1 "$CX/wine" --bottle $BOTTLE --wait-children "$(win "$PKG/NTSDSDL.exe")" \
    --no-network --virtual-clock 123456789 8 --overlay "$(win "$OUT/run/overlay")" \
    --script "20 frame $(win "$OUT/run")\\menu.png; 30 exit" > "$OUT/run/events.raw" 2> "$OUT/run/stderr.txt"
tr -d '\r' < "$OUT/run/events.raw" > "$OUT/run/events.jsonl"
echo "== default launch: $(grep -o '"event":"[a-zA-Z]*"\|"font":"[^"]*"\|"musicOutput":"[^"]*"' "$OUT/run/events.jsonl" | tr '\n' ' ')"
grep -q '"event":"started"' "$OUT/run/events.jsonl" && [ -s "$OUT/run/menu.png" ] && ! grep -q sdlMusicError "$OUT/run/events.jsonl"
NTSD_WINE_BOTTLE=$BOTTLE NTSD_WINE_EXE=NTSDSDL.exe NTSD_WINE_ENV="SDL_VIDEO_DRIVER=offscreen SDL_AUDIO_DRIVER=dummy" \
    python3 "$TOOLS/run_headless_scenarios.py" "$OUT/scenarios" --wine "$PKG" vs
"$CX/wineserver" --bottle $BOTTLE -k 2>/dev/null || true
