#!/usr/bin/env python3
"""Verify and accept the entire original live-slot post-draw consumer."""
import copy
import json
import os
import struct
import subprocess
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical, publish


def continued_inputs(doc):
    """Check that component continuations use only their declared inputs."""
    excluded = {'fill', 'poolSHA256', 'maskSHA256', 'globalsSHA256', 'events',
                'helpers', 'endPC', 'retainedBefore', 'retainedAfter'}
    output = {'scratchBefore', 'scratchAfter'}
    origins = {}
    word = lambda offset, value: [offset, struct.pack('<i', value).hex()]
    for name, whole in [('postdraw-slot-prefix', True), ('postdraw-opoint', False)]:
        report, old = historical(name)
        assert doc['header'] == old['header'] and doc['fpcw'] == old['fpcw']
        cases = [c for c in doc['cases'] if c['group'] == 'continued-'+name]
        assert len(cases) == len(old['cases'])
        for actual, previous in zip(cases, old['cases']):
            expected = copy.deepcopy({k: v for k, v in previous.items() if k not in excluded})
            expected.update(group='continued-'+name, label='continued-'+name+'-'+previous['label'], whole=whole)
            expected['headers'] = [[n, *word(0x6f4, value)] for n, value in enumerate(old['ids'])]
            expected['headers'] += [[n, *word(0x6f8, 3 if n == 3 else 0)] for n in range(4)]
            expected['headers'] += old['headerPatches'] + previous.get('headers', [])
            states = sorted(set(map(int, doc['states'])) | set(map(int, old['states'])))
            expected['frames'] = [[n, number, *word(8, old['states'].get(str(number), 3))]
                                  for n in range(4) for number in states] + previous.get('frames', [])
            expected['scratch'] = [0x12345678, 1, 0x23456789, 0x3456789a, 1, previous.get('retained', 3)]
            assert {k: v for k, v in actual.items() if k not in excluded | output} == expected, actual['label']
        origins[name] = dict(cases=len(cases), sha256=report['sha256'],
                             fixture=report['fixture'], fixtureSHA256=report['fixtureSHA256'], wholeLoop=whole)
    return origins


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous = json.loads((ROOT/'build/research/postdraw-opoint-fixture-pins.json').read_bytes())
    assert len(previous) == 159 and all(pins[n] == sha for n, sha in previous.items())
    report, raw, doc = capture('postdraw-lifecycle')
    assert doc['fpcw'] == report['fpcw'] == 0x27f
    assert len(doc['cases']) == report['cases'] == 5432
    assert len({c['label'] for c in doc['cases']}) == len(doc['cases'])
    assert Counter(c['group'] for c in doc['cases']) == report['groups']
    assert sum(c['helpers'] for c in doc['cases']) == report['helpers'] == 71283
    kinds = Counter(e['kind'] for c in doc['cases'] for e in c['events'])
    assert kinds == dict(random=18116, reconstruct=6360, catalogSound=974, builtinSound=188)
    assert sum(kinds.values()) == report['events'] == 25638
    observed = set(doc['instructions'])
    assert len(observed) == len(doc['instructions']) == report['instructions'] == 2370
    lines = (ROOT/'build/research/compact.asm').read_text().splitlines()
    inventories = {}
    for start, end, count, executed in [(0x41f550, 0x4214cf, 1892, 1885), (0x4061d0, 0x4064cc, 151, 151),
            (0x40d960, 0x40de20, 316, 164), (0x416fb0, 0x417082, 58, 56), (0x417090, 0x417162, 58, 41),
            (0x417170, 0x4171bc, 29, 26), (0x4450d0, 0x44517a, 55, 47)]:
        expected = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
                    and all(c in '0123456789abcdef' for c in line[:6]) and start <= int(line[:6], 16) <= end}
        actual = {pc for pc in observed if start <= pc <= end}
        assert len(expected) == count and len(actual) == executed and actual <= expected
        inventories[hex(start)] = dict(instructions=count, executed=executed, missing=sorted(expected-actual))
    assert sum(v['executed'] for v in inventories.values()) == len(observed)
    assert doc['scratchOffsets'] == [0x44, 0x50, 0x5c, 0x60, 0x6c, 0x70]
    assert sum(c.get('whole', False) for c in doc['cases']) == 921
    for case in doc['cases']:
        assert case['endPC'] == (0x4214d5 if case.get('whole') else 0x4214c6)
        assert len(case['scratchBefore']) == len(case['scratchAfter']) == 6
        for event in case['events']:
            assert 0 <= event['slot'] < 400
            assert len(event['arguments']) == {'random': 3, 'reconstruct': 1, 'catalogSound': 2, 'builtinSound': 2}[event['kind']]
            if not case.get('whole'):
                assert event['slot'] == case['slot']
    report.update(instructionCoverage=inventories, poolBytesPerCase=0x7d8+400*0x420,
                  globalsBytesPerCase=0xb440, eventKinds=dict(kinds), continuedInputs=continued_inputs(doc),
                  wholeLoopCases=921, wholeLoopCompared=True, initializedOwnChainExtended=False,
                  exits=dict(Counter(hex(c['endPC']) for c in doc['cases'])))
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalPostDrawLifecycleTests|OriginalPostDrawOpointTests|OriginalPostDrawSlotPrefixTests'],
                   env=dict(os.environ, NTSD_POSTDRAW_LIFECYCLE_DIRECTORY=str(ROOT/'build/original')), check=True)
    publish([('postdraw-lifecycle', report, raw)], pins, pin_name='postdraw-lifecycle-fixture-pins.json')


if __name__ == '__main__':
    main()
