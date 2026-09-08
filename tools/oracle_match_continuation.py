#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real remaining menu instructions through ret12, including 450c2c==1.

First reproduce the pinned complete prelude/preparation/recording chain, then
continue its state. Input/COM/RNG/ABI boundaries are explicit; no whole UI or W.
"""
import argparse
import base64
import json
import struct
import subprocess
import zlib
from collections import Counter
from import_ntsd import ROOT, EXE_SHA256
from oracle_match_prelude import MatchPrelude, SOUND
from oracle_match_preparation import digest, GLOBAL, GLOBAL_SIZE, WORLD
from oracle_objects import DEVICE, STUB, BITMAP_SIZE
from oracle_loaded_catalog import CATALOG
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_ESP, UC_X86_REG_EBP, UC_X86_REG_ECX, UC_X86_REG_EBX, UC_X86_REG_ESI, UC_X86_REG_EDI


class Continuation(MatchPrelude):
    def __init__(self, capture, pattern):
        super().__init__(capture, pattern)
        self.continuing = False
        self.probe_index = 0
        self.continuation_heap = 0x26000020
        self.uc.mem_map(0x26000000, 0x2000000)
        for hook, callback in [(UC_HOOK_MEM_READ, self.track_read), (UC_HOOK_MEM_WRITE, self.track_write)]:
            self.uc.hook_add(hook, callback, begin=0x26000000, end=0x27FFFFFF)
        self.uc.hook_add(UC_HOOK_CODE, self.music_entry, begin=0x4025D0, end=0x4025D0)

    def allocate(self, size, kind, caller):
        if not self.continuing:
            return super().allocate(size, kind, caller)
        assert kind == 'bitmap' and size == BITMAP_SIZE and self.continuation_heap+size+32 < 0x28000000
        address = self.continuation_heap
        self.continuation_heap += (size+63) & ~15
        region = self.add_region(address, size, kind)
        self.allocations.append(dict(address=address, size=size, kind=kind, caller=hex(caller)))
        return region

    def write_host(self, address, raw):
        if 0x26000000 <= address < 0x28000000:
            self.track_write(self.uc, 0, address, len(raw), 0, None)
        super().write_host(address, raw)

    def allowed_code(self, uc, address, size, data):
        if 0x42D704 <= address <= 0x42E0F9 or 0x4025D0 <= address < 0x4025DE or 0x40280C <= address <= 0x40280D:
            return
        super().allowed_code(uc, address, size, data)

    def music_entry(self, uc, address, size, data):
        assert self.continuing and self.u32(uc.reg_read(UC_X86_REG_ESP)) == 0x42D7A6 and self.u32(0x44D010) == 0
        self.ordered.append(dict(kind='music-selection'))

    def sound_entry(self, uc, address, size, data):
        if not self.continuing:
            return super().sound_entry(uc, address, size, data)
        sp = uc.reg_read(UC_X86_REG_ESP)
        assert self.u32(sp) in (0x42D753, 0x42D76C, 0x42DDDB, 0x42DEDF, 0x42DF16, 0x42DF7C)
        assert uc.reg_read(UC_X86_REG_ECX) == 0x455610 and self.u32(sp+4) == 0
        self.ordered.append(dict(kind='sound-request', loop=False))

    def imported(self, uc, address, size, data):
        start = len(getattr(self, 'prelude_events', []))
        super().imported(uc, address, size, data)
        if self.continuing:
            self.ordered.extend(self.prelude_events[start:])

    def observe(self, uc, address, size, data):
        if not self.continuing:
            return super().observe(uc, address, size, data)
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x417170 and self.u32(sp) in (0x42D8E2, 0x42E072):
            count = self.u32(sp+8)
            seat = (uc.reg_read(UC_X86_REG_EBP)-0x451248)//4 if self.u32(sp)==0x42D8E2 else self.u32(sp+0x40)//4
            assert 0 <= seat < 8 and 0 < count <= 137
            self.ordered.append(dict(kind='candidates', seat=seat, ordinals=[self.u32(sp+0x50+i*4) for i in range(count)]))
        start = len(self.calls)
        super().observe(uc, address, size, data)
        if address == 0x4061D0:
            self.ordered.append(dict(kind='reconstruct', index=self.actor_constructors[-1]))
        self.ordered.extend({k:v for k,v in call.items() if k!='caller'} for call in self.calls[start:])

    def probe(self, label, confirmation=1, action=0, mode=0, demo=0, words=None, flags=None, team_pattern=None):
        self.host_writes, self.calls, self.actor_constructors, self.events, self.ordered = [], [], [], [], []
        self.global_accesses, self.prelude_events = set(), []
        word = lambda address, value: self.stimulus(address, struct.pack('<I', value & 0xFFFFFFFF))
        self.device_result = 0x80004005 if self.probe_index % 2 else 0
        word(0x44EECC, 0 if self.probe_index % 3 == 0 else SOUND+0x200)
        word(0x455610, 0 if self.probe_index % 4 == 0 else SOUND)
        self.probe_index += 1
        for address, value in [(0x44D06C, action), (0x451160, mode), (0x450C2C, demo), (0x44D078, 0), (0x4512C8, 0)]:
            word(address, value)
        for address, value in (words or {}).items():
            word(address, value)
        if flags is not None:
            for seat, value in enumerate(flags):
                word(0x451228+seat*4, value)
        if team_pattern is not None:
            table = bytearray(self.random_source['table'])
            index, counter = (2999, 1233) if team_pattern == 29 else (0, 0)
            targets = [(26, 30, team_pattern), (27, 3, team_pattern % 3), (28, 6, team_pattern % 2)]
            if team_pattern == 29:
                targets.append((1, 15, 14))
            for nth, limit, target in targets:
                table[(index+nth) % 3000] = next(b for b in range(1, 256) if (b+(counter+nth) % 1234) % limit == target)
            self.stimulus(0x44FF90, bytes(table)); word(0x450BCC, index); word(0x450C34, counter)
        # Supply the real function's saved-register/SEH/cookie frame, not a stub
        # for its epilogue. Stack locals/confirmation remain explicit inputs.
        sp = STACK+0xF000
        saved = [(UC_X86_REG_EDI, 0x11111111), (UC_X86_REG_ESI, 0x22222222),
                 (UC_X86_REG_EBP, 0x33333333), (UC_X86_REG_EBX, 0x44444444)]
        for i, (_, value) in enumerate(saved):
            self.put(sp+4+i*4, value)
        for offset, value in [(0, self.u32(0x44EEA4) ^ (sp+4)), (0x14, WORLD), (0x18, confirmation),
                               (0x1C, 0x451160), (0x40, 0x44D020), (0xA94, self.u32(0x44EEA4) ^ (sp+0x14)),
                               (0xA98, 0), (0xAA4, STOP), (0xAAC, 0x44D020), (0xAB0, 0x451160)]:
            self.put(sp+offset, value)
        self.put(0, sp+0xA98)
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        before = self.snapshot()
        first_bitmap = len(self.bitmaps)
        self.continuing = True
        try:
            self.execute(0x42D704, STOP)
        finally:
            self.continuing = False
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp+0xAB4 and self.u32(0) == 0
        assert all(self.uc.reg_read(reg) == value for reg, value in saved)
        if team_pattern is not None:
            actual = next(c['result'] for c in self.calls if c.get('stream')==0xE4)
            assert actual == team_pattern, (actual, team_pattern)
        print(label, 'calls', len(self.ordered), 'RNG', self.random_state(), flush=True)
        return dict(label=label, confirmation=confirmation, deviceResult=self.device_result, stimulus=self.host_writes, before=before, after=self.snapshot(),
                    calls=self.ordered, events=self.events,
                    bitmaps=[{**b, 'storage':self.record(self.region(b['address'], BITMAP_SIZE))} for b in self.bitmaps[first_bitmap:]],
                    accesses=[dict(mode=m, address=a, size=n, instruction=hex(pc)) for m,a,n,pc in sorted(self.global_accesses)],
                    abi=dict(returnAddress=STOP, stackAfter=sp+0xAB4, savedRegisters=[v for _,v in saved], restoredSEH=0))


def run_probes(vm):
    cases = []
    for action in range(1, 6):
        cases.append(vm.probe(f'unconfirmed-action-{action}', confirmation=0, action=action))
    for demo in (-1, 2):
        cases.append(vm.probe(f'non-one-demo-flag-{demo}', demo=demo))
    for confirmation in (0, 1, -1):
        for timer in (-1, 0, 1):
            for latch in (0, 1, -1):
                cases.append(vm.probe(f'finish-{confirmation}-{timer}-{latch}', confirmation=confirmation,
                                       words={0x44D078:timer, 0x4512C8:latch}))
    for extra in (0, 1, -1):
        for level in (-2147483648, -2, -1, 0, 1, 2, 2147483647):
            cases.append(vm.probe(f'difficulty-{extra}-{level}', action=4, words={0x450C30:level, 0x458428:extra}))
    for stage in (-2147483648, -10, 0, 40, 50, 51, 60, 2147483647):
        cases.append(vm.probe(f'next-stage-{stage}', action=3, mode=1, words={0x450B94:stage}))
    for arena in (-2147483648, -1, 0, 15, 16, 17, 99, 100, 2147483647):
        cases.append(vm.probe(f'next-arena-{arena}', action=3, words={0x44D024:arena, 0x44D028:7}))
    cases.append(vm.probe('clear-selections', action=1, flags=[1,0,2,-1,1,0,1,2147483647]))
    cases.append(vm.probe('reset-input', action=5, words={0x44D020:7, 0x457580:-1}))
    for flags in ([0]*8, [1,0,-1,2,0,1,0,1], [1]*8):
        cases.append(vm.probe(f'random-selections-{len(cases)}', action=2, flags=flags))
    for pattern in range(30):
        cases.append(vm.probe(f'demo-team-pattern-{pattern}', confirmation=0, demo=1, team_pattern=pattern))
    cases.append(vm.probe('demo-then-reset-selections', demo=1, action=1, flags=[1]*8, team_pattern=12))
    cases.append(vm.probe('demo-then-random-selections', demo=1, action=2, flags=[1]*8, team_pattern=20))
    cases.append(vm.probe('demo-then-arena', demo=1, action=3, team_pattern=29))
    cases.append(vm.probe('input-reset-then-demo', demo=1, action=5, team_pattern=0))
    return cases


def accept():
    subprocess.run(['swift', 'build', '--package-path', str(ROOT/'native'), '-c', 'release', '--product', 'NTSDCatalogCheck'], check=True)
    paths, reports = [], []
    for suffix in ('', '-ramp'):
        raw=(ROOT/f'build/original/match-continuation{suffix}.json').read_bytes()
        path=ROOT/f'docs/evidence/match-continuation{suffix}.json'
        report=json.loads(path.read_text()); assert digest(raw)==report['corpusSHA256']
        doc=json.loads(raw)
        for case in doc['cases']:
            case.pop('accesses')
        blobs=doc.pop('blobs')
        def keys(value):
            if isinstance(value,str): return {value} if value in blobs else set()
            if isinstance(value,list): return set().union(*(keys(x) for x in value))
            if isinstance(value,dict): return set().union(*(keys(x) for x in value.values()))
            return set()
        doc['blobs']={key:blobs[key] for key in sorted(keys(doc))}
        compact=json.dumps(doc,separators=(',',':')).encode()
        packed=dict(count=len(compact),sha256=digest(compact),deflate=base64.b64encode(zlib.compress(compact,level=9,wbits=-15)).decode())
        output=ROOT/f'build/original/match-continuation{suffix}-check.json'
        output.write_text(json.dumps(packed,separators=(',',':'))+'\n'); paths.append(output); reports.append((path,report,suffix))
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
    args=[str(fixtures/'original-loaded-catalog.json')]
    for path, suffix in zip(paths, ('','-ramp')):
        args.extend([str(fixtures/f'original-match-prelude{suffix}.json'),str(path)])
    result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--match-continuation',*args],check=True,capture_output=True,text=True)
    print(result.stdout,end='',flush=True)
    for packed,(path,report,suffix) in zip(paths,reports):
        fixture=fixtures/f'original-match-continuation{suffix}.json'; fixture.write_bytes(packed.read_bytes())
        report.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(fixture.read_bytes()),fixtureBytes=fixture.stat().st_size)
        path.write_text(json.dumps(report,indent=2)+'\n')


def summarize_case(case):
    # Complete ordered calls/candidate lists remain in the accepted fixture.
    # The readable report provides an inventory plus their canonical digest.
    calls = case['calls']
    return dict(label=case['label'], confirmation=case['confirmation'], deviceResult=case['deviceResult'],
                callKinds=dict(sorted(Counter(c['kind'] for c in calls).items())),
                callsSHA256=digest(json.dumps(calls,sort_keys=True,separators=(',',':')).encode()),
                teamPattern=next((c['result'] for c in calls if c.get('stream')==0xE4),None),
                constructors=[c['index'] for c in calls if c['kind']=='reconstruct'],
                loadedArenas=[c['index'] for c in calls if c['kind']=='load-layers'],
                bitmaps=len(case['bitmaps']), abi=case['abi'])


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--ramp',action='store_true'); parser.add_argument('--accept',action='store_true')
    args=parser.parse_args()
    if args.accept:
        assert not args.ramp
        accept(); return
    suffix='-ramp' if args.ramp else ''
    parent_report=json.loads((ROOT/f'docs/evidence/match-prelude{suffix}.json').read_text())
    parent_raw=(ROOT/'build/original'/parent_report['corpus']).read_bytes(); assert digest(parent_raw)==parent_report['corpusSHA256']
    parent=json.loads(parent_raw)
    raw=(ROOT/'build/original/loaded-catalog.json').read_bytes(); assert digest(raw)==parent['loadedCatalogSHA256']
    vm=Continuation(json.loads(raw),None if args.ramp else 0xA5)
    assert vm.bootstrap()==parent['staged']
    for item in parent['cases']:
        vm.stage=item['prelude']['stage']
        background=struct.unpack('<i',bytes.fromhex(item['stimulus'][0]['bytes']))[0]
        actual=vm.scenario(item['label'],item['mode'],background,item['selections'])
        assert json.loads(json.dumps(actual))==item
    assert vm.cleanup()==parent['cleanup']
    initial=vm.snapshot(); bitmap_addresses=[b['address'] for b in vm.bitmaps]
    cases=run_probes(vm); vm.verify_immutable()
    for case in cases:
        for bitmap in case['bitmaps']:
            assert vm.record(vm.region(bitmap['address'],BITMAP_SIZE)) == bitmap['storage']
    scope='Real42d704..42e0f9/ret12 after pinned full catalog/bootstrap/prelude/preparation/recording chain; menu commands, random roster and full450c2c==1; supplied input/RNG/ABI/device and disabled music, no whole UI or Windows output'
    doc=dict(exeSHA256=EXE_SHA256,scope=scope,parentFixtureSHA256=parent_report['fixtureSHA256'],parentCorpusSHA256=parent_report['corpusSHA256'],
             worldAddress=WORLD,catalogAddress=CATALOG,objectAddresses=vm.object_addresses,actorAddresses=vm.actor_addresses,
             bitmapAddresses=bitmap_addresses,surfaceAddress=DEVICE,initial=initial,cases=cases,assets=list(vm.asset_inputs.values()),blobs=vm.blobs)
    output=ROOT/f'build/original/match-continuation{suffix}.json'; output.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    summary=dict(exeSHA256=EXE_SHA256,scope=scope,corpus=output.name,corpusSHA256=digest(output.read_bytes()),cases=len(cases),nativeComparison='pending',
                 parentFixtureSHA256=parent_report['fixtureSHA256'],readsBeforeWrites=[],abiReturnsVerified=True,immutableCatalogObjectHeapBytesVerified=True,
                 casesSummary=[summarize_case(c) for c in cases])
    (ROOT/f'docs/evidence/match-continuation{suffix}.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('Captured',len(cases),'continuations:',output,flush=True)


if __name__=='__main__': main()
