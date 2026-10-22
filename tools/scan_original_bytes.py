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
                              [--engine-files DIR] [--policy]

--engine-files indexes the raw bytes of every file under DIR instead of the
literals of engine/ (ENGINE_SPLIT E7c: a generated synthetic content pack).

--policy (ENGINE_SPLIT E7e-2) adds the policy for each class (POLICY: the
user's for the classes E7b's recommendations named, settled 2026-10-21, the
loop's for the rest) to the report and exits 1 when a hit is in a removed
class, unexpected and not one of the EXAMINED coincidences, or in a PINNED
class without its pinned digest; classes still open are listed, not failed.
With --lf2-exe (the pinned LF2 2.0a lf2.exe, kept outside the repository)
each "EXE strings (LF2 2.0a .rdata)" hit is also checked at the same offset
in that file; a hit whose bytes differ there is NTSD-only (ENGINE_SPLIT E6a-2).
It refuses (exit 2) a run whose originals are missing or empty, lack the
VC80 DLL, or change --min-length/--min-distinct, and it keeps every match
region of a literal (as file mode does), not only the longest.
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
                if f.lower().endswith(".zip") or f.startswith("._"): continue
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

PROJECT_JSON = "labels shared with the project's own fixtures and manifests (JSON text, not original bytes)"

def project_json(original, variant):
    """The project's own JSON text: a fixture or manifest .json, or an inflated fixture."""
    low = original.lower()
    return (low.endswith(".json") and ("/Fixtures/" in original or "/Resources/" in original)) or \
           (variant.startswith("inflated") and "/Fixtures/" in original)

# The policy for the classes: (rule, by, why). "user": the classes E7b's
# recommendations named, accepted by the user 2026-10-21; "loop": the loop's
# rule for classes those did not name. "keep" stays in the published engine,
# "removed" fails a hit, "open" is reported until its step settles it.
POLICY = {
    "zlib or other vendored upstream code": ("keep", "user", "licensed upstream code (zlib licence), not the game's"),
    "CALAC (vendored upstream)": ("keep", "loop", "licensed upstream code (Apache-2.0), not the game's"),
    "DAT key": ("keep", "user", "the format constant every LF2-format DAT is encrypted with"),
    "DirectShow GUIDs": ("keep", "user", "Microsoft's public interface and class IDs"),
    "VC80 power-of-ten table": ("removed", "user", "computed since E7e-1"),
    "CRT constants": ("keep", "loop", "public C runtime algorithm constants"),
    "EXE strings (LF2 2.0a .rdata)": ("keep", "user", "D1's rule, LF2's text stays engine text: NTSD 2.4.exe's .rdata equals LF2 2.0a lf2.exe's outside NTSD_RDATA_RUN (E6a)"),
    "NTSD-only strings (lib.dll or the swapped import)": ("removed", "user", "D1's rule: NTSD's text belongs to the game"),
    "VC80 runtime strings": ("keep", "loop", "Microsoft C runtime text in the pinned msvcr80.dll"),
    "names and vocabulary of the data files": ("keep", "user", "the content format"),
    PROJECT_JSON: ("keep", "user", "the project's own text"),
    "BMP/DIB header fields": ("keep", "loop", "format structure of authored files"),
    "WAV header fields": ("keep", "loop", "format structure of authored files"),
    "short audio sample runs (authored waveforms)": ("keep", "loop", "short authored runs"),
    "DAT and data-file format text (field vocabulary, frame names)": ("keep", "loop", "the content format"),
    "ascending integer runs (step 1, no content beyond start and length)": ("keep", "loop", "a run of consecutive integers, e.g. an ID range listed in full, which also occurs in the VC80 DLL's 16-bit identity tables (E6b)"),
    "DAT frame-line fragments (authored values in the format's vocabulary)": ("keep", "loop", "the content format: at most 64 printable bytes with at most 8 digits, against a DAT or a JSON fixture; a copied frame is longer"),
}

# Unexpected hits examined and judged coincidences: (engine path suffix, the
# match's SHA-256 prefix) -> the reason (E7c, E7d, E7e-1 evidence).
EXAMINED = {
    ("OriginalDiagnosticNumberTableTests.swift", "e3fd6a0a483c5b12"): "the power list 1...8 as le16, a trivial ascending run",
    ("SyntheticContentPackTests.swift", "9597f36279ed4330"): "the frame-number list as le16, equal to data inside 063.wav",
    ("OriginalStartup/manifest.json", "c1191491d6b51bce"): "the digest of initial.mask, all ones and so byte-identical to the original's",
    ("OriginalStartup/manifest.json", "5a0f3193d3e699f6"): "the digest of initial.mask, all ones and so byte-identical to the original's",
}

# Classes whose kept hits must be these exact matches (SHA-256 prefixes); any
# other hit of the class fails in --policy (E7e-2's review: whole-file rules
# would also keep other bytes of those files).
PINNED = {
    "DAT key": {"955e3ff19ab0e340"},
    "DirectShow GUIDs": {"12f0a8d9306b50c6", "2be04b8a4ecefad4"},
    "CRT constants": set(),
}

# Literal strings matching a data file are vocabulary only up to the longest
# seen (E7e-2: 32 bytes, at most 3 digits); longer ones are unexpected.
VOCABULARY_MAX, VOCABULARY_DIGITS = 32, 3

# NTSD 2.4.exe's only .rdata bytes that differ from LF2 2.0a's lf2.exe (E6a,
# es-e6a-lf2-reference.json: the swapped import's name, 0x44c600 + 17; the
# file offset equals the RVA in .rdata), widened to the name's hint word.
NTSD_RDATA_RUN = (0x4c5fe, 0x4c611)

WIDTH = {"u8": 1, "le16": 2, "le32": 4, "le64": 8}

def ascending_run(encoding, start, piece):
    """The whole values a match of an integer literal covers (a partial first or
    last value skipped) are at least three consecutive integers."""
    w = WIDTH.get(encoding)
    if not w: return False
    body = piece[(w - start % w) % w:]
    values = [int.from_bytes(body[i:i + w], "little") for i in range(0, len(body) - w + 1, w)]
    return len(values) >= 3 and all(b - a == 1 for a, b in zip(values, values[1:]))

def digits(piece):
    return sum(c in b"0123456789" for c in piece)

def classify_file(path, variant, piece, start, length, original, original_variant):
    """Classes for --engine-files (a generated content pack): the formats' own structure.
    `piece` is the generated file's matched bytes (DAT text decrypted)."""
    low, end = path.lower(), start + length
    if low.endswith(".json") and project_json(original, original_variant) and length <= 48 \
            and not re.search(rb"[0-9a-fA-F]{16}", piece):
        return PROJECT_JSON
    if low.endswith(".dib") and end <= 40: return "BMP/DIB header fields"
    if low.endswith(".bmp") and end <= 54: return "BMP/DIB header fields"
    if low.endswith(".wav") and end <= 46: return "WAV header fields"
    if low.endswith(".wav") and length <= 32: return "short audio sample runs (authored waveforms)"
    # A few format lines at most, with almost no values in them.
    if low.endswith((".dat", ".txt")) and length <= 104 and sum(c in b"0123456789" for c in piece) <= 3:
        return "DAT and data-file format text (field vocabulary, frame names)"
    # Frame lines with small authored values (E7d/E7f, longest 53 bytes): an
    # original frame copied whole is longer than this.
    olow = original.lower()
    if low.endswith(".dat") and length <= 64 and digits(piece) <= 8 \
            and (olow.endswith(".dat") or (olow.endswith(".json") and "/Fixtures/" in original)) \
            and all(32 <= c < 127 or c in b"\r\n\t" for c in piece):
        return "DAT frame-line fragments (authored values in the format's vocabulary)"
    return "unexpected"

def classify(path, kind, seq, original, section, offset, encoding="", start=0):
    for test, name in EXPECTED:
        if test(path, seq): return name
    low = original.lower()
    if low.endswith(".json") and ("/Fixtures/" in original or "/Resources/" in original):
        return PROJECT_JSON
    if kind == "integers" and ascending_run(encoding, start, seq):
        return "ascending integer runs (step 1, no content beyond start and length)"
    if kind == "string":
        name = os.path.basename(low)
        if name == "lib.dll": return "NTSD-only strings (lib.dll or the swapped import)"
        if name == "msvcr80.dll": return "VC80 runtime strings"
        if name == "ntsd 2.4.exe" and section == ".rdata":
            if offset < NTSD_RDATA_RUN[1] and offset + len(seq) > NTSD_RDATA_RUN[0]: return "NTSD-only strings (lib.dll or the swapped import)"
            return "EXE strings (LF2 2.0a .rdata)"
        if low.endswith((".exe", ".dll")): return "EXE strings outside a known section"
        if len(seq) <= VOCABULARY_MAX and digits(seq) <= VOCABULARY_DIGITS: return "names and vocabulary of the data files"
    return "unexpected"

def main():
    a = argparse.ArgumentParser(); a.add_argument("repo"); a.add_argument("out")
    a.add_argument("--originals", nargs="*", default=DEFAULT_ORIGINALS)
    a.add_argument("--min-length", type=int, default=16); a.add_argument("--min-distinct", type=int, default=6)
    a.add_argument("--engine-files", default=""); a.add_argument("--policy", action="store_true")
    a.add_argument("--lf2-exe", default="")
    o = a.parse_args(); repo = os.path.abspath(o.repo); started = time.time()
    if o.policy:
        roots = [os.path.join(repo, r) for r in o.originals]
        problems = [f"missing original {r}" for r in roots if not os.path.exists(r)]
        problems += [f"empty original {r}" for r in roots if os.path.isdir(r) and not any(fs for _, _, fs in os.walk(r))]
        if not any(os.path.basename(r).lower() == "msvcr80.dll" for r in roots): problems.append("the VC80 DLL (msvcr80.dll) is not among the originals")
        if (o.min_length, o.min_distinct) != (16, 6): problems.append("--policy needs --min-length 16 and --min-distinct 6")
        if problems: print("\n".join(problems), file=sys.stderr); sys.exit(2)
    if o.engine_files:
        top = os.path.abspath(o.engine_files); seqs = []
        for b, _, fs in sorted(os.walk(top)):
            for f in sorted(fs):
                if f.startswith("._"): continue  # AppleDouble files, not the pack's
                rel = os.path.relpath(os.path.join(b, f), os.path.dirname(top)); data = open(os.path.join(b, f), "rb").read()
                seqs.append((rel, 0, "file", "raw", data))
                # A generated DAT also as its text, so a copy at any key phase is found.
                if f.lower().endswith(".dat"): seqs.append((rel, 0, "file", "decrypted", decrypt(data, dat_key(repo))))
    else:
        seqs = engine_sequences(os.path.join(repo, "engine"))
    table = index(seqs)
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
                        # Literal mode: the longest match per literal and original. File
                        # mode: every match region (keyed by its maximal start in the file).
                        k = (n, rel, variant, p - lo) if seqs[n][2] == "file" or o.policy else (n, rel, variant)
                        if k not in best or best[k]["length"] < length:
                            sec = next((nm for s0, s1, nm in sections if s0 <= start < s1), None)
                            best[k] = {"length": length, "offset": start, "section": sec,
                                       "sha256": hashlib.sha256(matched).hexdigest()[:16],
                                       "engineSlice": [p - lo, p - lo + length]}
            if files % 500 == 0: print(f"  {files} files, {scanned >> 20} MiB, {len(best)} hits, {time.time() - started:.0f} s", flush=True)
    hits = []
    key = dat_key(repo)
    for (n, rel, variant, *_), h in sorted(best.items(), key=lambda kv: (seqs[kv[0][0]][0], seqs[kv[0][0]][1], kv[0][1], kv[1]["engineSlice"][0])):
        path, line, kind, enc, seq = seqs[n]; a0, a1 = h["engineSlice"]
        if kind == "file":
            piece = seq[a0:a1]
            if path.lower().endswith(".dat") and enc == "raw":  # ciphertext against ciphertext: judge the text
                piece = bytes((b - key[i % len(key)]) & 0xff if i >= 123 else b for i, b in zip(range(a0, a1), piece))
            c = classify_file(path, enc, piece, a0, h["length"], rel, variant)
        else:
            c = classify(path, kind, seq[a0:a1], rel, h["section"], h["offset"], enc, a0)
        hits.append({"engine": f"{path}:{line}", "kind": kind, "encoding": enc, "literalLength": len(seq),
                     "original": rel, "variant": variant, **h, "class": c})
    lf2 = None
    if o.lf2_exe:
        data = open(o.lf2_exe, "rb").read(); lf2 = {"path": o.lf2_exe, "sha256": hashlib.sha256(data).hexdigest(), "checked": 0, "differing": 0}
        for h in hits:
            if h["class"] != "EXE strings (LF2 2.0a .rdata)": continue
            lf2["checked"] += 1
            if hashlib.sha256(data[h["offset"]:h["offset"] + h["length"]]).hexdigest()[:16] != h["sha256"]:
                lf2["differing"] += 1; h["class"] = "NTSD-only strings (lib.dll or the swapped import)"
    classes = {}
    for h in hits:
        c = classes.setdefault(h["class"], {"hits": 0, "engineSites": set()}); c["hits"] += 1; c["engineSites"].add(h["engine"])
    summary = {k: {"hits": v["hits"], "engineSites": len(v["engineSites"])} for k, v in sorted(classes.items())}
    policy = None
    if o.policy:
        failing, examined, used = [], [], set()
        for h in hits:
            rule = POLICY.get(h["class"], ("unexpected",))[0]
            key = next(((p, d) for (p, d) in EXAMINED if h["engine"].split(":")[0].endswith(p) and h["sha256"] == d), None)
            if rule == "unexpected" and key:
                used.add(key); examined.append({"engine": h["engine"], "sha256": h["sha256"], "reason": EXAMINED[key]})
            elif rule in ("unexpected", "removed") or (h["class"] in PINNED and h["sha256"] not in PINNED[h["class"]]):
                failing.append(h)
        policy = {"settled": {"user": "2026-10-21: E7b's recommendations accepted", "loop": "the loop's rules for the classes they did not name"},
                  "table": {k: dict(zip(("rule", "by", "why"), v)) for k, v in POLICY.items()},
                  "pinned": {k: sorted(v) for k, v in PINNED.items()}, "vocabulary": [VOCABULARY_MAX, VOCABULARY_DIGITS],
                  "examined": examined, "examinedUnused": [f"{p} {d}" for (p, d) in EXAMINED if (p, d) not in used],
                  "failing": len(failing), "failingHits": failing,
                  "open": sorted(k for k in summary if POLICY.get(k, ("",))[0] == "open"),
                  "verdict": "fail" if failing else "pass"}
    json.dump({"tool": "tools/scan_original_bytes.py", "window": K, "stride": STRIDE, "minLength": o.min_length,
               "minDistinct": o.min_distinct, "originals": o.originals, "originalFiles": files, "originalBytes": scanned,
               "engineSequences": len(seqs), "indexedWindows": len(table), "seconds": round(time.time() - started),
               "summary": summary, **({"lf2Exe": lf2} if lf2 else {}), **({"policy": policy} if policy else {}), "hits": hits}, open(o.out, "w"), indent=1)
    print(json.dumps({"files": files, "bytes": scanned, "hits": len(hits), "summary": summary,
                      **({"lf2Exe": {k: lf2[k] for k in ("checked", "differing")}} if lf2 else {}),
                      **({"verdict": policy["verdict"], "failing": policy["failing"], "open": policy["open"]} if policy else {})}))
    if policy and policy["verdict"] == "fail": sys.exit(1)

if __name__ == "__main__":
    main()
