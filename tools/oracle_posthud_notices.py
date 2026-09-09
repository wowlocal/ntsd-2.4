#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole421a2d..421cdc: actual EXE, VC80 sprintf, text/fill/bitmap children.
Controlled constructed400-Actor pool and bitmap backing; CRT and EXE run on
one CPU atCW023f. COM/GDI/PTD are declared boundaries. Preserve caller strings
through the security-cookie boundary, full pool/masks/globals and ordered output.
Separate oversized probes record actual cookie writes, not safe native success.
No initialized gameplay continuation, hardware FPU, pixel or Windows claim.
"""
import itertools
import json
import math
import struct
from collections import Counter
from oracle_world_drawing import WorldDrawing, BITMAP, BITMAP_SIZE, TARGET, FILL_TARGET, VTABLE, API, signed
from oracle_world_control import WorldControl, WORLD, BODY_SP, HEADER, REGS, d, b, digest
from oracle_crt import CRT, DLL_SHA256, AREA, STOP, prepare
from inspect_original import PE
from import_ntsd import ROOT, EXE_SHA256
from unicorn import UC_HOOK_CODE, UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

START, END = 0x421a2d, 0x421cdc
LOCAL, LOCAL_SIZE, COOKIE = BODY_SP+0x46c, 0x154, BODY_SP+0x5c0
SPRINTF, GAPI = 0x7817775d, STOP+0x2000
HELPERS = {SPRINTF: 0, 0x401290: 0, 0x415160: 0, 0x43f010: 24, 0x43ef70: 0}
FORMAT_ADDRESSES = [0x449264, 0x44924c, 0x449244, 0x4491a8, 0x449190]
FORMAT_WORDS = [5, 8, 2, 4, 0]


class PostHUDNotices(WorldDrawing):
    def __init__(self):
        super().__init__()
        crt = CRT(); pe = PE(prepare().read_bytes())
        self.uc.mem_map(pe.base, 0x100000); self.uc.mem_write(pe.base, bytes(crt.uc.mem_read(pe.base, 0x100000)))
        self.uc.mem_map(AREA, 0x20000); self.uc.mem_write(AREA, bytes(crt.uc.mem_read(AREA, 0x20000)))
        self.uc.mem_map(STOP+0x1000, 0xf000)
        crt.uc = self.uc
        crt.boundaries = {a: n for a, n in crt.boundaries.items() if not STOP <= a < STOP+0x10000}
        for i, item in enumerate(pe.imports()):
            address = STOP+0x6000+16*i; self.put(int(item['iatVA'], 16), address); crt.boundaries[address] = item['name']
        for address in crt.boundaries: self.uc.hook_add(UC_HOOK_CODE, crt.boundary, begin=address, end=address)
        self.crt = crt
        self.put(0x447174, SPRINTF)
        self.gdi = {GAPI+16*i: name for i, name in enumerate(['setBackgroundColor', 'setTextColor', 'stringLength', 'textOut', 'getDC', 'releaseDC'])}
        for iat, address in [(0x44702c, GAPI), (0x447034, GAPI+16), (0x447084, GAPI+32), (0x447038, GAPI+48),
                             (VTABLE+0x44, GAPI+64), (VTABLE+0x68, GAPI+80)]: self.put(iat, address)
        self.formats = [self.cstr(p) for p in FORMAT_ADDRESSES]
        self.literals = {hex(p): bytes(self.uc.mem_read(p, 29)).hex() if p == 0x449204 else self.cstr(p).hex()
                         for p in [0x449204, 0x449224]}

    def cstr(self, pointer):
        raw = bytearray()
        while len(raw) < 4096:
            c = self.uc.mem_read(pointer+len(raw), 1)[0]
            if c == 0: return bytes(raw)
            raw.append(c)
        raise AssertionError('Unterminated source string')

    def probe(self, item, index):
        self.item = item; self.setup_bitmaps(item)
        item = dict(item, globals=[d(0x455608, FILL_TARGET), d(0x44f8f8, BITMAP+10*0x2000),
            d(0x44d78c, 794), d(0x44d790, 550), *item.get('globals', [])])
        result = WorldControl.probe(self, item, index)
        for n, raw in enumerate(self.bitmap_bytes): assert bytes(self.uc.mem_read(BITMAP+n*0x2000, len(raw))) == raw
        result.update(endPC=self.uc.reg_read(UC_X86_REG_EIP), localBytes=bytes(self.uc.mem_read(LOCAL, LOCAL_SIZE)).hex(),
            localMask=list(self.local_mask), formats=self.format_calls, fillBacking=self.fill_backing, fpu=self.fpu,
            esi=self.uc.reg_read(UC_X86_REG_ESI), edi=self.uc.reg_read(UC_X86_REG_EDI), cookieWrites=self.cookie_writes,
            cookieAfter=bytes(self.uc.mem_read(COOKIE, 4)).hex(), blits=self.blit_count)
        return result

    def execute(self):
        self.clip = None; self.bitmap = None; self.blit_count = 0; self.format_calls = []; self.fill_backing = []; self.cookie_writes = []
        self.local_mask = bytearray(LOCAL_SIZE); self.fpu = []
        pattern = self.item.get('stackPattern', 0)
        backing = bytes([0xa5])*0x6800 if pattern == 0 else bytes((i*13+17)&255 for i in range(0x6800))
        self.uc.mem_write(BODY_SP-0x5000, backing)
        self.local_before = bytes(self.uc.mem_read(LOCAL, LOCAL_SIZE))
        self.cookie_before = bytes(self.uc.mem_read(COOKIE, 4))
        self.uc.reg_write(UC_X86_REG_EDI, 0)
        self.uc.reg_write(UC_X86_REG_FPCW, 0x23f); self.uc.reg_write(UC_X86_REG_FPSW, self.item.get('fpsw', 0)); self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.uc.emu_start(START, 0, count=2_000_000)
        assert self.uc.reg_read(UC_X86_REG_ESP) == BODY_SP and not self.pending and self.clip is None and self.bitmap is None
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x23f and self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff
        after = bytes(self.uc.mem_read(LOCAL, LOCAL_SIZE))
        assert all(mask or before == value for before, value, mask in zip(self.local_before, after, self.local_mask))
        if not self.item.get('oversized'): assert not self.cookie_writes and bytes(self.uc.mem_read(COOKIE, 4)) == self.cookie_before
        else: assert self.cookie_writes
        if self.u32(0x450c2c) == 1:
            assert self.uc.reg_read(UC_X86_REG_ESI) == len(self.cstr(LOCAL)) and self.uc.reg_read(UC_X86_REG_EDI) == LOCAL+29, (self.item, self.cstr(LOCAL), hex(self.uc.reg_read(UC_X86_REG_ESI)), hex(self.uc.reg_read(UC_X86_REG_EDI)))
        else: assert self.uc.reg_read(UC_X86_REG_ESI) == SPRINTF and self.uc.reg_read(UC_X86_REG_EDI) == 0

    def access(self, uc, access, address, size, value, data):
        if self.running and access == UC_MEM_WRITE:
            if LOCAL <= address < LOCAL+LOCAL_SIZE:
                end = min(LOCAL+LOCAL_SIZE, address+size); self.local_mask[address-LOCAL:end-LOCAL] = b'\1'*(end-address)
            if address < COOKIE+4 and address+size > COOKIE:
                self.cookie_writes.append(dict(pc=uc.reg_read(UC_X86_REG_EIP), offset=address-BODY_SP, size=size, value=value & ((1<<(8*size))-1)))
        super().access(uc, access, address, size, value, data)

    def code(self, uc, pc, size, data):
        if not getattr(self, 'running', False): return
        sp = uc.reg_read(UC_X86_REG_ESP); arg = lambda n: self.u32(sp+4+4*n)
        while self.pending and pc == self.pending[-1]['returnPC']:
            h = self.pending.pop()
            assert sp == h['sp']+4+h['pop'] and h['saved'] == [uc.reg_read(r) for r in REGS], h
            self.helpers += 1
            if h['entry'] == SPRINTF:
                count = signed(uc.reg_read(UC_X86_REG_EAX)); assert 0 <= count < 1024
                raw = bytes(uc.mem_read(h['output'], count+1)); assert raw[-1] == 0
                self.events.append(dict(kind='format', arguments=[count], strings=[list(h['format']), list(raw[:-1])]))
                self.format_calls.append(dict(format=h['format'].decode(), arguments=h['words'], result=count, bytes=raw.hex(),
                    localBytes=bytes(uc.mem_read(LOCAL, LOCAL_SIZE)).hex(), localMask=list(self.local_mask)))
            if h['entry'] == 0x43f010: self.bitmap = None
        if self.clip and pc == self.clip['returnPC']:
            h = self.clip; self.clip = None
            self.event('clip', clip=dict(beforeSource=h['source'], beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']], destination=[signed(self.u32(p)) for p in h['dst']], visible=uc.reg_read(UC_X86_REG_EAX) == 1))
        if pc in (START, 0x421a48, 0x421a53, 0x421a60, 0x421a68, END):
            self.fpu.append(dict(pc=pc, cw=uc.reg_read(UC_X86_REG_FPCW), sw=uc.reg_read(UC_X86_REG_FPSW), tag=uc.reg_read(UC_X86_REG_FPTAG)))
        if pc == END: self.finished = True; uc.emu_stop(); return
        if pc in self.gdi:
            name = self.gdi[pc]; dc = self.item.get('dc', 0x76543210); result = self.item.get('dcResult', 0)
            if name == 'getDC': self.event(name, [arg(0)]); self.put(arg(1), dc); self.ret(result, 8)
            elif name == 'releaseDC': self.event(name, [arg(0), arg(1)]); self.ret(self.item.get('methodResult', -2147467259), 8)
            elif name in ('setBackgroundColor', 'setTextColor'): self.event(name, [arg(0), arg(1)]); self.ret(0xffffffff, 8)
            elif name == 'stringLength':
                raw = self.cstr(arg(0)); self.events.append(dict(kind=name, arguments=[], strings=[list(raw)])); self.ret(len(raw), 4)
            else:
                raw = bytes(uc.mem_read(arg(3), arg(4))); self.events.append(dict(kind=name, arguments=[arg(0), arg(1), arg(2), arg(4)], strings=[list(raw)])); self.ret(0, 20)
            return
        if pc == API:
            if self.u32(sp) == 0x4151bf:
                assert arg(2) == arg(3) == 0 and arg(4) == 0x1000400
                raw = bytes(uc.mem_read(arg(5), 100)); defined = [i < 4 or 0x50 <= i < 0x54 for i in range(100)]
                self.event('fill', fill=dict(target=arg(0), rectangle=list(struct.unpack('<4i', uc.mem_read(arg(1), 16))), flags=arg(4), effects=list(raw), defined=defined))
            else:
                assert arg(5) == 0
                self.event('blit', blit=dict(sourceSurface=arg(2), targetSurface=arg(0), source=list(struct.unpack('<4i', uc.mem_read(arg(3), 16))),
                    destination=list(struct.unpack('<4i', uc.mem_read(arg(1), 16))), flags=arg(4), effects=None)); self.blit_count += 1
            self.ret(self.item.get('methodResult', -2147467259), 24); return
        if pc in self.crt.boundaries: return
        self.instructions.add(pc)
        if pc in HELPERS:
            h = dict(entry=pc, sp=sp, pop=HELPERS[pc], returnPC=self.u32(sp), saved=[uc.reg_read(r) for r in REGS]); self.pending.append(h)
            if pc == SPRINTF:
                index = FORMAT_ADDRESSES.index(arg(1)); assert arg(0) == BODY_SP+0x48c
                h.update(output=arg(0), format=self.formats[index], words=[arg(i+2) for i in range(FORMAT_WORDS[index])])
            elif pc == 0x401290:
                raw = self.cstr(arg(1)); self.events.append(dict(kind='text', arguments=[arg(0), *[arg(i) for i in range(2, 6)]], strings=[list(raw)]))
            elif pc == 0x415160:
                self.fill_backing.append(bytes(uc.mem_read(sp-100, 100)).hex())
            elif pc == 0x43f010:
                pointer = uc.reg_read(UC_X86_REG_ECX); assert BITMAP <= pointer < BITMAP+13*0x2000 and (pointer-BITMAP)%0x2000 == 0
                self.bitmap = (pointer-BITMAP)//0x2000; self.event('draw', [self.token(self.bitmap), *[arg(n) for n in range(6)]])
            elif pc == 0x43ef70:
                src = [arg(i) for i in range(4)]; dst = [uc.reg_read(UC_X86_REG_ECX), uc.reg_read(UC_X86_REG_EDI), arg(4), arg(5)]
                self.clip = dict(returnPC=self.u32(sp), src=src, dst=dst, source=[signed(self.u32(p)) for p in src], destination=[signed(self.u32(p)) for p in dst])
        assert any(a <= pc <= z for a, z in [(START, END-1), (0x401290, 0x4012fe), (0x415160, 0x4151c2),
                    (0x43ef70, 0x43f2fe), (0x78130000, 0x7822ffff)]), hex(pc)


def case(group, values=(), **kw): return dict(group=group, label=group+'-'+'-'.join(map(str, values)), **kw)
def qbits(at, bits): return [at, struct.pack('<Q', bits).hex()]
def bits(value): return struct.unpack('<Q', struct.pack('<d', value))[0]
def probes():
    for diagnostic, exit_flag, keys, mode in itertools.product((0, 1, -1), (-1, 0, 1, 2), (-1, 0, 1, 2, 3), (0, 1, 2)):
        yield case('gates', (diagnostic, exit_flag, keys, mode), globals=[d(0x450bec, diagnostic), d(0x450c2c, exit_flag), d(0x450c28, keys), d(0x451160, mode)])
    for byte in range(256):
        yield case('signed-bytes', (byte,), globals=[d(0x450bec, 1), b(0x4553e8, byte), d(0x450bfc, -2147483648 if byte%2 else 2147483647),
            *[b(0x44d040+i, (byte+i*31)%256) for i in range(8)]])
    values = [0, 1, (1<<52)-1, 1<<52, 0x7ff0000000000000, 0x7ff0000000000001, 0x7ff7ffffffffffff, 0x7ff8000000000000, 0x7ff8000000000001, 0x7fffffffffffffff]
    values += [bits(v) for v in (0.03125, 0.0625, 0.1, 1.25, 999.9995, 2199023255552.0005, 1e100, 1e140)]
    values += [bits(math.nextafter((i+0.5)/10000, toward)) for i in (-1001, -1, 0, 1, 9999) for toward in (-math.inf, math.inf)]
    for a, sign, offset in itertools.product(values, (0, 1<<63), (0x48, 0x60)):
        yield case('coordinates', (f'{a|sign:016x}', offset, int(sign != 0)), actors=[[0, [qbits(offset, a|sign), d(0x14, -2147483648 if sign else 2147483647)]]], globals=[d(0x450bec, 1)], fpsw=0x4000)
    for slot, activity in itertools.product((0, 1, 399), (0, 1, 255)):
        yield case('slot-binding', (slot, activity), aliases=[[0, slot]], active=[[0, activity]], actors=[[slot, [qbits(0x48, bits(31.0625)), qbits(0x60, bits(-1.03125)), d(0x14, -17)]]], globals=[d(0x450bec, 1)])
    for index, value, mode in itertools.product(range(4), (-2147483648, -1, 0, 1, 2147483647), (-1, 0, 1, 2)):
        yield case('key-counts', (index, value, mode), globals=[d(0x450c28, 1), d(0x451160, mode), d(0x450c18+4*index, value)], stackPattern=1)
    for dc_result, method, dc, branch in itertools.product((-2147483648, -1, 0, 1, 2147483647), (-2147483648, -1, 0, 1), (0, 0xfedcba98), (1, 2, 3)):
        yield case('device-results', (dc_result, method, dc, branch), dcResult=dc_result, methodResult=method, dc=dc,
            globals=[d(0x450bec, 1), d(0x450c2c, 1 if branch == 1 else 0), d(0x450c28, 1 if branch == 2 else 2), d(0x451160, 1)], stackPattern=1)
    for count, axis, extent in itertools.product((-2147483648, -1, 0, 1, 500, 2147483647), (0x44d78c, 0x44d790), (-1, 0, 288, 360, 550, 794)):
        yield case('bitmap-clip', (count, axis, extent), globals=[d(0x450c2c, 1), d(axis, extent)], bitmaps=[[10, *d(0xc, count)]], undefinedBitmap=[[10, 0xc, 4]])
    for a, c in ((1e140, 1e140), (1e290, 0.0)):
        yield case('long-in-backing', (a, c), actors=[[0, [qbits(0x48, bits(a)), qbits(0x60, bits(c))]]], globals=[d(0x450bec, 1), d(0x450c28, 2)], stackPattern=1)
    for a, c in ((1e308, 0.0), (0.0, -1e308), (1e150, 1e150), (1.7976931348623157e308, -1.7976931348623157e308)):
        yield case('cookie-overwrite', (a, c), oversized=True, actors=[[0, [qbits(0x48, bits(a)), qbits(0x60, bits(c))]]], globals=[d(0x450bec, 1)])


def main():
    vm = PostHUDNotices(); cases = []; overflows = []; seen = {}
    for n, item in enumerate(probes()):
        if item['label'] in seen:
            assert seen[item['label']] == item  # Same signed midpoint reached twice.
            continue
        seen[item['label']] = item
        value = vm.probe(item, n); (overflows if item.get('oversized') else cases).append(value)
        if (n+1)%250 == 0: print('POSTHUD NOTICES', n+1, flush=True)
    doc = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, header=HEADER, cases=cases, overflows=overflows,
        fpcw=0x23f, instructions=sorted(vm.instructions), formats=[s.decode() for s in vm.formats], literals=vm.literals,
        bitmapBase=BITMAP, drawTarget=TARGET, fillTarget=FILL_TARGET, localOffset=0x46c, localSize=LOCAL_SIZE, cookieOffset=0x5c0)
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode(); path = ROOT/'build/original/posthud-notices.json'; path.write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, corpus=path.name, sha256=digest(raw), bytes=len(raw),
        cases=len(cases), overflows=len(overflows), groups=dict(Counter(c['group'] for c in cases)), instructions=len(vm.instructions),
        helpers=sum(c['helpers'] for c in cases), events=sum(len(c['events']) for c in cases), nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research/posthud-notices.json').write_text(json.dumps(report, indent=2)+'\n'); print(json.dumps(report, indent=2), flush=True)

if __name__ == '__main__': main()
