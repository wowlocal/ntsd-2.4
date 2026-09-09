#!/usr/bin/env python3
"""Compare whole native conversions/camera before publishing two new fixtures."""
import json
import os
import subprocess
from collections import Counter, defaultdict
from accept_initialized_gameplay import ROOT, FIXTURES, capture, historical, digest, publish

FILTER = ('OriginalCoordinatePrecisionTests'
          '|OriginalWorldCameraTests/testEntireCameraAndBackgroundAtStartupPrecision')


def validated():
    result = []
    report, raw, doc = capture('coordinate-precision')
    assert len(doc['cases']) == report['cases'] == 63006
    assert doc['entry'] == 0x4450d0 and doc['flag'] == 0x45971c and doc['mxcsr'] == 0x1f80
    assert doc['callerSP'] == 0x24001003
    assert len(set(doc['conversionInstructions'])) == len(doc['conversionInstructions']) == 47
    assert doc['conversionInstructions'] == report['conversionInstructions']
    assert doc['arithmeticInstructions'] == report['arithmeticInstructions']
    assert set(doc['arithmeticInstructions']) == {0x40e51d, 0x40e520, 0x40e523, 0x40e556, 0x4307be, 0x408425, 0x419791}
    assert Counter(c['group'] for c in doc['cases']) == report['groups']
    grouped = defaultdict(dict)
    for c in doc['cases']:
        modes = grouped[c['label']]
        key = c['fpcw'], c['sse2']
        assert key not in modes and c['mxcsr'] & ~0x3f == 0x1f80
        assert c['fpsw'] >> 11 & 7 == 0
        if modes:
            first = next(iter(modes.values()))
            assert c['group'] == first['group'] and c['inputs'] == first['inputs'] and c['operations'] == first['operations']
        modes[key] = c
    assert len(grouped) == 10501
    assert all(set(m) == {(cw, sse2) for cw in (0x7f, 0x27f, 0x37f) for sse2 in (False, True)} for m in grouped.values())
    differences = dict(legacyVersusSSE2={str(cw): sum(m[cw, False]['eax'] != m[cw, True]['eax'] for m in grouped.values())
                       for cw in (0x7f, 0x27f, 0x37f)},
                       precision53Versus64={str(sse2): sum(m[0x27f, sse2]['eax'] != m[0x37f, sse2]['eax'] for m in grouped.values())
                       for sse2 in (False, True)})
    assert differences == dict(legacyVersusSSE2={'127': 6017, '639': 6022, '895': 6035}, precision53Versus64={'False': 41, 'True': 0})
    report.update(differences=differences, entry=doc['entry'], flag=doc['flag'], mxcsr=doc['mxcsr'], callerSP=doc['callerSP'])
    result.append(('coordinate-precision', report, raw))
    report, raw, doc = capture('world-camera53')
    previous, old = historical('world-camera')
    assert len(doc['cases']) == report['cases'] == 4742 and doc['fpcw'] == report['fpcw'] == 0x27f
    assert doc['cases'] == old['cases'] and doc['changedFrom64'] == [] and report['changedFrom64'] == 0
    assert doc['historical'] == report['historical'] == dict(fixture=previous['fixture'], sha256=previous['fixtureSHA256'])
    assert doc['instructions'] == old['instructions'] and len(doc['instructions']) == report['instructions'] == 1133
    assert Counter(c['group'] for c in doc['cases']) == report['groups']
    assert sum(len(c['events']) for c in doc['cases']) == report['events'] == 6898
    assert sum(c['helpers'] for c in doc['cases']) == report['helpers'] == 25950
    result.append(('world-camera53', report, raw))
    return result


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous = json.loads((ROOT / 'build/research/control-precision-fixture-pins.json').read_bytes())
    assert all(pins[name] == sha for name, sha in previous.items())
    captures = validated()
    subprocess.run(['swift', 'test', '--package-path', str(ROOT / 'native'), '-c', 'release', '--filter', FILTER],
        env=dict(os.environ, NTSD_COORDINATE_PRECISION_DIRECTORY=str(ROOT / 'build/original')), check=True)
    publish(captures, pins, pin_name='coordinate-precision-fixture-pins.json')


if __name__ == '__main__':
    main()
