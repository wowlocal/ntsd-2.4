#!/usr/bin/env python3
"""The browser host as a static folder (docs/research/TVOS_WEB.md W2b-4c, W5).

Usage: web_app.py build BUILD_DIR OUT_DIR [--music DIR]
       web_app.py serve OUT_DIR [--port PORT] [--log FILE] [--rate MBIT_PER_S] [--latency MS] [--plain | --broken-encoding]
       web_app.py verify OUT_DIR BUILD_DIR [--music DIR]
       web_app.py measure OUT_DIR LOG
       web_app.py visit URL [--runs N] [--seconds S] [--profile DIR]

build assembles a folder any static host can serve, with no runner:

  index.html, wasi-worker.js, audio.js, pack-loader.js   the page (web/run.html) and its scripts
  config.json                     the run: program, arguments, mounts, the data's index
  data-HASH/br/NTSDWeb.wasm       the program without its custom sections, brotli-compressed
  data-HASH/br/pack-NN.bin        the packaged files, concatenated in the program's
                                  read order (web/read-order.json), brotli-compressed
  data-HASH/music/*.caf           the packaged tracks as they are (ALAC: brotli gains ~1%)
  data-HASH/index.json            the packs and each mount's listing
  _headers, vercel.json           headers for hosts that read them

W5 (the live site, 2026-10-17: a first visit's data took ~46 s from Vercel's
CDN however fast the connection, the menu 9.3 s): before, every file was its
own request (1,521, each a round trip, four at a time), the module carried
32 MB of debug sections and the menu waited for its 27.5 MB track. Now the
data are 12 packs (pack 0 is what the menu reads, the startup package; then
~64 MiB each in read order, 44 MB on the wire for 758 MB where per-file brotli
gave 52 MB and the CDN's own compression ~70 MB), the module is 14 MB on the
wire instead of 29 MB (its code and data sections byte for byte the build's:
DWARF, the name section, Swift's autolink entries and producers are left
out), and the page's loader worker (pack-loader.js) streams the packs into
the origin's private file system while the program runs, so a later visit
fetches nothing. index.json lists each packed mount's entries ({path, dir}
or {path, size, pack, offset}) and the packs ({url, raw, wire, files, header,
lazy}: header, the size of an eager pack's header, pack_header; lazy packs,
each music track and the program file, load only when the program asks, and
the web host's music player keeps time silently until its track is in).

HASH is the first 12 hex digits of a SHA-256 over every data file, the
program and the packs' layout, so the data folder's names change with its
contents and a host can
let browsers keep it (Cache-Control immutable for /data-*), while the page,
config and scripts are checked on each visit.

Everything under data-*/br/ must be served with Content-Encoding: br (the
browser then decodes it; each pack starts with a header naming it and the
loader marks none of its files ready before the header matches, so a host
that strips or doubles the encoding fails loudly): vercel.json and _headers say
so, other hosts need the same rule. The page needs cross-origin isolation
(SharedArrayBuffer): the host must send Cross-Origin-Opener-Policy:
same-origin and Cross-Origin-Embedder-Policy: require-corp with the page (and
the scripts); _headers is read by Netlify and Cloudflare Pages, vercel.json
by Vercel (untested elsewhere). Brotli is decoded by every current browser
over HTTPS. The saves stay in the player's browser (/save kept by the page,
W2b-4a). The guest runs in UTC (the runner pins Etc/GMT-1; whether WASI
Foundation honours a TZ for the player's zone is not yet checked).

serve is a test server only: the folder on 127.0.0.1 with the isolation
headers, the build's cache headers and data-*/br/ as brotli, older folders'
precompressed NAME.br/NAME.gz forms (W3b's build --compress) served as such
a host would (br, then gzip, when the request accepts them, with Vary on
every data response), a JSON line per GET (path, status, declared body
bytes, encoding, seconds since the server started, logged at the response's
end) in --log, --rate capping its total sending rate and --latency holding
each response's start by MS (a CDN's round trip, which W3b-W3f's runs left
out); --plain ignores the precompressed forms; --broken-encoding sends a
data file's form (.bmp, .dat, .wav, .dib; in a packed folder the packs)
without its Content-Encoding (a misconfigured host: the page must fail
loudly, not run on altered data).

verify decodes the program and every pack and compares each file with
BUILD_DIR's (and the music folder's) bytes, and the program's sections with
the build's: the folder delivers exactly what the build made.

visit opens URL (a served folder, or the published site) in headless
Chromium through web_run.mjs --url, clicks to start at 0.5 s and reports,
per run, when the first frame was drawn and when the data were all in (W5's
loader; W3f's prefetch on older pages), in seconds since the page began to
load, sampled every 0.25 s for S seconds (default 60): N cold visits on
fresh profiles, or with --profile DIR return visits on that profile (its
first run fills it).

measure reads such a log: the files a session fetched and their bytes by
kind, and what they weigh compressed (gzip -6; brotli -5, a host's on-the-fly
level, and -11 for files served pre-compressed), for the hosting decision.
"""
import gzip, hashlib, json, os, shutil, struct, subprocess, sys, threading, time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "tools/crossplatform/web"
ORDER = WEB / "read-order.json"   # the program's first reads (W5)
PACK_BYTES = 64 << 20   # a pack's raw size, past the startup pack
HEADER, FORMAT = 64, 1   # each pack's header (pack_header) and the layout's format
MOUNTS = ("/app", "/music")
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
HEADERS = {"Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp",
           "Cross-Origin-Resource-Policy": "same-origin"}
