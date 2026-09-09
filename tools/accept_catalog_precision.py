#!/usr/bin/env python3
"""Verify explicit53-bit original DAT scans and native whole catalog, then publish."""
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, DLL_SHA, capture, digest, publish


def blobs(doc):
    result = {}
    for key, blob in doc['blobs'].items():
        raw = zlib.decompress(base64.b64decode(blob['deflate']), -15)
        assert len(raw) == blob['count'] and digest(raw) == key
        result[key] = raw
    return result


def validated():
    catalog_report, catalog_raw, catalog = capture('loaded-catalog53')
    numeric_report, numeric_raw, numeric = capture('dat-numeric53')
    audit = catalog['precision']
    assert audit == catalog_report['precision'] == numeric['precision'] == numeric_report['precision']
    assert audit['gameControlWord'] == audit['scannerControlWord'] == 0x27f
    assert audit['scannerSharesGameCPU'] is False
    assert catalog['crtSHA256'] == catalog_report['dllSHA256'] == DLL_SHA
    previous = json.loads((ROOT / 'docs/evidence/loaded-catalog.json').read_bytes())['corpora'][0]
    assert audit['historical'] == dict(corpus=previous['corpus'], corpusSHA256=previous['corpusSHA256'],
        fixture=previous['fixture'], sha256=previous['fixtureSHA256'])
    assert digest((FIXTURES / previous['fixture']).read_bytes()) == previous['fixtureSHA256']
    historical_raw = (ROOT / 'build/original' / previous['corpus']).read_bytes()
    full_raw = (ROOT / 'build/original' / audit['fullCorpus']).read_bytes()
    assert full_raw == historical_raw
    assert digest(full_raw) == audit['fullSHA256'] == previous['corpusSHA256']
    assert len(full_raw) == audit['fullBytes'] == 95289959
    assert audit['changedHistoricalFields'] == []
    full = json.loads(full_raw)
    compact = {k: v for k, v in full.items() if k not in ('scans', 'readsBeforeWrites', 'events')}
    compact['events'] = [e for e in full['events'] if e['kind'] == 'mirror-blit']
    compact.update(scope=catalog['scope'], precision=audit)
    assert compact == catalog and not full['readsBeforeWrites']
    assert Counter(s['format'] for s in full['scans']) == audit['formats']
    assert len(full['scans']) == sum(audit['formats'].values()) == 919912
    loaded_blobs, numeric_blobs = blobs(catalog), blobs(numeric)
    assert all(loaded_blobs[key] == value for key, value in numeric_blobs.items())
    children = {c['path']: c for c in catalog['children']}
    scans = [s for s in full['scans'] if s['format'] == '%lf']
    assert len(scans) == len(numeric['cases']) == audit['numericCases'] == numeric_report['cases'] == 863
    assert len(numeric_blobs) == numeric_report['sourceFiles'] == 43
    assert Counter(c['kind'] for c in numeric['cases']) == numeric_report['kinds'] == {'object': 672, 'stages': 191}
    for index, (case, scan) in enumerate(zip(numeric['cases'], scans)):
        result = case['result']
        assert case['index'] == index and case['source'] == children[case['path']]['decoded']
        assert case['kind'] == children[case['path']]['kind']
        assert scan['before'] == case['offset'] and int(scan['caller'], 16) == case['caller']
        assert scan['after'] - scan['before'] == result['position']
        assert scan['assignments'] == result['result'] == 1
        assert scan['eof'] == result['eof'] is False and result['errno'] == 0
        assert result == case['unwritten'] == case['precision64']
        assert len(result['outputs']) == 8 and len(bytes.fromhex(result['outputs'][0])) == 8
        assert all(value == '' for value in result['outputs'][1:])
        assert 0 <= case['offset'] < case['offset'] + result['position'] < len(numeric_blobs[case['source']])
    assert numeric_report['changedFromUnwritten'] == numeric_report['changedFrom64'] == 0
    assert {key: catalog_report[key] for key in ('objects', 'backgrounds', 'stages', 'phases', 'frames', 'bitmaps', 'allocations', 'checksum')} == dict(
        objects=137, backgrounds=17, stages=25, phases=138, frames=15388, bitmaps=829, allocations=14586, checksum=31475378)
    catalog_report.update(historicalFullCaptureReproduced=True, verifiedBlobs=len(loaded_blobs))
    numeric_report.update(verifiedBlobs=len(numeric_blobs), callers=len({c['caller'] for c in numeric['cases']}))
    return [('loaded-catalog53', catalog_report, catalog_raw), ('dat-numeric53', numeric_report, numeric_raw)]


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous = json.loads((ROOT / 'build/research/coordinate-precision-fixture-pins.json').read_bytes())
    assert len(previous) == 154 and all(pins[name] == sha for name, sha in previous.items())
    captures = validated()
    subprocess.run(['swift', 'test', '--package-path', str(ROOT / 'native'), '-c', 'release', '--filter', 'OriginalCatalogPrecisionTests'],
        env=dict(os.environ, NTSD_CATALOG_PRECISION_DIRECTORY=str(ROOT / 'build/original')), check=True)
    publish(captures, pins, pin_name='catalog-precision-fixture-pins.json')


if __name__ == '__main__':
    main()
