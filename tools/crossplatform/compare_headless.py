#!/usr/bin/env python3
"""Compare a headless session run with an app e2e reference.

Usage: compare_headless.py EVENTS.jsonl CAPTURES_DIR OVERLAY_DIR EXIT_CODE REFERENCE.json [CONTAINER_DIR=HOST_DIR]

The events come from NTSDHeadless (macOS or Linux) run with the scenario's
app_e2e arguments. They are summarized by tools/app_e2e.py's own `summarize`
and compared key by key with the frozen reference, except capture hashes:
headless captures are framebuffer PNGs without host scaling and, until a
portable glyph rasteriser exists, without GDI text, while the reference hashes
AppKit window renders. Everything else (milestones, progress counters, music,
replay files, boundary, exit code, overlay files) must be equal. A run inside
a container reports its own paths; CONTAINER_DIR=HOST_DIR maps them back.
"""
import importlib.util, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("app_e2e", ROOT / "tools/app_e2e.py")
app_e2e = importlib.util.module_from_spec(spec); spec.loader.exec_module(app_e2e)


def without_captures(value):
    if isinstance(value, list):
        return [without_captures(v) for v in value]
    if isinstance(value, dict):
        return {k: without_captures(v) for k, v in value.items() if k != "capture"}
    return value


def main():
    events_path, captures, overlay, exit_code, reference_path = sys.argv[1:6]
    mapping = sys.argv[6].split("=", 1) if len(sys.argv) > 6 else None
    events = [json.loads(l) for l in open(events_path) if l.startswith("{")]
    if mapping:
        for e in events:
            if isinstance(e.get("path"), str) and e["path"].startswith(mapping[0]):
                e["path"] = mapping[1] + e["path"][len(mapping[0]):]
    observed = app_e2e.summarize(events, Path(captures), Path(overlay))
    observed["exitCode"] = int(exit_code)
    reference = json.loads(Path(reference_path).read_text())
    problems = []
    for key in ("exitCode", "boundary", "milestones", "progress", "overlayFiles"):
        r, o = without_captures(reference.get(key)), without_captures(observed.get(key))
        if r == o:
            print(f"{key}: equal" + (f" ({len(r)} entries)" if isinstance(r, list) else ""))
            continue
        problems.append(key)
        print(f"{key}: DIFFERS")
        if isinstance(r, list) and isinstance(o, list):
            for i, (a, b) in enumerate(zip(r, o)):
                if a != b:
                    print(f"  first difference at {i}:\n    reference {json.dumps(a)[:400]}\n    observed  {json.dumps(b)[:400]}")
                    break
            else:
                print(f"  lengths: reference {len(r)}, observed {len(o)}")
        else:
            print(f"  reference {json.dumps(r)[:400]}\n  observed  {json.dumps(o)[:400]}")
    print(json.dumps({"result": "equal" if not problems else "differs", "differs": problems}))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
