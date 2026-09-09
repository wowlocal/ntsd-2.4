#!/usr/bin/env python3
"""Accept the complete post-scheduler/opoint source comparison."""
import json
import os
import subprocess
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous = json.loads((ROOT/'build/research/postdraw-slot-prefix-fixture-pins.json').read_bytes())
    assert len(previous) == 158 and all(pins[n] == sha for n, sha in previous.items())
    report, raw, doc = capture('postdraw-opoint')
    assert doc['fpcw'] == report['fpcw'] == 0x27f
    assert len(doc['cases']) == report['cases'] == 1991
    assert len({c['label'] for c in doc['cases']}) == len(doc['cases'])
    assert Counter(c['group'] for c in doc['cases']) == report['groups']
    assert sum(c['helpers'] for c in doc['cases']) == report['helpers'] == 9164
    assert sum(len(c['events']) for c in doc['cases']) == report['events'] == 2291
    observed = set(doc['instructions']); assert len(observed) == len(doc['instructions']) == report['instructions'] == 786
    lines = (ROOT/'build/research/compact.asm').read_text().splitlines(); inventories = {}
    for start, end, count, executed in [(0x41fb0b, 0x4203af, 522, 519), (0x4213a9, 0x4214bf, 70, 69),
                                       (0x4061d0, 0x4064cc, 151, 151), (0x4450d0, 0x44517a, 55, 47)]:
        expected = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
                    and all(c in '0123456789abcdef' for c in line[:6]) and start <= int(line[:6], 16) <= end}
        actual = {pc for pc in observed if start <= pc <= end}
        assert len(expected) == count and len(actual) == executed and actual <= expected
        inventories[hex(start)] = dict(instructions=count, executed=executed, missing=sorted(expected-actual))
    assert sum(v['executed'] for v in inventories.values()) == len(observed)
    for case in doc['cases']:
        assert case['endPC'] in (0x4203b4, 0x420e93, 0x4214c6)
        assert case['helpers'] == len(case['events'])*4
        assert all(e['kind'] == 'reconstruct' and e['slot'] == case['slot'] and len(e['arguments']) == 1 for e in case['events'])
    survey = json.loads((ROOT/'docs/evidence/postdraw-opoint-dat-survey.json').read_bytes())
    survey_raw = (ROOT/'build/research'/survey['corpus']).read_bytes()
    assert digest(survey_raw) == survey['sha256'] and len(survey_raw) == survey['bytes']
    assert survey['objects'] == 137 and survey['entries'] == 2454 and survey['unknown'] == survey['invalidActions'] == []
    covered = {int(c['label'].split('-')[2]) for c in doc['cases'] if c['group'] == 'spread-count'}
    assert covered == set(map(int, survey['counts']))
    report.update(instructionCoverage=inventories, poolBytesPerCase=0x7d8+400*0x420, globalsBytesPerCase=0xb440,
                  exits=dict(Counter(hex(c['endPC']) for c in doc['cases'])), datSurveySHA256=survey['sha256'],
                  wholeLoopCompared=False, initializedOwnChainExtended=False)
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalPostDrawOpointTests|OriginalPostDrawSlotPrefixTests'],
                   env=dict(os.environ, NTSD_POSTDRAW_OPOINT_DIRECTORY=str(ROOT/'build/original')), check=True)
    publish([('postdraw-opoint', report, raw)], pins, pin_name='postdraw-opoint-fixture-pins.json')


if __name__ == '__main__': main()
