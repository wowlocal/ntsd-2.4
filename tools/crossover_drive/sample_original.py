#!/usr/bin/env python3
"""Sampled state of the original playing a recording, for bisecting a
difference that appears late in a long match.

usage: sample_original.py RECORDING OUT.json FIRST STEP [LAST]

Plays RECORDING as play_original.py does, then attaches winedbg with a
breakpoint at 421cdc whose condition is the match clock 450bbc == T, for
T = FIRST, FIRST+STEP, ... (LAST at most): at each stop the random index
450bcc and counter 450c34, the phase counters 450bd0..450bd8, the War totals
451b64..451b70 and the active seat count are read. The process runs at full
speed between samples (winedbg evaluates the condition). The Mac app's
`--network-trace` row with the same `clock` + 1 carries the same fields.
"""
import json
import os
import re
import shutil
import sys
import time
from pathlib import Path

import pexpect

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import play_original as po  # noqa: E402
import trace_ticks  # noqa: E402
import wd  # noqa: E402


def sample(pid, ticks):
    env = dict(os.environ, CX_BOTTLE_PATH=wd.BOTTLES)
    child = pexpect.spawn(wd.WINE, ["--bottle", "NTSD24XP", "--no-gui", "--", "winedbg", "0x" + pid],
                          env=env, encoding="latin-1", timeout=120)
    def run(command, timeout=120):
        child.send(command + "\r"); child.expect(trace_ticks.PROMPT, timeout=timeout)
        return trace_ticks.ANSI.sub("", child.before).replace("\r", "")
    def words(address, n):
        text = run(f"x /{n}x 0x{address:x}"); out = []
        for line in text.splitlines()[1:]:
            line = re.sub(r"^\s*0x[0-9a-f]+(\s+\S+)?:", " ", line.strip())
            out += [int(w, 16) for w in re.findall(r"(?<![0-9a-fx])([0-9a-f]{8})(?![0-9a-f])", line)]
        return [trace_ticks.signed(w) for w in out[:n]]
    child.expect(trace_ticks.PROMPT)
    run("break *0x421cdc")
    rows = []
    try:
        for tick in ticks:
            run(f"cond 1 *(int*)0x450bbc == {tick}")
            run("cont", timeout=3600)
            clock, = words(0x450BBC, 1)
            index, counter = words(0x450BCC, 1)[0], words(0x450C34, 1)[0]
            phases = words(0x450BD0, 3); war = words(0x451B64, 4); timer, = words(0x450BDC, 1)
            flags = b"".join((w & 0xFFFFFFFF).to_bytes(4, "little") for w in words(trace_ticks.WORLD + 4, 100))
            rows.append(dict(tick=clock, rngIndex=index, rngCounter=counter, phase12=phases[0], phase3=phases[1], phase2=phases[2],
                             war=war, roundTimer=timer, active=sum(1 for b in flags if b)))
            print(json.dumps(rows[-1]), flush=True)
            if timer: break
    finally:
        try:
            run("delete 1"); child.send("detach\r"); time.sleep(1)
        finally:
            child.close()
    return rows


def main(recording, out, first, step, last=1_000_000):
    held = po.lock(); clone = po.DEFAULT_CLONE; folder = clone / "recording"
    for old in (folder / "1", folder / "1.lfr"):
        if old.exists(): old.unlink()
    shutil.copy(recording, folder / "1")
    launcher, pid = po.start(clone)
    try:
        po.keys(pid, [1] * 6 + [38])
        for _ in range(20):
            time.sleep(1)
            if "Open" in po.titles(): break
        else: raise SystemExit("Open dialog not shown")
        time.sleep(1.5)
        po.keys(pid, [po.VK[c] for c in "1\n"], hold=60, gap=120, title="Open")
        for _ in range(15):
            time.sleep(1)
            if "Open" not in po.titles(): break
        po.wait_clock(pid)
        start = max(first, (po.word(pid, 0x450BBC) or 0) + 60)
        rows = sample(pid, range(start, last + 1, step))
    finally:
        po.stop(clone, launcher); held.close()
    Path(out).write_text(json.dumps(rows, indent=0))


if __name__ == "__main__":
    a = sys.argv
    main(a[1], a[2], int(a[3]), int(a[4]), *(int(x) for x in a[5:6]))
