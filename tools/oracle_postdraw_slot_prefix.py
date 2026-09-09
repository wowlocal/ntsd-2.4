#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""One entire post-draw slot prefix41f550..41fb0b, or inactive exit4214c6.

Real transforms, state9996 constructors/RNG, HP/MP recovery and whole40d960/
416fb0. Synthetic400-slot pool, four declared Objects and caller scratch+70;
explicitCW027f, full pool/masks/globals hashes and ordered helper requests.
No game helper is stubbed; constructor memset retains its established boundary.
The post-schedule/opoint/deletion continuation and full loop remain separate.
"""
import json
import itertools
import struct
from collections import Counter
from import_ntsd import ROOT, EXE_SHA256
from oracle_world_physics import WorldPhysics
from oracle_world_control import WORLD, POOL, BODY_SP, HEADER, d, b, q, digest, REGS
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI,
                              UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW,
                              UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

IDS = [2, 50, 217, 218]
STATES = {300: 9995, 301: 9996, 302: 8050, 303: 8999, 304: 8002, 305: 7999, 306: 9000}
HEADERS = [[2, *d(0x6f8, 3)], *[[n, *d(0x90, 20 + n)] for n in range(4)]]
CALLS = {0x4061d0: (0, 0), 0x417170: (2, 0), 0x40d960: (2, 8), 0x416fb0: (2, 0)}


class PostDrawSlotPrefix(WorldPhysics):
    source_ids = IDS
    frame_states = STATES
    header_patches = HEADERS

    def probe(self, item, index):
        self.item = item
        result = super().probe(item, index)
        result.update(endPC=self.uc.reg_read(UC_X86_REG_EIP), retainedBefore=item.get('retained', 0x12345678),
                      retainedAfter=self.u32(BODY_SP + 0x70))
        return result

    def execute(self):
        self.slot = self.item.get('slot', 0)
        self.uc.reg_write(UC_X86_REG_EDI, self.slot)
        self.uc.mem_write(BODY_SP, b'\xa5' * 0x600)
        self.uc.mem_write(BODY_SP + 0x70, struct.pack('<I', self.item.get('retained', 0x12345678)))
        self.uc.reg_write(UC_X86_REG_FPCW, 0x27f)
        self.uc.reg_write(UC_X86_REG_FPSW, 0)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.uc.emu_start(0x41f550, 0, count=2_000_000)
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
            assert sp == call['sp'] + 4 + call['pop'] and call['saved'] == [uc.reg_read(r) for r in REGS], call
            self.helpers += 1
            if call['entry'] == 0x417170:
                self.events.append(dict(slot=self.slot, kind='random', arguments=call['args'] + [uc.reg_read(UC_X86_REG_EAX)]))
        if pc in (0x41fb0b, 0x4214c6):
            assert not self.pending
            self.finished = True; uc.emu_stop(); return
        self.instructions.add(pc)
        if pc in CALLS:
            count, pop = CALLS[pc]
            args = [self.u32(sp + 4 + 4*i) for i in range(count)]
            self.pending.append(dict(entry=pc, sp=sp, pop=pop, returnPC=self.u32(sp), args=args, saved=[uc.reg_read(r) for r in REGS]))
            if pc == 0x416fb0:
                self.events.append(dict(slot=self.slot, kind='catalogSound', arguments=args))
            elif pc == 0x4061d0:
                self.target = uc.reg_read(UC_X86_REG_ECX)
                number, offset = divmod(self.target - POOL, 0x500)
                assert offset == 0 and 0 <= number < 400
                self.size = 0x420; self.mask = self.masks[number]; self.writes = []
                self.events.append(dict(slot=self.slot, kind='reconstruct', arguments=[self.u32(BODY_SP + 0x3c)]))
        assert any(a <= pc <= z for a, z in [(0x41f550, 0x41fb06), (0x40d960, 0x40de20),
                   (0x4061d0, 0x4064cc), (0x416fb0, 0x417082), (0x417170, 0x4171bc)]), hex(pc)


def case(group, values, slot=0, actor=(), active=None, **other):
    return dict(group=group, label=group + '-' + '-'.join(map(str, values)), slot=slot,
                active=[[slot, 1]] if active is None else active, actors=[[slot, list(actor)]], **other)


def probes():
    for slot, activity in itertools.product((0, 49, 50, 399), (0, 1, 128, 255)):
        yield case('activity', (slot, activity), slot=slot, active=[[slot, activity]])
    for number, kind, count, freeze in itertools.product((300, 302, 303, 304, 305, 306), (-1, 0, 3), (-1, 0, 1, 2, 4), (0, 1)):
        yield case('transform', (number, kind, count, freeze), actor=[d(0x70, number), d(0xb4, freeze), d(0x318, 123)],
                   headers=[[0, *d(0x6f8, kind)]], count=count)
    yield case('transform-chain', (0,), actor=[d(0x70, 300), d(0x88, 1)],
               frames=[[1, 0, *d(8, 8002)], [0, 0, *d(8, 9996)]])
    yield case('duplicate-id', (0,), actor=[d(0x70, 300)], headers=[[0, *d(0x6f4, 50)]])
    for hp, red, burn, divisor, phase in itertools.product((-2147483648, -1, 0, 1, 400, 500, 2147483647), (0, 500), (-1, 0), (-1, 0, 1, 100, 1000), (0, 1)):
        yield case('hp', (hp, red, burn, divisor, phase), actor=[d(0x2fc, hp), d(0x300, red), d(0x320, burn), d(0x340, divisor), d(0x34c, 2147483647)],
                   globals=[d(0x450bd0, phase), d(0x450bd4, 1)])
    for owner, mp, timer, phase in itertools.product((-2, -1, 0), (-2147483648, -1, 149, 150, 499, 500, 2147483647), (-1, 0), (-1, 0, 1)):
        yield case('mp-gates', (owner, mp, timer, phase), actor=[d(0x2f4, owner), d(0x308, mp), d(8, timer)], globals=[d(0x450bd4, phase)])
    for source, hp, mp in itertools.product((2, 50, 51, 52, 53), (-2147483648, -501, -1, 0, 1, 199, 200, 499, 500, 501, 2147483647), (-2147483648, 0, 499)):
        yield case('mp-amount', (source, hp, mp), actor=[d(0x2fc, hp), d(0x300, hp), d(0x308, mp), d(0x2f4, -1)],
                   headers=[[0, *d(0x6f4, source)]])
    for wait, kind in itertools.product((-2147483648, 0, 1, 2, 2147483647), (0, 3)):
        yield case('particle-gate', (wait, kind), actor=[d(0x70, 301), d(0x88, wait)], headers=[[0, *d(0x6f8, kind)]])
    for slot, free_count, alias, count in itertools.product((0, 50, 399), (0, 1, 3, 5), (0, 1, 2), (2, 3, 4)):
        free = [n for n in range(50, 400) if n != slot][:free_count]
        active = {n: 1 for n in range(50, 400) if n not in free}; active[slot] = 255
        aliases = [[free[0], slot]] if free and alias == 1 else [[free[1], free[0]]] if len(free) > 1 and alias == 2 else []
        yield case('particles', (slot, free_count, alias, count), slot=slot, active=list(active.items()), aliases=aliases, count=count, retained=1,
                   actor=[d(0x70, 301), d(0x88, 1), d(0x10, 2147483647), d(0x14, -2147483648), d(0x18, 2147483647)],
                   globals=[d(0x450bcc, 2999), d(0x450c34, 1233)])
    for retained in (0, 1, 2, 3):
        yield case('retained-index', (retained,), actor=[d(0x70, 301), d(0x88, 1)], count=0, retained=retained)
    for iy, cost in itertools.product((-1, 0), (-100, 0, 100)):
        yield case('scheduler-after-transform', (iy, cost), actor=[d(0x70, 300), d(0x14, iy)],
                   frames=[[1, 0, *d(0x10, 3)], [1, 3, *d(0x4c, cost)], [1, 3, *d(0x28, 4)]])


def main():
    vm = PostDrawSlotPrefix(); cases = []
    for index, item in enumerate(probes()):
        cases.append(vm.probe(item, index))
        if (index + 1) % 250 == 0:
            print('POSTDRAW SLOT PREFIX', index + 1, flush=True)
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, fpcw=0x27f, header=HEADER, headerPatches=HEADERS,
               ids=IDS, states=STATES, cases=cases, instructions=sorted(vm.instructions))
    raw = (json.dumps(doc, separators=(',', ':')) + '\n').encode(); name = 'postdraw-slot-prefix.json'
    (ROOT / 'build/original' / name).write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, fpcw=0x27f, corpus=name, sha256=digest(raw), bytes=len(raw),
                  cases=len(cases), groups=dict(Counter(c['group'] for c in cases)), helpers=sum(c['helpers'] for c in cases),
                  events=sum(len(c['events']) for c in cases), instructions=len(vm.instructions), nativeCompared=False, windowsVerified=False)
    (ROOT / 'build/research' / name).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
