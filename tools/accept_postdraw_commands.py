#!/usr/bin/env python3
"""Compare and accept whole4214d5..421a15, preserving all historical fixtures."""
import json
import os
import subprocess
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous = json.loads((ROOT/'build/research/gameplay-lifecycle-fixture-pins.json').read_bytes())
    assert len(previous) == 162 and all(pins[n] == sha for n, sha in previous.items())
    report, raw, doc = capture('postdraw-commands')
    assert doc['fpcw'] == report['fpcw'] == 0x27f
    assert len(doc['cases']) == report['cases'] == 3898
    assert len({c['label'] for c in doc['cases']}) == len(doc['cases'])
    assert Counter(c['group'] for c in doc['cases']) == report['groups'] == dict(
        items=840, pool=72, coordinates=180, destroy=576, refill=720, healing=1320,
        **{'healing-alias': 30, 'state1700': 9, 'joined': 144, 'all-slots': 5, 'empty': 1, 'null-music': 1})
    assert sum(c['helpers'] for c in doc['cases']) == report['helpers'] == 4951
    kinds = Counter(e['kind'] for c in doc['cases'] for e in c['events'])
    assert kinds == dict(random=2436, reconstruct=566, resumeMusic=250)
    assert sum(kinds.values()) == report['events'] == 3252
    observed = set(doc['instructions'])
    assert len(observed) == len(doc['instructions']) == report['instructions'] == 545
    lines = (ROOT/'build/research/compact.asm').read_text().splitlines()
    inventories = {}
    for start, end, count, executed in [(0x4214d5, 0x421799, 173, 172), (0x42179b, 0x421a0f, 154, 146),
            (0x4061d0, 0x4064cc, 151, 151), (0x417170, 0x4171bc, 29, 26),
            (0x4450d0, 0x44517a, 55, 42), (0x402000, 0x402011, 8, 8)]:
        expected = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
                    and all(c in '0123456789abcdef' for c in line[:6]) and start <= int(line[:6], 16) <= end}
        actual = {pc for pc in observed if start <= pc <= end}
        assert len(expected) == count and len(actual) == executed and actual <= expected
        inventories[hex(start)] = dict(instructions=count, executed=executed, missing=sorted(expected-actual))
    assert sum(v['executed'] for v in inventories.values()) == len(observed)
    for case in doc['cases']:
        assert case['endPC'] == 0x421a15
        assert case['retainedBefore'] == case.get('retained', 77)
        assert 0 <= case['retainedAfter'] < 400
        assert case['fill'] in ('a5', 'ramp')
        for event in case['events']:
            args = event['arguments']
            assert len(args) == {'random': 3, 'reconstruct': 1, 'resumeMusic': 2}[event['kind']]
            if event['kind'] == 'random':
                assert 208 <= args[0] <= 212 and args[1] == (2 if args[0] == 208 else 30)
                assert 0 <= args[2] < args[1]
            else:
                assert 0 <= args[0] < 400
                if event['kind'] == 'resumeMusic':
                    assert args[1] == 0x35000100
    report.update(instructionCoverage=inventories, poolBytesPerCase=0x7d8+400*0x420,
                  globalsBytesPerCase=0xb440, eventKinds=dict(kinds), retainedSlotOffset=0x34,
                  retainedSlotChangedCases=sum(c['retainedBefore'] != c['retainedAfter'] for c in doc['cases']),
                  wholeLoopCompared=True, initializedOwnChainExtended=False,
                  exits=dict(Counter(hex(c['endPC']) for c in doc['cases'])))
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalPostDrawCommandsTests'],
                   env=dict(os.environ, NTSD_POSTDRAW_COMMANDS_DIRECTORY=str(ROOT/'build/original')), check=True)
    publish([('postdraw-commands', report, raw)], pins, pin_name='postdraw-commands-fixture-pins.json')


if __name__ == '__main__':
    main()