IMMUTABLE = "public, max-age=31536000, immutable"   # the content-named data folder
VERCEL_HEADERS = [{"source": "/(.*)", "headers": [{"key": k, "value": v} for k, v in HEADERS.items()]},
                  {"source": "/data-(.*)", "headers": [{"key": "Cache-Control", "value": IMMUTABLE}]},
                  {"source": "/data-(.*)/br/(.*)", "headers": [{"key": "Content-Encoding", "value": "br"}]}]
BROKEN = (".bmp", ".dat", ".wav", ".dib")   # --broken-encoding: data files only (the manifests and program stay readable)


def leb(data, at):
    value = shift = 0
    while True:
        byte = data[at]; at += 1; value |= (byte & 0x7f) << shift; shift += 7
        if byte < 0x80: return value, at


def sections(data):
    """A wasm module's sections: (id, custom section name or None, its bytes with header)."""
    if data[:8] != b"\0asm\1\0\0\0":
        sys.exit("web_app.py: the program is not a wasm module")
    out, at = [], 8
    while at < len(data):
        start, kind = at, data[at]; size, at = leb(data, at + 1); end = at + size
        name = None
        if kind == 0:
            length, inner = leb(data, at); name = data[inner:inner + length].decode()
        out.append((kind, name, data[start:end])); at = end
    return out


def strip(data):
    """The module without custom sections (debug info, names, autolink entries,
    producers): what runs is unchanged, every other section byte for byte."""
    kept = [body for kind, name, body in sections(data) if kind != 0 or name == "target_features"]
    return data[:8] + b"".join(kept)


def brotli(data):
    return subprocess.run(["brotli", "-q", "11", "-w", "24", "-c"], input=data, capture_output=True, check=True).stdout


def pack_header(name, number, raw):
    """A pack's first 64 bytes: b"NTSDPACK", the format and pack number (Int32
    LE), the pack's whole size (UInt64 LE), the data folder's name
    (NUL-padded). The loader marks no file ready before they match the index,
    so a host that strips or doubles the encoding fails before the program
    reads a byte."""
    return (b"NTSDPACK" + struct.pack("<iiQ", FORMAT, number, raw) + name.encode()).ljust(HEADER, b"\0")


def compress_pack(job):
    target, head, sources = job
    body = brotli(head + b"".join(Path(s).read_bytes() for s in sources))
    Path(target).write_bytes(body)
    return len(body)


