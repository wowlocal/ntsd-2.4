#!/usr/bin/env python3
"""Accept the source-proven diagnostic fixed formats without changing old pins."""
import json
import os
import re
import subprocess
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish
from inspect_original import PE


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old = json.loads((ROOT/'build/research/gameplay-hud-fixture-pins.json').read_bytes())
    assert len(old) == 168 and all(pins[n] == sha for n, sha in old.items())
    report, raw, doc = capture('diagnostic-numbers')
    assert doc['fpcw'] == report['fpcw'] == 0x23f
    cases = doc['cases']
    assert len(cases) == report['cases'] == 74424
    assert len({(c['bits'], c['precision']) for c in cases}) == len(cases)
    groups = Counter(c['group'] for c in cases)
    assert groups == report['groups'] == {'binary-exponent': 57344, 'decimal-midpoint': 1320, 'decimal-power': 7568, 'raw-bits': 8192}
    assert all(c['precision'] in (3, 4) and c['fpswAfter'] == 0 for c in cases)
    assert Counter(((int(c['bits'], 16) >> 52) & 0x7ff, int(c['bits'], 16) >> 63, c['precision'])
                   for c in cases if c['group'] == 'binary-exponent') == {
                       (e, sign, p): 7 for e in range(2048) for sign in (0, 1) for p in (3, 4)}
    table_bytes = b''.join(bytes.fromhex(v) for t in doc['tables'] for v in t)
    assert len(table_bytes) == 504 and digest(table_bytes) == report['tableSHA256']
    dll = (ROOT/'build/original/crt/msvcr80.dll').read_bytes()
    assert digest(dll) == report['dllSHA256']
    pe = PE(dll)
    def memory(address, size):
        s = next(s for s in pe.sections if pe.base+s['rva'] <= address < pe.base+s['rva']+s['fileSize'])
        offset = s['fileOffset']+address-pe.base-s['rva']
        return dll[offset:offset+size]
    for base, table in zip((0x781c1ff0, 0x781c2150), doc['tables']):
        assert len(table) == 21
        for i, value in enumerate(table):
            assert memory(base+12*i, 12) == bytes.fromhex(value)
    for address, literal in doc['specials'].items():
        assert memory(int(address, 16), 8).split(b'\0')[0].decode('ascii') == literal
    observed = set(doc['instructions'])
    assert len(observed) == len(doc['instructions']) == report['observedPCs'] == 1568
    # CRT.boundary replaces this original function with the declared PTD token.
    # It is an observed hook address, not an executed _getptd instruction.
    boundary = 0x78132e29
    assert boundary in observed
    lines = (ROOT/'build/research/msvcr80.asm').read_text().splitlines()
    dll_pcs = {int(m[1], 16) for line in lines if (m := re.match(r'([0-9a-f]+):', line))}
    assert observed <= dll_pcs
    coverage = {}
    for a, z, total, count in [(0x78149dd9, 0x78149e94, 72, 72), (0x78149e94, 0x78149f22, 62, 54),
            (0x78149f23, 0x7814a7c5, 747, 579), (0x7814d4b2, 0x7814d56f, 90, 71),
            (0x78149b87, 0x78149c40, 81, 66), (0x78149a92, 0x78149b87, 99, 70)]:
        expected = {pc for pc in dll_pcs if a <= pc < z}
        actual = observed & expected
        assert len(expected) == total and len(actual) == count
        coverage[hex(a)] = dict(instructions=total, executed=count, missing=sorted(expected-actual))
    report.update(executedOriginalPCs=len(observed)-1, excludedHostBoundaries=[boundary], instructionCoverage=coverage,
        intermediateCompared=True, outputMasksAndGuardsChecked=True, allBinary64Exponents=True,
        allBinary64Values=False, fullPrintfImplemented=False, sameGameCPU=False)
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalDiagnosticNumberTests'], env=dict(os.environ,
                    NTSD_DIAGNOSTIC_NUMBERS_CORPUS=str(ROOT/'build/original/diagnostic-numbers.json')), check=True)
    publish([('diagnostic-numbers', report, raw)], pins, pin_name='diagnostic-numbers-fixture-pins.json')


if __name__ == '__main__':
    main()
