#!/usr/bin/env python3
"""Compare two Summary dumps (app --summary-json, summary_original.py): every seat field,
ticks, winner, mode and War totals. Exit 1 on a difference. usage: compare_summaries.py A.json B.json"""
import json
import sys


def load(path):
    d = json.load(open(path)); d.pop("summaryTimer", None); return d


def main(a, b):
    x, y = load(a), load(b); differences = []
    for key in sorted(set(x) | set(y)):
        if key != "seats" and x.get(key) != y.get(key): differences.append(f"{key}: {x.get(key)} != {y.get(key)}")
    sx = {s["seat"]: s for s in x.get("seats", [])}; sy = {s["seat"]: s for s in y.get("seats", [])}
    for seat in sorted(set(sx) | set(sy)):
        if seat not in sx or seat not in sy: differences.append(f"seat {seat} only in one"); continue
        for field in sorted(set(sx[seat]) | set(sy[seat])):
            if sx[seat].get(field) != sy[seat].get(field): differences.append(f"seat {seat} {field}: {sx[seat].get(field)} != {sy[seat].get(field)}")
    print("equal" if not differences else "\n".join(differences))
    return 0 if not differences else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
