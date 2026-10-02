#!/usr/bin/env python3
"""Interactive winedbg trace of the running original under CrossOver: the catalog
checksum 44f620 at every entry of the object loader (40ef70), and optionally at a
second address, after START is set in memory at the main menu (APPLICATION_CATALOG_CHECKSUM.md).
usage: trace_real.py OUT.json [SECOND_BREAK_HEX]"""
import json, os, re, subprocess, sys, time
import pexpect
import wd
BOTTLES = wd.BOTTLES
def main(out, bg_entry=None):
    pid = wd.wpid(); assert pid, "no NTSD process"
    env = dict(os.environ, CX_BOTTLE_PATH=BOTTLES)
    child = pexpect.spawn(wd.WINE, ["--bottle", "NTSD24XP", "--no-gui", "--", "winedbg", "0x" + pid], env=env, encoding="latin-1", timeout=120)
    prompt = r"Wine-dbg>"
    def run(command, timeout=120):
        child.send(command + "\r"); child.expect(prompt, timeout=timeout)
        return re.sub(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07", "", child.before).replace("\r", "")
    child.expect(prompt)
    run("break *0x40ef70")
    if bg_entry: run(f"break *0x{bg_entry}")
    for a, v in ((0x4546f0, 350), (0x453cdc, 230), (0x457580, 1)): run(f"set *(int*)0x{a:x} = {v}")
    hits = []
    for i in range(400):
        try:
            text = run("cont", timeout=60)
        except pexpect.TIMEOUT:
            # No further hit: the loading finished. Break into the debugger.
            child.sendcontrol("c"); child.expect(prompt, timeout=60); break
        where = re.findall(r"Stopped on breakpoint \d+ at (0x[0-9a-f]+)", text)
        value = re.findall(r"^\s*([0-9a-f]{8})\s*$", run("x /x 0x44f620"), re.M)
        hits.append(dict(at=where[-1] if where else None, checksum=int(value[-1], 16) if value else None))
        json.dump(hits, open(out, "w"), indent=1)
        if not where: break
        if i % 10 == 0: print(i, hits[-1], flush=True)
    value = re.findall(r"^\s*([0-9a-f]{8})\s*$", run("x /x 0x44f620"), re.M)
    hits.append(dict(at="after loading", checksum=int(value[-1], 16) if value else None))
    json.dump(hits, open(out, "w"), indent=1)
    child.send("detach\r"); child.close()
    print("hits", len(hits), "final", hex(hits[-1]["checksum"] or 0))
if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
