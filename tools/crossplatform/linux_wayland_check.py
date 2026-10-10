#!/usr/bin/env python3
"""Run an app_e2e scenario through the Linux SDL build on SDL's Wayland driver,
under a headless Weston compositor in ntsd-linux-runtime:noble (test harness),
and compare it with the scenario's frozen reference.

Usage: linux_wayland_check.py OUT_DIR BUILD_DIR [SCENARIO]   (SDL3 libs from $NTSD_SDL_LIB)

The sdlDrivers event must name the wayland video driver, so the check fails if
SDL fell back to another one.
"""
import importlib.util, json, os, shlex, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("app_e2e", ROOT / "tools/app_e2e.py")
app_e2e = importlib.util.module_from_spec(spec); spec.loader.exec_module(app_e2e)
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"


def main():
    out, build = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    name = sys.argv[3] if len(sys.argv) > 3 else "vs"
    setup = app_e2e.SCENARIOS[name]; base = out / name
    shutil.rmtree(base, ignore_errors=True)
    for d in ("captures", "overlay", "frames"): (base / d).mkdir(parents=True)
    inner = Path("/out") / name
    args = ["--original", "--mute-music", "--mute-sounds", "--no-network", "--music-dir", "/music", "--overlay", str(inner / "overlay"),
            "--virtual-clock", "123456789", "8", "--script-clock", "gameplay", "--body-captures", str(inner / "captures"),
            "--body-frames", str(inner / "frames"), "--body-frame-digests", "--script", setup["script"](inner / "captures")]
    script = " && ".join([
        "mkdir -p /tmp/xdg && chmod 700 /tmp/xdg",
        "(weston --backend=headless --socket=wayland-ntsd --width=1280 --height=1024 >/out/weston.log 2>&1 &)",
        "for i in $(seq 100); do [ -S /tmp/xdg/wayland-ntsd ] && break; sleep 0.1; done",
        "/app/NTSDSDL " + " ".join(shlex.quote(a) for a in args) + " >/out/events.jsonl 2>/out/stderr.txt",
    ])
    done = subprocess.run(["docker", "run", "--rm", "-e", "TZ=Etc/GMT-1", "-e", "XDG_RUNTIME_DIR=/tmp/xdg", "-e", "WAYLAND_DISPLAY=wayland-ntsd",
                           "-e", "SDL_VIDEO_DRIVER=wayland", "-e", "SDL_AUDIO_DRIVER=dummy", "-e", "LD_LIBRARY_PATH=/sdl",
                           "-v", f"{build}:/app:ro", "-v", f"{os.environ['NTSD_SDL_LIB']}:/sdl:ro", "-v", f"{MUSIC}:/music:ro",
                           "-v", f"{base}:/out/{name}", "-v", f"{out}:/out", "ntsd-linux-runtime:noble", "bash", "-c", script],
                          capture_output=True, text=True, timeout=3600)
    events = (out / "events.jsonl").read_text() if (out / "events.jsonl").exists() else ""
    (base / "events.jsonl").write_text(events)
    drivers = next((json.loads(l) for l in events.splitlines() if '"sdlDrivers"' in l), {})
    compare = subprocess.run([sys.executable, str(ROOT / "tools/crossplatform/compare_headless.py"), str(base / "events.jsonl"),
                              str(base / "captures"), str(base / "overlay"), str(done.returncode), str(setup["reference"]), f"/out={out}"],
                             capture_output=True, text=True)
    (base / "compare.txt").write_text(compare.stdout + compare.stderr)
    verdict = json.loads(compare.stdout.strip().splitlines()[-1]) if compare.stdout.strip() else {"result": "error"}
    result = {"scenario": name, "exit": done.returncode, "drivers": {k: drivers.get(k) for k in ("video", "audio")}, **verdict}
    if drivers.get("video") != "wayland": result["result"] = "differs"; result.setdefault("differs", []).append("video driver")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
