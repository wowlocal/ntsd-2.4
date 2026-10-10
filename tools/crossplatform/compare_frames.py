#!/usr/bin/env python3
"""Compare the presented-framebuffer PNGs of two run_headless_scenarios.py
output directories, scenario by scenario.

Usage: compare_frames.py OUT_A OUT_B

Frames come from `--body-frames` (OriginalFramebufferPNG), so equal game
frames give equal bytes on every host. Runs made with `--body-frame-digests`
also report every presented frame's SHA-256 in events.jsonl; those sequences
must be equal too. Prints one JSON line per scenario and a summary; exits 1
when a frame or digest differs or is missing on one side.
"""
import hashlib, json, sys
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def digests(run):
    path = run / "events.jsonl"
    if not path.exists():
        return []
    out = []
    for line in path.read_text().splitlines():
        if line.startswith("{") and '"frameDigest"' in line:
            e = json.loads(line)
            out.append((e["gameplayBodies"], tuple(e["size"]), e["sha256"]))
    return out


def main():
    a, b = Path(sys.argv[1]), Path(sys.argv[2])
    bad = 0
    total = 0
    for scenario in sorted(p.name for p in a.iterdir() if (p / "frames").is_dir()):
        fa = {p.name: p for p in (a / scenario / "frames").glob("*.png")}
        fb = {p.name: p for p in (b / scenario / "frames").glob("*.png")} if (b / scenario / "frames").is_dir() else {}
        names = sorted(set(fa) | set(fb))
        differ = [n for n in names if n in fa and n in fb and digest(fa[n]) != digest(fb[n])]
        missing = [n for n in names if n not in fa or n not in fb]
        da, db = digests(a / scenario), digests(b / scenario)
        first = next((i for i, (x, y) in enumerate(zip(da, db)) if x != y), None)
        digest_bad = first is not None or len(da) != len(db)
        total += len(names) + len(da); bad += len(differ) + len(missing) + (1 if digest_bad else 0)
        row = {"scenario": scenario, "frames": len(names), "identical": len(names) - len(differ) - len(missing),
               "differ": differ[:5], "missing": missing[:5]}
        if da or db:
            row["digests"] = {"a": len(da), "b": len(db), "equal": not digest_bad,
                              "firstDifferentBody": da[first][0] if first is not None else None}
        print(json.dumps(row))
    print(json.dumps({"frames": total, "mismatched": bad, "result": "identical" if bad == 0 and total else "differs"}))
    return 1 if bad or not total else 0


if __name__ == "__main__":
    sys.exit(main())
