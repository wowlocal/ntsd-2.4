#!/usr/bin/env python3
"""Accept initialized own gameplay and three World precision revalidations.

Validate captures and all old fixture pins, run one sequential SwiftPM process,
then publish five new lossless fixtures. Never rewrite historical expectations.
"""
import base64
import copy
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
DLL_SHA = 'c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def capture(name):
    report = json.loads((ROOT / 'build/research' / (name + '.json')).read_bytes())
    assert report['corpus'] == name + '.json'
    raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
    assert raw.endswith(b'\n') and len(raw) == report['bytes'] and digest(raw) == report['sha256']
    doc = json.loads(raw)
    assert doc['exeSHA256'] == report['exeSHA256'] == EXE_SHA
    if 'dllSHA256' in doc:
        assert doc['dllSHA256'] == report['dllSHA256'] == DLL_SHA
    return report, raw, doc


def historical(name):
    report = json.loads((ROOT / 'docs/evidence' / (name + '.json')).read_bytes())
    raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
    assert len(raw) == report['bytes'] and digest(raw) == report['sha256']
    assert digest((FIXTURES / report['fixture']).read_bytes()) == report['fixtureSHA256']
    return report, json.loads(raw)


def validated_captures():
    captures = []
    for kind, count, changes in [('physics', 515, 0), ('links', 3018, 0), ('hits', 7845, 3)]:
        name = 'world-' + kind + '53'
        report, raw, doc = capture(name)
        previous, old = historical('world-' + kind)
        assert doc['historical'] == report['historical'] == dict(fixture=previous['fixture'], sha256=previous['fixtureSHA256'])
        assert doc['fpcw'] == report['fpcw'] == 0x27f and len(doc['cases']) == report['cases'] == count
        assert len(doc['instructions']) == report['instructions']
        assert Counter(c['group'] for c in doc['cases']) == report['groups']
        assert sum(c['helpers'] for c in doc['cases']) == report['helpers']
        assert sum(len(c['events']) for c in doc['cases']) == report['events']
        assert [a['label'] for a, b in zip(doc['cases'], old['cases']) if a != b] == doc['changedFrom64']
        assert len(doc['changedFrom64']) == report['changedFrom64'] == changes
        captures.append((name, report, raw))
    for suffix in ('', '-control'):
        name = 'initialized-gameplay' + suffix
        report, raw, doc = capture(name)
        previous, old = historical('gameplay-impulses' + suffix)
        assert doc['control'] == bool(suffix) and doc['parent'] == report['parent'] == old['parent']
        assert digest((FIXTURES / doc['parent']['fixture']).read_bytes()) == doc['parent']['sha256']
        assert len(doc['cases']) == 1 and doc['cases'][0]['end'] == report['end'] == dict(pc=0x41f550, sp=0x1000e9bc)
        audit = doc['fpu']
        init = audit['initialization']
        assert init['entry'] == 0x445a31 and init['before'] == 0x37f and init['after'] == report['fpcw'] == 0x23f and init['result'] == 0
        assert len(init['instructions']) == report['initializationInstructions']
        assert {0x445a31, 0x445b16, 0x7814a7e9, 0x7814b04c, 0x7814b118}.issubset(init['instructions'])
        assert len(audit['checkpoints']) == report['checkpoints'] and len(audit['transitions']) == report['transitions']
        assert all(c['fpcw'] == 0x23f for c in audit['checkpoints'])
        assert audit['checkpoints'][0]['pc'] == 0x419e40 and audit['checkpoints'][-1]['pc'] == 0x41f550
        watched = {i['pc']: i for i in audit['watchedInstructions']}
        assert len(watched) == len(audit['watchedInstructions']) == 57
        current = init['before']
        for t in audit['transitions']:
            assert watched[t['pc']]['operation'] == t['operation'] and current == t['before']
            current = t['after']
        assert current == init['after']
        assert Counter(f"{t['pc']:x}:{t['before']:04x}->{t['after']:04x}" for t in audit['transitions']) == report['transitionKinds']
        # Compare complete game records/events with the old own pass. CPU-word
        # metadata is intentionally compared separately, not overwritten in
        # either raw capture or in the native engine's state.
        actual = copy.deepcopy(doc)
        actual.pop('fpu')
        actual.pop('scope')
        old.pop('scope')
        for value in (actual, old):
            for key in ('fpcw', 'fpswBefore', 'fpswAfter'):
                value['cases'][0]['impulses'].pop(key)
        assert actual == old
        for key, blob in doc['blobs'].items():
            value = zlib.decompress(base64.b64decode(blob['deflate']), -15)
            assert len(value) == blob['count'] and digest(value) == key
        report.update(historical=dict(fixture=previous['fixture'], sha256=previous['fixtureSHA256']), historicalGameRecordsReproduced=True)
        captures.append((name, report, raw))
    return captures


def publish(captures, pins):
    assert all(digest((FIXTURES / name).read_bytes()) == sha for name, sha in pins.items())
    for name, report, raw in captures:
        payload = raw[:-1]
        compressor = zlib.compressobj(level=9, wbits=-15)
        compressed = compressor.compress(payload) + compressor.flush()
        assert zlib.decompress(compressed, -15) == payload
        packed = (json.dumps(dict(count=len(payload), sha256=digest(payload),
                   deflate=base64.b64encode(compressed).decode()), separators=(',', ':')) + '\n').encode()
        fixture = FIXTURES / ('original-' + name + '.json')
        if fixture.name in pins:
            assert digest(packed) == pins[fixture.name], 'Never rewrite an accepted fixture'
        fixture.write_bytes(packed)
        report.update(nativeCompared=True, windowsVerified=False, fixture=fixture.name,
                      fixtureSHA256=digest(packed), fixtureBytes=len(packed))
        (ROOT / 'docs/evidence' / (name + '.json')).write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2), flush=True)
    pins.update({p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')})
    (ROOT / 'build/research/initialized-gameplay-fixture-pins.json').write_text(json.dumps(pins, indent=2) + '\n')


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    captures = validated_captures()
    subprocess.run(['swift', 'test', '--package-path', str(ROOT / 'native'), '-c', 'release', '--filter',
                    'OriginalInitializedGameplayTests|Original(ActorHits|WorldLinks|WorldPhysics)Tests/testWholePassAtStartupPrecision'],
                   env=dict(os.environ, NTSD_PRECISION_DIRECTORY=str(ROOT / 'build/original'),
                            NTSD_INITIALIZED_GAMEPLAY_DIRECTORY=str(ROOT / 'build/original')), check=True)
    publish(captures, pins)


if __name__ == '__main__':
    main()
