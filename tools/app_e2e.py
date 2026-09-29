#!/usr/bin/env python3
"""End-to-end app check: a whole computer-VS match on the release app.

Runs build/swiftpm-app/release/NTSDNative --original with a reproducible
virtual clock, muted music and a temporary overlay; the script picks VS,
Naruto/Sasuke, one computer player and District, fights, and presses Jump on
the Summary. The observed milestones (startup, loading, match launch, tick
progress with character AI/object input counts and window captures, the
return to the menus with its epilogue and replay file, music) are compared
with tools/app_e2e_reference.json; `--record` writes that reference instead.
Further runs end the game on each quit path — Quit on the main menu, ESC
(No, then Yes) and the window's close button — and require WM_QUIT to end
the process with code 0. Mission, War, Demo, Playback Recording, Tournament and
Team Tournament scenarios compare with their own references. The original is not executed. Captures are PNGs of the window rendering and
depend on the window's backing scale, which the reference records.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
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
# Playback Recording: the VS scenario's own recording (carried by the loader
# fixture) is chosen in place of the file dialog and plays; F4 ends it and
# returns to the main menu with the saved settings restored.
PLAYBACK = ("20 click 350 230; 60 click 402 218; " + "".join(f"{100 + 25 * i} key 83; " for i in range(6))
            + "250 key 74; 9000 key 115; 9600 capture {captures}/after-f4.png; 9700 exit")
LOADER_FIXTURE = ROOT / "native/Tests/NTSDCoreTests/Fixtures/original-replay-loader.json"
# Tournament / Team Tournament: fighter 1 is the first character as Human,
# the other seven Random computers; No at "Shuffle the order?", Fight!, the
# human's device (Attack), Yes at "Is the setting ok?". The human's match is
# played; the bracket then decides the computer pairings, shows the Winner,
# and Attack returns to the main menu.
BRACKET_SETUP = ("250 key 68; 275 key 74; 300 key 68; 325 key 74; " + "".join(f"{t} key 74; {t + 25} key 74; " for t in range(350, 700, 50))
                 + "800 key 68; 825 key 74; 900 key 87; 925 key 87; 975 key 74; 1400 key 74; 1500 key 68; 1550 key 74; ")
TOURNAMENT = ("20 click 350 230; 60 click 402 218; 100 key 83; 125 key 83; 150 key 74; " + BRACKET_SETUP
              + "9100 key 74; 12000 capture {captures}/winner.png; 13100 key 74; 13500 capture {captures}/menu.png; 13600 exit")
TEAM_TOURNAMENT = ("20 click 350 230; 60 click 402 218; 100 key 83; 125 key 83; 150 key 83; 175 key 74; " + BRACKET_SETUP
                   + "9100 key 68; 9200 key 74; 9600 key 68; 9700 key 74; 10000 capture {captures}/winner.png; "
                   + "10100 key 68; 10200 key 74; 10500 capture {captures}/menu.png; 10600 exit")


def playback_file(scratch):
    import base64
    path = scratch / "20260101_010000_VS.lfr"
    path.write_bytes(base64.b64decode(json.loads(LOADER_FIXTURE.read_text())["recordings"]["vs"]))
    return ["--playback-file", str(path)]


SCENARIOS = {
    "vs": dict(reference=REFERENCE, extra=[], script=lambda captures: SCRIPT.read_text().strip() + "; " + TAIL.format(captures=captures)),
    "mission": dict(reference=ROOT / "tools/app_e2e_mission_reference.json", extra=["--exit-after-bodies", "1800"],
                    script=lambda captures: MISSION),
    "demo": dict(reference=ROOT / "tools/app_e2e_demo_reference.json", extra=[],
                 script=lambda captures: DEMO.replace("{captures}", str(captures))),
    "war": dict(reference=ROOT / "tools/app_e2e_war_reference.json", extra=[],
                script=lambda captures: WAR.format(jump=14000, settings=14300, end=14400, captures=captures)),
    "playback": dict(reference=ROOT / "tools/app_e2e_playback_reference.json", extra=playback_file,
                     script=lambda captures: PLAYBACK.replace("{captures}", str(captures))),
    "tournament": dict(reference=ROOT / "tools/app_e2e_tournament_reference.json", extra=[],
                       script=lambda captures: TOURNAMENT.replace("{captures}", str(captures))),
    "team-tournament": dict(reference=ROOT / "tools/app_e2e_team_tournament_reference.json", extra=[],
                            script=lambda captures: TEAM_TOURNAMENT.replace("{captures}", str(captures))),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build():
    swift = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-build"
    subprocess.run([swift, "--package-path", "native", "--scratch-path", "build/swiftpm-app", "--build-system", "native",
                    "-c", "release", "--product", "NTSDNative"], cwd=ROOT, check=True)


KEPT = ROOT / "build/research/e2e"


def run(timeout, app=APP, scenario="vs"):
    with tempfile.TemporaryDirectory(prefix="ntsd-e2e-") as scratch:
        scratch = Path(scratch); overlay = scratch / "overlay"
        # Captures stay in build/research/e2e/<scenario> (replaced each run) so a
        # differing capture hash can be inspected; nothing else depends on them.
        captures = KEPT / scenario / "captures"
        shutil.rmtree(captures, ignore_errors=True); captures.mkdir(parents=True)
        overlay.mkdir()
        setup = SCENARIOS[scenario]
        extra = setup["extra"](scratch) if callable(setup["extra"]) else setup["extra"]
        command = [str(app), "--original", "--mute-music", "--mute-sounds", "--overlay", str(overlay), "--virtual-clock", "123456789", "8",
                   "--script-clock", "gameplay", "--body-captures", str(captures), *extra, "--script", setup["script"](captures)]
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


# Quit paths (APPLICATION_QUIT.md, APPLICATION_WINDOW_CLOSE.md): the loaded main
# menu's Quit; ESC answered No (the game continues) then Yes on the mode menu;
# the window's close button on the front menu. Each ends with WM_QUIT, code 0.
QUITS = {
    "menu": ("20 click 350 230; 60 click 402 218; " + "; ".join(f"{100 + 25 * i} key 83" for i in range(7))
             + "; 275 key 74; 2000 exit", []),
    "escape": ("20 click 350 230; 60 click 402 218; 140 answer no; 150 key 27; 240 answer yes; 250 key 27; 2000 exit", [7, 6]),
    "close": ("20 close; 2000 exit", []),
}


def quit_check(timeout, app=APP):
    """Every quit path: PostQuitMessage, WM_QUIT through the loop, exit 0."""
    results = {}
    for name, (script, answers) in QUITS.items():
        with tempfile.TemporaryDirectory(prefix="ntsd-quit-") as scratch:
            done = subprocess.run([str(app), "--original", "--exit-after-capture", "--mute-music", "--mute-sounds", "--overlay", scratch,
                                   "--virtual-clock", "123456789", "8", "--script", script],
                                  capture_output=True, text=True, timeout=timeout)
            events = [json.loads(l) for l in done.stdout.splitlines() if l.startswith("{")]
            quits = [e for e in events if e.get("event") == "quit"]
            boxes = [e["answer"] for e in events if e.get("event") == "messageBox"]
            ok = (done.returncode == 0 and len(quits) == 1 and quits[0]["code"] == 0 and boxes == answers
                  and not any(e.get("event") == "boundary" for e in events))
            results[name] = (ok, {"exitCode": done.returncode, "quit": quits, "messageBoxes": boxes})
    return all(ok for ok, _ in results.values()), {k: v for k, (_, v) in results.items()}


def website_check(timeout, app=APP):
    """Front menu → OFFICIAL WEBSITE: ShellExecuteA("open", the URL), reported
    by scripted runs instead of opening a browser; the menu keeps running."""
    with tempfile.TemporaryDirectory(prefix="ntsd-web-") as scratch:
        done = subprocess.run([str(app), "--original", "--mute-music", "--mute-sounds", "--overlay", scratch,
                               "--virtual-clock", "123456789", "8", "--script", "20 click 410 352; 120 exit"],
                              capture_output=True, text=True, timeout=timeout)
        events = [json.loads(l) for l in done.stdout.splitlines() if l.startswith("{")]
        opened = [e["file"] for e in events if e.get("event") == "shellOpen"]
        ok = done.returncode == 0 and opened == ["http://littlefighter.com"] and not any(e.get("event") == "boundary" for e in events)
        return ok, {"exitCode": done.returncode, "opened": opened}


def controls_check(timeout, app=APP):
    """Front menu → CONTROL SETTINGS: player 1's "up" cell, Q, OK. The overlay's
    data\\control.txt is the packaged file with that key changed (87 → 81) in
    Windows text form, and the menu keeps running (background reloaded)."""
    packaged = (ROOT / "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/data/control.txt").read_bytes()
    expected = packaged.replace(b"0 87 83 65", b"0 81 83 65", 1)
    with tempfile.TemporaryDirectory(prefix="ntsd-controls-") as scratch:
        done = subprocess.run([str(app), "--original", "--mute-music", "--mute-sounds", "--overlay", scratch,
                               "--virtual-clock", "123456789", "8", "--script",
                               "20 click 410 292; 60 click 250 290; 100 key 81; 140 click 480 450; 220 exit"],
                              capture_output=True, text=True, timeout=timeout)
        events = [json.loads(l) for l in done.stdout.splitlines() if l.startswith("{")]
        saved = Path(scratch, "data", "control.txt")
        written = saved.read_bytes() if saved.exists() else None
        ok = (done.returncode == 0 and expected != packaged and written == expected
              and not any(e.get("event") == "boundary" for e in events))
        return ok, {"exitCode": done.returncode, "saved": written is not None, "matches": written == expected}


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
        elif kind == "playbackDialog":
            out["milestones"].append({"event": kind, "file": Path(e["file"]).name, "iterations": e["iterations"]})
        elif kind == "playbackAlert":
            out["milestones"].append({"event": kind, "text": e["text"], "iterations": e["iterations"]})
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
                problems.append("quit"); reference["quit"] = "exit 0 with one quit event (code 0) on every quit path"; observed["quit"] = detail
            ok, detail = website_check(args.timeout, args.app)
            if not ok:
                problems.append("website"); reference["website"] = "one shellOpen of http://littlefighter.com, exit 0"; observed["website"] = detail
            ok, detail = controls_check(args.timeout, args.app)
            if not ok:
                problems.append("controls"); reference["controls"] = "control.txt saved with P1 up = 81, exit 0"; observed["controls"] = detail
        print(json.dumps({"scenario": name, "result": "pass" if not problems else "fail", "differs": problems,
                          "resources": observed.get("resources"), "progress": len(observed["progress"]), "milestones": len(observed["milestones"])}))
        for key in problems:
            print(f"--- {key}\nreference: {json.dumps(reference.get(key))[:2000]}\nobserved:  {json.dumps(observed.get(key))[:2000]}")
        failed = failed or bool(problems)
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
