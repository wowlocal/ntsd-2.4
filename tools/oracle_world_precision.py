#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Re-execute complete World physics, links or hits with explicit CW027f.

Every historical declared input is reproduced; only CPU precision changes.
Original helpers, full pool/masks/globals, mutable heap and ordered requests
retain the source study's boundaries. This is controlled precision evidence,
not natural DAT reachability, full startup or Windows thread behavior.
"""
import argparse
import importlib
import json
from collections import Counter
from import_ntsd import ROOT, EXE_SHA256
from oracle_bitmap_drawing import digest


def hit_witnesses():
    from oracle_world_hits import WorldHits, probes, POOL
    from unicorn import UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_EAX
    sources, pins = {}, []
    for cw, directory, name in [(0x37f, 'docs/evidence', 'world-hits'), (0x27f, 'build/research', 'world-hits53')]:
        r = json.loads((ROOT / directory / (name + '.json')).read_bytes())
        raw = (ROOT / 'build/original' / r['corpus']).read_bytes()
        assert len(raw) == r['bytes'] and digest(raw) == r['sha256']
        sources[cw] = json.loads(raw)
        pins.append(dict(fpcw=cw, corpus=r['corpus'], sha256=r['sha256']))
    labels = set(sources[0x27f]['changedFrom64'])
    assert len(labels) == 3
    vm, observations, cases = WorldHits(), [], []
    def observe(uc, pc, size, data):
        observations.append(dict(pc=pc, eax=uc.reg_read(UC_X86_REG_EAX)))
    for pc in (0x42f1e5, 0x42f1f6):
        vm.uc.hook_add(UC_HOOK_CODE, observe, begin=pc, end=pc)
    for n, item in enumerate(probes()):
        if item['label'] not in labels:
            continue
        modes = []
        for cw in (0x37f, 0x27f):
            vm.arithmetic_control_word = cw
            observations.clear()
            actual = json.loads(json.dumps(vm.probe(item, n)))
            assert actual == sources[cw]['cases'][n]
            assert [o['pc'] for o in observations] == ([0x42f1e5, 0x42f1f6] if cw == 0x37f else [0x42f1e5])
            modes.append(dict(fpcw=cw, observations=list(observations),
                pendingY=bytes(vm.uc.mem_read(POOL + 0x500 + 0x30, 8)).hex(), poolSHA256=actual['poolSHA256']))
        cases.append(dict(label=item['label'], modes=modes))
    result = dict(exeSHA256=EXE_SHA256,
        scope='Source-only branch witnesses for the three accepted-control inputs that differ at53 bits. Whole42e100 executes under both declared control words; full output cases reproduce their pinned corpora. The separately accepted native tests compare complete pool hashes; this trace adds original conversion-return and overwrite PCs.',
        nativeCompared=False, windowsVerified=False, corpora=pins, cases=cases)
    (ROOT / 'docs/evidence/hit-precision-branches.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('kind', choices=['physics', 'links', 'hits', 'camera'])
    p.add_argument('--witnesses', action='store_true', help='Trace the three precision-sensitive hit branches under both words')
    args = p.parse_args()
    if args.witnesses:
        assert args.kind == 'hits'
        return hit_witnesses()
    name = 'world-' + args.kind
    scope = (__doc__ if args.kind != 'camera' else
        'Whole original41b5d0..41bc87 camera with actual background/draw children at explicit CW027f. '
        'Every historical caller input is retained; full pool/masks/globals/backgrounds and ordered '
        'device requests are compared. Supplied metadata/stack/device boundaries, not Windows or raster output.')
    module = importlib.import_module('oracle_world_' + args.kind)
    report = json.loads((ROOT / 'docs/evidence' / (name + '.json')).read_bytes())
    raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
    assert len(raw) == report['bytes'] and digest(raw) == report['sha256']
    assert digest((ROOT / 'native/Tests/NTSDCoreTests/Fixtures' / report['fixture']).read_bytes()) == report['fixtureSHA256']
    old = json.loads(raw)
    assert old['exeSHA256'] == EXE_SHA256
    if args.kind == 'physics':
        assert 'fpcw' not in old and 'CW037f' in old['scope']
    else:
        assert old['fpcw'] == 0x37f
    vm = getattr(module, 'World' + args.kind.title())()
    assert vm.arithmetic_control_word == 0x37f
    vm.arithmetic_control_word = 0x27f
    outputs = {'poolSHA256', 'maskSHA256', 'globalsSHA256', 'heapSHA256', 'crtAfter', 'events', 'helpers',
               'backgroundsSHA256', 'backgroundMasksSHA256', 'fillInputs'}
    cases, changed = [], []
    for n, item in enumerate(module.probes()):
        actual = json.loads(json.dumps(vm.probe(item, n)))
        expected = old['cases'][n]
        assert {k: v for k, v in actual.items() if k not in outputs} == {k: v for k, v in expected.items() if k not in outputs}, actual['label']
        if actual != expected:
            changed.append(actual['label'])
        cases.append(actual)
        if (n + 1) % 500 == 0:
            print('WORLD PRECISION', name, n + 1, 'changed', len(changed), flush=True)
    assert len(cases) == len(old['cases']) == report['cases']
    doc = {k: v for k, v in old.items() if k not in ('scope', 'cases', 'fpcw', 'instructions')}
    historical = dict(fixture=report['fixture'], sha256=report['fixtureSHA256'])
    doc.update(scope=scope, cases=cases, fpcw=0x27f, instructions=sorted(vm.instructions), historical=historical, changedFrom64=changed)
    raw = (json.dumps(doc, separators=(',', ':')) + '\n').encode()
    path = ROOT / 'build/original' / (name + '53.json')
    path.write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=scope, corpus=path.name, sha256=digest(raw), bytes=len(raw), cases=len(cases),
        fpcw=0x27f, groups=dict(Counter(c['group'] for c in cases)), instructions=len(vm.instructions),
        events=sum(len(c['events']) for c in cases), helpers=sum(c['helpers'] for c in cases),
        changedFrom64=len(changed), historical=historical, nativeCompared=False, windowsVerified=False)
    if 'dllSHA256' in doc:
        report['dllSHA256'] = doc['dllSHA256']
    (ROOT / 'build/research' / path.name).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
