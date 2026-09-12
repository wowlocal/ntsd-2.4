#!/usr/bin/env python3
"""Copy/verify the original 18 common WAV inputs. Data only; no game execution.

Names retain the EXE caller order, including different names with equal bytes.
An existing package is verified without rewriting any file. A partial or corrupt
package fails validation and is left intact for diagnosis.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a"
OUTPUT = ROOT / "native/Sources/NTSDCore/Resources/OriginalCommonSounds"
EXE_SHA256 = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"
FILES = (
    ("001.wav", 23694, "28f50924fc845a963d398fda600b9df740149f1c696843aa7cbd56f8552d785a"),
    ("002.wav", 23704, "f2783a52e1fc333a46a094b61332bb883380586119c77b1b0f86031dfa3f15f0"),
    ("006.wav", 15654, "3ade81bab01f8eb99f9ed4c68d4c63245a6413757b801edfe04e59f7be3e80ea"),
    ("010.wav", 11576, "e5e31a220b7b607e189093cf01e1fefa4fb00ec00e8b55cb6ec9715c0fa199d6"),
    ("011.wav", 3884, "788bf352868b82eeead8da8b95d289bcc8a9dcdf1f8c2b368579cf61b1ce7f9a"),
    ("004.wav", 11228, "4b501f67bec53f364530e041012faa40334e7f4f0f82088b6b7caa472c2207ac"),
    ("016.wav", 8284, "40f7b9ac8483ba57dfed5c1e0322653fc387918d429b7711e3dd4b11178a9810"),
    ("017.wav", 15232, "43030d58b00f98999af6635c9966294fb9b5b6889d03fd1dca8f46bfedf3b5a6"),
    ("020.wav", 33678, "7fff68e80d827a2237a05b0483b914c757c742e73a1a5c8a012a3b3f58b8db70"),
    ("021.wav", 34436, "c5de442a4d4a3d48340529cd1a91b051dac7eccc83c88ab5ae67a8426a63f0a5"),
    ("025.wav", 8606, "8668a7e6a2912e5f5c093c9814ee06343aff88333f39d894dc954c8ddcfbc1d1"),
    ("032.wav", 12148, "90bb8290a65a8aa38e2effc077939431df0ece4e1c304eb6905ad47002def286"),
    ("033.wav", 21834, "4cbab9e851b6601cbf20cbbc349305436261e902862c12818e1458179f59d3bc"),
    ("039.wav", 2774, "8b3c2c8356655ad3708e578a9033a8f9db25243fb97c91a97ee2f0dbf350b889"),
    ("065.wav", 23694, "28f50924fc845a963d398fda600b9df740149f1c696843aa7cbd56f8552d785a"),
    ("066.wav", 23360, "70320b85f3cbad144f73e5a89d905b7917ae3a94d941f78051c98484b1afa009"),
    ("068.wav", 53588, "b1cffa6ba75ed2ca808cab85358da5c4bf627ff80559ca943d716a9461632018"),
    ("085.wav", 23704, "f2783a52e1fc333a46a094b61332bb883380586119c77b1b0f86031dfa3f15f0"),
)


def pin(raw):
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def regular_bytes(path):
    if not stat.S_ISREG(path.lstat().st_mode):
        raise ValueError(f"Expected regular file: {path}")
    return path.read_bytes()


def manifest_bytes():
    value = {"version": 1, "exeSHA256": EXE_SHA256, "entries": [
        {"name": "data\\" + name, "count": count, "sha256": digest}
        for name, count, digest in FILES
    ]}
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def build_package(baseline=BASELINE, output=OUTPUT, verify_only=False):
    baseline, output = Path(baseline), Path(output)
    exe = regular_bytes(baseline / "NTSD 2.4.exe")
    if pin(exe) != {"bytes": 31715328, "sha256": EXE_SHA256}:
        raise ValueError("Baseline EXE identity differs")
    payloads = {}
    for name, count, digest in FILES:
        raw = regular_bytes(baseline / "data" / name)
        if pin(raw) != {"bytes": count, "sha256": digest}:
            raise ValueError(f"Baseline WAV identity differs: {name}")
        payloads[name] = raw
    payloads["manifest.json"] = manifest_bytes()
    created = not output.exists() and not output.is_symlink()
    if created:
        if verify_only:
            raise ValueError("Package is absent")
        output.mkdir(mode=0o755, parents=True, exist_ok=False)
        os.chmod(output, 0o755)
        for name, raw in payloads.items():
            with (output / name).open("xb") as stream:
                stream.write(raw)
            os.chmod(output / name, 0o644)
    if output.is_symlink() or not output.is_dir():
        raise ValueError("Package must be a regular local directory")
    if {p.name for p in output.iterdir()} != set(payloads):
        raise ValueError("Package composition differs")
    outputs = {}
    for name, expected in payloads.items():
        path = output / name
        actual = regular_bytes(path)
        if actual != expected or stat.S_IMODE(path.stat().st_mode) != 0o644:
            raise ValueError(f"Package bytes/mode differ: {name}")
        outputs[name] = dict(pin(actual), mode="0644")
    # Recheck inputs after the copy, without changing either source or output.
    for name, _, _ in FILES:
        if regular_bytes(baseline / "data" / name) != payloads[name]:
            raise ValueError(f"Baseline WAV changed during copy: {name}")
    if regular_bytes(baseline / "NTSD 2.4.exe") != exe:
        raise ValueError("Baseline EXE changed during copy")
    return {"version": 1, "created": created, "originalExecuted": False,
            "baselineEXE": pin(exe), "manifest": pin(payloads["manifest.json"]),
            "fileCount": len(outputs), "waveCount": len(FILES),
            "waveBytes": sum(len(payloads[name]) for name, _, _ in FILES),
            "totalBytes": sum(len(raw) for raw in payloads.values()),
            "files": outputs}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=BASELINE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--verify", action="store_true", help="Require existing package; read only")
    parser.add_argument("--report", type=Path, help="New report path; never overwritten")
    args = parser.parse_args()
    if args.report is not None and args.report.exists():
        parser.error("Report already exists")
    report = build_package(args.baseline, args.output, args.verify)
    if args.report is not None:
        with args.report.open("x") as stream:
            json.dump(report, stream, indent=2, sort_keys=True)
            stream.write("\n")
    print(json.dumps({k: v for k, v in report.items() if k != "files"}, sort_keys=True))


if __name__ == "__main__":
    main()
