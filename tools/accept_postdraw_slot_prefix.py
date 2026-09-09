#!/usr/bin/env python3
"""Compare the complete slot prefix before publishing its source fixture."""
import json
import os
import subprocess
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous = json.loads((ROOT / 'build/research/actor-scheduler-fixture-pins.json').read_bytes())
    assert len(previous) == 157 and all(pins[name] == sha for name, sha in previous.items())
    report, raw, doc = capture('postdraw-slot-prefix')
    assert doc['fpcw'] == report['fpcw'] == 0x27f
    assert len(doc['cases']) == report['cases'] == 897
    assert len({c['label'] for c in doc['cases']}) == len(doc['cases'])
    assert Counter(c['group'] for c in doc['cases']) == report['groups']
    assert sum(c['helpers'] for c in doc['cases']) == report['helpers'] == 3227
    events = Counter(e['kind'] for c in doc['cases'] for e in c['events'])
    assert events == dict(random=1878, reconstruct=273, catalogSound=183)
    assert sum(events.values()) == report['events'] == 2334
    observed = set(doc['instructions'])
    assert len(observed) == len(doc['instructions']) == report['instructions'] == 714
    inventories = {}
    lines = (ROOT / 'build/research/compact.asm').read_text().splitlines()
    for start, end, count, executed in [(0x41f550, 0x41fb06, 329, 329), (0x4061d0, 0x4064cc, 151, 151),
                                       (0x40d960, 0x40de20, 316, 164), (0x416fb0, 0x417082, 58, 44),
                                       (0x417170, 0x4171bc, 29, 26)]:
        expected = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
                    and all(c in '0123456789abcdef' for c in line[:6]) and start <= int(line[:6], 16) <= end}
        actual = {pc for pc in observed if start <= pc <= end}
        assert len(expected) == count and len(actual) == executed and actual <= expected
        inventories[hex(start)] = dict(instructions=count, executed=executed, missing=sorted(expected-actual))
    assert sum(v['executed'] for v in inventories.values()) == len(observed)
    for case in doc['cases']:
        assert 0 <= case['slot'] < 400
        activity = dict(case['active']).get(case['slot'], 0)
        assert case['endPC'] == (0x41fb0b if activity else 0x4214c6)
        assert 0 <= case['retainedBefore'] <= 0xffffffff and 0 <= case['retainedAfter'] <= 0xffffffff
        for name in ('poolSHA256', 'maskSHA256', 'globalsSHA256'):
            assert len(bytes.fromhex(case[name])) == 32
        for event in case['events']:
            assert event['slot'] == case['slot']
            assert len(event['arguments']) == dict(random=3, reconstruct=1, catalogSound=2)[event['kind']]
    report.update(instructionCoverage=inventories, eventKinds=events, poolBytesPerCase=0x7d8+400*0x420,
                  globalsBytesPerCase=0xb440, retainedCallerWordCompared=True,
                  wholeLoopCompared=False, initializedOwnChainExtended=False)
    subprocess.run(['swift', 'test', '--package-path', str(ROOT / 'native'), '-c', 'release', '--filter',
                    'OriginalPostDrawSlotPrefixTests|OriginalActorSchedulerTests'],
                   env=dict(os.environ, NTSD_POSTDRAW_PREFIX_DIRECTORY=str(ROOT / 'build/original')), check=True)
    publish([('postdraw-slot-prefix', report, raw)], pins, pin_name='postdraw-slot-prefix-fixture-pins.json')


if __name__ == '__main__':
    main()
