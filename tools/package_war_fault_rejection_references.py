#!/usr/bin/env python3
"""Losslessly package nine saved NTSD War source faults for Native rejection tests.

Pinned EXE/lib/VC80 observations used controlled Unicorn2.1.4/CW023f/C locale,
explicit flat segments/FS and declared bitmap/music/replay API responses. This
transports complete faulted raw records, masks, events and blobs unchanged.
Matching failure sidecars remain independent pinned evidence. Seven successful
parent calls reuse existing nullable/partial-surface fixtures without duplication.

Only saved bytes/JSON are read and verified. No original, emulator, Native,
producer import, historical auditor, fault continuation or retry executes.
All nine source outcomes remain sourceFault, not successful Native matches.
Three safety incidents and full-game/Windows/device acceptance stay open.
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
TASK = STUDY / "war-fault-rejections-native-20260912"
PLAN = TASK / "plan.json"
PLAN_SHA = "6f2627e8f94b5ae86e0afbca8b223528e09f5c5954f3674bde48f94305ca9a80"
FIXTURES = ROOT / "native/Tests/NTSDCoreTests/Fixtures"
BOUND = FIXTURES / "original-lib-war-preparation-bound.json"
BOUND_SHA = "5b49a5d4acdf0ec42a9a25a5514aa821299fbfea24a83c12a1a0c2df113271e6"
INVENTORY = STUDY / "war-errors-completion-20260912/inventory2.json"
INVENTORY_SHA = "75a96b6e5eae6b2139de5c3d807d9c17b912a41c360e0c68880e3a7211c4f6f4"
EXE = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"
CRT = "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d"
LIB = "28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba"

# Limits cover the finite pinned corpus, including reused35.7MB parent envelopes.
MAX_ENVELOPE_BYTES = 40_000_000
MAX_BLOB_BYTES = 6_491_672
SIDECAR_FIELDS = ("spec", "before", "after", "events", "writes", "reads", "apiReads", "helpers", "pending", "instructions")


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


def inflate(encoded, count, sha, maximum=MAX_ENVELOPE_BYTES):
    assert type(count) is int and 0 <= count <= maximum
    inflater = zlib.decompressobj(-15)
    raw = inflater.decompress(base64.b64decode(encoded, validate=True), count + 1)
    assert inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail
    assert inflater.flush() == b"" and len(raw) == count and digest(raw) == sha
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
        raw = inflate(item["deflate"], item["count"], sha, maximum=MAX_BLOB_BYTES)
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
    assert plan["sourceRuns"] == 0 and len(plan["inputs"]) == 98 and len(plan["protectedFixtures"]) == 361
    selected = [(item["scenario"], item["ordinal"]) for item in plan["cases"]]
    assert selected == [(i, 1) for i in range(3, 10)] + [(22, 0), (28, 0)]
    check_pins(plan["inputs"])
    check_pins(plan["protectedFixtures"])
    assert shutil.disk_usage(ROOT).free >= plan["limits"]["internalReserveBytes"]
    inventory_raw, bound_raw = INVENTORY.read_bytes(), BOUND.read_bytes()
    assert digest(inventory_raw) == INVENTORY_SHA and digest(bound_raw) == BOUND_SHA
    inventory = {item["scenario"]: item for item in json.loads(inventory_raw)["scenarios"]}
    recorded_faults = {(scenario, row["ordinal"]) for scenario, item in inventory.items()
                       for row in item["calls"] if row["end"] == "sourceFault"}
    assert recorded_faults == set(selected)
    bound = json.loads(bound_raw)
    assert bound["schema"] == 2 and len(bound["cases"]) == 22
    artifacts, parents, unique, prefix_digests = [], [], {}, set()
    for item in plan["cases"]:
        scenario, ordinal = item["scenario"], item["ordinal"]
        assert item["nativeAccepted"] is False
        report_path = STUDY / f"war-preparation-fs-errors-s{scenario:02}-capture2.json"
        report_raw = report_path.read_bytes()
        report, row = json.loads(report_raw), inventory[scenario]
        assert report["scenarioIndex"] == scenario
        assert row["reportPin"] == {"bytes": len(report_raw), "sha256": digest(report_raw)}
        assert Path(row["report"]).resolve() == report_path.resolve()
        assert len(report["calls"]) == ordinal + 1 and len(row["calls"]) == ordinal + 1
        job = json.loads(report_path.with_suffix(".job.json").read_bytes())
        assert job["status"] == "terminal" and job["exitCode"] == 0 and job["inputsUnchanged"] is True
        path = ROOT / item["rawPin"]["path"]
        expected_path = STUDY / f"war-preparation-fs-errors-s{scenario:02}-capture2.parts/call-{ordinal:02}.json"
        assert path.resolve() == expected_path.resolve()
        raw = path.read_bytes()
        assert pin(path, raw) == item["rawPin"]
        recorded = report["calls"][ordinal]
        audited = row["calls"][ordinal]
        for observed in (recorded, audited):
            for key in ("bytes", "sha256"):
                assert observed[key] == item["rawPin"][key]
            assert Path(observed["path"]).resolve() == path.resolve()
            assert observed["end"] == "sourceFault"
        expected_pc = 0x40c116 if scenario == 3 else (0x401cfe if scenario == 22 else (0x43d2fd if scenario == 28 else 0x40c118))
        corpus = json.loads(raw)
        assert corpus["exeSHA256"] == EXE and corpus["crtSHA256"] == CRT
        assert corpus["installation"]["libSHA256"] == LIB and corpus["scenario"] == report["scenario"]
        case = corpus["case"]
        for key in ("end", "endPC", "endSP"):
            assert case[key] == recorded[key] == audited[key]
        assert case["end"] == "sourceFault" and case["endPC"] == expected_pc and case["cw"] == 0x23f
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
                                 "atomicPrefix": {"path": str(atomic_path.relative_to(ROOT)), **atomic_pin}})
            prefix_digests.add(proof["normalizedSHA256"])
        blob_bytes = check_blobs(corpus["blobs"], unique)
        sidecar_path = ROOT / item["failurePin"]["path"]
        sidecar_raw = sidecar_path.read_bytes()
        assert pin(sidecar_path, sidecar_raw) == item["failurePin"]
        sidecar = json.loads(sidecar_raw)
        assert int(sidecar["pc"], 16) == expected_pc
        for key in SIDECAR_FIELDS:
            assert sidecar[key] == case[key]
        for sha, blob in sidecar["blobs"].items():
            assert blob == corpus["blobs"][sha]
        extra = sorted(set(corpus["blobs"]) - set(sidecar["blobs"]))
        # The retained s28 atomic file has one additional30-byte music blob;
        # its sidecar is an exact subset. Keep and verify both originals.
        expected_extra = ["3f602f0d44c26057387596e3793a79c92cf2cf3722b843f7fa30bd40f9bf0fb4"] if scenario == 28 else []
        assert extra == expected_extra
        if extra:
            assert corpus["blobs"][extra[0]]["count"] == 30
        parent_reference = None
        if ordinal == 1:
            parent_path = path.with_name("call-00.json")
            parent_raw = parent_path.read_bytes()
            parent_recorded, parent_audited = report["calls"][0], row["calls"][0]
            for parent in (parent_recorded, parent_audited):
                assert parent["end"] == "returned" and Path(parent["path"]).resolve() == parent_path.resolve()
                assert len(parent_raw) == parent["bytes"] and digest(parent_raw) == parent["sha256"]
            kind = "nullable" if scenario == 3 else "partial-surface"
            parent_fixture = FIXTURES / f"original-lib-war-{kind}-s{scenario:02}-call-00.json"
            assert str(parent_fixture.relative_to(ROOT)) in plan["protectedFixtures"]
            parent_packed = parent_fixture.read_bytes()
            parent_transport = json.loads(parent_packed)
            assert inflate(parent_transport["deflate"], parent_transport["count"], parent_transport["sha256"]) == parent_raw
            parent_reference = {"scenario": scenario, "source": pin(parent_path, parent_raw),
                                "existingFixture": pin(parent_fixture, parent_packed),
                                "end": "returned", "wholeRawRoundtripExact": True, "newFixtureCreated": False}
            parents.append(parent_reference)
        packed = envelope(raw)
        target = FIXTURES / f"original-lib-war-fault-rejection-s{scenario:02}-call-{ordinal:02}.json"
        if args.operation == "package" and not target.exists():
            with target.open("xb") as handle:
                handle.write(packed)
        assert target.is_file() and not target.is_symlink()
        retained = target.read_bytes()
        assert retained == packed
        transport = json.loads(retained)
        restored = inflate(transport["deflate"], transport["count"], transport["sha256"])
        assert restored == raw and json.loads(restored) == corpus and path.read_bytes() == raw
        assert sidecar_path.read_bytes() == sidecar_raw
        artifacts.append({"scenario": scenario, "ordinal": ordinal, "source": pin(path, raw),
                          "fixture": pin(target, retained), "failureSidecar": pin(sidecar_path, sidecar_raw),
                          "report": pin(report_path, report_raw), "end": "sourceFault", "endPC": expected_pc,
                          "nativeCompared": False, "nativeAccepted": False,
                          "blobs": len(corpus["blobs"]), "blobBytes": blob_bytes,
                          "sidecarBlobs": len(sidecar["blobs"]),
                          "sidecarBlobBytes": sum(blob["count"] for blob in sidecar["blobs"].values()),
                          "sidecarFieldsExact": list(SIDECAR_FIELDS), "allSidecarBlobsEqualVerifiedRawBlobs": True,
                          "rawOnlyBlobKeys": extra, "parentReference": parent_reference,
                          "boundPrefixProofs": prefix_links, "wholeRawAndJSONRoundtripExact": True,
                          "allBlobRoundtripsExact": True})
    assert len(artifacts) == 9 and len(prefix_digests) == 10 and len(parents) == 7
    check_pins(plan["inputs"])
    check_pins(plan["protectedFixtures"])
    counts = {"sourceFaultCalls": len(artifacts), "returnedCallsPackaged": 0,
              "rawBytes": sum(x["source"]["bytes"] for x in artifacts),
              "packedBytes": sum(x["fixture"]["bytes"] for x in artifacts),
              "blobEntries": sum(x["blobs"] for x in artifacts), "blobEntryBytes": sum(x["blobBytes"] for x in artifacts),
              "distinctBlobs": len(unique), "distinctBlobBytes": sum(unique.values()),
              "maximumBlobBytes": max(unique.values()), "sidecars": len(artifacts),
              "sidecarRawBytes": sum(x["failureSidecar"]["bytes"] for x in artifacts),
              "sidecarBlobEntriesEqualVerifiedRawBlobs": sum(x["sidecarBlobs"] for x in artifacts),
              "sidecarBlobEntryBytes": sum(x["sidecarBlobBytes"] for x in artifacts),
              "boundPrefixProofLinks": sum(len(x["boundPrefixProofs"]) for x in artifacts),
              "distinctBoundPrefixes": len(prefix_digests), "existingParentFixturesReused": len(parents),
              "sourceEvidencePinsUnchanged": 98, "oldFixturesUnchanged": 361}
    assert counts["rawBytes"] == plan["counts"]["rawBytes"]
    result = {"schema": 1, "scope": __doc__, "operation": args.operation, "originalExecuted": False,
              "nativeCompared": False, "nativeFaultsAcceptedAsMatches": False, "windowsVerified": False,
              "safetyIncidentResolved": False, "fullPreparationComplete": False, "fullGameComplete": False,
              "producerPin": pin(Path(__file__).resolve()), "planPin": pin(PLAN, plan_raw),
              "inventoryPin": pin(INVENTORY, inventory_raw), "boundIndexPin": pin(BOUND, bound_raw),
              "sourceEvidencePins": plan["inputs"], "referenceSHA256": {"exe": EXE, "crt": CRT, "lib": LIB},
              "artifacts": artifacts, "existingParentReferences": parents,
              "inflationLimits": {"blobBytes": MAX_BLOB_BYTES, "rawEnvelopeBytes": MAX_ENVELOPE_BYTES},
              "prefixProofScope": "Saved normalizedSHA256 equals the pinned bundled bound-index case SHA; each raw atomic prefix pin is separately verified. No fresh source prefix execution or reconstruction.",
              "counts": counts}
    with args.output.open("x") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    print(json.dumps(counts))


if __name__ == "__main__":
    main()
