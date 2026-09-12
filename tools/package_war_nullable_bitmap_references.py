#!/usr/bin/env python3
"""Lossless packaging of three already returned NTSD War preparation calls.

The pinned EXE/lib/VC80 observations used controlled Unicorn 2.1.4, CW023f,
C locale and declared allocation/API responses. They recover the game's arena
bitmap ownership when the first or last wrapper allocation returns NULL and,
for the first NULL, the following Start99 skips release of four live wrappers.

This tool only reads retained reports/inventory/atomic JSON, validates metadata
and every blob, and roundtrips complete raw bytes through DEFLATE. It imports no
source producer and executes no EXE/DLL/emulation. The faulted s03/call-01 is
explicitly excluded, never resumed or converted into a successful match.
Packaging is not Native acceptance, Windows/device evidence or incident closure.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import zlib


ROOT = Path(__file__).resolve().parents[1]
STUDY = ROOT / "build/research/lib-war-preparation"
FIXTURES = ROOT / "native/Tests/NTSDCoreTests/Fixtures"
EXE = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"
CRT = "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d"
LIB = "28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba"
INVENTORY = "war-errors-completion-20260912/inventory2.json"
INVENTORY_SHA = "75a96b6e5eae6b2139de5c3d807d9c17b912a41c360e0c68880e3a7211c4f6f4"
BOUND_INDEX = FIXTURES / "original-lib-war-preparation-bound.json"
BOUND_INDEX_SHA = "5b49a5d4acdf0ec42a9a25a5514aa821299fbfea24a83c12a1a0c2df113271e6"
REPORTS = {
    2: (7948, "a5f3b5619801562032913cf4f3de6e6d7fac132843a1e73a80f708bf6f784e66", "wrapperNull-0"),
    3: (7949, "f635a75d68b3b6e3f61179ee6e293db7ecd3a0ce45f60b6dbe830e345241de55", "wrapperNull-4"),
}
CALLS = (
    (2, 0, 35621490, "29364c720cdc4bcda666576556a99001344900b3cc56bb2e356575ee87a3280c"),
    (2, 1, 35764638, "dbee1a12634438351a39005f40fb7562bc2a79eeea6dbbd2840e6e4c4276c5f0"),
    (3, 0, 35639552, "d333c0f19de94ac0cfa92c5354a7e335c33e85eb0bb20d52b9aeb3f627e7de56"),
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def pin(path, data):
    return {"path": str(path.relative_to(ROOT)), "bytes": len(data), "sha256": digest(data)}


def inflate(encoded, count, sha):
    compressed = base64.b64decode(encoded, validate=True)
    inflater = zlib.decompressobj(-15)
    raw = inflater.decompress(compressed) + inflater.flush()
    assert inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail
    assert len(raw) == count and digest(raw) == sha
    return raw


def envelope(raw):
    encoder = zlib.compressobj(9, zlib.DEFLATED, -15)
    compressed = encoder.compress(raw) + encoder.flush()
    return (json.dumps({"count": len(raw), "sha256": digest(raw),
                        "deflate": base64.b64encode(compressed).decode()}, separators=(",", ":")) + "\n").encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("package", "verify"))
    parser.add_argument("--output", type=Path, required=True, help="New verification JSON; never overwrite")
    args = parser.parse_args()
    assert not args.output.exists(), args.output
    inventory_raw = (STUDY / INVENTORY).read_bytes()
    assert digest(inventory_raw) == INVENTORY_SHA
    inventory = json.loads(inventory_raw)
    bound_raw = BOUND_INDEX.read_bytes()
    assert digest(bound_raw) == BOUND_INDEX_SHA
    bound = json.loads(bound_raw)
    assert bound["schema"] == 2 and len(bound["cases"]) == 22
    input_pins = [pin(STUDY / INVENTORY, inventory_raw), pin(BOUND_INDEX, bound_raw)]
    reports = {}
    rows = {item["scenario"]: item for item in inventory["scenarios"]}
    for scenario, (count, sha, label) in REPORTS.items():
        path = STUDY / f"war-preparation-fs-errors-s{scenario:02}-capture2.json"
        raw = path.read_bytes()
        assert len(raw) == count and digest(raw) == sha
        report = json.loads(raw)
        assert report["scenarioIndex"] == scenario and report["scenario"]["label"] == label
        assert rows[scenario]["reportPin"] == {"bytes": count, "sha256": sha}
        assert Path(rows[scenario]["report"]).resolve() == path.resolve()
        reports[scenario] = report
        input_pins.append(pin(path, raw))
    excluded = rows[3]["calls"][1]
    assert excluded["ordinal"] == 1 and excluded["end"] == "sourceFault" and excluded["endPC"] == 0x40c116

    artifacts = []
    unique_blobs = {}
    prefix_digests = set()
    for scenario, ordinal, count, sha in CALLS:
        path = STUDY / f"war-preparation-fs-errors-s{scenario:02}-capture2.parts/call-{ordinal:02}.json"
        raw = path.read_bytes()
        assert len(raw) == count and digest(raw) == sha
        report = reports[scenario]
        recorded = report["calls"][ordinal]
        audited = rows[scenario]["calls"][ordinal]
        for row in (recorded, audited):
            assert row["bytes"] == count and row["sha256"] == sha and row["end"] == "returned"
            assert Path(row["path"]).resolve() == path.resolve()
        corpus = json.loads(raw)
        assert corpus["scenario"] == report["scenario"]
        assert corpus["exeSHA256"] == EXE and corpus["crtSHA256"] == CRT
        assert corpus["installation"]["libSHA256"] == LIB
        assert len(corpus["prefixProof"]) == 10
        prefix_links = []
        for index, proof in enumerate(corpus["prefixProof"]):
            reference = bound["cases"][index]
            assert proof["index"] == index == reference["index"]
            assert proof["normalizedSHA256"] == reference["sha256"]
            prefix_links.append({"index": index, "normalizedSHA256": proof["normalizedSHA256"],
                                 "boundFixture": reference["path"], "boundPosition": reference["position"]})
            prefix_digests.add(proof["normalizedSHA256"])
        case = corpus["case"]
        assert case["end"] == "returned" and case["endPC"] == recorded["endPC"]
        assert case["endSP"] == recorded["endSP"] and case["cw"] == 0x23f
        blob_bytes = 0
        for key, blob in corpus["blobs"].items():
            assert blob["sha256"] == key
            decoded = inflate(blob["deflate"], blob["count"], key)
            blob_bytes += len(decoded)
            if key in unique_blobs:
                assert unique_blobs[key] == len(decoded)
            unique_blobs[key] = len(decoded)
        packed = envelope(raw)
        transport = json.loads(packed)
        assert inflate(transport["deflate"], transport["count"], transport["sha256"]) == raw
        target = FIXTURES / f"original-lib-war-nullable-s{scenario:02}-call-{ordinal:02}.json"
        if args.operation == "package" and not target.exists():
            with target.open("xb") as handle:
                handle.write(packed)
        retained = target.read_bytes()
        assert retained == packed
        transport = json.loads(retained)
        assert inflate(transport["deflate"], transport["count"], transport["sha256"]) == raw
        assert path.read_bytes() == raw
        input_pins.append(pin(path, raw))
        artifacts.append({"scenario": scenario, "ordinal": ordinal, "source": pin(path, raw),
                          "fixture": pin(target, retained), "end": "returned", "endPC": case["endPC"],
                          "endSP": case["endSP"], "blobs": len(corpus["blobs"]), "blobBytes": blob_bytes,
                          "boundPrefixProofs": prefix_links,
                          "wholeRawRoundtripExact": True, "allBlobRoundtripsExact": True})
    result = {"schema": 1, "scope": __doc__, "operation": args.operation,
              "originalExecuted": False, "nativeCompared": False, "windowsVerified": False,
              "safetyIncidentResolved": False, "fullPreparationComplete": False, "fullGameComplete": False,
              "producerPin": pin(Path(__file__).resolve(), Path(__file__).read_bytes()),
              "inputPins": input_pins, "referenceSHA256": {"exe": EXE, "crt": CRT, "lib": LIB},
              "artifacts": artifacts, "excludedFault": excluded,
              "prefixProofScope": "Saved normalizedSHA256 equals the pinned bundled bound-index case sha256; original atomic envelope bytes/hashes differ. No fresh prefix execution or reconstruction is claimed.",
              "counts": {"returnedCalls": len(artifacts), "rawBytes": sum(x["source"]["bytes"] for x in artifacts),
                         "packedBytes": sum(x["fixture"]["bytes"] for x in artifacts),
                         "blobEntries": sum(x["blobs"] for x in artifacts),
                         "blobEntryBytes": sum(x["blobBytes"] for x in artifacts),
                         "distinctBlobs": len(unique_blobs), "distinctBlobBytes": sum(unique_blobs.values()),
                         "boundPrefixProofLinks": sum(len(x["boundPrefixProofs"]) for x in artifacts),
                         "distinctBoundPrefixes": len(prefix_digests)}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    print(json.dumps(result["counts"]))


if __name__ == "__main__":
    main()
