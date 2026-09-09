#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole original4450d0/445106 conversion after real x87 input operations.

Finite binary64 operands, supplied caller/registers/stack, explicit nearest
CW007f/027f/037f and MXCSR1f80. The original CPU flag selects legacy or SSE2.
Arithmetic intermediates stay on the x87 stack until the actual helper; no
host conversion or expected state seeds execution. Only the returned EAX is
the native integer contract. FPU flags are observations, not hardware proof.
"""
import json
import math
import random
import struct
from collections import Counter
from oracle_arithmetic_precision import Arithmetic, OPERATIONS
from import_ntsd import ROOT, EXE_SHA256
from oracle_actor_input import digest
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_EBP, UC_X86_REG_EBX,
    UC_X86_REG_EDI, UC_X86_REG_ESI, UC_X86_REG_EIP, UC_X86_REG_ESP,
    UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG, UC_X86_REG_MXCSR)

STACK, STOP = 0x24000000, 0x30000000
SAVED = (UC_X86_REG_EBP, UC_X86_REG_EBX, UC_X86_REG_EDI, UC_X86_REG_ESI)


def bits(value):
    return struct.unpack('<Q', struct.pack('<d', value))[0]


class Conversion(Arithmetic):
    def __init__(self):
        super().__init__()
        self.uc.mem_map(STACK, 0x2000)
        self.uc.mem_map(STOP, 0x1000)
        self.converting = False
        self.conversion_pcs = set()
        self.uc.hook_add(UC_HOOK_CODE, self.code)

    def code(self, uc, pc, size, data):
        if self.converting:
            assert pc == STOP or 0x4450d0 <= pc <= 0x44517a, hex(pc)
            if pc != STOP:
                self.conversion_pcs.add(pc)

    def probe(self, label, group, operations, values, cw, sse2):
        uc = self.uc
        uc.reg_write(UC_X86_REG_FPCW, cw)
        uc.reg_write(UC_X86_REG_FPSW, 0)
        uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        uc.reg_write(UC_X86_REG_MXCSR, 0x1f80)
        uc.reg_write(UC_X86_REG_ESI, self.address)
        uc.reg_write(UC_X86_REG_EAX, self.address)
        uc.mem_write(0x45971c, struct.pack('<I', sse2))
        # The original FDIV ST,ST(1) leaves its denominator below the result.
        if 'divide' in operations:
            assert operations.count('divide') == 1 and operations[-1] == 'divide'
            self.load(values[-1])
        self.load(values[0])
        operand = 1
        for operation in operations:
            if operation == 'store-load':
                self.step(0x40e523, 0x40e526)
                self.step(0x40e51d, 0x40e520)
                continue
            pc = OPERATIONS[operation]
            if operation == 'divide':
                self.step(pc, pc + 2)
            else:
                offset = 0x58 if operation == 'subtract' else 0x40
                uc.mem_write(self.address + offset, struct.pack('<Q', values[operand]))
                self.step(pc, pc + 3)
            operand += 1
        sp = STACK + 0x1003  # Deliberately unaligned supplied caller.
        uc.mem_write(STACK, b'\xa5' * 0x2000)
        uc.mem_write(sp, struct.pack('<I', STOP))
        uc.reg_write(UC_X86_REG_ESP, sp)
        saved = [0x11223344, 0x22334455, 0x33445566, self.address]
        for register, value in zip(SAVED, saved):
            uc.reg_write(register, value)
        self.converting = True
        try:
            uc.emu_start(0x4450d0, STOP, count=200)
        finally:
            self.converting = False
        assert uc.reg_read(UC_X86_REG_EIP) == STOP and uc.reg_read(UC_X86_REG_ESP) == sp + 4
        assert [uc.reg_read(register) for register in SAVED] == saved
        assert bytes(uc.mem_read(STACK, sp - STACK - 64)) == b'\xa5' * (sp - STACK - 64)
        assert bytes(uc.mem_read(sp + 4, STACK + 0x2000 - sp - 4)) == b'\xa5' * (STACK + 0x2000 - sp - 4)
        assert int.from_bytes(uc.mem_read(0x45971c, 4), 'little') == sse2
        result = uc.reg_read(UC_X86_REG_EAX)
        # Helper popped only the numerator/result. Original discard removes
        # the retained denominator, if any; no extra binary64 store is inserted.
        if 'divide' in operations:
            self.step(0x419791, 0x419793)
        assert uc.reg_read(UC_X86_REG_FPCW) == cw
        assert (uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7 == 0
        assert uc.reg_read(UC_X86_REG_FPTAG) == 0xffff
        return dict(label=label, group=group, operations=operations,
            inputs=[struct.pack('<Q', value).hex() for value in values], fpcw=cw,
            sse2=bool(sse2), eax=result, fpsw=uc.reg_read(UC_X86_REG_FPSW), mxcsr=uc.reg_read(UC_X86_REG_MXCSR))


def inputs():
    values = {0, 1, 2, 0xfffffffffffff, 0x10000000000000, 0x7fefffffffffffff}
    for value in (0.5, 1., 1.5, 2., 2.5, 16777216., 2147483647., 2147483648.,
                  4294967295., 4294967296., 4503599627370496., 9223372036854775808.):
        values.update(bits(x) for x in (math.nextafter(value, 0), value, math.nextafter(value, math.inf)))
    for value in sorted(values):
        for sign in (0, 1 << 63):
            v = value | sign
            yield f'load-{v:x}', 'binary64-load', [], [v]
    # Integer edges with a retained fractional remainder, including the legacy
    # low-zero/high-zero-or-indefinite shortcut around +/-2^63.
    for value in (-9223372036854775808., -4294967296., -2147483648., -16777216., -1., 0.,
                  1., 16777216., 2147483647., 2147483648., 4294967296., 9223372036854775808.):
        for delta in (-1., -0.75, -0.5, -0.25, -1e-9, -3e-10, -2**-64, 2**-64, 3e-10, 1e-9, 0.25, 0.5, 0.75, 1.):
            yield f'boundary-{value}-{delta}', 'retained-integer-edge', ['add'], [bits(value), bits(delta)]
    # These prefixes preserve values beyond the binary64 exponent range.
    for value, factor in ((0x7fefffffffffffff, bits(2.)), (1, bits(0.5)), (0x8000000000000001, bits(0.5))):
        yield f'extended-{value:x}-{factor:x}', 'extended-exponent', ['multiply'], [value, factor]
        yield f'recovered-{value:x}-{factor:x}', 'extended-exponent', ['multiply', 'divide'], [value, factor, factor]
    # Same finite expressions used by the hit conversion branch audit.
    for value in (-9223372036854775808., -1e-9, -3e-10):
        yield f'hit-{value}', 'hit-boundary', ['add', 'store-load', 'add'], [bits(value), bits(1.), bits(2147483647.)]
    rng = random.Random(0x4450d0)
    def finite():
        value = rng.getrandbits(64)
        if (value >> 52) & 0x7ff == 0x7ff:
            value ^= 1 << 52
        return value
    for n in range(2048):
        a, b = finite(), finite()
        yield f'varied-load-{n}', 'varied-load', [], [a]
        for operation in ('add', 'subtract', 'multiply', 'divide'):
            if operation == 'divide' and b & 0x7fffffffffffffff == 0:
                continue
            yield f'varied-{operation}-{n}', 'varied-' + operation, [operation], [a, b]


def main():
    vm, cases = Conversion(), []
    for n, (label, group, operations, values) in enumerate(inputs()):
        for cw in (0x7f, 0x27f, 0x37f):
            for sse2 in (0, 1):
                cases.append(vm.probe(label, group, operations, values, cw, sse2))
        if (n + 1) % 2000 == 0:
            print('COORDINATE CONVERSION', n + 1, 'inputs', len(cases), 'calls', flush=True)
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, entry=0x4450d0, flag=0x45971c,
        mxcsr=0x1f80, callerSP=STACK + 0x1003, arithmeticInstructions=sorted(vm.instructions),
        conversionInstructions=sorted(vm.conversion_pcs), cases=cases)
    raw = (json.dumps(doc, separators=(',', ':')) + '\n').encode()
    path = ROOT / 'build/original/coordinate-precision.json'
    path.write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=path.name, sha256=digest(raw), bytes=len(raw),
        cases=len(cases), groups=dict(Counter(c['group'] for c in cases)),
        arithmeticInstructions=doc['arithmeticInstructions'], conversionInstructions=doc['conversionInstructions'],
        nativeCompared=False, windowsVerified=False)
    (ROOT / 'build/research' / path.name).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
