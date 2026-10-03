#!/usr/bin/env python3
"""Move top-level entries of a directory into PAX tar archives on /Volumes/T7.

T7 is ExFAT, so links, modes and nanosecond mtimes are kept inside the archive
payload (AGENTS.md, docs/evidence/t7-artifact-storage-2026-09-26.json).
Each archive streams to T7 (F_NOCACHE, then F_FULLFSYNC) while its SHA-256 is
computed. It is then read back from the device with F_NOCACHE, so cached pages
cannot stand in for T7. The whole-file SHA-256 must equal the streamed one, and every member's name, type, mode, nanosecond mtime, link target
and SHA-256 body are compared with the source. Only then is the source entry
removed. Each verified archive is appended to DEST/index.jsonl and to
SOURCE/ARCHIVED_TO_T7.jsonl.

Usage: archive_to_t7.py SOURCE DEST [--exclude NAME ...] [--dry-run] [--limit N]
"""
import argparse, fcntl, hashlib, json, os, plistlib, re, shutil, stat, subprocess, sys, tarfile, time
from decimal import Decimal

T7_UUID = "7C9569C1-BC8F-3288-B3FD-8831A3F07FAA"
T7_RESERVE = 40 * 2**30
OWN_ARCHIVE = 64 * 2**20
BATCH = 2 * 2**30
TAR = ["tar", "--format", "pax", "--no-mac-metadata", "--no-xattrs", "--no-acls", "--no-fflags"]


def check_t7():
    p = plistlib.loads(subprocess.run(["diskutil", "info", "-plist", "/Volumes/T7"], capture_output=True, check=True).stdout)
    if p.get("VolumeUUID") != T7_UUID or p.get("FilesystemType") != "exfat" or not p.get("WritableVolume"):
        sys.exit(f"T7 identity check failed: {p.get('VolumeUUID')} {p.get('FilesystemType')} writable={p.get('WritableVolume')}")
    return p["FreeSpace"]


def entries(root, name):
    """Relative paths of NAME and everything under it, never following links."""
    top = os.path.join(root, name)
    yield name
    if os.path.isdir(top) and not os.path.islink(top):
        for dirpath, dirnames, filenames in os.walk(top):
            for n in dirnames + filenames:
                yield os.path.relpath(os.path.join(dirpath, n), root)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_archive(root, names, path):
    """Stream `tar -cf -` into PATH, returning (sha256, bytes)."""
    env = dict(os.environ, COPYFILE_DISABLE="1")
    p = subprocess.Popen(TAR + ["-cf", "-", "-C", root, "--", *names], stdout=subprocess.PIPE, env=env)
    h, size = hashlib.sha256(), 0
    with open(path, "wb") as out:
        fcntl.fcntl(out.fileno(), fcntl.F_NOCACHE, 1)
        for chunk in iter(lambda: p.stdout.read(8 << 20), b""):
            out.write(chunk); h.update(chunk); size += len(chunk)
        out.flush(); fcntl.fcntl(out.fileno(), fcntl.F_FULLFSYNC)
    if p.wait() != 0:
        raise RuntimeError(f"tar exited {p.returncode}")
    return h.hexdigest(), size


