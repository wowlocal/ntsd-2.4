#!/usr/bin/env python3
"""Read saved active48 lifecycle provenance; never execute original or Native code.

This prerequisite inventory does not accept a new gameplay comparison. It joins
the retained parent, acquisition, lifecycle and returned allocation records, and
checks the finite transient's input-derived coordinates and helper observations.
Unknown middle snapshots and synthetic host boundaries remain explicit.
"""
import argparse
import base64
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import stat
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'native/Tests/NTSDCoreTests/Fixtures'
PINS = ['3b074ff960538fde6e13b1b65bda4f833b22bbc9cafcef990de12f71aaed511c',
        'd3abb578f36ac74716fa6e71eb12091c6f0eed5adb02f1b59a550275c73fc0b3']
BASE = 0x44d000
ACTOR_FIELDS = [0x10, 0x14, 0x18, 0x70, 0x74, 0x78, 0x88, 0x98, 0xb4,
                0x2f4, 0x2fc, 0x308, 0x31c, 0x354, 0x364, 0x368]
FRAME_FIELDS = [8, 12, 16, 0x24, 0x28, 0x50, 0x54, 0x58, 0x5c, 0x60,
                0x64, 0x68, 0x6c, 0x70, 0x74, 0x88, 0x174]


def digest(b):
    return hashlib.sha256(b).hexdigest()


def pin(p):
    b = p.read_bytes()
    return dict(path=str(p), bytes=len(b), sha256=digest(b),
                mode=stat.S_IMODE(p.stat().st_mode))


class Corpus:
    def __init__(self, name, expected):
        self.path = FIXTURES / name
        packed = self.path.read_bytes()
        assert digest(packed) == expected, name
        w = json.loads(packed)
        raw = zlib.decompress(base64.b64decode(w['deflate']), -15)
        assert len(raw) == w['count'] and digest(raw) == w['sha256']
        self.doc = json.loads(raw)
        self.cache = {}
        self.raw_pin = dict(bytes=len(raw), sha256=digest(raw))
        for key, value in self.doc['components'].items():
            assert digest(json.dumps(value, separators=(',', ':'), sort_keys=True).encode()) == key

    def blob(self, key):
        if key not in self.cache:
            w = self.doc['blobs'][key]
            b = zlib.decompress(base64.b64decode(w['deflate']), -15)
            assert len(b) == w['count'] and digest(b) == key
            self.cache[key] = b
        return self.cache[key]

    def component(self, refs, name):
        return self.doc['components'][refs[name]]

    def pool(self, refs):
        c = self.component(refs, 'state')
        b, m = self.blob(c['poolBytes']), self.blob(c['poolMask'])
        assert len(b) == len(m) == 0x7d8 + 400 * 0x420
        return b, m

    def actor(self, refs, slot):
        b, m = self.pool(refs)
        start = 0x7d8 + slot * 0x420
        return b[start:start+0x420], m[start:start+0x420]


def integer(record, offset, signed=True, size=4):
    b, m = record
    assert len(b) == len(m) and all(m[offset:offset+size]) and offset+size <= len(b)
    return int.from_bytes(b[offset:offset+size], 'little', signed=signed)


def fields(record, offsets):
    b, m = record
    # Undefined bytes remain explicitly labelled; they are never arithmetic inputs.
    return {hex(at): dict(value=int.from_bytes(b[at:at+4], 'little', signed=True),
                         defined=list(m[at:at+4])) for at in offsets}


def record_pin(record):
    b, m = record
    return dict(bytes=len(b), sha256=digest(b), maskSHA256=digest(m), definedBytes=sum(bool(x) for x in m))


