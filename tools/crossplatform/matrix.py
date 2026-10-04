#!/usr/bin/env python3
"""Cross-host matrix: the app_e2e scenarios on every host this Mac can drive,
with state compared to the frozen references and frames compared across hosts.

Usage: matrix.py OUT_DIR [--hosts a,b,...] [--skip-build] [--reuse]

Hosts (all test harnesses except the AppKit app and macOS SDL, which run on
this Mac itself):
  appkit          build/swiftpm-app NTSDNative (app_e2e's build)
  macos-sdl       NTSDSDL (NTSD_SDL=1), build/swiftpm-sdl
  linux-headless  NTSDHeadless, static musl aarch64, swift:6.4.0-noble container
  linux-x86_64    NTSDHeadless, static musl x86_64, linux/amd64 container (Rosetta)
  linux-sdl       NTSDSDL, glibc aarch64, ntsd-linux-runtime:noble (FreeType text)
  windows         NTSDHeadless.exe in the CrossOver bottle ntsd-xplat-test
  windows-sdl     NTSDSDL.exe in the bottle (GDI text)
  ios             NTSDiOS in the iPad simulator (ios_app.py)

Frames are grouped by glyph rasteriser: CoreText (appkit, macos-sdl, ios),
none (linux-headless, linux-x86_64, windows), FreeType (linux-sdl), GDI
(windows-sdl). Within a group every frame digest must be equal; across groups
the text-free frames must be equal and text must appear in the same frames
(compare_text_frames.py). Writes OUT_DIR/report.json and prints a summary.
The AppKit and macOS SDL hosts need an unlocked session: with the screen
locked the AppKit app stalled (observed 2026-10-04), so they are reported as
blocked instead of run; the other hosts do not draw to the window server.
"""
import argparse, datetime, json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools/crossplatform"
X5 = Path("/Volumes/X5/ntsd-2.4-research/crossplatform")
OSS = Path.home() / "Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift"
XCODE_BUILD = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-build"
GROUPS = {"appkit": "coretext", "macos-sdl": "coretext", "ios": "coretext", "linux-headless": "none", "linux-x86_64": "none",
          "windows": "none", "linux-sdl": "freetype", "windows-sdl": "gdi"}
RUNNER = TOOLS / "run_headless_scenarios.py"


GUI_HOSTS = {"appkit", "macos-sdl"}


def screen_locked():
    out = subprocess.run(["ioreg", "-n", "Root", "-d1", "-a"], capture_output=True, text=True).stdout
    i = out.find("CGSSessionScreenIsLocked")
    return i >= 0 and out[i:i + 80].find("<true/>") >= 0


def sh(cmd, env=None, cwd=ROOT):
    subprocess.run(cmd, check=True, cwd=cwd, env={**os.environ, **(env or {})})


def build(host):
    linux = {"NTSD_PORTABLE": "1"}
    if host == "appkit":
        sh([XCODE_BUILD, "--package-path", "native", "--scratch-path", "build/swiftpm-app", "--build-system", "native", "-c", "release", "--product", "NTSDNative"])
    elif host == "macos-sdl":
        sh([XCODE_BUILD, "--package-path", "native", "--scratch-path", "build/swiftpm-sdl", "--build-system", "native", "-c", "release", "--product", "NTSDSDL"], {"NTSD_SDL": "1"})
    elif host in ("linux-headless", "linux-x86_64"):
        arch = "aarch64" if host == "linux-headless" else "x86_64"
        sh([str(OSS), "build", "--package-path", "native", "--scratch-path", str(X5 / f"build-linux-{arch}"), "--swift-sdk", f"{arch}-swift-linux-musl",
            "-c", "release", "--product", "NTSDHeadless"], linux)
    elif host == "linux-sdl":
        sh([str(OSS), "build", "--package-path", "native", "--scratch-path", str(X5 / "build-linux-glibc-aarch64"), "--swift-sdk", "ntsd-6.4.0-ubuntu24.04-aarch64",
            "-c", "release", "--product", "NTSDSDL"], {**linux, "NTSD_SDL": "1", "NTSD_SDL_PREFIX": str(X5 / "linux-deps/sdl3/install-aarch64"),
                                                      "NTSD_FREETYPE_PREFIX": str(X5 / "linux-deps/freetype/install-aarch64")})
    elif host in ("windows", "windows-sdl"):
        product = "NTSDHeadless" if host == "windows" else "NTSDSDL"
        env = {**linux, **({"NTSD_SDL": "1", "NTSD_SDL_PREFIX": str(X5 / "windows-deps/sdl3/install-x86_64")} if host == "windows-sdl" else {})}
        sh([str(OSS), "build", "--package-path", "native", "--scratch-path", str(X5 / "build-windows-x86_64"), "--build-system", "native",
            "--swift-sdk", "ntsd-6.4.0-windows-x86_64", "-c", "release", "--product", product], env)
        products = X5 / "build-windows-x86_64/x86_64-unknown-windows-msvc/release"; run = X5 / ("win-headless" if host == "windows" else "win-sdl")
        run.mkdir(parents=True, exist_ok=True)
        shutil.copy2(products / f"{product}.exe", run / f"{product}.exe")
        shutil.rmtree(run / "NTSDNative_NTSDCore.resources", ignore_errors=True)
        shutil.copytree(products / "NTSDNative_NTSDCore.resources", run / "NTSDNative_NTSDCore.resources")
        for dll in (X5 / "windows-sdk-extract/tree").glob("*.dll"): shutil.copy2(dll, run / dll.name)
        if host == "windows-sdl": shutil.copy2(X5 / "windows-deps/sdl3/install-x86_64/bin/SDL3.dll", run / "SDL3.dll")