def data_name(stripped, listed, sources, layout):
    """data-HASH: a SHA-256 over the program, every listed entry and file and
    the layout (the index without wire sizes), so a new order or grouping is
    a new folder too (a browser never mixes another layout's packs)."""
    digest = hashlib.sha256(stripped)
    for name in MOUNTS:
        for e in listed[name]:
            digest.update(json.dumps({**e, "mount": name}, sort_keys=True).encode())
            if not e["dir"] and f"{name}/{e['path']}" != "/app/NTSDWeb.wasm":
                with open(sources[f"{name}/{e['path']}"], "rb") as f:
                    for block in iter(lambda: f.read(1 << 20), b""):
                        digest.update(block)
    digest.update(json.dumps(layout, sort_keys=True).encode())
    return f"data-{digest.hexdigest()[:12]}"


def layout_of(index):
    return {"format": FORMAT, "packs": [{k: v for k, v in p.items() if k != "wire"} for p in index["packs"]], "mounts": index["mounts"]}


def clone(source, target):
    """A copy-on-write clone where the volume allows one (cp -c), else a copy."""
    target.parent.mkdir(parents=True, exist_ok=True)
    if subprocess.run(["cp", "-cR", str(source), str(target)], capture_output=True).returncode != 0:
        if target.is_dir(): shutil.rmtree(target)   # what a failed cp left
        elif target.exists(): target.unlink()
        (shutil.copytree if source.is_dir() else shutil.copy2)(source, target)


def listing(folder):
    entries = []
    for path in sorted(folder.rglob("*")):
        if path.name.startswith("._") or path.name == ".DS_Store":
            continue
        rel = path.relative_to(folder).as_posix()
        entries.append({"path": rel, "dir": True} if path.is_dir() else {"path": rel, "dir": False, "size": path.stat().st_size})
    return entries


def mount_files(build_dir, music):
    """Each mount's listing ({path, dir, size}) and its files' sources."""
    program, bundle = build_dir / "NTSDWeb.wasm", build_dir / "NTSDNative_NTSDCore.bundle"
    app = [{"path": "NTSDNative_NTSDCore.bundle", "dir": True}] + \
          [{**e, "path": f"NTSDNative_NTSDCore.bundle/{e['path']}"} for e in listing(bundle)] + \
          [{"path": "NTSDWeb.wasm", "dir": False, "size": program.stat().st_size}]
    sources = {f"/app/{e['path']}": bundle / e["path"][len("NTSDNative_NTSDCore.bundle/"):] for e in app if not e["dir"]}
    sources["/app/NTSDWeb.wasm"] = program
    tracks = listing(music)
    sources.update({f"/music/{e['path']}": music / e["path"] for e in tracks if not e["dir"]})
    return {"/app": app, "/music": tracks}, sources


