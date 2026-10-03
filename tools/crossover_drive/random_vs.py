#!/usr/bin/env python3
"""Random VS cross-check: the Mac app records a VS match of P1 and N computers,
all with Random characters on a Random background, then the original under
CrossOver plays the recording and both Summaries are compared from memory.

usage: random_vs.py OUT_DIR SEED [SEED...] [--computers N] [--rerolls K]

Per seed: the app runs with `--virtual-clock SEED 8`; P1 joins as Random and
stays idle; the final menu's Randomize is pressed K times before Fight!. The
recording, the app's `--summary-json`, the original's dump (play_original.py)
and the comparison go to OUT_DIR/SEED/. CROSSPLAY_LOOP.md.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import compare_summaries  # noqa: E402
import play_original  # noqa: E402

APP = ROOT / "build/swiftpm-app/release/NTSDNative"


def script(computers, rerolls):
    steps = ["20 click 350 230", "60 click 402 218", "100 key 74", "150 key 74", "200 key 74", "250 key 74"]
    t = 1000
    for _ in range(computers - 1): steps.append(f"{t} key 68"); t += 30
    steps.append(f"{t} key 74"); t += 90
    for _ in range(computers): steps += [f"{t} key 74", f"{t + 100} key 74"]; t += 200
    t += 100
    for _ in range(rerolls): steps.append(f"{t} key 74"); t += 100
    steps += [f"{t} key 87", f"{t + 30} key 87", f"{t + 80} key 74", "60000 exit"]
    return "; ".join(steps)


def run(out, seed, computers, rerolls):
    d = out / str(seed); d.mkdir(parents=True, exist_ok=True); overlay = d / "overlay"; overlay.mkdir(exist_ok=True)
    mac = d / "mac.json"
    if not mac.exists():
        done = subprocess.run([str(APP), "--original", "--mute-music", "--mute-sounds", "--overlay", str(overlay),
                               "--virtual-clock", str(seed), "8", "--script-clock", "gameplay", "--exit-after-summary",
                               "--summary-json", str(mac), "--summary-capture", str(d / "mac-summary.png"),
                               "--script", script(computers, rerolls)], capture_output=True, text=True, timeout=1800,
                              env={"TZ": "Etc/GMT-1", "PATH": "/usr/bin:/bin"})
        (d / "mac.stdout").write_text(done.stdout + done.stderr)
    recordings = sorted(overlay.rglob("*.lfr"))
    result = dict(seed=seed, computers=computers, rerolls=rerolls, recording=[str(r) for r in recordings])
    if not mac.exists() or not recordings:
        result["result"] = "no Mac summary or recording"; return result
    original = d / "original.json"
    if not original.exists():
        try: play_original.main(str(recordings[-1]), str(original))
        except SystemExit as e: result["result"] = f"original: {e}"; return result
    status = compare_summaries.main(str(mac), str(original))
    result["result"] = "equal" if status == 0 else "different"
    result["mac"] = json.loads(mac.read_text()); result["original"] = json.loads(original.read_text())
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument("out"); p.add_argument("seeds", nargs="+", type=int)
    p.add_argument("--computers", type=int, default=3); p.add_argument("--rerolls", type=int, default=0)
    a = p.parse_args(); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    results = []
    for seed in a.seeds:
        r = run(out, seed, a.computers, a.rerolls); results.append(r)
        print(seed, r["result"], [s["id"] for s in r.get("mac", {}).get("seats", [])], flush=True)
        (out / "results.json").write_text(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
