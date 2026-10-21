#!/usr/bin/env python3
"""ENGINE_SPLIT D1: unpack a Clickteam Install Creator setup without running it.

Reads the official LF2 2.0a installer (lf2.net's LF2_v2.0a.exe) as data and
writes its files under OUT with their install paths. The layout, read from
the setup's own structure (2026-10-21): after the PE stub the signature
"wwgT)H", then blocks [u16 id][u16 flags][u32 size][body]; a metadata body is
[u32 inflated size][u8 method][stream]. Block 0x143a is the file list:
[u32 count] then entries [u16 size][u16 type] with, for type 0 (a file), the
data offset (+6), compressed size (+10), size (+18), a 32-bit check value
(+22; not CRC-32 or Adler-32 of the file, the stream or the chunk, so it is
recorded, not checked) and the NUL-terminated path at +62. Block 0x7f7f
holds the files: [u32 size] then each file at its offset as [u8 method]
[stream]. Methods: 1 zlib, 2 bzip2, 0 stored. Each file's stream checks
itself (zlib's Adler-32, bzip2's CRCs) and its size is compared with the
list; a mismatch, a stored file or an unknown method stops the tool. Prints a
JSON manifest (path, size, SHA-256) and never file contents.

Usage: extract_clickteam_setup.py SETUP.exe OUT
"""
import bz2, hashlib, json, os, struct, sys, zlib

METHODS = {1: zlib.decompress, 2: bz2.decompress}

def blocks(data):
    at = data.index(b"wwgT)H") + 6
    while at + 8 <= len(data):
        bid, _, size = struct.unpack_from("<HHI", data, at)
        if at + 8 + size > len(data): raise SystemExit(f"block {bid:#x} at {at:#x} runs past the end")
        yield bid, at + 8, size
        at += 8 + size

def unpack(body):
    size, method = struct.unpack_from("<IB", body)
    out = METHODS[method](body[5:])
    if len(out) != size: raise SystemExit(f"metadata size {len(out)} != {size}")
    return out

def main():
    setup, out = sys.argv[1:3]
    data = open(setup, "rb").read()
    found = {bid: (start, size) for bid, start, size in blocks(data)}
    listing = unpack(data[found[0x143a][0]:sum(found[0x143a])])
    files_at = found[0x7f7f][0] + 4
    count, at, rows = struct.unpack_from("<I", listing)[0], 4, []
    for _ in range(count):
        size, kind = struct.unpack_from("<HH", listing, at)
        entry = listing[at:at + size]; at += size
        if kind != 0: continue
        offset, csize = struct.unpack_from("<II", entry, 6)
        usize, crc = struct.unpack_from("<II", entry, 18)
        name = entry[62:entry.index(b"\0", 62)].decode("cp1252")
        chunk = data[files_at + offset:files_at + offset + csize]
        if chunk[0] not in METHODS: raise SystemExit(f"{name}: unknown method {chunk[0]}")
        body = METHODS[chunk[0]](chunk[1:])
        if len(body) != usize: raise SystemExit(f"{name}: size {len(body)} != {usize}")
        path = os.path.join(out, *name.split("\\"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f: f.write(body)
        rows.append({"path": name.replace("\\", "/"), "size": usize, "method": chunk[0], "listCheck": f"{crc:08x}",
                     "sha256": hashlib.sha256(body).hexdigest()})
    if at != len(listing): raise SystemExit(f"file list ends at {at}, not {len(listing)}")
    json.dump({"setup": os.path.basename(setup), "setupSHA256": hashlib.sha256(data).hexdigest(),
               "entries": count, "files": rows}, sys.stdout, indent=1)
    print()

if __name__ == "__main__":
    main()
