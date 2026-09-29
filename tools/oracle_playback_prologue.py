#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Real41bd24..41bdce — the playback controls at the start of each tick while a
recording plays (450b84) — over the pinned EXE image in controlled Unicorn
2.1.4. The span reads and writes only globals and restores ESI from its frame
([esp+0x68]). Cases cover F6/Left/Right/Down key bytes ('d' 0x64 down, 'u'
0x75 up, other values), 44d030, the playback camera words 450b74/450b78/450b7c
and the following camera's 450bc4/450bc8 (including wrap-prone values), and
450b84 = 0. Every
data write is recorded. APPLICATION_PLAYBACK_PLAN.md P4.
"""
import json, random, struct
from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_ESP, UC_X86_REG_ESI, UC_X86_REG_EDI

STACK = 0x10000000
START, END = 0x41BD24, 0x41BDCE
WORDS = [0x44D030, 0x450B74, 0x450B78, 0x450B7C, 0x450BC4, 0x450BC8, 0x450B84]
KEYS = [0x75, 0x25, 0x27, 0x28]


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
    writes, blocks = [], set()

    def code(u, pc, size, data):
        assert START <= pc <= END or 0x41C01A <= pc < 0x41C050, hex(pc)
        blocks.add(pc)

    def written(u, access, address, size, value, data):
        if address < STACK:
            writes.append((address, size))
    uc.hook_add(UC_HOOK_CODE, code)
    uc.hook_add(UC_HOOK_MEM_WRITE, written)
    R = random.Random(0x41BD24)
    interesting = [0, 1, -1, 5, -5, 7, 14, 100, -100, 0x7FFFFFFF, -0x80000000, 0x15555556, 12345]
    cases = []
    for index in range(600):
        g = {a: R.choice(interesting + [R.randrange(-5000, 5000)]) for a in WORDS}
        g[0x450B84] = R.choice([1, 1, 1, 1, 0, 2])
        g[0x44D030] = R.choice([0, 1, 1, 0, 5, -3])
        g[0x450B74] = R.choice([0, 1, 0, 1, 2])
        keys = {k: R.choice([0x64, 0x75, 0x75, 0x64, 0x00, 0x63]) for k in KEYS}
        for a, v in g.items():
            uc.mem_write(a, struct.pack('<i', v))
        for k, v in keys.items():
            uc.mem_write(0x455378 + k, bytes([v]))
        sp = STACK + 0x8000
        uc.mem_write(sp + 0x68, struct.pack('<I', 0x5a5a5a5a))
        uc.reg_write(UC_X86_REG_ESP, sp)
        uc.reg_write(UC_X86_REG_ESI, 0x11111111)
        uc.reg_write(UC_X86_REG_EDI, 0)
        writes.clear()
        uc.emu_start(START, END)
        after = {hex(a): struct.unpack('<i', uc.mem_read(a, 4))[0] for a in WORDS}
        keys_after = {hex(k): uc.mem_read(0x455378 + k, 1)[0] for k in KEYS}
        spans = sorted(set(writes))
        cases.append(dict(before=dict(globals={hex(a): v for a, v in g.items()}, keys={hex(k): v for k, v in keys.items()}),
                          after=dict(globals=after, keys=keys_after),
                          writes=[dict(address=a, bytes=bytes(uc.mem_read(a, n)).hex()) for a, n in spans]))
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, cases=cases, blocks=sorted(blocks))
    (ROOT / 'docs/evidence/playback-prologue.json').write_text(json.dumps(doc) + '\n')
    (ROOT / 'native/Tests/NTSDCoreTests/Fixtures/original-playback-prologue.json').write_text(json.dumps(doc) + '\n')
    print('cases', len(cases), 'blocks', len(blocks))


if __name__ == '__main__':
    main()
