#!/usr/bin/env python3
"""Run app_e2e scenarios through NTSDHeadless and compare each with its frozen
reference (tools/crossplatform/compare_headless.py).

Usage: run_headless_scenarios.py OUT_DIR (--linux BUILD_DIR | --linux-amd64 BUILD_DIR | --linux-sdl BUILD_DIR
                                         | --local BINARY | --wine RUN_DIR | --android RUN_DIR) [SCENARIO ...]

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
`--wine` runs RUN_DIR/NTSDHeadless.exe (with its resources and the Swift
runtime DLLs beside it) in the CrossOver bottle ntsd-xplat-test, a test
harness; paths are passed as Z:\\ paths and CRLF is stripped from its output.
$NTSD_WINE_BOTTLE picks another bottle, $NTSD_WINE_EXE names another exe in RUN_DIR (e.g. NTSDSDL.exe) and
$NTSD_WINE_ENV adds KEY=VALUE settings for it, separated by spaces.
`--android` pushes RUN_DIR (NTSDHeadless built for Android, libc++_shared.so
and the resource bundle) and the music to /data/local/tmp/ntsd on the device
adb reaches (an emulator: a test harness), runs each scenario there with
`adb shell`, and pulls its captures, overlay and frames back. $ADB names adb.
$NTSD_LINUX_PLATFORM sets the container platform (e.g. linux/amd64) and
$NTSD_LINUX_IMAGE replaces the container image (e.g. ntsd-linux-runtime:noble
from linux-runtime/Dockerfile, which adds fontconfig and DejaVu for text).
"""
import importlib.util, json, os, shlex, shutil, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("app_e2e", ROOT / "tools/app_e2e.py")
app_e2e = importlib.util.module_from_spec(spec); spec.loader.exec_module(app_e2e)
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
COMPARE = ROOT / "tools/crossplatform/compare_headless.py"
ADB = os.environ.get("ADB", "adb")
DEVICE = Path("/data/local/tmp/ntsd")


def adb(*args, **kw):
    return subprocess.run([ADB, *args], check=True, capture_output=True, text=True, **kw)


