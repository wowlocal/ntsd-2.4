#!/usr/bin/env python3
"""Build NTSDiOS for the iPad or Apple TV simulator, wrap it into an app and
run an app_e2e scenario in the simulator (P8, TVOS_WEB T0; test harness: the
simulator, not a device).

Usage: ios_app.py OUT_DIR [SCENARIO] [--platform ios|tvos] [--device NAME]

Builds with SwiftPM for arm64-apple-ios17.0-simulator, or with --platform tvos
arm64-apple-tvos17.0-simulator (NTSD_PORTABLE=1
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
# NTSD_SIM_SET=DIR keeps the simulator in a device set at DIR (ENGINE_SPLIT: off the
# internal disk), created there on first use; unset, the default device set.
SIM_SET = os.environ.get("NTSD_SIM_SET") and str(Path(os.environ["NTSD_SIM_SET"]).resolve())
SIMCTL = ["xcrun", "simctl"] + (["--set", SIM_SET] if SIM_SET else [])
# Per platform: target, SDK, default simulator, bundle identifier and the
# platform's Info.plist keys.
PLATFORMS = {
    "ios": {"triple": "arm64-apple-ios17.0-simulator", "sdk": "iphonesimulator", "scratch": "build-ios-sim",
            "device": "iPad Air 13-inch (M4)", "runtime": ".iOS-", "bundle": "local.ntsd.native.ios",
            "plist": {"CFBundleSupportedPlatforms": ["iPhoneSimulator"], "LSRequiresIPhoneOS": True, "UIDeviceFamily": [2],
                      "UIRequiresFullScreen": True,
                      "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]}},
    "tvos": {"triple": "arm64-apple-tvos17.0-simulator", "sdk": "appletvsimulator", "scratch": "build-tvos-sim",
             "device": "Apple TV 4K (3rd generation) (at 1080p)", "runtime": ".tvOS-", "bundle": "local.ntsd.native.tvos",
             "plist": {"CFBundleSupportedPlatforms": ["AppleTVSimulator"], "UIDeviceFamily": [3],
                       "UIRequiredDeviceCapabilities": ["arm64"],
                       # Gamepads (the game's joysticks) and the Siri Remote (TVOS_WEB T1b):
                       # the second-generation remote as a directional gamepad, with its ring.
                       "GCSupportedGameControllers": [{"ProfileName": "ExtendedGamepad"}, {"ProfileName": "DirectionalGamepad"},
                                                      {"ProfileName": "MicroGamepad"}],
                       "GCSupportsMultipleMicroGamepads": True, "GCSupportsControllerUserInteraction": True}},
}


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout.strip()


def main():
    a = argparse.ArgumentParser(); a.add_argument("out", type=Path); a.add_argument("scenario", nargs="?", default="vs")
    a.add_argument("--platform", choices=sorted(PLATFORMS), default="ios")
    a.add_argument("--device"); a.add_argument("--scratch", type=Path)
    args = a.parse_args(); out = args.out.resolve(); p = PLATFORMS[args.platform]
    args.device = args.device or p["device"]; args.scratch = args.scratch or Path(os.environ.get("NTSD_XPLAT_OUT", X5)) / p["scratch"]
    sdk = run(["xcrun", "--sdk", p["sdk"], "--show-sdk-path"])
    # The shipping build drops Swift's dynamic exclusivity checks (the user's decision, CORE_REALTIME 4aa).
    env = {**os.environ, "NTSD_PORTABLE": "1", "NTSD_IOS": "1", "NTSD_UNCHECKED_EXCLUSIVITY": "1"}
    common = ["xcrun", "--toolchain", "XcodeDefault", "swift", "build", "--package-path", str(ROOT / "native"),
              "--scratch-path", str(args.scratch), "--triple", p["triple"], "--sdk", sdk,
              "-c", "release", "--product", "NTSDiOS"]
    subprocess.run(common, env=env, check=True)
    products = Path(run(common + ["--show-bin-path"], env=env))
    app = out / "NTSDiOS.app"; shutil.rmtree(app, ignore_errors=True); app.mkdir(parents=True)
    shutil.copy2(products / "NTSDiOS", app / "NTSDiOS")
    # Inside an .app the input loaders read their folders from the main
    # bundle's resources (as the macOS packaging installs them), not .module.
    for folder in sorted((products / "NTSDNative_NTSDContent.bundle").iterdir()):
        if folder.is_dir() and folder.name.startswith("Original"):
            shutil.copytree(folder, app / folder.name)
    shutil.copytree(ROOT / "native/Sources/NTSDContent/Resources/OriginalMusic", app / "OriginalMusic")
    plistlib.dump({"CFBundleIdentifier": p["bundle"], "CFBundleExecutable": "NTSDiOS", "CFBundleName": "NTSD Native",
                   "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1", "CFBundleVersion": "1",
                   "MinimumOSVersion": "17.0", "UILaunchScreen": {}, **p["plist"],
                   "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False, "UISceneConfigurations": {
                       "UIWindowSceneSessionRoleApplication": [{"UISceneConfigurationName": "Default",
                                                               "UISceneDelegateClassName": "NTSDiOS.NTSDSceneDelegate"}]}}},
                  (app / "Info.plist").open("wb"))
    run(["codesign", "--force", "--sign", "-", str(app)])
    if SIM_SET: Path(SIM_SET).mkdir(parents=True, exist_ok=True)
    devices = json.loads(run([*SIMCTL, "list", "devices", "available", "-j"]))["devices"]
    udid = next((d["udid"] for runtime, listed in devices.items() if p["runtime"] in runtime for d in listed if d["name"] == args.device), None)
    if udid is None and SIM_SET:   # a new set: the device from the installed type and newest runtime
        kinds = json.loads(run(["xcrun", "simctl", "list", "devicetypes", "-j"]))["devicetypes"]
        runtimes = json.loads(run(["xcrun", "simctl", "list", "runtimes", "available", "-j"]))["runtimes"]
        kind = next((k["identifier"] for k in kinds if k["name"] == args.device), None)
        runtime = max((r for r in runtimes if p["runtime"] in r["identifier"]
                       and any(t.get("identifier") == kind for t in r.get("supportedDeviceTypes", []))), key=lambda r: [int(x) for x in r["version"].split(".")], default=None)
        if kind and runtime: udid = run([*SIMCTL, "create", args.device, kind, runtime["identifier"]])
    if udid is None:
        sys.exit(f"no available {args.platform} simulator named {args.device!r} (is its runtime installed? xcrun simctl list devices)")
    subprocess.run([*SIMCTL, "boot", udid], capture_output=True)
    run([*SIMCTL, "bootstatus", udid, "-b"])
    run([*SIMCTL, "install", udid, str(app)])
    data = Path(run([*SIMCTL, "get_app_container", udid, p["bundle"], "data"]))
    setup = app_e2e.SCENARIOS[args.scenario]
    work = data / "Documents" / args.scenario; shutil.rmtree(work, ignore_errors=True)
    for d in ("overlay", "captures", "frames"): (work / d).mkdir(parents=True)
    extra = setup["extra"](work) if callable(setup["extra"]) else list(setup["extra"])
    game = ["--events-file", str(work / "events.raw"), "--original", "--mute-music", "--mute-sounds", "--no-network", "--overlay", str(work / "overlay"),
            "--virtual-clock", "123456789", "8", "--script-clock", "gameplay", "--body-captures", str(work / "captures"),
            "--body-frames", str(work / "frames"), "--body-frame-digests", *extra, "--script", setup["script"](work / "captures")]
    done = subprocess.run([*SIMCTL, "launch", "--console", "--terminate-running-process", udid, p["bundle"], *game],
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
