#!/usr/bin/env python3
"""Read the pristine NTSD distribution without altering it; export lossless frame fields.

Format confirmed in the original EXE: decoder 0x4148a0, key 0x44892c,
123-byte header loop 0x41493a, subtraction 0x414993. See docs/ORIGINAL_ENGINE.md.
The JSON keeps numeric literals as strings, including
out-of-range values: compatibility decisions belong in the runtime, not import.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a"
EXE_SHA256 = '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
EXE_KEY = b"SiuHungIsAGoodBearBecauseHeIsVeryGood"
# The original advances the cipher index while skipping its 123-byte header.
KEY_OFFSET = 123 % len(EXE_KEY)
KEY = EXE_KEY[KEY_OFFSET:] + EXE_KEY[:KEY_OFFSET]
POINTER = b"version https://git-lfs.github.com/spec/v1"
FIELDS = re.compile(r"([A-Za-z_][A-Za-z_0-9]*(?:\([^)]*\))?):\s*")
BLOCKS = ("bdy", "itr", "opoint", "wpoint", "cpoint", "bpoint")


def read_bytes(path: Path) -> bytes:
    data = path.read_bytes()
    if data.startswith(POINTER):
        raise ValueError(f"Git LFS content is missing: {path}. Run tools/fetch-assets.sh.")
    return data


def decode_dat(data: bytes) -> str:
    if data.startswith(POINTER):
        raise ValueError("Git LFS pointer is not game data")
    if b"<bmp_begin>" in data[:256] or b"<background>" in data[:256]:
        return data.decode("latin-1")
    if len(data) < 123:
        raise ValueError("Truncated DAT header")
    result = bytes((byte - KEY[i % len(KEY)]) & 255 for i, byte in enumerate(data[123:]))
    return result.decode("latin-1")


def fields(text: str) -> dict[str, str]:
    # Field values end at the next field or line break; inline comments do not
    # become part of a number. Preserve strings such as sprite/sound paths.
    result = {}
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        matches = list(FIELDS.finditer(line))
        if not matches:
            stat = re.fullmatch(r"([a-z_]+)\s+(-?\d+(?:\.\d+)?)", line)
            if stat:
                result[stat[1]] = stat[2]
        for i, match in enumerate(matches):
            end = matches[i + 1].start() if i + 1 < len(matches) else len(line)
            result[match[1]] = line[match.end():end].strip()
    return result


def parse_object(text: str) -> dict:
    header = re.search(r"<bmp_begin>(.*?)<bmp_end>", text, re.S)
    if not header:
        raise ValueError("No <bmp_begin> section")
    sheets = []
    for line in header[1].splitlines():
        match = re.search(r"file\((\d+)-(\d+)\):\s*(\S+)(.*)", line)
        if match:
            sheets.append({"first": int(match[1]), "last": int(match[2]),
                           "path": match[3].replace("\\", "/"), "fields": fields(match[4])})
    frames, duplicates, occurrences = {}, [], []
    for match in re.finditer(r"<frame>\s*(-?\d+)\s*([^\r\n]*)[\r\n]+(.*?)<frame_end>", text, re.S):
        number = match[1]
        body = match[3]
        blocks = {}
        for kind in BLOCKS:
            pattern = rf"\b{kind}:\s*(.*?)\b{kind}_end:"
            blocks[kind] = [fields(m[1]) for m in re.finditer(pattern, body, re.S)]
            body = re.sub(pattern, "", body, flags=re.S)
        frame = {"name": match[2].strip(), "fields": fields(body), "blocks": blocks}
        if number in frames:
            duplicates.append({"number": number, "previous": frames[number], "replacement": frame})
        frames[number] = frame
        occurrences.append({"number": int(number), "frame": frame})
    if not frames:
        raise ValueError("No frames found")
    return {"header": fields(header[1]), "sheets": sheets, "frames": frames,
            "frameOccurrences": occurrences, "duplicateFrames": duplicates}


def parse_background(text: str) -> dict:
    layers = []
    for match in re.finditer(r"\blayer:\s*(.*?)\blayer_end", text, re.S):
        layer = fields(match[1])
        path = re.search(r"([\w\\/ .-]+\.bmp)", match[1], re.I)
        if path:
            layer["file"] = path[1].strip().replace("\\", "/")
        layers.append(layer)
    header = re.split(r"\blayer:", text, maxsplit=1)[0]
    return {"header": fields(header), "layers": layers}


def import_game(source: Path, output: Path) -> dict:
    source = source.resolve()
    exe = read_bytes(source / 'NTSD 2.4.exe')
    if hashlib.sha256(exe).hexdigest() != EXE_SHA256:
        raise ValueError('EXE differs from the original baseline; inspect and identify it before importing.')
    if exe[0x4892c:0x4892c+len(EXE_KEY)] != EXE_KEY:
        raise ValueError('Original cipher key does not match the inspected EXE.')
    index_data = read_bytes(source / "data/data.txt")
    index = index_data.decode("latin-1")
    file_map = {p.relative_to(source).as_posix().lower(): p.relative_to(source).as_posix()
                for p in source.rglob("*") if p.is_file()}
    objects, backgrounds, failures = [], [], []
    source_hashes = {"NTSD 2.4.exe": EXE_SHA256, "data/data.txt": hashlib.sha256(index_data).hexdigest()}
    states, kinds, effects, frame_fields = Counter(), Counter(), Counter(), Counter()
    extreme_values = []
    section = ""
    for line in index.splitlines():
        if "<object>" in line:
            section = "object"
        elif "<background>" in line:
            section = "background"
        elif "_end>" in line:
            section = ""
        entry = fields(line)
        if "file" not in entry or "id" not in entry:
            continue
        relative = entry["file"].replace("\\", "/")
        actual = file_map.get(relative.lower(), relative)
        try:
            raw = read_bytes(source / actual)
            source_hashes[actual] = hashlib.sha256(raw).hexdigest()
            text = decode_dat(raw) if source.joinpath(actual).suffix.lower() == ".dat" else raw.decode("latin-1")
            if section == "object":
                obj = parse_object(text)
                obj.update(id=int(entry["id"]), type=int(entry.get("type", 0)), source=actual, originalText=text)
                objects.append(obj)
                for number, frame in obj["frames"].items():
                    states[frame["fields"].get("state", "missing")] += 1
                    frame_fields.update(frame["fields"].keys())
                    for itr in frame["blocks"]["itr"]:
                        kinds[itr.get("kind", "missing")] += 1
                        effects[itr.get("effect", "0")] += 1
                    for group in [frame["fields"]] + [b for blocks in frame["blocks"].values() for b in blocks]:
                        for key, value in group.items():
                            if re.fullmatch(r"-?\d+", value) and not -(2**31) <= int(value) < 2**31:
                                extreme_values.append({"file": actual, "frame": number, "field": key, "value": value})
            elif section == "background":
                bg = parse_background(text)
                bg.update(id=int(entry["id"]), source=actual, originalText=text)
                backgrounds.append(bg)
        except (ValueError, OSError) as error:
            failures.append({"file": actual, "error": str(error)})
    if failures:
        raise ValueError(json.dumps(failures, ensure_ascii=False, indent=2))
    if not objects or not backgrounds:
        raise ValueError("Registry must contain objects and backgrounds")
    report = {
        "distribution": source.name, "objectCount": len(objects),
        "characterCount": sum(o["type"] == 0 for o in objects), "backgroundCount": len(backgrounds),
        "frameCount": sum(len(o["frames"]) for o in objects), "states": dict(states),
        "sourceFrameCount": sum(len(o["frameOccurrences"]) for o in objects),
        "itrKinds": dict(kinds), "itrEffects": dict(effects), "frameFields": dict(frame_fields),
        "outOfInt32Range": extreme_values, "sha256": source_hashes,
        "duplicateFrames": [{"file": o["source"], "numbers": [d["number"] for d in o["duplicateFrames"]]}
                            for o in objects if o["duplicateFrames"]],
        "notes": ["Inventory is not a claim of runtime compatibility; counters use the last-occurrence lookup unless named sourceFrameCount.",
                  "Original files are read-only inputs. Numeric literals are retained verbatim.",
                  "The frames lookup shows the last occurrence for convenience only, not original loader semantics.",
                  "frameOccurrences retains every definition in source order. The native inspector uses this list."]}
    output.mkdir(parents=True, exist_ok=True)
    (output / "game.json").write_text(json.dumps({"objects": objects, "backgrounds": backgrounds,
                                                 "files": file_map}, ensure_ascii=True), encoding="utf-8")
    (output / "audit.json").write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=ROOT / "build/imported")
    args = parser.parse_args()
    try:
        report = import_game(args.source, args.output)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Import failed: {error}\n")
    print(json.dumps({k: report[k] for k in ["objectCount", "characterCount", "backgroundCount", "frameCount"]}, indent=2))


if __name__ == "__main__":
    main()
