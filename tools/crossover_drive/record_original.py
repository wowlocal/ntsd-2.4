#!/usr/bin/env python3
"""Original -> Mac: the original under CrossOver records a VS match of P1
(Random, idle) and N Random computers; the Mac app plays the recording, and
both Summaries are compared from memory.

usage: record_original.py OUT_DIR [--computers N] [--shots] [--mode vs|stage]
                          [--stage-steps N] [--watch SECONDS]

The original's menus take held keys posted to its pid (play_original.keys);
each step waits on the selection phase 4512c8 (1 = computer count after the
countdown, 2 = computer fighters, 3 = final menu)
read with winedbg instead of on fixed delays. The original seeds its random
table from the real time, so every run is a new match. Writes OUT_DIR/
original.json, the recording, mac.json and the comparison. CROSSPLAY_LOOP.md.
"""
import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import compare_summaries  # noqa: E402
import cua  # noqa: E402
import play_original as po  # noqa: E402
import summary_original  # noqa: E402

APP = ROOT / "build/swiftpm-app/release/NTSDNative"
J, D, W, S = 38, 2, 13, 1
PLAYBACK = "20 click 350 230; 60 click 402 218; " + "".join(f"{100 + 25 * i} key 83; " for i in range(6)) + "250 key 74; 900000 exit"


def wait_word(pid, address, values, seconds, what):
    for _ in range(seconds):
        if po.word(pid, address) in values: return
        time.sleep(1)
    raise SystemExit(f"{what} not reached ({address:#x} = {po.word(pid, address)})")


def record(out, computers, shots, mode="vs", stage_steps=0, watch=0, summary=True):
    def shot(name):
        if shots:
            pid, wid = cua.window()
            cua.call("get_window_state", dict(pid=pid, window_id=wid, include_accessibility_tree=False, max_image_dimension=800,
                                              screenshot_out_file=str(out / f"{name}.png"), session=po.os.environ["CUA_SESSION"]))
    held = po.lock(); clone = po.DEFAULT_CLONE; folder = clone / "recording"
    before = {p.name for p in folder.iterdir()}
    launcher, pid = po.start(clone)
    try:
        po.keys(pid, [J] if mode == "vs" else [S, J]); time.sleep(3); shot("1-selection")  # VS, Mission Mode below it
        for _ in range(3): po.keys(pid, [J]); time.sleep(1.5)             # P1 joins, Random, team
        shot("2-p1")
        wait_word(pid, 0x4512C8, {1}, 60, "computer count"); time.sleep(1)
        # VS starts the count at one computer, Mission Mode at none.
        po.keys(pid, [D] * (computers - (1 if mode == "vs" else 0)) + [J]); time.sleep(2); shot("3-count")
        # Each computer takes J for its fighter (Random) and J for its team;
        # press until the final menu, since a press during an animation is
        # lost. A late extra J only rerolls the Random fighters there.
        for _ in range(4 * computers + 4):
            if po.word(pid, 0x4512C8) == 3: break
            po.keys(pid, [J]); time.sleep(2)
        wait_word(pid, 0x4512C8, {3}, 10, "final menu"); time.sleep(1); shot("4-final")
        if stage_steps:
            # Down to the Stage/Background line (3); each J steps it (Stage:
            # +10, 50 = Survival).
            for _ in range(4):
                if po.word(pid, 0x44D06C) == 3: break
                po.keys(pid, [S]); time.sleep(1)
            wait_word(pid, 0x44D06C, {3}, 5, "line 3")
            for _ in range(stage_steps): po.keys(pid, [J]); time.sleep(1)
            shot("4-stage")
        for _ in range(8):                                                # the marker 44d06c up to Fight!
            if po.word(pid, 0x44D06C) == 0: break
            po.keys(pid, [W]); time.sleep(1)
        wait_word(pid, 0x44D06C, {0}, 5, "Fight!")
        po.keys(pid, [J])
        # A live match starts its music, and even the no-music clone then shows
        # CrossOver's "Could not create a filter graph" box, which blocks the
        # main thread until OK. Ticks are counted per frame, so the pause does
        # not change the match.
        for _ in range(20):
            time.sleep(1)
            if po.dismiss_error(): break
            if (po.word(pid, 0x450BBC) or 0) > 0: break
        shot("5-fight")
        po.wait_clock(pid)
        for i in range(watch // 10):                                       # frames to look at
            time.sleep(10); po.dismiss_error(); shot(f"6-watch-{i:02d}")
        if not summary: return None
        summary_original.main(str(out / "original.json"), timeout=1800)
        time.sleep(3)                                                     # the file is written at the Summary
    finally:
        po.stop(clone, launcher); held.close()
    new = sorted((p for p in folder.iterdir() if p.name not in before and p.suffix == ".lfr"), key=lambda p: p.stat().st_mtime)
    if not new: raise SystemExit("the original saved no recording")
    shutil.copy(new[-1], out / new[-1].name); new[-1].unlink()
    return out / new[-1].name


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument("out")
    p.add_argument("--computers", type=int, default=3); p.add_argument("--shots", action="store_true")
    p.add_argument("--mode", choices=["vs", "stage"], default="vs")
    p.add_argument("--stage-steps", type=int, default=0, help="J presses on the Stage line (50 = Survival after 5)")
    p.add_argument("--watch", type=int, default=0, help="seconds of frames (every 10 s) after the start; needs --shots")
    p.add_argument("--watch-only", action="store_true", help="stop after the frames: no Summary, recording or Mac run")
    a = p.parse_args(); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    recording = next(iter(sorted(out.glob("*.lfr"))), None) if (out / "original.json").exists() else None
    recording = recording or record(out, a.computers, a.shots, a.mode, a.stage_steps, a.watch, not a.watch_only)
    if recording is None: return 0
    mac = out / "mac.json"
    if not mac.exists():
        overlay = out / "overlay"; overlay.mkdir(exist_ok=True)
        done = subprocess.run([str(APP), "--original", "--mute-music", "--mute-sounds", "--no-activate", "--overlay", str(overlay),
                               "--virtual-clock", "123456789", "8", "--script-clock", "gameplay", "--playback-file", str(recording),
                               "--exit-after-summary", "--summary-json", str(mac), "--summary-capture", str(out / "mac-summary.png"),
                               "--script", PLAYBACK], capture_output=True, text=True, timeout=7200,
                              env={"TZ": "Etc/GMT-1", "PATH": "/usr/bin:/bin"})
        (out / "mac.stdout").write_text(done.stdout + done.stderr)
        if not mac.exists(): raise SystemExit("no Mac summary")
    status = compare_summaries.main(str(out / "original.json"), str(mac))
    (out / "result.json").write_text(json.dumps(dict(recording=recording.name, equal=status == 0), indent=1))
    return status


if __name__ == "__main__":
    sys.exit(main())
