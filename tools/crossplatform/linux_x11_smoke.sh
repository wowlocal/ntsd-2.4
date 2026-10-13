#!/bin/bash
# Inside ntsd-linux-runtime:noble: NTSDSDL on Xvfb with SDL's x11 driver,
# driven by real X input (xdotool) instead of --script, with the app_e2e VS
# script's first inputs (START, mode, character selection, start the match)
# at real-time spacing. Writes /out/events.jsonl, /out/frames, /out/window.txt.
# Mounts: /app (NTSDSDL build), /sdl (SDL3 libs), /music, /out.
set -u
export DISPLAY=:99 SDL_VIDEO_DRIVER=x11 SDL_AUDIO_DRIVER=dummy LD_LIBRARY_PATH=/sdl TZ=Etc/GMT-1
Xvfb :99 -screen 0 1280x1024x24 -nolisten tcp >/out/xvfb.log 2>&1 &
for _ in $(seq 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.1; done
mkdir -p /out/overlay /out/frames
/app/NTSDSDL --original --no-network --mute-music --mute-sounds --music-dir /music --overlay /out/overlay \
    --body-frames /out/frames --body-frame-every 100 --exit-after-bodies 400 >/out/events.jsonl 2>/out/stderr.txt &
game=$!
for _ in $(seq 100); do window=$(xdotool search --onlyvisible --pid $game 2>/dev/null | head -1); [ -n "$window" ] && break; sleep 0.1; done
[ -z "${window:-}" ] && { echo "no window"; kill $game; exit 1; }
sleep 2
xwininfo -id $window | grep -E 'Absolute|Width|Height' > /out/window.txt
xdotool windowfocus --sync $window 2>/dev/null || true
# Presses last 150 ms, like a physical click or key press: the game reads its
# input once per iteration, and xdotool's instant click/key can fall between two.
# Map game pixels into the current aspect-kept picture, as linux_sdl_scaling.py
# does. The default window is now scalable, so raw game coordinates miss START.
size() { xwininfo -id $window | awk '/Width:/{w=$2} /Height:/{h=$2} END{print w, h}'; }
at() { read W H <<< "$(size)"; awk -v cx=$1 -v cy=$2 -v W=$W -v H=$H 'BEGIN{s=W/794; if (H/550<s) s=H/550; printf "%d %d", int((W-794*s)/2+(cx+0.5)*s), int((H-550*s)/2+(cy+0.5)*s)}'; }
click() { read X Y <<< "$(at $1 $2)"; echo "click $1 $2 at $X $Y in $(size)" >> /out/clicks.txt; xdotool mousemove --window $window $X $Y; sleep 0.1; xdotool mousedown 1; sleep 0.15; xdotool mouseup 1; sleep ${3:-2}; }
key() { xdotool keydown --window $window $1; sleep 0.15; xdotool keyup --window $window $1; sleep ${2:-0.6}; }
click 350 230 1
# Loading takes seconds in real time; continue once the game reports it.
for _ in $(seq 120); do grep -q '"event":"loaded"' /out/events.jsonl && break; sleep 0.5; done
sleep 1; click 402 218 3
for k in j j d j j KP_4 Right Right Right Right Right KP_4 KP_4; do key $k; done
sleep 2
for k in d j j j s j j w w w j; do key $k 0.8; done
for _ in $(seq 240); do kill -0 $game 2>/dev/null || break; sleep 0.5; done
kill $game 2>/dev/null; wait $game 2>/dev/null; echo "game exit=$?"
