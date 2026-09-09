#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole Actor/World control with explicit original arithmetic precision.

Historical callers are reproduced without rewriting their expectations. New
finite arithmetic controls run whole413080 at CW007f/027f/037f, preserving
original helpers, constants, stores, Actor masks, globals and event order.
No Windows/thread/device, natural sequence or complete tick claim.
"""
import argparse
import base64
import json
import random
import struct
import zlib
from collections import Counter

from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from oracle_actor_control import ActorControl, HEADER, STATES, probes, held, d, b, f, q, digest
from oracle_actor_control_catalog import CatalogControl
from oracle_world_control import WorldControl, probes as world_probes
from unicorn.x86_const import UC_X86_REG_FPCW, UC_X86_REG_FPSW

OUTPUTS = {'after', 'defined', 'globalsSHA256', 'events', 'poolSHA256', 'maskSHA256', 'helpers'}
ARITHMETIC_PCS = [0x413568, 0x4135d3, 0x4135ef, 0x41395e, 0x4139bd, 0x4139d7,
                  0x413bcd, 0x413bea, 0x413d3a, 0x413e2f, 0x413e53, 0x414231, 0x414353]


def historical(name):
    report = json.loads((ROOT / 'docs/evidence' / (name + '.json')).read_bytes())
    raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
    assert len(raw) == report['bytes'] and digest(raw) == report['sha256']
    assert digest((ROOT / 'native/Tests/NTSDCoreTests/Fixtures' / report['fixture']).read_bytes()) == report['fixtureSHA256']
    return report, json.loads(raw)


def inputs(case):
    return {k: v for k, v in case.items() if k not in OUTPUTS}


def run(vm, item, index, cw):
    # Writing FPCW matters: Unicorn's freshly constructed CPU can report zero
    # while its arithmetic mode differs from explicitly writing that same zero.
    vm.uc.reg_write(UC_X86_REG_FPCW, cw)
    vm.uc.reg_write(UC_X86_REG_FPSW, 0)
    actual = json.loads(json.dumps(vm.probe(item, index)))
    assert vm.uc.reg_read(UC_X86_REG_FPCW) == cw
    assert (vm.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7 == 0
    return actual


def catalog_objects():
    parent = json.loads((ROOT / 'docs/evidence/loaded-catalog.json').read_bytes())['corpora'][0]
    assert digest((ROOT / 'native/Tests/NTSDCoreTests/Fixtures' / parent['fixture']).read_bytes()) == parent['fixtureSHA256']
    raw = (ROOT / 'build/original' / parent['corpus']).read_bytes()
    assert digest(raw) == parent['corpusSHA256']
    catalog = json.loads(raw)
    def blob(key):
        b = catalog['blobs'][key]
        value = zlib.decompress(base64.b64decode(b['deflate']), -15)
        assert digest(value) == key and len(value) == b['count']
        return value
    objects, bindings = {}, []
    for item in catalog['children']:
        if item['kind'] != 'object' or item['objectType'] != 0:
            continue
        assert digest(read_bytes(DEFAULT_SOURCE / item['path'].replace('\\', '/'))) == item['source']
        raw, mask = blob(item['storage']['bytes']), blob(item['storage']['defined'])
        assert len(raw) == len(mask) == 0x25360 and raw[0x7a4] != 0
        objects[item['index']] = raw, mask
        bindings.append({key: item[key] for key in ('index', 'id', 'path', 'source')})
    assert len(objects) == 42
    return objects, bindings


def precision_inputs():
    edges = [0, 1, 2, 3, 0x000fffffffffffff, 0x0010000000000000,
             0x0010000000000001, 0x3ca0000000000000, 0x3e60000000000000,
             0x3fefffffffffffff, 0x3ff0000000000000, 0x3ff0000000000001,
             0x3ff6666666666666, 0x3ff3333333333333, 0x416ffffff0000000,
             0x4330000000000001, 0x4340000000000001, 0x7fefffffffffffff]
    values = [struct.unpack('<d', struct.pack('<Q', value | sign))[0]
              for value in edges for sign in (0, 1 << 63)]
    for n, value in enumerate(values):
        for heavy in (0, 2):
            for mask, phase in ((1, 0), (2, 0), (2, 15)):
                yield dict(label=f'walk-{n}-{heavy}-{mask}-{phase}', group='walk-divide',
                    actor=[d(0x98, heavy), d(0, phase), q(0x40, value), *held(mask)])
            for mask in (1, 2):
                yield dict(label=f'run-{n}-{heavy}-{mask}', group='run-divide',
                    actor=[d(0x70, 9), d(0x98, heavy), *held(mask)], header=[q(0x40 if heavy else 0x20, value)])
        for facing in (0, 1, 2, 127, 128, 255):
            yield dict(label=f'dash-{n}-{facing}', group='dash-multiply',
                actor=[d(0x70, 9), b(0x80, facing), *held(32)], header=[q(0x70, value)])
        for add in (0, 1, -1, 500, -2147483648):
            yield dict(label=f'air-{n}-{add}', group='air-subtract-store-add',
                actor=[d(0x70, 213), d(0x98, 1), q(0x40, 1), q(0x48, value), *held(16)], frames=[f(40, 0x18, add)])
        for add in (-2147483648, -16777217, -500, -1, 1, 500, 501, 2147483647):
            yield dict(label=f'dvy-{n}-{add}', group='frame-add-or-load',
                actor=[d(0x70, 302), q(0x48, value)], frames=[f(302, 0x18, add)])
    rng = random.Random(0x413080)
    for n in range(4096):
        # Finite varied exponents, including subnormal final stores. These
        # inputs are chosen independently of the original/native results.
        bits = rng.getrandbits(64)
        if (bits >> 52) & 0x7ff == 0x7ff:
            bits ^= 1 << 52
        value = struct.unpack('<d', struct.pack('<Q', bits))[0]
        for divisor in (14, 12):
            yield dict(label=f'seeded-divide-{n}-{divisor}', group='seeded-divide',
                actor=[d(0x70, 0 if divisor == 14 else 9), b(0x80, 2), q(0x40, value), *held(1)])


def inherited_witness():
    item = dict(label='initial-cw', actor=[d(0x70, 9), *held(1)])
    observations = []
    for mode in ('unwritten', 0, 0x7f, 0x27f, 0x37f):
        vm = ActorControl()
        before = vm.uc.reg_read(UC_X86_REG_FPCW)
        if mode == 'unwritten':
            actual = vm.probe(item, 0)
        else:
            actual = run(vm, item, 0, mode)
        observations.append(dict(mode=mode, before=before, after=vm.uc.reg_read(UC_X86_REG_FPCW),
            velocityX=actual['after'][0x40 * 2:0x48 * 2], actorSHA256=digest(bytes.fromhex(actual['after']))))
    assert observations[0]['before'] == observations[0]['after'] == observations[1]['after'] == 0
    assert observations[0]['velocityX'] != observations[1]['velocityX'] == observations[2]['velocityX']
    return observations


def world_precision_inputs():
    for sign in (0, 1 << 63):
        value = struct.unpack('<d', struct.pack('<Q', 3 | sign))[0]
        for count in (1, 2, 3):
            slots = (0, 1, 399)[:count]
            for mask in (1, 2):
                yield dict(label=f'live-division-{sign >> 63}-{count}-{mask}', group='live-division',
                    active=[[slot, (1, 255, 128)[n]] for n, slot in enumerate(slots)],
                    aliases=[[slot, 5] for slot in slots],
                    actors=[[5, [d(0x70, 9), b(0x80, 2), q(0x40, value), *held(mask)]]],
                    frames=[[0, number, *d(8, 2)] for number in (9, 10, 11)])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('kind', choices=['actor', 'catalog', 'world', 'edges', 'worldedges'])
    args = p.parse_args()
    cases, changed = [], []
    if args.kind in ('edges', 'worldedges'):
        vm = ActorControl() if args.kind == 'edges' else WorldControl()
        stimuli = precision_inputs() if args.kind == 'edges' else world_precision_inputs()
        for n, item in enumerate(stimuli):
            modes = []
            for cw in (0x7f, 0x27f, 0x37f):
                actual = run(vm, item, n, cw)
                actual['fpcw'] = cw
                cases.append(actual)
                modes.append({k: actual[k] for k in OUTPUTS if k in actual})
            for i, precision in enumerate((24, 53)):
                if modes[i] != modes[2]:
                    changed.append(dict(label=item['label'], precision=precision))
            if (n + 1) % 1000 == 0:
                print('CONTROL ARITHMETIC', n + 1, 'inputs', len(changed), 'changed', flush=True)
        if args.kind == 'edges':
            doc = dict(header=HEADER, states=STATES, changedFrom64=changed, arithmeticPCs=ARITHMETIC_PCS,
                       inheritedControlWordWitness=inherited_witness())
            assert set(ARITHMETIC_PCS).issubset(vm.instructions)
            name = 'actor-control-precision'
        else:
            doc = dict(header=HEADER, states=vm.frame_states, ids=vm.source_ids, changedFrom64=changed)
            assert {0x413bcd, 0x413bea}.issubset(vm.instructions)
            name = 'world-control-precision'
    else:
        previous_name = {'actor': 'actor-control', 'catalog': 'actor-control-catalog', 'world': 'world-control'}[args.kind]
        previous, old = historical(previous_name)
        if args.kind == 'catalog':
            objects, bindings = catalog_objects()
            assert bindings == old['bindings']
            vm, inherited = CatalogControl(objects), CatalogControl(objects)
            stimuli = (dict(label=f'source-{index}-held-{mask}', objectIndex=index, group='source-frame0', actor=held(mask))
                       for index in objects for mask in range(128))
        elif args.kind == 'actor':
            vm, inherited, stimuli = ActorControl(), ActorControl(), probes()
        else:
            vm, inherited, stimuli = WorldControl(), WorldControl(), world_probes()
        inherited_words = set()
        for n, item in enumerate(stimuli):
            # Fresh no-FPCW-write execution must reproduce the entire retained
            # historical corpus, including each backing pattern and helper event.
            original = json.loads(json.dumps(inherited.probe(item, n)))
            assert original == old['cases'][n], original['label']
            inherited_words.add(inherited.uc.reg_read(UC_X86_REG_FPCW))
            actual = run(vm, item, n, 0x27f)
            assert inputs(actual) == inputs(original), actual['label']
            if actual != original:
                changed.append(actual['label'])
            cases.append(actual)
            if (n + 1) % 2000 == 0:
                print('CONTROL53', args.kind, n + 1, 'changed', len(changed), flush=True)
        assert len(cases) == len(old['cases']) == previous['cases'] and inherited_words == {0}
        doc = {k: v for k, v in old.items() if k not in ('scope', 'cases', 'instructions')}
        doc.update(fpcw=0x27f, historical=dict(fixture=previous['fixture'], sha256=previous['fixtureSHA256']),
                   historicalReexecuted=True, historicalReportedFPCW=0, changedFromHistorical=changed)
        name = previous_name + '53'
    doc.update(exeSHA256=EXE_SHA256, scope=__doc__, cases=cases, instructions=sorted(vm.instructions))
    raw = (json.dumps(doc, separators=(',', ':')) + '\n').encode()
    (ROOT / 'build/original' / (name + '.json')).write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=name + '.json', sha256=digest(raw), bytes=len(raw),
                  cases=len(cases), groups=dict(Counter(c['group'] for c in cases)), instructions=len(vm.instructions),
                  events=sum(len(c['events']) for c in cases), nativeCompared=False, windowsVerified=False)
    for key in ('fpcw', 'historical', 'historicalReexecuted', 'historicalReportedFPCW', 'parent', 'arithmeticPCs'):
        if key in doc:
            report[key] = doc[key]
    if args.kind in ('edges', 'worldedges'):
        report['changedFrom64'] = dict(Counter(c['precision'] for c in changed))
        if 'inheritedControlWordWitness' in doc:
            report['inheritedControlWordWitness'] = doc['inheritedControlWordWitness']
    else:
        report['changedFromHistorical'] = len(changed)
    (ROOT / 'build/research' / (name + '.json')).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
