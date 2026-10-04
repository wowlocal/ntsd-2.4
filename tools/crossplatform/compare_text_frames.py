#!/usr/bin/env python3
"""Check that two hosts with different glyph rasterisers draw text in the same
frames, using a text-free run as the baseline.

Usage: compare_text_frames.py REFERENCE_OUT TEXTLESS_OUT CANDIDATE_OUT

All three are run_headless_scenarios.py output directories with frame digests
(e.g. AppKit with CoreText, headless without glyphs, Linux SDL with FreeType).
A frame whose digest equals the text-free run's has no text. For every
gameplay body the reference and the candidate must agree on whether text is
present; frames without text must then be identical across all three.
Exits 1 on any disagreement.
"""
import json, sys
from pathlib import Path


def digests(run):
    path = run / "events.jsonl"
    if not path.exists():
        return {}
    return {e["gameplayBodies"]: e["sha256"] for e in map(json.loads, (l for l in path.read_text().splitlines()
            if l.startswith("{") and '"frameDigest"' in l))}


def main():
    ref, bare, cand = (Path(p) for p in sys.argv[1:4])
    bad = 0
    totals = {"frames": 0, "textless": 0, "text": 0, "disagree": 0}
    for scenario in sorted(p.name for p in ref.iterdir() if p.is_dir()):
        r, b, c = digests(ref / scenario), digests(bare / scenario), digests(cand / scenario)
        if not r:
            continue
        if set(r) != set(b) or set(r) != set(c):
            print(json.dumps({"scenario": scenario, "error": "different body sets", "counts": [len(r), len(b), len(c)]})); bad += 1
            continue
        textless = text = 0; disagree = []
        for body in sorted(r):
            rt, ct = r[body] != b[body], c[body] != b[body]
            if rt != ct:
                disagree.append(body)
            elif rt:
                text += 1
            else:
                textless += 1
        bad += len(disagree)
        for k, v in (("frames", len(r)), ("textless", textless), ("text", text), ("disagree", len(disagree))):
            totals[k] += v
        print(json.dumps({"scenario": scenario, "frames": len(r), "textless": textless, "text": text,
                          "disagree": len(disagree), "firstDisagreements": disagree[:5]}))
    print(json.dumps({**totals, "result": "agree" if bad == 0 else "disagree"}))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
