#!/usr/bin/env python3
"""Demo cross-check: the first Demo match in the Mac app and in the original
under CrossOver from the same random table, compared at its Summary.

usage: demo_crossplay.py OUT_DIR BASE [--trace TICKS]

The Demo is not recorded, and its eight computers, teams and background come
from the game's random table. The Mac app seeds the VC80 CRT with timeGetTime
at startup (`--virtual-clock BASE 8` answers BASE there), and START rebuilds
the 3000-byte table at 44ff90 from it once. The original's seed is its real
startup time, so after START its table is overwritten with the Mac's
(`winedbg`, `set` per dword); the table index 450bcc and counter 450c34 are
read on both sides and must agree. Then S x5 and J open the Demo; CrossOver's
music ERROR box is dismissed whenever it appears.

The phase counter 450bd0 (mod 12; HP regeneration when 0, falling and hit
rules) also advances on every menu frame in both programs and is not reset for
a Demo, so its value at the first tick depends on how long the menus were up:
real time in the original. It is set at the original's first tick to the Mac's
(from the app's --network-trace). CROSSPLAY_LOOP.md.
"""
import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import compare_summaries  # noqa: E402
import play_original as po  # noqa: E402
import summary_original  # noqa: E402
import wd  # noqa: E402

APP = ROOT / "build/swiftpm-app/release/NTSDNative"
DEMO = "20 click 350 230; 60 click 402 218; 100 key 83; 125 key 83; 150 key 83; 175 key 83; 200 key 83; 225 key 74; 900000 exit"


def crt_table(seed):
    """EXE 422ac0 after srand(seed): 3000 draws of rand() % 255 + 1."""
    state, out = seed & 0xFFFFFFFF, bytearray()
    for _ in range(3000):
        state = (state * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        out.append(((state >> 16) & 0x7FFF) % 255 + 1)
    return bytes(out)


def mac(out, base):
    path = out / "mac.json"
    if path.exists(): return
    overlay = out / "overlay"; overlay.mkdir(parents=True, exist_ok=True)
    done = subprocess.run([str(APP), "--original", "--mute-music", "--mute-sounds", "--no-activate", "--overlay", str(overlay),
                           "--virtual-clock", str(base), "8", "--script-clock", "gameplay", "--exit-after-summary",
                           "--summary-json", str(path), "--summary-capture", str(out / "mac-summary.png"),
                           "--network-trace", str(out / "mac-trace.jsonl"), "--script", DEMO],
                          capture_output=True, text=True, timeout=7200, env={"TZ": "Etc/GMT-1", "PATH": "/usr/bin:/bin"})
    (out / "mac.stdout").write_text(done.stdout + done.stderr)
    if not path.exists(): raise SystemExit("no Mac summary")


def mac_phase(trace):
    """450bd0 after the Mac's first gameplay cycle (the original's value at
    its first 421cdc, inside that tick)."""
    for line in open(trace):
        r = json.loads(line)
        if r.get("kind") == "state" and r.get("completion") == "gameplay" and r["bodies"] == 1: return r["phase12"]
    raise SystemExit("no first gameplay cycle in the Mac trace")


def original(out, base):
    path = out / "original.json"
    if path.exists(): return
    table = crt_table(base)
    commands = [f"set *(int*)0x{0x44FF90 + i:x} = 0x{int.from_bytes(table[i:i + 4], 'little'):x}" for i in range(0, 3000, 4)]
    poke = out / "table.wdbg"; poke.write_text("\n".join(commands + ["detach"]) + "\n")
    held = po.lock(); clone = po.DEFAULT_CLONE
    launcher, pid = po.start(clone)
    try:
        state = {name: po.word(pid, address) for name, address in (("index", 0x450BCC), ("counter", 0x450C34))}
        wd.wine("winedbg", "--file", "Z:" + str(poke), "0x" + pid, timeout=300)
        check = wd.cmd(pid, "x /4x 0x44ff90")
        if f"{int.from_bytes(table[:4], 'little'):08x}" not in check: raise SystemExit("table not written: " + check)
        state["afterPoke"] = {name: po.word(pid, address) for name, address in (("index", 0x450BCC), ("counter", 0x450C34))}
        (out / "original-random.json").write_text(json.dumps(state, indent=1))
        import trace_ticks
        phase = mac_phase(out / "mac-trace.jsonl"); state["phase12"] = phase
        def dismiss():
            if "ERROR" in po.titles(): po.keys(pid, [36], title="ERROR")
        def first(run):
            state["originalPhase12"] = summary_original.signed(int(re.findall(r"([0-9a-f]{8})\s*$", run("x /x 0x450bd0").strip())[-1], 16))
            run(f"set *(int*)0x450bd0 = {phase}")
        trace_ticks.trace(pid, 1, started=lambda: po.keys(pid, [1] * 5 + [38]), on_wait=dismiss, first_hit=first)
        (out / "original-random.json").write_text(json.dumps(state, indent=1))
        deadline = time.time() + 1800
        while time.time() < deadline:
            if "ERROR" in po.titles(): po.keys(pid, [36], title="ERROR")
            timer = po.word(pid, 0x450BDC)
            if timer is not None and 144 <= timer < 350: break
            time.sleep(1)
        summary_original.main(str(path), timeout=60)
    finally:
        po.stop(clone, launcher); held.close()


def traces(out, base, count):
    """Both programs' per-tick fighters and random index for the first
    `count` ticks (trace_ticks.py; the app's --network-trace)."""
    import trace_ticks
    path = out / "mac-trace.jsonl"
    if not path.exists():
        overlay = out / "trace-overlay"; overlay.mkdir(parents=True, exist_ok=True)
        subprocess.run([str(APP), "--original", "--mute-music", "--mute-sounds", "--no-activate", "--overlay", str(overlay),
                        "--virtual-clock", str(base), "8", "--script-clock", "gameplay", "--exit-after-bodies", str(count + 30),
                        "--network-trace", str(path), "--script", DEMO], capture_output=True, text=True, timeout=7200,
                       env={"TZ": "Etc/GMT-1", "PATH": "/usr/bin:/bin"})
    table = crt_table(base)
    commands = [f"set *(int*)0x{0x44FF90 + i:x} = 0x{int.from_bytes(table[i:i + 4], 'little'):x}" for i in range(0, 3000, 4)]
    poke = out / "table.wdbg"; poke.write_text("\n".join(commands + ["detach"]) + "\n")
    held = po.lock(); clone = po.DEFAULT_CLONE
    launcher, pid = po.start(clone)
    try:
        wd.wine("winedbg", "--file", "Z:" + str(poke), "0x" + pid, timeout=300)
        def dismiss():
            if "ERROR" in po.titles(): po.keys(pid, [36], title="ERROR")
        hits = trace_ticks.trace(pid, count, started=lambda: po.keys(pid, [1] * 5 + [38]), on_wait=dismiss)
    finally:
        po.stop(clone, launcher); held.close()
    (out / "original-trace.json").write_text(json.dumps(hits, indent=0))


def main():
    out, base = Path(sys.argv[1]), int(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 3 and sys.argv[3] == "--trace":
        traces(out, base, int(sys.argv[4])); return 0
    mac(out, base); original(out, base)
    status = compare_summaries.main(str(out / "mac.json"), str(out / "original.json"))
    (out / "result.json").write_text(json.dumps(dict(base=base, equal=status == 0), indent=1))
    return status


if __name__ == "__main__":
    sys.exit(main())
