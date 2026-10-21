#!/usr/bin/env python3
"""ENGINE_SPLIT E6a: compare two PE files of one layout, section by section.

Prints, as JSON, each file's size, image base, entry, PE timestamp and section
table (with each section's SHA-256), then for every section both files map
at the same RVA the number of differing bytes and, for sections listed with
--ranges (default .text, .rdata, .data), the differing runs as virtual
addresses and lengths. Two runs closer than two bytes are joined. Never
prints byte values.

Usage: compare_pe_sections.py A.exe B.exe [--ranges .text .rdata .data]
"""
import argparse, hashlib, json, struct

def pe(path):
    d = open(path, "rb").read(); e = struct.unpack_from("<I", d, 0x3c)[0]
    if d[e:e + 4] != b"PE\0\0": raise SystemExit(f"{path}: not a PE file")
    count, opt = struct.unpack_from("<HH", d, e + 6)[0], struct.unpack_from("<H", d, e + 20)[0]
    entry, base = struct.unpack_from("<I", d, e + 40)[0], struct.unpack_from("<I", d, e + 52)[0]
    sections, at = [], e + 24 + opt
    for _ in range(count):
        name = d[at:at + 8].rstrip(b"\0").decode("ascii", "replace")
        vsize, va, rsize, raw = struct.unpack_from("<IIII", d, at + 8); at += 40
        sections.append({"name": name, "va": va, "vsize": vsize, "raw": raw, "rsize": rsize,
                         "sha256": hashlib.sha256(d[raw:raw + rsize]).hexdigest()})
    return d, {"size": len(d), "sha256": hashlib.sha256(d).hexdigest(), "base": base, "entry": base + entry,
               "timestamp": struct.unpack_from("<I", d, e + 8)[0], "sections": sections}

def main():
    a = argparse.ArgumentParser(); a.add_argument("a"); a.add_argument("b")
    a.add_argument("--ranges", nargs="*", default=[".text", ".rdata", ".data"]); o = a.parse_args()
    (da, ha), (db, hb) = pe(o.a), pe(o.b)
    out = {"a": {"path": o.a, **ha}, "b": {"path": o.b, **hb}, "sections": []}
    for sa in ha["sections"]:
        sb = next((s for s in hb["sections"] if s["name"] == sa["name"]), None)
        if sb is None: out["sections"].append({"name": sa["name"], "only": "a"}); continue
        lo, hi = max(sa["va"], sb["va"]), min(sa["va"] + sa["rsize"], sb["va"] + sb["rsize"])
        x = da[sa["raw"] + lo - sa["va"]:sa["raw"] + hi - sa["va"]]; y = db[sb["raw"] + lo - sb["va"]:sb["raw"] + hi - sb["va"]]
        row = {"name": sa["name"], "commonRVA": [lo, hi], "differing": sum(p != q for p, q in zip(x, y)),
               "sameHeader": all(sa[k] == sb[k] for k in ("va", "vsize", "raw", "rsize"))}
        if sa["name"] in o.ranges:
            runs, i = [], 0
            while i < len(x):
                if x[i] == y[i]: i += 1; continue
                j = i
                while j < len(x) and (x[j] != y[j] or (j + 1 < len(x) and x[j + 1] != y[j + 1])): j += 1
                runs.append({"va": f"{ha['base'] + lo + i:#x}", "length": j - i}); i = j
            row["runs"] = runs
        out["sections"].append(row)
    for sb in hb["sections"]:
        if not any(s["name"] == sb["name"] for s in ha["sections"]): out["sections"].append({"name": sb["name"], "only": "b"})
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
