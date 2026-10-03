#!/usr/bin/env python3
"""Per-tick state of the running original under CrossOver, for locating the
first tick where it and the Mac app part.

A breakpoint at 421cdc (the tick tail's result recording, entered once per
gameplay tick after the simulation) reads the match clock 450bbc, the game
random index 450bcc and counter 450c34, the phase counters 450bd0 (mod 12),
450bd4 (mod 3) and 450bd8 (mod 2), and for every active seat its frame
(Actor +70), HP (+2fc), x (+10), y (+14) and z (+18). The Mac app's
`--network-trace` writes the same fields per loaded cycle. trace(pid, count,
started) attaches, continues once, calls `started()` (to send the keys that
begin the match while the process runs), `first_hit(run)` at the first stop
(to set state with winedbg commands) and returns the first `count` hits.
"""
import os
import re
import time

import pexpect

import wd

PROMPT = r"Wine-dbg>"
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07")
WORLD = 0x458B00
FIELDS = (("frame", 0x70), ("hp", 0x2FC), ("x", 0x10), ("y", 0x14), ("z", 0x18))


def signed(v):
    return v - (1 << 32) if v & 0x80000000 else v


def trace(pid, count, started=lambda: None, on_wait=lambda: None, first_hit=lambda run: None):
    env = dict(os.environ, CX_BOTTLE_PATH=wd.BOTTLES)
    child = pexpect.spawn(wd.WINE, ["--bottle", "NTSD24XP", "--no-gui", "--", "winedbg", "0x" + pid],
                          env=env, encoding="latin-1", timeout=120)
    def run(command, timeout=120):
        child.send(command + "\r"); child.expect(PROMPT, timeout=timeout)
        return ANSI.sub("", child.before).replace("\r", "")
    def words(address, n):
        text = run(f"x /{n}x 0x{address:x}"); out = []
        for line in text.splitlines()[1:]:
            line = re.sub(r"^\s*0x[0-9a-f]+(\s+\S+)?:", " ", line.strip())
            out += [int(w, 16) for w in re.findall(r"(?<![0-9a-fx])([0-9a-f]{8})(?![0-9a-f])", line)]
        return out[:n]
    child.expect(PROMPT)
    run("break *0x421cdc")
    hits = []
    try:
        def resume():
            # A box the game opens while running (CrossOver's music ERROR)
            # blocks its next tick until on_wait closes it.
            child.send("cont\r")
            while True:
                try: child.expect(PROMPT, timeout=5); return
                except pexpect.TIMEOUT: on_wait()
        child.send("cont\r"); started()
        while True:
            try: child.expect(PROMPT, timeout=5); break
            except pexpect.TIMEOUT: on_wait()
        first_hit(run)
        while len(hits) < count:
            tick, = words(0x450BBC, 1); index, = words(0x450BCC, 1); counter, = words(0x450C34, 1)
            phase12, phase3, phase2 = words(0x450BD0, 3)
            flags = b"".join(w.to_bytes(4, "little") for w in words(WORLD + 4, 5))
            table = words(WORLD + 0x194, 20); seats = {}
            for seat in range(20):
                if not flags[seat]: continue
                a = table[seat]
                seats[seat] = {name: signed(words(a + offset, 1)[0]) for name, offset in FIELDS}
            hits.append(dict(tick=signed(tick), rngIndex=signed(index), rngCounter=signed(counter), phase12=signed(phase12),
                              phase3=signed(phase3), phase2=signed(phase2), seats=seats))
            resume()
    finally:
        try:
            run("delete 1"); child.send("detach\r"); time.sleep(1)
        finally:
            child.close()
    return hits
