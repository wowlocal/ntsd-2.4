#!/usr/bin/env python3
"""The Linux SDL build's scalable window (WINDOW_SCALING S4) in
ntsd-linux-runtime:noble (test harness).

Usage: linux_sdl_scaling.py OUT_DIR BUILD_DIR   (SDL3 libs from $NTSD_SDL_LIB)

x11: Xvfb 1920x1080 without a window manager, SDL's x11 driver, real time,
no script (so the window is scalable by default). xdotool clicks START at the
window's first size and, after `xdotool windowsize` to 1001x600 (a different
aspect: the picture is letterboxed), the VS mode, each at the window point of
the client pixel the app_e2e VS script clicks, mapped through the
aspect-kept picture; then the VS script's first keys start a match. Reaching
gameplay body 400 means every click landed on its client pixel.
`--original-window` repeats the first part with the fixed window.

wayland: headless Weston 1280x1024, SDL's wayland driver, a short script with
--scalable-window: frames before, in and after the script's `fullscreen`
(SDL desktop full screen, which Weston applies), with the window sizes SDL
reports.

Writes OUT_DIR/summary.json and the runs' events, frames and window sizes.
"""
import json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"

X11 = r"""
set -u
export DISPLAY=:99 SDL_VIDEO_DRIVER=x11 SDL_AUDIO_DRIVER=dummy LD_LIBRARY_PATH=/sdl TZ=Etc/GMT-1
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp >/out/xvfb.log 2>&1 &
for _ in $(seq 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.1; done
size() { xwininfo -id $window | awk '/Width:/{w=$2} /Height:/{h=$2} END{print w, h}'; }
# The window point of client pixel (cx, cy): its centre in the aspect-kept picture.
at() { read W H <<< "$(size)"; awk -v cx=$1 -v cy=$2 -v W=$W -v H=$H 'BEGIN{s=W/794; if (H/550<s) s=H/550; printf "%d %d", int((W-794*s)/2+(cx+0.5)*s), int((H-550*s)/2+(cy+0.5)*s)}'; }
click() { read X Y <<< "$(at $1 $2)"; echo "click $1 $2 at $X $Y in $(size)" >> $OUT/clicks.txt
          xdotool mousemove --window $window $X $Y; sleep 0.1; xdotool mousedown 1; sleep 0.15; xdotool mouseup 1; sleep ${3:-2}; }
key() { xdotool keydown --window $window $1; sleep 0.15; xdotool keyup --window $window $1; sleep ${2:-0.6}; }
run() {   # run NAME [game args...]
  OUT=/out/$1; shift; mkdir -p $OUT/overlay $OUT/frames
  /app/NTSDSDL --original --no-network --mute-music --mute-sounds --music-dir /music --overlay $OUT/overlay \
      --body-frames $OUT/frames --body-frame-every 100 --exit-after-bodies 400 "$@" >$OUT/events.jsonl 2>$OUT/stderr.txt &
  game=$!
  for _ in $(seq 100); do window=$(xdotool search --onlyvisible --pid $game 2>/dev/null | head -1); [ -n "$window" ] && break; sleep 0.1; done
  [ -z "${window:-}" ] && { echo "no window" > $OUT/result.txt; kill $game; return; }
  sleep 2; echo "first $(size)" > $OUT/window.txt
  xdotool windowfocus --sync $window 2>/dev/null || true
  click 350 230 1
  for _ in $(seq 120); do grep -q '"event":"loaded"' $OUT/events.jsonl && break; sleep 0.5; done
  if [ "$RESIZE" = 1 ]; then xdotool windowsize --sync $window 1001 600 2>/dev/null || xdotool windowsize $window 1001 600; sleep 1.5; echo "resized $(size)" >> $OUT/window.txt; fi
  sleep 1; click 402 218 3
  for k in j j d j j KP_4 Right Right Right Right Right KP_4 KP_4; do key $k; done
  sleep 2
  for k in d j j j s j j w w w j; do key $k 0.8; done
  for _ in $(seq 240); do kill -0 $game 2>/dev/null || break; sleep 0.5; done
  kill $game 2>/dev/null; wait $game 2>/dev/null; echo "exit=$?" > $OUT/result.txt
}
RESIZE=1 run x11
RESIZE=0 run x11-original --original-window
"""