def device_sha256(path):
    """Whole-file SHA-256 read from the device, bypassing the buffer cache."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        fcntl.fcntl(f.fileno(), fcntl.F_NOCACHE, 1)
        for chunk in iter(lambda: f.read(8 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def verify(root, names, path):
    expected = {rel: os.lstat(os.path.join(root, rel)) for n in names for rel in entries(root, n)}
    files = bytes_ = 0
    raw = open(path, "rb")
    fcntl.fcntl(raw.fileno(), fcntl.F_NOCACHE, 1)
    with raw, tarfile.open(fileobj=raw, mode="r:") as t:
        for m in t:
            rel = m.name.rstrip("/")
            st = expected.pop(rel, None)
            if st is None:
                raise RuntimeError(f"unexpected member {m.name}")
            src = os.path.join(root, rel)
            kind = "dir" if stat.S_ISDIR(st.st_mode) else "link" if stat.S_ISLNK(st.st_mode) else "file" if stat.S_ISREG(st.st_mode) else "other"
            if kind != ("dir" if m.isdir() else "link" if m.issym() else "file" if m.isfile() else "other"):
                raise RuntimeError(f"type differs: {rel}")
            if kind != "link" and m.mode != stat.S_IMODE(st.st_mode):
                raise RuntimeError(f"mode differs: {rel} {oct(m.mode)} {oct(stat.S_IMODE(st.st_mode))}")
            raw = m.pax_headers.get("mtime")
            mtime = Decimal(raw) if raw is not None else Decimal(int(m.mtime))
            if mtime != Decimal(st.st_mtime_ns) / Decimal(10**9):
                raise RuntimeError(f"mtime differs: {rel} {mtime} {st.st_mtime_ns}")
            if kind == "link" and m.linkname != os.readlink(src):
                raise RuntimeError(f"link differs: {rel}")
            if kind == "file":
                if m.size != st.st_size:
                    raise RuntimeError(f"size differs: {rel}")
                h = hashlib.sha256()
                body = t.extractfile(m)
                for chunk in iter(lambda: body.read(8 << 20), b""):
                    h.update(chunk)
                if h.hexdigest() != sha256_file(src):
                    raise RuntimeError(f"body differs: {rel}")
                files += 1; bytes_ += st.st_size
    if expected:
        raise RuntimeError(f"{len(expected)} source paths missing from archive, e.g. {next(iter(expected))}")
    return files, bytes_


def remove(root, name):
    path = os.path.join(root, name)
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path)
    else:
        os.remove(path)


def main():
    a = argparse.ArgumentParser()
    a.add_argument("source"); a.add_argument("dest")
    a.add_argument("--exclude", action="append", default=[]); a.add_argument("--dry-run", action="store_true")
    a.add_argument("--limit", type=int, default=0, help="process only the first N archives")
    o = a.parse_args()
    root = os.path.abspath(o.source)
    names = sorted(n for n in os.listdir(root) if n not in o.exclude and n != "ARCHIVED_TO_T7.jsonl")
    sizes = {n: sum(os.lstat(os.path.join(root, r)).st_size for r in entries(root, n)) for n in names}
    groups, small, small_size = [], [], 0
    for n in names:
        if sizes[n] >= OWN_ARCHIVE:
            groups.append((re.sub(r"[^A-Za-z0-9._-]", "_", n), [n]))
        else:
            small.append(n); small_size += sizes[n]
            if small_size >= BATCH:
                groups.append((f"small-{len(groups):04d}", small)); small, small_size = [], 0
    if small:
        groups.append((f"small-{len(groups):04d}", small))
    total = sum(sizes.values())
    print(f"{len(names)} entries, {total} bytes, {len(groups)} archives", flush=True)
    if o.dry_run:
        for g, ns in groups:
            print(g, len(ns), sum(sizes[n] for n in ns))
        return
    os.makedirs(o.dest, exist_ok=True)
    for g, ns in (groups[:o.limit] if o.limit else groups):
        need = sum(sizes[n] for n in ns)
        if check_t7() - need < T7_RESERVE:
            sys.exit(f"T7 reserve would drop below {T7_RESERVE} bytes before {g}")
        final = os.path.join(o.dest, g + ".tar")
        if os.path.exists(final):
            sys.exit(f"{final} already exists; refusing to overwrite")
        partial = final + ".partial"
        start = time.time()
        digest, size = write_archive(root, ns, partial)
        files, body = verify(root, ns, partial)
        if device_sha256(partial) != digest:
            raise RuntimeError(f"{partial}: device SHA-256 differs from the streamed archive")
        os.rename(partial, final)
        record = {"archive": final, "sha256": digest, "bytes": size, "entries": ns, "files": files,
                  "fileBytes": body, "verified": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "seconds": round(time.time() - start, 1),
                  "check": "F_NOCACHE readback from T7: whole-file SHA-256 and per-member name/type/mode/ns-mtime/link/SHA-256"}
        for index in (os.path.join(o.dest, "index.jsonl"), os.path.join(root, "ARCHIVED_TO_T7.jsonl")):
            with open(index, "a") as f:
                f.write(json.dumps(record) + "\n"); f.flush(); os.fsync(f.fileno())
        for n in ns:
            remove(root, n)
        print(f"{g}: {len(ns)} entries, {files} files, {size} archive bytes, {record['seconds']}s, removed from source", flush=True)


if __name__ == "__main__":
    main()
