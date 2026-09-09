#!/usr/bin/env python3
"""Accept the whole notice caller with explicit sNaN oracle discrepancies.
819 direct comparisons,8 architectural-load/QNaN companion comparisons and
4 rejected cookie-overwrite controls. Never describe these as827 direct matches.
"""
import json
import os
import re
import subprocess
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish
from inspect_original import PE


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old = json.loads((ROOT/'build/research/diagnostic-numbers-fixture-pins.json').read_bytes())
    assert len(old) == 169 and all(pins[n] == sha for n, sha in old.items())
    report, raw, doc = capture('posthud-notices')
    cases, overflows = doc['cases'], doc['overflows']
    assert len(cases) == report['cases'] == 827 and len(overflows) == report['overflows'] == 4
    assert len({c['label'] for c in cases+overflows}) == 831
    assert Counter(c['group'] for c in cases) == report['groups']
    assert (doc['fpcw'], doc['localOffset'], doc['localSize'], doc['cookieOffset']) == (0x23f, 0x46c, 0x154, 0x5c0)
    kinds = Counter(e['kind'] for c in cases for e in c['events'])
    assert kinds == dict(format=2061, text=2375, getDC=2375, setBackgroundColor=2167, setTextColor=2167,
        stringLength=2167, textOut=2167, releaseDC=2167, fill=69, draw=157, read=1400, clip=290, blit=240)
    assert sum(kinds.values()) == report['events'] == 19802
    assert sum(c['helpers'] for c in cases) == report['helpers'] == 4952
    assert sum(e['kind'] == 'read' and not e['read']['defined'] for c in cases for e in c['events']) == 192
    discrepancies = []
    for c in cases+overflows:
        assert c['endPC'] == 0x421cdc
        assert c['helpers'] == sum(e['kind'] in ('format', 'text', 'fill', 'draw', 'clip') for e in c['events'])
        assert all(v['cw'] == 0x23f and v['sw'] == c.get('fpsw', 0) and v['tag'] == 0xffff for v in c['fpu'])
        assert len(c['localMask']) == len(bytes.fromhex(c['localBytes'])) == 0x154
        for f in c['formats']:
            value = bytes.fromhex(f['bytes']); assert len(value) == f['result']+1 and value[-1] == 0
        if c['group'] == 'cookie-overwrite':
            assert c['cookieWrites'] and c['formats'][0]['result']+1 > 0x134
        else:
            assert not c['cookieWrites'] and all(f['result']+1 <= 0x134 for f in c['formats'])
        if c['group'] == 'coordinates':
            _, bits, offset, sign = c['label'].split('-'); bits = int(bits, 16); offset = int(offset)
            if bits & 0x7ff0000000000000 == 0x7ff0000000000000 and bits & 0xfffffffffffff and not bits & 0x8000000000000:
                args = c['formats'][0]['arguments']; i = 0 if offset == 0x48 else 2
                assert args[i] | args[i+1] << 32 == bits
                companion = f'coordinates-{bits | 0x8000000000000:016x}-{offset}-{sign}'
                other = next(v for v in cases if v['label'] == companion)
                assert c['events'] != other['events'] and c['formats'][0]['bytes'] != other['formats'][0]['bytes']
                discrepancies.append(dict(label=c['label'], inputBits=f'{bits:016x}', companion=companion,
                    observedBytes=c['formats'][0]['bytes'], architecturalLoadCompanionBytes=other['formats'][0]['bytes']))
    assert len(discrepancies) == 8
    # Standalone x87 loads corroborate the architectural conversion, while
    # retaining the important distinction between Rosetta and actual hardware.
    load_path = ROOT/'build/research/posthud-x87-load-store.json'
    witness = json.loads(load_path.read_bytes()); assert len(witness['cases']) == 24
    for c in witness['cases']:
        a, z = int(c['input'], 16), int(c['output'], 16)
        snan = a & 0x7ff0000000000000 == 0x7ff0000000000000 and a & 0xfffffffffffff and not a & 0x8000000000000
        assert z == (a | 0x8000000000000 if snan else a) and c['cw'] == 0x23f
        denormal = a & 0x7ff0000000000000 == 0 and a & 0xfffffffffffff
        assert c['sw'] == (1 if snan else 2 if denormal else 0)
    observed = set(doc['instructions']); assert len(observed) == report['instructions'] == 2190
    asm = (ROOT/'build/research/compact.asm').read_text().splitlines()
    exe_pcs = {int(m[1], 16) for line in asm if (m := re.match(r'^([0-9a-f]{6}) ', line))}
    dll_pcs = {int(m[1], 16) for line in (ROOT/'build/research/msvcr80.asm').read_text().splitlines() if (m := re.match(r'^([0-9a-f]{8}):', line))}
    assert observed <= exe_pcs | dll_pcs
    assert 0x78132e29 not in observed and not any(0x30000000 <= pc < 0x30010000 for pc in observed)
    coverage = {}
    for a, z, total, reached in [(0x421a2d, 0x421cdc, 198, 195), (0x401290, 0x4012ff, 46, 46),
            (0x415160, 0x4151c3, 28, 28), (0x43ef70, 0x43f001, 57, 45), (0x43f010, 0x43f2ff, 214, 171)]:
        expected = {pc for pc in exe_pcs if a <= pc < z}; actual = expected & observed
        assert len(expected) == total and len(actual) == reached
        coverage[hex(a)] = dict(instructions=total, executed=reached, missing=sorted(expected-actual))
    assert sum(v['executed'] for v in coverage.values()) == 485 and len(observed & dll_pcs) == 1705
    exe = (ROOT/'downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe').read_bytes(); assert digest(exe) == doc['exeSHA256']; pe = PE(exe)
    def memory(address, size):
        s = next(s for s in pe.sections if pe.base+s['rva'] <= address < pe.base+s['rva']+s['fileSize'])
        at = s['fileOffset']+address-pe.base-s['rva']; return exe[at:at+size]
    for address, value in doc['literals'].items():
        value = bytes.fromhex(value); assert memory(int(address, 16), len(value)) == value
    for address, fmt in zip((0x449264, 0x44924c, 0x449244, 0x4491a8, 0x449190), doc['formats']):
        assert memory(address, len(fmt)+1) == fmt.encode()+b'\0'
    report.update(directlyMatchedCases=819, signalingNaNOracleDifferences=discrepancies,
        signalingNaNCompanionComparisons=8, nativeRejectsCookieOverwriteCases=4,
        instructionCoverage=coverage, instructionInventoryIncludesOverflowProbes=True, executedEXEPCs=485, executedDLLPCs=1705,
        excludedBoundaries=['COM/GDI', '_getptd78132e29', 'unexecuted421cdc'], eventKinds=dict(kinds), undefinedBitmapReads=192,
        poolBytesPerCase=0x7d8+400*0x420, globalsBytesPerCase=0xb440, callerLocalBytesPerCase=0x154,
        localBytesAndMasksCompared=True, formatIntermediateStorageCompared=True, sameControlledCPUForEXEAndCRT=True,
        fillBackingIsDeclaredHelperEntryInput=True, hardwareFPUStatusCompared=False,
        x87LoadStoreWitness=dict(source='tools/probe_x87_load_store.c', sourceSHA256=digest((ROOT/'tools/probe_x87_load_store.c').read_bytes()),
            sha256=digest(load_path.read_bytes()), **witness),
        intelReference=dict(url='https://cdrdv2-public.intel.com/843820/325462-sdm-vol-1-2abcd-3abcd-4-1.pdf',
            sections=['Vol.1 4.8.3.5/Table4-7', 'Vol.2A FLD/3-412'], pages=[104, 1004],
            sha256=digest((ROOT/'build/research/intel-sdm-dec24.pdf').read_bytes())),
        initializedOwnChainExtended=False, pixelsCompared=False, fullMatchCompared=False)
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalPostHUDNoticesTests|OriginalDiagnosticNumberTests'], env=dict(os.environ,
                    NTSD_POSTHUD_NOTICES_CORPUS=str(ROOT/'build/original/posthud-notices.json')), check=True)
    publish([('posthud-notices', report, raw)], pins, pin_name='posthud-notices-fixture-pins.json')

if __name__ == '__main__': main()
