#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Complete post-scheduler slot41fb0b..4214c6 and whole live-slot41f550 loop.

Original constructors, scheduler, RNG, sound and conversions. Declared400-slot
pool/four Objects, explicitCW027f and caller retained words. Entire pool/masks,
globals, ordered helpers and retained-word outputs; not initialized natural play.
"""
import itertools
import json
import struct
import copy
from collections import Counter
from import_ntsd import ROOT, EXE_SHA256
from oracle_world_physics import WorldPhysics
from oracle_world_control import POOL, BODY_SP, HEADER, REGS, d, b, q, digest
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_ESI,
                              UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)
IDS = [100, 999, 998, 50]
STATES = {300: 3, 301: 13, 302: 18, 303: 19, 304: 9996}
HEADERS = [[0, *d(0x6f8, 1)], [1, *d(0x6f8, 3)], [2, *d(0x6f8, 3)],
           *[[n, *d(0x90, 20+n)] for n in range(4)]]
SCRATCH = [0x44, 0x50, 0x5c, 0x60, 0x6c, 0x70]
DEFAULT_SCRATCH = [0x12345678, 1, 0x23456789, 0x3456789a, 1, 3]
CALLS = {0x4061d0: (0, 0), 0x40d960: (2, 8), 0x417170: (2, 0), 0x416fb0: (2, 0),
         0x417090: (2, 0), 0x4450d0: (0, 0)}


class PostDrawLifecycle(WorldPhysics):
    source_ids = IDS
    frame_states = STATES
    header_patches = HEADERS
    def probe(self, item, index):
        self.item = item
        result = super().probe(item, index)
        result.update(endPC=self.uc.reg_read(UC_X86_REG_EIP), scratchBefore=item.get('scratch', DEFAULT_SCRATCH),
                      scratchAfter=[self.u32(BODY_SP+x) for x in SCRATCH])
        return result
    def execute(self):
        self.whole = self.item.get('whole', False)
        self.slot = self.item.get('slot', 0)
        self.uc.reg_write(UC_X86_REG_EDI, 0 if self.whole else self.slot)
        self.uc.mem_write(BODY_SP, b'\xa5'*0x800)
        for offset, value in zip(SCRATCH, self.item.get('scratch', DEFAULT_SCRATCH)):
            self.uc.mem_write(BODY_SP+offset, struct.pack('<I', value))
        self.uc.mem_write(0x45971c, struct.pack('<I', self.item.get('sse2', 0)))
        self.uc.reg_write(UC_X86_REG_FPCW, 0x27f); self.uc.reg_write(UC_X86_REG_FPSW, 0); self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.uc.emu_start(0x41f550 if self.whole else 0x41fb0b, 0, count=8_000_000)
        assert self.uc.reg_read(UC_X86_REG_EDI) == (400 if self.whole else self.slot)
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x27f and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7 == 0
        assert self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff
    def code(self, uc, pc, size, data):
        if not self.running or pc == 0x4450a0: return
        sp = uc.reg_read(UC_X86_REG_ESP)
        while self.pending and pc == self.pending[-1]['returnPC']:
            h = self.pending.pop()
            assert sp == h['sp']+4+h['pop'] and h['saved'] == [uc.reg_read(r) for r in REGS], h
            self.helpers += 1
            if h['entry'] == 0x417170:
                self.events.append(dict(slot=h['slot'], kind='random', arguments=h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
        if pc == (0x4214d5 if self.whole else 0x4214c6):
            assert not self.pending; self.finished = True; uc.emu_stop(); return
        self.instructions.add(pc)
        if pc in CALLS:
            count, pop = CALLS[pc]; args = [self.u32(sp+4+4*i) for i in range(count)]
            #40d960 saves the caller EDI then reuses it for0/14/999. Its
            #nested sound belongs to the saved scheduler slot, not that local.
            scheduler = next((h for h in reversed(self.pending) if h['entry'] == 0x40d960), None)
            slot = scheduler['slot'] if scheduler else uc.reg_read(UC_X86_REG_EDI)
            self.pending.append(dict(entry=pc, sp=sp, pop=pop, returnPC=self.u32(sp), args=args, slot=slot, saved=[uc.reg_read(r) for r in REGS]))
            if pc in (0x416fb0, 0x417090):
                self.events.append(dict(slot=slot, kind='catalogSound' if pc == 0x416fb0 else 'builtinSound', arguments=args))
            elif pc == 0x4061d0:
                self.target = uc.reg_read(UC_X86_REG_ECX); physical, offset = divmod(self.target-POOL, 0x500)
                assert offset == 0 and 0 <= physical < 400
                self.size = 0x420; self.mask = self.masks[physical]; self.writes = []
                created = self.u32(BODY_SP+0x3c) if self.u32(sp) == 0x41f751 else uc.reg_read(UC_X86_REG_ESI)
                self.events.append(dict(slot=slot, kind='reconstruct', arguments=[created]))
        assert any(a <= pc <= z for a, z in [(0x41f550, 0x4214cf), (0x4061d0, 0x4064cc), (0x40d960, 0x40de20),
                                            (0x416fb0, 0x417082), (0x417090, 0x417162), (0x417170, 0x4171bc), (0x4450d0, 0x44517a)]), hex(pc)


def case(group, values, actor=(), slot=0, frames=(), active=None, **other):
    return dict(group=group, label=group+'-'+'-'.join(map(str, values)), slot=slot,
                actors=[[slot, [d(0x70, 300), d(0x78, 0), d(0x31c, 20), d(0x10, 300), d(0x14, -50), d(0x18, 480),
                    q(0x58, 300.25), q(0x60, -50.75), q(0x68, 480.5), *actor]]], frames=list(frames),
                active=[[slot, 1]] if active is None else active, **other)


def probes():
    for kind, hp, source, sound in itertools.product((-1, 0, 1, 2, 3, 4, 5, 6), (-1, 0, 1),
            (99, 100, 101, 120, 121, 122, 123, 124, 150, 151, 201, 213, 217, 218, 999), (-1, 0)):
        yield case('weapon', (kind, hp, source, sound), actor=[d(0x31c, hp)],
                   headers=[[0, *d(0x6f8, kind)], [0, *d(0x6f4, source)], [0, *d(0xac, sound)]])
    for source, free_count, alias, count in itertools.product((100, 101, 122, 123, 150, 151, 201, 213, 217), (0, 1, 3, 8), (0, 1, 2), (-1, 0, 1, 4)):
        free = list(range(50, 50+free_count)); active = [[0, 1]]+[[n, 1] for n in range(50, 400) if n not in free]
        aliases = [[50, 0]] if free and alias == 1 else [[51, 50]] if len(free)>1 and alias == 2 else []
        yield case('weapon-pool', (source, free_count, alias, count), actor=[d(0x31c, -1)], active=active, aliases=aliases, count=count,
                   headers=[[0, *d(0x6f4, source)]], globals=[d(0x450bcc, 2999), d(0x450c34, 1233)])
    for slot, command, kind, hp in itertools.product((0, 9, 10, 399), ((9, 0, 9, 0), (9, 9, 9, 9), (9, 5, 9, 5), (9, 0, 9, 1), (8, 0, 9, 0)), (0, 3), (0, 1)):
        yield case('command-gates', (slot, command, kind, hp), slot=slot, actor=[d(0x2fc, hp), *[d(o, v) for o, v in zip((0x40c, 0x410, 0x414, 0x418), command)]], headers=[[0, *d(0x6f8, kind)]])
    for command, activity, kind, hp, team, count, full in itertools.product(((9, 0, 9, 0), (9, 9, 9, 9), (9, 5, 9, 5)), (0, 1, 2, 255), (0, 3), (0, 1), (0, 1), (0, 2, 4), (False, True)):
        active = [[0, 1], [1, activity]]+([[n, 1] for n in range(50, 400)] if full else [])
        item = case('command-targets', (command, activity, kind, hp, team, count, full), active=active, count=count,
                    actor=[d(0x364, 1), *[d(o, v) for o, v in zip((0x40c, 0x410, 0x414, 0x418), command)]],
                    headers=[[0, *d(0x6f8, 0)], [3, *d(0x6f8, kind)]])
        item['actors'].append([1, [d(0x368, 3), d(0x2fc, hp), d(0x364, team)]])
        yield item
    for previous, current, count, free_count, alias in itertools.product((0, 200, 301, 302, 303), (0, 200, 301, 302, 303), (0, 1, 4), (0, 1, 7, 20), (False, True)):
        free = list(range(50, 50+free_count)); active = [[0, 255]]+[[n, 1] for n in range(50, 400) if n not in free]
        yield case('late-effects', (previous, current, count, free_count, alias), actor=[d(0x78, previous), d(0x70, current), q(0x28, -1.25), q(0x40, 2.75)],
                   count=count, active=active, aliases=[[50, 0]] if free and alias else [], globals=[d(0x450bcc, 2999), d(0x450c34, 1233)])
    for current, seed in itertools.product((302, 303), range(8)):
        yield case('fire-roll', (current, seed), actor=[d(0x70, current), d(0x78, 302)], globals=[d(0x450c34, seed)])
    for whole, slot, mode in itertools.product((False, True), (0, 49, 50, 399), ('weapon', 'opoint', 'particles', 'dead', 'fire', 'command')):
        actor=[]; frames=[]; headers=[]
        if mode == 'weapon': actor=[d(0x31c, -1)]
        elif mode == 'opoint': frames=[[0, 300, *d(o,v)] for o,v in [(0x58, 1), (0x64, 2), (0x68, 8), (0x70, 999), (0x74, 30)]]
        elif mode == 'particles': actor=[d(0x70, 304), d(0x88, 1)]; headers=[[0, *d(0x6f8, 0)]]
        elif mode == 'dead': actor=[d(0x78, 301)]
        elif mode == 'fire': actor=[d(0x78, 302)]
        else: actor=[d(0x40c,9),d(0x414,9)]; headers=[[0,*d(0x6f8,0)]]
        yield case('joined', (whole, slot, mode), slot=slot, actor=actor, frames=frames, headers=headers, whole=whole)
    for previous, offset, value in itertools.product((301, 302), (0x58, 0x60, 0x28, 0x40),
            (-1.7976931348623157e308, -9007199254740992., -1e-300, -0.0, 0.0, 1e-300, 0.1, 9007199254740992., 1.7976931348623157e308)):
        yield case('late-numeric', (previous, offset, value), actor=[d(0x78, previous), q(offset, value)])
    #Continue every accepted component input through its surrounding consumer.
    #No expected component output is supplied as input to this new source run.
    for name, whole in [('postdraw-slot-prefix', True), ('postdraw-opoint', False)]:
        report = json.loads((ROOT/'docs/evidence'/f'{name}.json').read_bytes())
        raw = (ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(raw) == report['sha256'] and digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes()) == report['fixtureSHA256']
        doc = json.loads(raw)
        for old in doc['cases']:
            item = copy.deepcopy({k:v for k,v in old.items() if k not in ('fill', 'poolSHA256', 'maskSHA256', 'globalsSHA256', 'events', 'helpers', 'endPC', 'retainedBefore', 'retainedAfter')})
            item.update(group='continued-'+name, label='continued-'+name+'-'+old['label'], whole=whole)
            item['headers'] = [[n, *d(0x6f4, oid)] for n,oid in enumerate(doc['ids'])]+[[n, *d(0x6f8, 3 if n == 3 else 0)] for n in range(4)]+doc['headerPatches']+item.get('headers', [])
            item['frames'] = [[n, number, *d(8, doc['states'].get(str(number), 3))] for n in range(4) for number in sorted(set(STATES)|set(map(int, doc['states'])))]+item.get('frames', [])
            item['scratch'] = DEFAULT_SCRATCH[:-1]+[item.get('retained', DEFAULT_SCRATCH[-1])]
            yield item


def main():
    vm=PostDrawLifecycle(); cases=[]
    for n, item in enumerate(probes()):
        cases.append(vm.probe(item,n))
        if (n+1)%500==0: print('POSTDRAW LIFECYCLE',n+1,flush=True)
    doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,fpcw=0x27f,header=HEADER,headerPatches=HEADERS,ids=IDS,states=STATES,
             scratchOffsets=SCRATCH,cases=cases,instructions=sorted(vm.instructions))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode(); name='postdraw-lifecycle.json'
    (ROOT/'build/original'/name).write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,fpcw=0x27f,corpus=name,sha256=digest(raw),bytes=len(raw),cases=len(cases),
        groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),events=sum(len(c['events']) for c in cases),
        instructions=len(vm.instructions),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/name).write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__': main()
