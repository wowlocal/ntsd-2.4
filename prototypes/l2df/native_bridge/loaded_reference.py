"""External retained comparison. This module never supplies runtime state."""
import base64
import hashlib
import json
from pathlib import Path
import zlib

FIXTURES = [
    ('original-settings-loading.json', 'b0c95deb903f0ec03b6cd15a8dad8186433ece4616e75912ecee49d09c852517'),
    ('original-settings-loading-control.json', '0440f022b596e9cd7618b891f60a4bba28b8b74a648a5cdff4188af0c9411443'),
]


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def unpack(value):
    raw = zlib.decompress(base64.b64decode(value['deflate'], validate=True), -15)
    assert len(raw) == value['count'] and digest(raw) == value['sha256']
    return raw


def typed_equal(actual, expected):
    """JSON bool is not a numeric0/1; all observable types remain contractual."""
    if type(actual) is not type(expected):
        return False
    if isinstance(expected, dict):
        return actual.keys() == expected.keys() and all(typed_equal(actual[k], v) for k, v in expected.items())
    if isinstance(expected, list):
        return len(actual) == len(expected) and all(typed_equal(a, e) for a, e in zip(actual, expected))
    return actual == expected


def compare(project, fixture_root, manifest_sha):
    results = []
    for profile, (name, pinned) in enumerate(FIXTURES):
        raw = (fixture_root / name).read_bytes()
        assert digest(raw) == pinned
        corpus = json.loads(unpack(json.loads(raw)))
        assert corpus['exeSHA256'] == '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
        assert corpus['control'] is bool(profile)
        boot_path = project / f'loaded-{profile}-boot.json'
        ready_path = project / f'loaded-{profile}-ready.json'
        boot, actual = json.loads(boot_path.read_bytes()), json.loads(ready_path.read_bytes())
        assert (project / f'loaded-{profile}-rollback.json').read_bytes() == boot_path.read_bytes()
        records = semantic_bytes = 0
        def blob(key):
            value = unpack(corpus['blobs'][key])
            assert digest(value) == key
            return value
        def actual_record(value):
            b, m = (base64.b64decode(value[k], validate=True) for k in ['bytes', 'defined'])
            assert len(b) == len(m) and set(m) <= {0, 1}
            return b, m
        def record(value, expected_bytes, expected_mask, label):
            nonlocal records, semantic_bytes
            b, m = actual_record(value)
            assert b == expected_bytes, label + ' full bytes'
            assert m == expected_mask, label + ' full mask'
            records += 1; semantic_bytes += len(b)
        def stored(value, expected, label, surface=None):
            b, m = blob(expected['bytes']), blob(expected['defined'])
            if surface is not None:
                assert int.from_bytes(b[:4], 'little') == surface, label + ' original surface binding'
                assert m[:4] == bytes([1]) * 4, label + ' known surface word'
                b = int(surface != 0).to_bytes(4, 'little') + b[4:]
            record(value, b, m, label)
        def globals_record(value, key, label):
            b = blob(key); assert len(b) == 0xb440
            record(value, b, bytes([1]) * len(b), label)
        front, settings = corpus['front'], corpus['cases'][0]
        assert front['stimulus'] == [] and front['selector'] is None and front['continuation'] == 'settings'
        assert len(front['allocations']) == len(front['records']) == 24 and len(front['events']) == 6892
        assert settings['stimulus'] == [] and settings['present'] and settings['callerEBX'] == settings['closeResult'] == 0
        assert settings['continuation'] == 'ready' and len(settings['events']) == 63
        assert front['endPC'] == 0x427089 and settings['endPC'] == 0x42709b
        for doc, phase, revision in [(boot, 2, 0), (actual, 3, 1)]:
            wanted = {'schema': 1, 'profile': profile, 'lifecycle': phase, 'revision': revision,
                      'manifestSHA256': manifest_sha, 'ownedDIBCount': 23,
                      'ownedDIBBytes': sum(len(blob(s['dib'])) for s in corpus['sources']),
                      'rawControlBytes': len(blob(corpus['source']['raw']))}
            assert typed_equal({k: doc[k] for k in wanted}, wanted), 'typed lifecycle/resource ownership'
        for field in ['frontEvents', 'settingsEvents', 'bitmaps']:
            assert typed_equal(boot[field], [])
        assert not any(field in boot for field in ['frontGlobals', 'scratch', 'settingsContinuation'])
        globals_record(boot['initialGlobals'], corpus['frontInitialGlobals'], 'boot independent PE recipe')
        globals_record(boot['globals'], corpus['frontInitialGlobals'], 'boot globals')
        globals_record(actual['initialGlobals'], corpus['frontInitialGlobals'], 'retained recipe')
        stored(boot['world'], corpus['initialWorld'], 'World constructor')
        for doc in [boot, actual]:
            for field, count in [('savedPlayback', 0x320), ('replayPointers', 8)]:
                record(doc[field], bytes(count), bytes([1]) * count, 'PE BSS ' + field)
        assert typed_equal(actual['frontEvents'], front['events']), 'every typed front event/order/argument'
        globals_record(actual['frontGlobals'], front['globals'], 'front globals')
        globals_record(actual['frontGlobals'], corpus['settingsInitialGlobals'], 'settings inherited globals')
        stored(actual['world'], front['world'], 'front World')
        stored(actual['world'], corpus['settingsWorld'], 'settings inherited World')
        by_address = {item['address']: item for item in actual['bitmaps']}
        assert len(actual['bitmaps']) == len(by_address) == 24
        assert typed_equal(sorted(by_address), sorted(r['address'] for r in front['records']))
        input_by_address = {front['allocations'][x['index']]['address']: x for x in front['inputs']}
        for expected in front['records']:
            item, supplied = by_address[expected['address']], input_by_address[expected['address']]
            assert typed_equal(item['input'], supplied['resource']) and item['optional'] is False
            stored(item['storage'], expected['storage'], 'front bitmap', surface=supplied['surface'])
        assert len(actual['settingsEvents']) == len(settings['events'])
        semantic_fields = ['kind', 'arguments', 'strings', 'format', 'before', 'position', 'eof', 'result']
        for index, (event, source) in enumerate(zip(actual['settingsEvents'], settings['events'])):
            expected = {k: source.get(k, [] if k in ['arguments', 'strings'] else None) for k in semantic_fields}
            if source['kind'] == 'settingsReturn':
                assert expected['arguments'][0] == 0x1000f000
                expected['result'] = expected['arguments'][1]; expected['arguments'] = []
            observed = {k: event.get(k, [] if k in ['arguments', 'strings'] else None) for k in semantic_fields}
            assert typed_equal(observed, expected), f'typed settings event {index}'
            if 'globals' in source:
                globals_record(event['globals'], source['globals'], f'settings checkpoint {index}')
            if 'scratch' in source:
                stored(event['scratch'], source['scratch'], f'scratch checkpoint {index}')
        globals_record(actual['globals'], settings['globals'], 'final globals')
        stored(actual['scratch'], settings['scratch'], 'final scratch')
        assert typed_equal(actual['settingsContinuation'], settings['continuation'])
        results.append({'profile': profile, 'fixture': name, 'fixtureSHA256': pinned,
                        'records': records, 'semanticBytesAndMasks': semantic_bytes,
                        'frontEvents': 6892, 'settingsEvents': 63, 'bitmapRecords': 24,
                        'actualSHA256': digest(ready_path.read_bytes()), 'pass': True})
    return results