def run(host, out):
    target = out / host
    if host == "appkit":
        sh([sys.executable, str(RUNNER), str(target), "--local", str(ROOT / "build/swiftpm-app/release/NTSDNative")])
    elif host == "macos-sdl":
        sh([sys.executable, str(RUNNER), str(target), "--local", str(ROOT / "build/swiftpm-sdl/release/NTSDSDL")])
    elif host == "linux-headless":
        sh([sys.executable, str(RUNNER), str(target), "--linux", str(X5 / "build-linux-aarch64/out/Products/Release-staticlinux-aarch64")])
    elif host == "linux-x86_64":
        sh([sys.executable, str(RUNNER), str(target), "--linux-amd64", str(X5 / "build-linux-x86_64/out/Products/Release-staticlinux-x86_64")])
    elif host == "linux-sdl":
        sh([sys.executable, str(RUNNER), str(target), "--linux-sdl", str(X5 / "build-linux-glibc-aarch64/out/Products/Release-linux-aarch64")],
           {"NTSD_LINUX_IMAGE": "ntsd-linux-runtime:noble", "NTSD_SDL_LIB": str(X5 / "linux-deps/sdl3/install-aarch64/lib")})
    elif host == "windows":
        sh([sys.executable, str(RUNNER), str(target), "--wine", str(X5 / "win-headless")])
    elif host == "windows-sdl":
        sh([sys.executable, str(RUNNER), str(target), "--wine", str(X5 / "win-sdl")],
           {"NTSD_WINE_EXE": "NTSDSDL.exe", "NTSD_WINE_ENV": "NTSD_SDL_VIDEO_DRIVER=offscreen NTSD_SDL_AUDIO_DRIVER=dummy"})
    elif host == "ios":
        target.mkdir(parents=True, exist_ok=True)
        rows = []
        for scenario in ("vs", "mission", "demo", "war", "playback", "tournament", "altenter", "tournament-win", "team-tournament", "joystick"):
            line = subprocess.run([sys.executable, str(TOOLS / "ios_app.py"), str(target), scenario], capture_output=True, text=True).stdout.strip().splitlines()[-1]
            rows.append({"scenario": scenario, **json.loads(line)})
        (target / "results.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))


def compare(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(r.stdout.strip().splitlines()[-1])


def main():
    a = argparse.ArgumentParser(); a.add_argument("out", type=Path)
    a.add_argument("--hosts", default=",".join(GROUPS)); a.add_argument("--skip-build", action="store_true")
    a.add_argument("--reuse", action="store_true", help="keep hosts whose OUT_DIR/<host>/results.jsonl already lists every scenario")
    args = a.parse_args(); out = args.out.resolve(); out.mkdir(parents=True, exist_ok=True)
    hosts = args.hosts.split(",")
    report = {"date": datetime.datetime.now().isoformat(timespec="seconds"),
              "commit": subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip(),
              "dirty": subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain", "native"], capture_output=True, text=True).stdout.strip() != "",
              "hosts": {}, "frames": {}}
    blocked = [h for h in hosts if h in GUI_HOSTS and screen_locked()]
    for host in blocked:
        report["hosts"][host] = {"group": GROUPS[host], "blocked": "screen locked"}
        print(host, "blocked: screen locked", flush=True)
    hosts = [h for h in hosts if h not in blocked]
    for host in hosts:
        done = out / host / "results.jsonl"
        if args.reuse and done.exists() and len([l for l in done.read_text().splitlines() if l.strip()]) == 10:
            print(host, "reused", flush=True)
        else:
            if not args.skip_build: build(host)
            run(host, out)
        rows = [json.loads(l) for l in (out / host / "results.jsonl").read_text().splitlines() if l.strip()]
        report["hosts"][host] = {"group": GROUPS[host], "equal": [r["scenario"] for r in rows if r["result"] == "equal"],
                                 "differs": {r["scenario"]: r.get("differs") for r in rows if r["result"] != "equal"}}
        print(host, len(report["hosts"][host]["equal"]), "/", len(rows), "equal", flush=True)
    by_group = {}
    for host in hosts: by_group.setdefault(GROUPS[host], []).append(host)
    for group, members in by_group.items():
        for other in members[1:]:
            report["frames"][f"{members[0]}=={other}"] = compare([sys.executable, str(TOOLS / "compare_frames.py"), str(out / members[0]), str(out / other)])
    bare = by_group.get("none", [None])[0]; ref = by_group.get("coretext", [None])[0]
    if bare and ref:
        for group, members in by_group.items():
            if group not in ("none", "coretext"):
                report["frames"][f"text:{ref}~{members[0]}"] = compare([sys.executable, str(TOOLS / "compare_text_frames.py"), str(out / ref), str(out / bare), str(out / members[0])])
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report["frames"], indent=1))


if __name__ == "__main__":
    main()
