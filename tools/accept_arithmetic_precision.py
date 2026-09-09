#!/usr/bin/env python3
"""Verify four precision corpora, compare native results, then publish fixtures.

Historical fixtures remain unchanged. SwiftPM runs once, sequentially, before
any resource write. This accepts declared arithmetic contexts, not Windows FPU
provenance or a fully initialized native match.
"""
import base64
import hashlib
import json
import os
import subprocess
import zlib
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'native/Tests/NTSDCoreTests/Fixtures'
EXE_SHA = '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
COUNTS = {'arithmetic-precision': 54201, 'impulse-precision': 3090,
          'actor-physics53': 9344, 'actor-physics53-catalog': 46089}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def validated_captures():
    captures = []
    for name, count in COUNTS.items():
        report = json.loads((ROOT / 'build/research' / f'{name}.json').read_bytes())
        assert report['corpus'] == f'{name}.json'
        raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
        assert raw.endswith(b'\n') and len(raw) == report['bytes'] and digest(raw) == report['sha256']
        doc = json.loads(raw)
        assert doc['exeSHA256'] == report['exeSHA256'] == EXE_SHA
        assert len(doc['cases']) == report['cases'] == count
        for key in ('historical', 'parent'):
            if key in doc:
                assert doc[key] == report[key]
                assert digest((FIXTURES / doc[key]['fixture']).read_bytes()) == doc[key]['sha256']
        if name.startswith('actor-physics53'):
            assert doc['fpcw'] == report['fpcw'] == 0x27f
            assert len(doc['changedFrom64']) == report['changedFrom64'] == (0 if name.endswith('-catalog') else 168)
            assert len(doc['instructions']) == report['instructions']
            assert sum(len(c['events']) for c in doc['cases']) == report['events']
            assert Counter(c['group'] for c in doc['cases']) == report['groups']
        else:
            assert Counter(c['fpcw'] for c in doc['cases']) == {cw: count // 3 for cw in (0x7f, 0x27f, 0x37f)}
        if name == 'arithmetic-precision':
            assert doc['instructions'] == report['instructions']
            assert set(doc['instructions']) == {0x40e51d, 0x40e520, 0x4307be, 0x40e556, 0x408425, 0x40e523, 0x419791}
            assert Counter('/'.join(c['operations']) or 'load' for c in doc['cases']) == report['groups']
        if name == 'impulse-precision':
            assert sum(len(c['events']) for c in doc['cases']) == report['writes'] == 28155
            old_packed = json.loads((FIXTURES / doc['historical']['fixture']).read_bytes())
            old_raw = zlib.decompress(base64.b64decode(old_packed['deflate']), -15)
            assert len(old_raw) == old_packed['count'] and digest(old_raw) == old_packed['sha256']
            old = {c['label']: c for c in json.loads(old_raw)['cases']}
            changes = Counter({str(cw): 0 for cw in (0x7f, 0x27f, 0x37f)})
            for c in doc['cases']:
                expected = old[c['label']]
                if c['fpcw'] == 0x37f:
                    assert {k: v for k, v in c.items() if k != 'fpcw'} == expected
                changes[str(c['fpcw'])] += c['poolSHA256'] != expected['poolSHA256']
            assert changes == report['changedPoolsFrom64'] == {'127': 518, '639': 22, '895': 0}
        captures.append((name, report, raw))
    return captures


def publish(captures, pins):
    assert all(digest((FIXTURES / name).read_bytes()) == sha for name, sha in pins.items())
    for name, report, raw in captures:
        payload = raw[:-1]
        compressor = zlib.compressobj(level=9, wbits=-15)
        compressed = compressor.compress(payload) + compressor.flush()
        packed = (json.dumps(dict(count=len(payload), sha256=digest(payload),
                   deflate=base64.b64encode(compressed).decode()), separators=(',', ':')) + '\n').encode()
        assert zlib.decompress(compressed, -15) == payload
        fixture = FIXTURES / f'original-{name}.json'
        if fixture.name in pins:
            assert digest(packed) == pins[fixture.name], 'Never rewrite an accepted fixture'
        fixture.write_bytes(packed)
        report.update(nativeCompared=True, windowsVerified=False, fixture=fixture.name,
                      fixtureSHA256=digest(packed), fixtureBytes=len(packed))
        (ROOT / 'docs/evidence' / f'{name}.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2), flush=True)
    pins.update({p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')})
    (ROOT / 'build/research/arithmetic-precision-fixture-pins.json').write_text(json.dumps(pins, indent=2) + '\n')


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    captures = validated_captures()
    subprocess.run(['swift', 'test', '--package-path', str(ROOT / 'native'), '-c', 'release', '--filter',
                    'OriginalArithmeticPrecisionTests|OriginalActorPhysicsTests/test(WholePhysicsAtStartupPrecision|CompleteCatalogAtStartupPrecision)|OriginalWorldImpulsesTests/testAllThreeImpulsePrecisions'],
                   env=dict(os.environ, NTSD_PRECISION_DIRECTORY=str(ROOT / 'build/original')), check=True)
    publish(captures, pins)


if __name__ == '__main__':
    main()
