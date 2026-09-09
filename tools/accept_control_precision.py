#!/usr/bin/env python3
"""Verify source identities, compare native control, then publish new fixtures.

Historical fixtures are immutable. SwiftPM is sequential; this command must
not overlap another build/test or any Swift/Fixtures edit.
"""
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, historical, digest

FILTER = ('OriginalActorControlTests/test(WholeControlAtStartupPrecision|CatalogControlAtStartupPrecision|ArithmeticAtThreeExplicitPrecisions)'
          '|OriginalWorldControlTests/test(EntireControlCallerAtStartupPrecision|LiveAliasedArithmeticAtThreePrecisions)')


def validated():
    result = []
    for name, count in [('actor-control53', 25795), ('actor-control-catalog53', 5376), ('world-control53', 1491),
                        ('actor-control-precision', 27708), ('world-control-precision', 36)]:
        report, raw, doc = capture(name)
        assert len(doc['cases']) == report['cases'] == count
        assert len(doc['instructions']) == report['instructions']
        assert Counter(c['group'] for c in doc['cases']) == report['groups']
        assert sum(len(c['events']) for c in doc['cases']) == report['events']
        if name.endswith('53'):
            previous, old = historical(name[:-2])
            assert doc['historical'] == report['historical'] == dict(fixture=previous['fixture'], sha256=previous['fixtureSHA256'])
            assert doc['historicalReexecuted'] and report['historicalReexecuted']
            assert doc['historicalReportedFPCW'] == report['historicalReportedFPCW'] == 0
            assert doc['fpcw'] == report['fpcw'] == 0x27f
            assert doc['cases'] == old['cases'] and doc['changedFromHistorical'] == [] and report['changedFromHistorical'] == 0
            if 'parent' in doc:
                assert doc['parent'] == old['parent'] == report['parent']
                assert digest((FIXTURES / doc['parent']['fixture']).read_bytes()) == doc['parent']['sha256']
        else:
            assert Counter(c['fpcw'] for c in doc['cases']) == {word: count // 3 for word in (0x7f, 0x27f, 0x37f)}
            changes = []
            for a, b, c in zip(doc['cases'][::3], doc['cases'][1::3], doc['cases'][2::3]):
                assert a['label'] == b['label'] == c['label']
                for mode, precision in ((a, 24), (b, 53)):
                    if {k: v for k, v in mode.items() if k != 'fpcw'} != {k: v for k, v in c.items() if k != 'fpcw'}:
                        changes.append(dict(label=mode['label'], precision=precision))
            assert changes == doc['changedFrom64']
            counts = {str(k): v for k, v in Counter(c['precision'] for c in changes).items()}
            assert counts == report['changedFrom64'] == ({'24': 8762, '53': 24} if name.startswith('actor') else {'24': 12, '53': 12})
            if name.startswith('actor'):
                assert len(set(doc['arithmeticPCs'])) == 13 and set(doc['arithmeticPCs']).issubset(doc['instructions'])
                assert doc['inheritedControlWordWitness'] == report['inheritedControlWordWitness']
                witness = doc['inheritedControlWordWitness']
                assert witness[0]['mode'] == 'unwritten' and witness[1]['mode'] == 0
                assert witness[0]['before'] == witness[0]['after'] == witness[1]['after'] == 0
                assert witness[0]['velocityX'] != witness[1]['velocityX'] == witness[2]['velocityX']
        result.append((name, report, raw))
    return result


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous = json.loads((ROOT / 'build/research/initialized-gameplay-fixture-pins.json').read_bytes())
    assert all(pins[name] == sha for name, sha in previous.items())
    captures = validated()
    subprocess.run(['swift', 'test', '--package-path', str(ROOT / 'native'), '-c', 'release', '--filter', FILTER],
        env=dict(os.environ, NTSD_CONTROL_PRECISION_DIRECTORY=str(ROOT / 'build/original')), check=True)
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
    assert all(digest((FIXTURES / name).read_bytes()) == sha for name, sha in pins.items())
    pins.update({p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')})
    (ROOT / 'build/research/control-precision-fixture-pins.json').write_text(json.dumps(pins, indent=2) + '\n')


if __name__ == '__main__':
    main()