def build(build_dir, out, music):
    if out.exists():
        sys.exit(f"web_app.py: {out} exists")
    if not shutil.which("brotli"):
        sys.exit("web_app.py: build needs the brotli command")
    program, bundle = build_dir / "NTSDWeb.wasm", build_dir / "NTSDNative_NTSDCore.bundle"
    for needed in (program, bundle, music, ORDER):
        if not needed.exists():
            sys.exit(f"web_app.py: no {needed}")
    listed, sources = mount_files(build_dir, music)
    stripped = strip(program.read_bytes())
    order = json.loads(ORDER.read_text()); rank = {p: i for i, p in enumerate(order["paths"])}
    lazy = [g for g in sources if g == "/app/NTSDWeb.wasm" or (g.startswith("/music/") and g.endswith(".caf"))]
    eager = [g for g in sources if g not in lazy]   # sources keep each mount's listing order
    eager.sort(key=lambda g: rank.get(g, len(rank)))   # stable: unlisted files last, in listing order
    groups, current, size = [[g for g in eager if rank.get(g, len(rank)) < order["startup"]]], [], 0
    for g in eager[len(groups[0]):]:
        current.append(g); size += sources[g].stat().st_size
        if size >= PACK_BYTES: groups.append(current); current, size = [], 0
    if current: groups.append(current)
    place, packs = {}, []   # guest path → (pack, offset)
    for number, group in enumerate(groups):
        offset = HEADER
        for g in group:
            place[g] = (number, offset); offset += sources[g].stat().st_size
        packs.append({"url": f"br/pack-{number:02d}.bin", "raw": offset, "files": len(group), "header": HEADER})
    for g in lazy:
        url, raw = ("br/NTSDWeb.wasm", len(stripped)) if g == "/app/NTSDWeb.wasm" else (f"music/{g[len('/music/'):]}", sources[g].stat().st_size)
        place[g] = (len(packs), 0); packs.append({"url": url, "raw": raw, "files": 1, "lazy": True})
    mounts = {}
    for name in MOUNTS:
        mounts[name] = []
        for e in listed[name]:
            g = f"{name}/{e['path']}"
            if e["dir"]: mounts[name].append({"path": e["path"], "dir": True}); continue
            pack, offset = place[g]
            mounts[name].append({"path": e["path"], "size": packs[pack]["raw"] if g == "/app/NTSDWeb.wasm" else e["size"], "pack": pack, "offset": offset})
    data = data_name(stripped, listed, sources, layout_of({"packs": packs, "mounts": mounts}))
    out.mkdir(parents=True)
    shutil.copy2(WEB / "run.html", out / "index.html")
    for name in ("wasi-worker.js", "audio.js", "pack-loader.js"):
        shutil.copy2(WEB / name, out / name)
    (out / data / "br").mkdir(parents=True)
    from concurrent.futures import ProcessPoolExecutor
    with ProcessPoolExecutor() as pool:   # the packs in parallel, the program here meanwhile
        futures = [pool.submit(compress_pack, (str(out / data / p["url"]), pack_header(data, number, p["raw"]), [str(sources[g]) for g in group]))
                   for number, (p, group) in enumerate(zip(packs, groups))]
        (out / data / "br/NTSDWeb.wasm").write_bytes(brotli(stripped))
        for p, future in zip(packs, futures):
            p["wire"] = future.result()
    for p, g in zip(packs[len(groups):], lazy):
        if g == "/app/NTSDWeb.wasm": p["wire"] = (out / data / "br/NTSDWeb.wasm").stat().st_size
        else: clone(sources[g], out / data / p["url"]); p["wire"] = p["raw"]
    (out / data / "index.json").write_text(json.dumps({"packs": packs, "mounts": mounts}, separators=(",", ":")))
    config = {"program": f"{data}/br/NTSDWeb.wasm", "data": f"{data}/index.json",
              "args": ["/app/NTSDWeb.wasm", "--resources", "/app/NTSDNative_NTSDCore.bundle", "--music-dir", "/music"],
              "env": {}, "canvas": True, "frameBytes": 32 << 20, "interactive": True, "autostart": False,
              "mounts": [{"guest": "/app", "writable": False, "packed": True},
                         {"guest": "/music", "writable": False, "packed": True},
                         {"guest": "/save", "writable": True, "persist": True}]}
    (out / "config.json").write_text(json.dumps(config, indent=1) + "\n")
    (out / "_headers").write_text("/*\n" + "".join(f"  {k}: {v}\n" for k, v in HEADERS.items())   # one splat per rule (Cloudflare Pages)
                                  + f"/data-*\n  Cache-Control: {IMMUTABLE}\n/:data/br/*\n  Content-Encoding: br\n")
    (out / "vercel.json").write_text(json.dumps({"headers": VERCEL_HEADERS}, indent=1) + "\n")
    files = [p for p in out.rglob("*") if p.is_file()]
    eager_packs = [p for p in packs if not p.get("lazy")]
    print(json.dumps({"out": str(out), "data": data, "files": len(files), "bytes": sum(p.stat().st_size for p in files),
                      "program": {"built": program.stat().st_size, "stripped": len(stripped), "wire": (out / data / "br/NTSDWeb.wasm").stat().st_size},
                      "packs": len(eager_packs), "raw": sum(p["raw"] for p in eager_packs), "wire": sum(p["wire"] for p in eager_packs),
                      "startupPack": eager_packs[0], "lazy": len(packs) - len(eager_packs)}, indent=1))


