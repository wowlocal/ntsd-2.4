#!/usr/bin/env python3
"""The browser host's saves across page loads (docs/research/TVOS_WEB.md W2b-4a).

Usage: web_saves_check.py BUILD_DIR OUT_DIR [--mac-headless PATH]

BUILD_DIR holds NTSDWeb.wasm and its resource bundle. In each engine
(NTSD_BROWSER_ENGINE chromium and webkit), web_run.mjs runs the web host with
/save kept by the page in the browser's IndexedDB (--persist) on a browser
profile folder kept between runs (--profile) and one port (--port: the
browser keeps storage per origin), with app_e2e's scripted CONTROL
SETTINGS change:

  first   a new profile: player 1's "up" becomes Q (87 -> 81), OK;
  second  the same profile: player 1's "down" becomes X (83 -> 88), OK;
  fresh   a new profile: the second change alone.

The game writes its whole control table to data\\control.txt on OK, so the
second run's file holds both changes only if the game read the first run's
file back from the browser: the stored bytes (the page's report) must be the
packaged control.txt with the first change, both changes, and the second change
alone. With --mac-headless the same two scripts run in the macOS headless host
on one --overlay folder, and its control.txt must equal the second run's.
Prints a JSON report; exits 0 when every check passes.
"""
import hashlib, json, os, socket, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
PACKAGED = (ROOT / "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/data/control.txt").read_bytes()
FIRST = "20 click 410 292; 60 click 250 290; 100 key 81; 140 click 480 450; 220 exit"    # app_e2e's controls_check
SECOND = "20 click 410 292; 60 click 250 312; 100 key 88; 140 click 480 450; 220 exit"   # the row below: down
GAME = ["--original", "--mute-music", "--mute-sounds", "--no-network", "--virtual-clock", "123456789", "8"]
CONTROL = "/save/NTSD Native/data/control.txt"
# What the browser keeps after each run: the overlay's folders, the startup's
# data\adinfo.txt and the control file.
KEYS = ["/save/NTSD Native", "/save/NTSD Native/data", "/save/NTSD Native/data/adinfo.txt", CONTROL]
PROBLEMS = ("web_run: storing", "did not report", "web_run: worker", "timed out")


def changed(data, *pairs):
    for old, new in pairs:
        assert data.count(old) == 1, old
        data = data.replace(old, new)
    return data


EXPECTED = {"first": changed(PACKAGED, (b"0 87 83 65", b"0 81 83 65")),
            "second": changed(PACKAGED, (b"0 87 83 65", b"0 81 88 65")),
            "fresh": changed(PACKAGED, (b"0 87 83 65", b"0 87 88 65"))}


def node():
    found = sorted((Path.home() / ".local/share/fnm/node-versions").glob("v26.*/installation/bin/node"))
    return os.environ.get("NTSD_NODE") or (str(found[-1]) if found else "node")


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0)); return s.getsockname()[1]


def web(engine, build, profile, port, out, script):
    out.mkdir(parents=True)
    command = [node(), str(ROOT / "tools/crossplatform/web_run.mjs"), "--timeout", "600", "--port", str(port),
               "--ro", f"/app={build}", "--ro", f"/music={MUSIC}", "--persist", "/save", "--profile", str(profile),
               "--argv0", "/app/NTSDWeb.wasm", "--metrics", str(out / "browser-metrics.json"), "--canvas", "--",
               str(build / "NTSDWeb.wasm"), "--resources", "/app/NTSDNative_NTSDContent.bundle", "--music-dir", "/music",
               *GAME, "--script", script]
    done = subprocess.run(command, capture_output=True, text=True, timeout=900,
                          env={**os.environ, "NTSD_BROWSER_ENGINE": engine, "TZ": "Etc/GMT-1"})
    (out / "events.jsonl").write_text(done.stdout); (out / "stderr.txt").write_text(done.stderr)
    page = json.loads((out / "page.json").read_text()) if (out / "page.json").exists() else {}
    kept = page.get("kept") or {}
    boundaries = sum(1 for l in done.stdout.splitlines() if '"event":"boundary"' in l.replace(" ", ""))
    problems = [l for l in done.stderr.splitlines() if any(p in l for p in PROBLEMS)]
    return {"exit": done.returncode, "boundaries": boundaries, "problems": problems,
            "kept": {k: v.get("sha256", "dir") for k, v in kept.items()}}


def main():
    args = sys.argv[1:]
    mac = None
    if "--mac-headless" in args:
        at = args.index("--mac-headless"); mac = Path(args[at + 1]); del args[at:at + 2]
    if len(args) != 2:
        sys.exit(__doc__)
    build, base = Path(args[0]).resolve(), Path(args[1]).resolve()
    base.mkdir(parents=True, exist_ok=False)
    expected = {k: hashlib.sha256(v).hexdigest() for k, v in EXPECTED.items()}
    report = {"expected": expected, "engines": {}}
    ok = True
    for engine in ("chromium", "webkit"):
        profile, other, port = base / engine / "profile", base / engine / "profile-fresh", free_port()
        runs = {"first": web(engine, build, profile, port, base / engine / "first", FIRST),
                "second": web(engine, build, profile, port, base / engine / "second", SECOND),
                "fresh": web(engine, build, other, port, base / engine / "fresh", SECOND)}
        for name, run in runs.items():
            run["control"] = run["kept"].get(CONTROL)
            run["pass"] = (run["exit"] == 0 and run["boundaries"] == 0 and not run["problems"]
                           and sorted(run["kept"]) == KEYS and run["control"] == expected[name])
            ok = ok and run["pass"]
        report["engines"][engine] = runs
    if mac:
        with tempfile.TemporaryDirectory(prefix="ntsd-saves-") as overlay:
            exits = [subprocess.run([str(mac), "--music-dir", str(MUSIC), *GAME, "--overlay", overlay, "--script", s],
                                    capture_output=True, text=True, timeout=900, env={**os.environ, "TZ": "Etc/GMT-1"}).returncode
                     for s in (FIRST, SECOND)]
            saved = Path(overlay, "data", "control.txt")
            digest = hashlib.sha256(saved.read_bytes()).hexdigest() if saved.exists() else None
        report["macHeadless"] = {"binary": str(mac), "exits": exits, "control": digest,
                                 "pass": exits == [0, 0] and digest == expected["second"]}
        ok = ok and report["macHeadless"]["pass"]
    report["result"] = "pass" if ok else "fail"
    print(json.dumps(report, indent=1))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
