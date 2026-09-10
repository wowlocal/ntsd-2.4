#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Self-test our collector PE on synthetic APIs, NOT Windows or the game.

Only newly compiled probe instructions execute. Deliberately artificial NLS
outputs exercise serialization, own-output dependencies and ordinary file/API
failures. Never supply these outputs to the original CRT or accepted fixtures.
Full raw output is preserved inside explicitly synthetic test envelopes.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct
from build_windows_nls_probe import IMPORTS, inspect_pe
from verify_windows_nls_capture import verify_raw
from unicorn import Uc, UC_ARCH_X86, UC_ARCH_ARM64, UC_MODE_32, UC_MODE_ARM, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_ESP, UC_X86_REG_EAX, UC_X86_REG_EIP
from unicorn.arm64_const import UC_ARM64_REG_SP, UC_ARM64_REG_PC, UC_ARM64_REG_LR, UC_ARM64_REG_X0

API_BASE, STACK = 0x30000000, 0x20000000


class CollectorTest:
    def __init__(self, exe, machine, stimulus):
        self.machine, self.stimulus = machine, stimulus
        self.raw = bytearray(); self.exit = None; self.error = 0; self.requests = []
        self.write_count = 0
        self.meta = inspect_pe(exe, machine)
        self.u = Uc(UC_ARCH_X86, UC_MODE_32) if machine == 0x14c else Uc(UC_ARCH_ARM64, UC_MODE_ARM)
        self.width = 4 if machine == 0x14c else 8
        b = exe.read_bytes(); pe = struct.unpack_from('<I', b, 0x3c)[0]; opt = pe + 24
        base = int.from_bytes(b[opt + (28 if self.width == 4 else 24):][:self.width], 'little')
        extent = struct.unpack_from('<I', b, opt + 56)[0]
        self.u.mem_map(base, extent); self.u.mem_write(base, b[:0x400])
        for s in self.meta['sections']:
            if s['rawSize']:
                self.u.mem_write(base + s['rva'], b[s['rawOffset']:s['rawOffset'] + s['rawSize']])
        self.u.mem_map(API_BASE, 0x1000); self.u.mem_map(STACK, 0x100000)
        self.u.reg_write(UC_X86_REG_ESP if self.width == 4 else UC_ARM64_REG_SP, STACK + 0xff000)
        directories = opt + (96 if self.width == 4 else 112)
        iat = struct.unpack_from('<I', b, directories + 12 * 8)[0]
        self.boundaries = {}
        for i, item in enumerate(self.meta['imports']):
            pc = API_BASE + i * 16
            self.boundaries[pc] = (item['name'], IMPORTS[item['name']] // 4)
            self.u.mem_write(base + iat + i * self.width, pc.to_bytes(self.width, 'little'))
        for i, name in enumerate(('IsWow64Process2', 'GetNLSVersionEx'), 64):
            self.boundaries[API_BASE + i * 16] = (name, 3)
        self.u.hook_add(UC_HOOK_CODE, self.api, begin=API_BASE, end=API_BASE + 0xfff)
        self.entry = base + self.meta['entryRVA']

    def integer(self, p, n=4): return int.from_bytes(self.u.mem_read(p, n), 'little')
    def put(self, p, v, n=4): self.u.mem_write(p, v.to_bytes(n, 'little'))
    def string(self, p, wide=False):
        unit = 2 if wide else 1; raw = bytearray()
        for _ in range(1024):
            item = bytes(self.u.mem_read(p, unit)); p += unit
            if not any(item): return raw.decode('utf-16le' if wide else 'ascii')
            raw.extend(item)
        raise AssertionError('Unterminated collector string')

    def api(self, u, pc, size, data):
        name, argc = self.boundaries[pc]
        sp = u.reg_read(UC_X86_REG_ESP if self.width == 4 else UC_ARM64_REG_SP)
        args = [self.integer(sp + 4 + i * 4) if self.width == 4 else u.reg_read(UC_ARM64_REG_X0 + i)
                for i in range(argc)]
        if name != 'WriteFile': self.requests.append(dict(api=name, arguments=args))
        r = 1
        if name == 'ExitProcess': self.exit = args[0]; u.emu_stop(); return
        elif name == 'CreateFileW':
            assert self.string(args[0], True) == 'nls.json'
            assert args[1:] == [0x40000000, 0, 0, 1, 0x80, 0]
            r = (1 << (self.width * 8)) - 1 if self.stimulus == 'existing' else 0x1234
        elif name == 'WriteFile':
            h, p, n, written, overlap = args
            assert h == 0x1234 and overlap == 0
            self.write_count += 1
            if self.stimulus in ('write-failure', 'write-zero') and self.write_count == 8:
                self.put(written, 0); r = int(self.stimulus == 'write-zero')
            else:
                n = min(n, 7) if self.stimulus == 'short-write' else n
                self.raw.extend(u.mem_read(p, n)); self.put(written, n)
        elif name in ('FlushFileBuffers', 'CloseHandle'):
            assert args == [0x1234]
            r = int(not (self.stimulus == 'flush-failure' and name == 'FlushFileBuffers')
                    and not (self.stimulus == 'close-failure' and name == 'CloseHandle'))
        elif name == 'GetLastError': r = self.error
        elif name == 'SetLastError': self.error = args[0]; r = 0
        elif name == 'GetStringTypeW':
            kind, source, n, destination = args
            assert kind == 1 and n in (1, 256)
            # Intentionally NON-Windows values. No classification reference.
            u.mem_write(destination, b''.join((0x6000 + i).to_bytes(2, 'little') for i in range(n)))
        elif name == 'GetCPInfo':
            assert args[0] == 1252; u.mem_write(args[1], bytes(range(20)))
        elif name == 'MultiByteToWideChar':
            cp, flags, source, n, destination, capacity = args
            assert cp == 1252 and flags in (0, 1) and n == 256 and capacity == 512
            assert bytes(u.mem_read(source, n)) == bytes(range(256))
            if self.stimulus == 'conversion-failure' and flags == 1:
                r = 0; self.error = 87
            else:
                r = n
                u.mem_write(destination, b''.join((0x1000 + i).to_bytes(2, 'little') for i in range(n)))
        elif name == 'LCMapStringW':
            locale, flags, source, n, destination, capacity = args
            assert locale == 0x409 and flags in (0x100, 0x200) and capacity == 1024
            r = n
            u.mem_write(destination, b''.join((self.integer(source + 2 * i, 2) ^ flags).to_bytes(2, 'little') for i in range(n)))
        elif name == 'WideCharToMultiByte':
            cp, flags, source, n, destination, capacity, default, used = args
            assert cp == 1252 and flags == 0 and capacity == 1024 and default == 0
            r = n; u.mem_write(destination, bytes(self.integer(source + 2 * i, 2) & 255 for i in range(n)))
            self.put(used, 0)
        elif name in ('GetACP', 'GetOEMCP', 'GetThreadLocale', 'GetSystemDefaultLCID', 'GetUserDefaultLCID'):
            r = 0xf001  # Deliberately artificial environment marker.
        elif name == 'GetCurrentProcess': r = (1 << (self.width * 8)) - 1
        elif name == 'GetModuleHandleW':
            r = {'kernel32.dll': 0x1100, 'kernelbase.dll': 0x1200, 'ntdll.dll': 0x1300}[self.string(args[0], True)]
        elif name == 'GetProcAddress':
            assert args[0] == 0x1100
            symbol = self.string(args[1]); assert symbol in ('IsWow64Process2', 'GetNLSVersionEx')
            r = 0 if self.stimulus == 'optional-absent' else API_BASE + (64 + int(symbol == 'GetNLSVersionEx')) * 16
        elif name == 'IsWow64Process2':
            self.put(args[1], 0x14c if self.width == 4 else 0, 2); self.put(args[2], 0xaa64, 2)
        elif name == 'GetModuleFileNameW':
            assert args[0] in (0x1100, 0x1200, 0x1300) and args[2] == 1024
            path = 'C:\\SYNTHETIC-NOT-WINDOWS\\test.dll'
            u.mem_write(args[1], (path + '\0').encode('utf-16le')); r = len(path)
        elif name == 'GetVersionExW':
            assert self.integer(args[0]) == 284
            u.mem_write(args[0] + 4, struct.pack('<4I', 999, 999, 999, 999))
        elif name == 'GetNLSVersionEx':
            assert args[0] == 1 and self.string(args[1], True) == 'en-US' and self.integer(args[2]) == 32
            u.mem_write(args[2] + 4, bytes(range(28)))
        else: raise AssertionError(name)
        if self.width == 4:
            ret = self.integer(sp); u.reg_write(UC_X86_REG_ESP, sp + 4 + argc * 4)
            u.reg_write(UC_X86_REG_EAX, r & 0xffffffff); u.reg_write(UC_X86_REG_EIP, ret)
        else:
            u.reg_write(UC_ARM64_REG_X0, r); u.reg_write(UC_ARM64_REG_PC, u.reg_read(UC_ARM64_REG_LR))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--kit', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args(); assert not a.output.exists(); a.output.mkdir(parents=True)
    results = []
    for arch, machine in (('x86', 0x14c), ('arm64', 0xaa64)):
        for stimulus in ('complete', 'short-write', 'conversion-failure', 'optional-absent',
                         'existing', 'write-failure', 'write-zero', 'flush-failure', 'close-failure'):
            vm = CollectorTest(a.kit / ('probe-windows-nls-' + arch + '.exe'), machine, stimulus)
            failure = None
            try: vm.u.emu_start(vm.entry, 0, count=20000000)
            except Exception as e: failure = repr(e)
            envelope = dict(scope=__doc__, synthetic=True, windowsExecuted=False,
                            gameExecuted=False, architecture=arch, stimulus=stimulus,
                            exitCode=vm.exit, failure=failure, writeCalls=vm.write_count,
                            rawBytes=len(vm.raw), rawSHA256=hashlib.sha256(vm.raw).hexdigest(),
                            rawBase64=base64.b64encode(vm.raw).decode(), requests=vm.requests)
            (a.output / (arch + '-' + stimulus + '.json')).write_text(json.dumps(envelope, sort_keys=True) + '\n')
            assert failure is None and vm.exit is not None, envelope['failure']
            expected_exit = {'existing': 21, 'write-failure': 22, 'write-zero': 22,
                             'flush-failure': 23, 'close-failure': 23}.get(stimulus, 0)
            assert vm.exit == expected_exit
            if stimulus not in ('existing', 'write-failure', 'write-zero'):
                result = verify_raw(json.loads(vm.raw), machine)
                assert result['caseCount'] == (16 if stimulus == 'conversion-failure' else 24)
                assert result['nulRequests'][0]['output'] == '0060'  # Synthetic only.
            elif stimulus == 'existing': assert not vm.raw
            else:
                assert vm.raw
                try: json.loads(vm.raw)
                except json.JSONDecodeError: pass
                else: raise AssertionError('Failed write must not be accepted as complete JSON')
            results.append(dict(architecture=arch, stimulus=stimulus, exitCode=vm.exit,
                                rawBytes=len(vm.raw), rawSHA256=hashlib.sha256(vm.raw).hexdigest()))
    report = dict(scope=__doc__, synthetic=True, windowsExecuted=False, gameExecuted=False,
                  compatibilityAccepted=False, tests=results)
    (a.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(tests=len(results), windowsExecuted=False, gameExecuted=False,
                         output=str(a.output)), indent=2))


if __name__ == '__main__': main()
