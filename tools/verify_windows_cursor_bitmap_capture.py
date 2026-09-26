#!/usr/bin/env python3
"""Check cursor collector structure/provenance; never accept game equivalence.

Reported bitmap bytes are observations, not initialization guarantees or write
masks. API failures and collector descriptor boundaries remain distinct outcomes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
from build_windows_cursor_bitmap_probe import EXE_SHA, RESOURCE_SHA


def sha(data): return hashlib.sha256(data).hexdigest()


def verify_raw(data, machine, *, resource_sha=RESOURCE_SHA):
    assert data['schema'] == 'ntsd-windows-cursor-bitmap-v1'
    assert data['kind'] == 'windowsAPICollectorOutput' and data['complete'] is True
    assert data['gameExecuted'] is False and data['storageSnapshotsAreWriteMasks'] is False
    assert data['resourceName'] == 'LF2_CURSOR' and data['lastErrorSeed'] == 0x6e747364
    assert data['systemModuleFlags'] == 0x800
    env = data['environment']; width = 4 if machine == 0x14c else 8
    assert env['compiledMachine'] == machine and env['pointerBits'] == width * 8
    assert [m['name'] for m in env['modules']] == ['kernel32.dll', 'user32.dll', 'gdi32.dll']
    for m in env['modules']:
        assert len(bytes.fromhex(m['pathUTF16LE'])) == min(m['pathCharacters'], 1024) * 2
    def handle(item, key):
        raw = bytes.fromhex(item[key]); assert len(raw) == width
        return int.from_bytes(raw, 'little')
    def reply(item, key):
        r = item[key]
        assert all(isinstance(r[k], int) and 0 <= r[k] <= 0xffffffff
                   for k in ('resultBits', 'lastErrorAfter'))
        return r['resultBits']
    resource = data['resource']; assert resource['moduleFlags'] == 0x60
    handle(resource, 'module')
    available = 'raw' in resource
    if available:
        raw = bytes.fromhex(resource['raw']); assert len(raw) == resource['bytes']
        assert 0 < len(raw) <= 65536 and sha(raw) == resource_sha
        assert handle(resource, 'found') and handle(resource, 'data') and handle(resource, 'locked')
    attempts = data['attempts']; assert len(attempts) == (3 if available and data['functionsReady'] else 0)
    results = []
    for index, a in enumerate(attempts):
        assert a['index'] == index
        assert (a['loadImageType'], a['loadImageFlags'], a['requestedWidth'], a['requestedHeight']) == (0, 0x2000, 0, 0)
        result = dict(index=index, outcome='load-failed')
        if not handle(a, 'bitmap'):
            assert a['observation'] == 'load-failed' and 'descriptorAfter' not in a
            results.append(result); continue
        size = 84 if width == 4 else 104
        assert bytes.fromhex(a['descriptorBefore']) == b'\xa5' * size
        desc = bytes.fromhex(a['descriptorAfter']); assert len(desc) == size
        got = reply(a, 'getObject')
        bmtype, w, h, stride, planes, bpp = struct.unpack_from('<iiiiHH', desc)
        bits = int.from_bytes(desc[20 if width == 4 else 24:24 if width == 4 else 32], 'little')
        header = struct.unpack_from('<IiiHHIIiiII', desc, 24 if width == 4 else 32)
        valid = got == size and (w, h, planes, bpp) == (11, 19, 1, 8) and 11 <= stride <= 4096 and bits != 0
        valid = valid and header[:2] == (40, 11) and header[2] in (19, -19) and header[3:6] == (1, 8, 0)
        assert a['descriptorAccepted'] is bool(valid)
        result['deleteObjectResult'] = reply(a, 'deleteObject')
        if not valid:
            assert 'storageBeforePalette' not in a and 'memoryDC' not in a
            result['outcome'] = 'get-object-failed' if got == 0 else 'collector-descriptor-boundary'
            results.append(result); continue
        n = stride * 19; assert a['storageBytes'] == n
        before, after = (bytes.fromhex(a[k]) for k in ('storageBeforePalette', 'storageAfterPalette'))
        assert len(before) == len(after) == n
        result.update(outcome='storage-only', storageBeforeSHA256=sha(before), storageAfterSHA256=sha(after),
                      changedStorageBytes=sum(x != y for x, y in zip(before, after)),
                      bitmapType=bmtype, stride=stride, headerHeight=header[2])
        dc = handle(a, 'memoryDC')
        if dc:
            assert [c['index'] for c in a['deviceCaps']] == [2, 12, 14, 38, 88, 90]
            result['deleteDCResult'] = reply(a, 'deleteDC')
            previous = handle(a, 'previousObject')
            if previous not in (0, (1 << (8 * width)) - 1):
                count = reply(a, 'getPalette'); assert count <= 256
                assert bytes.fromhex(a['paletteBefore']) == b'\xa5' * 1024
                palette = bytes.fromhex(a['paletteAfter']); assert len(palette) == 1024
                result['restoreResult'] = handle(a, 'restoreResult')
                result['paletteCount'] = count
                if count:
                    # Interpret only API-returned entries, never untouched tail.
                    indices = [before[(18-y if header[2] > 0 else y)*stride+x]
                               for y in range(19) for x in range(11)]
                    unresolved = [i for i, value in enumerate(indices) if value >= count]
                    result['indicesWithoutReturnedPaletteEntry'] = unresolved
                    if not unresolved:
                        rgb = b''.join(palette[value*4:value*4+3][::-1] for value in indices)
                        result.update(outcome='observed-rgb', rgbTopLeft=rgb.hex(), rgbSHA256=sha(rgb))
                    else:
                        result['outcome'] = 'palette-coverage-boundary'
        results.append(result)
    return dict(attempts=results, resourceAvailable=available, compiledMachine=machine,
                structuralVerificationOnly=True, initializationGuaranteed=False,
                gameExecuted=False, nativeCompared=False, compatibilityAccepted=False)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('capture', type=Path)
    p.add_argument('--manifest-sha256', required=True)
    a = p.parse_args()
    run = json.loads((a.capture / 'run.json').read_text(encoding='utf-8-sig'))
    manifest_bytes = (a.capture / 'manifest.json').read_bytes(); manifest = json.loads(manifest_bytes)
    assert sha(manifest_bytes) == a.manifest_sha256 == run['manifestSHA256']
    assert manifest['schema'] == 'ntsd-windows-cursor-bitmap-build-v1'
    assert manifest['referenceEXESHA256'] == run['referenceEXESHA256'] == EXE_SHA
    assert manifest['resourceSHA256'] == RESOURCE_SHA and manifest['resourceName'] == 'LF2_CURSOR'
    assert run['schema'] == 'ntsd-windows-cursor-bitmap-run-v1'
    assert run['complete'] is True and run['failure'] is None and run['gameExecuted'] is False
    assert run['environmentDescription'].strip() and run['windowsRegistry']['CurrentBuildNumber']
    captures = {}
    for c in run['captures']:
        arch = c['architecture']; assert arch in ('x86', 'arm64') and arch not in captures
        assert c['exitCode'] == 0 and c['timedOut'] is False and c['terminal'] is True and c['rawExists'] is True
        assert c['processId'] > 0 and c['processStartUTC'] and c['executable'] and c['launchWorkingDirectory']
        directory = a.capture / arch; raw = (directory / 'cursor.json').read_bytes()
        assert sha(raw) == c['sha256'] and len(raw) == c['bytes']
        assert sha((directory / 'reference.exe').read_bytes()) == c['referenceAfterSHA256'] == EXE_SHA
        captures[arch] = verify_raw(json.loads(raw), manifest['binaries'][arch]['machine'])
    assert captures
    print(json.dumps(dict(schema='ntsd-windows-cursor-bitmap-verification-v1', captures=captures,
                          run=run, structuralVerificationOnly=True, compatibilityAccepted=False), indent=2))


if __name__ == '__main__': main()
