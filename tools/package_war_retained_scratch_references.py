#!/usr/bin/env python3
"""Losslessly package two saved, returned NTSD War retained-scratch calls.

Pinned EXE/lib/VC80 observations used controlled Unicorn2.1.4/CW023f/C locale
and declared first-layer GetObject0 / GetSurfaceDesc-1 responses. Complete raw
records, masks, event order, owners and blobs are preserved for Native recovery
of bitmap fields retained from earlier War-menu producers. No source private
storage is turned into Native input or newly declared known by this packaging.

This tool only reads retained reports, inventory, plans and atomic JSON,
verifies their pins and DEFLATE roundtrips, and publishes two new fixtures.
It imports no source producer and executes no original, emulator, old auditor
or Native code. Each selected scenario has exactly one normal return. Nine
historical source faults and three safety incidents stay separate and open;
no fault archive, retry, continuation, Windows/device or full-game acceptance
is introduced by this packaging.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil
import zlib


ROOT = Path(__file__).resolve().parents[1]
STUDY = ROOT / "build/research/lib-war-preparation"
TASK = STUDY / "war-retained-scratch-native-20260912"
PLAN = TASK / "plan.json"
PLAN_SHA = "2f8d19d36cf2ee3b22755934f54945211d6826d7e1421d2a5e800ca8ccf4b28e"
FIXTURES = ROOT / "native/Tests/NTSDCoreTests/Fixtures"
BOUND = FIXTURES / "original-lib-war-preparation-bound.json"
BOUND_SHA = "5b49a5d4acdf0ec42a9a25a5514aa821299fbfea24a83c12a1a0c2df113271e6"
INVENTORY = STUDY / "war-errors-completion-20260912/inventory2.json"
INVENTORY_SHA = "75a96b6e5eae6b2139de5c3d807d9c17b912a41c360e0c68880e3a7211c4f6f4"
EXE = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"
CRT = "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d"
LIB = "28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_digest(path):
    result = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def pin(path, raw=None):
    return {"path": str(path.relative_to(ROOT)), "bytes": len(raw) if raw is not None else path.stat().st_size,
            "sha256": digest(raw) if raw is not None else file_digest(path)}


def check_pins(pins):
    for name, expected in pins.items():
        path = ROOT / name
        assert path.stat().st_size == expected["bytes"] and file_digest(path) == expected["sha256"], name


def inflate(encoded, count, sha):
    inflater = zlib.decompressobj(-15)
    raw = inflater.decompress(base64.b64decode(encoded, validate=True)) + inflater.flush()
    assert inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail
    assert len(raw) == count and digest(raw) == sha
    return raw


def envelope(raw):
    encoder = zlib.compressobj(9, zlib.DEFLATED, -15)
    packed = encoder.compress(raw) + encoder.flush()
    return (json.dumps({"count": len(raw), "sha256": digest(raw),
                        "deflate": base64.b64encode(packed).decode()}, separators=(",", ":")) + "\n").encode()


def check_blobs(blobs, unique):
    count = 0
    for sha, item in blobs.items():
        assert item["sha256"] == sha
        raw = inflate(item["deflate"], item["count"], sha)
        count += len(raw)
        if sha in unique:
            assert unique[sha] == len(raw)
        unique[sha] = len(raw)
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("package", "verify"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert args.output.parent.resolve() == TASK.resolve() and not args.output.exists()
    plan_raw = PLAN.read_bytes()
    assert digest(plan_raw) == PLAN_SHA
    plan = json.loads(plan_raw)
    assert TASK.resolve() == Path(plan["storage"]["directory"])
    assert plan["sourceRuns"] == 0 and len(plan["inputs"]) == 34 and len(plan["protectedFixtures"]) == 359
    assert [(item["scenario"], item["ordinal"]) for item in plan["cases"]] == [(10, 0), (11, 0)]
    check_pins(plan["inputs"])
    check_pins(plan["protectedFixtures"])
    assert shutil.disk_usage(ROOT).free >= plan["limits"]["internalReserveBytes"]
    inventory_raw, bound_raw = INVENTORY.read_bytes(), BOUND.read_bytes()
    assert digest(inventory_raw) == INVENTORY_SHA and digest(bound_raw) == BOUND_SHA
    inventory = {item["scenario"]: item for item in json.loads(inventory_raw)["scenarios"]}
    previous_faults = [{"scenario": scenario, "call": row} for scenario, item in inventory.items()
                       for row in item["calls"] if row["end"] == "sourceFault"]
    assert len(previous_faults) == 9
    bound = json.loads(bound_raw)
    assert bound["schema"] == 2 and len(bound["cases"]) == 22
    artifacts, unique, prefix_digests = [], {}, set()
    for item in plan["cases"]:
        scenario, expected = item["scenario"], item["source"]
        report_path = STUDY / f"war-preparation-fs-errors-s{scenario:02}-capture2.json"
        report_raw = report_path.read_bytes()
        report, row = json.loads(report_raw), inventory[scenario]
        assert report["scenarioIndex"] == scenario and report["scenario"] == item["input"]
        assert row["reportPin"] == {"bytes": len(report_raw), "sha256": digest(report_raw)}
        assert Path(row["report"]).resolve() == report_path.resolve()
        assert len(report["calls"]) == 1 and len(row["calls"]) == 1
        job = json.loads(report_path.with_suffix(".job.json").read_bytes())
        assert job["status"] == "terminal" and job["exitCode"] == 0 and job["inputsUnchanged"] is True
        path = STUDY / f"war-preparation-fs-errors-s{scenario:02}-capture2.parts/call-00.json"
        raw = path.read_bytes()
        assert len(raw) == expected["bytes"] and digest(raw) == expected["sha256"]
        assert Path(expected["path"]).resolve() == path.resolve()
        for recorded in (report["calls"][0], row["calls"][0]):
            for key in ("bytes", "sha256", "end", "endPC", "endSP"):
                assert recorded[key] == expected[key]
            assert Path(recorded["path"]).resolve() == path.resolve()
        corpus = json.loads(raw)
        assert corpus["exeSHA256"] == EXE and corpus["crtSHA256"] == CRT
        assert corpus["installation"]["libSHA256"] == LIB and corpus["scenario"] == item["input"]
        case = corpus["case"]
        for key in ("end", "endPC", "endSP"):
            assert case[key] == expected[key]
        assert case["end"] == "returned" and case["cw"] == 0x23f
        assert case["resourceFailureInput"]["declared"] == item["input"]
        assert len(corpus["prefixProof"]) == 10
        prefix_links = []
        for index, proof in enumerate(corpus["prefixProof"]):
            reference = bound["cases"][index]
            assert proof["index"] == index == reference["index"]
            assert proof["normalizedSHA256"] == reference["sha256"]
            atomic_path = STUDY / f"war-preparation-bound-capture1.parts/{index:04}.json"
            atomic_pin = plan["inputs"][str(atomic_path.relative_to(ROOT))]
            assert Path(proof["path"]).resolve() == atomic_path.resolve()
            assert proof["bytes"] == atomic_pin["bytes"] and proof["sha256"] == atomic_pin["sha256"]
            prefix_links.append({"index": index, "normalizedSHA256": proof["normalizedSHA256"],
                                 "boundFixture": reference["path"], "boundPosition": reference["position"],
                                 "atomicPrefix": {"path": str(atomic_path.relative_to(ROOT)), **atomic_pin},
                                 "rawAtomicPrefixPinVerified": True})
            prefix_digests.add(proof["normalizedSHA256"])
        blob_bytes = check_blobs(corpus["blobs"], unique)
        packed = envelope(raw)
        target = FIXTURES / f"original-lib-war-retained-scratch-s{scenario:02}-call-00.json"
        if args.operation == "package" and not target.exists():
            with target.open("xb") as handle:
                handle.write(packed)
        assert target.is_file() and not target.is_symlink()
        retained = target.read_bytes()
        assert retained == packed
        transport = json.loads(retained)
        restored = inflate(transport["deflate"], transport["count"], transport["sha256"])
        assert restored == raw and json.loads(restored) == corpus and path.read_bytes() == raw
        artifacts.append({"scenario": scenario, "source": pin(path, raw), "fixture": pin(target, retained),
                          "report": pin(report_path, report_raw), "end": "returned",
                          "blobs": len(corpus["blobs"]), "blobBytes": blob_bytes,
                          "boundPrefixProofs": prefix_links, "wholeRawAndJSONRoundtripExact": True,
                          "allBlobRoundtripsExact": True})
    assert len(artifacts) == 2 and len(prefix_digests) == 10
    check_pins(plan["inputs"])
    check_pins(plan["protectedFixtures"])
    counts = {"returnedCalls": len(artifacts), "rawBytes": sum(x["source"]["bytes"] for x in artifacts),
              "packedBytes": sum(x["fixture"]["bytes"] for x in artifacts),
              "blobEntries": sum(x["blobs"] for x in artifacts), "blobEntryBytes": sum(x["blobBytes"] for x in artifacts),
              "distinctBlobs": len(unique), "distinctBlobBytes": sum(unique.values()),
              "boundPrefixProofLinks": sum(len(x["boundPrefixProofs"]) for x in artifacts),
              "distinctBoundPrefixes": len(prefix_digests), "selectedSourceFaults": 0,
              "historicalSourceFaultsExcluded": len(previous_faults),
              "sourceEvidencePinsUnchanged": 34, "oldFixturesUnchanged": 359}
    result = {"schema": 1, "scope": __doc__, "operation": args.operation, "originalExecuted": False,
              "nativeCompared": False, "windowsVerified": False, "safetyIncidentResolved": False,
              "fullPreparationComplete": False, "fullGameComplete": False,
              "producerPin": pin(Path(__file__).resolve()), "planPin": pin(PLAN, plan_raw),
              "inventoryPin": pin(INVENTORY, inventory_raw), "boundIndexPin": pin(BOUND, bound_raw),
              "sourceEvidencePins": plan["inputs"], "referenceSHA256": {"exe": EXE, "crt": CRT, "lib": LIB},
              "artifacts": artifacts, "historicalSourceFaultsExcluded": previous_faults,
              "prefixProofScope": "Saved normalizedSHA256 equals the pinned bundled bound-index case SHA; original atomic envelope bytes/hashes differ. No fresh source prefix execution or reconstruction.",
              "counts": counts}
    with args.output.open("x") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    print(json.dumps(counts))


if __name__ == "__main__":
    main()
