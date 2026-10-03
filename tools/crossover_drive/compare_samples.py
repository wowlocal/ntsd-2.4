#!/usr/bin/env python3
"""Compare the original's sampled ticks (sample_original.py) with the Mac
app's `--network-trace`: random index and counter and the phase counters.

usage: compare_samples.py SAMPLES.json MAC.jsonl

A sample at the original's clock t (read on entry to 421cdc, before the
tick's increment) is the Mac row after the cycle whose clock reads t + 1.
"""
import json
import sys

FIELDS = ("rngIndex", "rngCounter", "phase12", "phase3", "phase2")


def main(samples, mac):
    rows = {}
    for line in open(mac):
        r = json.loads(line)
        if r.get("kind") == "state" and r.get("completion") == "gameplay" and "clock" in r:
            rows.setdefault(r["clock"], r)
    first = None
    for s in json.load(open(samples)):
        r = rows.get(s["tick"] + 1)
        if r is None: print(s["tick"], "no Mac row"); continue
        diff = {k: (s[k], r[k]) for k in FIELDS if s[k] != r[k]}
        print(s["tick"], "equal" if not diff else diff)
        if diff and first is None: first = s["tick"]
    print("first differing sample:", first)
    return 0 if first is None else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
