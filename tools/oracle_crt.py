#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute the repository's Microsoft VC80 scanf instructions, not host atoi.

Development tooling only. The DLL is extracted from the hash-pinned original
redistributable; neither it nor Unicorn belongs in the native application's runtime.
"""
import hashlib
import io
import json
import os
import re
import struct
import subprocess
import tempfile

from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, decode_dat, read_bytes
from inspect_original import PE
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EIP, UC_X86_REG_ESP

PACKAGE_SHA256 = "8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd"
DLL_SHA256 = "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d"
DLL_NAME = "msvcr80.dll.8.0.50727.6195.98CB24AD_52FB_DB5F_FF1F_C8B3B9A1E18E"
POLICY_NAME = "manifest.8.0.50727.6195.63E949F6_03BC_5C40_FF1F_C8B3B9A1E18E"
POLICY_SHA256 = "e446fc3432a5d83eb96142ce40f4cc8ed417872539893ace445f7236ff4dd187"
STACK, AREA, STOP = 0x10000000, 0x20000000, 0x30000000
PTD, FILE, INPUT, FORMAT, OUTPUT = AREA, AREA + 0x1000, AREA + 0x2000, AREA + 0x12000, AREA + 0x13000


def prepare():
    """Extract without running the Windows installer; reject changed inputs."""
    package = ROOT / "downloads/vcredist_x86_2005sp1.exe"
    assert hashlib.sha256(read_bytes(package)).hexdigest() == PACKAGE_SHA256
    destination = ROOT / "build/original/crt/msvcr80.dll"
    policy = destination.with_name('policy.manifest')
    if destination.is_file():
        assert hashlib.sha256(destination.read_bytes()).hexdigest() == DLL_SHA256
        if policy.is_file():
            assert hashlib.sha256(policy.read_bytes()).hexdigest() == POLICY_SHA256
            return destination
    import olefile
    msi = subprocess.run(["bsdtar", "-xOf", str(package), "vcredist.msi"], check=True, capture_output=True).stdout
    with olefile.OleFileIO(io.BytesIO(msi)) as ole:
        for entry in ole.listdir():
            raw = ole.openstream(entry).read()
            if not raw.startswith(b"MSCF"):
                continue
            with tempfile.NamedTemporaryFile(suffix=".cab") as cab:
                cab.write(raw); cab.flush()
                names = subprocess.run(["bsdtar", "-tf", cab.name], check=True, capture_output=True).stdout.decode().splitlines()
                for name, path, expected in [(DLL_NAME, destination, DLL_SHA256), (POLICY_NAME, policy, POLICY_SHA256)]:
                    if name in names:
                        data = subprocess.run(["bsdtar", "-xOf", cab.name, name], check=True, capture_output=True).stdout
                        assert hashlib.sha256(data).hexdigest() == expected
                        path.parent.mkdir(parents=True, exist_ok=True)
                        path.write_bytes(data)
    if destination.is_file() and policy.is_file():
        return destination
    raise ValueError("Pinned CRT was not found in the original redistributable")


class CRT:
    def __init__(self):
        raw = prepare().read_bytes()
        pe = PE(raw)
        self.uc = Uc(UC_ARCH_X86, UC_MODE_32)
        self.uc.mem_map(pe.base, 0x100000)
        for s in pe.sections:
            self.uc.mem_write(pe.base + s['rva'], raw[s['fileOffset']:s['fileOffset'] + s['fileSize']])
        for address, size in [(0, 0x1000), (STACK, 0x10000), (AREA, 0x20000), (STOP, 0x10000)]:
            self.uc.mem_map(address, size)
        self.boundaries = {}
        self.visited = set()
        for item in pe.imports():
            address = STOP + 0x100 + len(self.boundaries) * 16
            self.put(int(item['iatVA'], 16), address)
            self.boundaries[address] = item['name']
        self.uc.hook_add(UC_HOOK_CODE, self.boundary, begin=STOP + 0x100, end=STOP + 0xFFFF)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.written, begin=OUTPUT, end=OUTPUT + 0xFFF)
        for address, name in [(0x781324C4, '_lock'), (0x781323EC, '_unlock'), (0x78132E29, '_getptd'), (0x78165576, '_read')]:
            self.boundaries[address] = name
            self.uc.hook_add(UC_HOOK_CODE, self.boundary, begin=address, end=address)
        # _calloc_crt's zero-filled PTD backing; execute its real initializer.
        self.call(0x78132CF3, [PTD, 0])

    def written(self, uc, access, address, size, value, data):
        assert OUTPUT <= address < address + size <= OUTPUT + 0x1000
        offset = address - OUTPUT
        self.mask[offset:offset + size] = b'\1' * size

    def u32(self, address):
        return int.from_bytes(self.uc.mem_read(address, 4), 'little')

    def put(self, address, value):
        self.uc.mem_write(address, struct.pack('<I', value & 0xFFFFFFFF))

    def ret(self, value=0, pop=0):
        sp = self.uc.reg_read(UC_X86_REG_ESP)
        self.uc.reg_write(UC_X86_REG_EAX, value & 0xFFFFFFFF)
        self.uc.reg_write(UC_X86_REG_EIP, self.u32(sp))
        self.uc.reg_write(UC_X86_REG_ESP, sp + 4 + pop)

    def boundary(self, uc, address, size, data):
        name = self.boundaries[address]
        self.visited.add(name)
        sp = uc.reg_read(UC_X86_REG_ESP)
        if name in ('_lock', '_unlock'):
            self.ret()
        elif name == '_getptd':
            self.ret(PTD)
        elif name == 'GetModuleHandleA':
            self.ret(0, 4)  # optional kernel32 FLS extension discovery unavailable
        elif name in ('EnterCriticalSection', 'LeaveCriticalSection'):
            self.ret(0, 4)
        elif name == 'InterlockedIncrement':
            target = self.u32(sp + 4)
            value = (self.u32(target) + 1) & 0xFFFFFFFF
            self.put(target, value); self.ret(value, 4)
        elif name == '_read':
            assert self.u32(sp + 4) == 0xFFFFFFFF and self.u32(sp + 8) == INPUT
            amount = min(self.u32(sp + 12), self.chunk, len(self.data) - self.read_position)
            uc.mem_write(INPUT, self.data[self.read_position:self.read_position + amount])
            self.read_position += amount
            self.ret(amount)
        else:
            raise ValueError((name, hex(self.u32(sp))))

    def call(self, address, args):
        sp = STACK + 0xF000
        self.uc.mem_write(sp, struct.pack('<' + 'I' * (len(args) + 1), STOP, *args))
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.emu_start(address, STOP, timeout=5_000_000, count=1_000_000)
        if self.uc.reg_read(UC_X86_REG_EIP) != STOP:
            raise ValueError('CRT call did not return')
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 4
        return struct.unpack('<i', struct.pack('<I', self.uc.reg_read(UC_X86_REG_EAX)))[0]

    def scan(self, data, fmt=b'%d', string_file=False, chunk=4096):
        assert len(fmt) < 0xFF0 and b'\0' not in fmt and chunk > 0
        if string_file:
            assert len(data) < 0x10000
            self.uc.mem_write(INPUT, data + b'\0')
        self.data, self.chunk, self.read_position = data, chunk, 0
        self.uc.mem_write(FORMAT, fmt + b'\0')
        self.uc.mem_write(OUTPUT - 16, b'\x96' * 16 + b'\xa5' * 0x1000 + b'\x69' * 16)
        self.mask = bytearray(0x1000)
        self.put(PTD + 8, 0)  # errno is separate from scanf's result
        self.uc.mem_write(FILE, struct.pack('<8I', INPUT, len(data) if string_file else 0, INPUT,
                                           0x49 if string_file else 9, 0xFFFFFFFF, 0, 0x10000, 0))
        result = self.call(0x78175F0B, [FILE, FORMAT, *[OUTPUT + i*512 for i in range(8)]])
        raw = bytes(self.uc.mem_read(OUTPUT, 0x1000))
        assert bytes(self.uc.mem_read(OUTPUT - 16, 16)) == b'\x96' * 16
        assert bytes(self.uc.mem_read(OUTPUT + 0x1000, 16)) == b'\x69' * 16
        outputs = []
        for i in range(8):
            mask = self.mask[i*512:(i+1)*512]
            size = sum(mask)
            assert mask == b'\1' * size + b'\0' * (512-size)
            assert raw[i*512+size:(i+1)*512] == b'\xa5' * (512-size)
            outputs.append(raw[i*512:i*512+size].hex())
        return dict(result=result, position=self.u32(FILE) - INPUT if string_file else self.read_position - self.u32(FILE + 4),
                    eof=bool(self.u32(FILE + 12) & 0x10), errno=self.u32(PTD + 8), outputs=outputs)


def integer_suite():
    assert hashlib.sha256(read_bytes(DEFAULT_SOURCE / 'NTSD 2.4.exe')).hexdigest() == EXE_SHA256
    registry = read_bytes(DEFAULT_SOURCE / 'data/data.txt')
    sources, literals = [], {}
    for _, _, path in re.findall(r'id:\s*(-?\d+)\s+type:\s*(-?\d+)\s+file:\s*(\S+)', registry.decode('latin1')):
        raw = read_bytes(DEFAULT_SOURCE / path.replace('\\', '/'))
        sources.append(dict(path=path, sha256=hashlib.sha256(raw).hexdigest()))
        # Inventory only. Actual field/stream consumption is tested by Object.
        for token in decode_dat(raw).split():
            if re.fullmatch(r'[+-]?[0-9]+', token):
                literals.setdefault(token, set()).add(path)
    inputs = [(value, 'source-integer-token') for value in sorted(literals)]
    inputs += [(value, 'control') for value in ['', ' ', ' \t\r\n\v\f', '+', '-', '+x', '-x', '++12', '--12', '+ 1', '-\t1',
        'nope', '0x12', '-0x12', '1.5', '+12suffix', '\xff42', '\0', '12\0x', '2147483648', '-2147483649',
        '4294967296', '-4294967296', '18446744073709551616', '-18446744073709551616', '9'*1024, '-'+ '9'*1024]]
    crt, cases = CRT(), []
    for value, kind in inputs:
        for fmt in ['%d', '%ld', '%d %d']:
            for suffix in ['', ' 7']:
                data = (value + suffix).encode('latin1')
                results = [crt.scan(data, fmt.encode(), chunk=chunk) for chunk in [1, 7, 4096]]
                assert results[0] == results[1] == results[2], (value, fmt, results)
                cases.append(dict(input=data.hex(), format=fmt, kind=kind, **results[0]))
    document = dict(dllSHA256=DLL_SHA256, exeSHA256=EXE_SHA256, packageSHA256=PACKAGE_SHA256, policySHA256=POLICY_SHA256,
                    registrySHA256=hashlib.sha256(registry).hexdigest(), sources=sources,
                    sourceIntegers=len(literals), sourceOverflow=[dict(literal=k, paths=sorted(v)) for k, v in literals.items() if not -2**31 <= int(k) < 2**31],
                    chunks=[1, 7, 4096], boundaries=sorted(crt.visited), cases=cases)
    output = ROOT / 'build/original/crt/integers.json'
    output.write_text(json.dumps(document, separators=(',', ':')) + '\n')
    print(f'Captured {len(cases)} cases × 3 buffer sizes from actual VC80 fscanf; native comparison follows.', flush=True)
    subprocess.run(['swift', 'test', '--package-path', str(ROOT / 'native'), '--filter', 'OriginalCRTTests'],
                   env={**os.environ, 'NTSD_CRT_CORPUS': str(output)}, check=True)
    fixture = ROOT / 'native/Tests/NTSDCoreTests/Fixtures/original-crt-integers.json'
    fixture.write_bytes(output.read_bytes())
    report = {k: v for k, v in document.items() if k != 'cases'}
    report.update(cases=len(cases), calls=len(cases)*3, fixtureSHA256=hashlib.sha256(fixture.read_bytes()).hexdigest(),
                  scope='Actual VC80 8.0.50727.6195 fscanf and _input_l, C locale initialized by _initptd; supplied translated bytes at _read. No Windows loader/file translation or full game verification.',
                  entries=dict(fscanf='0x78175f0b', input='0x7817b37d', initializeThread='0x78132cf3', decimalMultiply='0x7817be22', decimalAdd='0x7817be56', negate='0x7817be8c', store='0x7817bec7'))
    (ROOT / 'docs/evidence/crt-integers.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    integer_suite()
