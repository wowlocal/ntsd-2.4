#!/usr/bin/env python3
"""End-to-end app check: a whole computer-VS match on the release app.

Runs build/swiftpm-app/release/NTSDNative --original with a reproducible
virtual clock, muted music and a temporary overlay; the script picks VS,
Naruto/Sasuke, one computer player and District, fights, and presses Jump on
the Summary. The observed milestones (startup, loading, match launch, tick
progress with character AI/object input counts and window captures, the
return to the menus with its epilogue and replay file, music) are compared
with tools/app_e2e_reference.json; `--record` writes that reference instead.
The original is not executed. Captures are PNGs of the window rendering and
depend on the window's backing scale, which the reference records.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "build/swiftpm-app/release/NTSDNative"
SCRIPT = ROOT / "tools/app_e2e_computer_vs.script"
REFERENCE = ROOT / "tools/app_e2e_reference.json"
# Summary is up by step 9000 at this clock; Jump continues to the selection.
TAIL = "9000 key 74; 9100 capture {captures}/selection.png; 9200 exit"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build():
    swift = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-build"
    subprocess.run([swift, "--package-path", "native", "--scratch-path", "build/swiftpm-app", "--build-system", "native",
                    "-c", "release", "--product", "NTSDNative"], cwd=ROOT, check=True)


def run(timeout):
    with tempfile.TemporaryDirectory(prefix="ntsd-e2e-") as scratch:
        scratch = Path(scratch); overlay = scratch / "overlay"; captures = scratch / "captures"
        overlay.mkdir(); captures.mkdir()
        script = SCRIPT.read_text().strip() + "; " + TAIL.format(captures=captures)
        command = [str(APP), "--original", "--mute-music", "--overlay", str(overlay), "--virtual-clock", "123456789", "8",
                   "--script-clock", "gameplay", "--body-captures", str(captures), "--script", script]
        done = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        events = []
        for line in done.stdout.splitlines():
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        observed = summarize(events, captures, overlay)
        observed["exitCode"] = done.returncode
        return observed


def summarize(events, captures, overlay):
    out = {"milestones": [], "progress": [], "boundary": None}
    for e in events:
        kind = e.get("event")
        if kind == "started":
            out["backingScale"] = e.get("backingScale")
            out["milestones"].append({"event": kind, "requests": e["requests"], "attempts": e["attempts"], "dates": e["dates"]})
        elif kind == "loaded":
            out["milestones"].append({"event": kind, **{k: e[k] for k in ("allocations", "audioRequests", "bitmapRequests", "files")}})
        elif kind == "matchLaunched":
            out["milestones"].append({"event": kind, "iterations": e["iterations"], "cycles": e["cycles"]})
        elif kind == "gameplay":
            out["milestones"].append({"event": kind, "cycles": e["cycles"]})
        elif kind == "progress":
            m = e.get("music", {})
            out["progress"].append({"bodies": e["gameplayBodies"], "iterations": e["iterations"], "cycles": e["cycles"],
                                    "characterAI": e["characterAI"], "objectInputs": e["objectInputs"],
                                    "capture": sha(e["path"]), "track": m.get("track"), "musicPlaying": m.get("playing")})
        elif kind == "menu":
            out["milestones"].append({"event": kind, "iterations": e["iterations"], "cycles": e["cycles"],
                                      "gameplayBodies": e["gameplayBodies"], "epilogues": e["epilogues"],
                                      "replayFiles": e["replayFiles"], "refusedReplays": e["refusedReplays"]})
        elif kind == "captured":
            m = e.get("music", {})
            out["milestones"].append({"event": kind, "iterations": e["iterations"], "capture": sha(e["path"]),
                                      "track": m.get("track"), "musicPlaying": m.get("playing")})
        elif kind == "boundary":
            out["boundary"] = e.get("error")
    out["overlayFiles"] = {str(p.relative_to(overlay)): sha(p) for p in sorted(overlay.rglob("*")) if p.is_file()}
    return out


def compare(reference, observed):
    problems = []
    for key in ("exitCode", "boundary", "milestones", "progress", "overlayFiles"):
        if reference.get(key) != observed.get(key):
            problems.append(key)
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", help="Build the release app first")
    parser.add_argument("--record", action="store_true", help="Write the reference from this run")
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    if args.build:
        build()
    observed = run(args.timeout)
    if args.record:
        REFERENCE.write_text(json.dumps(observed, indent=1, sort_keys=True) + "\n")
        print(json.dumps({"recorded": str(REFERENCE.relative_to(ROOT)), "progress": len(observed["progress"]),
                          "milestones": len(observed["milestones"]), "boundary": observed["boundary"]}))
        return
    reference = json.loads(REFERENCE.read_text())
    if reference.get("backingScale") != observed.get("backingScale"):
        print(json.dumps({"result": "incomparable", "reason": "display backing scale differs from the reference"}))
        sys.exit(2)
    problems = compare(reference, observed)
    print(json.dumps({"result": "pass" if not problems else "fail", "differs": problems,
                      "progress": len(observed["progress"]), "milestones": len(observed["milestones"])}))
    if problems:
        for key in problems:
            print(f"--- {key}\nreference: {json.dumps(reference.get(key))[:2000]}\nobserved:  {json.dumps(observed.get(key))[:2000]}")
        sys.exit(1)


if __name__ == "__main__":
    main()
