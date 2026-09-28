#!/usr/bin/env python3
"""Decode the original 8 bgm tracks into lossless ALAC/CAF resources.

Build tool only; the app never decodes WMA and the original is not executed.
FFmpeg's native WMA v2/Pro decoders produce float samples; each sample becomes
int16 by round-half-even of x*32768 with saturation (declared rule; the PCM of
Windows' WMA decoder is not claimed). Apple's afconvert encodes ALAC, and its
own decode must return those int16 samples bit for bit. An existing package is
verified without rewriting any file.
"""
import argparse
import array
import hashlib
import json
import os
from pathlib import Path
import stat
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a"
OUTPUT = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
EXE_SHA256 = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"
FILES = (
    ("boss1", 1254751, "851b9337cf258e59"),
    ("boss2", 1284791, "5806bb56d2dcb6d0"),
    ("main", 3895405, "e3448b9b8445e348"),
    ("stage1", 2162365, "82ae94243bbd6ab4"),
    ("stage2", 1311827, "568be15688c78049"),
    ("stage3", 1236727, "3557950e4a5d83dc"),
    ("stage4", 1236727, "323ec7712db42b34"),
    ("stage5", 2072725, "1af041e596fe69f6"),
)
CHANNELS, RATE = 2, 44100


def pin(raw):
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def regular_bytes(path):
    if not stat.S_ISREG(path.lstat().st_mode):
        raise ValueError(f"Expected regular file: {path}")
    return path.read_bytes()


def run(command):
    return subprocess.run(command, check=True, capture_output=True).stdout


def tools():
    ffmpeg = run(["ffmpeg", "-version"]).decode().splitlines()[0]
    system = [run(["sw_vers", flag]).decode().strip() for flag in ("-productVersion", "-buildVersion")]
    return {"ffmpeg": ffmpeg, "afconvert": "macOS " + " ".join(system)}


def probe(source):
    out = run(["ffprobe", "-v", "error", "-show_entries", "stream=codec_name,sample_rate,channels",
               "-of", "json", str(source)])
    stream = json.loads(out)["streams"]
    if len(stream) != 1 or int(stream[0]["sample_rate"]) != RATE or stream[0]["channels"] != CHANNELS:
        raise ValueError(f"Unexpected stream layout: {source}")
    return stream[0]["codec_name"]


def pcm(source):
    if sys.byteorder != "little":
        raise ValueError("Little-endian host required")
    floats = array.array("f", run(["ffmpeg", "-v", "error", "-i", str(source), "-f", "f32le", "-acodec", "pcm_f32le", "-"]))
    if len(floats) % CHANNELS:
        raise ValueError(f"Partial frame: {source}")
    return array.array("h", (max(-32768, min(32767, round(v * 32768.0))) for v in floats)).tobytes()


def wave(data):
    header = struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + len(data), b"WAVE", b"fmt ", 16, 1, CHANNELS, RATE,
                         RATE * CHANNELS * 2, CHANNELS * 2, 16, b"data", len(data))
    return header + data


def caf_data(raw):
    if raw[:4] != b"caff":
        raise ValueError("Not a CAF file")
    offset = 8
    while offset + 12 <= len(raw):
        kind, size = raw[offset:offset + 4], struct.unpack(">q", raw[offset + 4:offset + 12])[0]
        if kind == b"data":
            return raw[offset + 16:] if size == -1 else raw[offset + 16:offset + 12 + size]
        offset += 12 + size
    raise ValueError("CAF without data chunk")


def apple_decode(caf, scratch):
    back = Path(scratch) / "back.caf"
    run(["afconvert", "-f", "caff", "-d", "LEI16", str(caf), str(back)])
    data = caf_data(back.read_bytes()); back.unlink()
    return data


def build_package(baseline=BASELINE, output=OUTPUT, verify_only=False):
    baseline, output = Path(baseline), Path(output)
    exe = regular_bytes(baseline / "NTSD 2.4.exe")
    if pin(exe) != {"bytes": 31715328, "sha256": EXE_SHA256}:
        raise ValueError("Baseline EXE identity differs")
    created = not output.exists() and not output.is_symlink()
    if created and verify_only:
        raise ValueError("Package is absent")
    entries, payloads = [], {}
    with tempfile.TemporaryDirectory() as scratch:
        for name, count, prefix in FILES:
            source = baseline / "bgm" / f"{name}.wma"
            raw = regular_bytes(source)
            if len(raw) != count or not pin(raw)["sha256"].startswith(prefix):
                raise ValueError(f"Baseline track identity differs: {name}")
            codec, data = probe(source), pcm(source)
            target = output / f"{name}.caf"
            if created:
                wav = Path(scratch) / f"{name}.wav"
                wav.write_bytes(wave(data))
                encoded = Path(scratch) / f"{name}.caf"
                run(["afconvert", "-f", "caff", "-d", "alac", str(wav), str(encoded)])
                wav.unlink()
                payloads[target.name] = encoded.read_bytes()
                check = encoded
            else:
                check = target
            if apple_decode(check, scratch) != data:
                raise ValueError(f"ALAC decode differs from the int16 samples: {name}")
            caf = payloads.get(target.name) or regular_bytes(target)
            entries.append({"name": f"bgm\\{name}.wma", "resource": target.name, "codec": codec,
                            "source": pin(raw), "frames": len(data) // (2 * CHANNELS),
                            "pcm": pin(data), "caf": pin(caf)})
    manifest = {"version": 1, "exeSHA256": EXE_SHA256, "channels": CHANNELS, "sampleRate": RATE,
                "conversion": "FFmpeg float decode; int16 = saturate(roundHalfEven(x*32768)); ALAC by afconvert",
                "tools": tools(), "entries": entries}
    manifest_raw = (json.dumps(manifest, indent=1, sort_keys=True) + "\n").encode()
    if created:
        output.mkdir(mode=0o755, parents=True, exist_ok=False)
        for name, raw in list(payloads.items()) + [("manifest.json", manifest_raw)]:
            with (output / name).open("xb") as stream:
                stream.write(raw)
            os.chmod(output / name, 0o644)
    if output.is_symlink() or not output.is_dir():
        raise ValueError("Package must be a regular local directory")
    expected = {f"{name}.caf" for name, _, _ in FILES} | {"manifest.json"}
    if {p.name for p in output.iterdir()} != expected:
        raise ValueError("Package composition differs")
    stored = json.loads(regular_bytes(output / "manifest.json"))
    if stored["entries"] != entries:
        raise ValueError("Manifest entries differ from the package")
    return {"version": 1, "created": created, "originalExecuted": False, "baselineEXE": pin(exe),
            "manifest": pin(regular_bytes(output / "manifest.json")), "tracks": len(entries),
            "frames": sum(e["frames"] for e in entries), "cafBytes": sum(e["caf"]["bytes"] for e in entries),
            "tools": tools()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=BASELINE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--verify", action="store_true", help="Require existing package; read only")
    args = parser.parse_args()
    print(json.dumps(build_package(args.baseline, args.output, args.verify), sort_keys=True))


if __name__ == "__main__":
    main()
