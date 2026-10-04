#!/usr/bin/env python3
"""Build the Android app (NTSDAndroid in a NativeActivity), install it on the
device adb reaches and optionally run an app_e2e scenario through it (P8;
the emulator is a test harness, not a device observation).

Usage: android_app.py OUT_DIR [--scenario NAME] [--skip-build] [--no-install]

Builds libNTSDAndroid.so with SwiftPM (NTSD_PORTABLE=1 NTSD_ANDROID=1,
aarch64-unknown-linux-android28, static Swift runtime, NDK r30), stages the
game data (the resource bundle) and the packaged music as APK assets under
assets/ntsd with a file list, links the manifest with aapt2 (no Java code,
debuggable so `run-as` reaches the app's files), adds lib/arm64-v8a
(libNTSDAndroid.so, NDK r30's libc++_shared.so), aligns and signs it with a
local debug key and installs OUT_DIR/ntsd.apk.

--scenario writes the scenario's session options to the app's files/args.txt
(paths inside the app's files folder), starts the activity, waits for the
process to exit, pulls the results into OUT_DIR/<scenario>, removes args.txt
and compares them with the scenario's frozen reference.
"""
import argparse, importlib.util, json, os, shutil, subprocess, sys, tarfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("app_e2e", ROOT / "tools/app_e2e.py")
app_e2e = importlib.util.module_from_spec(spec); spec.loader.exec_module(app_e2e)
X5 = Path("/Volumes/X5/ntsd-2.4-research/crossplatform")
SDK = Path("/opt/homebrew/share/android-commandlinetools")
NDK = SDK / "ndk/30.0.16248370"
TOOLS = SDK / "build-tools/36.1.0"
ADB = str(SDK / "platform-tools/adb")
SWIFT = Path.home() / "Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift"
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
PACKAGE = "local.ntsd.port"
FILES = f"/data/user/0/{PACKAGE}/files"
MANIFEST = f"""<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{PACKAGE}">
  <uses-permission android:name="android.permission.INTERNET"/>
  <application android:label="NTSD" android:hasCode="false" android:extractNativeLibs="true"
      android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
    <activity android:name="android.app.NativeActivity" android:exported="true" android:launchMode="singleTask"
        android:screenOrientation="sensorLandscape"
        android:configChanges="orientation|keyboardHidden|keyboard|screenSize|screenLayout|smallestScreenSize|uiMode|navigation|density">
      <meta-data android:name="android.app.lib_name" android:value="NTSDAndroid"/>
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
"""


def run(cmd, **kw):
    return subprocess.run([str(c) for c in cmd], check=True, capture_output=True, text=True, **kw).stdout.strip()


def build(out):
    env = {**os.environ, "NTSD_PORTABLE": "1", "NTSD_ANDROID": "1", "ANDROID_HOME": str(SDK), "ANDROID_NDK_ROOT": str(NDK)}
    common = [SWIFT, "build", "--package-path", ROOT / "native", "--scratch-path", X5 / "build-android-aarch64",
              "--swift-sdk", "aarch64-unknown-linux-android28", "-c", "release", "--static-swift-stdlib", "--product", "NTSDAndroid"]
    subprocess.run([str(c) for c in common], env=env, check=True)
    products = X5 / "build-android-aarch64/out/Products/Release-android-aarch64"
    stage = out / "stage"; shutil.rmtree(stage, ignore_errors=True)
    libs = stage / "lib/arm64-v8a"; libs.mkdir(parents=True)
    shutil.copy2(products / "libNTSDAndroid.so", libs / "libNTSDAndroid.so")
    shutil.copy2(NDK / "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so", libs / "libc++_shared.so")
    assets = stage / "assets/ntsd"; assets.mkdir(parents=True)
    shutil.copytree(products / "NTSDNative_NTSDCore.bundle", assets / "NTSDNative_NTSDCore.bundle")
    shutil.copytree(MUSIC, assets / "OriginalMusic")
    listing = sorted(p for p in assets.rglob("*") if p.is_file())
    (assets / "files.txt").write_text("".join(f"{p.relative_to(assets)}\t{p.stat().st_size}\n" for p in listing))
    (stage / "AndroidManifest.xml").write_text(MANIFEST)
    unaligned, aligned, apk = out / "unaligned.apk", out / "aligned.apk", out / "ntsd.apk"
    for p in (unaligned, aligned, apk): p.unlink(missing_ok=True)
    run([TOOLS / "aapt2", "link", "-o", unaligned, "--manifest", stage / "AndroidManifest.xml", "-I", SDK / "platforms/android-35/android.jar",
         "-A", stage / "assets", "--min-sdk-version", "28", "--target-sdk-version", "35", "--version-code", "1", "--version-name", "0.1",
         "--debug-mode"])
    run(["zip", "-q", "-r", unaligned, "lib"], cwd=stage)
    run([TOOLS / "zipalign", "-p", "-f", "4", unaligned, aligned])
    key = X5 / "android-debug.keystore"   # local debug key only
    if not key.exists():
        run(["keytool", "-genkeypair", "-keystore", key, "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey",
             "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", "CN=Android Debug,O=Android,C=US"])
    run([TOOLS / "apksigner", "sign", "--ks", key, "--ks-pass", "pass:android", "--out", apk, aligned])
    run([TOOLS / "apksigner", "verify", apk])
    unaligned.unlink(); aligned.unlink()
    return apk


