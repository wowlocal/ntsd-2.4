#!/usr/bin/env python3
"""Executed EXE instruction starts recorded in saved oracle data.

Scans fixtures and evidence JSON (plain or {"count","sha256","deflate"}
transport) for instruction-keyed subtrees and keeps every value that is an
instruction start of the pristine EXE universe (tools/exe_coverage_universe.py).
Writes one set per file. Static reading of saved records; nothing executes.
"""
import base64
import glob
import json
import os
import re
import sys
import zlib

KEY = re.compile(os.environ.get('EXE_COVERAGE_KEYS', r'"([A-Za-z0-9_]*(?:[Ii]nstruction|PCs|Pcs|pcs)[A-Za-z0-9_]*)"\s*:'))
HEX = re.compile(r'^(?:0x)?([0-9a-fA-F]{6,8})$')


def load_text(path):
    raw = open(path, 'rb').read()
    if raw[:1] in (b'{', b'['):
        text = raw.decode('utf-8', 'replace')
        if text.lstrip().startswith('{"count"') and '"deflate"' in text[:400]:
            try:
                d = json.loads(text)
                if set(d) >= {'deflate'}:
                    blob = base64.b64decode(d['deflate'])
                    try:
                        return zlib.decompress(blob, -15).decode('utf-8', 'replace')
                    except zlib.error:
                        return zlib.decompress(blob).decode('utf-8', 'replace')
            except (ValueError, KeyError):
                pass
        return text
    return None


def collect(value, out):
    if isinstance(value, bool):
        return
    if isinstance(value, int):
        out.add(value)
    elif isinstance(value, str):
        m = HEX.match(value)
        if m:
            out.add(int(m.group(1), 16))
    elif isinstance(value, list):
        for v in value:
            collect(v, out)
    elif isinstance(value, dict):
        for k, v in value.items():
            m = HEX.match(k)
            if m:
                out.add(int(m.group(1), 16))
            collect(v, out)


def scan(text, starts):
    decoder = json.JSONDecoder()
    found, keys = set(), set()
    for m in KEY.finditer(text):
        try:
            value, _ = decoder.raw_decode(text, m.end() + (len(text[m.end():m.end() + 8]) - len(text[m.end():m.end() + 8].lstrip())))
        except ValueError:
            continue
        before = len(found)
        values = set()
        collect(value, values)
        found |= {v for v in values if v in starts}
        if len(found) > before:
            keys.add(m.group(1))
    return found, keys


def main(universe_path, output_path, *patterns):
    universe = json.load(open(universe_path))
    starts = {int(a) for a in universe['sizes']}
    result = {}
    for pattern in patterns:
        for path in sorted(glob.glob(pattern, recursive=True)):
            text = load_text(path)
            if text is None:
                continue
            found, keys = scan(text, starts)
            if found:
                result[os.path.relpath(path)] = dict(starts=sorted(found), keys=sorted(keys))
            print(f'{len(found):6d} {os.path.basename(path)}', flush=True)
    json.dump(result, open(output_path, 'w'))


if __name__ == '__main__':
    main(*sys.argv[1:])
