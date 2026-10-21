#!/usr/bin/env python3
"""ENGINE_SPLIT E7b: look for bytes copied from the original game into engine/.

The engine side is the literals of every file under engine/ (not the code
text): Swift and C string literals (UTF-8), runs of four or more integer
literals (flattened across nested arrays and tuples) encoded as u8, le16, le32
and le64 where they fit, and hex-digit strings decoded to bytes. Every
8-byte window of those sequences with at least four distinct byte values is
indexed. The original side is read by this tool only: the pinned
distribution (each DAT also decrypted with the engine's own DAT key; the EXE
and lib.dll labelled by PE section), the content packages, the test
fixtures (zlib or raw DEFLATE files inflated) and any further file or folder
named with --originals (the pinned VC80 runtime DLL, whose tables the engine
also copies). Consecutive hex strings of one array are also joined. Each
original is sampled every 8 bytes, so
any copy of 15 bytes or more is found; a hit is extended both ways to its
full length and kept when it is at least MIN_LENGTH bytes with at least
MIN_DISTINCT distinct values.

The report never contains original bytes: per hit the engine location
(path:line, literal kind, encoding), the matched length, the original
(path, variant, PE section, offset) and the first 16 hex digits of the
match's SHA-256. Each hit gets a class: the survey's expected classes
(docs/evidence/es-e7-survey.md section 3) or "unexpected".

Usage: scan_original_bytes.py REPO OUT.json [--originals PATH ...] [--min-length N]
"""
import argparse, hashlib, json, mmap, os, re, struct, sys, tempfile, time, zlib

K, STRIDE = 8, 8
DEFAULT_ORIGINALS = ["downloads/NTSD_2.4_2.0a_clean", "native/Sources/NTSDContent/Resources",
                     "native/Tests/NTSDCoreTests/Fixtures"]

# --- the engine side -------------------------------------------------------

STRING = re.compile(r'(?<![\w#])"((?:[^"\\\n]|\\.)*)"')
NUMBER = r'-?(?:0[xX][0-9a-fA-F_]+|\d[\d_]*)(?![\w.])'
RUN = re.compile(r'(?<![\w.])' + NUMBER + r'(?:\s*[\]\)\}]*\s*,\s*[\[\(\{]*\s*' + NUMBER + r')+')
HEX = re.compile(r'^(?:[0-9a-fA-F]{2}){4,}$')
HEXRUN = re.compile(r'"(?:[0-9a-fA-F]{2})+"(?:\s*[\]\)]*\s*,\s*[\[\(]*\s*"(?:[0-9a-fA-F]{2})+")+')

def unescape(text):
    out, i = bytearray(), 0
    simple = {"n": b"\n", "r": b"\r", "t": b"\t", "0": b"\0", "\\": b"\\", '"': b'"', "'": b"'"}
    while i < len(text):
        c = text[i]
        if c != "\\":
            out += c.encode("utf-8"); i += 1; continue
        n = text[i + 1] if i + 1 < len(text) else ""
        if n in simple:
            out += simple[n]; i += 2
        elif n == "u" and text[i + 2:i + 3] == "{":
            j = text.index("}", i); out += chr(int(text[i + 3:j], 16)).encode("utf-8"); i = j + 1
        elif n == "x" and re.match(r"[0-9a-fA-F]{2}", text[i + 2:i + 4]):  # C
            out.append(int(text[i + 2:i + 4], 16)); i += 4
        elif n == "(":  # Swift interpolation: a segment boundary
            out += b"\xff\xfe"; depth, i = 1, i + 2
            while i < len(text) and depth:
                depth += {"(": 1, ")": -1}.get(text[i], 0); i += 1
        else:
            out += n.encode("utf-8"); i += 2
    return [bytes(s) for s in bytes(out).split(b"\xff\xfe") if s]

def number(token):
    t = token.replace("_", "")
    neg = t.startswith("-"); t = t.lstrip("-")
    v = int(t, 16) if t[:2].lower() == "0x" else int(t)
    return -v if neg else v

def encodings(values):
    out = []
    for name, lo, hi, fmt in (("u8", -128, 255, "B"), ("le16", -32768, 65535, "<H"),
                              ("le32", -2**31, 2**32 - 1, "<I"), ("le64", -2**63, 2**64 - 1, "<Q")):
        if all(lo <= v <= hi for v in values):
            bits = 8 * struct.calcsize(fmt)
            out.append((name, b"".join(struct.pack(fmt, v % (1 << bits)) for v in values)))
    return out

