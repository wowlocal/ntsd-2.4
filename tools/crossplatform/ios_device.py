#!/usr/bin/env python3
"""Build NTSDiOS for a real iPad (or, with --iphone, the separate iPhone
app), sign it for development and install it (P8). The app is the one ios_app.py wraps for the simulator, built for
arm64-apple-ios17.0 instead.

Usage: ios_device.py OUT_DIR --device UDID --profile PROFILE.mobileprovision --identity SHA1
                     [--iphone] [--ipa PATH] [--no-install | --launch]

--iphone makes the separate iPhone app (PHONE_CONTROLLER C1): bundle
local.ntsd.native.iphone, iPhone only, landscape only; the profile must
cover that bundle identifier.

Builds with SwiftPM (NTSD_PORTABLE=1 NTSD_IOS=1, scratch on X5), writes
OUT_DIR/NTSDiOS.app (executable, the Original* resource folders at the app
root, OriginalMusic, Info.plist, embedded.mobileprovision), signs it with the
given Apple Development identity and the profile's team, installs it with
`xcrun devicectl` (unless --no-install) and, with --launch, starts it.
--ipa also writes the signed app as an IPA, which any Mac can install. A launched app runs the
game normally (music and sound on, settings in the app's own folder).
"""
import argparse, os, plistlib, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
X5 = Path("/Volumes/X5/ntsd-2.4-research/crossplatform")
BUNDLE_ID = "local.ntsd.native.ios"
IPHONE_BUNDLE_ID = "local.ntsd.native.iphone"


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout.strip()


def main():
    a = argparse.ArgumentParser(); a.add_argument("out", type=Path)
    a.add_argument("--device", required=True); a.add_argument("--profile", type=Path, required=True)
    a.add_argument("--identity", required=True); a.add_argument("--launch", action="store_true")
    a.add_argument("--no-install", action="store_true"); a.add_argument("--ipa", type=Path)
    a.add_argument("--iphone", action="store_true")
    args = a.parse_args(); out = args.out.resolve()
    bundle = IPHONE_BUNDLE_ID if args.iphone else BUNDLE_ID
    family = {"UIDeviceFamily": [1], "UIStatusBarHidden": True,
              "UISupportedInterfaceOrientations": ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]} if args.iphone \
        else {"UIDeviceFamily": [2], "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]}
    profile = plistlib.loads(run(["security", "cms", "-D", "-i", str(args.profile)]).encode())
    team = profile["TeamIdentifier"][0]
    if args.device not in profile.get("ProvisionedDevices", []): sys.exit(f"the profile does not include {args.device}")
    app_id = profile.get("Entitlements", {}).get("application-identifier", "")
    if app_id not in (f"{team}.{bundle}", f"{team}.*"): sys.exit(f"the profile is for {app_id!r}, not {team}.{bundle}")
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
    plistlib.dump({"CFBundleIdentifier": bundle, "CFBundleExecutable": "NTSDiOS", "CFBundleName": "NTSD Native",
                   "CFBundleDisplayName": "NTSD", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1",
                   "CFBundleVersion": "1", "CFBundleSupportedPlatforms": ["iPhoneOS"], "MinimumOSVersion": "17.0",
                   "LSRequiresIPhoneOS": True, **family, "UIRequiresFullScreen": True, "UILaunchScreen": {},
                   "UIRequiredDeviceCapabilities": ["arm64"],
                   "NSLocalNetworkUsageDescription": "ONLINE GAME connects to another player on the local network.",
                   "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False, "UISceneConfigurations": {
                       "UIWindowSceneSessionRoleApplication": [{"UISceneConfigurationName": "Default",
                                                               "UISceneDelegateClassName": "NTSDiOS.NTSDSceneDelegate"}]}}},
                  (app / "Info.plist").open("wb"))
    shutil.copy2(args.profile, app / "embedded.mobileprovision")
    entitlements = out / "entitlements.plist"
    plistlib.dump({"application-identifier": f"{team}.{bundle}", "com.apple.developer.team-identifier": team,
                   "get-task-allow": True}, entitlements.open("wb"))
    run(["codesign", "--force", "--sign", args.identity, "--entitlements", str(entitlements), "--timestamp=none", str(app)])
    run(["codesign", "--verify", "--strict", str(app)])
    if args.ipa:
        stage = out / "ipa"; shutil.rmtree(stage, ignore_errors=True); (stage / "Payload").mkdir(parents=True)
        run(["ditto", str(app), str(stage / "Payload/NTSDiOS.app")])
        args.ipa.unlink(missing_ok=True)
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", "Payload", str(args.ipa.resolve())], cwd=stage)
        shutil.rmtree(stage); print(args.ipa)
    if args.no_install: return
    print(run(["xcrun", "devicectl", "device", "install", "app", "--device", args.device, str(app)]).splitlines()[-1])
    if args.launch:
        print(run(["xcrun", "devicectl", "device", "process", "launch", "--device", args.device, "--terminate-existing", bundle]).splitlines()[-1])


if __name__ == "__main__":
    main()
