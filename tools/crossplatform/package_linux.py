#!/usr/bin/env python3
"""Build the Linux SDL package of the native port (glibc, aarch64 or x86_64).

Usage: package_linux.py OUT_DIR [--arch aarch64|x86_64] [--deps DIR] [--scratch DIR]

Cross-builds NTSDSDL on this Mac (open-source Swift 6.4.0, generated glibc
SDK ntsd-6.4.0-ubuntu24.04-<arch>, --static-swift-stdlib) against the SDL3
and FreeType of build_linux_deps.sh, then assembles:

  ntsd-linux-<arch>/NTSDSDL                    the game (RUNPATH $ORIGIN)
  ntsd-linux-<arch>/libSDL3.so.0               SDL3 3.4.16
  ntsd-linux-<arch>/NTSDNative_NTSDCore.bundle resources
  ntsd-linux-<arch>/OriginalMusic              packaged tracks + manifest
  ntsd-linux-<arch>/LICENSES                   SDL3, FreeType, ALAC, Swift, ICU
  ntsd-linux-<arch>/README.txt

and a reproducible tar.gz (sorted entries, owner 0, mtime of HEAD's commit)
with manifest.json (per-file SHA-256) and the archive's SHA-256. Needs glibc
2.39 (Ubuntu 24.04 or newer), libstdc++, and X11 or Wayland, fonts and audio
as on a desktop. Local artefact only: publishing it is a separate decision.
"""
import argparse, gzip, hashlib, io, json, os, shutil, subprocess, tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT = Path.home() / "Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift"
X5 = Path("/Volumes/X5/ntsd-2.4-research/crossplatform")
README = """NTSD native port for Linux ({arch}, SDL3)

Run:   ./NTSDSDL
Data:  settings and replays go to ~/.local/share/NTSD Native/ (SDL_GetPrefPath).
Needs: glibc 2.39+ (Ubuntu 24.04 or newer), libstdc++, an X11 or Wayland
       session, audio (PulseAudio, PipeWire or ALSA) and fonts. Text uses the
       closest standard font to the macOS port's (DejaVu Sans Condensed Bold,
       Liberation Sans Bold, ...; NTSD_FONT=/path/font.ttf overrides): the
       original's GDI SYSTEM_FONT ships with Windows, not the game.
Build: {commit}
"""


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    a = argparse.ArgumentParser(); a.add_argument("out", type=Path)
    a.add_argument("--arch", choices=["aarch64", "x86_64"], default="aarch64")
    a.add_argument("--deps", type=Path, default=X5 / "linux-deps"); a.add_argument("--scratch", type=Path)
    args = a.parse_args(); arch = args.arch
    args.scratch = args.scratch or X5 / f"build-linux-glibc-static-{arch}"
    sdl, ft = args.deps / "sdl3", args.deps / "freetype"
    env = {**os.environ, "NTSD_PORTABLE": "1", "NTSD_SDL": "1", "NTSD_SDL_PREFIX": str(sdl / f"install-{arch}"),
           "NTSD_FREETYPE_PREFIX": str(ft / f"install-{arch}")}
    common = ["--package-path", str(ROOT / "native"), "--scratch-path", str(args.scratch), "--swift-sdk", f"ntsd-6.4.0-ubuntu24.04-{arch}",
              "-c", "release", "--static-swift-stdlib", "--product", "NTSDSDL"]
    subprocess.run([str(SWIFT), "build", *common], env=env, check=True)
    products = Path(subprocess.run([str(SWIFT), "build", *common, "--show-bin-path"], env=env, check=True, capture_output=True, text=True).stdout.strip())
    commit = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
    epoch = int(subprocess.run(["git", "-C", str(ROOT), "log", "-1", "--format=%ct"], check=True, capture_output=True, text=True).stdout)
    dirty = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain", "native"], check=True, capture_output=True, text=True).stdout.strip() != ""

    name = f"ntsd-linux-{arch}"; stage = args.out / name
    shutil.rmtree(args.out, ignore_errors=True); stage.mkdir(parents=True)
    shutil.copy2(products / "NTSDSDL", stage / "NTSDSDL")
    shutil.copy2(sdl / f"install-{arch}/lib/libSDL3.so.0.4.16", stage / "libSDL3.so.0")
    shutil.copytree(products / "NTSDNative_NTSDCore.bundle", stage / "NTSDNative_NTSDCore.bundle")
    shutil.copytree(ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic", stage / "OriginalMusic")
    lic = stage / "LICENSES"; lic.mkdir()
    shutil.copy2(sdl / "src/LICENSE.txt", lic / "SDL3-zlib.txt")
    shutil.copy2(ft / "src/docs/FTL.TXT", lic / "FreeType-FTL.txt")
    shutil.copy2(ROOT / "native/Sources/CALAC/vendor/LICENSE", lic / "ALAC-Apache-2.0.txt")
    shutil.copy2(SWIFT.parent.parent / "share/swift/LICENSE.txt", lic / "Swift-Apache-2.0-runtime-exception.txt")
    # Foundation's ICU is linked in statically: its own licence and the Swift repository's.
    shutil.copy2(ROOT / "tools/crossplatform/licenses/ICU-LICENSE.txt", lic / "ICU-Unicode-3.0.txt")
    shutil.copy2(ROOT / "tools/crossplatform/licenses/swift-foundation-icu-LICENSE.md", lic / "swift-foundation-icu-Apache-2.0.md")
    (stage / "README.txt").write_text(README.format(arch=arch, commit=commit + (" (with uncommitted changes)" if dirty else "")))

    files = sorted(p for p in stage.rglob("*") if p.is_file())
    manifest = {"commit": commit, "dirty": dirty, "toolchain": "swift-6.4.0-RELEASE (open source)", "sdk": f"ntsd-6.4.0-ubuntu24.04-{arch}", "arch": arch,
                "files": {str(p.relative_to(args.out)): {"bytes": p.stat().st_size, "sha256": sha(p)} for p in files}}
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w", format=tarfile.PAX_FORMAT) as tar:
        for p in sorted([stage, *stage.rglob("*")]):
            info = tar.gettarinfo(str(p), arcname=str(p.relative_to(args.out)))
            info.uid = info.gid = 0; info.uname = info.gname = ""; info.mtime = epoch
            info.mode = 0o755 if p.is_dir() or os.access(p, os.X_OK) else 0o644
            if p.is_file():
                with p.open("rb") as f: tar.addfile(info, f)
            else:
                tar.addfile(info)
    archive = args.out / f"{name}-{commit[:7]}.tar.gz"
    with archive.open("wb") as f, gzip.GzipFile(fileobj=f, mode="wb", mtime=0, filename="") as gz:
        gz.write(raw.getvalue())
    manifest["archive"] = {"name": archive.name, "bytes": archive.stat().st_size, "sha256": sha(archive)}
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest["archive"]))


if __name__ == "__main__":
    main()
