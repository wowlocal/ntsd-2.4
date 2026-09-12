#!/usr/bin/env python3
"""Package existing NTSD catalog/file observations; never execute the game.

The three complete 4122f0 corpora and Object control are transported byte for
byte. The explicitly scoped first-Object file projection preserves all 51 file
events (with original ordinals), five files, the decoder boundary, virtual files
and every blob they reference. It is not the full first-Object/caller trace.
Pinned EXE/VC80 observations came from controlled reference tooling, not Windows
or native device execution. This tool only reads retained JSON and verifies
raw DEFLATE, hashes and the declared projection before publishing new fixtures.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import zlib


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "native/Tests/NTSDCoreTests/Fixtures"
SOURCES = (
    ("build/original/loaded-catalog.json", "original-loaded-catalog-files", 95289959,
     "8ff43ea70036d84dbbea5309387176595658b0246aa3ff5773e8e22d08f12dee"),
    ("build/original/loaded-catalog-raw-zero.json", "original-loaded-catalog-files-raw-zero", 95252389,
     "7c9c839ea3cea8733ddb4c4e8ec9218ee4b982dc1ca8df52632d381efa40dd40"),
    ("build/original/loaded-catalog-interleaved.json", "original-loaded-catalog-files-interleaved", 5383412,
     "57d71e09189e52254d03b78d0c2f66cdbc1011acadb0e389c88968a30ed8419c"),
    ("build/original/objects-probe.json", "original-loading-files-weapon-control", 3400976,
     "a55aa30fc50fafc885957c8682fb646820f12f4bf80db6cf493349917a4979de"),
)
FIRST_OBJECT = ("build/research/application-catalog-probe8-nominal-object.json", 37673163,
                "5e62f4828793afcf4c8a3de60de67392965d9d9894279349a873cee35b4a9692")
NEGATIVE_CLOSE = ("build/research/application-catalog-file-close-negative1.json", 37044483,
                  "7d6ef2ce704e6716a7ffc6b873e21894bd8d951932bf797660dba52c7ae9f632")
EXE = "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"
CRT = "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d"
FILE_KINDS = {"openFile", "readFile", "writeFile", "closeReadFile", "closeOutputDescriptor"}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_source(path, count, sha):
    raw = (ROOT / path).read_bytes()
    assert len(raw) == count and digest(raw) == sha, path
    return raw


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=True, separators=(",", ":")) + "\n").encode()


def envelope(raw, source, scope):
    encoder = zlib.compressobj(9, zlib.DEFLATED, -15)
    compressed = encoder.compress(raw) + encoder.flush()
    return json_bytes({"format": "raw-deflate-json-v1", "source": source, "scope": scope,
                       "count": len(raw), "sha256": digest(raw),
                       "deflate": base64.b64encode(compressed).decode()})


def unpack(packed):
    item = json.loads(packed)
    inflater = zlib.decompressobj(-15)
    raw = inflater.decompress(base64.b64decode(item["deflate"], validate=True)) + inflater.flush()
    assert inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail
    assert len(raw) == item["count"] and digest(raw) == item["sha256"]
    return raw


def file_projection(source, source_pin):
    corpus = json.loads(source)
    assert corpus["exeSHA256"] == EXE and corpus["crtSHA256"] == CRT
    case = corpus["case"]
    events = [{"ordinal": index, "event": event} for index, event in enumerate(case["events"])
              if event.get("kind") in FILE_KINDS]
    assert len(events) == 51 and len(case["files"]) == 5 and len(case["decoders"]) == 1
    selected = {"files": case["files"], "decoders": case["decoders"],
                "fileEvents": events, "virtualFiles": case["virtualFiles"],
                "sourceEventCount": len(case["events"])}
    if source_pin == NEGATIVE_CLOSE:
        responses = case["closeResponses"]
        assert len(responses) == 4 and all(item["result"] == -1 for item in responses)
        assert case["decoders"][0]["result"] == 0xffffffff
        selected["closeResponses"] = responses
    references = set()

    def visit(value):
        if isinstance(value, dict):
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
        elif isinstance(value, str) and value in corpus["blobs"]:
            references.add(value)

    visit(selected)
    blobs = {key: corpus["blobs"][key] for key in sorted(references)}
    for key, blob in blobs.items():
        raw = zlib.decompress(base64.b64decode(blob["deflate"]), -15)
        assert len(raw) == blob["count"] and digest(raw) == key == blob["sha256"]
    return json_bytes({"schema": 1,
                       "scope": "Exact file-only projection; no parser/output interleaving, private CRT ABI or full caller comparison",
                       "source": {"path": source_pin[0], "count": len(source), "sha256": digest(source)},
                       "exeSHA256": EXE, "crtSHA256": CRT, "libSHA256": corpus["libSHA256"],
                       "case": selected, "blobs": blobs})


def artifacts():
    for path, name, count, sha in SOURCES:
        raw = read_source(path, count, sha)
        yield name, raw, path, "Complete retained raw JSON, unchanged bytes including scans and all events"
    for name, pin in (("original-loading-files-first-object", FIRST_OBJECT),
                      ("original-loading-files-negative-close", NEGATIVE_CLOSE)):
        path, count, sha = pin
        raw = file_projection(read_source(path, count, sha), pin)
        yield name, raw, path, "Declared file-only projection; source raw remains archived"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("package", "verify"))
    parser.add_argument("--output", type=Path, required=True, help="New verification report; never overwrite")
    args = parser.parse_args()
    assert not args.output.exists(), args.output
    reports = []
    for name, raw, source, scope in artifacts():
        target = FIXTURES / (name + ".json")
        packed = envelope(raw, source, scope)
        assert unpack(packed) == raw
        if args.operation == "package" and not target.exists():
            with target.open("xb") as handle:
                handle.write(packed)
        retained = target.read_bytes()
        assert retained == packed and unpack(retained) == raw
        reports.append({"path": str(target.relative_to(ROOT)), "bytes": len(retained), "sha256": digest(retained),
                        "unpackedBytes": len(raw), "unpackedSHA256": digest(raw), "source": source, "scope": scope})
    result = {"schema": 1, "operation": args.operation, "sourceExecuted": False,
              "nativeCompared": False, "artifacts": reports, "allRoundtripsExact": True,
              "sourcePins": [{"path": p, "bytes": n, "sha256": h} for p, _, n, h in SOURCES] +
                            [{"path": pin[0], "bytes": pin[1], "sha256": pin[2]}
                             for pin in (FIRST_OBJECT, NEGATIVE_CLOSE)]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("xb") as handle:
        handle.write(json.dumps(result, indent=2).encode() + b"\n")
    print(json.dumps({"artifacts": len(reports), "packedBytes": sum(x["bytes"] for x in reports),
                      "unpackedBytes": sum(x["unpackedBytes"] for x in reports), "verified": True}))


if __name__ == "__main__":
    main()
