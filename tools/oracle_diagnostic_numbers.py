#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Actual VC80 sprintf %2.3f/%2.4f used by421a60 diagnostic coordinates.

Explicit C-locale PTD and CW023f on a separate CRT CPU. Real binary64->LD10,
$I10_OUTPUT, digit rounding and fixed layout; captures17-digit intermediate.
Every binary64 exponent, both signs, mantissa boundaries, decimal midpoint
neighbors and deterministic raw-bit samples. No caller/Windows/pixel claim.
"""
import json
import math
import random
import struct
from collections import Counter
from oracle_crt import CRT, FORMAT, OUTPUT, DLL_SHA256
from import_ntsd import ROOT, EXE_SHA256
from oracle_bitmap_drawing import digest
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG


class DiagnosticNumbers(CRT):
    def __init__(self):
        super().__init__()
        self.instructions = set()
        self.uc.hook_add(UC_HOOK_CODE, self.observe)
        self.tables = [[bytes(self.uc.mem_read(base+12*i, 12)).hex() for i in range(21)] for base in (0x781c1ff0, 0x781c2150)]
        self.specials = {hex(p): bytes(self.uc.mem_read(p, 8)).split(b'\0')[0].decode('ascii')
                         for p in (0x78196388, 0x78196390, 0x78196398, 0x781963a0)}

    def observe(self, uc, pc, size, data):
        self.instructions.add(pc)
        if pc == 0x78149ed8:
            assert self.intermediate is None
            raw = bytes(uc.mem_read(uc.reg_read(UC_X86_REG_EBP)-0x2c, 26))
            count = raw[3]
            assert 0 < count <= 21 and raw[4+count] == 0
            self.intermediate = dict(decimalPosition=int.from_bytes(raw[:2], 'little', signed=True),
                negative=raw[2] == 45, digits=raw[4:4+count].decode('ascii'), finite=uc.reg_read(UC_X86_REG_EAX) == 1)
            assert raw[2] in (32, 45)

    def probe(self, group, bits, precision):
        self.uc.mem_write(FORMAT, f'%2.{precision}f'.encode()+b'\0')
        self.uc.mem_write(OUTPUT-16, b'\x96'*16+b'\xa5'*4096+b'\x69'*16)
        self.mask = bytearray(4096)
        self.uc.reg_write(UC_X86_REG_FPCW, 0x23f)
        self.uc.reg_write(UC_X86_REG_FPSW, 0)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.intermediate = None
        result = self.call(0x7817775d, [OUTPUT, FORMAT, bits & 0xffffffff, bits >> 32])
        assert 0 < result < 4096 and self.intermediate is not None
        raw = bytes(self.uc.mem_read(OUTPUT, 4096))
        assert raw[result] == 0 and raw[result+1:] == b'\xa5'*(4095-result)
        assert self.mask == b'\1'*(result+1)+bytes(4095-result)
        assert bytes(self.uc.mem_read(OUTPUT-16, 16)) == b'\x96'*16
        assert bytes(self.uc.mem_read(OUTPUT+4096, 16)) == b'\x69'*16
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x23f
        assert self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff
        return dict(group=group, bits=f'{bits:016x}', precision=precision, output=raw[:result].decode('ascii'),
                    intermediate=self.intermediate, fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW))


def probes():
    seen = set()
    def pair(group, bits):
        for precision in (3, 4):
            key = (bits, precision)
            if key not in seen:
                seen.add(key); yield group, bits, precision
    mantissas = [0, 1, (1 << 51)-1, 1 << 51, (1 << 51)+1, (1 << 52)-2, (1 << 52)-1]
    for exponent in range(2048):
        for fraction in mantissas:
            for sign in (0, 1):
                yield from pair('binary-exponent', sign << 63 | exponent << 52 | fraction)
    for precision in (3, 4):
        for integer in [-10000, -1001, -1000, -999, *range(-50, 51), 999, 1000, 1001, 10000, 999999999999999]:
            middle = (integer+0.5)/10**precision
            for value in (math.nextafter(middle, -math.inf), middle, math.nextafter(middle, math.inf)):
                yield from pair('decimal-midpoint', struct.unpack('<Q', struct.pack('<d', value))[0])
    for exponent in range(-323, 309):
        value = 10.0**exponent
        for direction in (-math.inf, 0, math.inf):
            v = math.nextafter(value, direction) if direction else value
            for sign in (1, -1):
                yield from pair('decimal-power', struct.unpack('<Q', struct.pack('<d', sign*v))[0])
    rng = random.Random(0x421a60)
    for _ in range(4096):
        yield from pair('raw-bits', rng.getrandbits(64))


def main():
    vm = DiagnosticNumbers(); cases = []
    for n, args in enumerate(probes()):
        cases.append(vm.probe(*args))
        if (n+1) % 5000 == 0: print('DIAGNOSTIC NUMBERS', n+1, flush=True)
    doc = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, fpcw=0x23f,
               tables=vm.tables, specials=vm.specials, cases=cases, instructions=sorted(vm.instructions))
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode()
    path = ROOT/'build/original/diagnostic-numbers.json'; path.write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, fpcw=doc['fpcw'], corpus=path.name,
        sha256=digest(raw), bytes=len(raw), cases=len(cases), groups=dict(Counter(c['group'] for c in cases)),
        observedPCs=len(vm.instructions), tableSHA256=digest(b''.join(bytes.fromhex(v) for t in vm.tables for v in t)),
        nativeCompared=False, windowsVerified=False, callerExecuted=False)
    (ROOT/'build/research/diagnostic-numbers.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
