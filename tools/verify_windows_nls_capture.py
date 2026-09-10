#!/usr/bin/env python3
"""Verify a bounded Windows NLS capture without supplying expected API outputs.

Checks the observed NUL input, every complete before/after buffer, own-output
dependency bytes, raw hashes and declared OS metadata. Failed API calls remain
failures; this never accepts a full CRT/game/native match or changes a fixture.
"""
import argparse
import hashlib
import json
from pathlib import Path


def sha(b): return hashlib.sha256(b).hexdigest()


def verify_raw(data, machine):
    assert data['schema'] == 'ntsd-windows-nls-v1'
    assert data['kind'] == 'windowsAPICollectorOutput' and data['complete'] is True
    env = data['environment']
    assert env['compiledMachine'] == machine
    assert env['pointerBits'] == (32 if machine == 0x14c else 64)
    assert len(bytes.fromhex(env['getVersionExW']['structureAfter'])) == 284
    for module in env['modules']:
        assert len(bytes.fromhex(module['pathUTF16LE'])) == module['pathCharacters'] * 2
    if env['getNLSVersionEx']['available']:
        assert len(bytes.fromhex(env['getNLSVersionEx']['structureAfter'])) == 32
    cases = data['cases']
    assert data['caseCount'] == len(cases)
    ids = {}
    for i, c in enumerate(cases):
        assert c['id'] == i
        ids[i] = c
        assert c['lastErrorBefore'] == 0x6e747364
        assert 0 <= c['resultBits'] <= 0xffffffff and 0 <= c['lastErrorAfter'] <= 0xffffffff
        source = bytes.fromhex(c['sourceBytes'])
        before, after = (bytes.fromhex(c[k]) for k in ('destinationBefore', 'destinationAfter'))
        cap = c['destinationCapacity']
        unit = 2 if c['api'] in ('GetStringTypeW', 'MultiByteToWideChar', 'LCMapStringW') else 1
        assert len(before) == len(after) == cap * unit
        if 'parentConversion' in c:
            parent = ids[c['parentConversion']]
            assert parent['id'] < i and parent['api'] == 'MultiByteToWideChar'
            assert 0 < parent['resultBits'] <= 512
            assert c['sourceCount'] == parent['resultBits']
            assert source == bytes.fromhex(parent['destinationAfter'])[:2 * parent['resultBits']]
        if c['api'] == 'GetStringTypeW':
            assert c['infoType'] == 1 and len(source) == c['sourceCount'] * 2
            assert cap == c['sourceCount']
        elif c['api'] == 'GetCPInfo':
            assert c['codePage'] == 1252 and source == b'' and cap == 20
        elif c['api'] == 'MultiByteToWideChar':
            assert c['codePage'] == 1252 and c['flags'] in (0, 1)
            assert source == bytes(range(256)) and c['sourceCount'] == 256 and cap == 512
            assert c['resultBits'] <= cap
        elif c['api'] == 'LCMapStringW':
            assert c['locale'] == 0x409 and c['flags'] in (0x100, 0x200) and cap == 1024
            assert c['resultBits'] <= cap
        elif c['api'] == 'WideCharToMultiByte':
            assert c['codePage'] == 1252 and c['flags'] == 0 and cap == 1024
            assert c['defaultChar'] is None and c['usedDefaultBefore'] == 0x5a5a5a5a
            assert c['resultBits'] <= cap
        else:
            raise ValueError(('Unexpected API', c['api']))
    assert cases[0]['destinationBefore'] == 'd8e9'
    assert cases[1]['destinationBefore'] == 'a5a5'
    for c in cases[:2]:
        assert c['api'] == 'GetStringTypeW' and c['sourceBytes'] == '0000'
        assert c['sourceCount'] == c['destinationCapacity'] == 1 and 'parentConversion' not in c
    assert [c['api'] for c in cases[2:4]] == ['GetCPInfo'] * 2
    assert cases[2]['destinationBefore'] == '00' * 20
    assert cases[3]['destinationBefore'] == 'a5' * 20
    cursor = 4
    for flags in (0, 1):
        for seed in (0, 0xa5):
            c = cases[cursor]
            assert c['api'] == 'MultiByteToWideChar' and c['flags'] == flags
            assert bytes.fromhex(c['destinationBefore']) == bytes([seed]) * 1024
            cursor += 1
            if c['resultBits']:
                children = cases[cursor:cursor + 4]
                assert [x['api'] for x in children] == ['GetStringTypeW', 'LCMapStringW', 'LCMapStringW', 'WideCharToMultiByte']
                assert [x['flags'] for x in children[1:3]] == [0x100, 0x200]
                for child in children:
                    assert child['parentConversion'] == c['id']
                    assert set(bytes.fromhex(child['destinationBefore'])) == {seed}
                cursor += 4
    assert cursor == len(cases)
    return dict(caseCount=len(cases), failedCases=[c['id'] for c in cases if c['resultBits'] == 0],
                nulRequests=[dict(id=c['id'], resultBits=c['resultBits'],
                                  output=c['destinationAfter'], lastErrorAfter=c['lastErrorAfter'])
                             for c in cases[:2]], compiledMachine=machine,
                environment=env, gameExecuted=False, nativeCompared=False,
                compatibilityAccepted=False)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('capture', type=Path)
    p.add_argument('--manifest-sha256', required=True, help='Trusted hash from the host build, not from capture contents')
    a = p.parse_args()
    run = json.loads((a.capture / 'run.json').read_text(encoding='utf-8-sig'))
    manifest_raw = (a.capture / 'manifest.json').read_bytes()
    assert sha(manifest_raw) == a.manifest_sha256 == run['manifestSHA256']
    manifest = json.loads(manifest_raw)
    assert manifest['schema'] == 'ntsd-windows-nls-build-v1'
    assert run['schema'] == 'ntsd-windows-nls-run-v1'
    assert run['complete'] is True and run['failure'] is None
    assert run['environmentDescription'].strip() and run['windowsRegistry']['CurrentBuildNumber']
    captures = {}
    for c in run['captures']:
        arch = c['architecture']
        assert arch in ('x86', 'arm64') and arch not in captures
        assert c['exitCode'] == 0 and c['rawExists'] is True
        raw = (a.capture / arch / 'nls.json').read_bytes()
        assert sha(raw) == c['sha256'] and len(raw) == c['bytes']
        captures[arch] = verify_raw(json.loads(raw), manifest['binaries'][arch]['machine'])
    assert captures
    print(json.dumps(dict(schema='ntsd-windows-nls-verification-v1', captures=captures,
                          metadata=run, structuralVerificationOnly=True,
                          compatibilityAccepted=False), indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
