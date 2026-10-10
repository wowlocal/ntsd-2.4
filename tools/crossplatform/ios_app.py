#!/usr/bin/env python3
"""Build NTSDiOS for the iPad simulator, wrap it into an app and run an
app_e2e scenario in the simulator (P8; test harness: the simulator, not a
device).

Usage: ios_app.py OUT_DIR [SCENARIO] [--device NAME]

Builds with SwiftPM for arm64-apple-ios17.0-simulator (NTSD_PORTABLE=1
NTSD_IOS=1), writes OUT_DIR/NTSDiOS.app (executable, the Original* resource
folders at the app root as the macOS packaging installs them, OriginalMusic,
Info.plist; ad-hoc signed), boots the simulator, installs it and
launches it with app_e2e's command line for SCENARIO (default vs) plus
--body-frames and --body-frame-digests. Paths point into the app's data
container. The output lands in OUT_DIR/<scenario> like run_headless_scenarios.py
and is compared with the scenario's frozen reference.
"""
import argparse, importlib.util, json, os, plistlib, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("app_e2e", ROOT / "tools/app_e2e.py")
app_e2e = importlib.util.module_from_spec(spec); spec.loader.exec_module(app_e2e)
X5 = Path("/Volumes/X5/ntsd-2.4-research/crossplatform")
BUNDLE_ID = "local.ntsd.native.ios"


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout.strip()


def main():
    a = argparse.ArgumentParser(); a.add_argument("out", type=Path); a.add_argument("scenario", nargs="?", default="vs")
    a.add_argument("--device", default="iPad Air 13-inch (M4)")
    a.add_argument("--scratch", type=Path, default=X5 / "build-ios-sim")
    args = a.parse_args(); out = args.out.resolve()
    sdk = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"])
    # The shipping build drops Swift's dynamic exclusivity checks (the user's decision, CORE_REALTIME 4aa).
    env = {**os.environ, "NTSD_PORTABLE": "1", "NTSD_IOS": "1", "NTSD_UNCHECKED_EXCLUSIVITY": "1"}
    common = ["xcrun", "--toolchain", "XcodeDefault", "swift", "build", "--package-path", str(ROOT / "native"),
              "--scratch-path", str(args.scratch), "--triple", "arm64-apple-ios17.0-simulator", "--sdk", sdk,
              "-c", "release", "--product", "NTSDiOS"]
    subprocess.run(common, env=env, check=True)
    products = Path(run(common + ["--show-bin-path"], env=env))
    app = out / "NTSDiOS.app"; shutil.rmtree(app, ignore_errors=True); app.mkdir(parents=True)
    shutil.copy2(products / "NTSDiOS", app / "NTSDiOS")
    # Inside an .app the input loaders read their folders from the main
    # bundle's resources (as the macOS packaging installs them), not .module.
    for folder in sorted((products / "NTSDNative_NTSDCore.bundle").iterdir()):
        if folder.is_dir() and folder.name.startswith("Original"):
            shutil.copytree(folder, app / folder.name)
    shutil.copytree(ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic", app / "OriginalMusic")
    plistlib.dump({"CFBundleIdentifier": BUNDLE_ID, "CFBundleExecutable": "NTSDiOS", "CFBundleName": "NTSD Native",
                   "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1", "CFBundleVersion": "1",
                   "CFBundleSupportedPlatforms": ["iPhoneSimulator"], "MinimumOSVersion": "17.0", "LSRequiresIPhoneOS": True,
                   "UIDeviceFamily": [2], "UIRequiresFullScreen": True, "UILaunchScreen": {},
                   "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
                   "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False, "UISceneConfigurations": {
                       "UIWindowSceneSessionRoleApplication": [{"UISceneConfigurationName": "Default",
                                                               "UISceneDelegateClassName": "NTSDiOS.NTSDSceneDelegate"}]}}},
                  (app / "Info.plist").open("wb"))
    run(["codesign", "--force", "--sign", "-", str(app)])
    devices = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "-j"]))["devices"]
    udid = next(d["udid"] for runtime in devices.values() for d in runtime if d["name"] == args.device)
    subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True)
    run(["xcrun", "simctl", "bootstatus", udid, "-b"])
    run(["xcrun", "simctl", "install", udid, str(app)])
    data = Path(run(["xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, "data"]))
    setup = app_e2e.SCENARIOS[args.scenario]
    work = data / "Documents" / args.scenario; shutil.rmtree(work, ignore_errors=True)
    for d in ("overlay", "captures", "frames"): (work / d).mkdir(parents=True)
    extra = setup["extra"](work) if callable(setup["extra"]) else list(setup["extra"])
    game = ["--events-file", str(work / "events.raw"), "--original", "--mute-music", "--mute-sounds", "--no-network", "--overlay", str(work / "overlay"),
            "--virtual-clock", "123456789", "8", "--script-clock", "gameplay", "--body-captures", str(work / "captures"),
            "--body-frames", str(work / "frames"), "--body-frame-digests", *extra, "--script", setup["script"](work / "captures")]
    done = subprocess.run(["xcrun", "simctl", "launch", "--console", "--terminate-running-process", udid, BUNDLE_ID, *game],
                          capture_output=True, text=True, timeout=3600, env={**os.environ, "SIMCTL_CHILD_TZ": "Etc/GMT-1"})
    result = out / args.scenario; shutil.rmtree(result, ignore_errors=True); shutil.copytree(work, result)
    raw = (work / "events.raw").read_text() if (work / "events.raw").exists() else done.stdout
    events = "\n".join(l for l in raw.replace("\r\n", "\n").splitlines() if l.startswith("{")) + "\n"
    (result / "events.jsonl").write_text(events); (result / "stderr.txt").write_text(done.stderr)
    compare = subprocess.run([sys.executable, str(ROOT / "tools/crossplatform/compare_headless.py"), str(result / "events.jsonl"),
                              str(result / "captures"), str(result / "overlay"), "0", str(setup["reference"]), f"{work}={result}"],
                             capture_output=True, text=True)
    (result / "compare.txt").write_text(compare.stdout + compare.stderr)
    print(compare.stdout.strip().splitlines()[-1] if compare.stdout.strip() else compare.stderr[-400:])


if __name__ == "__main__":
    main()
