#!/bin/bash
# Builds the libraries the Android host links against, with the Android SDK's
# CMake and Ninja and NDK r30 (the Swift 6.4.0 Android runtime needs its libc++).
#   tools/crossplatform/build_android_deps.sh OUT_DIR
# OUT_DIR/freetype/install-aarch64: FreeType 2.13.3, static, no optional deps
# (the same tarball and options as build_linux_deps.sh), for
# aarch64-linux-android28. The source is checked against its SHA-256 first.
set -euo pipefail
OUT=$(cd "$1" && pwd)
SDK=/opt/homebrew/share/android-commandlinetools; NDK=$SDK/ndk/30.0.16248370; BIN=$SDK/cmake/4.1.2/bin
FT_SHA=0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289
mkdir -p "$OUT/freetype"; cd "$OUT/freetype"
[ -f freetype-2.13.3.tar.xz ] || curl -sSLO https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz
echo "$FT_SHA  freetype-2.13.3.tar.xz" | shasum -a 256 -c -
rm -rf src build-aarch64 install-aarch64; mkdir src; tar -xJf freetype-2.13.3.tar.xz -C src --strip-components=1
"$BIN/cmake" -S src -B build-aarch64 -G Ninja -DCMAKE_MAKE_PROGRAM="$BIN/ninja" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28 \
  -DCMAKE_INSTALL_PREFIX="$OUT/freetype/install-aarch64" \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DFT_DISABLE_ZLIB=TRUE -DFT_DISABLE_BZIP2=TRUE \
  -DFT_DISABLE_PNG=TRUE -DFT_DISABLE_HARFBUZZ=TRUE -DFT_DISABLE_BROTLI=TRUE > cmake-aarch64.log
"$BIN/ninja" -C build-aarch64 install > build-aarch64.log
echo "built FreeType for aarch64-linux-android28"