def engine_sequences(root):
    seqs = []
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in sorted(files):
            path = os.path.join(base, f); rel = os.path.relpath(path, os.path.dirname(root))
            try: text = open(path, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                seqs.append((rel, 0, "binary", "raw", open(path, "rb").read())); continue
            line_at = lambda pos: text.count("\n", 0, pos) + 1
            for m in STRING.finditer(text):
                body = m.group(1); line = line_at(m.start())
                for segment in unescape(body):
                    seqs.append((rel, line, "string", "utf8", segment))
                if HEX.match(body):
                    seqs.append((rel, line, "hex", "bytes", bytes.fromhex(body)))
            for m in HEXRUN.finditer(text):  # consecutive hex strings of one array, joined
                parts = re.findall(r'"([0-9a-fA-F]+)"', m.group(0))
                seqs.append((rel, line_at(m.start()), "hex-run", "bytes", bytes.fromhex("".join(parts))))
            for m in RUN.finditer(text):
                values = [number(t) for t in re.findall(NUMBER, m.group(0))]
                if len(values) >= 4:
                    for name, data in encodings(values):
                        seqs.append((rel, line_at(m.start()), "integers", name, data))
    return seqs

def index(seqs):
    table = {}
    for n, (_, _, _, _, data) in enumerate(seqs):
        for p in range(len(data) - K + 1):
            w = data[p:p + K]
            if len(set(w)) >= 4: table.setdefault(w, []).append((n, p))
    return table

# --- the original side -----------------------------------------------------

def dat_key(repo):
    text = open(os.path.join(repo, "engine/Sources/NTSDCore/OriginalDATDecoder.swift"), encoding="utf-8").read()
    m = re.search(r'key\s*=\s*Array\("([^"]+)"\.utf8\)', text) or re.search(r'"(SiuHung[^"]*)"', text)
    return m.group(1).encode("ascii")

def decrypt(data, key):
    return bytes(data[:123]) + bytes((b - key[i % len(key)]) & 0xff for i, b in enumerate(data[123:], 123))

def pe_sections(data):
    try:
        e = struct.unpack_from("<I", data, 0x3c)[0]
        if data[e:e + 4] != b"PE\0\0": return []
        count, opt = struct.unpack_from("<H", data, e + 6)[0], struct.unpack_from("<H", data, e + 20)[0]
        out, at = [], e + 24 + opt
        for i in range(count):
            name = data[at:at + 8].rstrip(b"\0").decode("ascii", "replace")
            size, raw = struct.unpack_from("<II", data, at + 16)
            out.append((raw, raw + size, name)); at += 40
        return out
    except struct.error:
        return []

def originals(repo, roots, key, scratch):
    for root in roots:
        top = os.path.join(repo, root)
        walk = [(os.path.dirname(top), [], [os.path.basename(top)])] if os.path.isfile(top) else os.walk(top)
        for base, dirs, files in walk:
            dirs.sort()
            for f in sorted(files):
                path = os.path.join(base, f)
                rel = os.path.relpath(path, repo) if path.startswith(repo + os.sep) else path
                if f.lower().endswith(".zip"): continue
                if f.endswith(".zlib"):
                    # A zlib stream, or raw DEFLATE (Foundation's .zlib); else scanned as is.
                    out = os.path.join(scratch, "inflated")
                    for wbits in (15, -15):
                        try:
                            d = zlib.decompressobj(wbits)
                            with open(path, "rb") as src, open(out, "wb") as dst:
                                for chunk in iter(lambda: src.read(1 << 24), b""): dst.write(d.decompress(chunk))
                                dst.write(d.flush())
                            yield rel, "inflated" if wbits > 0 else "inflated-raw", out; break
                        except zlib.error:
                            continue
                    else:
                        yield rel, "raw-uninflatable", path
                    continue
                yield rel, "raw", path
                if f.lower().endswith(".dat"):
                    out = os.path.join(scratch, "decrypted")
                    open(out, "wb").write(decrypt(open(path, "rb").read(), key))
                    yield rel, "decrypted", out

# --- matching and classes --------------------------------------------------

EXPECTED = [
    (lambda p, s: "/vendor/" in p or "/CZLib/" in p or "zlib" in p.lower(), "zlib or other vendored upstream code"),
    (lambda p, s: "CALAC" in p, "CALAC (vendored upstream)"),
    (lambda p, s: p.endswith("OriginalDATDecoder.swift") or b"SiuHungIsAGood" in s, "DAT key"),
    (lambda p, s: p.endswith(("OriginalMusicPlayback.swift", "OriginalMacRuntimeMusic.swift")) and len(s) in (16, 32), "DirectShow GUIDs"),
    (lambda p, s: p.endswith("OriginalDiagnosticNumber.swift"), "VC80 power-of-ten table"),
    (lambda p, s: p.endswith(("OriginalCalendarTime.swift", "OriginalCRTRandom.swift")), "CRT constants"),
]

def classify(path, kind, seq, original, section):
    for test, name in EXPECTED:
        if test(path, seq): return name
    low = original.lower()
    if low.endswith(".json") and ("/Fixtures/" in original or "/Resources/" in original):
        return "labels shared with the project's own fixtures and manifests (JSON text, not original bytes)"
    if kind == "string":
        if low.endswith((".exe", ".dll")): return "EXE strings"
        return "names and vocabulary of the data files"
    return "unexpected"

def main():
    a = argparse.ArgumentParser(); a.add_argument("repo"); a.add_argument("out")
    a.add_argument("--originals", nargs="*", default=DEFAULT_ORIGINALS)
    a.add_argument("--min-length", type=int, default=16); a.add_argument("--min-distinct", type=int, default=6)
    o = a.parse_args(); repo = os.path.abspath(o.repo); started = time.time()
    seqs = engine_sequences(os.path.join(repo, "engine")); table = index(seqs)
    print(f"engine: {len(seqs)} literal sequences, {len(table)} indexed windows", flush=True)
    key = dat_key(repo); best = {}; scanned = files = 0
    with tempfile.TemporaryDirectory(dir=os.path.dirname(os.path.abspath(o.out))) as scratch:
        for rel, variant, path in originals(repo, o.originals, key, scratch):
            size = os.path.getsize(path); files += 1; scanned += size
            if size < K: continue
            with open(path, "rb") as fh, mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ) as data:
                sections = pe_sections(data) if rel.lower().endswith((".exe", ".dll")) and variant == "raw" else []
                get = table.get
                for i in range(0, size - K + 1, STRIDE):
                    hits = get(data[i:i + K])
                    if not hits: continue
                    for n, p in hits:
                        seq = seqs[n][4]; lo, hi = 0, K
                        while p - lo > 0 and i - lo > 0 and seq[p - lo - 1] == data[i - lo - 1]: lo += 1
                        while p + hi < len(seq) and i + hi < size and seq[p + hi] == data[i + hi]: hi += 1
                        length = lo + hi; start = i - lo
                        if length < o.min_length: continue
                        matched = bytes(data[start:start + length])
                        if len(set(matched)) < o.min_distinct: continue
                        k = (n, rel, variant)
                        if k not in best or best[k]["length"] < length:
                            sec = next((nm for s0, s1, nm in sections if s0 <= start < s1), None)
                            best[k] = {"length": length, "offset": start, "section": sec,
                                       "sha256": hashlib.sha256(matched).hexdigest()[:16],
                                       "engineSlice": [p - lo, p - lo + length]}
            if files % 500 == 0: print(f"  {files} files, {scanned >> 20} MiB, {len(best)} hits, {time.time() - started:.0f} s", flush=True)
    hits = []
    for (n, rel, variant), h in sorted(best.items(), key=lambda kv: (seqs[kv[0][0]][0], seqs[kv[0][0]][1], kv[0][1])):
        path, line, kind, enc, seq = seqs[n]
        hits.append({"engine": f"{path}:{line}", "kind": kind, "encoding": enc, "literalLength": len(seq),
                     "original": rel, "variant": variant, **h,
                     "class": classify(path, kind, seq[h["engineSlice"][0]:h["engineSlice"][1]], rel, h["section"])})
    classes = {}
    for h in hits:
        c = classes.setdefault(h["class"], {"hits": 0, "engineSites": set()}); c["hits"] += 1; c["engineSites"].add(h["engine"])
    summary = {k: {"hits": v["hits"], "engineSites": len(v["engineSites"])} for k, v in sorted(classes.items())}
    json.dump({"tool": "tools/scan_original_bytes.py", "window": K, "stride": STRIDE, "minLength": o.min_length,
               "minDistinct": o.min_distinct, "originals": o.originals, "originalFiles": files, "originalBytes": scanned,
               "engineSequences": len(seqs), "indexedWindows": len(table), "seconds": round(time.time() - started),
               "summary": summary, "hits": hits}, open(o.out, "w"), indent=1)
    print(json.dumps({"files": files, "bytes": scanned, "hits": len(hits), "summary": summary}))

if __name__ == "__main__":
    main()
