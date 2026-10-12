#!/usr/bin/env python3
"""The browser host as a static folder (docs/research/TVOS_WEB.md W2b-4c).

Usage: web_app.py build BUILD_DIR OUT_DIR [--music DIR]
       web_app.py serve OUT_DIR [--port PORT] [--log FILE]
       web_app.py measure OUT_DIR LOG

build assembles a folder any static host can serve, with no runner:

  index.html, wasi-worker.js, audio.js   the page (web/run.html) and its scripts
  config.json                            the run: program, arguments, mounts
  data-HASH/app/NTSDWeb.wasm             the program (BUILD_DIR's, byte for byte)
  data-HASH/app/NTSDNative_NTSDCore.bundle/...  the packaged data (BUILD_DIR's)
  data-HASH/music/...                    the packaged tracks
  data-HASH/app.json, music.json         each mount's listing: [{path, dir, size}]
  _headers, vercel.json                  headers for hosts that read them

HASH is the first 12 hex digits of a SHA-256 over every data file, so the
data folder's names change with its contents and a host can let browsers
keep it (Cache-Control immutable for /data-*), while the page, config and
scripts are checked on each visit. The page fetches a session's files in
parallel before the program starts (the /app mount's prefetch; the music
tracks load when they play), showing progress, so the program's
one-at-a-time reads come from the browser's cache.

The page needs cross-origin isolation (SharedArrayBuffer): the host must send
Cross-Origin-Opener-Policy: same-origin and Cross-Origin-Embedder-Policy:
require-corp with the page (and the scripts); _headers is read by Netlify and
Cloudflare Pages, vercel.json by Vercel; other hosts need the same headers in
their own configuration. Hosts should send application/wasm for .wasm (else
the page compiles from the bytes, slower). Host limits matter: the program
is 96 MB and the largest track 27.5 MB (Cloudflare Pages takes files up to
25 MiB). The saves stay in the player's browser (/save kept by the page,
W2b-4a). The guest runs in UTC (the runner pins Etc/GMT-1; whether WASI
Foundation honours a TZ for the player's zone is not yet checked). Files are
cloned where the file system can (APFS), so a folder on the build's volume
costs little space.

serve is a test server only: the folder on 127.0.0.1 with the isolation
headers, a JSON line per request (path, status, bytes) in --log, no caching.

measure reads such a log: the files a session fetched and their bytes by
kind, and what they weigh compressed (gzip -6; brotli -5, a host's on-the-fly
level, and -11 for files served pre-compressed), for the hosting decision.
"""
import hashlib, json, os, shutil, subprocess, sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "tools/crossplatform/web"
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
HEADERS = {"Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp",
           "Cross-Origin-Resource-Policy": "same-origin"}
IMMUTABLE = "public, max-age=31536000, immutable"   # the content-named data folder


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


def build(build_dir, out, music):
    if out.exists():
        sys.exit(f"web_app.py: {out} exists")
    program, bundle = build_dir / "NTSDWeb.wasm", build_dir / "NTSDNative_NTSDCore.bundle"
    for needed in (program, bundle, music):
        if not needed.exists():
            sys.exit(f"web_app.py: no {needed}")
    out.mkdir(parents=True)
    shutil.copy2(WEB / "run.html", out / "index.html")
    for name in ("wasi-worker.js", "audio.js"):
        shutil.copy2(WEB / name, out / name)
    staging = out / "data"
    clone(program, staging / "app/NTSDWeb.wasm")
    clone(bundle, staging / "app/NTSDNative_NTSDCore.bundle")
    clone(music, staging / "music")
    digest = hashlib.sha256()
    for name in ("app", "music"):
        entries = listing(staging / name)
        for e in entries:
            digest.update(json.dumps(e, sort_keys=True).encode())
            if not e["dir"]:
                with open(staging / name / e["path"], "rb") as f:
                    for block in iter(lambda: f.read(1 << 20), b""):
                        digest.update(block)
        (staging / f"{name}.json").write_text(json.dumps(entries, separators=(",", ":")))
    data = f"data-{digest.hexdigest()[:12]}"
    staging.rename(out / data)
    config = {"program": f"{data}/app/NTSDWeb.wasm", "args": ["/app/NTSDWeb.wasm", "--resources", "/app/NTSDNative_NTSDCore.bundle", "--music-dir", "/music"],
              "env": {}, "canvas": True, "frameBytes": 32 << 20, "interactive": True, "autostart": False,
              "mounts": [{"guest": "/app", "writable": False, "url": f"{data}/app", "manifest": f"{data}/app.json", "prefetch": True},
                         {"guest": "/music", "writable": False, "url": f"{data}/music", "manifest": f"{data}/music.json"},
                         {"guest": "/save", "writable": True, "persist": True}]}
    (out / "config.json").write_text(json.dumps(config, indent=1) + "\n")
    (out / "_headers").write_text("/*\n" + "".join(f"  {k}: {v}\n" for k, v in HEADERS.items())
                                  + f"/data-*\n  Cache-Control: {IMMUTABLE}\n")
    (out / "vercel.json").write_text(json.dumps({"headers": [
        {"source": "/(.*)", "headers": [{"key": k, "value": v} for k, v in HEADERS.items()]},
        {"source": "/data-(.*)", "headers": [{"key": "Cache-Control", "value": IMMUTABLE}]}]}, indent=1) + "\n")
    files = [p for p in out.rglob("*") if p.is_file()]
    print(json.dumps({"out": str(out), "data": data, "files": len(files), "bytes": sum(p.stat().st_size for p in files),
                      "program": program.stat().st_size, "config": config}, indent=1))


def serve(folder, port, log):
    class Handler(SimpleHTTPRequestHandler):
        extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".js": "text/javascript", ".json": "application/json"}

        def __init__(self, *a, **k):
            super().__init__(*a, directory=str(folder), **k)

        def end_headers(self):   # the headers build writes for hosts: isolation, and the data folder kept
            for k, v in HEADERS.items():
                self.send_header(k, v)
            self.send_header("Cache-Control", IMMUTABLE if self.path.startswith("/data-") else "no-cache")
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

        def do_GET(self):   # one JSON line per request: path, status, body bytes
            super().do_GET()
            if log:
                with open(log, "a") as f:
                    f.write(json.dumps({"path": self.path, "status": getattr(self, "status", 0), "bytes": getattr(self, "length", 0)}) + "\n")

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"web_app.py: serving {folder} on http://127.0.0.1:{server.server_address[1]}/", flush=True)
    server.serve_forever()


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


def main():
    args = sys.argv[1:]
    def option(name, default=None):
        if name in args:
            at = args.index(name); value = args[at + 1]; del args[at:at + 2]; return value
        return default
    if args[:1] == ["build"]:
        music = Path(option("--music", str(MUSIC))).resolve()
        if len(args) != 3:
            sys.exit(__doc__)
        build(Path(args[1]).resolve(), Path(args[2]).resolve(), music)
    elif args[:1] == ["serve"]:
        port, log = int(option("--port", "8140")), option("--log")
        if len(args) != 2:
            sys.exit(__doc__)
        serve(Path(args[1]).resolve(), port, log)
    elif args[:1] == ["measure"] and len(args) == 3:
        measure(Path(args[1]).resolve(), args[2])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
