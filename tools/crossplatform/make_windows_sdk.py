#!/usr/bin/env python3
"""Make and install the Swift SDK bundle ntsd-6.4.0-windows-x86_64.

Usage: make_windows_sdk.py [--x5 DIR]

Inputs on X5 (docs/research/CROSS_PLATFORM.md, P0-W): the Swift 6.4.0
Windows SDK extracted from swift-6.4.0-RELEASE-windows10.exe
(windows-sdk-extract/tree) and the xwin splat winsysroot-vs16 (MSVC
14.29.16.10, Windows SDK 10.0.22621, UCRT 10.0.26624; Microsoft's VS Build
Tools terms accepted by the user on 2026-10-03). The bundle contains:

- a copy of Windows.sdk with windows/ucrt-26624.modulemap.patch applied
  (UCRT 10.0.26624 has no stdalign.h, stdnoreturn.h or corecrt_math.h; math.h
  becomes corecrt.math, where the prebuilt Foundation module expects pow);
- usr/lib/swift/clang -> the toolchain's Clang builtin headers: without them
  SwiftPM's -resource-dir made Clang fall through to MSVC's iso646.h, which
  pulls C++-only yvals_core.h into C module builds;
- a toolset with the MSVC/SDK roots for Swift and C, and the SDK library
  folders for lld-link (swiftc passes none).

Build with: swift build --build-system native --swift-sdk ntsd-6.4.0-windows-x86_64
(the swift-build system has no Windows platform definition here).
"""
import argparse, json, os, shutil, subprocess
from pathlib import Path

NAME = "ntsd-6.4.0-windows-x86_64"
TOOLS = Path(__file__).resolve().parent
TOOLCHAIN = Path.home() / "Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr"


def main():
    a = argparse.ArgumentParser(); a.add_argument("--x5", type=Path, default=Path("/Volumes/X5/ntsd-2.4-research/crossplatform"))
    x = a.parse_args().x5
    source = x / "windows-sdk-extract/tree/LocalApp/Programs/Swift/Platforms/6.4.0/Windows.platform/Developer/SDKs/Windows.sdk"
    msvc = x / "winsysroot-vs16/VC/Tools/MSVC/14.29.16.10"; kits = x / "winsysroot-vs16/Windows Kits/10"; sdkv = "10.0.22621"
    bundle = x / "swift-sdks" / f"{NAME}.artifactbundle"; variant = bundle / NAME
    shutil.rmtree(bundle, ignore_errors=True); variant.mkdir(parents=True)
    shutil.copytree(source, variant / "Windows.sdk", symlinks=True)
    subprocess.run(["patch", "-p1", "--quiet", "-i", str(TOOLS / "windows/ucrt-26624.modulemap.patch")], cwd=variant, check=True)
    os.symlink((TOOLCHAIN / "lib/clang/21").resolve(), variant / "Windows.sdk/usr/lib/swift/clang")
    (bundle / "info.json").write_text(json.dumps({"schemaVersion": "1.0", "artifacts": {NAME: {"type": "swiftSDK", "version": "0.1",
        "variants": [{"path": NAME}]}}}, indent=2) + "\n")
    (variant / "swift-sdk.json").write_text(json.dumps({"schemaVersion": "4.0", "targetTriples": {"x86_64-unknown-windows-msvc": {
        "sdkRootPath": "Windows.sdk", "swiftResourcesPath": "Windows.sdk/usr/lib/swift",
        "swiftStaticResourcesPath": "Windows.sdk/usr/lib/swift_static", "toolsetPaths": ["toolset.json"]}}}, indent=2) + "\n")
    libs = [kits / f"Lib/{sdkv}/um/x86_64", kits / f"Lib/{sdkv}/ucrt/x86_64", msvc / "lib/x86_64"]
    swift = ["-visualc-tools-root", str(msvc), "-windows-sdk-root", str(kits), "-windows-sdk-version", sdkv, "-use-ld=lld"]
    for lib in libs: swift += ["-Xlinker", f"-libpath:{lib}"]
    c = ["-Xmicrosoft-visualc-tools-root", str(msvc), "-Xmicrosoft-windows-sdk-root", str(kits), "-Xmicrosoft-windows-sdk-version", sdkv]
    (variant / "toolset.json").write_text(json.dumps({"schemaVersion": "1.0", "swiftCompiler": {"extraCLIOptions": swift},
        "cCompiler": {"extraCLIOptions": c}, "cxxCompiler": {"extraCLIOptions": c},
        "linker": {"extraCLIOptions": [f"-libpath:{lib}" for lib in libs]}}, indent=2) + "\n")
    swift_bin = str(TOOLCHAIN / "bin/swift")
    subprocess.run([swift_bin, "sdk", "remove", NAME], capture_output=True)
    subprocess.run([swift_bin, "sdk", "install", str(bundle)], check=True)
    print(bundle)


if __name__ == "__main__":
    main()
