#!/usr/bin/env python3
"""Accept both own initialized whole notice continuations, preserving170 pins."""
import base64
import json
import os
import subprocess
import zlib
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old = json.loads((ROOT/'build/research/posthud-notices-fixture-pins.json').read_bytes())
    assert len(old) == 170 and all(pins[n] == sha for n, sha in old.items())
    lines = (ROOT/'build/research/compact.asm').read_text().splitlines()
    static = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
              and all(c in '0123456789abcdef' for c in line[:6]) and 0x421a2d <= int(line[:6], 16) < 0x421cdc}
    assert len(static) == 198
    captures = []
    for suffix in ('', '-control'):
        name = 'gameplay-notices'+suffix
        report, raw, doc = capture(name)
        parent_report, parent = historical('gameplay-hud'+suffix)
        assert doc['parent'] == report['parent'] == dict(fixture=parent_report['fixture'], sha256=parent_report['fixtureSHA256'])
        assert doc['control'] == bool(suffix) and len(doc['cases']) == 1
        for key in ('worldAddress', 'actorAddresses', 'objectAddresses'): assert doc[key] == parent[key]
        c = doc['cases'][0]; n = c['notices']
        assert c['label'] == 'post-hud-notices'
        assert c['before'] == parent['cases'][0]['after'] == c['after']
        assert c['end'] == report['end'] == dict(pc=0x421cdc, sp=0x1000e9bc)
        assert c['checkpoints'] == c['helpers'] == c['readsBeforeWrites'] == []
        assert c['readsBeforeWrites'] == report['readsBeforeWrites'] and report['helpers'] == report['events'] == 0
        assert n['events'] == n['fillInputs'] == n['localAccesses'] == report['localAccesses'] == []
        assert n['localBefore'] == n['localAfter'] and len(bytes.fromhex(n['localBefore'])) == 0x158 and n['localWritten'] == [0]*0x158
        assert n['flags'] == {'0x450bec': 0, '0x450c2c': 0, '0x450c28': 0, '0x451160': 0}
        assert (n['target'], n['dcResult'], n['dc'], n['methodResult'], n['esi'], n['edi']) == (0x28002020, 0, 0x12345678, 0, 0x7817775d, 0)
        observed = set(c['instructions'])
        executed = {0x421a2d, 0x421a33, 0x421a39, 0x421b30, 0x421b37, 0x421c0a, 0x421c0f, 0x421c12, 0x421ca8, 0x421cab}
        assert executed <= static and observed == executed | {0x421cdc}
        assert len(observed) == len(c['instructions']) == report['instructions'] == 11
        audit, before = doc['fpu'], parent['fpu']
        for field in ('initialization', 'transitions', 'watchedInstructions'): assert audit[field] == before[field]
        assert len(before['checkpoints']) == 1603 and audit['checkpoints'][:-1] == before['checkpoints']
        assert len(audit['checkpoints']) == report['fpuCheckpoints'] == 1604
        assert audit['checkpoints'][-1] == dict(pc=0x421a2d, sp=0x1000e9bc, fpcw=0x23f, fpsw=0x4000)
        assert all(c['fpcw'] == 0x23f for c in audit['checkpoints'])
        assert n['fpcw'] == report['fpcw'] == 0x23f and n['fpswBefore'] == n['fpswAfter'] == 0x4000
        assert n['fptagBefore'] == n['fptagAfter'] == 0xffff
        for key, blob in doc['blobs'].items():
            value = zlib.decompress(base64.b64decode(blob['deflate']), -15)
            assert len(value) == blob['count'] and digest(value) == key
        report.update(initializedParentReproduced=True, parentSHA256=parent_report['sha256'],
            instructionCoverage=dict(callerStaticStarts=len(static), executedOriginalStarts=len(executed), missing=sorted(static-executed)),
            observedUnexecutedTerminal=0x421cdc, sourceStateBeforeAfterIdentical=True,
            sourceLocalAndCookieBytesUntouched=0x158, nativeCallerBackingRemainsUnknown=True,
            sourceLocalBytesImportedToNative=False, newPlatformCalls=0,
            sourceFPUEntryExitIdentical=True, hardwareFPUCompared=False, firstTickReturned=False, pixelsCompared=False)
        captures.append((name, report, raw))
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalGameplayNoticesTests'], env=dict(os.environ,
                    NTSD_GAMEPLAY_NOTICES_DIRECTORY=str(ROOT/'build/original')), check=True)
    publish(captures, pins, pin_name='gameplay-notices-fixture-pins.json')

if __name__ == '__main__': main()
