#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Differential test against the original x86 DAT decoder, at VA 0x4148a0.

CPU emulation is used ONLY in this developer test, never in the native app.
Only fopen/fscanf/feof/fprintf/fclose are replaced with in-memory byte streams.
No game behavior, Windows environment, or replacement engine is substituted.
The Windows EXE is not launched; a specific bounded routine is exercised.

Run: uv run tools/oracle_dat.py
"""
import hashlib
import json
import struct
from pathlib import Path

from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ESP, UC_X86_REG_EIP
from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, decode_dat, read_bytes
from inspect_original import PE


def original_decode(exe: bytes, payload: bytes) -> bytes:
    if hashlib.sha256(exe).hexdigest() != EXE_SHA256:
        raise ValueError('The oracle only supports the identified original EXE.')
    pe = PE(exe)
    uc = Uc(UC_ARCH_X86, UC_MODE_32)
    uc.mem_map(0x400000, 0x100000)
    for section in pe.sections:
        if section['name'] == '.rsrc':
            continue
        uc.mem_write(pe.base + section['rva'], exe[section['fileOffset']:section['fileOffset']+section['fileSize']])
    stack, scratch, stubs, stop = 0x10000000, 0x20000000, 0x30000000, 0x30000f00
    for address in [stack, scratch, stubs]:
        uc.mem_map(address, 0x10000)
    uc.mem_write(scratch, b'original.dat\0')
    sp = stack + 0xf000
    uc.mem_write(sp, struct.pack('<II', stop, scratch))
    uc.reg_write(UC_X86_REG_ESP, sp)
    handles = {}
    outputs = []
    lookup = {}

    def u32(address): return struct.unpack('<I', uc.mem_read(address, 4))[0]
    def string(address):
        result = bytearray()
        while len(result) < 4096:
            byte = bytes(uc.mem_read(address + len(result), 1))
            if byte == b'\0': return bytes(result)
            result.extend(byte)
        raise ValueError('Unterminated string in oracle')

    allowed = {'fopen', 'fscanf', 'feof', 'fprintf', 'fclose'}
    for item in pe.imports():
        if item['name'] in allowed:
            address = stubs + len(lookup) * 16
            lookup[address] = item['name']
            uc.mem_write(address, b'\xc3')  # cdecl RET; original caller removes args
            uc.mem_write(int(item['iatVA'], 16), struct.pack('<I', address))

    def imported_call(uc, address, size, user_data):
        name = lookup.get(address)
        if name is None: return
        esp = uc.reg_read(UC_X86_REG_ESP)
        args = [u32(esp + 4 + i*4) for i in range(3)]
        result = 0
        if name == 'fopen':
            mode = string(args[1])
            handle = len(handles) + 1
            writable = b'w' in mode
            handles[handle] = {'data': bytearray() if writable else payload, 'pos': 0, 'eof': False, 'writable': writable}
            if writable: outputs.append(handle)
            result = handle
        elif name == 'fscanf':
            stream = handles[args[0]]
            if string(args[1]) != b'%c': raise ValueError('Unexpected scan format')
            if stream['pos'] >= len(stream['data']):
                stream['eof'] = True; result = 0xffffffff
            else:
                uc.mem_write(args[2], bytes([stream['data'][stream['pos']]]))
                stream['pos'] += 1; result = 1
        elif name == 'feof': result = int(handles[args[0]]['eof'])
        elif name == 'fprintf':
            if string(args[1]) != b'%c': raise ValueError('Unexpected write format')
            handles[args[0]]['data'].append(args[2] & 255); result = 1
        elif name == 'fclose': result = 0
        uc.reg_write(UC_X86_REG_EAX, result)

    uc.hook_add(UC_HOOK_CODE, imported_call, begin=stubs, end=stubs + 0x100)
    uc.emu_start(0x4148a0, stop, timeout=30_000_000, count=100_000_000)
    if uc.reg_read(UC_X86_REG_EIP) != stop:
        raise RuntimeError('Original decoder exceeded the test execution limit')
    if len(outputs) != 1: raise RuntimeError('Unexpected number of original output streams')
    return bytes(handles[outputs[0]]['data'])


def main():
    exe = read_bytes(DEFAULT_SOURCE / 'NTSD 2.4.exe')
    cases = ['chars/naruto.dat', 'chars/sasuke.dat', 'chars/flash.dat', 'bg/sys/Valley/bg.dat']
    results = []
    for relative in cases:
        encoded = read_bytes(DEFAULT_SOURCE / relative)
        expected = original_decode(exe, encoded)
        actual = decode_dat(encoded).encode('latin-1')
        if actual != expected:
            index = next((i for i, (a,b) in enumerate(zip(actual, expected)) if a != b), min(len(actual), len(expected)))
            raise AssertionError(f'{relative}: differs from original at byte {index}; lengths {len(actual)} / {len(expected)}')
        item = {'file': relative, 'bytes': len(actual), 'decodedSHA256': hashlib.sha256(actual).hexdigest(), 'equal': True}
        results.append(item)
        print(f'Original x86 decoder matches byte-for-byte: {relative} ({len(actual)} bytes)', flush=True)
    output = ROOT / 'build/original/decoder-oracle.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'exeSHA256': EXE_SHA256, 'entryVA': '0x4148a0', 'cases': results}, indent=2) + '\n')


if __name__ == '__main__': main()