def scenario(out, name):
    setup = app_e2e.SCENARIOS[name]
    base = out / name; shutil.rmtree(base, ignore_errors=True)
    for d in ("captures", "overlay", "frames"): (base / d).mkdir(parents=True)
    inner = Path(FILES) / name
    extra = setup["extra"](base) if callable(setup["extra"]) else list(setup["extra"])
    extra = [str(inner / Path(a).relative_to(base)) if a.startswith(str(base)) else a for a in extra]
    args = ["--events-file", str(inner / "events.jsonl"), "--tz", "Etc/GMT-1", "--original", "--mute-music", "--mute-sounds", "--no-network",
            "--overlay", str(inner / "overlay"), "--virtual-clock", "123456789", "8", "--script-clock", "gameplay",
            "--body-captures", str(inner / "captures"), "--body-frames", str(inner / "frames"), "--body-frame-digests",
            *extra, "--script", setup["script"](inner / "captures")]
    assert not any("\n" in a for a in args), "args.txt holds one argument per line"
    packed = out / f"{name}-in.tar"
    with tarfile.open(packed, "w") as t: t.add(base, arcname=name)
    run([ADB, "shell", "am", "force-stop", PACKAGE])
    run([ADB, "shell", f"run-as {PACKAGE} sh -c 'mkdir -p files && rm -rf files/{name} files/args.txt && tar -C files -xf -'"], input=None, stdin=packed.open("rb"))
    subprocess.run([ADB, "shell", f"run-as {PACKAGE} sh -c 'cat > files/args.txt'"], input="\n".join(args) + "\n", text=True, check=True)
    start = time.time()
    run([ADB, "shell", "am", "start", "-n", f"{PACKAGE}/android.app.NativeActivity"])
    time.sleep(3)
    while subprocess.run([ADB, "shell", "pidof", PACKAGE], capture_output=True, text=True).stdout.strip():
        if time.time() - start > 3600: raise TimeoutError(name)
        time.sleep(2)
    raw = subprocess.run([ADB, "exec-out", f"run-as {PACKAGE} tar -C files -cf - {name}"], capture_output=True, check=True).stdout
    subprocess.run([ADB, "shell", f"run-as {PACKAGE} rm -f files/args.txt"], check=True)
    shutil.rmtree(base); (out / f"{name}-out.tar").write_bytes(raw)
    with tarfile.open(out / f"{name}-out.tar") as t: t.extractall(out)
    compare = subprocess.run([sys.executable, str(ROOT / "tools/crossplatform/compare_headless.py"), str(base / "events.jsonl"),
                              str(base / "captures"), str(base / "overlay"), "0", str(setup["reference"]), f"{inner}={base}"],
                             capture_output=True, text=True)
    (base / "compare.txt").write_text(compare.stdout + compare.stderr)
    verdict = json.loads(compare.stdout.strip().splitlines()[-1]) if compare.stdout.strip() else {"result": "error", "differs": [compare.stderr[-300:]]}
    row = {"scenario": name, "seconds": round(time.time() - start, 1), **verdict}
    print(json.dumps(row), flush=True)
    return row


def main():
    a = argparse.ArgumentParser(); a.add_argument("out", type=Path); a.add_argument("--scenario", action="append", default=[])
    a.add_argument("--skip-build", action="store_true"); a.add_argument("--no-install", action="store_true")
    args = a.parse_args(); out = args.out.resolve(); out.mkdir(parents=True, exist_ok=True)
    apk = out / "ntsd.apk" if args.skip_build else build(out)
    print(apk, apk.stat().st_size, flush=True)
    if not args.no_install: print(run([ADB, "install", "-r", apk]).splitlines()[-1], flush=True)
    rows = [scenario(out, name) for name in (list(app_e2e.SCENARIOS) if args.scenario == ["all"] else args.scenario)]
    if rows: (out / "results.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))


if __name__ == "__main__":
    main()
