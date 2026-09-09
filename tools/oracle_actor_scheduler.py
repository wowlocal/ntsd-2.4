#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole40d960..40de20 and actual catalog sound416fb0..417082 at explicitCW027f.

Declared synthetic Actor/Object/Frame/global inputs, original Actor constructors.
No scheduler or sound helper is stubbed. Full Actor bytes/masks, whole globals
SHA, ordered sound requests, saved registers, ret8 and empty FPU stack checked.
This is not the enclosing interleaved400-slot caller or a natural DAT sequence.
"""
import itertools
import json
import math
import struct
from collections import Counter
from import_ntsd import ROOT, EXE_SHA256
from oracle_actor_control import ActorControl, d, b, f, q, digest, REGS
from unicorn.x86_const import UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

HEADER = [d(0x6f4, 2), d(0x6f8, 0), q(0x50, -9.7), q(0x58, 8.3), q(0x60, 1.9)]


class ActorScheduler(ActorControl):
    def object_bytes(self, item):
        obj = bytearray(0x40000)
        for offset, raw in HEADER + item.get('header', []):
            value = bytes.fromhex(raw); obj[offset:offset + len(value)] = value
        for number in range(400):
            offset = 0x7a4 + number * 0x178
            obj[offset] = 1
            struct.pack_into('<i', obj, offset + 8, 3)
            struct.pack_into('<i', obj, offset + 0x174, -1)
        for number, offset, raw in item.get('frames', []):
            value = bytes.fromhex(raw); start = 0x7a4 + number * 0x178 + offset
            obj[start:start + len(value)] = value
        return bytes(obj)

    def code(self, uc, pc, size, data):
        if not self.running:
            return
        sp = uc.reg_read(UC_X86_REG_ESP)
        while self.pending and pc == self.pending[-1]['returnPC']:
            call = self.pending.pop()
            assert sp == call['sp'] + 4 and [uc.reg_read(reg) for reg in REGS] == call['saved']
        if pc == self.until:
            assert not self.pending
            uc.emu_stop(); return
        self.instructions.add(pc)
        if pc == 0x416fb0:
            self.pending.append(dict(sp=sp, returnPC=self.u32(sp), saved=[uc.reg_read(reg) for reg in REGS]))
            self.events.append(dict(kind='catalogSound', arguments=[self.u32(sp + 4), self.u32(sp + 8)]))
        assert 0x40d960 <= pc <= 0x40de20 or 0x416fb0 <= pc <= 0x417082, hex(pc)

    def execute(self, item):
        self.uc.reg_write(UC_X86_REG_FPCW, 0x27f)
        self.uc.reg_write(UC_X86_REG_FPSW, 0)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.call(0x40d960, (item.get('mode', 0), item.get('slot', 0)), pop=8)
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x27f
        assert (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7 == 0
        assert self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff

    def probe(self, item, index):
        try:
            result = super().probe(item, index)
            result['writes'] = self.writes.copy()
            return result
        except Exception:
            print('SCHEDULER FAILURE', item['label'], flush=True)
            raise


def scenario(group, values, actor=(), frames=(), header=(), **other):
    return dict(label=group + '-' + '-'.join(map(str, values)), group=group,
                actor=list(actor), frames=list(frames), header=list(header), **other)


def probes():
    for freeze, kind, held, point in itertools.product((-2147483648, -1, 0, 1, 2147483647), (-1, 0, 2, 3), (-2, -1, 0, 2), (0, 1, 2, 3)):
        yield scenario('gates', (freeze, kind, held, point), actor=[d(0xb4, freeze), d(0x98, held), d(0xec, 2)],
                       header=[d(0x6f8, kind)], frames=[f(0, 0x88, point)])
    for counter, byte, wait in itertools.product((-2147483648, -2, -1, 0, 1, 2, 2147483647), (-128, -1, 0, 1, 2, 127), (-1, 0, 1, 2147483647)):
        yield scenario('counters', (counter, byte, wait), actor=[*[d(o, counter) for o in (8, 0xb0, 0xb8, 0xec, 0x88)], b(0xea, byte)], frames=[f(0, 0xc, wait)])
    for nxt, previous, facing, kind, iy in itertools.product((-2147483648, -1000, -999, -400, -399, -212, -202, -114, -110, -3, -1, 0, 1, 3, 110, 114, 202, 212, 399, 400, 999, 1000, 2147483647), (0, 2), (0, 1, 2, 255), (-1, 0, 2, 3), (-1, 0, 1)):
        yield scenario('next', (nxt, previous, facing, kind, iy), actor=[d(0x74, previous), b(0x80, facing), d(0x14, iy)],
                       header=[d(0x6f8, kind)], frames=[f(0, 0x10, nxt)])
    for hp, cost, target in itertools.product((-2147483648, -1, 0, 1, 500, 2147483647), (0, 1, 500, 2147483647), (1, 212)):
        yield scenario('type3-hp', (hp, cost, target), actor=[d(0x2fc, hp)], header=[d(0x6f8, 3)],
                       frames=[f(0, 0x24, cost), f(0, 0x28, target), f(target, 0xc, 1)])
    speeds = [-math.inf, -1., math.nextafter(-.1, -math.inf), -.1, math.nextafter(-.1, 0), -0., 0.,
              math.nextafter(.1, 0), .1, math.nextafter(.1, math.inf), 1., math.inf, math.nan]
    for kind, iy, speed in itertools.product((0, 1, 2, 3), (-1, 0, 1), speeds):
        yield scenario('weapon', (kind, iy, speed), actor=[d(0x14, iy), q(0x40, speed), b(0x80, 255)],
                       header=[d(0x6f8, kind)], frames=[f(0, 8, 2000)])
    for hp, timer, owner, category, slot in itertools.product((-1, 0, 1), (-1, 0, 1, 31), (-1, 0), (0, 5), (0, 19, 20, 399)):
        yield scenario('death', (hp, timer, owner, category, slot), actor=[d(0x2fc, hp), d(8, timer), d(0x2f4, owner), d(0x364, category)],
                       frames=[f(0, 8, 14), f(0, 0x10, 1)], slot=slot)
    for state, category, flag, mode, selector, source in itertools.product((3, 13), (0, 5), (0, 1), (-1, 0, 1, 4), (1, 2), (-30, 29, 30, 37, 38, 39, 40)):
        yield scenario('recover', (state, category, flag, mode, selector, source), actor=[d(0x74, 2), d(0x364, category), d(0x344, flag)],
                       frames=[f(2, 8, 14), f(0, 0x10, 3), f(3, 8, state)], header=[d(0x6f4, source)],
                       globals=[d(0x450c30, selector)], mode=mode)
    for up, down, left, right in itertools.product((0, 1, 2, 255), repeat=4):
        yield scenario('jump-input', (up, down, left, right), actor=[b(0xcd, up), b(0xce, down), b(0xcf, left), b(0xd0, right)], frames=[f(0, 0x10, 212)])
    for speed, mask in itertools.product((-math.inf, -1.7976931348623157e308, -5e-324, -0., 0., 5e-324, 1.7976931348623157e308, math.inf), range(16)):
        yield scenario('jump-bits', (speed, mask), actor=[b(0xcd + i, mask >> i & 1) for i in range(4)],
                       header=[q(o, speed) for o in (0x50, 0x58, 0x60)], frames=[f(0, 0x10, 212)])
    for cost, mp, enabled, mask in itertools.product((-2147483648, -2001, -100, -1, 0, 1), (-2147483648, -101, -100, -1, 0, 2147483647), (0, 1, -1), range(16)):
        yield scenario('negative-mp', (cost, mp, enabled, mask), actor=[d(0x308, mp), d(0x350, 2147483647),
                       b(0xcf, mask & 1), b(0xd0, mask >> 1 & 1), b(0x80, mask >> 2 & 1), d(0x14, -1 if mask & 8 else 0)],
                       frames=[f(0, 0x10, 1), f(1, 0x4c, cost), f(1, 0x28, 2), f(2, 0x28, 3)], globals=[d(0x44d034, enabled)])
    for number, wait, nxt in itertools.product((110, 114, 202), (-1, 0, 1), (0, 3)):
        yield scenario('tail', (number, wait, nxt), actor=[d(0x70, number), d(0x74, number)], frames=[f(number, 0xc, wait), f(number, 0x10, nxt)])
    for x, camera, flag, sound in itertools.product((-2147483648, -400, -1, 0, 199, 200, 399, 400, 599, 600, 799, 800, 1000, 2147483647), (-1, 0, 2147483647), (0, 1, -1), (0, 7, 399)):
        yield scenario('sound-twice', (x, camera, flag, sound), actor=[d(0x74, 2), d(0x10, x)],
                       frames=[f(0, 0x174, sound), f(0, 0x10, 1), f(1, 0x174, sound)],
                       globals=[d(0x450bc4, camera), d(0x457588 + sound * 4, flag), d(0x457bc8 + sound * 4, 2147483647), d(0x452170 + sound * 4, -2147483648)])
    # The airborne state0 transition is independent of wait expiry and must
    # subsequently read frame212 metadata, not keep the pre-transition frame.
    for kind, wait, nxt in itertools.product((-1, 0, 2, 3), (0, 1, 2), (0, 3, 999)):
        yield scenario('airborne-standing', (kind, wait, nxt), actor=[d(0x14, -1)], header=[d(0x6f8, kind)],
                       frames=[f(0, 8, 0), f(0, 0xc, 100), f(212, 0xc, wait), f(212, 0x10, nxt)])


def main():
    vm = ActorScheduler(); cases = []
    for index, item in enumerate(probes()):
        cases.append(vm.probe(item, index))
        if (index + 1) % 2000 == 0:
            print('ACTOR SCHEDULER', index + 1, flush=True)
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, fpcw=0x27f, header=HEADER, cases=cases, instructions=sorted(vm.instructions))
    raw = (json.dumps(doc, separators=(',', ':')) + '\n').encode()
    name = 'actor-scheduler.json'; (ROOT / 'build/original' / name).write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=name, sha256=digest(raw), bytes=len(raw), fpcw=0x27f,
                  cases=len(cases), groups=dict(Counter(c['group'] for c in cases)), instructions=len(vm.instructions),
                  events=sum(len(c['events']) for c in cases), writes=sum(len(c['writes']) for c in cases), nativeCompared=False, windowsVerified=False)
    (ROOT / 'build/research' / name).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
