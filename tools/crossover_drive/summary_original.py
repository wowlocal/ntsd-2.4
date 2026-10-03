#!/usr/bin/env python3
"""Read the Summary's source fields from the running original under CrossOver.

Waits until the Summary timer 450bdc is in 144..349 (the app's own
--exit-after-summary test), then reads in one winedbg session the fields that
OriginalResultLayout draws: per active seat the object id (+368 -> +6f4), Kill
+358, Attack +348, HP Lost +34c, MP Usage +350, Picking +35c, team +364 and HP
+2fc; time 450bbc, winner 450bf8, mode 451160 and the War totals 451b64..451b70.
The output has the shape of the app's `--summary-json`.

usage: summary_original.py OUT.json [TIMEOUT_SECONDS]
"""
import json
import os
import re
import sys
import time

import pexpect

import wd

WORLD = 0x458B00
PROMPT = r"Wine-dbg>"
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07")


def signed(v):
    return v - (1 << 32) if v & 0x80000000 else v


def read_words(run, address, count):
    """`x /Nx` prints lines of hex words, optionally after an address prefix."""
    text = run(f"x /{count}x 0x{address:x}")
    words = []
    for line in text.splitlines()[1:]:
        line = re.sub(r"^\s*0x[0-9a-f]+(\s+\S+)?:", " ", line.strip())
        words += [int(w, 16) for w in re.findall(r"(?<![0-9a-fx])([0-9a-f]{8})(?![0-9a-f])", line)]
    if len(words) < count:
        raise RuntimeError(f"short read at {address:#x}: {text!r}")
    return words[:count]


def summary_timer(pid):
    out = wd.cmd(pid, "x /x 0x450bdc")
    values = re.findall(r"^\s*([0-9a-f]{8})\s*$", out, re.M)
    return signed(int(values[-1], 16)) if values else None


def main(out, timeout=600):
    pid = wd.wpid()
    if not pid:
        raise SystemExit("no NTSD 2.4.exe process in the bottle")
    deadline = time.time() + timeout
    while True:
        timer = summary_timer(pid)
        if timer is not None and 144 <= timer < 350:
            break
        if time.time() > deadline:
            raise SystemExit(f"Summary not reached (450bdc = {timer})")
        time.sleep(2)
    env = dict(os.environ, CX_BOTTLE_PATH=wd.BOTTLES)
    child = pexpect.spawn(wd.WINE, ["--bottle", "NTSD24XP", "--no-gui", "--", "winedbg", "0x" + pid],
                          env=env, encoding="latin-1", timeout=120)
    def run(command):
        child.send(command + "\r"); child.expect(PROMPT)
        return ANSI.sub("", child.before).replace("\r", "")
    child.expect(PROMPT)
    try:
        flags = b"".join(w.to_bytes(4, "little") for w in read_words(run, WORLD + 4, 5))
        table = read_words(run, WORLD + 0x194, 20)
        seats = []
        for seat in range(20):
            if not flags[seat]:
                continue
            actor = table[seat]
            block = read_words(run, actor + 0x2FC, 0x1C)  # +2fc..+36b
            field = lambda offset: signed(block[(offset - 0x2FC) // 4])
            obj = block[(0x368 - 0x2FC) // 4]
            seats.append(dict(seat=seat, id=signed(read_words(run, obj + 0x6F4, 1)[0]), kill=field(0x358), attack=field(0x348),
                              hpLost=field(0x34C), mp=field(0x350), picking=field(0x35C), team=field(0x364), hp=field(0x2FC)))
        g = lambda address: signed(read_words(run, address, 1)[0])
        values = dict(seats=seats, ticks=g(0x450BBC), winner=g(0x450BF8), mode=g(0x451160),
                      war=[signed(w) for w in read_words(run, 0x451B64, 4)], summaryTimer=g(0x450BDC))
    finally:
        child.send("detach\r"); child.close()
    json.dump(values, open(out, "w"), indent=1, sort_keys=True)
    print(json.dumps(values, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 600)