WAYLAND = r"""
set -u
export TZ=Etc/GMT-1 XDG_RUNTIME_DIR=/tmp/xdg WAYLAND_DISPLAY=wayland-ntsd SDL_VIDEO_DRIVER=wayland SDL_AUDIO_DRIVER=dummy LD_LIBRARY_PATH=/sdl
mkdir -p /tmp/xdg && chmod 700 /tmp/xdg
(weston --backend=headless --socket=wayland-ntsd --width=1280 --height=1024 >/out/weston.log 2>&1 &)
for i in $(seq 100); do [ -S /tmp/xdg/wayland-ntsd ] && break; sleep 0.1; done
OUT=/out/wayland; mkdir -p $OUT/overlay
/app/NTSDSDL --original --no-network --mute-music --mute-sounds --music-dir /music --overlay $OUT/overlay --scalable-window \
  --script-clock all --script "300 frame $OUT/1-window.png; 310 fullscreen; 600 frame $OUT/2-full.png; 610 fullscreen; 900 frame $OUT/3-back.png; 910 exit" \
  >$OUT/events.jsonl 2>$OUT/stderr.txt
echo "exit=$?" > $OUT/result.txt
"""


def docker(out, build, script):
    return subprocess.run(["docker", "run", "--rm", "-v", f"{build}:/app:ro", "-v", f"{os.environ['NTSD_SDL_LIB']}:/sdl:ro",
                           "-v", f"{MUSIC}:/music:ro", "-v", f"{out}:/out", "ntsd-linux-runtime:noble", "bash", "-c", script],
                          capture_output=True, text=True, timeout=3600)


def events(path):
    rows = []
    for line in path.read_text().splitlines():
        try: rows.append(json.loads(line))
        except ValueError: pass
    return rows


def main():
    out, build = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    shutil.rmtree(out, ignore_errors=True); out.mkdir(parents=True)
    summary = {}
    for name, script in (("x11", X11), ("wayland", WAYLAND)):
        done = docker(out, build, script)
        summary[name + "Docker"] = done.returncode
    for run in ("x11", "x11-original"):
        d = out / run
        ev = events(d / "events.jsonl") if (d / "events.jsonl").exists() else []
        bodies = max([e.get("gameplayBodies", 0) for e in ev if isinstance(e.get("gameplayBodies"), int)] or [0])
        summary[run] = {"window": (d / "window.txt").read_text().split("\n")[:-1] if (d / "window.txt").exists() else None,
                        "clicks": (d / "clicks.txt").read_text().split("\n")[:-1] if (d / "clicks.txt").exists() else None,
                        "loaded": any(e.get("event") == "loaded" for e in ev), "maxGameplayBodies": bodies,
                        "boundary": [e for e in ev if "boundary" in json.dumps(e).lower()][:2],
                        "frames": len(list((d / "frames").glob("*.png"))) if (d / "frames").exists() else 0,
                        "result": (d / "result.txt").read_text().strip() if (d / "result.txt").exists() else None}
    w = out / "wayland"
    ev = events(w / "events.jsonl") if (w / "events.jsonl").exists() else []
    summary["wayland"] = {"drivers": [e for e in ev if e.get("event") == "sdlDrivers"],
                          "fullScreen": [e for e in ev if e.get("event") == "sdlFullScreen"],
                          "frames": sorted(p.name for p in w.glob("*.png")),
                          "result": (w / "result.txt").read_text().strip() if (w / "result.txt").exists() else None}
    (out / "summary.json").write_text(json.dumps(summary, indent=1) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