def serve(folder, port, log, rate=None, plain=False, broken=False, latency=0):
    began, bucket, lock = time.monotonic(), [0.0], threading.Lock()   # --rate: when the next byte may leave
    class Handler(SimpleHTTPRequestHandler):
        extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".js": "text/javascript", ".json": "application/json",
                          ".bin": "application/octet-stream"}

        def __init__(self, *a, **k):
            super().__init__(*a, directory=str(folder), **k)

        def end_headers(self):   # the headers build writes for hosts: isolation, and the data folder kept
            for k, v in HEADERS.items():
                self.send_header(k, v)
            self.send_header("Cache-Control", IMMUTABLE if self.path.startswith("/data-") else "no-cache")
            if self.path.startswith("/data-"):
                self.send_header("Vary", "Accept-Encoding")   # plain or encoded, kept apart by caches
            super().end_headers()

        def send_response(self, code, message=None):
            self.status, self.length = code, 0
            super().send_response(code, message)

        def send_header(self, keyword, value):
            if keyword.lower() == "content-length":
                self.length = int(value)
            super().send_header(keyword, value)

        def log_request(self, code="-", size="-"):
            pass

        def send_head(self):   # a precompressed form for the plain name, as gzip_static/brotli_static serve it
            self.encoding = None
            if latency: time.sleep(latency / 1000)   # --latency: the round trip before the response starts
            path = self.translate_path(self.path)
            if self.path.startswith("/data-") and "/br/" in self.path and os.path.isfile(path):   # data-*/br/: brotli bytes (W5)
                body = open(path, "rb")
                self.send_response(200); self.send_header("Content-Type", self.guess_type(path))
                strip_it = broken and "/br/pack-" in self.path   # the packs only: the program still runs, and the loader must refuse them
                if not strip_it: self.send_header("Content-Encoding", "br")
                self.send_header("Content-Length", str(os.fstat(body.fileno()).st_size)); self.end_headers()
                self.encoding = "stripped:br" if strip_it else "br"
                return body
            accepted = set()   # codings with a q above 0
            for part in self.headers.get("Accept-Encoding", "").split(","):
                coding, _, params = part.strip().partition(";")
                q = params.strip()[2:] if params.strip().startswith("q=") else "1"
                try:
                    if float(q) > 0: accepted.add(coding.strip().lower())
                except ValueError:
                    pass
            for suffix, name in () if plain else (("br", "br"), ("gz", "gzip")):
                if name in accepted and os.path.isfile(path) and os.path.isfile(f"{path}.{suffix}"):
                    body = open(f"{path}.{suffix}", "rb")
                    self.send_response(200); self.send_header("Content-Type", self.guess_type(path))
                    if not (broken and path.endswith(BROKEN)): self.send_header("Content-Encoding", name)
                    self.send_header("Content-Length", str(os.fstat(body.fileno()).st_size)); self.end_headers()
                    self.encoding = f"stripped:{name}" if broken and path.endswith(BROKEN) else name
                    return body
            return super().send_head()

        def copyfile(self, source, outputfile):   # --rate: the server's whole sending rate capped
            if not rate:
                return super().copyfile(source, outputfile)
            while block := source.read(64 << 10):
                with lock:
                    now = time.monotonic(); start = max(now, bucket[0]); bucket[0] = start + len(block) * 8 / (rate * 1e6)
                if start > now: time.sleep(start - now)
                outputfile.write(block)

        def do_GET(self):   # one JSON line per request: path, status, body bytes, encoding, seconds
            try:
                super().do_GET()
            finally:   # an aborted response too
                self.log_line()

        def log_line(self):
            if log:
                with open(log, "a") as f:
                    f.write(json.dumps({"path": self.path, "status": getattr(self, "status", 0), "bytes": getattr(self, "length", 0),
                                        "encoding": getattr(self, "encoding", None), "t": round(time.monotonic() - began, 3)}) + "\n")

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"web_app.py: serving {folder} on http://127.0.0.1:{server.server_address[1]}/", flush=True)
    server.serve_forever()


