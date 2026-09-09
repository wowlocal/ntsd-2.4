#!/usr/bin/env python3
"""Compare both initialized matches through resource commands before publication."""
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old_pins = json.loads((ROOT/'build/research/postdraw-commands-fixture-pins.json').read_bytes())
    assert len(old_pins) == 163 and all(pins[n] == sha for n, sha in old_pins.items())
    captures = []
    for suffix in ('', '-control'):
        name = 'gameplay-commands'+suffix
        report, raw, doc = capture(name)
        parent_report, parent = historical('gameplay-lifecycle'+suffix)
        assert doc['parent'] == report['parent'] == dict(fixture=parent_report['fixture'], sha256=parent_report['fixtureSHA256'])
        assert doc['control'] == bool(suffix) and len(doc['cases']) == 1
        assert doc['worldAddress'] == parent['worldAddress'] and doc['actorAddresses'] == parent['actorAddresses']
        assert doc['objectAddresses'] == parent['objectAddresses']
        section = doc['cases'][0]
        assert section['label'] == 'post-draw-commands'
        assert section['before'] == parent['cases'][0]['after']
        assert section['end'] == report['end'] == dict(pc=0x421a15, sp=0x1000e9bc)
        assert section['readsBeforeWrites'] == report['readsBeforeWrites'] == [] and section['checkpoints'] == []
        assert len(section['helpers']) == report['helpers'] == 0
        observed = set(section['instructions'])
        assert len(observed) == len(section['instructions']) == report['instructions']
        lines = (ROOT/'build/research/compact.asm').read_text().splitlines()
        expected = {int(line[:6], 16) for line in lines if len(line) > 6 and line[6] == ' '
                    and all(c in '0123456789abcdef' for c in line[:6]) and 0x4214d5 <= int(line[:6], 16) <= 0x421a15}
        assert observed <= expected and {0x4214d5, 0x4217b0, 0x4219f5, 0x421a15} <= observed
        audit, before = doc['fpu'], parent['fpu']
        for field in ['initialization', 'transitions', 'watchedInstructions']:
            assert audit[field] == before[field]
        count = len(before['checkpoints'])
        assert audit['checkpoints'][:count] == before['checkpoints'] and count == 1192
        assert len(audit['checkpoints']) == report['fpuCheckpoints'] == 1593
        extra = audit['checkpoints'][count:]
        assert [c['pc'] for c in extra] == [0x4214d5] + [0x4217b0]*400
        assert all(c['sp'] == 0x1000e9bc for c in extra)
        assert all(c['fpcw'] == 0x23f for c in audit['checkpoints'])
        commands = section['commands']
        assert commands['fpcw'] == report['fpcw'] == 0x23f
        assert commands['fptagBefore'] == commands['fptagAfter'] == 0xffff
        assert commands['fpswBefore'] >> 11 & 7 == commands['fpswAfter'] >> 11 & 7 == 0
        assert commands['retainedOffset'] == 0x34 and commands['retainedBefore'] == commands['retainedAfter']
        assert commands['scratchAccesses'] == report['scratchAccesses'] == []
        assert len(commands['events']) == report['events'] == 0
        for key, blob in doc['blobs'].items():
            value = zlib.decompress(base64.b64decode(blob['deflate']), -15)
            assert len(value) == blob['count'] and digest(value) == key
        report.update(initializedParentReproduced=True, nativeScratchInput='unknown; source does not access SP34',
                      observedPCsIncludeTerminalBoundary=True, executedInstructions=len(observed)-1,
                      fpuExit='Explicit equal-entry/exit CW assertion',
                      firstTickReturned=False, parentSHA256=parent_report['sha256'])
        captures.append((name, report, raw))
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalGameplayCommandsTests'],
                   env=dict(os.environ, NTSD_GAMEPLAY_COMMANDS_DIRECTORY=str(ROOT/'build/original')), check=True)
    publish(captures, pins, pin_name='gameplay-commands-fixture-pins.json')


if __name__ == '__main__':
    main()
