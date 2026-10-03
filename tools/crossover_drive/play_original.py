#!/usr/bin/env python3
"""Play one recording in the original under CrossOver and read its Summary from memory.

usage: play_original.py RECORDING.lfr OUT.json [CLONE_DIR]

Uses the no-music diagnostic clone by default (its EXE has .data 44d010 = 0,
so no "filter graph" box blocks the main thread; gameplay is unaffected).
The recording is copied into the clone's recording folder as `1`. START
is set in memory with winedbg; the mode menu (S x6, J) and the Open dialog
(the digit typed, Return) take held keys posted to the game's pid only. The
Summary is read with summary_original.py. Needs an unlocked screen for keys.
"""
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cua  # noqa: E402
import summary_original  # noqa: E402
import wd  # noqa: E402

DEFAULT_CLONE = Path("/Volumes/X5/ntsd-2.4-research/goal-100-20261002/checksum-bisect/nomusic/NTSD 2.4_2.0a")
LAUNCHER = "/Users/michael/Developer/ntsd-2.4/run-ntsd24.sh"
KEYHOLD = HERE / "keyhold"
VK = {**{c: v for c, v in zip("asdfhgzxcv", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])}, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
      "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
      "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, ".": 47, "\n": 36}


def word(pid, address):
    out = wd.cmd(pid, f"x /x 0x{address:x}")
    import re
    values = re.findall(r"^\s*([0-9a-f]{8})\s*$", out, re.M)
    return summary_original.signed(int(values[-1], 16)) if values else None


def keys(pid, codes, hold=150, gap=300, title="Little Fighter 2"):
    windows = [w for w in cua.call("list_windows", {})["windows"]
               if w["app_name"] == "NTSD 2.4.exe" and w["is_on_screen"] and w["title"] == title]
    if windows:
        cua.call("bring_to_front", dict(pid=windows[0]["pid"], window_id=windows[0]["window_id"], session=os.environ["CUA_SESSION"]))
        time.sleep(0.4)
        mac_pid = windows[0]["pid"]
    else:
        raise SystemExit("no original window")
    subprocess.run([str(KEYHOLD), str(mac_pid), "pid", str(hold), str(gap), *map(str, codes)], check=True, capture_output=True)


def titles():
    return [w["title"] for w in cua.call("list_windows", {})["windows"] if w["app_name"] == "NTSD 2.4.exe" and w["is_on_screen"]]


LOCK = Path("/Volumes/X5/ntsd-2.4-research/goal-100-20261002/crossplay-loop/original.lock")


def main(recording, out, clone=DEFAULT_CLONE):
    # One original at a time: a second instance of the same clone confuses the
    # pid lookup and the window filter.
    import fcntl
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    lock = open(LOCK, "w"); fcntl.flock(lock, fcntl.LOCK_EX)
    os.environ.setdefault("CUA_SESSION", "play-" + time.strftime("%H%M%S"))
    if not KEYHOLD.exists():
        subprocess.run(["/usr/bin/swiftc", "-O", str(HERE / "keyhold.swift"), "-o", str(KEYHOLD)], check=True)
    clone = Path(clone); folder = clone / "recording"
    # Digits only and no extension: Wine types the dialog's text through the
    # current macOS keyboard layout, and digits are the same in every layout.
    for old in (folder / "1", folder / "1.lfr"):
        if old.exists(): old.unlink()
    name = "1"; shutil.copy(recording, folder / name)
    env = dict(os.environ, CX_BOTTLE_PATH=wd.BOTTLES, BOTTLE="NTSD24XP", GAME_DIR=str(clone), EXE_PATH=str(clone / "NTSD 2.4.exe"))
    launcher = subprocess.Popen([LAUNCHER], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        pid = None
        for _ in range(60):
            time.sleep(2); pid = pid or wd.wpid()
            if pid and word(pid, 0x44D020) == 10 and "Little Fighter 2" in titles(): break
        else: raise SystemExit("main menu not reached")
        time.sleep(2)
        wd.wine("winedbg", "--file", "Z:" + str(HERE / "start.wdbg"), "0x" + pid)
        for _ in range(60):
            time.sleep(2)
            if word(pid, 0x44F620) == 0x1EC3356: break
        else: raise SystemExit("catalog not loaded")
        time.sleep(3)
        keys(pid, [1] * 6 + [38])                       # mode menu: S x6 to Playback Recording, J
        for _ in range(20):
            time.sleep(1)
            if "Open" in titles(): break
        else: raise SystemExit("Open dialog not shown")
        time.sleep(1.5)
        keys(pid, [VK[c] for c in name + "\n"], hold=60, gap=120, title="Open")
        for _ in range(15):
            time.sleep(1)
            t = titles()
            if "Error" in t: raise SystemExit("recording rejected by the original")
            if "Open" not in t: break
        # The match clock 450bbc must run; otherwise the playback never started.
        for _ in range(30):
            time.sleep(2)
            if (word(pid, 0x450BBC) or 0) > 30: break
        else: raise SystemExit("playback did not start")
        summary_original.main(out, timeout=900)
    finally:
        for line in subprocess.run(["ps", "-axo", "pid,command"], capture_output=True, text=True).stdout.splitlines():
            if str(clone).replace("/", "\\") in line or str(clone) in line:
                subprocess.run(["kill", line.split()[0]])
        launcher.wait(timeout=30)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], *(sys.argv[3:4]))
