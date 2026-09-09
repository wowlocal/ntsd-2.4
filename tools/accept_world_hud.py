#!/usr/bin/env python3
"""Verify and accept the complete original HUD and its real drawing children."""
import json
import os
import subprocess
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old = json.loads((ROOT/'build/research/gameplay-commands-fixture-pins.json').read_bytes())
    assert len(old) == 165 and all(pins[n] == sha for n, sha in old.items())
    report, raw, doc = capture('world-hud')
    assert doc['fpcw'] == report['fpcw'] == 0x27f
    assert len(doc['cases']) == report['cases'] == 1753
    assert len({c['label'] for c in doc['cases']}) == len(doc['cases'])
    assert Counter(c['group'] for c in doc['cases']) == report['groups']
    kinds = Counter(e['kind'] for c in doc['cases'] for e in c['events'])
    assert kinds == dict(draw=17912, read=178772, clip=33856, blit=39462, rectangle=6104)
    assert sum(kinds.values()) == report['events'] == 276106
    assert sum(c['helpers'] for c in doc['cases']) == report['helpers'] == 59625
    assert sum(c['blits'] for c in doc['cases']) == report['blits'] == kinds['blit']
    undefined = sum(e['kind'] == 'read' and not e['read']['defined'] for c in doc['cases'] for e in c['events'])
    assert undefined == 70
    for case in doc['cases']:
        assert case['endPC'] == 0x421a2d
        assert case['argumentAccesses'] == [dict(pc=0x421a15, offset=0x68, size=4, write=False),
                                           dict(pc=0x421a19, offset=-4, size=4, write=True)]
        assert case['blits'] == sum(e['kind'] == 'blit' for e in case['events'])
        assert case['helpers'] == 1 + sum(e['kind'] in ('draw', 'rectangle', 'clip') for e in case['events'])
    observed = set(doc['instructions'])
    assert len(observed) == len(doc['instructions']) == report['instructions'] == 483
    lines = (ROOT/'build/research/compact.asm').read_text().splitlines()
    inventories = {}
    for start, end, count, executed in [(0x421a15, 0x421a28, 6, 6), (0x41ae60, 0x41b12d, 223, 223),
            (0x43ef70, 0x43f000, 57, 45), (0x43f010, 0x43f2fe, 214, 171), (0x43f310, 0x43f37a, 38, 38)]:
        expected = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
                    and all(c in '0123456789abcdef' for c in line[:6]) and start <= int(line[:6], 16) <= end}
        actual = {pc for pc in observed if start <= pc <= end}
        assert len(expected) == count and len(actual) == executed and actual <= expected
        inventories[hex(start)] = dict(instructions=count, executed=executed, missing=sorted(expected-actual))
    assert sum(v['executed'] for v in inventories.values()) == len(observed)
    report.update(instructionCoverage=inventories, poolBytesPerCase=0x7d8+400*0x420, globalsBytesPerCase=0xb440,
        eventKinds=dict(kinds), undefinedBitmapReadEvents=undefined, hudStackArgumentRead=False,
        callerArgumentAccessesPerCase=2, callerResetsFlagsBeforeHUD=True, initializedOwnChainExtended=False, pixelsCompared=False)
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalWorldHUDTests|OriginalGameplayCommandsTests'],
                   env=dict(os.environ, NTSD_WORLD_HUD_CORPUS=str(ROOT/'build/original/world-hud.json')), check=True)
    publish([('world-hud', report, raw)], pins, pin_name='world-hud-fixture-pins.json')


if __name__ == '__main__':
    main()
