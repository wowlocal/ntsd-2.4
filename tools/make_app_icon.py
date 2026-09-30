#!/usr/bin/env python3
"""The app bundle's icon from the original EXE's own icon resource.

The pinned EXE has one icon group (121) with one 32x32 24-bit image and its
AND mask — the icon Windows shows for the game. This decodes it, scales it by
whole factors with nearest-neighbour sampling (the pixel art stays crisp) into
the sizes `iconutil` expects, and writes an .icns. Standard library only.

Usage: make_app_icon.py EXE OUT.icns
"""
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path


def sections(exe):
    pe = struct.unpack_from('<I', exe, 0x3c)[0]
    count = struct.unpack_from('<H', exe, pe + 6)[0]
    optional = struct.unpack_from('<H', exe, pe + 20)[0]
    table = []
    for i in range(count):
        o = pe + 24 + optional + i * 40
        virtual_size, virtual_address, raw_size, raw = struct.unpack_from('<IIII', exe, o + 8)
        table.append((virtual_address, max(virtual_size, raw_size), raw))
    resources = struct.unpack_from('<I', exe, pe + 24 + 96 + 16)[0]
    return table, resources


def resource(exe, kind, name):
    table, root_rva = sections(exe)

    def offset(rva):
        for address, size, raw in table:
            if address <= rva < address + size:
                return raw + rva - address
        raise ValueError(hex(rva))

    root = offset(root_rva)

    def entries(directory):
        named, ids = struct.unpack_from('<HH', exe, directory + 12)
        return [struct.unpack_from('<II', exe, directory + 16 + 8 * k) for k in range(named + ids)]

    for kind_id, pointer in entries(root):
        if kind_id != kind:
            continue
        for name_id, second in entries(root + (pointer & 0x7fffffff)):
            if name_id != name:
                continue
            for _, leaf in entries(root + (second & 0x7fffffff)):
                rva, size = struct.unpack_from('<II', exe, root + leaf)
                return exe[offset(rva):offset(rva) + size]
    raise KeyError((kind, name))


def decode(image):
    """A DIB icon image (BITMAPINFOHEADER, XOR pixels, AND mask) → RGBA rows."""
    width, doubled, _, bits = struct.unpack_from('<iiHH', image, 4)
    height = doubled // 2
    if bits != 24:
        raise ValueError(f'unsupported icon depth {bits}')
    stride = (width * 3 + 3) & ~3
    mask_stride = ((width + 31) // 32) * 4
    pixels = 40
    mask = pixels + stride * height
    rows = []
    for y in range(height):
        source = height - 1 - y                     # bottom-up rows
        row = []
        for x in range(width):
            b, g, r = image[pixels + source * stride + 3 * x: pixels + source * stride + 3 * x + 3]
            transparent = image[mask + source * mask_stride + x // 8] >> (7 - x % 8) & 1
            row.append((r, g, b, 0 if transparent else 255))
        rows.append(row)
    return width, height, rows


def png(rows, factor):
    height, width = len(rows) * factor, len(rows[0]) * factor
    raw = b''.join(b'\0' + bytes(c for x in range(width) for c in rows[y // factor][x // factor]) for y in range(height))

    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data))

    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def main():
    exe = Path(sys.argv[1]).read_bytes()
    group = resource(exe, 14, 121)
    icon_id = struct.unpack_from('<H', group, 6 + 12)[0]
    width, height, rows = decode(resource(exe, 3, icon_id))
    assert (width, height) == (32, 32)
    with tempfile.TemporaryDirectory() as scratch:
        iconset = Path(scratch) / 'AppIcon.iconset'
        iconset.mkdir()
        # iconutil's names and pixel sizes; 16 would need a fractional factor, so it is omitted.
        for name, size in [('icon_16x16@2x', 32), ('icon_32x32', 32), ('icon_32x32@2x', 64), ('icon_128x128', 128),
                           ('icon_128x128@2x', 256), ('icon_256x256', 256), ('icon_256x256@2x', 512),
                           ('icon_512x512', 512), ('icon_512x512@2x', 1024)]:
            (iconset / f'{name}.png').write_bytes(png(rows, size // 32))
        subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', sys.argv[2]], check=True)


if __name__ == '__main__':
    main()