def inventory(control):
    c = Corpus('original-active-gameplay' + ('-control' if control else '') + '.json', PINS[control])
    d = c.doc
    parent = Corpus(d['parent']['fixture'], d['parent']['sha256'])
    last = parent.doc['cases'][-1]['after']
    assert all(parent.component(last, key) == c.component(d['initial'], key) for key in last)
    assert set(d['initial']) - set(last) == {'objects', 'objectStrings'}
    assert len(d['cases']) == 48 and len(d['actorAddresses']) == len(set(d['actorAddresses'])) == 400
    assert [v['index'] for v in d['cases']] == list(range(1, 49))
    rows, helpers, grouped = [], Counter(), Counter()
    previous = d['initial']
    transient_after = None
    for call in d['cases']:
        index = call['index']
        assert call['before'] == previous
        before = c.component(call['before'], 'state')
        acquired = c.component(call['acquired'], 'state')
        assert {k: v for k, v in before.items() if k != 'globals'} == {
            k: v for k, v in acquired.items() if k != 'globals'}
        gb, ga = c.blob(before['globals']), c.blob(acquired['globals'])
        changes = call['acquisition']['changes']
        assert call['acquisition']['plan'] == d['schedule'][index-1]
        expected = bytearray(gb)
        for change in changes:
            at = change['address'] - BASE
            assert change['address'] == 0x455378 + change['key'] and gb[at] == change['before']
            assert change['after'] in (100, 117)
            expected[at] = change['after']
        assert bytes(expected) == ga
        for key in ['objects', 'objectStrings', 'frameHeap']:
            assert call['before'][key] == call['acquired'][key] == call['after'][key]
        section = call['stages'][12]
        assert section['label'] == 'post-draw-lifecycle' and section['end']['pc'] == 0x4214d5
        assert section['end']['sp'] == 0x1000e9bc
        assert section['before'] == call['stages'][11]['after']
        assert section['after'] == call['stages'][13]['before']
        assert section['effects'] == section['checkpoints'] == section['readsBeforeWrites'] == []
        assert all(h['entry'] != 0x4061d0 for stage in call['stages'][:12]+call['stages'][13:]
                   for h in stage['helpers'])
        assert set(section['events']) <= {'lifecycle'}
        for key in section['before']:
            if key not in ('early', 'state'):
                assert section['before'][key] == section['after'][key]
        pb, mb = c.pool(section['before']); pa, ma = c.pool(section['after'])
        assert pb[:0x7d8] == pa[:0x7d8] and mb[:0x7d8] == ma[:0x7d8]
        assert list(pb[4:404]) == [1, 1] + [0]*398
        changed = [slot for slot in range(400) if c.actor(section['before'], slot) != c.actor(section['after'], slot)]
        assert changed == ([0, 1, 50] if index == 17 else [0, 1])
        for h in section['helpers']:
            helpers[hex(h['entry'])] += 1
            assert h['returnSP'] == h['entrySP'] + 4 + h['pop'] and len(h['saved']) == 4
            if h['entry'] == 0x40d960:
                assert h['arguments'] == [0, h['slot']] and h['returnPC'] == 0x41fb0b
                assert h['this'] == d['actorAddresses'][h['slot']]
        schedules = [h['slot'] for h in section['helpers'] if h['entry'] == 0x40d960]
        assert schedules == ([0, 1, 50] if index == 17 else [0, 1])
        scratch_accesses = [a for a in call['stackAccesses']
                            if a['phase'] == 'gameplay-post-draw-lifecycle'
                            and any(a['address'] < 0x1000e9bc+offset+4
                                    and a['address']+a['size'] > 0x1000e9bc+offset
                                    for offset in (0x44, 0x50, 0x5c, 0x60, 0x6c, 0x70))]
        assert scratch_accesses == []
        events = section['events'].get('lifecycle', [])
        grouped.update(e['kind'] for e in events)
        assert len(section['boundaries']) == (1 if index == 17 else 0)
        if index <= 17:
            assert c.actor(section['before'], 50) == c.actor(d['initial'], 50)
            for earlier in call['stages'][:12]:
                assert c.actor(earlier['before'], 50) == c.actor(earlier['after'], 50) == c.actor(d['initial'], 50)
        if index == 17:
            transient_after = c.actor(section['after'], 50)
        elif index > 17:
            assert c.actor(section['before'], 50) == transient_after
        if index >= 17:
            assert c.actor(call['after'], 50) == transient_after
            for later in call['stages'][13:]:
                assert c.actor(later['before'], 50) == c.actor(later['after'], 50) == transient_after
        rows.append(dict(call=index, acquisitionChanges=changes, changedActorSlots=changed,
                         schedulerSlots=schedules, events=events, endpoint=section['end'],
                         retainedScratchAccesses=scratch_accesses,
                         stateBefore=section['before']['state'], stateAfter=section['after']['state']))
        previous = call['after']

    call = d['cases'][16]; section = call['stages'][12]
    objects = c.component(call['acquired'], 'objects')
    assert [o['address'] for o in objects] == d['objectAddresses']
    records = {o['address']: (c.blob(o['storage']['bytes']), c.blob(o['storage']['defined'])) for o in objects}
    def frame(obj, number):
        at = 0x7a4 + number * 0x178
        return tuple(b[at:at+0x178] for b in obj)
    actor = c.actor(section['before'], 0)
    obj = records[integer(actor, 0x368, False)]
    initial_frame = frame(obj, integer(actor, 0x70))
    assert integer(obj, 0x6f4) == 2 and integer(obj, 0x6f8) == 0
    assert integer(actor, 0x70) == 60 and integer(actor, 0x74) != 60
    assert integer(actor, 0x88) == integer(initial_frame, 12) == 0
    assert integer(initial_frame, 16) == 61
    # Scheduler reset/increment exceeds Frame.wait0, selecting Frame61/wait0.
    op = frame(obj, integer(initial_frame, 16))
    assert integer(op, 0x58) == 1 and integer(op, 0x70) > 0 and integer(op, 0x74) == 0
    chosen = next(o for o in objects if integer(records[o['address']], 0x6f4) == integer(op, 0x70))
    child_obj = records[chosen['address']]
    child_frame = frame(child_obj, integer(op, 0x64))
    assert integer(child_obj, 0x6f4) == 203 and integer(child_obj, 0x6f8) == 3
    assert integer(op, 0x64) == 200 and integer(child_frame, 8) == 3005
    assert integer(child_frame, 12) == 0 and integer(child_frame, 16) == 1000
    assert integer(child_frame, 0x24) == integer(child_frame, 0x88) == 0
    facing = integer(actor, 0x80, False, 1)
    assert facing in (0, 1)
    x = integer(actor, 0x10) + (integer(op, 0x5c)-integer(op, 0x50)) * (1-2*facing)
    y = integer(actor, 0x14) - integer(op, 0x54) + integer(op, 0x60)
    assert all(actor[1][0x68:0x70])
    z = struct.unpack_from('<d', actor[0], 0x68)[0] + 1.0
    assert math.isfinite(z) and -2147483648 < z < 2147483647
    child_after = c.actor(section['after'], 50)
    assert [integer(child_after, at) for at in (0x10, 0x14, 0x18)] == [x, y, int(z)]
    assert integer(child_after, 0x368, False) == chosen['address']
    assert integer(child_after, 0x70) == integer(child_after, 0x74) == integer(child_after, 0x78) == 0
    conversions = [h for h in section['helpers'] if h['entry'] == 0x4450d0]
    assert [h['result'] for h in conversions] == [x, y, int(z)]
    assert [h['returnPC'] for h in conversions] == [0x420232, 0x42024b, 0x420264]
    events = section['events']['lifecycle']
    assert events == [dict(kind='reconstruct', slot=0, arguments=[50]),
                      dict(kind='catalogSound', slot=1, arguments=[357, 109]),
                      dict(kind='catalogSound', slot=50, arguments=[x, integer(child_frame, 0x174)])]
    boundary = section['boundaries'][0]
    assert boundary['kind'] == 'memset' and boundary['entryPC'] == 0x4450a0
    assert boundary['arguments'] == [d['actorAddresses'][50]+0xf0, 0, 400]
    assert boundary['returnPC'] == boundary['actualReturnPC'] == 0x406447
    assert boundary['returnSP'] == boundary['entrySP']+4 and boundary['result'] == boundary['arguments'][0]
    assert boundary['savedBefore'] == boundary['savedAfter']
    assert c.blob(boundary['before']) == c.blob(boundary['after']) == bytes(400)
    retained_before = c.actor(section['before'], 50)
    assert retained_before[0][0xf0:0x280] == bytes(400) and all(retained_before[1][0xf0:0x280])
    plays = [e for e in call['output']['events'] if e['kind'] == 'play']
    assert [e['arguments'][0] for e in plays] == [0x452948+4*109, 0x452948+4*366]
    assert helpers == {'0x40d960':97, '0x4061d0':1, '0x4450d0':3, '0x416fb0':7}
    assert grouped == {'reconstruct':1, 'catalogSound':7}
    return dict(control=bool(control), fixture=pin(c.path), rawEnvelope=c.raw_pin,
                parent=pin(parent.path), parentJoinedComponents=sorted(last),
                verifiedComponentManifests=len(d['components']), verifiedConsumedBlobs=len(c.cache),
                calls=rows, helpers=dict(helpers), groupedEvents=dict(grouped),
                transient=dict(call=17, parentActorFields=fields(actor, ACTOR_FIELDS),
                    parentActorPin=record_pin(actor), initialFrame=fields(initial_frame, FRAME_FIELDS),
                    opointFrame=fields(op, FRAME_FIELDS), childObjectOrdinal=objects.index(chosen),
                    childObject=chosen, childFrame=fields(child_frame, FRAME_FIELDS),
                    coordinatesFromInputs=[x, y, int(z)], binary64ZBeforeConversion=z,
                    constructorBackingBefore=record_pin(retained_before),
                    constructorBackingFields=fields(retained_before, ACTOR_FIELDS),
                    retainedChildAfter=record_pin(child_after), retainedChildFields=fields(child_after, ACTOR_FIELDS),
                    orderedHelperReturns=section['helpers'], boundary=boundary, outputPlays=plays,
                    unchangedAfterLifecycleThroughCall48=True),
                nativeCompared=False, actualWindowsOrDevice=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Preserve previous reports; select a new output path'
    reports = [inventory(n) for n in (0, 1)]
    result = dict(schema='active-lifecycle-provenance-v1', UTC=datetime.now(timezone.utc).isoformat(),
                  reader=pin(Path(__file__).resolve()), reports=reports, originalExecuted=False,
                  nativeExecuted=False, lifecycleNativeAccepted=False, fullGoalComplete=False,
                  limits=['Pristine EXE/VC80 controlled captures, bundled lib.dll absent.',
                          'Intermediate child creation/removal states inferred from inputs and helper/control-flow evidence, not full snapshots.',
                          'Constructor memset and sound device replies are declared harness boundaries.',
                          'No complete instruction trace, full helper ABI or new Native state comparison.'])
    with args.output.open('x') as f:
        json.dump(result, f, indent=2); f.write('\n')
    print(json.dumps(dict(output=str(args.output), calls=96, schedulerReturns=194,
                         reconstructions=2, nativeCompared=False)))


if __name__ == '__main__':
    main()
