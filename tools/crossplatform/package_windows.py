#!/usr/bin/env python3
"""Build the Windows SDL package of the native port (x86_64).

Usage: package_windows.py OUT_DIR [--scratch DIR]

Cross-builds NTSDSDL.exe on this Mac with the Swift SDK bundle from
make_windows_sdk.py (open-source Swift 6.4.0, SwiftPM's native build system)
against libsdl's SDL3 3.4.16 VC package, then assembles:

  ntsd-windows-x86_64/NTSDSDL.exe                    the game
  ntsd-windows-x86_64/SDL3.dll                       SDL3 3.4.16 (libsdl's build)
  ntsd-windows-x86_64/*.dll                          the Swift 6.4.0 and MSVC runtime
                                                     DLLs NTSDSDL.exe loads (import
                                                     closure; the rest are left out)
  ntsd-windows-x86_64/NTSDNative_NTSDCore.resources  resources
  ntsd-windows-x86_64/OriginalMusic                  packaged tracks + manifest
  ntsd-windows-x86_64/LICENSES, README.txt           SDL3, ALAC, Swift, ICU

and a reproducible zip (sorted entries, times of HEAD's commit) with
manifest.json. Text uses GDI's SYSTEM_FONT, the original's own font; ONLINE
GAME uses the real Winsock stack. Local artefact only: publishing it is a
separate decision.
"""
import argparse, datetime, hashlib, json, os, shutil, subprocess, zipfile, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT = Path.home() / "Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift"
X5 = Path("/Volumes/X5/ntsd-2.4-research/crossplatform")
README = """NTSD native port for Windows (x86_64, SDL3)

Run:   NTSDSDL.exe
Data:  settings and replays go to %APPDATA%\\NTSD Native\\ (SDL_GetPrefPath).
Text:  GDI's SYSTEM_FONT, as the original game draws it.
Build: {commit}
"""


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pe_imports(path):
    """DLL names in a PE32+ file's import and delay-import directories."""
    b = path.read_bytes(); pe = struct.unpack_from("<I", b, 0x3C)[0]
    sections, optsize = struct.unpack_from("<H", b, pe + 6)[0], struct.unpack_from("<H", b, pe + 20)[0]
    opt = pe + 24; assert struct.unpack_from("<H", b, opt)[0] == 0x20B, path
    table = [struct.unpack_from("<IIII", b, opt + optsize + 40 * i + 8) for i in range(sections)]
    def offset(rva):
        return next(raw + rva - va for size, va, rawsize, raw in table if va <= rva < va + max(size, rawsize))
    def name(rva):
        o = offset(rva); return b[o:b.index(b"\0", o)].decode("ascii")
    names = set()
    for index, step, field in ((1, 20, 12), (13, 32, 4)):
        rva = struct.unpack_from("<I", b, opt + 112 + 8 * index)[0]
        if rva == 0: continue
        o = offset(rva)
        while any(b[o:o + step]):
            names.add(name(struct.unpack_from("<I", b, o + field)[0]).lower()); o += step
    return names


def loaded(start, available):
    """The DLLs in `available` (lowercase name -> path) that `start` loads, transitively."""
    found, todo = set(), [start]
    while todo:
        for dll in pe_imports(todo.pop()):
            if dll in available and dll not in found: found.add(dll); todo.append(available[dll])
    return found


def main():
    a = argparse.ArgumentParser(); a.add_argument("out", type=Path)
    a.add_argument("--scratch", type=Path, default=X5 / "build-windows-x86_64")
    args = a.parse_args()
    sdl = X5 / "windows-deps/sdl3/install-x86_64"; runtime = X5 / "windows-sdk-extract/tree"
    env = {**os.environ, "NTSD_PORTABLE": "1", "NTSD_SDL": "1", "NTSD_SDL_PREFIX": str(sdl)}
    common = ["--package-path", str(ROOT / "native"), "--scratch-path", str(args.scratch), "--build-system", "native",
              "--swift-sdk", "ntsd-6.4.0-windows-x86_64", "-c", "release", "--product", "NTSDSDL"]
    subprocess.run([str(SWIFT), "build", *common], env=env, check=True)
    products = Path(subprocess.run([str(SWIFT), "build", *common, "--show-bin-path"], env=env, check=True,
                                   capture_output=True, text=True).stdout.strip())
    commit = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
    epoch = int(subprocess.run(["git", "-C", str(ROOT), "log", "-1", "--format=%ct"], check=True, capture_output=True, text=True).stdout)
    dirty = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain", "native"], check=True, capture_output=True, text=True).stdout.strip() != ""

    name = "ntsd-windows-x86_64"; stage = args.out / name
    shutil.rmtree(args.out, ignore_errors=True); stage.mkdir(parents=True)
    shutil.copy2(products / "NTSDSDL.exe", stage / "NTSDSDL.exe")
    shutil.copy2(sdl / "bin/SDL3.dll", stage / "SDL3.dll")
    available = {p.name.lower(): p for p in runtime.glob("*.dll")}
    for dll in sorted(loaded(stage / "NTSDSDL.exe", available) - {"sdl3.dll"}):
        shutil.copy2(available[dll], stage / available[dll].name)
    shutil.copytree(products / "NTSDNative_NTSDCore.resources", stage / "NTSDNative_NTSDCore.resources")
    shutil.copytree(ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic", stage / "OriginalMusic")
    lic = stage / "LICENSES"; lic.mkdir()
    shutil.copy2(sdl / "LICENSE.txt", lic / "SDL3-zlib.txt")
    shutil.copy2(ROOT / "native/Sources/CALAC/vendor/LICENSE", lic / "ALAC-Apache-2.0.txt")
    shutil.copy2(SWIFT.parent.parent / "share/swift/LICENSE.txt", lic / "Swift-Apache-2.0-runtime-exception.txt")
    shutil.copy2(ROOT / "tools/crossplatform/licenses/ICU-LICENSE.txt", lic / "ICU-Unicode-3.0.txt")
    shutil.copy2(ROOT / "tools/crossplatform/licenses/swift-foundation-icu-LICENSE.md", lic / "swift-foundation-icu-Apache-2.0.md")
    (stage / "README.txt").write_text(README.format(commit=commit + (" (with uncommitted changes)" if dirty else "")).replace("\n", "\r\n"))

    files = sorted(p for p in stage.rglob("*") if p.is_file())
    manifest = {"commit": commit, "dirty": dirty, "toolchain": "swift-6.4.0-RELEASE (open source)", "sdk": "ntsd-6.4.0-windows-x86_64",
                "files": {str(p.relative_to(args.out)): {"bytes": p.stat().st_size, "sha256": sha(p)} for p in files}}
    stamp = datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).timetuple()[:6]
    archive = args.out / f"{name}-{commit[:7]}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in sorted([*stage.rglob("*")]):
            rel = str(p.relative_to(args.out)) + ("/" if p.is_dir() else "")
            info = zipfile.ZipInfo(rel, date_time=stamp)
            info.external_attr = (0o40755 << 16) | 0x10 if p.is_dir() else (0o100644 << 16)
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, b"" if p.is_dir() else p.read_bytes())
    manifest["archive"] = {"name": archive.name, "bytes": archive.stat().st_size, "sha256": sha(archive)}
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest["archive"]))


if __name__ == "__main__":
    main()
