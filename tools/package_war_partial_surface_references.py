#!/usr/bin/env python3
"""Package six saved, returned NTSD War partial-surface calls without execution.

The pinned EXE/lib/VC80 observations used controlled Unicorn2.1.4/CW023f/C
locale and declared image/CreateSurface/SetColorKey failures at the first/last
arena layer. Complete raw records, masks, events, owners and blobs are retained
to compare Native preparation. This tool only reads saved data, verifies pins,
and transports bytes; it imports no producer and runs no original/Native code.
Six following source faults and their sidecars are verified and archived apart
from the six returned fixtures. No fault is resumed, relabelled or accepted as
a Native match. Existing safety incidents and full-game/Windows claims stay open.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil
import stat
import tarfile
import zlib


ROOT = Path(__file__).resolve().parents[1]
STUDY = ROOT / "build/research/lib-war-preparation"
TASK = STUDY / "war-partial-surfaces-native-20260912"
PLAN = TASK / "plan.json"
PLAN_SHA = "b4af8cc9de32b828e6433998d9662318d494f7881b0c7498321f5b8980d53361"
FIXTURES = ROOT / "native/Tests/NTSDCoreTests/Fixtures"
BOUND = FIXTURES / "original-lib-war-preparation-bound.json"
BOUND_SHA = "5b49a5d4acdf0ec42a9a25a5514aa821299fbfea24a83c12a1a0c2df113271e6"
INVENTORY = STUDY / "war-errors-completion-20260912/inventory2.json"
INVENTORY_SHA = "75a96b6e5eae6b2139de5c3d807d9c17b912a41c360e0c68880e3a7211c4f6f4"
EXE = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"
CRT = "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d"
LIB = "28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba"
FAULT_KEYS = ("spec", "before", "after", "events", "writes", "reads", "apiReads", "helpers", "pending", "instructions")


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


def check_metadata(corpus, expected, scenario):
    assert corpus["exeSHA256"] == EXE and corpus["crtSHA256"] == CRT
    assert corpus["installation"]["libSHA256"] == LIB and corpus["scenario"] == scenario
    case = corpus["case"]
    for key in ("end", "endPC", "endSP"):
        assert case[key] == expected[key]
    assert case["cw"] == 0x23f


def archive_faults(paths, target, operation):
    if operation == "package" and not target.exists():
        with tarfile.open(target, "x:gz", compresslevel=1) as archive:
            for path in paths:
                assert path.is_file() and not path.is_symlink()
                archive.add(path, arcname=str(path.relative_to(STUDY)), recursive=False)
    members = []
    expected = {str(path.relative_to(STUDY)): path for path in paths}
    with tarfile.open(target, "r:gz") as archive:
        table = archive.getmembers()
        assert len(table) == len(expected) and {member.name for member in table} == set(expected)
        for member in table:
            path = expected[member.name]
            assert member.isfile() and member.size == path.stat().st_size
            assert member.mode == stat.S_IMODE(path.stat().st_mode)
            assert member.mtime == path.stat().st_mtime
            with archive.extractfile(member) as handle:
                raw = handle.read()
            assert raw == path.read_bytes()
            members.append({"name": member.name, "bytes": len(raw), "sha256": digest(raw),
                            "mode": member.mode, "mtime": member.mtime})
    return {"archive": pin(target), "members": members, "memberCount": len(members),
            "rawBytes": sum(item["bytes"] for item in members), "allMemberBytesExact": True}


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
    assert plan["sourceRuns"] == 0 and len(plan["inputs"]) == 46 and len(plan["protectedFixtures"]) == 336
    assert [item["scenario"] for item in plan["cases"]] == list(range(4, 10))
    check_pins(plan["inputs"])
    check_pins(plan["protectedFixtures"])
    assert shutil.disk_usage(ROOT).free >= plan["limits"]["internalReserveBytes"]
    inventory_raw, bound_raw = INVENTORY.read_bytes(), BOUND.read_bytes()
    assert digest(inventory_raw) == INVENTORY_SHA and digest(bound_raw) == BOUND_SHA
    inventory = {item["scenario"]: item for item in json.loads(inventory_raw)["scenarios"]}
    bound = json.loads(bound_raw)
    assert bound["schema"] == 2 and len(bound["cases"]) == 22
    artifacts, faults, fault_paths = [], [], []
    returned_unique, fault_unique, prefix_digests = {}, {}, set()
    for item in plan["cases"]:
        scenario = item["scenario"]
        report_path = STUDY / f"war-preparation-fs-errors-s{scenario:02}-capture2.json"
        report = json.loads(report_path.read_bytes())
        row = inventory[scenario]
        assert report["scenarioIndex"] == scenario and report["scenario"] == item["input"]
        assert row["reportPin"] == {key: pin(report_path)[key] for key in ("bytes", "sha256")}
        assert Path(row["report"]).resolve() == report_path.resolve()
        job = json.loads(report_path.with_suffix(".job.json").read_bytes())
        assert job["status"] == "terminal" and job["exitCode"] == 0 and job["inputsUnchanged"] is True
        for ordinal, expected in ((0, item["source"]), (1, item["separateFault"])):
            path = STUDY / f"war-preparation-fs-errors-s{scenario:02}-capture2.parts/call-{ordinal:02}.json"
            raw = path.read_bytes()
            assert len(raw) == expected["bytes"] and digest(raw) == expected["sha256"]
            for recorded in (report["calls"][ordinal], row["calls"][ordinal]):
                for key in ("bytes", "sha256", "end", "endPC", "endSP"):
                    assert recorded[key] == expected[key]
                assert Path(recorded["path"]).resolve() == path.resolve()
            corpus = json.loads(raw)
            check_metadata(corpus, expected, item["input"])
            if ordinal == 1:
                assert expected["end"] == "sourceFault" and expected["endPC"] == 0x40c118
                sidecar_path = path.with_name("call-01.failure.json")
                sidecar = json.loads(sidecar_path.read_bytes())
                assert int(sidecar["pc"], 16) == expected["endPC"]
                for key in FAULT_KEYS:
                    assert sidecar[key] == corpus["case"][key]
                assert sidecar["blobs"] == corpus["blobs"]
                blob_bytes = check_blobs(corpus["blobs"], fault_unique)
                faults.append({"scenario": scenario, "call": pin(path, raw), "sidecar": pin(sidecar_path),
                               "end": "sourceFault", "endPC": expected["endPC"], "blobs": len(corpus["blobs"]),
                               "blobBytes": blob_bytes, "sidecarFieldsExact": list(FAULT_KEYS),
                               "sidecarBlobsExactlyEqualVerifiedCallBlobs": True, "nativeMatch": False})
                fault_paths.extend((path, sidecar_path))
                continue
            assert expected["end"] == "returned" and len(corpus["prefixProof"]) == 10
            prefix_links = []
            for index, proof in enumerate(corpus["prefixProof"]):
                reference = bound["cases"][index]
                assert proof["index"] == index == reference["index"]
                assert proof["normalizedSHA256"] == reference["sha256"]
                prefix_links.append({"index": index, "normalizedSHA256": proof["normalizedSHA256"],
                                     "boundFixture": reference["path"], "boundPosition": reference["position"]})
                prefix_digests.add(proof["normalizedSHA256"])
            blob_bytes = check_blobs(corpus["blobs"], returned_unique)
            packed = envelope(raw)
            target = FIXTURES / f"original-lib-war-partial-surface-s{scenario:02}-call-00.json"
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
                              "end": "returned", "blobs": len(corpus["blobs"]), "blobBytes": blob_bytes,
                              "boundPrefixProofs": prefix_links, "wholeRawAndJSONRoundtripExact": True,
                              "allBlobRoundtripsExact": True})
    fault_archive = archive_faults(fault_paths, TASK / "fault-preservation1.tar.gz", args.operation)
    check_pins(plan["inputs"])
    check_pins(plan["protectedFixtures"])
    counts = {"returnedCalls": len(artifacts), "rawBytes": sum(x["source"]["bytes"] for x in artifacts),
              "packedBytes": sum(x["fixture"]["bytes"] for x in artifacts),
              "blobEntries": sum(x["blobs"] for x in artifacts), "blobEntryBytes": sum(x["blobBytes"] for x in artifacts),
              "distinctBlobs": len(returned_unique), "distinctBlobBytes": sum(returned_unique.values()),
              "boundPrefixProofLinks": sum(len(x["boundPrefixProofs"]) for x in artifacts),
              "distinctBoundPrefixes": len(prefix_digests), "separateSourceFaults": len(faults),
              "faultBlobEntries": sum(x["blobs"] for x in faults), "faultBlobEntryBytes": sum(x["blobBytes"] for x in faults),
              "distinctFaultBlobs": len(fault_unique), "distinctFaultBlobBytes": sum(fault_unique.values()),
              "sidecarBlobEntriesEqualVerifiedFaultBlobs": sum(x["blobs"] for x in faults),
              "sourceEvidencePinsUnchanged": 46, "oldFixturesUnchanged": 336}
    result = {"schema": 1, "scope": __doc__, "operation": args.operation, "originalExecuted": False,
              "nativeCompared": False, "windowsVerified": False, "safetyIncidentResolved": False,
              "fullPreparationComplete": False, "fullGameComplete": False,
              "producerPin": pin(Path(__file__).resolve()), "planPin": pin(PLAN, plan_raw),
              "inventoryPin": pin(INVENTORY, inventory_raw), "boundIndexPin": pin(BOUND, bound_raw),
              "sourceEvidencePins": plan["inputs"], "referenceSHA256": {"exe": EXE, "crt": CRT, "lib": LIB},
              "artifacts": artifacts, "separateFaults": faults, "faultPreservation": fault_archive,
              "prefixProofScope": "Saved normalizedSHA256 equals the pinned bundled bound-index case SHA; original atomic envelope bytes/hashes differ. No fresh source prefix execution or reconstruction.",
              "counts": counts}
    with args.output.open("x") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    print(json.dumps(counts))


if __name__ == "__main__":
    main()
