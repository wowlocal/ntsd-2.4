#!/usr/bin/env python3
"""Compare both initialized matches through the whole HUD before publication."""
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old = json.loads((ROOT/'build/research/world-hud-fixture-pins.json').read_bytes())
    assert len(old) == 166 and all(pins[n] == sha for n, sha in old.items())
    lines = (ROOT/'build/research/compact.asm').read_text().splitlines()
    captures = []
    for suffix in ('', '-control'):
        control = bool(suffix)
        name = 'gameplay-hud'+suffix
        report, raw, doc = capture(name)
        parent_report, parent = historical('gameplay-commands'+suffix)
        assert doc['parent'] == report['parent'] == dict(fixture=parent_report['fixture'], sha256=parent_report['fixtureSHA256'])
        assert doc['control'] == control and len(doc['cases']) == 1
        for key in ('worldAddress', 'actorAddresses', 'objectAddresses'):
            assert doc[key] == parent[key]
        section = doc['cases'][0]
        assert section['label'] == 'world-hud'
        assert section['before'] == parent['cases'][0]['after'] == section['after']
        assert section['end'] == report['end'] == dict(pc=0x421a2d, sp=0x1000e9bc)
        assert section['checkpoints'] == []
        assert section['readsBeforeWrites'] == report['readsBeforeWrites'] == [
            ['bitmap', 12, 4, 0x43f04b], ['bitmap', 12, 4, 0x43f183]]
        kinds = Counter(e['kind'] for e in section['drawing']['events'])
        assert kinds == dict(draw=12, read=112 if control else 72, clip=20 if control else 12,
                             blit=28 if control else 20, rectangle=8)
        assert sum(kinds.values()) == report['events'] == (180 if control else 124)
        helpers = section['helpers']
        assert len(helpers) == report['helpers'] == (41 if control else 33)
        assert Counter(h['entry'] for h in helpers) == {0x41ae60: 1, 0x43f010: 12, 0x43f310: 8, 0x43ef70: kinds['clip']}
        abi = {0x41ae60: (1, 4), 0x43f010: (6, 24), 0x43ef70: (6, 0), 0x43f310: (7, 28)}
        for h in helpers:
            count, pop = abi[h['entry']]
            assert len(h['arguments']) == count and h['pop'] == pop and h['returnSP'] == h['entrySP']+4+pop
        observed = set(section['instructions'])
        assert len(observed) == len(section['instructions']) == report['instructions'] == (426 if control else 421)
        inventories = {}
        executed_pcs = set()
        for start, end, count, executed in [(0x421a15, 0x421a28, 6, 6), (0x41ae60, 0x41b12d, 223, 177),
                (0x43ef70, 0x43f000, 57, 32 if control else 27), (0x43f010, 0x43f2fe, 214, 171), (0x43f310, 0x43f37a, 38, 38)]:
            expected = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
                        and all(c in '0123456789abcdef' for c in line[:6]) and start <= int(line[:6], 16) <= end}
            actual = {pc for pc in observed if start <= pc <= end}
            assert len(expected) == count and len(actual) == executed and actual <= expected
            inventories[hex(start)] = dict(instructions=count, executed=executed, missing=sorted(expected-actual))
            executed_pcs.update(actual)
        # PAPI is the inherited COM host boundary; the terminal instruction is
        # observed before emu_stop but never executed by this continuation.
        assert observed-executed_pcs == {0x30009000, 0x421a2d}
        audit, before = doc['fpu'], parent['fpu']
        for field in ('initialization', 'transitions', 'watchedInstructions'):
            assert audit[field] == before[field]
        count = len(before['checkpoints'])
        assert count == 1593 and audit['checkpoints'][:count] == before['checkpoints']
        assert len(audit['checkpoints']) == report['fpuCheckpoints'] == 1603
        extra = audit['checkpoints'][count:]
        assert [c['pc'] for c in extra] == [0x421a15, 0x41ae60]+[0x41ae70]*8
        assert [c['sp'] for c in extra] == [0x1000e9bc, 0x1000e9b4]+[0x1000e99c]*8
        assert all(c['fpcw'] == 0x23f for c in audit['checkpoints'])
        hud = section['hud']
        assert hud['fpcw'] == report['fpcw'] == 0x23f
        assert hud['fptagBefore'] == hud['fptagAfter'] == 0xffff
        assert hud['fpswBefore'] == hud['fpswAfter'] == 0x4000
        assert hud['argument'] == hud['retainedAfter'] == 0x28002020
        assert hud['argumentAccesses'] == report['argumentAccesses'] == [
            dict(pc=0x421a15, offset=0x68, size=4, write=False), dict(pc=0x421a19, offset=-4, size=4, write=True)]
        undefined = Counter((e['read']['offset'], e['read']['value']) for e in section['drawing']['events']
                            if e['kind'] == 'read' and not e['read']['defined'])
        assert undefined == ({(12, 0x0f0e0d0c): 24, (4012, 0xafaeadac): 8, (2012, 0xdfdedddc): 8,
                              (6012, 0x7f7e7d7c): 8, (12, 0xa5a5a5a5): 4} if control else {(12, 0xa5a5a5a5): 20})
        for key, blob in doc['blobs'].items():
            value = zlib.decompress(base64.b64decode(blob['deflate']), -15)
            assert len(value) == blob['count'] and digest(value) == key
        report.update(initializedParentReproduced=True, parentSHA256=parent_report['sha256'],
            instructionCoverage=inventories, executedInstructions=len(executed_pcs), observedHostBoundary=0x30009000,
            observedUnexecutedTerminal=0x421a2d, eventKinds=dict(kinds), undefinedBitmapReadEvents=sum(undefined.values()),
            hudStackArgumentRead=False, nativeTargetSource='independently rebuilt global455608',
            fpuExit='Explicit equal-entry/exit CW assertion', firstTickReturned=False, pixelsCompared=False)
        captures.append((name, report, raw))
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalGameplayHUDTests'],
                   env=dict(os.environ, NTSD_GAMEPLAY_HUD_DIRECTORY=str(ROOT/'build/original')), check=True)
    publish(captures, pins, pin_name='gameplay-hud-fixture-pins.json')


if __name__ == '__main__':
    main()
