#!/usr/bin/env python3
"""Frames of the original's Demo at chosen ticks, for a side-by-side with the
Mac app's `--body-captures DIR --body-capture-every N` of the same Demo.

usage: demo_frames.py OUT_DIR BASE MAC_TRACE FIRST STEP LAST

The Demo starts as in demo_crossplay.py: the random table is the Mac's for
`--virtual-clock BASE 8`, the 450bd0 phase is the Mac's at the first tick
(MAC_TRACE, the app's --network-trace), the music ERROR box is clicked away
and J released. A breakpoint at 421cdc with the condition 450bbc == T stops
the game at each tick T = FIRST, FIRST+STEP, ... LAST; while it stands the
window is captured (OUT_DIR/oTTTTTT.png) and the random index and counter are
read and compared with the Mac's row for the same tick (frames.json).
"""
import json
import os
import re
import sys
import time
from pathlib import Path

import pexpect

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cua  # noqa: E402
import demo_crossplay as dc  # noqa: E402
import play_original as po  # noqa: E402
import trace_ticks  # noqa: E402
import wd  # noqa: E402


def mac_rows(trace):
    rows = {}
    for line in open(trace):
        r = json.loads(line)
        if r.get("kind") == "state" and r.get("completion") == "gameplay": rows.setdefault(r["clock"], r)
    return rows


def capture(path):
    pid, wid = cua.window()
    cua.call("get_window_state", dict(pid=pid, window_id=wid, include_accessibility_tree=False, max_image_dimension=0,
                                      screenshot_out_file=str(path), session=os.environ["CUA_SESSION"]))


def main(out, base, trace, first, step, last):
    out = Path(out); out.mkdir(parents=True, exist_ok=True); rows = mac_rows(trace)
    table = dc.crt_table(base)
    commands = [f"set *(int*)0x{0x44FF90 + i:x} = 0x{int.from_bytes(table[i:i + 4], 'little'):x}" for i in range(0, 3000, 4)]
    poke = out / "table.wdbg"; poke.write_text("\n".join(commands + ["detach"]) + "\n")
    phase = dc.mac_phase(trace)
    held = po.lock(); clone = po.DEFAULT_CLONE
    launcher, pid = po.start(clone)
    frames = []
    try:
        wd.wine("winedbg", "--file", "Z:" + str(poke), "0x" + pid, timeout=300)
        env = dict(os.environ, CX_BOTTLE_PATH=wd.BOTTLES)
        child = pexpect.spawn(wd.WINE, ["--bottle", "NTSD24XP", "--no-gui", "--", "winedbg", "0x" + pid],
                              env=env, encoding="latin-1", timeout=120)
        def run(command, timeout=120):
            child.send(command + "\r"); child.expect(trace_ticks.PROMPT, timeout=timeout)
            return trace_ticks.ANSI.sub("", child.before).replace("\r", "")
        def word(address):
            return trace_ticks.signed(int(re.findall(r"([0-9a-f]{8})\s*$", run(f"x /x 0x{address:x}").strip())[-1], 16))
        def resume():
            child.send("cont\r")
            while True:
                try: child.expect(trace_ticks.PROMPT, timeout=5); return
                except pexpect.TIMEOUT: dc.opened(pid)
        child.expect(trace_ticks.PROMPT)
        run("break *0x421cdc")
        child.send("cont\r"); po.keys(pid, [1] * 5 + [38])
        while True:
            try: child.expect(trace_ticks.PROMPT, timeout=5); break
            except pexpect.TIMEOUT: dc.opened(pid)
        run(f"set *(int*)0x450bd0 = {phase}")
        try:
            for tick in range(first, last + 1, step):
                run(f"cond 1 *(int*)0x450bbc == {tick}")
                resume()
                index, counter = word(0x450BCC), word(0x450C34)
                path = out / f"o{tick:06d}.png"; capture(path)
                mac = rows.get(tick + 1, {})
                frames.append(dict(tick=tick, rngIndex=index, rngCounter=counter, macIndex=mac.get("rngIndex"),
                                   macCounter=mac.get("rngCounter"), equal=(index, counter) == (mac.get("rngIndex"), mac.get("rngCounter"))))
                print(json.dumps(frames[-1]), flush=True)
                (out / "frames.json").write_text(json.dumps(frames, indent=0))
        finally:
            run("delete 1"); child.send("detach\r"); time.sleep(1); child.close()
    finally:
        po.stop(clone, launcher); held.close()


if __name__ == "__main__":
    a = sys.argv
    main(a[1], int(a[2]), a[3], int(a[4]), int(a[5]), int(a[6]))
