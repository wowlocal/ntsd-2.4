#!/usr/bin/env python3
"""Distinct executed PCs in saved catalog traces (ordered-json-array-zlib-parts-v1).

Reads parts read-only, decompresses each and collects "pc", "returnPC" and
"entry" values that are EXE instruction starts. `stride` scans every n-th part
of the listed kinds (a lower bound: every collected PC was executed).
"""
import json, os, re, sys, zlib
from multiprocessing import Pool

PC = re.compile(rb'"(?:pc|returnPC|entry)":(\d+)')
STARTS = None

def init(universe):
    global STARTS
    STARTS = {int(a) for a in json.load(open(universe))['sizes']}

def part(path):
    raw = open(path, 'rb').read()
    for w in (-15, 15):
        try:
            text = zlib.decompress(raw, w); break
        except zlib.error:
            text = None
    if text is None:
        return set()
    return {v for v in map(int, PC.findall(text)) if v in STARTS}

def main(universe, directory, out, full_kinds, stride_kinds, stride):
    jobs = []
    for kind in full_kinds.split(','):
        jobs += [os.path.join(directory, p['path']) for p in json.load(open(os.path.join(directory, kind + '-index.json')))['parts']]
    for kind in stride_kinds.split(','):
        parts = json.load(open(os.path.join(directory, kind + '-index.json')))['parts']
        jobs += [os.path.join(directory, p['path']) for p in parts[::int(stride)]]
    found = set()
    with Pool(6, initializer=init, initargs=(universe,)) as pool:
        for i, s in enumerate(pool.imap_unordered(part, jobs, chunksize=4)):
            found |= s
            if i % 500 == 0:
                print(i, len(jobs), len(found), flush=True)
    json.dump({directory: dict(starts=sorted(found), keys=['pc', 'returnPC', 'entry'], parts=len(jobs))}, open(out, 'w'))
    print('done', len(jobs), 'parts', len(found), 'distinct executed starts')

if __name__ == '__main__':
    main(*sys.argv[1:])
