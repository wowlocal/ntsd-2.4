#!/usr/bin/env python3
"""Inspect the exact Windows executable and extract original bitmap resources.

Uses only PE structures and the user-provided EXE. No replacement engine is
used as evidence of NTSD behavior. This does not execute or patch the binary.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

from import_ntsd import DEFAULT_SOURCE, ROOT, read_bytes


class PE:
    def __init__(self, data: bytes):
        self.data = data
        if data[:2] != b'MZ':
            raise ValueError('Not a DOS/PE executable')
        self.pe = self.u32(0x3c)
        if data[self.pe:self.pe+4] != b'PE\0\0':
            raise ValueError('Missing PE signature')
        self.machine = self.u16(self.pe + 4)
        opt = self.pe + 24
        if self.u16(opt) != 0x10b:
            raise ValueError('This inspector expects PE32')
        self.base = self.u32(opt + 28)
        self.entry = self.base + self.u32(opt + 16)
        self.directories = [struct.unpack_from('<II', data, opt + 96 + i*8) for i in range(16)]
        self.sections = []
        start = opt + self.u16(self.pe + 20)
        for i in range(self.u16(self.pe + 6)):
            offset = start + i*40
            virtual_size, rva, raw_size, raw_offset = struct.unpack_from('<IIII', data, offset + 8)
            self.sections.append(dict(name=data[offset:offset+8].rstrip(b'\0').decode('ascii'),
                                      rva=rva, virtualSize=virtual_size, fileSize=raw_size, fileOffset=raw_offset))

    def u16(self, offset): return struct.unpack_from('<H', self.data, offset)[0]
    def u32(self, offset): return struct.unpack_from('<I', self.data, offset)[0]

    def offset(self, rva):
        for s in self.sections:
            if s['rva'] <= rva < s['rva'] + s['fileSize']:
                return s['fileOffset'] + rva - s['rva']
        raise ValueError(f'RVA outside file-backed sections: {rva:x}')

    def string(self, rva):
        start = self.offset(rva)
        return self.data[start:self.data.index(b'\0', start)].decode('ascii', 'replace')

    def imports(self):
        offset = self.offset(self.directories[1][0])
        result = []
        while any(self.data[offset:offset+20]):
            original, _, _, name, first = struct.unpack_from('<IIIII', self.data, offset)
            dll = self.string(name)
            table = self.offset(original or first)
            index = 0
            while self.u32(table + index*4):
                thunk = self.u32(table + index*4)
                symbol = f'ordinal:{thunk & 0xffff}' if thunk & 0x80000000 else self.string(thunk + 2)
                result.append(dict(dll=dll, name=symbol, iatVA=f'0x{self.base + first + index*4:08x}'))
                index += 1
            offset += 20
        return result

    def resources(self):
        root = self.offset(self.directories[2][0])
        result = []

        def walk(relative, path):
            offset = root + relative
            count = self.u16(offset + 12) + self.u16(offset + 14)
            for i in range(count):
                name, target = struct.unpack_from('<II', self.data, offset + 16 + i*8)
                if name & 0x80000000:
                    string_offset = root + (name & 0x7fffffff)
                    length = self.u16(string_offset)
                    name = self.data[string_offset+2:string_offset+2+length*2].decode('utf-16le')
                if target & 0x80000000:
                    walk(target & 0x7fffffff, path + [name])
                else:
                    rva, size, codepage, _ = struct.unpack_from('<IIII', self.data, root + target)
                    result.append(dict(path=path + [name], rva=rva, size=size, fileOffset=self.offset(rva), codepage=codepage))
        walk(0, [])
        return result


def dib_to_bmp(dib: bytes) -> bytes:
    header_size = struct.unpack_from('<I', dib)[0]
    if header_size < 40:
        raise ValueError('Unsupported bitmap header')
    bits = struct.unpack_from('<H', dib, 14)[0]
    compression = struct.unpack_from('<I', dib, 16)[0]
    used = struct.unpack_from('<I', dib, 32)[0]
    palette = (used or (1 << bits if bits <= 8 else 0)) * 4
    masks = 12 if header_size == 40 and compression == 3 else 0
    offset = 14 + header_size + palette + masks
    return struct.pack('<2sIHHI', b'BM', 14 + len(dib), 0, 0, offset) + dib


def inspect(executable: Path, output: Path):
    raw = read_bytes(executable)
    pe = PE(raw)
    output.mkdir(parents=True, exist_ok=True)
    bitmaps = output / 'bitmaps'
    bitmaps.mkdir(exist_ok=True)
    resources = pe.resources()
    for resource in resources:
        if resource['path'][0] == 2:
            dib = raw[resource['fileOffset']:resource['fileOffset']+resource['size']]
            name = re.sub(r'[^\w.-]', '_', str(resource['path'][1])) + f'_{resource["path"][2]}.bmp'
            (bitmaps / name).write_bytes(dib_to_bmp(dib))
            resource['extracted'] = f'bitmaps/{name}'
    report = dict(executable=executable.name, sha256=hashlib.sha256(raw).hexdigest(), size=len(raw),
                  machine=f'0x{pe.machine:04x}', imageBase=f'0x{pe.base:08x}', entry=f'0x{pe.entry:08x}',
                  sections=pe.sections, imports=pe.imports(), resources=resources)
    (output / 'executable.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'EXE SHA-256: {report["sha256"]}')
    print(f'{len(report["imports"])} imports; {len(resources)} resources; '
          f'{sum("extracted" in r for r in resources)} original bitmaps extracted.')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, default=DEFAULT_SOURCE / 'NTSD 2.4.exe')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/original')
    args = parser.parse_args()
    inspect(args.exe, args.output)