def main():
    out = Path(sys.argv[1]).resolve(); mode, target = sys.argv[2], sys.argv[3]
    platform = ["--platform", "linux/amd64"] if mode == "--linux-amd64" else []
    if os.environ.get("NTSD_LINUX_PLATFORM"): platform = ["--platform", os.environ["NTSD_LINUX_PLATFORM"]]
    binary, docker = "NTSDHeadless", []
    if mode == "--linux-sdl":
        binary = "NTSDSDL"
        docker = ["-e", "SDL_VIDEO_DRIVER=offscreen", "-e", "SDL_AUDIO_DRIVER=dummy", "-e", "LD_LIBRARY_PATH=/sdl",
                  "-v", f"{os.environ['NTSD_SDL_LIB']}:/sdl:ro"]
    if mode in ("--linux-amd64", "--linux-sdl"): mode = "--linux"
    names = sys.argv[4:] or list(app_e2e.SCENARIOS)
    if mode == "--android":   # the game and the music, once per run
        adb("shell", f"rm -rf {DEVICE} && mkdir -p {DEVICE}/out {DEVICE}/home")
        adb("push", str(Path(target).resolve()), f"{DEVICE}/app"); adb("push", str(MUSIC), f"{DEVICE}/music")
        adb("shell", f"chmod 755 {DEVICE}/app/NTSDHeadless")
    results = []
    for name in names:
        setup = app_e2e.SCENARIOS[name]
        base = out / name
        shutil.rmtree(base, ignore_errors=True); (base / "captures").mkdir(parents=True); (base / "overlay").mkdir(); (base / "frames").mkdir()
        inner = Path("/out") / name if mode == "--linux" else DEVICE / "out" / name if mode == "--android" else base
        def host(path):   # the path as the game process sees it
            return "Z:" + str(path).replace("/", "\\") if mode == "--wine" else str(path)
        extra = setup["extra"](base) if callable(setup["extra"]) else list(setup["extra"])
        if mode in ("--linux", "--android"):   # files the scenario placed under base are seen under /out
            extra = [str(inner / Path(a).relative_to(base)) if a.startswith(str(base)) else a for a in extra]
        if mode == "--wine":
            extra = [host(a) if a.startswith("/") else a for a in extra]
        script = setup["script"](inner / "captures")
        if mode == "--wine":   # capture paths inside the script
            script = script.replace(str(inner / "captures"), host(inner / "captures"))
        args = ["--original", "--mute-music", "--mute-sounds", "--no-network", "--overlay", host(inner / "overlay"),
                "--virtual-clock", "123456789", "8", "--script-clock", "gameplay", "--body-captures", host(inner / "captures"),
                "--body-frames", host(inner / "frames"), "--body-frame-digests",
                *extra, "--script", script]
        if mode == "--linux":
            command = ["docker", "run", "--rm", *platform, *docker, "-e", "TZ=Etc/GMT-1", "-v", f"{target}:/app:ro", "-v", f"{MUSIC}:/music:ro",
                       "-v", f"{out}:/out", os.environ.get("NTSD_LINUX_IMAGE", "swift:6.4.0-noble"), f"/app/{binary}", "--music-dir", "/music", *args]
        elif mode == "--android":
            adb("shell", f"rm -rf {inner}"); adb("push", str(base), str(inner.parent))
            adb("shell", f"mkdir -p {inner}/captures {inner}/overlay {inner}/frames")   # push skips empty folders
            line = " ".join(shlex.quote(a) for a in [f"{DEVICE}/app/NTSDHeadless", "--music-dir", f"{DEVICE}/music", *args])
            command = [ADB, "shell", f"cd {DEVICE}/app && TZ=Etc/GMT-1 HOME={DEVICE}/home TMPDIR={DEVICE}/home {line}"]
        elif mode == "--wine":
            cx = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
            command = [cx, "--bottle", os.environ.get("NTSD_WINE_BOTTLE", "ntsd-xplat-test"), "--wait-children", host(Path(target).resolve() / os.environ.get("NTSD_WINE_EXE", "NTSDHeadless.exe")),
                       "--music-dir", host(MUSIC), *args]
        else:
            command = [target, "--music-dir", str(MUSIC), *args]
        start = time.time()
        wine_env = dict(kv.split("=", 1) for kv in os.environ.get("NTSD_WINE_ENV", "").split()) if mode == "--wine" else {}
        done = subprocess.run(command, capture_output=True, text=True, timeout=3600,
                              env={**app_e2e.APP_ENV, **wine_env} if mode not in ("--linux", "--android") else None)
        (base / "events.jsonl").write_text(done.stdout.replace("\r\n", "\n")); (base / "stderr.txt").write_text(done.stderr)
        if mode == "--android":
            for d in ("captures", "overlay", "frames"):
                shutil.rmtree(base / d); adb("pull", str(inner / d), str(base))
        compare = [sys.executable, str(COMPARE), str(base / "events.jsonl"), str(base / "captures"), str(base / "overlay"),
                   str(done.returncode), str(setup["reference"])] + ([f"/out={out}"] if mode == "--linux" else
                                                                      [f"{DEVICE}/out={out}"] if mode == "--android" else [])
        c = subprocess.run(compare, capture_output=True, text=True)
        verdict = json.loads(c.stdout.strip().splitlines()[-1]) if c.stdout.strip() else {"result": "error", "differs": [c.stderr[-300:]]}
        row = {"scenario": name, "exit": done.returncode, "seconds": round(time.time() - start, 1), **verdict}
        (base / "compare.txt").write_text(c.stdout + c.stderr)
        results.append(row); print(json.dumps(row), flush=True)
    (out / "results.jsonl").write_text("".join(json.dumps(r) + "\n" for r in results))


if __name__ == "__main__":
    main()
