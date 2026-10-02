#!/usr/bin/env python3
"""EXE coverage table from the instruction universe, executed sets and citations.

Inputs: the universe (tools/exe_coverage_universe.py), executed-set files
(tools/exe_coverage_executed.py) and the repository's Swift sources and
research documents. Output: JSON plus a printed table. Static reading only.
"""
import glob
import json
import os
import re
import struct
import sys

THUNKS_LO, ZLIB_LO, RUNTIME_LO = 0x43f37e, 0x43f400, 0x4450a0
# Documents often run words into addresses ("Entire41f550..4214d5"): an
# address may follow letters but not digits, and may not run on into hex.
HEXADDR = re.compile(r'(?<![0-9])(?:0x)?(4[0-4][0-9a-f]{4})(?![0-9A-Za-z])')
RANGE = re.compile(r'(?<![0-9])(?:0x)?(4[0-4][0-9a-f]{4})\s*\.\.<?\s*(?:0x)?(4[0-4][0-9a-f]{4})(?![0-9A-Za-z])')


def citations(files, starts_sorted, functions, lo, hi):
    cited_entries, ranges = set(), []
    for path in files:
        text = open(path, errors='ignore').read()
        for a in HEXADDR.findall(text):
            cited_entries.add(int(a, 16))
        for a, b in RANGE.findall(text):
            a, b = int(a, 16), int(b, 16)
            if lo <= a < b <= hi and b - a < 0x20000:
                ranges.append((a, b))
    fn_cited = {f for f in functions if f in cited_entries}
    import bisect
    in_ranges = set()
    for a, b in ranges:
        i = bisect.bisect_left(starts_sorted, a)
        while i < len(starts_sorted) and starts_sorted[i] < b:
            in_ranges.add(starts_sorted[i]); i += 1
    covered = set(in_ranges)
    for f in fn_cited:
        covered |= functions[f]
    return fn_cited, in_ranges, covered


