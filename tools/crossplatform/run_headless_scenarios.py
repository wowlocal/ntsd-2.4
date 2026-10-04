#!/usr/bin/env python3
"""Run app_e2e scenarios through NTSDHeadless and compare each with its frozen
reference (tools/crossplatform/compare_headless.py).

Usage: run_headless_scenarios.py OUT_DIR (--linux BUILD_DIR | --linux-amd64 BUILD_DIR | --linux-sdl BUILD_DIR
                                         | --local BINARY) [SCENARIO ...]

The command line is app_e2e's own (`run`): --original --mute-music
--mute-sounds --overlay --virtual-clock 123456789 8 --script-clock gameplay
--body-captures, the scenario's extra arguments and script, TZ=Etc/GMT-1, plus
--no-network, --body-frames OUT_DIR/<scenario>/frames (presented framebuffers,
identical PNG bytes on every host) and --body-frame-digests (every presented
frame's SHA-256 as an event); compare runs with compare_frames.py.
`--local` takes any binary with these options: NTSDHeadless, NTSDSDL or the
AppKit NTSDNative, which ignores --music-dir and --no-network. `--linux` runs the cross-built static binary in swift:6.4.0-noble
with the build and music directories read-only and OUT_DIR mounted at /out;
`--linux-amd64` does the same for an x86_64 build on linux/amd64 (Rosetta on
Apple silicon: a test harness, not an x86 host observation). `--linux-sdl` runs
the glibc NTSDSDL build there with SDL's offscreen video and dummy audio
drivers and the SDL3 libraries from $NTSD_SDL_LIB mounted read-only.
"""
import importlib.util, json, os, shutil, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("app_e2e", ROOT / "tools/app_e2e.py")
app_e2e = importlib.util.module_from_spec(spec); spec.loader.exec_module(app_e2e)
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
COMPARE = ROOT / "tools/crossplatform/compare_headless.py"


def main():
    out = Path(sys.argv[1]).resolve(); mode, target = sys.argv[2], sys.argv[3]
    platform = ["--platform", "linux/amd64"] if mode == "--linux-amd64" else []
    binary, docker = "NTSDHeadless", []
    if mode == "--linux-sdl":
        binary = "NTSDSDL"
        docker = ["-e", "SDL_VIDEO_DRIVER=offscreen", "-e", "SDL_AUDIO_DRIVER=dummy", "-e", "LD_LIBRARY_PATH=/sdl",
                  "-v", f"{os.environ['NTSD_SDL_LIB']}:/sdl:ro"]
    if mode in ("--linux-amd64", "--linux-sdl"): mode = "--linux"
    names = sys.argv[4:] or list(app_e2e.SCENARIOS)
    results = []
    for name in names:
        setup = app_e2e.SCENARIOS[name]
        base = out / name
        shutil.rmtree(base, ignore_errors=True); (base / "captures").mkdir(parents=True); (base / "overlay").mkdir(); (base / "frames").mkdir()
        inner = Path("/out") / name if mode == "--linux" else base
        extra = setup["extra"](base) if callable(setup["extra"]) else list(setup["extra"])
        if mode == "--linux":   # files the scenario placed under base are seen under /out
            extra = [str(inner / Path(a).relative_to(base)) if a.startswith(str(base)) else a for a in extra]
        args = ["--original", "--mute-music", "--mute-sounds", "--no-network", "--overlay", str(inner / "overlay"),
                "--virtual-clock", "123456789", "8", "--script-clock", "gameplay", "--body-captures", str(inner / "captures"),
                "--body-frames", str(inner / "frames"), "--body-frame-digests",
                *extra, "--script", setup["script"](inner / "captures")]
        if mode == "--linux":
            command = ["docker", "run", "--rm", *platform, *docker, "-e", "TZ=Etc/GMT-1", "-v", f"{target}:/app:ro", "-v", f"{MUSIC}:/music:ro",
                       "-v", f"{out}:/out", "swift:6.4.0-noble", f"/app/{binary}", "--music-dir", "/music", *args]
        else:
            command = [target, "--music-dir", str(MUSIC), *args]
        start = time.time()
        done = subprocess.run(command, capture_output=True, text=True, timeout=3600,
                              env={**app_e2e.APP_ENV} if mode != "--linux" else None)
        (base / "events.jsonl").write_text(done.stdout); (base / "stderr.txt").write_text(done.stderr)
        compare = [sys.executable, str(COMPARE), str(base / "events.jsonl"), str(base / "captures"), str(base / "overlay"),
                   str(done.returncode), str(setup["reference"])] + ([f"/out={out}"] if mode == "--linux" else [])
        c = subprocess.run(compare, capture_output=True, text=True)
        verdict = json.loads(c.stdout.strip().splitlines()[-1]) if c.stdout.strip() else {"result": "error", "differs": [c.stderr[-300:]]}
        row = {"scenario": name, "exit": done.returncode, "seconds": round(time.time() - start, 1), **verdict}
        (base / "compare.txt").write_text(c.stdout + c.stderr)
        results.append(row); print(json.dumps(row), flush=True)
    (out / "results.jsonl").write_text("".join(json.dumps(r) + "\n" for r in results))


if __name__ == "__main__":
    main()
