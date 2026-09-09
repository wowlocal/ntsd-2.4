#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole4214d5..421a15 item/resource commands, healing and slot cleanup.

Controlled400-slot pool/four Objects/declared BGs, actual constructors/RNG/
conversion/402000. Only constructor memset and COM response are boundaries.
Full pool bytes/masks, globals and retainedSP34. ExplicitCW027f, not Windows.
"""
import itertools
import json
import struct
from collections import Counter
from import_ntsd import ROOT, EXE_SHA256
from oracle_world_physics import WorldPhysics
from oracle_world_control import WORLD, POOL, CATALOG, BODY_SP, HEADER, REGS, d, b, digest
from unicorn import UC_MEM_READ
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_EIP,
                              UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

IDS = [100, 122, 123, 300]
STATES = {300: 1700}
HEADERS = [[n, *d(0x6f8, kind)] for n, kind in enumerate((1, 2, 2, 0))] + [[n, *d(0x90, 20+n)] for n in range(4)]
BACKGROUNDS = [[0, 800, 200, 700], [1, 61, -9, 51], [100, 801, 100, 701]]
API, CONTROL, VTABLE = 0x35000300, 0x35000100, 0x35000200
CALLS = {0x4061d0: (0, 0), 0x417170: (2, 0), 0x4450d0: (0, 0), 0x402000: (0, 0)}


class PostDrawCommands(WorldPhysics):
    source_ids = IDS
    frame_states = STATES
    header_patches = HEADERS

    def __init__(self):
        super().__init__()
        self.uc.mem_map(0x35000000, 0x1000)
        self.uc.mem_write(CONTROL, struct.pack('<I', VTABLE))
        self.uc.mem_write(VTABLE+0x1c, struct.pack('<I', API))
        self.uc.mem_write(API, b'\xc3')

    def probe(self, item, index):
        self.item = item
        result = super().probe(item, index)
        result.update(endPC=self.uc.reg_read(UC_X86_REG_EIP), retainedBefore=item.get('retained', 77),
                      retainedAfter=self.u32(BODY_SP+0x34))
        return result

    def execute(self):
        self.uc.mem_write(BODY_SP, b'\xa5'*0x800)
        self.uc.mem_write(BODY_SP+0x34, struct.pack('<I', self.item.get('retained', 77)))
        self.backgrounds = {n: struct.pack('<iii', w, z0, z1) for n, w, z0, z1 in self.item.get('backgrounds', BACKGROUNDS)}
        for n, raw in self.backgrounds.items():
            self.uc.mem_write(CATALOG+0x4d45db0+n*0x990, raw)
        self.uc.mem_write(0x45971c, struct.pack('<I', self.item.get('sse2', 0)))
        self.uc.reg_write(UC_X86_REG_FPCW, 0x27f)
        self.uc.reg_write(UC_X86_REG_FPSW, 0)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.uc.emu_start(0x4214d5, 0, count=4_000_000)
        assert self.u32(BODY_SP+0x3c) == 400 and self.uc.reg_read(UC_X86_REG_EDI) == 0
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x27f and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7 == 0
        assert self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff
        for n, raw in self.backgrounds.items():
            assert bytes(self.uc.mem_read(CATALOG+0x4d45db0+n*0x990, len(raw))) == raw

    def access(self, uc, access, address, size, value, data):
        start = CATALOG+0x4d45db0
        if self.running and start <= address < start+101*0x990:
            n, offset = divmod(address-start, 0x990)
            assert access == UC_MEM_READ and n in self.backgrounds and offset+size <= 12
        super().access(uc, access, address, size, value, data)

    def code(self, uc, pc, size, data):
        if not self.running or pc == 0x4450a0:
            return
        sp = uc.reg_read(UC_X86_REG_ESP)
        while self.pending and pc == self.pending[-1]['returnPC']:
            h = self.pending.pop()
            assert sp == h['sp']+4+h['pop'] and h['saved'] == [uc.reg_read(r) for r in REGS], h
            self.helpers += 1
            if h['entry'] == 0x417170:
                self.events.append(dict(kind='random', arguments=h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
        if pc == 0x421a15:
            assert not self.pending
            self.finished = True
            uc.emu_stop()
            return
        if pc == API:
            assert self.u32(sp) == 0x402011 and self.u32(sp+4) == CONTROL
            self.events.append(dict(kind='resumeMusic', arguments=[self.u32(BODY_SP+0x3c), CONTROL]))
            uc.reg_write(UC_X86_REG_EAX, self.item.get('methodResult', 0) & 0xffffffff)
            uc.reg_write(UC_X86_REG_ESP, sp+8)
            uc.reg_write(UC_X86_REG_EIP, self.u32(sp))
            return
        self.instructions.add(pc)
        if pc in CALLS:
            count, pop = CALLS[pc]
            self.pending.append(dict(entry=pc, sp=sp, pop=pop, returnPC=self.u32(sp),
                args=[self.u32(sp+4+4*i) for i in range(count)], saved=[uc.reg_read(r) for r in REGS]))
            if pc == 0x4061d0:
                self.target = uc.reg_read(UC_X86_REG_ECX)
                n, offset = divmod(self.target-POOL, 0x500)
                assert offset == 0 and 0 <= n < 400
                self.size = 0x420; self.mask = self.masks[n]; self.writes = []
                self.events.append(dict(kind='reconstruct', arguments=[self.u32(BODY_SP+0x34)]))
        assert any(a <= pc <= z for a, z in [(0x4214d5, 0x421a0f), (0x4061d0, 0x4064cc),
                   (0x417170, 0x4171bc), (0x4450d0, 0x44517a), (0x402000, 0x402011)]), hex(pc)


def case(group, values, actors=None, active=None, **other):
    return dict(group=group, label=group+'-'+'-'.join(map(str, values)),
                actors=actors or [], active=active if active is not None else [[0, 1]], **other)


def probes():
    for command, count, seed, source in itertools.product((-1, 0, 1, 2, 3), (-1, 0, 1, 2, 3, 4), range(4), (99, 100, 121, 122, 123, 199, 200)):
        yield case('items', (command, count, seed, source), count=count, headers=[[0, *d(0x6f4, source)]],
                   globals=[d(0x450bb8, command), d(0x450c34, seed)])
    for free_count, retained, alias, sse2 in itertools.product((0, 1, 2, 4), (0, 77, 399), (0, 1, 2), (0, 1)):
        free = list(range(50, 50+free_count))
        active = [[0, 255]]+[[i, 1] for i in range(50, 400) if i not in free]
        aliases = [[50, 0]] if alias == 1 else [[51, 50]] if alias == 2 else []
        yield case('pool', (free_count, retained, alias, sse2), retained=retained, aliases=aliases, active=active, sse2=sse2,
                   actors=[[0, [b(0xf0+50, 17), b(0xf0+51, 31)]], [399, [b(0xf0+50, 27)]]],
                   globals=[d(0x450bb8, 1), d(0x450bcc, 2999), d(0x450c34, 1233)])
    values = (-2147483648, -1000, -61, -1, 0, 59, 60, 61, 800, 2147483647)
    for arena, offset, value, seed in itertools.product((0, 1, 100), range(3), values, (0, 29)):
        bg = [800, 200, 700]; bg[offset] = value
        yield case('coordinates', (arena, offset, value, seed), count=1, backgrounds=[[arena, *bg]],
                   globals=[d(0x450bb8, 1), d(0x44d024, arena), d(0x450c34, seed)])
    for command, mode, kind, team, source in itertools.product((-1, 0, 2, 3), (0, 1, 2), (-1, 0, 1, 2, 3, 4, 5, 6), (1, 5), (299, 300, 301)):
        yield case('destroy', (command, mode, kind, team, source), actors=[[0, [d(0x364, team)]]],
                   headers=[[0, *d(0x6f8, kind)], [0, *d(0x6f4, source)]], globals=[d(0x450bb8, command), d(0x451160, mode)])
    for enabled, mode, slot, team, maximum in itertools.product((-1, 0, 1, 2), (0, 1, 2), (0, 7, 8, 399), (0, 1, 5), (-1, 499, 500, 501, 2147483647)):
        yield case('refill', (enabled, mode, slot, team, maximum), active=[[slot, 255]],
                   actors=[[slot, [d(0x364, team), d(0x304, maximum), d(0x2fc, -1), d(0x308, -5)]]],
                   globals=[d(0x450bc0, enabled), d(0x451160, mode), d(0x44f044, CONTROL)])
    for offset, timer, hp, red in itertools.product((0xe0, 0xe4), (-2147483648, -1, 0, 1, 8, 9, 999, 1000, 1001, 1008, 1009, 1100, 1999, 2000, 2147483647),
                                                    (-1, 0, 1, 492, 493, 499, 500, 501, 2147483640, 2147483646, 2147483647), (-1, 0, 500, 2147483647)):
        yield case('healing', (offset, timer, hp, red), actors=[[0, [d(offset, timer), d(0x2fc, hp), d(0x300, red)]]])
    for timers, hp, alias in itertools.product(((1009, 9), (1001, 1), (1100, 0), (1999, 1999), (0, 17)),
                                               (491, 499, 2147483640), (False, True)):
        yield case('healing-alias', (*timers, hp, alias), active=[[0, 1], [399, 255]],
                   aliases=[[399, 0]] if alias else [],
                   actors=[[i, [d(0xe0, timers[0]), d(0xe4, timers[1]), d(0x2fc, hp), d(0x300, 2147483647)]] for i in (0, 399)])
    for hp, timer in itertools.product((-1, 0, 1), (-1, 0, 1009)):
        yield case('state1700', (hp, timer), actors=[[0, [d(0x70, 300), d(0x2fc, hp), d(0xe0, timer)]]])
    for first, second, alias, state, result in itertools.product((0, 7, 398), (1, 8, 399), (False, True), (0, 300), (-2147483648, -1, 0, 1)):
        yield case('joined', (first, second, alias, state, result), active=[[first, 1], [second, 255]],
                   aliases=[[second, first]] if alias else [], methodResult=result,
                   actors=[[first, [d(0x70, state), d(0x2fc, 491), d(0x300, 500), d(0xe0, 1009), d(0xe4, 9), d(0x364, 1)]]],
                   globals=[d(0x450bb8, 2), d(0x450bc0, 1), d(0x451160, 1), d(0x44f044, CONTROL)])
    for activity in (0, 1, 2, 128, 255):
        yield case('all-slots', (activity,), active=[[i, activity] for i in range(400)],
                   actors=[[i, [d(0xe0, 1009), d(0xe4, 9), d(0x2fc, 491), d(0x300, 500), d(0x70, 300 if i%3 == 0 else 0),
                                 d(0xe8, -1430532899), d(0xec, 0x10203040), d(0x2e4, 93),
                                 d(0x2e8, 91), d(0x2ec, 92), d(0x2f0, 93)]] for i in range(400)])
    yield case('empty', (), active=[])
    yield case('null-music', (), globals=[d(0x450bc0, 1)])


def main():
    vm = PostDrawCommands(); cases = []
    for n, item in enumerate(probes()):
        cases.append(vm.probe(item, n))
        if (n+1)%500 == 0:
            print('POSTDRAW COMMANDS', n+1, flush=True)
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, fpcw=0x27f, header=HEADER, headerPatches=HEADERS,
               ids=IDS, states=STATES, backgrounds=BACKGROUNDS, cases=cases, instructions=sorted(vm.instructions))
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode(); name = 'postdraw-commands.json'
    (ROOT/'build/original'/name).write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=name, sha256=digest(raw), bytes=len(raw), fpcw=0x27f,
                  cases=len(cases), groups=dict(Counter(c['group'] for c in cases)), helpers=sum(c['helpers'] for c in cases),
                  events=sum(len(c['events']) for c in cases), instructions=len(vm.instructions), nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research'/name).write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
