#!/usr/bin/env python3
"""First tick where the original's trace (trace_ticks.py) and the Mac app's
`--network-trace` part: per gameplay tick the random index and counter and
every active seat's frame and HP.

usage: compare_traces.py ORIGINAL.json MAC.jsonl

The original is read on entry to 421cdc, before that tick's clock increment;
the Mac's state row follows the whole cycle. Rows are aligned on the match
clock: original tick t is the Mac row whose world clock reads t + 1.
"""
import base64
import json
import struct
import sys


def mac_rows(path):
    rows = {}
    for line in open(path):
        r = json.loads(line)
        if r.get("kind") != "state" or r.get("completion") == "menu": continue
        rows.setdefault(r["bodies"], r)
    return rows


def main(original, mac):
    hits = json.load(open(original)); rows = mac_rows(mac)
    # Align: the first original hit's fighters against the Mac rows by bodies.
    first = hits[0]
    def key(seats): return sorted((int(s), v["frame"], v["hp"]) for s, v in seats.items())
    def mkey(r): return sorted((f["seat"], f["frame"], f["hp"]) for f in r["fighters"])
    offset = next((b - 0 for b, r in sorted(rows.items()) if mkey(r) == key(first["seats"]) and r["rngIndex"] == first["rngIndex"]), None)
    if offset is None: print("no Mac row matches the first original tick"); return 1
    print("aligned: original hit 0 (tick", first["tick"], ") = Mac bodies", offset)
    for i, h in enumerate(hits):
        r = rows.get(offset + i)
        if r is None: print("Mac trace ends at hit", i); return 0
        mine = dict(rngIndex=h["rngIndex"], rngCounter=h["rngCounter"], fighters=key(h["seats"]))
        theirs = dict(rngIndex=r["rngIndex"], rngCounter=r["rngCounter"], fighters=mkey(r))
        if mine != theirs:
            print(f"first difference at hit {i} (original tick {h['tick']}, Mac bodies {offset + i})")
            for k in mine:
                if mine[k] != theirs[k]: print(" ", k, "original", mine[k], "Mac", theirs[k])
            return 1
    print("equal for", len(hits), "ticks"); return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
