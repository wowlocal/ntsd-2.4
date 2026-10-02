#!/usr/bin/env python3
"""Inspect or re-stamp the catalog checksum of NTSD 2.4 recordings (.lfr).

A recording is a 4-byte payload length, then a zlib stream whose leading bytes
carry the writer's key (the string at 0x44d7a0, read from the EXE). The decoded
recording holds the catalog checksum at +0x744 and the version at +0x748; the
playback start (4326c7) rejects a recording whose checksum differs from 44f620.

  lfr_checksum.py --exe "NTSD 2.4.exe" inspect FILE...
  lfr_checksum.py --exe "NTSD 2.4.exe" patch FILE CHECKSUM OUT

`patch` changes only the checksum field; the result is recompressed, so its
file bytes differ while the decoded recording differs only at +0x744..+0x747.
Such a copy is a diagnostic aid (CROSSOVER_REPLAY_CROSSPLAY.md), not a
recording either program wrote.
"""
import argparse
import hashlib
import struct
import zlib


def writer_key(exe_path):
    exe = open(exe_path, "rb").read()
    pe = struct.unpack_from("<I", exe, 0x3c)[0]
    count = struct.unpack_from("<H", exe, pe + 6)[0]
    optional = struct.unpack_from("<H", exe, pe + 20)[0]
    base = struct.unpack_from("<I", exe, pe + 24 + 28)[0]
    for i in range(count):
        _, _, va, raw_size, raw = struct.unpack_from("<8sIIII", exe, pe + 24 + optional + i * 40)
        if va <= 0x44d7a0 - base < va + raw_size:
            start = raw + 0x44d7a0 - base - va
            return exe[start:exe.index(b"\0", start)]
    raise SystemExit("key string 0x44d7a0 not in a file-backed section")


def decode(data, key):
    n = struct.unpack_from("<I", data)[0]
    payload = bytearray(data[4:4 + n])
    for i in range(min(n, len(key))):
        payload[i] = (payload[i] - key[i] + 0x30) & 0xff
    return zlib.decompress(bytes(payload))


def encode(recording, key):
    payload = bytearray(zlib.compress(bytes(recording), 9))
    for i in range(min(len(payload), len(key))):
        payload[i] = (payload[i] + key[i] - 0x30) & 0xff
    return struct.pack("<I", len(payload)) + bytes(payload)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--exe", required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    inspect = sub.add_parser("inspect"); inspect.add_argument("files", nargs="+")
    patch = sub.add_parser("patch"); patch.add_argument("file"); patch.add_argument("checksum"); patch.add_argument("out")
    args = parser.parse_args()
    key = writer_key(args.exe)
    if args.command == "inspect":
        for path in args.files:
            data = open(path, "rb").read(); recording = decode(data, key)
            checksum, version = struct.unpack_from("<Ii", recording, 0x744)
            print(f"{path}: {len(data)} bytes, decoded {len(recording)}, checksum {checksum:#x} ({checksum}), version {version:#x}")
    else:
        recording = bytearray(decode(open(args.file, "rb").read(), key))
        struct.pack_into("<I", recording, 0x744, int(args.checksum, 0))
        out = encode(recording, key)
        assert decode(out, key) == bytes(recording)
        open(args.out, "wb").write(out)
        print(f"{args.out}: checksum {int(args.checksum, 0):#x}, {len(out)} bytes, sha256 {hashlib.sha256(out).hexdigest()}")


if __name__ == "__main__":
    main()
