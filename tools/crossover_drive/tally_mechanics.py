#!/usr/bin/env python3
"""Per character, the largest MP Usage, Picking and Attack in matches whose
Summaries matched the original (docs/evidence/crossplay-*.json), with the
evidence file of each maximum: which mechanics the equal matches exercised.

usage: tally_mechanics.py OUT.json"""
import glob
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main(out):
    best = {}
    for path in sorted(glob.glob(str(ROOT / "docs/evidence/crossplay-*.json"))):
        try: cases = json.load(open(path)).get("cases", [])
        except (ValueError, AttributeError): continue
        for case in cases:
            if not case.get("equal"): continue
            for seat in case["mac"]["seats"]:
                entry = best.setdefault(seat["id"], {})
                for field in ("mp", "picking", "attack", "kill"):
                    if seat[field] > entry.get(field, {}).get("value", 0):
                        entry[field] = dict(value=seat[field], evidence=Path(path).name, case=case["seed"])
    ids = sorted(best)
    result = dict(characters={str(i): best[i] for i in ids},
                  withoutMP=[i for i in range(1, 26) if "mp" not in best.get(i, {})],
                  withoutPicking=[i for i in range(1, 26) if "picking" not in best.get(i, {})])
    Path(out).write_text(json.dumps(result, indent=1) + "\n")
    print(len(ids), "characters; without MP", result["withoutMP"], "without picking", result["withoutPicking"])


if __name__ == "__main__":
    main(sys.argv[1])
