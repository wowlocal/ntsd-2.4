#!/bin/bash
# Builds the Linux libraries NTSDSDL links against, inside swift:6.4.0-noble
# (Ubuntu 24.04 has no SDL3 package), for the container's architecture.
#   tools/crossplatform/build_linux_deps.sh OUT_DIR [linux/arm64|linux/amd64]
# OUT_DIR/sdl3/install-<arch>:     SDL3 3.4.16, shared, with X11, Wayland,
#                                  PulseAudio, PipeWire, ALSA, offscreen and
#                                  dummy drivers (desktop backends load at run time).
# OUT_DIR/freetype/install-<arch>: FreeType 2.13.3, static, no optional deps.
# Sources are checked against these SHA-256 values before building.
set -euo pipefail
OUT=$(cd "$1" && pwd); PLATFORM=${2:-linux/arm64}
SDL_SHA=7322236cd12090c3eb40b9728be4d49c76f66ad17d04369584d4ecad5cf77c68
FT_SHA=0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289
mkdir -p "$OUT/sdl3" "$OUT/freetype"
docker run --rm --platform "$PLATFORM" -v "$OUT:/w" -e SDL_SHA=$SDL_SHA -e FT_SHA=$FT_SHA swift:6.4.0-noble bash -c '
set -euo pipefail; export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
apt-get install -y -qq cmake ninja-build pkg-config curl xz-utils libx11-dev libxext-dev libxrandr-dev libxcursor-dev \
  libxi-dev libxss-dev libxfixes-dev libxtst-dev libxkbcommon-dev libwayland-dev wayland-protocols libdecor-0-dev \
  libegl-dev libgl-dev libgles-dev libdrm-dev libgbm-dev libasound2-dev libpulse-dev libpipewire-0.3-dev libudev-dev \
  libdbus-1-dev >/dev/null 2>&1
arch=$(uname -m)
cd /w/sdl3
[ -f SDL3-3.4.16.tar.gz ] || curl -sSLO https://github.com/libsdl-org/SDL/releases/download/release-3.4.16/SDL3-3.4.16.tar.gz
echo "$SDL_SHA  SDL3-3.4.16.tar.gz" | sha256sum -c -
rm -rf src build-$arch install-$arch; mkdir src; tar -xzf SDL3-3.4.16.tar.gz -C src --strip-components=1
cmake -S src -B build-$arch -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/w/sdl3/install-$arch \
  -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_STATIC=OFF > cmake-$arch.log
ninja -C build-$arch install > build-$arch.log
cd /w/freetype
[ -f freetype-2.13.3.tar.xz ] || curl -sSLO https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz
echo "$FT_SHA  freetype-2.13.3.tar.xz" | sha256sum -c -
rm -rf src build-$arch install-$arch; mkdir src; tar -xJf freetype-2.13.3.tar.xz -C src --strip-components=1
cmake -S src -B build-$arch -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/w/freetype/install-$arch \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DFT_DISABLE_ZLIB=TRUE -DFT_DISABLE_BZIP2=TRUE \
  -DFT_DISABLE_PNG=TRUE -DFT_DISABLE_HARFBUZZ=TRUE -DFT_DISABLE_BROTLI=TRUE > cmake-$arch.log
ninja -C build-$arch install > build-$arch.log
echo "built for $arch"'