def main(universe_path, out_path, image_path, repo, *executed_paths):
    u = json.load(open(universe_path))
    image = open(image_path, 'rb').read()
    lo, hi = u['text']
    sizes = {int(a): n for a, n in u['sizes'].items()}
    functions = {int(f, 16): set(v) for f, v in u['functions'].items()}
    # Import thunks: one-instruction functions `jmp dword ptr [abs]`.
    pe = struct.unpack_from('<I', image, 0x3c)[0]
    opt = struct.unpack_from('<H', image, pe + 20)[0]
    o = pe + 24 + opt
    tva, traw = 0x400000 + struct.unpack_from('<I', image, o + 12)[0], struct.unpack_from('<I', image, o + 20)[0]
    thunks = set()
    for f, ins in functions.items():
        if len(ins) == 1:
            a = next(iter(ins))
            if image[traw + a - tva:traw + a - tva + 2] == b'\xff\x25':
                thunks.add(a)

    def part(a):
        if a in thunks: return 'thunks'
        if a < THUNKS_LO: return 'game'
        if ZLIB_LO <= a < RUNTIME_LO: return 'zlib'
        return 'runtime'
    parts = {}
    for a in sizes:
        parts.setdefault(part(a), set()).add(a)
    fparts = {}
    for f in functions:
        fparts.setdefault(part(f), set()).add(f)

    executed = {}
    for path in executed_paths:
        data = json.load(open(path))
        for name, record in data.items():
            executed.setdefault(name, set()).update(record['starts'])
    swift = (glob.glob(os.path.join(repo, 'native/Sources/NTSDCore/*.swift'))
             + glob.glob(os.path.join(repo, 'native/Sources/NTSDMacPlatform/*.swift')))
    code = ''.join(open(p, errors='ignore').read()
                   for p in glob.glob(os.path.join(repo, 'native/**/*.swift'), recursive=True))

    def stem(n):
        s = os.path.basename(n).rsplit('.', 1)[0]
        return re.sub(r'[-_]?part[-_]?\d+$', '', s)
    groups = {
        'fixtures (all Native test resources)': set(),
        'fixtures named in Native code': set(),
        'evidence files': set(),
        'raw oracle corpora (build/original)': set(),
    }
    for name, s in executed.items():
        if '/Fixtures/' in name:
            groups['fixtures (all Native test resources)'] |= s
            base = os.path.basename(name)
            if base in code or base.rsplit('.', 1)[0] in code or stem(name) in code:
                groups['fixtures named in Native code'] |= s
        elif 'docs/evidence/' in name:
            groups['evidence files'] |= s
        elif '.traces' in name:
            groups.setdefault('catalog trace PCs (build/research)', set()).update(s)
        else:
            groups['raw oracle corpora (build/original)'] |= s
    groups['all saved records'] = set().union(*groups.values())

    starts_sorted = sorted(sizes)
    port_fn, port_ranges, port_ins = citations(swift, starts_sorted, functions, lo, hi)
    docs = glob.glob(os.path.join(repo, 'docs/research/*.md')) + glob.glob(os.path.join(repo, 'docs/*.md'))
    doc_fn, doc_ranges, doc_ins = citations(docs + swift, starts_sorted, functions, lo, hi)
    scope = json.load(open(os.environ['EXE_COVERAGE_SCOPES'])) if os.environ.get('EXE_COVERAGE_SCOPES') else {}
    scope_fixture_fn = set().union(*[set(v) for k, v in scope.items() if '/Fixtures/' in k]) if scope else set()

    table = {}
    for p in ('game', 'zlib', 'runtime', 'thunks'):
        total = parts.get(p, set())
        tbytes = sum(sizes[a] for a in total)
        row = dict(instructions=len(total), bytes=tbytes, functions=len(fparts.get(p, set())))
        for g, s in groups.items():
            hit = total & s
            row[g] = dict(instructions=len(hit), bytes=sum(sizes[a] for a in hit),
                          percentInstructions=round(100 * len(hit) / max(1, len(total)), 1),
                          percentBytes=round(100 * sum(sizes[a] for a in hit) / max(1, tbytes), 1),
                          functionsTouched=sum(1 for f in fparts.get(p, set()) if functions[f] & s))
        fn_here = fparts.get(p, set())
        evidence_fn = {f for f in fn_here if functions[f] & groups['all saved records']} | (scope_fixture_fn & fn_here)
        share = sum(len(functions[f] & total) for f in evidence_fn)
        row['functions with recorded execution or a compared corpus'] = dict(functions=len(evidence_fn),
            instructionsInThem=share, percentInstructions=round(100 * share / max(1, len(total)), 1))
        row['cited in the Swift port (ranges only)'] = dict(instructions=len(port_ranges & total),
            percentInstructions=round(100 * len(port_ranges & total) / max(1, len(total)), 1))
        row['cited in the Swift port'] = dict(functions=len(port_fn & fn_here),
            instructions=len(port_ins & total), percentInstructions=round(100 * len(port_ins & total) / max(1, len(total)), 1))
        row['cited in research or port'] = dict(functions=len(doc_fn & fn_here),
            instructions=len(doc_ins & total), percentInstructions=round(100 * len(doc_ins & total) / max(1, len(total)), 1))
        table[p] = row
    json.dump(dict(universe=dict(instructions=len(sizes), bytes=sum(sizes.values()), functions=len(functions), text=[lo, hi]),
                   partitions=dict(thunksFrom=THUNKS_LO, zlib=[ZLIB_LO, RUNTIME_LO], runtimeFrom=RUNTIME_LO),
                   table=table, executedFiles=len(executed)), open(out_path, 'w'), indent=1)
    for p, row in table.items():
        print(f"== {p}: {row['instructions']} instructions, {row['bytes']} bytes, {row['functions']} functions")
        for g in groups:
            r = row[g]
            print(f"   {g:42s} {r['instructions']:6d} ins {r['percentInstructions']:5.1f}%  bytes {r['percentBytes']:5.1f}%  functions {r['functionsTouched']}")
        r = row['functions with recorded execution or a compared corpus']
        print(f"   {'functions with execution/compared corpus':42s} {r['functions']:6d} fns, {r['instructionsInThem']} ins {r['percentInstructions']:5.1f}%")
        r = row['cited in the Swift port (ranges only)']
        print(f"   {'cited in the Swift port (ranges only)':42s} {r['instructions']:6d} ins {r['percentInstructions']:5.1f}%")
        for g in ('cited in the Swift port', 'cited in research or port'):
            r = row[g]
            print(f"   {g:42s} {r['instructions']:6d} ins {r['percentInstructions']:5.1f}%  functions {r['functions']}")


if __name__ == '__main__':
    main(*sys.argv[1:])