def verify(folder, build_dir, music):
    """The folder delivers the build's bytes: the program decodes to the
    build's module without its custom sections (every other section equal),
    every pack decodes to its listed size, starts with its header and holds
    each file's bytes where the index says, the index lists exactly the
    build's files, and the folder's name is theirs in this layout."""
    def decode(path):
        return subprocess.run(["brotli", "-d", "-c", str(path)], capture_output=True, check=True).stdout
    config = json.loads((folder / "config.json").read_text())
    data = folder / Path(config["data"]).parent
    index = json.loads((data / "index.json").read_text())
    listed, sources = mount_files(build_dir, music)
    wrong = []
    built, delivered = (build_dir / "NTSDWeb.wasm").read_bytes(), decode(folder / config["program"])
    if delivered != strip(built): wrong.append("program: not the build's module without its custom sections")
    if [b for k, n, b in sections(delivered)] != [b for k, n, b in sections(built) if k != 0 or n == "target_features"]:
        wrong.append("program: its sections differ from the build's")
    if data.name != data_name(strip(built), listed, sources, layout_of(index)):
        wrong.append(f"{data.name}: not the name of the build's files in this layout")
    bodies = {}
    for number, p in enumerate(index["packs"]):
        bodies[number] = decode(data / p["url"]) if p["url"].startswith("br/") else (data / p["url"]).read_bytes()
        if len(bodies[number]) != p["raw"]: wrong.append(f"{p['url']}: {len(bodies[number])} bytes, listed {p['raw']}")
        if p.get("header") and bodies[number][:p["header"]] != pack_header(data.name, number, p["raw"]): wrong.append(f"{p['url']}: its header")
    checked = 0
    for name in MOUNTS:
        if [{"path": e["path"], "dir": e["dir"]} for e in listed[name]] != [{"path": e["path"], "dir": bool(e.get("dir"))} for e in index["mounts"][name]]:
            wrong.append(f"{name}: the index does not list the build's entries")
        for e in index["mounts"][name]:
            if e.get("dir"): continue
            g = f"{name}/{e['path']}"
            expected = strip(built) if g == "/app/NTSDWeb.wasm" else sources[g].read_bytes()
            if bodies[e["pack"]][e["offset"]:e["offset"] + e["size"]] != expected or len(expected) != e["size"]: wrong.append(g)
            checked += 1
    ok = not wrong and checked > 0
    print(json.dumps({"files": checked, "packs": len(index["packs"]), "wrong": wrong[:20], "result": "pass" if ok else "fail"}, indent=1))
    sys.exit(0 if ok else 1)


def measure(folder, log):
    from urllib.parse import unquote, urlsplit
    import collections, gzip as gz
    seen, kinds, requests, transferred = {}, collections.defaultdict(lambda: collections.Counter()), 0, 0
    for line in open(log):
        r = json.loads(line); requests += 1; transferred += r["bytes"] if r["status"] == 200 else 0
        path = unquote(urlsplit(r["path"]).path).lstrip("/") or "index.html"
        if r["status"] == 200 and path not in seen and (folder / path).is_file():
            seen[path] = r["bytes"]
    def brotli(data, quality):
        return len(subprocess.run(["brotli", "-q", str(quality), "-c"], input=data, capture_output=True, check=True).stdout)
    for path, size in seen.items():
        data = (folder / path).read_bytes()
        kind = "program" if path.endswith(".wasm") else Path(path).suffix.lower() or "(none)"
        k = kinds[kind]
        k["files"] += 1; k["bytes"] += len(data); k["gzip6"] += len(gz.compress(data, 6))
        k["brotli5"] += brotli(data, 5); k["brotli11"] += brotli(data, 11) if len(data) < 64 << 20 or kind == "program" else brotli(data, 9)
    total = collections.Counter()
    for k in kinds.values():
        total.update(k)
    print(json.dumps({"requests": requests, "bytesTransferred": transferred, "files": len(seen), "total": dict(total),
                      "byKind": {kind: dict(k) for kind, k in sorted(kinds.items(), key=lambda kv: -kv[1]["bytes"])}}, indent=1))


