#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole post-scheduler corrections/opoint41fb0b..4203b4 plus early exits.

Real Actor constructors and4450d0 conversions; stops at4203b4 (no opoint),
420e93 (opoint path) or4214c6 (early frame lifetime handling). Declared400-slot
pool/four Objects, explicit53-bit precision and legacy/SSE2 controls. Full
pool/masks/globals and ordered constructor events. Not the entire slot loop.
"""
import itertools
import json
import struct
from collections import Counter
from import_ntsd import ROOT, EXE_SHA256
from oracle_world_physics import WorldPhysics
from oracle_world_control import WORLD, POOL, BODY_SP, HEADER, REGS, d, b, q, digest
from unicorn.x86_const import (UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_ESI,
                              UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW,
                              UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

IDS = [2, 211, 223, 224]
STATES = {300: 3}
HEADERS = [[n, *d(0x6f8, 3)] for n in (1, 2)] + [[n, *d(0x90, 20+n)] for n in range(4)]
EXITS = (0x4203b4, 0x420e93, 0x4214c6)


class PostDrawOpoint(WorldPhysics):
    source_ids = IDS
    frame_states = STATES
    header_patches = HEADERS

    def probe(self, item, index):
        self.item = item
        result = super().probe(item, index)
        result.update(endPC=self.uc.reg_read(UC_X86_REG_EIP))
        return result

    def execute(self):
        self.slot = self.item.get('slot', 0)
        self.uc.reg_write(UC_X86_REG_EDI, self.slot)
        self.uc.mem_write(BODY_SP, b'\xa5' * 0x600)
        self.uc.mem_write(0x45971c, struct.pack('<I', self.item.get('sse2', 0)))
        self.uc.reg_write(UC_X86_REG_FPCW, 0x27f)
        self.uc.reg_write(UC_X86_REG_FPSW, 0)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.uc.emu_start(0x41fb0b, 0, count=4_000_000)
        assert self.uc.reg_read(UC_X86_REG_EDI) == self.slot
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x27f
        assert (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7 == 0
        assert self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff

    def code(self, uc, pc, size, data):
        if not self.running or pc == 0x4450a0:
            return
        sp = uc.reg_read(UC_X86_REG_ESP)
        while self.pending and pc == self.pending[-1]['returnPC']:
            call = self.pending.pop()
            assert sp == call['sp'] + 4 and call['saved'] == [uc.reg_read(r) for r in REGS], call
            self.helpers += 1
        if pc in EXITS:
            assert not self.pending
            self.finished = True; uc.emu_stop(); return
        self.instructions.add(pc)
        if pc in (0x4061d0, 0x4450d0):
            self.pending.append(dict(entry=pc, sp=sp, returnPC=self.u32(sp), saved=[uc.reg_read(r) for r in REGS]))
            if pc == 0x4061d0:
                self.target = uc.reg_read(UC_X86_REG_ECX)
                physical, offset = divmod(self.target - POOL, 0x500)
                assert offset == 0 and 0 <= physical < 400
                self.size = 0x420; self.mask = self.masks[physical]; self.writes = []
                self.events.append(dict(slot=self.slot, kind='reconstruct', arguments=[uc.reg_read(UC_X86_REG_ESI)]))
        assert any(a <= pc <= z for a, z in [(0x41fb0b, 0x4203af), (0x4213a9, 0x4214bf),
                   (0x4061d0, 0x4064cc), (0x4450d0, 0x44517a)]), hex(pc)


def f(n, offset, value, obj=0):
    return [obj, n, *d(offset, value)]


def case(group, values, slot=0, actor=(), frames=(), active=None, **other):
    return dict(group=group, label=group+'-'+'-'.join(map(str, values)), slot=slot,
                active=[[slot, 1]] if active is None else active,
                actors=[[slot, [d(0x70, 300), *actor]]], frames=list(frames), **other)


def spawn(group, values, actor=(), frames=(), **other):
    inputs = [f(300, o, v) for o, v in [(0x50, 30), (0x54, 40), (0x58, 1), (0x5c, 17),
              (0x60, 19), (0x64, 2), (0x68, 8), (0x6c, -7), (0x70, 211), (0x74, 0)]]
    return case(group, values, actor=[d(0x10, 300), d(0x14, -50), q(0x68, 479.75), d(0x354, 31),
                d(0x364, 7), d(0x2f4, -1), *actor], frames=inputs+list(frames), **other)


def probes():
    for number in (-2147483648, -1300, -1, 0, 11, 12, 110, 111, 179, 180, 184, 189, 190, 212, 214, 215, 399, 400, 1099, 1100, 1199, 1200, 1299, 1300, 2147483647):
        for kind, hp in itertools.product((0, 3), (-1, 0, 1)):
            yield case('lifetime', (number, kind, hp), actor=[d(0x70, number), d(0x2fc, hp)], headers=[[0, *d(0x6f8, kind)]])
    for number, offset, value in itertools.product((179, 180, 184, 189, 190, 211, 212, 214, 215), (0x60, 0x48, 0x30), (-0.0, 0.0, -1e-300, 1e-300, float('inf'), float('nan'))):
        yield case('ground', (number, offset, str(value)), actor=[d(0x70, number), d(0x14, 0), q(0x60, 0), q(0x48, 0), q(0x30, 0), q(offset, value)])
    for slot, number, activity, alias in itertools.product((0, 199, 399), (1100, 1150, 1200, 1299), (0, 1, 2, 255), (False, True)):
        owned = (slot+1)%400
        item = case('lifetime-owned', (slot, number, activity, alias), slot=slot, actor=[d(0x70, number), d(8, 77), d(0x2f4, slot)],
                    active=[[slot, 1], [owned, activity]], aliases=[[owned, slot]] if alias else [])
        if not alias: item['actors'].append([owned, [d(0x2f4, slot), d(8, 88)]])
        yield item
    for kind, oid, wait, freeze, typ in itertools.product((-1, 0, 1, 2, 3), (-1, 0, 211, 999), (-1, 0, 1), (0, 1), (0, 3)):
        yield spawn('gates', (kind, oid, wait, freeze, typ), actor=[d(0x88, wait), d(0xb4, freeze)],
                    frames=[f(300, 0x58, kind), f(300, 0x70, oid)], headers=[[0, *d(0x6f8, typ)]])
    for facing, packed, vx in itertools.product((0, 1, 2, 255), (-2147483648, -1, 0, 1, 2, 10, 11, 20, 21, 30, 40, 60, 70), (-8, 0, 8)):
        yield spawn('facing-count', (facing, packed, vx), actor=[b(0x80, facing)], frames=[f(300, 0x74, packed), f(300, 0x68, vx)])
    for state, source, mask, typ, owner in itertools.product((3, 1002, 3000, 3006), (5, 52, 211, 223, 224), range(4), (0, 3), (-2, -1, 0, 399)):
        yield spawn('child-rules', (state, source, mask, typ, owner), actor=[b(0xcd, 2 if mask&1 else 0), b(0xce, 255 if mask&2 else 0), d(0x2f4, owner)],
                    frames=[f(300, 0x70, source), f(2, 8, state, 1)], headers=[[1, *d(0x6f4, source)], [1, *d(0x6f8, typ)]])
    for packed, free_count, alias, count in itertools.product((0, 20, 30, 40, 60), (0, 1, 3, 5), (0, 1, 2), (-1, 0, 1, 4)):
        free = list(range(50, 50+free_count)); active = [[0, 255]]+[[n, 1] for n in range(50, 400) if n not in free]
        aliases = [[50, 0]] if free and alias == 1 else [[51, 50]] if len(free)>1 and alias == 2 else []
        yield spawn('pool-alias', (packed, free_count, alias, count), active=active, aliases=aliases, count=count,
                    frames=[f(300, 0x74, packed), f(0, 0x50, -50, 1), f(0, 0x54, 10, 1)])
    for kind, held_owner, mask in itertools.product((0, 3), (0, 5, 399), (0, 1, 2, 255)):
        item = spawn('vrest-links', (kind, held_owner, mask), actor=[d(0, held_owner), (0xf0, (b'\xa7'*400).hex())],
            active=[[0, 1], [5, mask], [199, 255], [399, 1]], frames=[f(300, 8, 3003), f(300, 0x58, 2), f(300, 0x74, 30)], headers=[[0, *d(0x6f8, kind)]])
        for n in (5, 199, 399): item['actors'].append([n, [(0xf0, (b'\xa7'*400).hex())]])
        yield item
    for z, sse in itertools.product((-1e20, -9223372036854775808., -4294967296.9, -2147483648.9, -1.5, -0.0, 0.0,
                                     2147483647.9, 2147483648., 4294967296.9, 9007199254740992., 9223372036854775808., 1e20), (0, 1)):
        yield spawn('depth-conversion', (z, sse), actor=[q(0x68, z)], sse2=sse)
    for x, y, cx, cy, ox, oy, facing in itertools.product((-2147483648, 2147483647), (-2147483648, 2147483647), (-1, 1), (-1, 1), (-1, 1), (-1, 1), (0, 1)):
        yield spawn('coordinate-wrap', (x, y, cx, cy, ox, oy, facing), actor=[d(0x10, x), d(0x14, y), b(0x80, facing)],
                    frames=[f(300, 0x50, cx), f(300, 0x54, cy), f(300, 0x5c, ox), f(300, 0x60, oy)])
    for slot, alias, packed in itertools.product((49, 50, 399), (False, True), (0, 21, 50)):
        free = 51 if slot == 50 else 50
        yield spawn('selected-slot', (slot, alias, packed), slot=slot, aliases=[[free, slot]] if alias else [],
                    frames=[f(300, 0x74, packed)])
    #All multiplicities found by a static survey of the original loaded DAT
    #catalog, including35. These remain controlled inputs, not natural play.
    for count, vx, mask in itertools.product((1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 35), (-2147483648, -8, 0, 8, 2147483647), (1, 2)):
        yield spawn('spread-count', (count, vx, mask), actor=[b(0xcd, mask&1), b(0xce, mask&2)],
                    frames=[f(300, 0x74, count*10), f(300, 0x68, vx), f(2, 8, 3000, 1)])
    item = case('all-owned-slots', (0,), actor=[d(0x70, 1150), d(0x2f4, 0)], active=[[n, 1] for n in range(400)])
    item['actors'] += [[n, [d(0x2f4, 0)]] for n in range(1, 400)]
    yield item


def main():
    vm = PostDrawOpoint(); cases = []
    for index, item in enumerate(probes()):
        cases.append(vm.probe(item, index))
        if (index+1)%500 == 0: print('POSTDRAW OPOINT', index+1, flush=True)
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, fpcw=0x27f, header=HEADER, headerPatches=HEADERS,
               ids=IDS, states=STATES, cases=cases, instructions=sorted(vm.instructions))
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode(); name = 'postdraw-opoint.json'
    (ROOT/'build/original'/name).write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, fpcw=0x27f, corpus=name, sha256=digest(raw), bytes=len(raw),
                  cases=len(cases), groups=dict(Counter(c['group'] for c in cases)), helpers=sum(c['helpers'] for c in cases),
                  events=sum(len(c['events']) for c in cases), instructions=len(vm.instructions), nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research'/name).write_text(json.dumps(report, indent=2)+'\n'); print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__': main()
