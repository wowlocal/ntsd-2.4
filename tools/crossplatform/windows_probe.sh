#!/bin/bash
# Cross-compiles tools/crossplatform/windows/probe.swift for x86_64 Windows on
# this Mac with the open-source Swift 6.4.0 toolchain, and runs it in a
# dedicated CrossOver bottle (test harness only; actual Windows stays open).
#   tools/crossplatform/windows_probe.sh WORK_DIR
# Inputs on X5 (docs/research/CROSS_PLATFORM.md, P0-W):
#  - windows-sdk-extract/tree: the Swift 6.4.0 Windows SDK and runtime DLLs from
#    swift-6.4.0-RELEASE-windows10.exe (7zz + msiextract);
#  - winsysroot-vs16: `xwin --accept-license --manifest-version 16
#    --arch x86_64,aarch64 splat --use-winsysroot-style` (MSVC 14.29.16.10,
#    Windows SDK 10.0.22621, UCRT 10.0.26624); the user accepted Microsoft's
#    VS Build Tools terms for these downloads on 2026-10-03.
# Swift 6.4's ucrt.modulemap names stdalign.h, stdnoreturn.h and corecrt_math.h,
# which UCRT 10.0.26624 does not have (math.h carries the math declarations);
# windows/ucrt-26624.modulemap.patch removes those three modules in a copy of
# the SDK. MSVC 14.44 headers do not build as modules here (threads.h needs
# UCRT macros), so the 14.29 toolset is used. swiftc passes no SDK library
# directories to lld-link, so they are given explicitly.
set -euo pipefail
WORK=$1; X=/Volumes/X5/ntsd-2.4-research/crossplatform; TOOLS=$(cd "$(dirname "$0")" && pwd)
SWIFTC=~/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swiftc
SRC_SDK=$X/windows-sdk-extract/tree/LocalApp/Programs/Swift/Platforms/6.4.0/Windows.platform/Developer/SDKs/Windows.sdk
ROOT=$X/winsysroot-vs16; MSVC=$ROOT/VC/Tools/MSVC/14.29.16.10; KITS="$ROOT/Windows Kits/10"; SDKV=10.0.22621
mkdir -p "$WORK"; WORK=$(cd "$WORK" && pwd)
rm -rf "${WORK:?}/Windows.sdk"; cp -R "$SRC_SDK" "$WORK/Windows.sdk"
(cd "$WORK" && patch -p1 --quiet < "$TOOLS/windows/ucrt-26624.modulemap.patch")
"$SWIFTC" -target x86_64-unknown-windows-msvc -sdk "$WORK/Windows.sdk" -visualc-tools-root "$MSVC" \
    -windows-sdk-root "$KITS" -windows-sdk-version $SDKV -use-ld=lld \
    -Xlinker "-libpath:$KITS/Lib/$SDKV/um/x86_64" -Xlinker "-libpath:$KITS/Lib/$SDKV/ucrt/x86_64" -Xlinker "-libpath:$MSVC/lib/x86_64" \
    "$TOOLS/windows/probe.swift" -o "$WORK/probe.exe"
cp "$X"/windows-sdk-extract/tree/*.dll "$WORK/"
CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
"$CX/cxbottle" --bottle ntsd-xplat-test --status >/dev/null 2>&1 || "$CX/cxbottle" --create --bottle ntsd-xplat-test --template win10_64
"$CX/wine" --bottle ntsd-xplat-test --wait-children "Z:$(echo "$WORK" | tr '/' '\\')\\probe.exe" > "$WORK/probe.out" 2> "$WORK/probe.err"
cat "$WORK/probe.out"
