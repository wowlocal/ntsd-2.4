#!/usr/bin/env python3
"""Package exact original catalog/media inputs; no game or reference execution.

The checked manifest comes from a separately verified original-input inventory.
Existing outputs are read-only verified. New outputs publish by directory rename
only after complete verification; a failed partial directory is preserved.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a"
MANIFEST = Path(__file__).with_name("catalog_inputs_manifest.json")
MANIFEST_SHA256 = "fd42d041549f00f5ba715063d7e560a9e2b01ab720017d1da5e032c34ca9451d"
EXE_SHA256 = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"
TARGET_MANIFEST = Path(__file__).with_name("ntsd_2_8_3_3_partial_inputs_manifest.json")
TARGET_MANIFEST_SHA256 = "c0ef67b9ee7d49b5efec4e98a3830395ecb8942136dd6e0784f66ac479688899"


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def regular(root, name):
    parts = name.split("/")
    if any(part in ("", ".", "..") for part in parts) or "\\" in name:
        raise ValueError("Invalid package path")
    path = root
    for i, part in enumerate(parts):
        path /= part
        mode = path.lstat().st_mode
        if not (stat.S_ISREG(mode) if i == len(parts)-1 else stat.S_ISDIR(mode)):
            raise ValueError(f"Nonregular path: {path}")
    return path.read_bytes()


def members(directory):
    if not stat.S_ISDIR(directory.lstat().st_mode):
        raise ValueError("Package root is not a regular directory")
    found = set()
    for path in directory.rglob("*"):
        mode = path.lstat().st_mode
        if stat.S_ISREG(mode):
            found.add(str(path.relative_to(directory)))
        elif not stat.S_ISDIR(mode):
            raise ValueError(f"Nonregular package member: {path}")
    return found


def build_package(baseline, output, verify_only=False):
    baseline, output = Path(baseline), Path(output)
    raw = regular(MANIFEST.parent, MANIFEST.name)
    if digest(raw) != MANIFEST_SHA256:
        raise ValueError("Manifest identity differs")
    manifest = json.loads(raw)
    if manifest["version"] != 1 or manifest["exeSHA256"] != EXE_SHA256:
        raise ValueError("Manifest contract differs")
    entries = manifest["entries"]
    if len(entries) != 1198 or len({e["path"] for e in entries}) != 1198:
        raise ValueError("Package membership differs")
    exe = regular(baseline, "NTSD 2.4.exe")
    if len(exe) != 31715328 or digest(exe) != EXE_SHA256:
        raise ValueError("Baseline EXE identity differs")
    def source(entry):
        origin = entry["origin"]
        if entry["kind"] == "dib":
            start = origin["offset"]
            data = exe[start:start+entry["count"]]
        else:
            data = regular(baseline, origin["path"])
        if len(data) != entry["count"] or digest(data) != entry["sha256"]:
            raise ValueError(f"Original input differs: {entry['name']}")
        return data
    def validate_source():
        if regular(baseline, "NTSD 2.4.exe") != exe:
            raise ValueError("Baseline changed during copy")
    result = publish_package(output, raw, entries, source, verify_only, validate_source)
    return dict(result, manifestSHA256=MANIFEST_SHA256, originalExecuted=False)


def publish_package(output, raw, entries, source, verify_only, validate_source=lambda: None):
    """Shared verified-copy path; failed partials and existing outputs survive."""
    created = not output.exists() and not output.is_symlink()
    destination = output
    if created:
        if verify_only:
            raise ValueError("Package is absent")
        destination = output.with_name(output.name + ".partial")
        destination.mkdir(parents=True, exist_ok=False)
        os.chmod(destination, 0o755)
        for entry in entries:
            data = source(entry)
            path = destination / entry["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("xb") as stream:
                stream.write(data)
            os.chmod(path, 0o644)
        (destination / "manifest.json").write_bytes(raw)
        os.chmod(destination / "manifest.json", 0o644)
    if members(destination) != {e["path"] for e in entries} | {"manifest.json"}:
        raise ValueError("Package composition differs")
    if regular(destination, "manifest.json") != raw:
        raise ValueError("Packaged manifest differs")
    for entry in entries:
        if regular(destination, entry["path"]) != source(entry):
            raise ValueError(f"Packaged bytes differ: {entry.get('name', entry['path'])}")
        if stat.S_IMODE((destination/entry["path"]).stat().st_mode) != 0o644:
            raise ValueError(f"Packaged mode differs: {entry.get('name', entry['path'])}")
    validate_source()
    if created:
        if output.exists() or output.is_symlink():
            raise ValueError("Output appeared during copy")
        destination.rename(output)
    return dict(created=created,fileCount=len(entries)+1,payloadBytes=sum(e["count"] for e in entries))


def build_target_raw_package(archive, output, verify_only=False):
    """Only nine ordinary outer-ZIP members; no EXE/DLL or opaque content."""
    raw = regular(TARGET_MANIFEST.parent, TARGET_MANIFEST.name)
    if digest(raw) != TARGET_MANIFEST_SHA256:
        raise ValueError("Target partial manifest identity differs")
    manifest = json.loads(raw)
    entries = manifest["entries"]
    if (manifest["version"] != 1 or manifest["identity"] != "NTSD-2.8.3.3-partial"
            or manifest["partial"] is not True or len(entries) != 9
            or len({e["path"] for e in entries}) != 9
            or sum(e["count"] for e in entries) != 161202):
        raise ValueError("Target partial manifest contract differs")
    archive = Path(archive)
    if not stat.S_ISREG(archive.lstat().st_mode):
        raise ValueError("Target archive is not a regular file")
    with archive.open("rb") as stream:
        archive_digest = hashlib.sha256()
        for block in iter(lambda: stream.read(1 << 20), b""):
            archive_digest.update(block)
        if archive_digest.hexdigest() != manifest["archiveSHA256"]:
            raise ValueError("Target archive identity differs")
        stream.seek(0)
        with zipfile.ZipFile(stream) as zipped:
            def source(entry):
                name = "NTSD2.8.3.3/" + entry["path"]
                matches = [info for info in zipped.infolist() if info.filename == name]
                if len(matches) != 1 or matches[0].file_size != entry["count"]:
                    raise ValueError(f"Target member identity differs: {name}")
                data = zipped.read(matches[0])
                if len(data) != entry["count"] or digest(data) != entry["sha256"]:
                    raise ValueError(f"Target member bytes differ: {name}")
                return data
            result = publish_package(Path(output), raw, entries, source, verify_only)
    return dict(result,manifestSHA256=TARGET_MANIFEST_SHA256,partial=True,originalExecuted=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    origin = parser.add_mutually_exclusive_group()
    origin.add_argument("--baseline",type=Path)
    origin.add_argument("--target-raw-zip",type=Path,help="Package only pinned ordinary 2.8.3.3 outer-ZIP inputs")
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--verify",action="store_true")
    args = parser.parse_args()
    result = (build_target_raw_package(args.target_raw_zip,args.output,args.verify) if args.target_raw_zip
              else build_package(args.baseline or BASELINE,args.output,args.verify))
    print(json.dumps(result,sort_keys=True))


if __name__ == "__main__":
    main()
