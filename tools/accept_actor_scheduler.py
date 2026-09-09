#!/usr/bin/env python3
"""Compare the whole native scheduler before publishing its new source fixture."""
import json
import os
import subprocess
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous = json.loads((ROOT / 'build/research/catalog-precision-fixture-pins.json').read_bytes())
    assert len(previous) == 156 and all(pins[name] == sha for name, sha in previous.items())
    report, raw, doc = capture('actor-scheduler')
    assert doc['fpcw'] == report['fpcw'] == 0x27f
    assert len(doc['cases']) == report['cases'] == 6084
    assert len({c['label'] for c in doc['cases']}) == len(doc['cases'])
    assert Counter(c['group'] for c in doc['cases']) == report['groups']
    assert sum(len(c['events']) for c in doc['cases']) == report['events'] == 756
    assert sum(len(c['writes']) for c in doc['cases']) == report['writes'] == 30189
    observed = set(doc['instructions'])
    assert len(observed) == len(doc['instructions']) == report['instructions'] == 374
    inventories = {}
    lines = (ROOT / 'build/research/compact.asm').read_text().splitlines()
    for start, end, count in [(0x40d960, 0x40de20, 316), (0x416fb0, 0x417082, 58)]:
        expected = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
                    and all(c in '0123456789abcdef' for c in line[:6]) and start <= int(line[:6], 16) <= end}
        assert len(expected) == count and expected == {pc for pc in observed if start <= pc <= end}
        inventories[hex(start)] = dict(instructions=count, executed=count, missing=[])
    for case in doc['cases']:
        assert len(bytes.fromhex(case['after'])) == len(bytes.fromhex(case['defined'])) == 0x420
        assert set(bytes.fromhex(case['defined'])) <= {0, 1}
        for event in case['events']:
            assert event['kind'] == 'catalogSound' and len(event['arguments']) == 2
        for write in case['writes']:
            assert write['kind'] == 'instruction' and 0x40d960 <= int(write['instruction'], 16) <= 0x40de20
            assert 0 <= write['offset'] < write['offset'] + len(bytes.fromhex(write['bytes'])) <= 0x420
    report.update(instructionCoverage=inventories, actorBytes=6084 * 0x420, globalsBytesPerCase=0xb440,
                  actorWritesSourceOnly=True)
    subprocess.run(['swift', 'test', '--package-path', str(ROOT / 'native'), '-c', 'release', '--filter', 'OriginalActorSchedulerTests'],
        env=dict(os.environ, NTSD_SCHEDULER_DIRECTORY=str(ROOT / 'build/original')), check=True)
    publish([('actor-scheduler', report, raw)], pins, pin_name='actor-scheduler-fixture-pins.json')


if __name__ == '__main__':
    main()
