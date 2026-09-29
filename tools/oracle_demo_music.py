#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Real4025d0 — the Demo's music selection, reached only from 42d7a1 — over the
pinned EXE image in controlled Unicorn2.1.4. Its track is read from the slot
its own `push ecx` fills, i.e. ECX at entry (no argument is pushed; at 42d7a1
ECX is the residue of the preceding text call). Cases cover music disabled
(44d010 = 0), tracks 0 (RNG 417170 tag 2 over 8), 1..8 and other values, empty
and non-empty prior paths in 44eed0, and several RNG states. 417170 executes;
402020 (music play) is a recorded boundary with its path. Every data-section
write is recorded. APPLICATION_DEMO_PLAN.md.
"""
import json, random, struct
from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_EIP, UC_X86_REG_EAX

STACK, STOP = 0x10000000, 0x30000000
ALLOWED = [(0x4025B0, 0x4025C5), (0x4025D0, 0x40280E), (0x417170, 0x4171BD)]


def main():
    raw = read_bytes(DEFAULT_SOURCE / 'NTSD 2.4.exe')
    pe = PE(raw)
    uc = Uc(UC_ARCH_X86, UC_MODE_32)
    lo = pe.base & ~0xFFF
    hi = max(pe.base + s['rva'] + max(s['virtualSize'], s['fileSize']) for s in pe.sections)
    uc.mem_map(lo, (hi - lo + 0xFFFF) & ~0xFFFF)
    for s in pe.sections:
        uc.mem_write(pe.base + s['rva'], raw[s['fileOffset']:s['fileOffset'] + s['fileSize']])
    uc.mem_map(STACK, 0x10000)
    uc.mem_map(STOP, 0x1000)
    writes, calls, blocks = [], [], set()

    def code(u, pc, size, data):
        if pc == 0x402020:
            sp = u.reg_read(UC_X86_REG_ESP)
            ret, arg = struct.unpack('<II', u.mem_read(sp, 8))
            path = bytes(u.mem_read(arg, 64)).split(b'\0')[0]
            calls.append(dict(kind='music', caller=ret, argument=arg, path=path.hex()))
            u.reg_write(UC_X86_REG_EAX, 0); u.reg_write(UC_X86_REG_ESP, sp + 4); u.reg_write(UC_X86_REG_EIP, ret)
            return
        if pc == STOP:
            u.emu_stop(); return
        assert any(a <= pc < b for a, b in ALLOWED), hex(pc)
        blocks.add(pc)

    def written(u, access, address, size, value, data):
        if address < STACK:
            writes.append((address, size))

    uc.hook_add(UC_HOOK_CODE, code)
    uc.hook_add(UC_HOOK_MEM_WRITE, written)
    R = random.Random(0x4025D0)
    seed, table = 0x4025D0, bytearray()
    for _ in range(3000):
        seed = (seed * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        table.append(((seed >> 16) & 0x7FFF) % 255 + 1)
    uc.mem_write(0x44FF90, bytes(table) + b'\0')
    cases = []
    tracks = [0] * 12 + list(range(1, 9)) * 2 + [9, -1, 0x7FFFFFFF, 0x12345678, -8, 100]
    for enabled in (0, 1, 7):
        for track in tracks:
            prior = R.choice([b'', b'bgm\\stage3.wma', b'bgm\\main.wma', b'x'])
            index, counter = R.randrange(3000), R.randrange(1234)
            before = dict(enabled=enabled, track=track, prior=prior.hex(), index=index, counter=counter)
            uc.mem_write(0x44D010, struct.pack('<i', enabled))
            uc.mem_write(0x44EED0, (prior + b'\0').ljust(0x20, b'\xa5'))
            uc.mem_write(0x450BCC, struct.pack('<ii', index, 0))
            uc.mem_write(0x450C34, struct.pack('<i', counter))
            writes.clear(); calls.clear()
            sp = STACK + 0x8000
            uc.mem_write(sp, struct.pack('<I', STOP))
            uc.reg_write(UC_X86_REG_ESP, sp)
            uc.reg_write(UC_X86_REG_ECX, track & 0xFFFFFFFF)
            uc.emu_start(0x4025D0, STOP)
            assert uc.reg_read(UC_X86_REG_ESP) == sp + 4
            spans = sorted(set(writes))
            cases.append(dict(before=before, calls=list(calls),
                              writes=[dict(address=a, bytes=bytes(uc.mem_read(a, n)).hex()) for a, n in spans],
                              after=dict(path=bytes(uc.mem_read(0x44EED0, 0x20)).hex(),
                                         index=struct.unpack('<i', uc.mem_read(0x450BCC, 4))[0],
                                         counter=struct.unpack('<i', uc.mem_read(0x450C34, 4))[0])))
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, table=bytes(table).hex(), blocks=sorted(blocks), cases=cases)
    out = ROOT / 'docs/evidence/demo-music.json'
    out.write_text(json.dumps(doc, indent=1) + '\n')
    print('cases', len(cases), 'blocks', len(blocks))


if __name__ == '__main__':
    main()
