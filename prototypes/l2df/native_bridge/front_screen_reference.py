"""External two-parent first-return comparison. Never imported by native runtime."""
import base64
import copy
import json

FIXTURES = [
    ('original-menu-loading.json', 'c7aa707bb32d37837704b94d0afd98baac26f23f2f28b9d668f27fa2ca2a7e7f'),
    ('original-menu-loading-control.json', '54334dd243f5c24ee52e47d386e07a214bc76dff209c30c1d954276ead7b6efd'),
]


def compare(project, fixture_root, manifest_sha, reference):
    unpack, digest, typed_equal = reference.unpack, reference.digest, reference.typed_equal
    reports = []
    for profile, (name, pinned) in enumerate(FIXTURES):
        raw = (fixture_root / name).read_bytes()
        assert digest(raw) == pinned
        document = json.loads(unpack(json.loads(raw)))
        completion = document['parent']
        alternate = completion['parent']
        body = alternate['parent']
        panel = body['parent']
        prefix = panel['parent']
        settings = prefix['parent']
        parents = [prefix, panel, body, alternate, completion]
        for section in parents:
            assert section['exeSHA256'] == '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
            assert section['dllSHA256'] == 'c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
            assert section['cases'][0]['stimulus'] == []
        assert typed_equal(completion['initialCRT'], 1) and typed_equal(completion['initialPointers'], [0] * 8)
        source = completion['cases'][0]
        assert source['entry'] == 'main' and source['mainExit'] == 'present' and source['random'] == []
        assert typed_equal(source['abi'], {'endPC': 0x30000000, 'endSP': 0x1000f42c,
            'saved': [0x11223344, 0x22334455, 0x33445566, 0x44556677], 'seh': 0x12345678})
        expected_counts = [17 if profile == 0 else 24, 2, 153, 0, 11, 20 if profile == 0 else 27]
        assert typed_equal(source['mainEvents'], 11)
        ready_path = project / f'loaded-{profile}-ready.json'
        result_path = project / f'front-{profile}-returned.json'
        actual = json.loads(result_path.read_bytes())
        ready = json.loads(ready_path.read_bytes())
        assert (project / f'front-{profile}-rollback.json').read_bytes() == ready_path.read_bytes()
        assert (project / f'front-{profile}-fresh.json').read_bytes() == result_path.read_bytes()
        if profile == 0:
            assert (project / 'front-0-after-resource-removal.json').read_bytes() == result_path.read_bytes()
        assert 'frontScreen' not in ready
        assert actual.keys() == ready.keys() | {'frontScreen'}
        assert typed_equal({k: actual[k] for k in ['schema', 'profile', 'lifecycle', 'revision', 'manifestSHA256']},
            dict(schema=1, profile=profile, lifecycle=4, revision=2, manifestSHA256=manifest_sha))
        # Earlier observations remain the exact accepted history, not rewritten
        # to the new parent's five platform bindings.
        for key in ready.keys() - {'globals', 'world', 'replayPointers', 'lifecycle', 'revision'}:
            assert typed_equal(actual[key], ready[key]), 'preserved earlier owner history ' + key
        screen = actual['frontScreen']
        assert typed_equal(sorted(screen), sorted(['phases', 'assets', 'records', 'crtState', 'local',
            'retainedOperation', 'replayPointers', 'ownedDIBCount', 'ownedDIBBytes', 'ownedDIBSHA256', 'inputs']))
        records = byte_count = 0

        def blob(key):
            data = unpack(document['blobs'][key]); assert digest(data) == key
            return data

        def decoded(value):
            assert set(value) == {'bytes', 'defined'}
            b, m = [base64.b64decode(value[k], validate=True) for k in ['bytes', 'defined']]
            assert len(b) == len(m) and set(m) <= {0, 1}
            return b, m

        def record(value, b, m, label):
            nonlocal records, byte_count
            ab, am = decoded(value)
            assert ab == b, label + ' complete bytes'
            assert am == m, label + ' complete mask'
            records += 1; byte_count += len(b)

        def stored(value, source, label):
            record(value, blob(source['bytes']), blob(source['defined']), label)

        def globals_record(value, key, label):
            b = blob(key); assert len(b) == 0xb440
            record(value, b, bytes([1]) * len(b), label)

        def allocations(values, expected, label):
            by_address = {v['address']: v for v in values}
            assert len(values) == len(by_address) == len(expected) == 25, label + ' unique complete allocation set'
            assert typed_equal(sorted(by_address), sorted(v['address'] for v in expected))
            for v in expected:
                item = by_address[v['address']]
                assert set(item) == {'address', 'live', 'storage'}
                assert typed_equal(item['live'], v.get('live', True))
                raw_surface, raw_mask = blob(v['storage']['bytes']), blob(v['storage']['defined'])
                assert raw_mask[:4] == bytes([1]) * 4
                assert int.from_bytes(raw_surface[:4], 'little') == source_assets[v['address']][1]
                stored(item['storage'], v['storage'], label + ' allocation')

        # Independent late-binding provenance: exact former ready bytes plus
        # these five declared fields, no arbitrary replacement snapshot.
        overlaid, mask = decoded(ready['globals']); overlaid = bytearray(overlaid)
        for address, value in [(0x455608, 0x28002020), (0x44eecc, 0x28002020),
                               (0x453e0c, 0x28002020), (0x455634, 0x28002020), (0x458348, 1 if profile == 0 else 3)]:
            overlaid[address - 0x44d000:address - 0x44d000 + 4] = value.to_bytes(4, 'little')
        assert bytes(overlaid) == blob(prefix['initialGlobals']) and mask == bytes([1]) * 0xb440

        assets = screen['assets']; by_address = {v['address']: v for v in assets}
        assert len(assets) == len(by_address) == 25
        source_assets = {}
        front = settings['front']
        for v in front['inputs']:
            address = front['allocations'][v['index']]['address']
            source_assets[address] = (v['resource'], v['surface'])
        first_prefix = prefix['cases'][0]
        source_assets[first_prefix['allocation']['address']] = (first_prefix['bitmapInput']['resource'], first_prefix['bitmapInput']['surface'])
        assert typed_equal(sorted(by_address), sorted(source_assets))
        for address, (resource, surface) in source_assets.items():
            assert typed_equal(by_address[address], {'address': address, 'generation': 1,
                'resourceKey': resource['path'], 'rawSurface': surface, 'input': resource})
        background = next(v for v in prefix['sources'] if v['path'] == 'MENU_BACK1')
        dib = blob(background['dib'])
        assert typed_equal({k: screen[k] for k in ['ownedDIBCount', 'ownedDIBBytes', 'ownedDIBSHA256']},
            {'ownedDIBCount': 1, 'ownedDIBBytes': len(dib), 'ownedDIBSHA256': {'MENU_BACK1': digest(dib)}})
        expected_inputs = {'prefix': first_prefix['input'], 'body': body['cases'][0]['input'],
            'alternate': alternate['cases'][0]['input'], 'completion': source['input']}
        assert typed_equal(screen['inputs'], expected_inputs), 'all declared platform inputs and owner-derived selector/targets'

        private_source = body['cases'][0]['local']
        private_bytes, private_mask = blob(private_source['bytes']), bytearray(blob(private_source['defined']))
        assert len(private_bytes) == len(private_mask) == 192 and sum(private_mask) == 92
        private_mask[0x20:0x24] = bytes([1]) * 4
        expected_local = bytes(v if private_mask[i] else 0 for i, v in enumerate(private_bytes))
        assert sum(private_mask) == 96

        # Replay each observable producer independently. At every raw string
        # read/decode, bytes through NUL must be initialized; target has own input.
        local, known = bytearray(192), bytearray(192)
        local[0x20:0x24] = (0x28002020).to_bytes(4, 'little'); known[0x20:0x24] = bytes([1]) * 4
        writes = texts = 0
        decode_row = decode_index = 0
        offsets = [0x48, 0x84, 0x64]
        copy_stores = []
        assert len(body['literals']) == 3
        for row, start in zip(body['literals'], offsets):
            literal = bytes(row['bytes']); assert len(literal) in (28, 31, 29) and literal[-1] == 0
            for offset in range(0, 28, 4):
                copy_stores.append((start + offset, 4, int.from_bytes(literal[offset:offset+4], 'little')))
            if len(literal) == 31:
                copy_stores.extend([(start + 28, 2, int.from_bytes(literal[28:30], 'little')), (start + 30, 1, literal[30])])
            elif len(literal) == 29:
                copy_stores.append((start + 28, 1, literal[28]))
        assert len(copy_stores) == 24
        panel_globals = blob(panel['cases'][0]['globals'])
        raw_y = int.from_bytes(panel_globals[0x45757c-0x44d000:0x457580-0x44d000], 'little')

        def string(offset):
            output = bytearray()
            for index in range(offset, len(local)):
                assert known[index] == 1, 'unknown private string operand'
                if local[index] == 0:
                    return list(output)
                output.append(local[index])
            raise AssertionError('unterminated private string')

        phases = screen['phases']
        names = ['prefix', 'panel', 'body', 'alternate', 'main', 'completion']
        assert len(phases) == 6 and typed_equal([p['name'] for p in phases], names)
        expected_phases = [prefix['cases'][0], panel['cases'][0], body['cases'][0], alternate['cases'][0],
            dict(source['mainAfter'], events=source['events'][:source['mainEvents']], continuation=source['mainExit']),
            dict(source['after'], events=source['events'], continuation='returned')]
        for index, (phase, expected) in enumerate(zip(phases, expected_phases)):
            keys = {'name', 'continuation', 'events', 'drawOwners', 'world', 'globals', 'records',
                    'replayPointers', 'crtState', 'retainedOperation'}
            assert set(phase) == (keys | {'local'} if index >= 2 else keys)
            assert len(phase['events']) == len(expected['events']) == expected_counts[index]
            expected_events = copy.deepcopy(expected['events'])
            for e in expected_events:
                if 'fill' in e:
                    fill = e['fill']; mask = [i < 4 or 0x50 <= i < 0x54 for i in range(100)]
                    assert typed_equal(fill['defined'], mask)
                    assert len(fill['effects']) == 100
                    fill['effects'] = [v if mask[i] else 0 for i, v in enumerate(fill['effects'])]
            assert typed_equal(phase['events'], expected_events), phase['name'] + ' complete semantic events'
            assert typed_equal(phase['continuation'], expected['continuation'])
            globals_record(phase['globals'], expected['globals'], phase['name'] + ' globals')
            stored(phase['world'], expected['world'], phase['name'] + ' World')
            allocations(phase['records'], expected['records'], phase['name'])
            assert typed_equal(phase['crtState'], expected.get('crtState', 1))
            assert typed_equal(phase['retainedOperation'], 'sleep')
            record(phase['replayPointers'], bytes(expected.get('pointers', [0] * 8)), bytes([1]) * 8, 'BSS replay pointers')
            if index < 2:
                assert 'local' not in phase
            else:
                record(phase['local'], expected_local, bytes(private_mask), 'own private local projection')
            expected_owners = []
            for event_index, e in enumerate(phase['events']):
                if e['kind'] == 'draw':
                    args = e['arguments']; assert len(args) == 7
                    asset = by_address[args[0]]
                    expected_owners.append({'eventIndex': event_index, 'address': asset['address'], 'generation': 1,
                        'resourceKey': asset['resourceKey'], 'rawSource': asset['rawSurface'], 'rawTarget': args[6], 'targetRole': 'backbuffer'})
                if index != 2:
                    continue
                if e['kind'] == 'writeLocal':
                    offset, count, value = e['arguments']; assert count in (1, 2, 4)
                    assert 0 <= offset <= 192 - count
                    if writes < 24:
                        assert (offset, count, value) == copy_stores[writes]
                    elif writes == 24:
                        assert (offset, count, value) == (0x14, 4, (raw_y + 491) & 0xffffffff)
                    if writes >= 25:
                        for start in offsets: string(start)
                        assert known[offset:offset+count] == bytes([1]) * count
                        while decode_row < 3 and decode_index >= len(string(offsets[decode_row])):
                            decode_row += 1; decode_index = 0
                        assert decode_row < 3 and count == 1 and offset == offsets[decode_row] + decode_index
                        assert value == ((local[offset] - (decode_index & 3)) & 255)
                        decode_index += 1
                    local[offset:offset+count] = value.to_bytes(4, 'little')[:count]
                    known[offset:offset+count] = bytes([1]) * count
                    writes += 1
                elif e['kind'] == 'text':
                    assert texts < 3 and typed_equal(e['strings'], [string(offsets[texts])])
                    texts += 1
                elif e['kind'] == 'draw':
                    assert known[0x20:0x24] == bytes([1]) * 4
                    assert typed_equal(e['arguments'][6], int.from_bytes(local[0x20:0x24], 'little'))
            assert typed_equal(phase['drawOwners'], expected_owners)
        assert texts == 3 and writes == 110 and bytes(local) == expected_local and known == private_mask
        record(screen['local'], bytes(local), bytes(known), 'independent local write/read reconstruction')
        globals_record(actual['globals'], source['after']['globals'], 'persistent final globals')
        stored(actual['world'], source['after']['world'], 'persistent final World')
        allocations(screen['records'], source['after']['records'], 'persistent final allocations')
        assert typed_equal(screen['crtState'], source['after']['crtState']) and screen['retainedOperation'] == 'sleep'
        for value in [actual['replayPointers'], screen['replayPointers']]:
            record(value, bytes(source['after']['pointers']), bytes([1]) * 8, 'persistent pointers')
        reports.append({'profile': profile, 'pass': True, 'fixture': name, 'fixtureSHA256': pinned,
            'actualSHA256': digest(result_path.read_bytes()), 'phases': names, 'phaseEvents': expected_counts,
            'recordComparisons': records, 'recordBytes': byte_count, 'maskBytes': byte_count,
            'privateBodyKnownBytes': sum(known), 'privateFillKnownBytes': 8, 'ownedBitmapRecords': 25,
            'scope': 'Two controlled pristine first returns with independently checked own private projection; no device/application/gameplay claim'})
    return reports
