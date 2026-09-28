#!/usr/bin/env python3
"""Package the deferred arena BMPs of every registered background.

Data only; the original is not executed. The backgrounds are the <background>
entries of data/data.txt (bg\\sys\\<Name>\\bg.dat); every BMP of each folder
is copied with its size, SHA-256, dimensions and format into
native/Sources/NTSDCore/Resources/OriginalMatchArenas (manifest format of the
earlier District package). An existing package is verified without rewriting.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a"
OUTPUT = ROOT / "native/Sources/NTSDCore/Resources/OriginalMatchArenas"
EXE_SHA256 = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"


def regular_bytes(path):
    if not stat.S_ISREG(path.lstat().st_mode):
        raise ValueError(f"Expected regular file: {path}")
    return path.read_bytes()


def backgrounds(baseline):
    text = regular_bytes(baseline / "data/data.txt").decode("latin-1")
    section = text[text.index("<background>"):text.index("<background_end>")]
    found = re.findall(r"id:\s*(\d+)\s+file:\s*(bg\\sys\\[^\\\s]+)\\bg\.dat", section)
    ids = [int(i) for i, _ in found]
    if sorted(ids) != list(range(len(ids))):
        raise ValueError("Background ids are not 0..n-1")
    return [folder for _, folder in sorted(found, key=lambda x: int(x[0]))]


def entry(baseline, relative):
    raw = regular_bytes(baseline / relative)
    if raw[:2] != b"BM":
        raise ValueError(f"Not a BMP: {relative}")
    width, height, planes, bits, compression = struct.unpack("<iiHHI", raw[18:34])
    if planes != 1 or bits not in (8, 24) or compression != 0:
        raise ValueError(f"Unsupported BMP format: {relative}")
    path = relative.as_posix()
    return raw, {"name": path.replace("/", "\\"), "path": path, "bytes": len(raw),
                 "sha256": hashlib.sha256(raw).hexdigest(), "width": width, "height": height,
                 "bits": bits, "compression": compression}


def build_package(baseline=BASELINE, output=OUTPUT, verify_only=False):
    baseline, output = Path(baseline), Path(output)
    exe = regular_bytes(baseline / "NTSD 2.4.exe")
    if hashlib.sha256(exe).hexdigest() != EXE_SHA256:
        raise ValueError("Baseline EXE identity differs")
    payloads, entries = {}, []
    for folder in backgrounds(baseline):
        directory = baseline / folder.replace("\\", "/")
        names = sorted(p.name for p in directory.iterdir() if p.suffix.lower() == ".bmp")
        if not names:
            raise ValueError(f"No BMP in {folder}")
        for name in names:
            raw, item = entry(baseline, Path(folder.replace("\\", "/")) / name)
            payloads[item["path"]] = raw; entries.append(item)
    manifest = (json.dumps({"version": 1, "exeSHA256": EXE_SHA256, "entries": entries}, indent=2) + "\n").encode()
    exists = output.exists()
    if verify_only and not exists:
        raise ValueError("Package is absent")
    if not verify_only:
        for path, raw in payloads.items():
            target = output / path
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists() or target.read_bytes() != raw:
                target.write_bytes(raw); os.chmod(target, 0o644)
        (output / "manifest.json").write_bytes(manifest)
    stored = {p.relative_to(output).as_posix() for p in output.rglob("*") if p.is_file()}
    if stored != set(payloads) | {"manifest.json"}:
        raise ValueError("Package composition differs")
    for path, raw in payloads.items():
        if regular_bytes(output / path) != raw:
            raise ValueError(f"Package bytes differ: {path}")
    if regular_bytes(output / "manifest.json") != manifest:
        raise ValueError("Manifest differs")
    return {"version": 1, "originalExecuted": False, "backgrounds": len({e["path"].rsplit("/", 1)[0] for e in entries}),
            "files": len(entries), "bytes": sum(e["bytes"] for e in entries),
            "manifestSHA256": hashlib.sha256(manifest).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=BASELINE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--verify", action="store_true", help="Require existing package; read only")
    args = parser.parse_args()
    print(json.dumps(build_package(args.baseline, args.output, args.verify), sort_keys=True))


if __name__ == "__main__":
    main()
