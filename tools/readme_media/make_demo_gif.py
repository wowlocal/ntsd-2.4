#!/usr/bin/env python3
"""Side-by-side GIF of the same Demo in the Mac app and in the original.

usage: make_demo_gif.py MAC_DIR ORIG_DIR FIRST STEP LAST OUT.gif|OUT.mp4|OUT.png [PANE_WIDTH]

MAC_DIR holds the app's `--body-captures` frames (bNNNNNN.png, window only),
ORIG_DIR the original's demo_frames.py frames (oNNNNNN.png, with the 28-point
title bar CrossOver's window adds, cropped here). Frame T of both shows the
same tick (tools/crossover_drive/demo_frames.py checks the random index at
each). Each pane gets a caption bar (label.swift); the GIF runs at 30/STEP
frames per second, the game's own speed. A .mp4 keeps full colour; a .png is
the first frame only. The README's GIF: 603 3 837, width 420.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main(mac, orig, first, step, last, out, width=560):
    mac, orig, out = Path(mac), Path(orig), Path(out)
    work = Path(tempfile.mkdtemp())
    label = work / "label"
    subprocess.run(["/usr/bin/swiftc", "-O", str(HERE / "label.swift"), "-o", str(label)], check=True)
    caption = 36
    subprocess.run([str(label), str(width), str(caption), str(work / "mac.png"), "Native Swift", "macOS app"], check=True)
    subprocess.run([str(label), str(width), str(caption), str(work / "orig.png"), "Original NTSD 2.4.exe", "Windows, under CrossOver"], check=True)
    (work / "m").mkdir(); (work / "o").mkdir()
    for n, tick in enumerate(range(first, last + 1, step)):
        shutil.copy(mac / f"b{tick:06d}.png", work / "m" / f"{n:05d}.png")
        shutil.copy(orig / f"o{tick:06d}.png", work / "o" / f"{n:05d}.png")
    fps = 30 / step
    graph = (f"[0:v]scale={width}:-2:flags=lanczos[m];"
             f"[1:v]crop=1588:1100:0:56,scale={width}:-2:flags=lanczos[o];"
             f"[2:v][m]vstack=shortest=1[mm];[3:v][o]vstack=shortest=1[oo];"
             f"[mm]pad=iw+8:ih:0:0:color=0x14171e[mp];[mp][oo]hstack")
    if out.suffix == ".gif":
        # The camera follows the fight, so nearly every pixel changes between
        # frames; an undithered 112-colour palette keeps 8 s near 10 MB.
        graph += ",split[a][b];[a]palettegen=max_colors=112:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle"
        codec = ["-loop", "0"]
    elif out.suffix == ".mp4": codec = ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart"]
    else: codec = ["-frames:v", "1"]
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-framerate", str(fps), "-i", str(work / "m" / "%05d.png"),
                    "-framerate", str(fps), "-i", str(work / "o" / "%05d.png"),
                    "-loop", "1", "-framerate", str(fps), "-i", str(work / "mac.png"),
                    "-loop", "1", "-framerate", str(fps), "-i", str(work / "orig.png"),
                    "-filter_complex", graph, *codec, str(out)], check=True)
    shutil.rmtree(work)
    print(out, out.stat().st_size // 1024, "KiB")


if __name__ == "__main__":
    a = sys.argv
    main(a[1], a[2], int(a[3]), int(a[4]), int(a[5]), a[6], *(int(x) for x in a[7:8]))
