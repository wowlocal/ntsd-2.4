#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole421a15..421a2d caller and41ae60..41b12d HUD, real bitmap/clip/rectangle.

Controlled400-slot World/Actor pool and thirteen declared bitmap records.
Actual flag reset and ret4; the HUD never reads its passed stack argument.
Full pool/masks/globals and immutable resources; ordered reads/clip/COM Blts.
Only constructor memset and device HRESULTs are boundaries. CW027f; no pixels
or Windows/full-match claim. Native constructs inputs independently.
"""
import itertools
import json
import struct
from collections import Counter
from oracle_world_drawing import WorldDrawing, BITMAP, BITMAP_SIZE, TARGET, FILL_TARGET, API, signed
from oracle_world_control import WorldControl, WORLD, BODY_SP, HEADER, REGS, d, b, digest
from import_ntsd import ROOT, EXE_SHA256
from unicorn import UC_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI,
                              UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

IDS = [2, 122, 123, 10]
RESOURCES = {0x4511a8: 10, 0x44faf4: 5, 0x44f888: 6, 0x44fcbc: 7, 0x44fb68: 8, 0x44faf8: 9, 0x44fd7c: 12}
HEADERS = [[n, *d(0x728, BITMAP+n*0x2000)] for n in range(4)]
HELPERS = {0x41ae60: 4, 0x43f010: 24, 0x43ef70: 0, 0x43f310: 28}
RESULTS = [-2147467259, 0, 1, -1]


class WorldHUD(WorldDrawing):
    source_ids = IDS
    header_patches = HEADERS

    def probe(self, item, index):
        self.item = dict(item)
        self.setup_bitmaps(item)
        self.argument_accesses = []
        item = dict(item, globals=[*[d(g, BITMAP+n*0x2000) for g, n in RESOURCES.items()],
            d(0x44d78c, 794), d(0x44d790, 550), d(0x455608, FILL_TARGET),
            d(0x450bb8, 2), d(0x450bc0, 1), *item.get('globals', [])])
        result = WorldControl.probe(self, item, index)
        for n, raw in enumerate(self.bitmap_bytes):
            assert bytes(self.uc.mem_read(BITMAP+n*0x2000, len(raw))) == raw
        result.update(endPC=self.uc.reg_read(UC_X86_REG_EIP), argumentAccesses=self.argument_accesses, blits=self.blit_count)
        return result

    def execute(self):
        self.clip = None; self.bitmap = None; self.blit_count = 0
        self.uc.mem_write(BODY_SP-0x4000, b'\xa5'*0x4800)
        self.uc.mem_write(BODY_SP+0x68, struct.pack('<I', self.item.get('argument', 0x12345678)))
        self.uc.reg_write(UC_X86_REG_EDI, 0)
        self.uc.reg_write(UC_X86_REG_FPCW, 0x27f)
        self.uc.reg_write(UC_X86_REG_FPSW, 0)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.uc.emu_start(0x421a15, 0, count=1_000_000)
        assert self.uc.reg_read(UC_X86_REG_ESP) == BODY_SP
        assert [self.uc.reg_read(r) for r in REGS] == [WORLD, 0x22334455, 0x33445566, 0]
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x27f and self.uc.reg_read(UC_X86_REG_FPSW) == 0
        assert self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff
        assert self.u32(BODY_SP-4) == self.u32(BODY_SP+0x68) == self.item.get('argument', 0x12345678)
        assert self.argument_accesses == [dict(pc=0x421a15, offset=0x68, size=4, write=False),
                                         dict(pc=0x421a19, offset=-4, size=4, write=True)]

    def access(self, uc, access, address, size, value, data):
        if self.running and address in (BODY_SP-4, BODY_SP+0x68):
            self.argument_accesses.append(dict(pc=uc.reg_read(UC_X86_REG_EIP), offset=address-BODY_SP,
                                              size=size, write=access == UC_MEM_WRITE))
        super().access(uc, access, address, size, value, data)

    def code(self, uc, pc, size, data):
        if not getattr(self, 'running', False):
            return
        sp = uc.reg_read(UC_X86_REG_ESP)
        arg = lambda n: self.u32(sp+4+4*n)
        while self.pending and pc == self.pending[-1]['returnPC']:
            h = self.pending.pop()
            assert sp == h['sp']+4+h['pop'] and h['saved'] == [uc.reg_read(r) for r in REGS], h
            self.helpers += 1
            if h['entry'] in (0x43f010, 0x43f310):
                self.bitmap = None
        if self.clip and pc == self.clip['returnPC']:
            h = self.clip; self.clip = None
            assert uc.reg_read(UC_X86_REG_EAX) in (0, 1)
            self.event('clip', clip=dict(beforeSource=h['source'], beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']], destination=[signed(self.u32(p)) for p in h['dst']],
                visible=uc.reg_read(UC_X86_REG_EAX) == 1))
        if pc == 0x421a2d:
            assert not self.pending and self.clip is None and self.bitmap is None
            self.finished = True; uc.emu_stop(); return
        if pc == API:
            assert arg(0) in (TARGET, FILL_TARGET) and arg(2) in [0, *[TARGET+0x100+n*16 for n in range(13)]] and arg(5) == 0
            self.event('blit', blit=dict(sourceSurface=arg(2), targetSurface=arg(0),
                source=list(struct.unpack('<4i', uc.mem_read(arg(3), 16))),
                destination=list(struct.unpack('<4i', uc.mem_read(arg(1), 16))), flags=arg(4), effects=None))
            results = self.item.get('methodResults', RESULTS)
            result = results[self.blit_count % len(results)]; self.blit_count += 1
            self.ret(result, 24); return
        self.instructions.add(pc)
        if pc in HELPERS:
            self.pending.append(dict(entry=pc, sp=sp, pop=HELPERS[pc], returnPC=self.u32(sp), saved=[uc.reg_read(r) for r in REGS]))
        if pc == 0x41ae60:
            assert self.u32(sp) == 0x421a2d and arg(0) == self.item.get('argument', 0x12345678)
            assert self.u32(0x450bb8) == self.u32(0x450bc0) == 0
        elif pc in (0x43f010, 0x43f310):
            pointer = uc.reg_read(UC_X86_REG_ECX)
            assert BITMAP <= pointer < BITMAP+13*0x2000 and (pointer-BITMAP) % 0x2000 == 0
            self.bitmap = (pointer-BITMAP)//0x2000
            self.event('draw' if pc == 0x43f010 else 'rectangle', [self.token(self.bitmap), *[arg(n) for n in range(6 if pc == 0x43f010 else 7)]])
        elif pc == 0x43ef70:
            assert self.clip is None
            src = [arg(i) for i in range(4)]
            dst = [uc.reg_read(UC_X86_REG_ECX), uc.reg_read(UC_X86_REG_EDI), arg(4), arg(5)]
            self.clip = dict(returnPC=self.u32(sp), src=src, dst=dst,
                             source=[signed(self.u32(p)) for p in src], destination=[signed(self.u32(p)) for p in dst])
        assert any(a <= pc <= z for a, z in [(0x421a15, 0x421a28), (0x41ae60, 0x41b12d), (0x43ef70, 0x43f37a)]), hex(pc)


def case(group, values=(), **kw):
    return dict(group=group, label=group+'-'+'-'.join(map(str, values)), **kw)


def probes():
    for cell, primary, secondary, obj in itertools.product(range(8), (0, 1, 2, 255), (0, 1, 2, 255), range(4)):
        yield case('selection', (cell, primary, secondary, obj), active=[[cell, primary], [cell+10, secondary]],
                   actors=[[cell, [d(0x368, obj), d(0x364, 1)]], [cell+10, [d(0x368, (obj+1)%4), d(0x364, 4)]]])
    for activity, alias in itertools.product((0, 1, 2, 128, 255), (False, True)):
        yield case('all-slots', (activity, alias), active=[[i, activity] for i in range(400)],
                   actors=[[i, [d(0x364, i%6), d(0x368, i%4)]] for i in range(400)], aliases=[[i, 0] for i in range(400)] if alias else [])
    for slot in (8, 9, 18, 19, 399):
        yield case('ignored-slot', (slot,), active=[[slot, 255]], headers=[[n, *d(0x728, 0)] for n in range(4)])
    values = (-2147483648, -1, 0, 1, 2, 124, 125, 499, 500, 501, 1000, 69273666, 69273667, 138547332, 2147483647)
    for slot, offset, value in itertools.product((0, 7, 10, 17), (0x2fc, 0x300, 0x308), values):
        yield case('bar-width', (slot, offset, value), active=[[slot, 1]], actors=[[slot, [d(offset, value)]]])
    for maximum in (-2147483648, 1, 500, 2147483647):
        yield case('unused-maximum', (maximum,), active=[[0, 1]], actors=[[0, [d(0x304, maximum), d(0x300, 750)]]])
    for first, second, tick, hp in itertools.product((-2147483648, -1000, -1, 0, 999, 1000, 1001, 1999, 2000, 2147483647),
                                                    (-1, 0, 1, 2147483647), (-2147483648, -3, -2, -1, 0, 1, 2, 3, 2147483647), (0, 1)):
        yield case('healing', (first, second, tick, hp), active=[[0, 1]], actors=[[0, [d(0xe0, first), d(0xe4, second), d(0x2fc, hp)]]], globals=[d(0x450bd0, tick)])
    for team, slot, hp in itertools.product((-2147483648, -1, 0, 1, 2, 3, 4, 5, 2147483647), (0, 7, 10, 17), (-1, 0, 1)):
        yield case('team', (team, slot, hp), active=[[slot, 1]], actors=[[slot, [d(0x364, team), d(0x2fc, hp)]]])
    for axis, extent, active in itertools.product((0x44d78c, 0x44d790), (-1, 0, 1, 53, 54, 197, 198, 594, 794, 2147483647), (False, True)):
        yield case('viewport', (axis, extent, active), active=[[i, 1] for i in range(18)] if active else [], globals=[d(axis, extent)])
    for bitmap, count in itertools.product((0, 4, 5, 10), (-2147483648, -1, 0, 1, 254, 255, 500, 2147483647)):
        yield case('bitmap-count', (bitmap, count), active=[[0, 1]], headers=[[0, *d(0x728, BITMAP+(4 if bitmap == 4 else 0)*0x2000)]], bitmaps=[[bitmap, *d(0xc, count)]])
    for bitmap, offset, value in itertools.product((0, 10), (4, 8), (-2147483648, -1, 0, 1, 794, 2147483647)):
        yield case('bitmap-size', (bitmap, offset, value), active=[[0, 1]], bitmaps=[[bitmap, *d(offset, value)]])
    for bitmap, offset in itertools.product((0, 5, 10, 12), (0, 4, 8, 0xc, 0xfb0, 0x1780)):
        yield case('bitmap-provenance', (bitmap, offset), active=[[0, 1]], undefinedBitmap=[[bitmap, offset, 4]])
    for resource, bitmap in itertools.product(RESOURCES, range(5, 13)):
        yield case('resource-alias', (resource, bitmap), active=[[0, 1], [1, 1]], actors=[[0, [d(0x364, 1)]], [1, [d(0x364, 4)]]], globals=[d(resource, BITMAP+bitmap*0x2000)])
    for word, target, result in itertools.product((0, 1, 0x12345678, 0xffffffff), (TARGET, FILL_TARGET), (-2147483648, -1, 0, 1)):
        yield case('caller', (word, target, result), argument=word, active=[[0, 1]], methodResults=[result], globals=[d(0x455608, target)])
    for bitmap in (0, 5, 10, 12):
        yield case('null-source', (bitmap,), active=[[0, 1]], bitmaps=[[bitmap, *d(0, 0)]])
    yield case('hidden-null-target', globals=[d(0x455608, 0), d(0x44d78c, -1), d(0x44d790, -1)])
    yield case('empty')


def main():
    vm = WorldHUD(); cases = []
    for n, item in enumerate(probes()):
        cases.append(vm.probe(item, n))
        if (n+1) % 250 == 0:
            print('WORLD HUD', n+1, flush=True)
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, ids=IDS, header=HEADER, headerPatches=HEADERS,
               cases=cases, instructions=sorted(vm.instructions), fpcw=0x27f, bitmapBase=BITMAP,
               drawTarget=TARGET, fillTarget=FILL_TARGET, resources=RESOURCES, methodResults=RESULTS)
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode(); path = ROOT/'build/original/world-hud.json'; path.write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=path.name, sha256=digest(raw), bytes=len(raw), cases=len(cases),
        groups=dict(Counter(c['group'] for c in cases)), helpers=sum(c['helpers'] for c in cases), instructions=len(vm.instructions),
        events=sum(len(c['events']) for c in cases), blits=sum(c['blits'] for c in cases), fpcw=doc['fpcw'],
        nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research/world-hud.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
