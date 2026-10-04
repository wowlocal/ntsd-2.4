#!/usr/bin/env python3
"""Build NTSDiOS for a real iPad, sign it for development and install it
(P8). The app is the one ios_app.py wraps for the simulator, built for
arm64-apple-ios17.0 instead.

Usage: ios_device.py OUT_DIR --device UDID --profile PROFILE.mobileprovision --identity SHA1 [--launch]

Builds with SwiftPM (NTSD_PORTABLE=1 NTSD_IOS=1, scratch on X5), writes
OUT_DIR/NTSDiOS.app (executable, the Original* resource folders at the app
root, OriginalMusic, Info.plist, embedded.mobileprovision), signs it with the
given Apple Development identity and the profile's team, installs it with
`xcrun devicectl` and, with --launch, starts it. A launched app runs the
game normally (music and sound on, settings in the app's own folder).
"""
import argparse, os, plistlib, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
X5 = Path("/Volumes/X5/ntsd-2.4-research/crossplatform")
BUNDLE_ID = "local.ntsd.native.ios"


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout.strip()


def main():
    a = argparse.ArgumentParser(); a.add_argument("out", type=Path)
    a.add_argument("--device", required=True); a.add_argument("--profile", type=Path, required=True)
    a.add_argument("--identity", required=True); a.add_argument("--launch", action="store_true")
    args = a.parse_args(); out = args.out.resolve()
    profile = plistlib.loads(run(["security", "cms", "-D", "-i", str(args.profile)]).encode())
    team = profile["TeamIdentifier"][0]
    if args.device not in profile.get("ProvisionedDevices", []): sys.exit(f"the profile does not include {args.device}")
    sdk = run(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"])
    env = {**os.environ, "NTSD_PORTABLE": "1", "NTSD_IOS": "1"}
    common = ["xcrun", "--toolchain", "XcodeDefault", "swift", "build", "--package-path", str(ROOT / "native"),
              "--scratch-path", str(X5 / "build-ios-device"), "--triple", "arm64-apple-ios17.0", "--sdk", sdk,
              "-c", "release", "--product", "NTSDiOS"]
    subprocess.run(common, env=env, check=True)
    products = Path(run(common + ["--show-bin-path"], env=env))
    app = out / "NTSDiOS.app"; shutil.rmtree(app, ignore_errors=True); app.mkdir(parents=True)
    shutil.copy2(products / "NTSDiOS", app / "NTSDiOS")
    # Inside an .app the input loaders read their folders from the main bundle's resources.
    for folder in sorted((products / "NTSDNative_NTSDCore.bundle").iterdir()):
        if folder.is_dir() and folder.name.startswith("Original"):
            shutil.copytree(folder, app / folder.name)
    shutil.copytree(ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic", app / "OriginalMusic")
    plistlib.dump({"CFBundleIdentifier": BUNDLE_ID, "CFBundleExecutable": "NTSDiOS", "CFBundleName": "NTSD Native",
                   "CFBundleDisplayName": "NTSD", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1",
                   "CFBundleVersion": "1", "CFBundleSupportedPlatforms": ["iPhoneOS"], "MinimumOSVersion": "17.0",
                   "LSRequiresIPhoneOS": True, "UIDeviceFamily": [2], "UIRequiresFullScreen": True, "UILaunchScreen": {},
                   "UIRequiredDeviceCapabilities": ["arm64"],
                   "NSLocalNetworkUsageDescription": "ONLINE GAME connects to another player on the local network.",
                   "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
                   "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False, "UISceneConfigurations": {
                       "UIWindowSceneSessionRoleApplication": [{"UISceneConfigurationName": "Default",
                                                               "UISceneDelegateClassName": "NTSDiOS.NTSDSceneDelegate"}]}}},
                  (app / "Info.plist").open("wb"))
    shutil.copy2(args.profile, app / "embedded.mobileprovision")
    entitlements = out / "entitlements.plist"
    plistlib.dump({"application-identifier": f"{team}.{BUNDLE_ID}", "com.apple.developer.team-identifier": team,
                   "get-task-allow": True}, entitlements.open("wb"))
    run(["codesign", "--force", "--sign", args.identity, "--entitlements", str(entitlements), "--timestamp=none", str(app)])
    run(["codesign", "--verify", "--strict", str(app)])
    print(run(["xcrun", "devicectl", "device", "install", "app", "--device", args.device, str(app)]).splitlines()[-1])
    if args.launch:
        print(run(["xcrun", "devicectl", "device", "process", "launch", "--device", args.device, "--terminate-existing", BUNDLE_ID]).splitlines()[-1])


if __name__ == "__main__":
    main()