def visit(url, runs, seconds, profile):
    import tempfile
    node = os.environ.get("NTSD_NODE") or str(max((Path.home() / ".local/share/fnm/node-versions").glob("v*/installation/bin/node"),
                                                    key=lambda p: [int(x) for x in p.parts[-4].lstrip("v").split(".")]))
    probe = ("JSON.stringify({t: performance.now(), first: self.ntsdPage && self.ntsdPage.report.firstFrameMs,"
             " data: self.ntsdPage && (self.ntsdPage.report.dataDoneMs ?? self.ntsdPage.report.prefetchDoneMs),"
             " loader: self.ntsdPage && self.ntsdPage.loader, exit: self.ntsdPage && self.ntsdPage.exit})")
    steps = [{"at": 0.5, "click": [397, 275]}] + [{"at": round(0.25 * i, 2), "log": probe} for i in range(1, int(seconds * 4) + 1)]
    results = []
    with tempfile.TemporaryDirectory() as scratch:
        (Path(scratch) / "steps.json").write_text(json.dumps(steps))
        for run in range(runs):
            folder = profile or str(Path(scratch) / f"profile-{run}")
            done = subprocess.run([node, str(ROOT / "tools/crossplatform/web_run.mjs"), "--url", url, "--steps", str(Path(scratch) / "steps.json"),
                                   "--profile", folder, "--timeout", str(int(seconds) + 60)], capture_output=True, text=True)
            samples = [json.loads(json.loads(line.split(" = ", 1)[1])) for line in done.stderr.splitlines()
                       if line.startswith("web_run.mjs: log ") and " = " in line]
            last = samples[-1] if samples else {}
            row = {"run": run + 1, "firstFrameSeconds": last.get("first") and round(last["first"] / 1000, 2),
                   "dataSeconds": last.get("data") and round(last["data"] / 1000, 2), "loader": last.get("loader"), "exit": last.get("exit")}
            results.append(row); print(json.dumps(row), flush=True)
    print(json.dumps({"url": url, "visits": "return" if profile else "cold", "runs": results}))


def main():
    args = sys.argv[1:]
    def option(name, default=None):
        if name in args:
            at = args.index(name); value = args[at + 1]; del args[at:at + 2]; return value
        return default
    music = Path(option("--music", str(MUSIC))).resolve()
    if args[:1] == ["build"]:
        if len(args) != 3:
            sys.exit(__doc__)
        build(Path(args[1]).resolve(), Path(args[2]).resolve(), music)
    elif args[:1] == ["serve"]:
        port, log, rate, latency = int(option("--port", "8140")), option("--log"), option("--rate"), float(option("--latency", "0"))
        plain, broken = "--plain" in args, "--broken-encoding" in args
        for flag in ("--plain", "--broken-encoding"):
            if flag in args: args.remove(flag)
        if len(args) != 2:
            sys.exit(__doc__)
        serve(Path(args[1]).resolve(), port, log, float(rate) if rate else None, plain, broken, latency)
    elif args[:1] == ["verify"] and len(args) == 3:
        verify(Path(args[1]).resolve(), Path(args[2]).resolve(), music)
    elif args[:1] == ["visit"]:
        runs, seconds, profile = int(option("--runs", "3")), float(option("--seconds", "60")), option("--profile")
        if len(args) != 2:
            sys.exit(__doc__)
        visit(args[1], runs, seconds, profile and str(Path(profile).resolve()))
    elif args[:1] == ["measure"] and len(args) == 3:
        measure(Path(args[1]).resolve(), args[2])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
