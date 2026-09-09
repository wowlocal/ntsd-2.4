#!/usr/bin/env python3
"""Compare both fresh initialized post-draw continuations before publication."""
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical, publish


def main():
    pins = {p.name: digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old_pins = json.loads((ROOT/'build/research/postdraw-lifecycle-fixture-pins.json').read_bytes())
    assert len(old_pins) == 160 and all(pins[n] == sha for n, sha in old_pins.items())
    captures = []
    for suffix in ('', '-control'):
        name = 'gameplay-lifecycle'+suffix
        report, raw, doc = capture(name)
        parent_report, parent = historical('initialized-gameplay'+suffix)
        assert doc['parent'] == report['parent'] == dict(fixture=parent_report['fixture'], sha256=parent_report['fixtureSHA256'])
        assert doc['control'] == bool(suffix) and len(doc['cases']) == 1
        assert doc['worldAddress'] == parent['worldAddress'] and doc['actorAddresses'] == parent['actorAddresses']
        assert doc['objectAddresses'] == parent['objectAddresses']
        section = doc['cases'][0]
        assert section['label'] == 'post-draw-lifecycle'
        assert section['before'] == parent['cases'][0]['after']
        assert section['end'] == report['end'] == dict(pc=0x4214d5, sp=0x1000e9bc)
        assert section['readsBeforeWrites'] == report['readsBeforeWrites'] == []
        assert len(section['helpers']) == report['helpers']
        assert len(set(section['instructions'])) == len(section['instructions']) == report['instructions']
        audit, before = doc['fpu'], parent['fpu']
        for field in ['initialization', 'transitions', 'watchedInstructions']:
            assert audit[field] == before[field]
        count = len(before['checkpoints'])
        assert audit['checkpoints'][:count] == before['checkpoints']
        assert len(audit['checkpoints']) == report['fpuCheckpoints'] > count
        assert len(audit['checkpoints']) == 1192 and count == 788
        assert Counter(c['pc'] for c in audit['checkpoints'][count:]) == {0x41f550: 400, 0x40d960: 2, 0x41fb0b: 2}
        # The earlier gameplay stop hook stops before the late terminal FPU
        # hook runs. The capture explicitly reads/asserts the same CW at exit;
        # its lifecycle.fpcw represents equal entry/exit words, not another
        # entry in this instruction-checkpoint array.
        assert audit['checkpoints'][-1]['pc'] == 0x41f550
        assert all(c['fpcw'] == 0x23f for c in audit['checkpoints'])
        lifecycle = section['lifecycle']
        assert lifecycle['fpcw'] == report['fpcw'] == 0x23f
        assert lifecycle['fptagBefore'] == lifecycle['fptagAfter'] == 0xffff
        assert lifecycle['fpswBefore'] >> 11 & 7 == lifecycle['fpswAfter'] >> 11 & 7 == 0
        assert lifecycle['scratchOffsets'] == [0x44, 0x50, 0x5c, 0x60, 0x6c, 0x70]
        assert len(lifecycle['scratchBefore']) == 6 and lifecycle['scratchBefore'] == lifecycle['scratchAfter']
        assert lifecycle['scratchAccesses'] == report['scratchAccesses'] == []
        assert len(lifecycle['events']) == report['events']
        assert report['helpers'] == 4 and report['events'] == 2 and report['instructions'] == 303
        assert [h['entry'] for h in section['helpers']] == [0x416fb0, 0x40d960, 0x416fb0, 0x40d960]
        assert [h['arguments'] for h in section['helpers']] == [[442, 6], [0, 0], [289, 6], [0, 1]]
        assert lifecycle['events'] == [dict(kind='catalogSound', slot=0, arguments=[442, 6]),
                                        dict(kind='catalogSound', slot=1, arguments=[289, 6])]
        for key, blob in doc['blobs'].items():
            value = zlib.decompress(base64.b64decode(blob['deflate']), -15)
            assert len(value) == blob['count'] and digest(value) == key
        report.update(initializedParentReproduced=True, nativeScratchInputs='unknown; source does not access these words',
                      observedPCsIncludeTerminalBoundary=True, executedInstructions=302,
                      fpuExit='Explicit equal-entry/exit CW assertion; terminal hook follows the stop hook',
                      firstTickReturned=False, parentSHA256=parent_report['sha256'])
        captures.append((name, report, raw))
    subprocess.run(['swift', 'test', '--package-path', str(ROOT/'native'), '-c', 'release', '--filter',
                    'OriginalGameplayLifecycleTests|OriginalInitializedGameplayTests|OriginalPostDrawLifecycleTests'],
                   env=dict(os.environ, NTSD_GAMEPLAY_LIFECYCLE_DIRECTORY=str(ROOT/'build/original')), check=True)
    publish(captures, pins, pin_name='gameplay-lifecycle-fixture-pins.json')


if __name__ == '__main__':
    main()
