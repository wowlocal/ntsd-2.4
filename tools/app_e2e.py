#!/usr/bin/env python3
"""End-to-end app check: a whole computer-VS match on the release app.

Runs build/swiftpm-app/release/NTSDNative --original with a reproducible
virtual clock, muted music and a temporary overlay; the script picks VS,
Naruto/Sasuke, one computer player and District, fights, and presses Jump on
the Summary. The observed milestones (startup, loading, match launch, tick
progress with character AI/object input counts and window captures, the
return to the menus with its epilogue and replay file, music) are compared
with tools/app_e2e_reference.json; `--record` writes that reference instead.
A second run chooses Quit on the main menu and requires WM_QUIT to end the
process with code 0. The original is not executed. Captures are PNGs of the window rendering and
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
# Mission Mode: player 1 (Naruto), no computers, Fight!; Stage 1-1 until the
# enemy has knocked the idle player out and the Summary is shown.
MISSION = ("20 click 350 230; 60 click 402 218; 100 key 83; 125 key 74; 175 key 74; 200 key 68; 225 key 74; "
           "250 key 74; 1000 key 74; 1100 key 87; 1125 key 87; 1160 key 74; 30000 exit")
# War: one human (Naruto) and one computer, War setup defaults, Fight!; the
# troops fight until the Summary, Jump returns to the War settings.
WAR = ("20 click 350 230; 60 click 402 218; 100 key 83; 125 key 83; 150 key 83; 175 key 83; 200 key 74; "
       "250 key 74; 275 key 68; 300 key 74; 325 key 74; 400 key 75; 425 key 75; 450 key 75; 475 key 75; "
       "1000 key 74; 1100 key 68; 1150 key 74; 1200 key 74; 1400 key 74; 1450 key 87; 1500 key 87; 1600 key 74; "
       "{jump} key 74; {settings} capture {captures}/war-settings.png; {end} exit")
# Demo: the first automatic match (eight computers) plays; Jump pressed through
# its closing window ends the Demo and returns to the main menu.
DEMO = ("20 click 350 230; 60 click 402 218; 100 key 83; 125 key 83; 150 key 83; 175 key 83; 200 key 83; 225 key 74; "
        + "".join(f"{t} key 75; " for t in range(1000, 7001, 20)) + "7200 capture {captures}/demo-exit.png; 7300 exit")
SCENARIOS = {
    "vs": dict(reference=REFERENCE, extra=[], script=lambda captures: SCRIPT.read_text().strip() + "; " + TAIL.format(captures=captures)),
    "mission": dict(reference=ROOT / "tools/app_e2e_mission_reference.json", extra=["--exit-after-bodies", "1800"],
                    script=lambda captures: MISSION),
    "demo": dict(reference=ROOT / "tools/app_e2e_demo_reference.json", extra=[],
                 script=lambda captures: DEMO.replace("{captures}", str(captures))),
    "war": dict(reference=ROOT / "tools/app_e2e_war_reference.json", extra=[],
                script=lambda captures: WAR.format(jump=14000, settings=14300, end=14400, captures=captures)),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build():
    swift = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-build"
    subprocess.run([swift, "--package-path", "native", "--scratch-path", "build/swiftpm-app", "--build-system", "native",
                    "-c", "release", "--product", "NTSDNative"], cwd=ROOT, check=True)


def run(timeout, app=APP, scenario="vs"):
    with tempfile.TemporaryDirectory(prefix="ntsd-e2e-") as scratch:
        scratch = Path(scratch); overlay = scratch / "overlay"; captures = scratch / "captures"
        overlay.mkdir(); captures.mkdir()
        setup = SCENARIOS[scenario]
        command = [str(app), "--original", "--mute-music", "--overlay", str(overlay), "--virtual-clock", "123456789", "8",
                   "--script-clock", "gameplay", "--body-captures", str(captures), *setup["extra"], "--script", setup["script"](captures)]
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


def quit_check(timeout, app=APP):
    """Main menu → Quit: PostQuitMessage, WM_QUIT through the loop, exit 0."""
    with tempfile.TemporaryDirectory(prefix="ntsd-quit-") as scratch:
        downs = "; ".join(f"{100 + 25 * i} key 83" for i in range(7))
        script = f"20 click 350 230; 60 click 402 218; {downs}; 275 key 74; 2000 exit"
        done = subprocess.run([str(app), "--original", "--exit-after-capture", "--mute-music", "--overlay", scratch,
                               "--virtual-clock", "123456789", "8", "--script", script],
                              capture_output=True, text=True, timeout=timeout)
        events = [json.loads(l) for l in done.stdout.splitlines() if l.startswith("{")]
        quits = [e for e in events if e.get("event") == "quit"]
        ok = done.returncode == 0 and len(quits) == 1 and quits[0]["code"] == 0 and not any(e.get("event") == "boundary" for e in events)
        return ok, {"exitCode": done.returncode, "quit": quits}


def summarize(events, captures, overlay):
    out = {"milestones": [], "progress": [], "boundary": None}
    for e in events:
        kind = e.get("event")
        if kind == "started":
            out["backingScale"] = e.get("backingScale"); out["resources"] = e.get("resources")
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
    parser.add_argument("--app", type=Path, default=APP, help="Executable to run, e.g. the packaged .app's")
    parser.add_argument("--skip-quit", action="store_true", help="Do not run the main-menu Quit check")
    parser.add_argument("--scenario", choices=["all", *SCENARIOS], default="all")
    args = parser.parse_args()
    if args.build:
        build()
    failed = False
    for name in (SCENARIOS if args.scenario == "all" else [args.scenario]):
        path = SCENARIOS[name]["reference"]
        observed = run(args.timeout, args.app, name)
        if args.record:
            path.write_text(json.dumps(observed, indent=1, sort_keys=True) + "\n")
            print(json.dumps({"scenario": name, "recorded": str(path.relative_to(ROOT)), "progress": len(observed["progress"]),
                              "milestones": len(observed["milestones"]), "boundary": observed["boundary"]}))
            continue
        reference = json.loads(path.read_text())
        if reference.get("backingScale") != observed.get("backingScale"):
            print(json.dumps({"scenario": name, "result": "incomparable", "reason": "display backing scale differs from the reference"}))
            sys.exit(2)
        problems = compare(reference, observed)
        if name == "vs" and not args.skip_quit:
            ok, detail = quit_check(args.timeout, args.app)
            if not ok:
                problems.append("quit"); reference["quit"] = "exit 0 with one quit event (code 0)"; observed["quit"] = detail
        print(json.dumps({"scenario": name, "result": "pass" if not problems else "fail", "differs": problems,
                          "resources": observed.get("resources"), "progress": len(observed["progress"]), "milestones": len(observed["milestones"])}))
        for key in problems:
            print(f"--- {key}\nreference: {json.dumps(reference.get(key))[:2000]}\nobserved:  {json.dumps(observed.get(key))[:2000]}")
        failed = failed or bool(problems)
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
